# Issues

## ISSUE-001: Delivery approval misread successful validation

- Status: Fixed in 1.0.1
- Reported: 2026-08-01
- Incident note: `03-工作项目/deliver-code-quality技能包/故障-2026-08-01-Test-AiDelivery退出码误判.md`

### Symptom

`Approve-AiStage.ps1 -Stage Delivery` reported `Delivery validation failed` even though `Test-AiDelivery.ps1` printed a passing result.

### Root cause

The approval script checked `$LASTEXITCODE`, which is intended for native commands or scripts that explicitly call `exit`. A successful PowerShell script left the value `$null` or stale, so `$LASTEXITCODE -ne 0` could incorrectly evaluate to true.

### Resolution

- `Test-AiDelivery.ps1` now exits explicitly with `0` on success.
- `Approve-AiStage.ps1` checks `$?` immediately after invoking the PowerShell validation script.
- `aq.ps1` captures `$?` per subcommand and exits deterministically with `0` or `1` instead of forwarding stale `$LASTEXITCODE` state.

### Verification

- Fresh-process Delivery approval succeeds without pre-initializing `$LASTEXITCODE`.
- Invalid delivery still returns exit code `1`.
- `aq.ps1 status` returns `0` even when the parent PowerShell process previously held a non-zero native exit code.
