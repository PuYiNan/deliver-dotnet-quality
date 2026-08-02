# Changelog

## [2.1.1](https://github.com/PuYiNan/deliver-code-quality/compare/v2.1.0...v2.1.1) (2026-08-02)


### Bug Fixes

* **release:** publish through npm trusted publisher ([#7](https://github.com/PuYiNan/deliver-code-quality/issues/7)) ([6997832](https://github.com/PuYiNan/deliver-code-quality/commit/6997832859ea03eebd650469497edf8e3ac4b845))

## [2.1.0](https://github.com/PuYiNan/deliver-code-quality/compare/v2.0.0...v2.1.0) (2026-08-01)


### Features

* add one-command installer and automated releases ([33cdc9d](https://github.com/PuYiNan/deliver-code-quality/commit/33cdc9d10c033b064a7c10cc38b602fd39ebc152))

## 2.0.0 - 2026-08-01

- Extracted a language-neutral quality-gate orchestrator from the former hard-coded .NET gate.
- Added composable .NET, Node.js, Python, and generic command adapters with unified schema-version-2 evidence.
- Added automatic multi-stack detection during bootstrap and required-adapter support for polyglot repositories.
- Preserved v1.x `solution` / `requireFormatCheck` behavior through `legacy-dotnet` compatibility mode.
- Added an upgrade tool that preserves repository state and configuration, creates backups, and supports tested rollback.
- Hardened Delivery validation against changed gate configuration or adapter implementations.

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
