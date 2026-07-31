# Validation record

Validated on 2026-08-01 using Windows, PowerShell 7, Node.js, and .NET SDK 10.0.302.

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
- Manual mode remained the default, rejected approval without `-ApprovedBy`, and required the exact interactive confirmation phrase.
- Trusted mode required one explicit activation phrase and recorded the authorizer and activation time.
- Trusted Requirements, Plan, Tests, and Delivery approvals completed without repeated prompts only after deterministic readiness and delivery checks passed.
- Trusted approval JSON identified `approvalMode: trusted` and `approvalAuthority: implementing-agent` instead of impersonating the user.
- An incomplete trusted specification remained in `discovery`, while a complete three-stage flow reached `implementation-authorized` and opened product edits.
- `aq.ps1 trust -Disable` restored manual behavior.
- All PowerShell files parsed successfully, all bundled JSON parsed successfully, and the Pi TypeScript guard passed Node syntax validation.
- The Agent Skill passed the official skill structure validator.

## Not executed in this environment

- The updated Pi extension was syntax-checked but was not reloaded inside the user's already-running interactive Pi session; `/reload` is still required there.
- No product-specific Playwright, Appium, or FlaUI application was supplied. The UI gate intentionally fails UI-scoped work until a repository hook is configured.
- GitHub/Azure branch protection cannot be enabled from a portable template; repository administrators must configure the included CI check as required.
