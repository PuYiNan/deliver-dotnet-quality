---
name: deliver-dotnet-quality
description: Enforce an evidence-based, closed-loop workflow for C# and .NET feature work, bug fixes, refactoring, APIs, web UI, and Windows desktop UI. Use when an agent must understand requirements before editing, obtain explicit stage approvals, implement in small slices, run deterministic quality gates, test user-visible behavior, and deliver verifiable evidence instead of an unsupported completion claim.
---

# Deliver .NET Quality

Treat repository files and executable checks as the source of truth. Never treat an agent's confidence as evidence.

## Start or resume a work item

1. Locate `.ai-quality/agent-policy.md` and read it completely.
2. Locate the active `.ai-quality/work-items/<id>/state.json`.
3. If no work item exists, run `.ai-quality/scripts/New-AiWorkItem.ps1` and stop in Discovery.
4. Read [state-machine.md](references/state-machine.md). Obey the allowed actions for the current state.
5. Never create an approval on the user's behalf. Ask the user to run or explicitly authorize the approval command.

## Execute the workflow

### Discovery

- Inspect the repository without editing product code.
- Complete `spec.md`: objective, current behavior, desired behavior, user journeys, constraints, non-goals, risks, ambiguities, and acceptance criteria.
- Express each acceptance criterion as an observable outcome with an `AC-###` identifier.
- Stop if a material ambiguity changes behavior, data, security, compatibility, or scope.

### Planning

- Begin only after Requirements approval is recorded.
- Complete `plan.md` and `test-matrix.md`.
- Map every planned change and test to at least one acceptance criterion.
- Prefer small vertical slices. Preserve unrelated user changes.
- Select the .NET and UI verification layers using [dotnet-verification.md](references/dotnet-verification.md) and [ui-verification.md](references/ui-verification.md).

### Implementation

- Begin only when `state.json` is `implementation-authorized`.
- Implement one slice, run its narrowest relevant check, inspect the diff, then continue.
- Do not weaken, delete, skip, or rewrite an approved test merely to make it pass. If an approved expectation is wrong, return to Planning and request a new approval.
- Do not broaden scope silently.

### Verification

- Run `.ai-quality/scripts/Invoke-AiQualityGate.ps1 -WorkItemId <id> -Mode Full`.
- Fix implementation failures and rerun the complete gate.
- If UI is in scope, collect screenshots/traces and run the configured UI hook. Do not substitute source inspection for executing the UI.
- Run `.ai-quality/scripts/Test-AiDelivery.ps1 -WorkItemId <id>` before reporting completion.

### Delivery

- Complete `delivery.md` using actual gate evidence.
- State incomplete when any required check is failed, skipped, unavailable, or unverified.
- Report acceptance-criterion status, commands executed, evidence paths, residual risks, and manual checks.
- The user, reviewer, or protected CI process decides acceptance; the implementing agent does not.

## Install repository controls

When a repository lacks `.ai-quality`, run [bootstrap-repository.ps1](scripts/bootstrap-repository.ps1) with the repository path. Never overwrite existing files unless the user explicitly approves `-Force`.

## Non-negotiable stop conditions

Stop and report the blocking state when:

- requirements or test expectations are materially ambiguous;
- the next state lacks the required approval;
- a required dependency or environment is unavailable;
- a quality gate fails after implementation attempts;
- UI evidence is required but the application cannot be executed;
- completion would require skipping or weakening a check.
