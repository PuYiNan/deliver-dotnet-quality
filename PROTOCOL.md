# Agent-neutral delivery protocol v2

This protocol defines behavior between any coding agent, a repository, a human approver, and CI. It does not define a model API or conversation format.

## Required repository interface

An implementation MUST provide:

- `aq.ps1`: stable command entry point;
- `.ai-quality/agent-policy.md`: always-on policy;
- `.ai-quality/active-work-item.txt`: active ID;
- `.ai-quality/work-items/<id>/state.json`: machine-readable state;
- specification, plan, test contract, approval, evidence, and delivery artifacts;
- a Full verification command with a non-zero failure exit code;
- one or more required gate adapters covering every affected technology stack.

## CLI contract

```text
pwsh ./aq.ps1 new -Title <text> [-Id <id>] [-UiScope]
pwsh ./aq.ps1 status [-WorkItemId <id>] [-Json]
pwsh ./aq.ps1 trust [-Enable -AuthorizedBy <human> | -Disable]
pwsh ./aq.ps1 approve -Stage <Requirements|Plan|Tests|Delivery> -WorkItemId <id> [-ApprovedBy <human>]
pwsh ./aq.ps1 verify -WorkItemId <id> -Mode <Quick|Full> [-Target <legacy-single-dotnet-target>]
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

Repositories MUST default to `approvalMode: manual`. Manual Requirements, Plan, Tests, and Delivery approvals MUST originate outside the implementing agent's authority. A user MAY explicitly enable `approvalMode: trusted` once for a repository; the implementing Agent may then create approvals only after deterministic readiness validation succeeds.

All approval records bind the approved artifact SHA-256. Verification MUST fail if an approved artifact changes. Trusted records MUST identify `approvalMode: trusted`, `approvalAuthority: implementing-agent`, and the user/time that enabled the mode; they MUST NOT impersonate an external reviewer.

For protected repositories, approval authority SHOULD be a human PR reviewer or a service identity unavailable to the agent process. A local interactive approval is an ergonomic checkpoint, not a cryptographic security boundary.

## Evidence contract

A passing Full run MUST record:

- work-item ID and approved specification hash;
- exact adapter IDs, types, required flags, targets, working directories, adapter implementation hashes, and mode;
- start and finish timestamps;
- each executed command, exit code, status, and log path;
- test-result artifacts;
- UI hook result when UI scope is true;
- overall result.

For schema-version-2 evidence, Delivery validation MUST reject a stale gate configuration, a changed required adapter implementation, a missing required adapter, or a required adapter whose status is not `Passed`.

Delivery MUST be rejected when any acceptance criterion lacks PASS evidence, or when a required check is failed, skipped, unavailable, or unverified.

## Gate adapter contract

The workflow core MUST NOT hard-code a language command. A gate adapter MUST resolve a technology-specific target into ordered executable steps containing:

- stable adapter and step IDs;
- executable file plus argument array, never an opaque shell command string;
- repository-contained working directory;
- target identity and required/optional status.

The core MUST execute and normalize every adapter into common evidence. All configured required adapters MUST pass before a Full gate can transition to `verification-passed`. Optional adapters may be skipped only with an explicit recorded reason.

Implementations SHOULD provide built-in .NET, Node.js, and Python adapters plus a reviewed command adapter for other toolchains. A polyglot repository composes adapters; it does not choose one language winner.

Workflow configuration and adapter implementations are protected controls. An implementing Agent MUST NOT weaken, delete, or replace them merely to make product changes pass.

## v1.x compatibility contract

If `gate.adapters` is absent or empty and the config contains the v1.x `solution` / `requireFormatCheck` fields, the resolver MUST create one implicit required .NET adapter and mark evidence as `legacy-dotnet`. Upgrade tooling MUST preserve the existing config, work items, evidence, templates, and hooks, create a rollback manifest, and allow restoration of every replaced or newly added workflow file.

## Harness adapter contract

An adapter for Codex, Claude Code, Pi, or another harness SHOULD:

1. load the central policy at session start and after context compaction;
2. run `aq.ps1 status` before editing;
3. intercept direct file writes and call `Assert-AiEditAllowed.ps1` where the harness supports hooks;
4. prevent the implementing identity from creating approvals in manual mode; in trusted mode, allow only the common CLI to create auditable automatic approvals;
5. invoke only the common CLI for transitions and verification;
6. display CLI evidence and non-zero exits without rewriting their meaning.

Harness-specific hooks are defense in depth. Because an agent with unrestricted shell and repository permissions can bypass local files, branch protection and clean CI execution remain the final enforcement boundary.

## Strong local isolation profile

For high-risk work, run two separate agent sessions or sandboxes:

- Discovery/Planning: repository product files mounted read-only; only the active work-item draft artifacts are writable.
- Implementation: approved specification/plan/tests and workflow controls mounted read-only; product files writable; production credentials unavailable.

Then run Full verification in a clean CI identity that cannot be modified by the implementing agent.
