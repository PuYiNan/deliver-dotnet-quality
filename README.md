# AI Agent 高质量闭环工程套件（语言无关内核）

当前版本：`2.0.0` <!-- x-release-please-version -->

[![CI](https://github.com/PuYiNan/deliver-dotnet-quality/actions/workflows/ci.yml/badge.svg)](https://github.com/PuYiNan/deliver-dotnet-quality/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/deliver-code-quality.svg)](https://www.npmjs.com/package/deliver-code-quality)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

这个套件把“先理解、再实现、用证据交付”变成与 Agent 厂商无关的仓库协议、CLI、状态机和 CI 门禁。Claude Code、Pi、Codex 只是协议的适配器；即使更换 Agent，任务状态、审批哈希、测试命令和证据格式都不变。

## 架构边界

```text
Claude Code ─┐
Pi Agent ────┼─> AGENTS/Skill/Hook 适配层 ─> aq.ps1 通用 CLI
Codex ───────┘                              │
                                             ├─ 状态机与审批哈希
                                             ├─ 多语言 Gate Adapter + UI 门禁
                                             ├─ 证据与交付校验
                                             └─ CI + 人工合并审批（最终信任边界）
```

通用内核完全位于产品仓库的 `.ai-quality` 和 `aq.ps1` 中，不调用任何模型 API，也不依赖 Claude、Pi 或 Codex 的会话格式。

稳定的命令、状态、审批和证据接口见 [PROTOCOL.md](PROTOCOL.md)。未来接入新的 Agent，只需实现薄适配层，不需要复制业务工作流。

## 套件包含什么

- `aq.ps1`：所有 Agent 和人类使用的统一入口，支持 `new/status/trust/approve/verify/check-delivery`。
- `.ai-quality`：Agent 无关的工作项、状态机、审批、门禁和证据协议。
- `skills/deliver-dotnet-quality`：为兼容现有安装保留名称的可移植技能包；能力已覆盖 .NET、Node、Python、自定义工具链和多语言仓库。
- `AGENTS.md`、`CLAUDE.md`：启动时上下文适配。
- `.agents/skills`：Pi 和兼容 Agent Skills 的项目级技能适配。
- `.claude/skills` 与可选 PreToolUse Hook：Claude Code 适配。
- `.pi/extensions/ai-quality-guard.ts`：Pi 的写入前状态门禁。
- `.ai-quality/work-items/<id>`：每个需求的规格、计划、测试契约、审批、证据和交付报告。
- PowerShell 状态机：创建任务、人工审批、执行质量门禁、验证交付声明。
- Gate Adapter：内置 .NET、Node.js、Python 和通用命令适配器，可在同一 Monorepo 组合执行。
- 统一证据：不同语言都输出适配器、目标、命令、工作目录、退出码、日志与状态。
- UI Hook：可接 Playwright、Appium、FlaUI 或项目自己的端到端脚本。
- GitHub Actions 和 Azure Pipelines 示例。

## 60 秒安装

要求：Node.js 20+ 和 PowerShell 7（`pwsh`）。下面一条命令会安装指定 Agent 的全局 Skill，并在当前仓库不存在工作流时执行初始化、已经存在时执行安全升级：

```bash
npx -y deliver-code-quality@latest setup --agent pi --repository . --yes
```

把 `pi` 换成 `codex`、`claude`、`agents` 或 `all` 即可安装到其他 Agent。安装器会在替换旧 Skill 前创建时间戳备份；项目升级继续保留原有配置、工作项、证据和 Hook。

公共 npm 首次发布前，可在仓库公开后直接从 GitHub 运行同一个 CLI：

```bash
npx -y github:PuYiNan/deliver-dotnet-quality setup --agent pi --repository . --yes
```

需要长期使用命令时，也可以全局安装：

```bash
npm install --global deliver-code-quality
deliver-quality setup --agent pi --repository . --yes
```

只检查环境，不写文件：

```bash
npx -y deliver-code-quality@latest doctor --json
npx -y deliver-code-quality@latest install-skill --agent pi --dry-run --json
```

适合 AI Agent 的确定性安装命令始终使用 `--yes --json`，不要让 Agent 猜测交互式问题：

```bash
npx -y deliver-code-quality@latest setup \
  --agent all \
  --repository . \
  --yes \
  --json
```

详细的全局路径、恢复和离线安装方式见 [Agent 安装指南](docs/agent-installation.md)。

## 1. 安装到源码仓库

推荐使用 npm CLI：

```bash
npx -y deliver-code-quality@latest init 'D:\src\YourProduct'
```

也可以从本套件源码目录执行底层脚本：

```powershell
./skills/deliver-dotnet-quality/scripts/bootstrap-repository.ps1 -RepositoryPath 'D:\src\YourProduct'
```

脚本会检测 `.sln/.csproj`、`package.json`、`pyproject.toml/requirements.txt`，并为每个发现的技术栈生成适配器。也可显式指定：

```powershell
./skills/deliver-dotnet-quality/scripts/bootstrap-repository.ps1 `
  -RepositoryPath 'D:\src\YourProduct' `
  -Adapters dotnet,node,python
```

Java、Go、Rust 或其他未内置识别的仓库可先使用 `-Adapters command`，然后在受评审的配置中填写实际步骤；空的 command adapter 不会通过 Full Gate。

脚本默认拒绝覆盖已有文件。已有规则需要合并时使用升级脚本，不要直接对正式仓库使用 `-Force`。

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

## 6. 配置语言与项目验证

`.ai-quality/config.json` 的 `gate.adapters` 是语言无关边界。每个受影响的解决方案、包或服务都应有一个 `required: true` 的适配器：

```json
{
  "gate": {
    "adapters": [
      {
        "id": "api",
        "type": "dotnet",
        "workingDirectory": "services/api",
        "target": "Api.slnx",
        "required": true,
        "settings": { "requireFormatCheck": true }
      },
      {
        "id": "web",
        "type": "node",
        "workingDirectory": "apps/web",
        "target": "",
        "required": true,
        "settings": { "packageManager": "pnpm", "requiredScripts": ["lint", "test", "build"] }
      }
    ]
  }
}
```

- `dotnet`：Restore、可选格式检查、Release Build（警告视为错误）和测试/TRX。
- `node`：使用 npm 或 pnpm 锁文件确定性安装，并执行配置的 lint/typecheck/build/test scripts；没有锁文件时默认失败而不是改写依赖。
- `python`：可选依赖安装、compileall、unittest/pytest，以及可选 Ruff/mypy。
- `command`：用“可执行文件 + 参数数组”接入 Java、Go、Rust、打包、安全扫描等任意工具链。

适配器、配置和质量脚本属于工作流控制文件，不能为了让实现通过而临时删减检查。

- 集成、安全、打包等跨栈检查：把 `hooks/full.ps1.example` 改名为 `full.ps1` 并填入实际命令。
- Web UI：.NET 可改造 `examples/ui-playwright.ps1`，Node 可改造 `examples/ui-playwright-node.ps1`，复制为 `hooks/ui.ps1` 后填写真实 E2E 路径。
- Windows UI：复制 `examples/ui-windows.ps1` 为 `hooks/ui.ps1`，填写 Appium/FlaUI 测试项目路径。

如果任务标记为 UI 范围但没有可执行 UI Hook，Full 门禁会失败，不允许用“我检查过代码”代替 UI 测试。

## 7. 运行交付门禁

```powershell
pwsh ./aq.ps1 verify -WorkItemId '<id>' -Mode Full
```

门禁会验证三次审批后的文件哈希，并保存每个适配器及步骤的类型、目标、命令、工作目录、退出码、日志、测试结果与 UI 证据。任一必需适配器失败时状态变成 `verification-failed`；修复后必须重新运行完整门禁。

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

## 9. 升级 v1.x .NET 仓库

v1.x 的 `solution` 与 `requireFormatCheck` 配置仍受支持，运行时会标记为 `legacy-dotnet`。升级脚本只替换公共 CLI、核心脚本和适配器，保留配置、工作项、证据、模板和 Hook，并生成可回滚备份：

```powershell
./skills/deliver-dotnet-quality/scripts/upgrade-repository.ps1 `
  -RepositoryPath 'D:\src\ExistingProduct'
```

需要同步项目级 Agent 指令时，审查后增加 `-IncludeAgentInstructions`。脚本会输出备份 ID；使用同一脚本的 `-Rollback '<backup-id>'` 可恢复被替换文件。确认兼容模式 Full Gate 通过后，再单独评审是否迁移为显式 `gate.adapters`。

npm CLI 的等价命令是：

```bash
npx -y deliver-code-quality@latest upgrade . --include-agent-instructions
npx -y deliver-code-quality@latest upgrade . --rollback '<backup-id>'
```

## 自动构建与发布

- 每个 PR 和 `main` 推送都会在 Windows、Linux 上执行 CLI、npm tarball、状态机、升级回滚和真实多语言适配器回归。
- Conventional Commit 合入 `main` 后，Release Please 自动创建或更新 Release PR。
- Release PR 合并后，流水线重新验证版本和全部测试，创建 GitHub Release、发布公共 npm 包，并上传相同的 `.tgz` 构件。
- npm 发布优先使用 GitHub Actions OIDC Trusted Publisher，不在仓库中保存长期 token。

仓库管理员只需完成一次 npm 身份引导和 GitHub Actions 权限设置，详见 [发布指南](docs/releasing.md)。

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
