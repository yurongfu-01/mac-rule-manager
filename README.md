# Mac Rule Manager · 规则管家

一个以对话为主入口的开源 macOS 文件管理应用。用户自己决定管理规范；AI 通过应用内工具完成选目录、扫描、写规则、生成计划、查询历史和申请撤销。涉及文件移动时，应用在本地校验计划并展示预览，用户说“确认执行”或点击确认按钮后才执行。

**当前状态：早期可运行版本。** 当前可执行范围是用户选定目录内的普通文件移动；应用管理、全盘清理、删除、重命名、定时执行尚未实现。它们不会被模型凭文字指令绕过。

## 开始使用

需要 macOS 13 或更新版本及 Xcode Command Line Tools。

```bash
git clone https://github.com/yurongfu-01/mac-rule-manager.git
cd mac-rule-manager
swift run MacRuleManager
```

也可执行 `bash scripts/build-app.sh` 生成未签名的 `dist/MacRuleManager.app`。当前没有预构建、签名或公证安装包。

1. 在首屏右侧选择 OpenAI、DeepSeek 或小米 MiMo，填入 API 密钥并保存。模型标识与 HTTPS Chat Completions 地址可修改。密钥保存在 macOS 钥匙串。
2. 点击“选择管理目录”，在 macOS 面板中授权一个目录。也可以在对话里说“帮我选择目录”，助手会打开同一个面板。
3. 用自然语言说出自己的整理习惯，例如“把超过 30 天的 PDF 放进归档文件夹，其他文件别动”。助手会把它写成 `R001:` 等编号规则；没有预设的清理规范。
4. 开启右侧“共享文件元数据”，让助手读取扫描清单。默认只有 ID、扩展名、大小和相对时间；需要依据文件名判断时再开启“包含文件名与相对路径”。聊天文字和规范正文会发送到所选模型接口，文件内容不会被扫描或发送。
5. 说“按我的规则整理这个文件夹”。助手调用应用工具扫描、提出移动计划，预览显示每项来源、目标、规则、原因和证据。取消不需要的项目后，说“确认执行”或点击按钮。历史中可查看核验结果、撤销成功的移动。

连接失败、规则不清楚、缺少共享许可、扫描不完整或计划校验失败时，助手会解释下一步。当前对话仅保存在运行中的应用进程内，重启后仍保留已保存的规则和操作历史。

## AI 工具接口

内置 OpenAI 兼容的 Chat Completions 工具调用循环，包含 `workspace_status`、`read_rules`、`choose_folder`、`scan_files`、`list_files`、`save_rules`、`prepare_moves`、`list_history`、`undo_move` 和 `execute_approved_plan`。模型返回工具名与参数；本地程序验证并执行有限动作。模型无 shell、任意文件访问、删除或自行批准移动的工具。工具协议及首次使用场景见[对话式产品规范](docs/CONVERSATIONAL_AGENT_SPEC.md)。当前工具是应用内接口，尚未开放本机 HTTP 或 MCP 服务。

计划必须引用当前规则和扫描 ID，且最多 50 项。文件类型、路径、版本、冲突和执行状态由本地代码检查。执行器不会覆盖同名文件；撤销同样要通过检查。使用边界见[安全与隐私](SECURITY.md)。

## 开发

```bash
swift test
swift run RuleCoreChecks
swift build -c release
```

本地只有 Command Line Tools 时，`swift test` 需要完整 Xcode；可先运行 `swift run RuleCoreChecks`。项目没有第三方包依赖。架构见[架构说明](docs/ARCHITECTURE.md)，后续能力见[路线图](docs/ROADMAP.md)，设计输入见[竞品与用户评价研究](docs/COMPETITOR_RESEARCH.md)。

MIT 许可，见 [LICENSE](LICENSE)。
