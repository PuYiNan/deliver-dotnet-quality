# Validation record

Validated on 2026-07-31 using Windows, PowerShell 7, and .NET SDK 10.0.302.

## Passed checks

- Portable Agent Skill structure validation.
- PowerShell parser validation for every included `.ps1` file.
- JSON parsing for every included configuration file.
- Pi TypeScript extension syntax validation using Node type stripping.
- Bootstrap into a clean generated .NET repository.
- Unified `aq.ps1 new` and `aq.ps1 status` commands.
- Discovery-state edit guard: specification edit allowed; product and direct state edits blocked.
- Claude Code PreToolUse guard: allowed and blocked paths return the expected status.
- Human approval transitions for Requirements, Plan, and Tests.
- SHA-256 tamper test: a post-approval specification change blocked verification.
- Full .NET gate against a generated solution: restore, format check, Release build with zero warnings, and one xUnit test passed.
- Evidence generation: JSON, Markdown, logs, TRX, and latest-result pointers.
- Delivery validation negative test rejected TODO, missing PASS evidence, and INCOMPLETE status.
- Delivery validation positive test accepted a fully evidenced report while still requiring human acceptance.
- Fresh-process Delivery approval passed with `$LASTEXITCODE` initially unset.
- Unified CLI returned deterministic success despite a stale non-zero parent `$LASTEXITCODE`.
- Invalid delivery continued to return exit code `1`.

## Not executed in this environment

- A live Pi runtime was not installed, so its extension was syntax-checked against the documented `tool_call` API but not loaded in a Pi session.
- No product-specific Playwright, Appium, or FlaUI application was supplied. The UI gate intentionally fails UI-scoped work until a repository hook is configured.
- GitHub/Azure branch protection cannot be enabled from a portable template; repository administrators must configure the included CI check as required.
