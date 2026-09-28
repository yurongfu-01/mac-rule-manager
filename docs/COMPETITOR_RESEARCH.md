# macOS 电脑管理竞品与用户评价研究

研究日期：2026-09-28
用途：开源项目的设计输入；表中的“对本品的决定”和提升清单包含尚未实现的方向，当前能力以 [README](../README.md) 为准。

## 研究方法与边界

选取六种与本品能力直接相邻的产品：综合维护（CleanMyMac）、空间分析（DaisyDisk）、规则自动化（Hazel）、轻量卸载（AppCleaner）、重复文件（Gemini 2）、自然语言文件整理（Sortio），并以 macOS 自带功能作为基线。功能与页面流程以产品官方指南为准；亮点和不足以 App Store 用户评价及用户讨论中的第一手体验为线索。评价样本跨不同年份和版本，不能代表发生率；单条严重故障报告只作为设计风险，不当作已经证实的普遍问题。

## 1. 竞品矩阵

| 产品与模式 | 页面、功能细节 | 用户认可的亮点 | 用户指出的不足 | 对本品的决定 |
|---|---|---|---|---|
| **CleanMyMac：一站式扫描和任务卡片** | Smart Care 汇总清理、安全、性能、应用、杂项结果，按卡片查看细节与取消勾选。[官方流程](https://macpaw.com/support/cleanmymac/knowledgebase/smart-care) | 用户赞赏单次扫描给出集中概览、界面易懂、减少逐个工具检查的时间。[App Store 评价](https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12&see-all=reviews) | 评价中有订阅/版本差异引发的困惑，也有卸载提示“完成”但用户随后仍能打开应用的个别报告；不同发行渠道确实存在功能差异。[英国区评价](https://apps.apple.com/gb/app/cleanmymac/id1339170533?mt=12&platform=mac&see-all=reviews)、[美国区评价](https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12&see-all=reviews)、[官方版本差异](https://cms-static.macpaw.com/support/cleanmymac/knowledgebase/missing-features) | 首页采用简明任务摘要，但每个结果必须有“已验证/未验证/需权限”状态；完成后重新检查实际文件位置。不借“健康分”暗示未经验证的性能提升。 |
| **DaisyDisk：可视化找出空间占用** | 磁盘环图逐层查看，占用项可用 Quick Look 预览；先放入 Collector，再明确删除。[官方预览](https://web.daisydiskapp.com/guide/4/en/Previewing)、[官方 Collector](https://web.daisydiskapp.com/guide/4/en/DeletingFiles) | 用户评价称扫描和视觉定位大文件很直观，节省逐层打开 Finder 的时间。[App Store 评价](https://apps.apple.com/us/app/daisydisk/id411643860?mt=12&see-all=reviews) | 有用户反映小扇区不易选择，缩放入口不直观；App Store 版本受权限限制时会出现看不到的空间。[App Store 评价](https://apps.apple.com/us/app/daisydisk/id411643860?mt=12&see-all=reviews) | 增加“空间地图 + 可排序列表”双视图、搜索和明确的扫描覆盖率；不能把无权限区域算成空白。 |
| **Hazel：文件夹规则引擎** | 以文件夹为单位建规则；支持单文件实时预览、规则状态、日志、暂停和手动运行。[规则说明](https://www.noodlesoft.com/manual/hazel/hazel-basics/about-folders-rules/)、[预览](https://www.noodlesoft.com/manual/hazel/work-with-folders-rules/create-edit-rules/preview-a-rule/)、[规则管理](https://www.noodlesoft.com/manual/hazel/work-with-folders-rules/manage-rules/) | 长期用户认为强大规则显著节省重复劳动。[用户讨论](https://www.reddit.com/r/macapps/comments/1it0la5) | 新用户表示入门复杂；有人需要按需运行而非持续监视；也有价格顾虑。[入门讨论](https://www.reddit.com/r/macapps/comments/1go0ytk)、[按需执行讨论](https://www.reddit.com/r/macapps/comments/1k3sz8a)、[替代产品讨论](https://www.reddit.com/r/macapps/comments/1pn8teg/) | 规范编辑采用“自然语言 + 结构化解释 + 实例测试”三层；同一规则既可按需运行，也可经用户开启后定时生成计划。 |
| **AppCleaner：单任务轻量工具** | 拖入应用，列出关联文件供用户选择后处理。[官网](https://freemacsoft.net/appcleaner/) | 用户称界面简单、轻量，查看关联文件后再决定很直接。[用户讨论](https://www.reddit.com/r/macapps/comments/1dzqy8l/app_cleaner_vs_pear_cleaner/)、[另一组用户评价](https://www.reddit.com/r/mac/comments/1kwqp56/are_you_for_or_against_appcleaner/) | 有用户报告它仍会遗漏遗留文件；“彻底卸载”难以仅靠候选匹配保证。[遗留文件讨论](https://www.reddit.com/r/macapps/comments/1hrucxk/)、[另一报告](https://www.reddit.com/r/macapps/comments/1lqc8t8/) | 保持单任务入口清楚；应用盘点与卸载分开。首版不声称能够完整卸载应用，后续若加入卸载须显示候选来源和未覆盖范围。 |
| **Gemini 2：重复文件分组与智能选择** | 区分完全重复和相似文件，支持网格比较与批量选择规则。[官方结果页](https://macpaw.com/support/gemini/knowledgebase/reviewing-scan-results) | 用户报告扫描大量跨盘重复文件、节省人工比较时间。[App Store 评价](https://apps.apple.com/us/app/gemini-2-the-duplicate-finder/id1090488118?mt=12&platform=mac&see-all=reviews) | 部分用户表示“选择的是删除还是保留”容易混淆、自动选择依据不透明；路径截断使跨目录副本难比较，还有重复扫描结果不一致的个别报告。[App Store 评价](https://apps.apple.com/us/app/gemini-2-the-duplicate-finder/id1090488118?mt=12&platform=mac&see-all=reviews) | 重复项明确显示“保留此文件/处理此副本”，完整路径可展开；精确重复与相似候选分栏；用户能按文件夹设置保留优先级。首版只列复查，不自动删除。 |
| **Sortio：自然语言 + AI 整理** | 用户用普通语言表达分类、重命名和路由要求，可让规则持续处理新文件。[官网](https://www.getsortio.com/) | 用户对按文件内容整理和重命名的方向感兴趣，期望少写复杂规则。[用户讨论](https://www.reddit.com/r/macapps/comments/1jwwp4s/sortio_can_now_rename_files_and_sort_by_content/) | 用户问“究竟读文件名还是内容、使用什么模型”；有试用后卡住的报告，还有一条未独立核实的数据丢失报告。另有用户指出自然语言里“文件类型”与“扩展名”可能被不同解释。[隐私疑问](https://www.reddit.com/r/macapps/comments/1fq7lax)、[运行及风险报告](https://www.reddit.com/r/macapps/comments/1jwwp4s/sortio_can_now_rename_files_and_sort_by_content/)、[分类歧义讨论](https://www.reddit.com/r/macapps/comments/1pn8teg/) | 每次模型调用前展示服务商、外发字段和费用估算；规则先产出可编辑解释，再用测试样本验证；文件操作写前日志、逐项验证、可暂停和撤销。 |

### macOS 自带功能基线

Finder 智能文件夹已能按文件类型、日期、内容等条件保存动态搜索；macOS 也提供存储管理建议。本品不应把这些已有能力包装成独有创新，应突出跨规则解释、计划审阅和可追溯执行。[Apple 智能文件夹说明](https://support.apple.com/en-asia/guide/mac-help/mchlp2804/mac)、[Apple 存储建议](https://support.apple.com/en-au/guide/mac-help/-sysp4ee93ca4/mac)

Apple 将“系统数据”描述为未归入其他类别的 Apple 和第三方文件的通用统计类别；用户讨论也反复出现不知道这些空间对应哪些文件的困惑。因此本品的空间页要显示可定位的实际目录、无法扫描的部分以及统计口径，不把“系统数据”直接标成可清理垃圾。[Apple 说明](https://support.apple.com/en-gb/102624)、[用户讨论](https://www.reddit.com/r/MacOS/comments/1tg3dfu/system_data_size_is_huge/)

## 2. 跨产品发现

1. **用户喜欢先得到有用的总体视图。** CleanMyMac 的集中任务卡与 DaisyDisk 的空间图减少“从哪里开始”的成本，但任务卡必须能展开到具体文件与验证状态。[CleanMyMac 用户评价](https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12&see-all=reviews)、[DaisyDisk 用户评价](https://apps.apple.com/us/app/daisydisk/id411643860?mt=12&see-all=reviews)
2. **规则的可解释性比规则数量重要。** Hazel 的预览和日志已经证明“为什么匹配”可在界面中解释；用户仍会因规则复杂和自动运行模式而困惑。本品应把规则解释和样本测试放在保存流程内。[Hazel 官方预览](https://www.noodlesoft.com/manual/hazel/work-with-folders-rules/create-edit-rules/preview-a-rule/)、[用户讨论](https://www.reddit.com/r/macapps/comments/1go0ytk/)
3. **“看见建议”和“相信执行完成”是两件事。** CleanMyMac 的个别卸载反馈、Gemini 2 对选择语义的抱怨，说明结果页要展示实际目标、成功/跳过/失败和执行后验证；按钮不能只显示“完成”。[CleanMyMac 评价](https://apps.apple.com/us/app/cleanmymac/id1339170533?mt=12&see-all=reviews)、[Gemini 2 评价](https://apps.apple.com/us/app/gemini-2-the-duplicate-finder/id1090488118?mt=12&platform=mac&see-all=reviews)
4. **AI 能降低规则编写门槛，也增加不确定性。** 用户不清楚发送了什么、模型怎样理解“分类”，以及失败后能否恢复。本品要显示模型解释稿、外发清单、成本估算、逐项交易与撤销。[Sortio 官网](https://www.getsortio.com/)、[用户疑问](https://www.reddit.com/r/macapps/comments/1fq7lax)、[分类歧义讨论](https://www.reddit.com/r/macapps/comments/1pn8teg/)
5. **权限与发行渠道影响扫描完整性。** DaisyDisk 和 CleanMyMac 都有与渠道/权限相关的功能差异。首版必须展示“扫描到多少、哪些区域无法扫描、为什么”，绝不把未扫描区域当作没有问题。[DaisyDisk 评价](https://apps.apple.com/us/app/daisydisk/id411643860?mt=12&see-all=reviews)、[CleanMyMac 官方差异表](https://cms-static.macpaw.com/support/cleanmymac/knowledgebase/missing-features)

## 3. 本品提升清单

| 优先级 | 能力 | 对应发现 | 验收重点 |
|---|---|---|---|
| P0 | 规范解释稿与逐条样本测试 | Hazel 易用性、Sortio 语义歧义 | 可看到每条规则匹配/不匹配的原因，用户修订后才启用 |
| P0 | 外发数据、服务商与费用预览 | AI 隐私和信任疑问 | 请求前显示字段和估算；取消后不发送 |
| P0 | 扫描覆盖率与权限缺口 | DaisyDisk 隐藏空间 | 未扫描目录和错误单独显示，不给“全盘已检查”的错觉 |
| P0 | 执行前逐项队列与执行后核验 | CleanMyMac、Gemini 2、Sortio 风险 | 完整路径、保留/处理语义、来源/目标、实际结果与恢复入口 |
| P1 | 空间地图 + 列表双视图 | DaisyDisk 视觉优势与小扇区问题 | 地图可缩放，列表可搜索/排序，结果一致 |
| P1 | 重复文件比较与保留位置偏好 | Gemini 2 审阅痛点 | 精确重复和相似候选分开，完整路径与预览可见 |
| P1 | 按需运行 / 定时生成计划双模式 | Hazel 场景差异 | 默认按需；后台扫描可暂停，定时只生成待审计划 |
| P1 | 用量与连接状态透明 | CleanMyMac 费用反馈、AI 接入需求 | 显示本次请求估算与月度限额；连接失败有明确原因 |
| P2 | 应用卸载与遗留文件专题 | AppCleaner 优势与遗漏 | 独立功能设计，先证明关联判断和安全恢复能力再开放执行 |

P0 是正式接入真实文件操作前的门槛；P1 可以分阶段推出；P2 不纳入首版执行范围。以上优先级是本品的设计判断，不代表竞品质量排名。
