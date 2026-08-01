# Validation record

Validated on 2026-08-01 using Windows, PowerShell 7, Node.js 24, Python 3.12, and .NET SDK 10.0.302.

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
- Protocol v2 core executed without any hard-coded language command; all technology-specific commands came from protected adapters.
- An unknown technology stack failed before bootstrap wrote repository files; explicitly selecting the generic command adapter then bootstrapped successfully.
- A missing command executable produced a failed Full gate with the failed step, exit status, and log retained in evidence.
- A real xUnit project passed restore, format check, Release build with zero warnings, and one test through v1.x `legacy-dotnet` compatibility mode.
- A real polyglot fixture automatically detected Node and Python package roots and ran both as required adapters in one Full gate.
- The Node adapter passed lint, build, and one native `node:test` test.
- The Python adapter passed compileall and one `unittest` test without external dependencies.
- A required generic command adapter passed in the same polyglot Full gate.
- Schema-version-2 evidence contained common adapter, target, working-directory, command, exit-code, log, hash, and status fields.
- The Node/Python/command work item completed Requirements, Plan, Tests, Full verification, Delivery validation, and trusted acceptance end to end.
- Delivery validation rejected a deliberately changed required adapter implementation, then passed again after restoration.
- Changing trust metadata did not invalidate language-gate evidence because the fingerprint covers only verification-relevant configuration.
- The v1.x upgrade tool preserved config byte-for-byte, installed the new core/adapters, created a manifest, and restored both replaced and newly added files during rollback.
- Reference CI setup versions were checked against the current official GitHub Actions and Azure Pipelines task documentation.

## Not executed in this environment

- The updated Pi extension was syntax-checked but was not reloaded inside the user's already-running interactive Pi session; `/reload` is still required there.
- No product-specific Playwright, Appium, or FlaUI application was supplied. The UI gate intentionally fails UI-scoped work until a repository hook is configured.
- GitHub/Azure branch protection cannot be enabled from a portable template; repository administrators must configure the included CI check as required.
- The reference GitHub Actions and Azure Pipelines definitions were syntax-reviewed locally but not executed by their hosted services during this validation.
