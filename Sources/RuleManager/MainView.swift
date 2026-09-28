import RuleCore
import SwiftUI

private enum Page: String, CaseIterable, Identifiable {
    case overview = "概览"
    case policy = "我的规范"
    case plan = "扫描与计划"
    case history = "历史记录"
    case settings = "模型与权限"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .policy: "text.book.closed"
        case .plan: "list.bullet.rectangle"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @State private var page: Page? = .overview
    @State private var showingMoveConfirmation = false

    var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: $page) { item in
                Label(item.rawValue, systemImage: item.icon).tag(item)
            }
            .navigationTitle("规则管家")
            .frame(minWidth: 170)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Text("规范 v\(vm.activePolicy?.version.description ?? "—")")
                    Text(vm.config.provider.rawValue)
                    Text(vm.inventory.map { "扫描 \($0.records.count) 项" } ?? "尚未扫描")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                Divider()
                Group {
                    switch page ?? .overview {
                    case .overview: overview
                    case .policy: policyPage
                    case .plan: planPage
                    case .history: historyPage
                    case .settings: settingsPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if !vm.notice.isEmpty {
                    Divider()
                    Text(vm.notice).font(.callout).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .confirmationDialog("确认移动所选 \(vm.selectedCount) 个文件？", isPresented: $showingMoveConfirmation) {
                Button("确认移动 \(vm.selectedCount) 个文件") { vm.executeSelected() }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请先在建议列表中核对每个来源、目标和规则依据。")
            }
        }
    }

    private var overview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("按你的规范管理 Mac").font(.largeTitle.bold())
                Text("先写规则，再选择目录。模型只生成建议；每次移动都由你确认。")
                    .foregroundStyle(.secondary)
                HStack(alignment: .top, spacing: 16) {
                    summaryCard("当前规范", vm.activePolicy.map { "v\($0.version) · \($0.ruleIDs.count) 条" } ?? "尚未创建", "text.book.closed")
                    summaryCard("授权范围", vm.state.selectedRootPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "尚未选择", "folder")
                    summaryCard("待审计划", "\(vm.plannedCount) 项", "list.bullet.rectangle")
                }
                GroupBox("下一步") {
                    VStack(alignment: .leading, spacing: 12) {
                        if vm.activePolicy == nil { Button("编写规范") { page = .policy } }
                        if vm.state.selectedRootPath == nil { Button("选择授权目录") { vm.chooseRoot() } }
                        if vm.config.model.isEmpty { Button("配置模型") { page = .settings } }
                        if vm.activePolicy != nil && vm.state.selectedRootPath != nil {
                            Button("开始扫描") { page = .plan; vm.scan() }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }.padding(28).frame(maxWidth: 900, alignment: .leading)
        }
    }

    private func summaryCard(_ title: String, _ value: String, _ icon: String) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).foregroundStyle(.secondary)
                Text(value).font(.title2.bold()).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
        }
    }

    private var policyPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("我的规范").font(.largeTitle.bold())
            Text("每条规则用 R001: 开头，写清判断条件、目标文件夹和例外。这里没有预设清理规则。")
                .foregroundStyle(.secondary)
            TextEditor(text: $vm.policyDraft)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("导入文本") { vm.importPolicy() }
                Button("导出当前规范") { vm.exportPolicy() }.disabled(vm.activePolicy == nil)
                Spacer()
                Button("保存新版本") { vm.savePolicy() }.buttonStyle(.borderedProminent)
            }
        }.padding(28)
    }

    private var planPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("扫描与计划").font(.largeTitle.bold())
            HStack {
                Text(vm.rootDisplay).lineLimit(2).textSelection(.enabled)
                Spacer()
                Button("选择目录") { vm.chooseRoot() }
                Button("本地扫描") { vm.scan() }.disabled(vm.state.selectedRootPath == nil)
            }
            if let inventory = vm.inventory {
                GroupBox("扫描覆盖") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("扫描到 \(inventory.records.count) 个普通文件；跳过 \(inventory.skipped) 项。")
                        Text(inventory.isPartial ? "扫描不完整，已禁止生成执行计划。" : "扫描完成。未读取文件内容。")
                        ForEach(inventory.errors.prefix(3), id: \.self) { Text($0).foregroundStyle(.orange) }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
                GroupBox("发送前预览") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("目标：\(vm.config.provider.rawValue) · \(vm.endpointHost) · \(vm.config.model)")
                        Text("发送：规范正文、\(inventory.records.count) 个文件 ID、扩展名、大小、相对年龄\(vm.config.includeNames ? "、文件名和相对路径" : "")。")
                        Text("不发送文件内容或绝对路径。费用未知；请在供应商后台检查价格和额度。")
                        Button(vm.isBusy ? "请求中…" : "发送上述数据并生成建议") { vm.generatePlan() }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.isBusy || inventory.isPartial || vm.activePolicy == nil)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(6)
                }
            }
            if !vm.clarifications.isEmpty {
                GroupBox("需要澄清") {
                    VStack(alignment: .leading) {
                        ForEach(vm.clarifications, id: \.self) { Text("• " + $0) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if !vm.actions.isEmpty {
                Text("待审建议 · \(vm.selectedCount) / \(vm.plannedCount) 项选中").font(.headline)
                List(vm.actions) { action in
                    Toggle(isOn: Binding(
                        get: { vm.selectedIDs.contains(action.id) },
                        set: { isOn in
                            if isOn { vm.selectedIDs.insert(action.id) }
                            else { vm.selectedIDs.remove(action.id) }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.source.relativePath + " → " + action.destinationRelativePath).bold()
                            Text("\(action.proposal.ruleID) · \(action.proposal.reason)")
                            Text(action.proposal.evidence.joined(separator: "；"))
                                .foregroundStyle(.secondary)
                        }.textSelection(.enabled)
                    }
                }
                Button("移动所选 \(vm.selectedCount) 个文件") { showingMoveConfirmation = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.selectedCount == 0)
            }
        }.padding(28)
    }

    private var historyPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("历史记录").font(.largeTitle.bold())
            Text("每项显示实际来源、目标和核验状态。撤销前会再次检查冲突与文件变化。")
                .foregroundStyle(.secondary)
            List(vm.state.journal.reversed()) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.status.rawValue).bold()
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        if entry.status == .verified {
                            Button("撤销") { vm.undo(entry) }
                        }
                    }
                    Text(entry.sourcePath + " → " + entry.destinationPath).font(.callout)
                    Text(entry.message).foregroundStyle(.secondary)
                }.textSelection(.enabled)
            }
        }.padding(28)
    }

    private var settingsPage: some View {
        Form {
            Section("模型连接") {
                Picker("服务商", selection: $vm.config.provider) {
                    ForEach(Provider.allCases) { provider in Text(provider.rawValue).tag(provider) }
                }
                .onChange(of: vm.config.provider) { provider in
                    vm.config.endpoint = provider.defaultEndpoint
                }
                TextField("模型标识", text: $vm.config.model)
                TextField("Chat Completions 地址", text: $vm.config.endpoint)
                SecureField("API 密钥（留空则保留已保存密钥）", text: $vm.keyDraft)
                Toggle("发送文件名和相对路径", isOn: $vm.config.includeNames)
                Text("密钥存在 macOS 钥匙串。更改地址前请检查域名；请求会发送给该地址。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("保存设置") { vm.saveConfig() }.buttonStyle(.borderedProminent)
                    Button("测试连接") { vm.testConnection() }.disabled(vm.isBusy)
                }
            }
            Section("目录授权") {
                Text(vm.rootDisplay).textSelection(.enabled)
                Button("选择目录") { vm.chooseRoot() }
            }
        }.padding(28).formStyle(.grouped)
    }
}
