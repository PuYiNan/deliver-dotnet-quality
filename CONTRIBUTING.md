# Contributing

This repository uses an Issue-first, evidence-based delivery workflow.

## Development flow

1. Open an Issue that describes current behavior, desired behavior, non-goals, risks, and observable acceptance criteria.
2. Create a branch from the latest `main`. Use `feature/<topic>` or `fix/<topic>`.
3. Keep implementation, tests, documentation, and release-impact changes within the Issue scope.
4. Run `npm run ci` and all PowerShell regression suites before opening a PR.
5. Open a PR with `Closes #<issue>`, include executed checks, and wait for Windows and Linux CI.
6. Use a Conventional Commit title when squash-merging:
   - `feat:` for a backward-compatible feature.
   - `fix:` for a backward-compatible fix.
   - `feat!:` or another `!` type for a breaking change.
7. Do not publish from a feature branch. Release Please creates a separate Release PR after releasable commits reach `main`.
8. Merge the Release PR only after reviewing its version and changelog. The release workflow revalidates and publishes the exact npm artifact.

## Required local checks

```powershell
npm ci
npm run ci
pwsh ./tests/Invoke-WorkflowRegression.ps1
pwsh ./tests/Invoke-UpgradeRegression.ps1
pwsh ./tests/Invoke-AdapterRegression.ps1
```

Never weaken a workflow control, adapter, approved test, or evidence check merely to make a PR pass.
