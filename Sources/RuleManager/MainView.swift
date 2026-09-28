import RuleCore
import SwiftUI

private enum Screen: String, CaseIterable {
    case chat = "AI 工作台", rules = "我的规范", history = "操作历史", settings = "连接设置"
    var icon: String {
        switch self {
        case .chat: "sparkles.rectangle.stack"
        case .rules: "text.book.closed"
        case .history: "clock.arrow.circlepath"
        case .settings: "slider.horizontal.3"
        }
    }
}

private enum Theme {
    static let ink = Color(red: 0.08, green: 0.12, blue: 0.20)
    static let navy = Color(red: 0.07, green: 0.10, blue: 0.17)
    static let teal = Color(red: 0.10, green: 0.60, blue: 0.59)
    static let canvas = Color(red: 0.965, green: 0.973, blue: 0.984)
    static let muted = Color(red: 0.43, green: 0.49, blue: 0.56)
}

struct MainView: View {
    @EnvironmentObject private var vm: WorkspaceViewModel
    @State private var screen: Screen = .chat

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 218)
            VStack(spacing: 0) {
                header
                Divider()
                HStack(spacing: 0) {
                    Group {
                        switch screen {
                        case .chat: chatScreen
                        case .rules: rulesScreen
                        case .history: historyScreen
                        case .settings: settingsScreen
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    if screen == .chat {
                        Divider()
                        contextRail.frame(width: 265)
                    }
                }
            }
            .background(Theme.canvas)
        }
        .foregroundStyle(Theme.ink)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "asterisk")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 39, height: 39)
                    .background(Theme.teal, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("RULE / OS").font(.system(size: 15, weight: .black, design: .rounded))
                    Text("你的 Mac，按你的规则").font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }.foregroundStyle(.white)
            }.padding(.horizontal, 16).padding(.top, 30).padding(.bottom, 34)

            Text("工作空间")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2).foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 19).padding(.bottom, 11)

            ForEach(Screen.allCases, id: \.self) { item in
                Button { screen = item } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.icon).frame(width: 18)
                        Text(item.rawValue)
                        Spacer()
                        if item == .rules, let policy = vm.activePolicy {
                            Text("v\(policy.version)").font(.caption2)
                        }
                    }
                    .font(.system(size: 12, weight: screen == item ? .semibold : .medium))
                    .padding(.horizontal, 12).frame(height: 40)
                    .foregroundStyle(screen == item ? .white : .white.opacity(0.63))
                    .background(screen == item ? .white.opacity(0.12) : .clear,
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10).padding(.bottom, 4)
            }
            Spacer()
            Button { vm.startNewConversation(); screen = .chat } label: {
                Label("开启新对话", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity).frame(height: 38)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).padding(.horizontal, 15)
            HStack(spacing: 8) {
                Circle().fill(vm.hasCredential ? Theme.teal : Color.orange)
                    .frame(width: 7, height: 7)
                Text(vm.hasCredential ? "密钥已保存" : "等待连接模型")
            }.font(.caption).foregroundStyle(.white.opacity(0.52))
                .padding(.horizontal, 20).padding(.vertical, 21)
        }
        .background(Theme.navy)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(screen.rawValue).font(.system(size: 17, weight: .bold))
                Text(screen == .chat ? "用一句话描述目标，助手负责操作" : "所有改动都受你的规范和授权目录约束")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(vm.config.provider.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(.white, in: Capsule())
            Text(vm.config.model).font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.muted)
        }.padding(.horizontal, 24).frame(height: 67)
    }

    private var chatScreen: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        if vm.chatItems.isEmpty { welcome }
                        ForEach(vm.chatItems) { item in bubble(item).id(item.id) }
                        if vm.isBusy {
                            HStack(spacing: 9) {
                                ProgressView().controlSize(.small)
                                Text("正在思考并操作工作空间…")
                                Button("停止") { vm.stopChat() }
                            }.font(.callout).foregroundStyle(Theme.muted).padding(12)
                        }
                        if !vm.actions.isEmpty { planPreview }
                        Color.clear.frame(height: 1).id("end")
                    }
                    .frame(maxWidth: 760).frame(maxWidth: .infinity)
                    .padding(.horizontal, 26).padding(.top, 28).padding(.bottom, 20)
                }
                .onChange(of: vm.chatItems.count) { _ in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("end", anchor: .bottom) }
                }
            }
            composer
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(Theme.teal)
                    .frame(width: 52, height: 52)
                    .background(Theme.teal.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                Spacer()
                Text("CONVERSATION FIRST")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3).foregroundStyle(Theme.teal)
            }.padding(.bottom, 25)
            Text("告诉我，你想怎样\n管理这台 Mac？")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("不需要先学会软件。说出你的习惯，我会帮你写规则、检查文件、展示计划，并在你确认后执行。")
                .font(.system(size: 14)).foregroundStyle(Theme.muted)
                .lineSpacing(5).padding(.top, 15).padding(.bottom, 27)
            Text("试着这样开始").font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.muted).padding(.bottom, 8)
            prompt("帮我选择要管理的文件夹", "folder.badge.plus")
            prompt("我想把超过 30 天的 PDF 放到归档文件夹；其他文件别动", "text.badge.plus")
            prompt("先看看这个文件夹里有什么，再按我的规则给建议", "sparkle.magnifyingglass")
            Text("示例只是提问方式，不会自动成为管理规则。")
                .font(.system(size: 10)).foregroundStyle(Theme.muted).padding(.top, 13)
        }
        .padding(27)
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.ink.opacity(0.05)))
    }

    private func prompt(_ text: String, _ icon: String) -> some View {
        Button { vm.sendChat(text) } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(Theme.teal).frame(width: 20)
                Text(text).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.left").foregroundStyle(Theme.muted)
            }
            .font(.system(size: 12, weight: .medium)).padding(12)
            .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).padding(.bottom, 7)
    }

    private func bubble(_ item: ChatItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if item.kind == .user { Spacer(minLength: 30) }
            if item.kind == .assistant {
                Image(systemName: "asterisk").font(.caption.bold()).foregroundStyle(.white)
                    .frame(width: 27, height: 27)
                    .background(Theme.teal, in: RoundedRectangle(cornerRadius: 8))
            }
            Text(item.text)
                .font(.system(size: item.kind == .activity ? 11 : 13))
                .lineSpacing(4).textSelection(.enabled)
                .padding(item.kind == .activity ? 9 : 15)
                .background(bubbleColor(item), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(item.kind == .user ? .white : item.kind == .activity ? Theme.teal : Theme.ink)
                .frame(maxWidth: item.kind == .activity ? .infinity : 610,
                       alignment: item.kind == .user ? .trailing : .leading)
            if item.kind != .user { Spacer(minLength: 15) }
        }
    }

    private func bubbleColor(_ item: ChatItem) -> Color {
        switch item.kind {
        case .user: Theme.ink
        case .assistant: .white
        case .activity: Theme.teal.opacity(0.08)
        }
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checklist.checked").foregroundStyle(Theme.teal)
                Text("等待你确认 · \(vm.selectedCount) 项移动").font(.system(size: 15, weight: .bold))
                Spacer()
                Text("未执行").font(.caption).foregroundStyle(.orange)
            }
            ForEach(vm.actions) { action in
                Toggle(isOn: Binding(
                    get: { vm.selectedIDs.contains(action.id) },
                    set: { selected in
                        if selected { vm.selectedIDs.insert(action.id) }
                        else { vm.selectedIDs.remove(action.id) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(action.source.relativePath) → \(action.destinationRelativePath)")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(action.proposal.ruleID) · \(action.proposal.reason) · \(action.proposal.evidence.joined(separator: "；"))")
                            .font(.system(size: 11)).foregroundStyle(Theme.muted)
                    }
                }.toggleStyle(.checkbox)
            }
            ForEach(vm.clarifications, id: \.self) { value in
                Text("需要澄清：" + value).font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Text("确认前可取消不需要的项目。")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
                Spacer()
                Button("确认执行 \(vm.selectedCount) 项") { vm.sendChat("确认执行") }
                    .buttonStyle(.borderedProminent).tint(Theme.teal)
                    .disabled(vm.selectedCount == 0 || vm.isBusy)
            }
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.teal.opacity(0.30)))
    }

    private var composer: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("例如：按照我的规则整理这个文件夹", text: $vm.chatInput, axis: .vertical)
                    .lineLimit(1...4).font(.system(size: 13)).textFieldStyle(.plain)
                    .onSubmit { vm.sendChat() }
                Button { vm.sendChat() } label: {
                    Image(systemName: "arrow.up").font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white).frame(width: 32, height: 32)
                        .background(Theme.teal, in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
                    .disabled(vm.chatInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isBusy)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.ink.opacity(0.1)))
            Text("聊天和规则会发给当前模型；文件元数据需另行允许。移动前会显示预览。")
                .font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
    }

    private var contextRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                railHeading("当前工作空间")
                railCard {
                    status("管理规范", vm.activePolicy.map { "v\($0.version) · \($0.ruleIDs.count) 条" } ?? "等待定义", "text.book.closed")
                    Divider()
                    status("授权目录", vm.state.selectedRootPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "尚未选择", "folder")
                    Divider()
                    status("扫描结果", vm.inventory.map { "\($0.records.count) 个文件" } ?? "尚未扫描", "list.bullet")
                    Button("选择管理目录") { vm.chooseRoot() }.font(.system(size: 11, weight: .semibold))
                }
                railHeading("模型连接")
                railCard {
                    Picker("服务商", selection: Binding(
                        get: { vm.config.provider }, set: { vm.selectProvider($0) }
                    )) {
                        ForEach(Provider.allCases) { provider in Text(provider.rawValue).tag(provider) }
                    }
                    TextField("模型标识", text: $vm.config.model).textFieldStyle(.roundedBorder)
                    SecureField(vm.hasCredential ? "密钥已保存 · 留空保留" : "填写 API 密钥", text: $vm.keyDraft)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("保存连接") { vm.saveConfig() }.buttonStyle(.borderedProminent).tint(Theme.teal)
                        Button("测试") { vm.testConnection() }.disabled(vm.isBusy)
                    }
                    Text(vm.endpointHost).font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                }
                railHeading("数据共享")
                railCard {
                    Toggle("共享文件元数据", isOn: Binding(
                        get: { vm.shareMetadata }, set: { vm.setMetadataSharing($0) }
                    ))
                    Toggle("包含文件名与相对路径", isOn: Binding(
                        get: { vm.config.includeNames }, set: { vm.setNameSharing($0) }
                    )).disabled(!vm.shareMetadata)
                    Text("只共享文件 ID、扩展名、大小与相对时间；开启第二项才发送路径。不会读取文件内容。")
                        .font(.system(size: 10)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !vm.notice.isEmpty {
                    Text(vm.notice).font(.system(size: 10)).foregroundStyle(Theme.muted)
                        .padding(12).background(Theme.teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                }
            }.padding(16)
        }.background(Color.white.opacity(0.65))
    }

    private func railHeading(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(1.1).foregroundStyle(Theme.muted)
    }

    private func railCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10, content: content)
            .font(.system(size: 11)).padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.ink.opacity(0.05)))
    }

    private func status(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.teal).frame(width: 17)
            Text(title).foregroundStyle(Theme.muted)
            Spacer(minLength: 2)
            Text(value).fontWeight(.semibold).lineLimit(1)
        }
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }

    private var rulesScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("你的规范，由你定义", "助手可以在对话里帮你起草；也可以在这里直接编辑。每条规则以 R001: 开头。")
            TextEditor(text: $vm.policyDraft)
                .font(.system(size: 13, design: .monospaced)).scrollContentBackground(.hidden)
                .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 15))
            HStack {
                Button("导入文本") { vm.importPolicy() }
                Button("导出当前规范") { vm.exportPolicy() }.disabled(vm.activePolicy == nil)
                Spacer()
                Button("保存新版本") { vm.savePolicy() }.buttonStyle(.borderedProminent).tint(Theme.teal)
            }
            Text(vm.notice).font(.caption).foregroundStyle(Theme.muted)
        }.padding(28)
    }

    private var historyScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("每次操作，都有来路", "移动结果保存在本机。你也可以在对话里说“撤销刚才的移动”。")
            List(vm.state.journal.reversed()) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.status.rawValue).bold()
                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(Theme.muted)
                        Spacer()
                        if entry.status == .verified { Button("撤销") { vm.undo(entry) } }
                    }
                    Text(entry.sourcePath + " → " + entry.destinationPath).font(.caption)
                    Text(entry.message).font(.caption).foregroundStyle(Theme.muted)
                }.padding(.vertical, 5).textSelection(.enabled)
            }.scrollContentBackground(.hidden)
            Text(vm.notice).font(.caption).foregroundStyle(Theme.muted)
        }.padding(28)
    }

    private var settingsScreen: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("连接与边界", "支持 OpenAI、DeepSeek、小米 MiMo 的工具调用接口，也可填写兼容的 HTTPS 地址。")
            Form {
                Picker("服务商", selection: Binding(
                    get: { vm.config.provider }, set: { vm.selectProvider($0) }
                )) {
                    ForEach(Provider.allCases) { provider in Text(provider.rawValue).tag(provider) }
                }
                TextField("模型标识", text: $vm.config.model)
                TextField("Chat Completions 地址", text: $vm.config.endpoint)
                SecureField("API 密钥（留空保留已保存密钥）", text: $vm.keyDraft)
                HStack {
                    Button("保存连接") { vm.saveConfig() }.buttonStyle(.borderedProminent).tint(Theme.teal)
                    Button("测试连接") { vm.testConnection() }.disabled(vm.isBusy)
                }
                Text("密钥只保存在 macOS 钥匙串。自定义地址会收到聊天、规则及你授权共享的数据。")
                    .font(.caption).foregroundStyle(Theme.muted)
            }.formStyle(.grouped)
            Text(vm.notice).font(.caption).foregroundStyle(Theme.muted)
        }.padding(28)
    }
}
