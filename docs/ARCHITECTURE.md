# 架构

```text
用户对话 → Chat Completions 工具调用（OpenAI / DeepSeek / 小米 MiMo）
                    ↓
            AgentToolProtocol 工具目录
                    ↓
  本地状态 / 系统目录选择器 / 扫描 / 保存规则 / 历史
                    ↓
            prepare_moves → PlanValidator
                    ↓
              对话内计划预览与用户确认
                    ↓
           execute_approved_plan → Executor
                    ↓
                交易记录、核验和撤销
```

`Policy` 保存用户原文、版本和 SHA-256 哈希。每次保存新版本后丢弃旧扫描和旧计划。`Scanner` 只读元数据，给扫描项分配本次有效的文件 ID。`AgentClient` 使用 Chat Completions 的工具调用协议，保留服务商返回的工具调用 ID；小米 MiMo 和 DeepSeek 返回的推理续接字段也会按原样传回。`ModelClient` 仍提供独立的短句连接测试。

`WorkspaceViewModel` 负责对话状态和工具分发。所有工具参数先按允许字段解析；模型最多在一条用户消息里发起 8 次请求、12 次工具调用。文件清单工具需要用户在工作台打开元数据共享。目录工具只能弹出系统选择器。连接密钥永不写入模型消息。对话只在内存中保留；规则及交易记录写入本地状态。

`PlanValidator` 要求固定 JSON 字段、最多 50 项移动、存在的规则和文件 ID、相同规范哈希和扫描 ID，以及授权目录内的目标相对文件夹。程序在本机追加原文件名，不允许模型改名。`AgentApprovalGate` 只接受当前计划上用户输入的准确“确认执行”，且令牌只能使用一次。文件内容、模型输出中的其他动作和命令从未交给执行器。

`Executor` 再核对文件类型、大小、修改时间和文件编号，拒绝同名覆盖，先写入操作意图再移动，随后核验实际位置。历史保留每项状态。应用启动时会重新核验未定状态；撤销同样检查冲突和文件状态。

此版本尚未实现对自然语言规则语义的机械证明。因此所有建议都必须由用户逐项审核。工具定义与交互验收见[对话式产品规范](CONVERSATIONAL_AGENT_SPEC.md)，后续方向见[路线图](ROADMAP.md)。
