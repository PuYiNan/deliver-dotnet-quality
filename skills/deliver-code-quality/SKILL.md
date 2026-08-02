---
name: deliver-code-quality
description: Install, upgrade, and enforce an evidence-based, closed-loop software delivery workflow across .NET, Node.js/TypeScript, Python, custom toolchains, and polyglot repositories. Use for repository onboarding, feature work, bug fixes, refactoring, APIs, web UI, desktop UI, libraries, and services when an agent must understand requirements before editing, follow manual or explicitly trusted approvals, run every configured language adapter and UI gate, and deliver verifiable evidence instead of an unsupported completion claim.
---

# Deliver Code Quality

Treat repository files and executable checks as the source of truth. Never treat an agent's confidence as evidence.

## Start or resume a work item

1. Locate `.ai-quality/agent-policy.md` and read it completely.
2. Locate the active `.ai-quality/work-items/<id>/state.json`.
3. If no work item exists, run `.ai-quality/scripts/New-AiWorkItem.ps1` and stop in Discovery.
4. Read [state-machine.md](references/state-machine.md). Obey the allowed actions for the current state.
5. Read `approvalMode` from `pwsh ./aq.ps1 status`:
   - In `manual`, never create an approval on the user's behalf. Ask the user to run the approval command.
   - In `trusted`, self-approve the next stage only after the required artifact is complete and the CLI readiness checks pass. Never label an automatic approval as human review.

## Execute the workflow

### Discovery

- Inspect the repository without editing product code.
- Complete `spec.md`: objective, current behavior, desired behavior, user journeys, constraints, non-goals, risks, ambiguities, and acceptance criteria.
- Express each acceptance criterion as an observable outcome with an `AC-###` identifier.
- Stop if a material ambiguity changes behavior, data, security, compatibility, or scope.

### Planning

- Begin only after Requirements approval is recorded. In trusted mode, record it with the common CLI instead of pausing for the user.
- Complete `plan.md` and `test-matrix.md`.
- Map every planned change and test to at least one acceptance criterion.
- Prefer small vertical slices. Preserve unrelated user changes.
- Read [gate-adapters.md](references/gate-adapters.md). Confirm every affected technology stack has a required adapter before implementation.
- Read [dotnet-verification.md](references/dotnet-verification.md) for .NET scope, [language-verification.md](references/language-verification.md) for Node/Python/custom stacks, and [ui-verification.md](references/ui-verification.md) for user-visible behavior.

### Implementation

- Begin only when `state.json` is `implementation-authorized`.
- Implement one slice, run its narrowest relevant check, inspect the diff, then continue.
- Do not weaken, delete, skip, or rewrite an approved test merely to make it pass. If an approved expectation is wrong, return to Planning and request a new approval.
- Do not broaden scope silently.

### Verification

- Run `.ai-quality/scripts/Invoke-AiQualityGate.ps1 -WorkItemId <id> -Mode Full`.
- Require every configured required adapter to pass. In a polyglot repository, do not treat one stack's success as completion for another.
- Fix implementation failures and rerun the complete multi-adapter gate.
- If UI is in scope, collect screenshots/traces and run the configured UI hook. Do not substitute source inspection for executing the UI.
- Run `.ai-quality/scripts/Test-AiDelivery.ps1 -WorkItemId <id>` before reporting completion.

### Delivery

- Complete `delivery.md` using actual gate evidence.
- State incomplete when any required check is failed, skipped, unavailable, or unverified.
- Report acceptance-criterion status, commands executed, evidence paths, residual risks, and manual checks.
- In manual mode, the user, reviewer, or protected CI process decides acceptance. In trusted mode, the implementing agent may record Delivery acceptance only after the Full gate and delivery validator pass, and must report that independent review was not performed.

## Install repository controls

Prefer the published installer when Node.js and PowerShell 7 are available:

```bash
npx -y deliver-code-quality@latest setup --agent <pi|codex|claude|agents|all> --repository . --yes --json
```

Use `--json` for Agent-driven installation and retain every reported backup path. When the npm package is unavailable, run [bootstrap-repository.ps1](scripts/bootstrap-repository.ps1) from a reviewed local checkout. It detects .NET, Node, and Python roots and may configure more than one adapter. Never overwrite existing files unless the user explicitly approves `-Force`.

For a v1.x repository, run [upgrade-repository.ps1](scripts/upgrade-repository.ps1). Preserve its existing config and use `legacy-dotnet` compatibility until an explicit migration to `gate.adapters` is reviewed. Keep the printed rollback ID.

## Non-negotiable stop conditions

Stop and report the blocking state when:

- requirements or test expectations are materially ambiguous;
- the next state lacks the required approval and the active mode does not authorize the agent to create it;
- a required dependency or environment is unavailable;
- an affected language or package root lacks a required gate adapter;
- a quality gate fails after implementation attempts;
- UI evidence is required but the application cannot be executed;
- completion would require skipping or weakening a check.
