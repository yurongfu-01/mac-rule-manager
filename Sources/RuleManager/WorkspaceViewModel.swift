import AppKit
import Foundation
import RuleCore
import SwiftUI

@MainActor
final class WorkspaceViewModel: ObservableObject {
    @Published var state: SavedState
    @Published var policyDraft: String
    @Published var config: ModelConfig
    @Published var keyDraft = ""
    @Published var inventory: Inventory?
    @Published var actions: [ValidatedAction] = []
    @Published var selectedIDs: Set<String> = []
    @Published var clarifications: [String] = []
    @Published var notice = ""
    @Published var isBusy = false

    private let store = LocalStore()
    private var planID = UUID()

    init() {
        let loaded: SavedState
        var loadProblem: String?
        do { loaded = try store.load() }
        catch {
            loaded = SavedState()
            loadProblem = "本地记录无法读取：\(error.localizedDescription)。原文件未被覆盖。"
        }
        self.state = loaded
        self.policyDraft = loaded.activePolicy?.text ?? ""
        self.config = loaded.modelConfig
        self.state.journal = loaded.journal.map(Executor.reconcile)
        if let loadProblem { self.notice = loadProblem }
        else { try? store.save(self.state) }
    }

    var rootDisplay: String { state.selectedRootPath ?? "尚未选择目录" }
    var activePolicy: Policy? { state.activePolicy }
    var plannedCount: Int { actions.count }
    var selectedCount: Int { selectedIDs.count }
    var endpointHost: String { URL(string: config.endpoint)?.host ?? "地址无效" }

    func chooseRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "授权此目录"
        if panel.runModal() == .OK, let url = panel.url {
            state.selectedRootPath = url.standardizedFileURL.path
            clearPlan()
            persist()
        }
    }

    func importPolicy() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do { policyDraft = try String(contentsOf: url, encoding: .utf8) }
            catch { notice = "导入失败：\(error.localizedDescription)" }
        }
    }

    func exportPolicy() {
        guard let policy = activePolicy else { notice = "请先保存规范。"; return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "my-rules.md"
        if panel.runModal() == .OK, let url = panel.url {
            do { try policy.text.write(to: url, atomically: true, encoding: .utf8) }
            catch { notice = "导出失败：\(error.localizedDescription)" }
        }
    }

    func savePolicy() {
        do {
            let policy = try Policy(text: policyDraft, version: (activePolicy?.version ?? 0) + 1)
            if policy.hash == activePolicy?.hash { notice = "规范内容没有变化。"; return }
            state.policies.append(policy)
            clearPlan()
            try store.save(state)
            notice = "已保存规范 v\(policy.version)。旧计划已失效。"
        } catch { notice = error.localizedDescription }
    }

    func saveConfig() {
        do {
            _ = try config.validatedURL()
            state.modelConfig = config
            try store.save(state)
            if !keyDraft.isEmpty {
                try CredentialStore.save(keyDraft, provider: config.provider)
                keyDraft = ""
            }
            clearPlan()
            notice = "模型设置已保存。密钥保存在 macOS 钥匙串。"
        } catch { notice = error.localizedDescription }
    }

    func testConnection() {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let key = try CredentialStore.read(provider: config.provider) ?? ""
                let reply = try await ModelClient.test(config: config, apiKey: key)
                notice = "连接成功：\(reply.prefix(60))"
            } catch { notice = "连接失败：\(error.localizedDescription)" }
        }
    }

    func scan() {
        guard let path = state.selectedRootPath else { notice = "请先选择授权目录。"; return }
        do {
            inventory = try Scanner.scan(root: URL(fileURLWithPath: path))
            clearPlan(keepInventory: true)
            if let inventory {
                notice = inventory.isPartial
                    ? "扫描不完整：已列出 \(inventory.records.count) 个文件，\(inventory.errors.count) 个错误；不会生成可执行计划。"
                    : "扫描完成：\(inventory.records.count) 个普通文件，跳过 \(inventory.skipped) 项。"
            }
        } catch { notice = "扫描失败：\(error.localizedDescription)" }
    }

    func generatePlan() {
        guard let policy = activePolicy, let inventory, !inventory.isPartial else {
            notice = "请先保存规范并完成一次完整扫描。"; return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let key = try CredentialStore.read(provider: config.provider) ?? ""
                let plan = try await ModelClient.propose(config: config, apiKey: key,
                                                         policy: policy, inventory: inventory)
                let validated = try PlanValidator.validate(plan, policy: policy, inventory: inventory)
                guard policy.hash == activePolicy?.hash, inventory.id == self.inventory?.id,
                      config.provider == state.modelConfig.provider else {
                    throw RuleError.invalidPlan("规范、扫描或模型配置已变化，请重新生成计划。")
                }
                actions = validated
                selectedIDs = Set(validated.map(\.id))
                clarifications = plan.clarifications
                planID = UUID()
                notice = "收到 \(validated.count) 项待审建议。请逐项查看后确认。"
            } catch { clearPlan(keepInventory: true); notice = "计划未通过校验：\(error.localizedDescription)" }
        }
    }

    func executeSelected() {
        guard let policy = activePolicy, let inventory else { notice = "计划已失效。"; return }
        let selected = actions.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty else { notice = "没有选中的操作。"; return }
        var success = 0
        var failed = 0
        for action in selected {
            do {
                let result = try Executor.execute(action, inventory: inventory, policy: policy,
                                                  planID: planID) { [self] entry in
                    upsert(entry)
                    try store.save(state)
                }
                if result.status == .verified { success += 1 } else { failed += 1 }
            } catch {
                failed += 1
                notice = "\(action.source.name)：\(error.localizedDescription)"
            }
        }
        clearPlan(keepInventory: true)
        notice = "执行结束：\(success) 项已核验，\(failed) 项跳过或失败。请查看历史。"
    }

    func undo(_ entry: JournalEntry) {
        do {
            _ = try Executor.undo(entry) { [self] updated in
                upsert(updated)
                try store.save(state)
            }
            notice = "已撤销并核验。"
        } catch { notice = "撤销失败：\(error.localizedDescription)" }
    }

    private func upsert(_ entry: JournalEntry) {
        if let index = state.journal.firstIndex(where: { $0.id == entry.id }) {
            state.journal[index] = entry
        } else { state.journal.append(entry) }
    }

    private func clearPlan(keepInventory: Bool = false) {
        actions = []
        selectedIDs = []
        clarifications = []
        planID = UUID()
        if !keepInventory { inventory = nil }
    }

    private func persist() {
        do { try store.save(state) }
        catch { notice = "保存失败：\(error.localizedDescription)" }
    }
}
