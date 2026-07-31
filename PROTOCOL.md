# Agent-neutral delivery protocol v1

This protocol defines behavior between any coding agent, a repository, a human approver, and CI. It does not define a model API or conversation format.

## Required repository interface

An implementation MUST provide:

- `aq.ps1`: stable command entry point;
- `.ai-quality/agent-policy.md`: always-on policy;
- `.ai-quality/active-work-item.txt`: active ID;
- `.ai-quality/work-items/<id>/state.json`: machine-readable state;
- specification, plan, test contract, approval, evidence, and delivery artifacts;
- a Full verification command with a non-zero failure exit code.

## CLI contract

```text
pwsh ./aq.ps1 new -Title <text> [-Id <id>] [-UiScope]
pwsh ./aq.ps1 status [-WorkItemId <id>] [-Json]
pwsh ./aq.ps1 approve -Stage <Requirements|Plan|Tests|Delivery> -WorkItemId <id> -ApprovedBy <human>
pwsh ./aq.ps1 verify -WorkItemId <id> -Mode <Quick|Full> [-Target <solution>]
pwsh ./aq.ps1 check-delivery -WorkItemId <id>
```

Commands MUST return non-zero when a transition, hash, test, evidence, or delivery assertion fails. Agents MUST surface that failure and MUST NOT translate it into a completion claim.

## State contract

```text
discovery
  -> requirements-approved
  -> plan-approved
  -> implementation-authorized
  -> verification-passed
  -> accepted

implementation-authorized -> verification-failed -> verification-passed
```

Product edits are allowed only in `implementation-authorized` and `verification-failed`. Artifact-specific edits are controlled by `Assert-AiEditAllowed.ps1`.

## Approval contract

Requirements, Plan, Tests, and Delivery approvals MUST originate outside the implementing agent's authority. Approval records bind the approved artifact SHA-256. Verification MUST fail if an approved artifact changes.

For protected repositories, approval authority SHOULD be a human PR reviewer or a service identity unavailable to the agent process. A local interactive approval is an ergonomic checkpoint, not a cryptographic security boundary.

## Evidence contract

A passing Full run MUST record:

- work-item ID and approved specification hash;
- exact target and mode;
- start and finish timestamps;
- each executed command, exit code, status, and log path;
- test-result artifacts;
- UI hook result when UI scope is true;
- overall result.

Delivery MUST be rejected when any acceptance criterion lacks PASS evidence, or when a required check is failed, skipped, unavailable, or unverified.

## Harness adapter contract

An adapter for Codex, Claude Code, Pi, or another harness SHOULD:

1. load the central policy at session start and after context compaction;
2. run `aq.ps1 status` before editing;
3. intercept direct file writes and call `Assert-AiEditAllowed.ps1` where the harness supports hooks;
4. prevent the implementing identity from creating approvals;
5. invoke only the common CLI for transitions and verification;
6. display CLI evidence and non-zero exits without rewriting their meaning.

Harness-specific hooks are defense in depth. Because an agent with unrestricted shell and repository permissions can bypass local files, branch protection and clean CI execution remain the final enforcement boundary.

## Strong local isolation profile

For high-risk work, run two separate agent sessions or sandboxes:

- Discovery/Planning: repository product files mounted read-only; only the active work-item draft artifacts are writable.
- Implementation: approved specification/plan/tests and workflow controls mounted read-only; product files writable; production credentials unavailable.

Then run Full verification in a clean CI identity that cannot be modified by the implementing agent.
