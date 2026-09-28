# Mac Rule Manager · 规则管家

一个由用户自己写规范的 macOS 文件管理工具。大模型只生成建议；本地程序验证建议，用户逐项审阅后才移动文件。

**当前状态：早期可运行版本。** 本版聚焦授权目录内的普通文件移动。应用管理、系统设置、重复文件处理、定时运行和废纸篓操作尚未实现。[设计方向](docs/ROADMAP.md)会随着实际使用反馈调整。

## 能做什么

- 自行编写、导入和导出规则。没有内置电脑清理规范；规则以 `R001:` 等编号开头，保存后形成新版本。
- 选择一个要管理的目录，扫描其中的普通文件。跳过隐藏项、应用包和符号链接；扫描不完整时禁止生成可执行计划。
- 配置 OpenAI、DeepSeek 或小米 MiMo 的 Chat Completions 兼容接口。密钥存入 macOS 钥匙串；模型标识和 HTTPS 地址可修改。
- 请求前查看发送对象及字段。默认发送规范正文、文件 ID、扩展名、大小和相对年龄；只有开启选项后才发送文件名和相对路径。不会发送文件内容或绝对路径。
- 本地检查模型 JSON、规则编号、文件 ID、路径和扫描版本。只能在授权目录内移动普通文件，且不改名、不覆盖。
- 逐项取消建议、明确确认移动；保存操作记录，核验完成状态，支持冲突检查后的撤销。

## 运行

运行和构建需要 macOS 13 或更新版本，以及 Xcode Command Line Tools（`swift --version` 可用）。运行 `swift test` 中的 XCTest 测试还需要完整 Xcode；只装命令行工具时可运行 `swift run RuleCoreChecks`。

```bash
git clone https://github.com/yurongfu-01/mac-rule-manager.git
cd mac-rule-manager
swift run MacRuleManager
```

也可执行 `bash scripts/build-app.sh` 在 `dist/` 生成未签名 `.app`。首次打开未签名应用时，macOS 可能要求手动允许。当前不提供预构建、签名或公证安装包。

## 使用流程

1. 在“我的规范”写规则，例如 `R001: 将超过 30 天的 .txt 文件移到 Archive 文件夹；其他文件不动。`，然后保存。
2. 在“模型与权限”填写服务商、模型标识和 API 密钥并保存。可先测试连接；测试请求不含本机文件清单。
3. 选择授权目录，进入“扫描与计划”本地扫描。
4. 查看外发字段、模型地址和费用提示，主动点击“发送上述数据并生成建议”。
5. 阅读每项规则依据、来源和目标；取消不需要的操作，再点击具体数量的移动按钮。
6. 在“历史记录”查看核验结果，需要时撤销。

若规则含糊或所需字段未共享，模型应提出澄清问题。请修改规则并保存新版本后重新扫描和生成计划。模型建议仍可能误判，请以实际文件路径和规则内容为准审阅。

## 开发与测试

```bash
swift test
swift run RuleCoreChecks
swift build -c release
```

代码没有第三方依赖。`Sources/RuleCore` 是扫描、API、校验和执行模块；`Sources/RuleManager` 是 SwiftUI 界面。见[架构说明](docs/ARCHITECTURE.md)、[安全与隐私](SECURITY.md)及[贡献指南](CONTRIBUTING.md)。

页面与功能的设计输入见[竞品及用户评价研究](docs/COMPETITOR_RESEARCH.md)；研究中的规划项不代表当前版本已经实现。

## 许可

MIT，见 [LICENSE](LICENSE)。
