# Changelog

## 1.0.1 - 2026-08-01

- Fixed Delivery approval incorrectly failing when `Test-AiDelivery.ps1` succeeded in a fresh PowerShell process.
- Made `Test-AiDelivery.ps1` return an explicit success exit code.
- Replaced PowerShell-script success checks based on stale `$LASTEXITCODE` with `$?`-based command results.
- Made `aq.ps1` return deterministic success or failure for every subcommand.
- Added fresh-process regression coverage for Delivery approval and stale-exit-code handling.

## 1.0.0 - 2026-07-31

- Added the agent-neutral work-item state machine, approval hashes, .NET quality gate, UI hooks, CI examples, and Codex/Claude Code/Pi adapters.
