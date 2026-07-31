# Changelog

## 1.1.0 - 2026-08-01

- Added an explicit repository-level trusted approval mode while preserving manual approval as the default.
- Allowed Agents in trusted mode to self-approve completed Requirements, Plan, Tests, and Delivery artifacts without repeated interactive prompts.
- Kept state-based edit protection, artifact hashes, Full verification, UI hooks, and delivery validation mandatory in both modes.
- Added deterministic readiness checks and auditable `implementing-agent` approval metadata for trusted approvals.
- Added `aq.ps1 trust` commands to inspect, enable, and disable trusted mode.

## 1.0.1 - 2026-08-01

- Fixed Delivery approval incorrectly failing when `Test-AiDelivery.ps1` succeeded in a fresh PowerShell process.
- Made `Test-AiDelivery.ps1` return an explicit success exit code.
- Replaced PowerShell-script success checks based on stale `$LASTEXITCODE` with `$?`-based command results.
- Made `aq.ps1` return deterministic success or failure for every subcommand.
- Added fresh-process regression coverage for Delivery approval and stale-exit-code handling.

## 1.0.0 - 2026-07-31

- Added the agent-neutral work-item state machine, approval hashes, .NET quality gate, UI hooks, CI examples, and Codex/Claude Code/Pi adapters.
