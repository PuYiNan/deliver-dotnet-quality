# AI Agent 高质量闭环工程套件（C#/.NET）

当前版本：`1.1.0`

这个套件把“先理解、再实现、用证据交付”变成与 Agent 厂商无关的仓库协议、CLI、状态机和 CI 门禁。Claude Code、Pi、Codex 只是协议的适配器；即使更换 Agent，任务状态、审批哈希、测试命令和证据格式都不变。

## 架构边界

```text
Claude Code ─┐
Pi Agent ────┼─> AGENTS/Skill/Hook 适配层 ─> aq.ps1 通用 CLI
Codex ───────┘                              │
                                             ├─ 状态机与审批哈希
                                             ├─ .NET/UI 质量门禁
                                             ├─ 证据与交付校验
                                             └─ CI + 人工合并审批（最终信任边界）
```

通用内核完全位于产品仓库的 `.ai-quality` 和 `aq.ps1` 中，不调用任何模型 API，也不依赖 Claude、Pi 或 Codex 的会话格式。

稳定的命令、状态、审批和证据接口见 [PROTOCOL.md](PROTOCOL.md)。未来接入新的 Agent，只需实现薄适配层，不需要复制业务工作流。

## 套件包含什么

- `aq.ps1`：所有 Agent 和人类使用的统一入口，支持 `new/status/trust/approve/verify/check-delivery`。
- `.ai-quality`：Agent 无关的工作项、状态机、审批、门禁和证据协议。
- `skills/deliver-dotnet-quality`：遵循 Agent Skills 目录结构的可移植技能包；Codex、Claude Code 和 Pi 可按各自目录加载。
- `AGENTS.md`、`CLAUDE.md`：启动时上下文适配。
- `.agents/skills`：Pi 和兼容 Agent Skills 的项目级技能适配。
- `.claude/skills` 与可选 PreToolUse Hook：Claude Code 适配。
- `.pi/extensions/ai-quality-guard.ts`：Pi 的写入前状态门禁。
- `.ai-quality/work-items/<id>`：每个需求的规格、计划、测试契约、审批、证据和交付报告。
- PowerShell 状态机：创建任务、人工审批、执行质量门禁、验证交付声明。
- .NET 门禁：Restore、格式检查、Release 构建、警告视为错误、全部测试。
- UI Hook：Web 可接 Playwright .NET；WPF/WinForms/WinUI 可接 Appium 或 FlaUI。
- GitHub Actions 和 Azure Pipelines 示例。

## 1. 安装到一个 .NET 仓库

从本套件目录执行：

```powershell
./skills/deliver-dotnet-quality/scripts/bootstrap-repository.ps1 -RepositoryPath 'D:\src\YourProduct'
```

脚本默认拒绝覆盖已有文件。已有规则需要合并时先审查，不要直接使用 `-Force`。

安装完成后，各 Agent 的使用方式如下：

| Agent | 自动读取 | 可选增强 | 通用执行入口 |
|---|---|---|---|
| Codex | `AGENTS.md` | 将可移植 skill 复制到 Codex skills 目录 | `pwsh ./aq.ps1 ...` |
| Claude Code | `CLAUDE.md`、`.claude/skills` | 合并 Claude PreToolUse Hook | `pwsh ./aq.ps1 ...` |
| Pi | `AGENTS.md`、`.agents/skills` | 信任项目后加载 `.pi/extensions` 写入门禁 | `pwsh ./aq.ps1 ...` |

Pi 启动后执行 `/trust`，重启或 `/reload`，即可加载项目技能和写入门禁。Claude Code 如需本地写入拦截，把 `.claude/settings.ai-quality.example.json` 中的 Hook 合并到现有 `.claude/settings.json`，不要覆盖已有 Hook。

Codex Skill 不是内核依赖；即使不安装 Skill，`AGENTS.md + aq.ps1 + CI` 仍然工作。

## 2. 创建真实任务

在产品仓库执行：

```powershell
pwsh ./aq.ps1 new -Title '管理员创建用户并处理重复邮箱'
```

有 UI 变更时增加 `-UiScope`。这会进入 `discovery` 状态，此时 Agent 只能检查代码并填写 `spec.md`，不能改产品代码。

## 3. 选择审批模式

默认是 `manual`，完全保留原有人工审批。需要让 Agent 自主推进时，由用户在仓库中做一次显式授权：

```powershell
pwsh ./aq.ps1 trust -Enable -AuthorizedBy '你的名字'
```

输入一次 `ENABLE TRUSTED MODE` 后，仓库进入 `trusted`。Agent 随后可以自行执行各阶段 `approve`，不再每一步等待人工输入；状态机、文档完整性检查、审批哈希、Full 门禁、UI Hook 和交付校验仍然强制执行。

