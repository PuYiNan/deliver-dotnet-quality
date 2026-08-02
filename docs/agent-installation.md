# Agent installation guide

## Prerequisites

- Node.js 20 or newer.
- PowerShell 7 available as `pwsh`.
- A repository with Git initialized before using the delivery workflow.

Check the environment without changing files:

```bash
npx -y deliver-code-quality@latest doctor --json
```

## Guided setup

For a human-operated terminal, omit `--agent` and `--yes` to receive prompts:

```bash
npx -y deliver-code-quality@latest setup
```

For an AI Agent or CI process, always select the destination and consent explicitly:

```bash
npx -y deliver-code-quality@latest setup --agent pi --repository . --yes --json
```

`setup` performs two operations:

1. Install or update the global Agent Skill with an atomic, timestamped backup.
2. Run repository bootstrap when `.ai-quality/config.json` is absent, otherwise run the safe upgrade tool.

## Agent destinations

| Value | Default global Skill root |
|---|---|
| `pi` | `~/.pi/agent/skills` |
| `codex` | `$CODEX_HOME/skills`, otherwise `~/.codex/skills` |
| `claude` | `$CLAUDE_CONFIG_DIR/skills`, otherwise `~/.claude/skills` |
| `agents` | `~/.agents/skills` |
| `all` | All four roots |

Use `--destination <skills-root>` with exactly one `--agent` for portable installs, tests, or nonstandard layouts.

Pi's global path follows its documented Agent Skills discovery directory: [Pi coding agent skills](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md#skills).

After installation, restart the Agent. Pi users may run `/reload`.

## Separate operations

Install only the global Skill:

```bash
npx -y deliver-code-quality@latest install-skill --agent pi --json
```

Initialize only the current repository:

```bash
npx -y deliver-code-quality@latest init .
```

Initialize a repository with explicit adapters:

```bash
npx -y deliver-code-quality@latest init . --adapters dotnet,node,python
```

Upgrade an existing repository:

```bash
npx -y deliver-code-quality@latest upgrade . --include-agent-instructions --json
```

Roll back a repository upgrade using the ID printed by the upgrade command:

```bash
npx -y deliver-code-quality@latest upgrade . --rollback 20260801-120000 --json
```

## Restore a global Skill backup

Every replacement reports a sibling directory named `deliver-dotnet-quality.backup-<timestamp>`. Restore it explicitly:

```bash
npx -y deliver-code-quality@latest restore-skill \
  --agent pi \
  --backup ~/.pi/agent/skills/deliver-dotnet-quality.backup-20260801-120000 \
  --json
```

The currently installed Skill is moved aside as `deliver-dotnet-quality.replaced-<timestamp>` instead of being deleted.

## Install from GitHub before an npm release

After the repository is public, npm can run the package directly from its GitHub source:

```bash
npx -y github:PuYiNan/deliver-code-quality doctor --json
npx -y github:PuYiNan/deliver-code-quality setup --agent pi --repository . --yes --json
```