随时查看或关闭：

```powershell
pwsh ./aq.ps1 trust
pwsh ./aq.ps1 trust -Disable
```

`trusted` 的审批记录会写入 `approvalAuthority: implementing-agent` 以及本次信任授权人和时间，绝不会伪装成人工评审。它适合个人项目和高频迭代；受保护分支仍建议保留独立 CI 与 PR 审核。

## 4. 批准需求

在 `manual` 中，审查 `.ai-quality/work-items/<id>/spec.md` 后由人类执行：

```powershell
pwsh ./aq.ps1 approve -Stage Requirements -WorkItemId '<id>' -ApprovedBy '你的名字'
```

在 `trusted` 中，Agent 完成规格并把状态改为 `READY`、勾选就绪清单后，直接执行下面的命令（不需要 `-ApprovedBy`，也不会弹人工确认）：

```powershell
pwsh ./aq.ps1 approve -Stage Requirements -WorkItemId '<id>'
```

两种模式都会记录规格文件 SHA-256。批准后再改规格会导致质量门禁失败。

## 5. 批准计划和测试契约

让 Agent 填写 `plan.md` 和 `test-matrix.md`。审查后依次执行：

```powershell
pwsh ./aq.ps1 approve -Stage Plan -WorkItemId '<id>' -ApprovedBy '你的名字'
pwsh ./aq.ps1 approve -Stage Tests -WorkItemId '<id>' -ApprovedBy '你的名字'
```

Tests 批准后状态才会进入 `implementation-authorized`，Agent 此时才能修改代码。

`trusted` 中省略 `-ApprovedBy` 即可自动审批；计划必须含 AC 映射，测试契约必须含 `T-### -> AC-###` 映射，否则自动审批会失败。

## 6. 配置项目专属验证

基础 .NET 验证无需配置。仓库有多个解决方案时，在 `.ai-quality/config.json` 填写 `solution`。

- 集成、安全、打包等项目检查：把 `hooks/full.ps1.example` 改名为 `full.ps1` 并填入实际命令。
- Web UI：复制 `examples/ui-playwright.ps1` 为 `hooks/ui.ps1`，填写 E2E 测试项目路径。
- Windows UI：复制 `examples/ui-windows.ps1` 为 `hooks/ui.ps1`，填写 Appium/FlaUI 测试项目路径。

如果任务标记为 UI 范围但没有可执行 UI Hook，Full 门禁会失败，不允许用“我检查过代码”代替 UI 测试。

## 7. 运行交付门禁

```powershell
pwsh ./aq.ps1 verify -WorkItemId '<id>' -Mode Full
```

门禁会验证三次审批后的文件哈希，并保存每一步的命令、退出码、日志、测试结果与 UI 证据。失败时状态变成 `verification-failed`；修复后必须重新运行完整门禁。

Agent 填完 `delivery.md` 后执行：

```powershell
pwsh ./aq.ps1 check-delivery -WorkItemId '<id>'
```

只有全部 AC 都有 PASS 证据、Full 门禁通过、交付报告没有 TODO/FAIL/UNVERIFIED 时验证才通过。`manual` 最终由人类批准：

```powershell
pwsh ./aq.ps1 approve -Stage Delivery -WorkItemId '<id>' -ApprovedBy '你的名字'
```

`trusted` 可由 Agent 省略 `-ApprovedBy` 执行同一命令，但交付结论必须说明未进行独立人工评审。

## 8. 建立真正不可绕过的硬门禁

AGENTS、Skills 和本地 Hook 解决的是“让 Agent 知道并尽量正确执行”；如果 Agent 拥有与你完全相同的文件和 Git 权限，它理论上仍可绕过或修改这些规则。真正不可绕过的边界必须放在 Agent 进程权限之外：

1. Agent 只能推送功能分支，不能直接推送受保护分支。
2. 将 `ai-quality-gate` 设置为合并前必需检查。
3. 启用至少一名人类审批和 Code Owner 审批。
4. Agent 使用独立凭据，不能批准自己的 PR，不能修改分支保护。
5. CI 从干净环境重新执行 Full 门禁并上传 evidence artifact。

`.github/CODEOWNERS.ai-quality.example` 提供了保护路径示例。Azure DevOps 用户可使用根目录的 `azure-pipelines-ai-quality.yml.example` 并配置对应的分支策略。

## 状态流

```text
discovery
  -> requirements-approved
  -> plan-approved
  -> implementation-authorized
  -> verification-passed
  -> accepted

验证失败：implementation-authorized -> verification-failed -> 重新验证
规格变化：任何后续状态 -> 重新进行需求/计划/测试审批
```

最重要的实践不是让 Agent 背会更多规则，而是让 Agent 每次工作都必须经过同一组外部可验证关卡。
