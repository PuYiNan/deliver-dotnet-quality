# Workflow state machine

The active work item state is authoritative.

| State | Product edits | Required output | Exit authority |
|---|---:|---|---|
| `discovery` | No | Completed `spec.md` | Manual: human; Trusted: Agent after readiness checks |
| `requirements-approved` | No | Completed `plan.md` and `test-matrix.md` | Manual: human; Trusted: Agent after readiness checks |
| `plan-approved` | No | Final executable test contract | Manual: human; Trusted: Agent after readiness checks |
| `implementation-authorized` | Yes | Code, tests, incremental evidence | Quality gate |
| `verification-passed` | No new scope | Full gate evidence and `delivery.md` | Manual: human/PR; Trusted: Agent with limitation recorded |
| `verification-failed` | Fixes only | Failure evidence | Successful full gate |
| `accepted` | No | Archived evidence | Authority recorded in approval JSON |

Allowed transitions:

`discovery -> requirements-approved -> plan-approved -> implementation-authorized -> verification-passed -> accepted`

`implementation-authorized -> verification-failed -> implementation-authorized`

Any material requirements change returns to `discovery`. Any material plan or test-contract change returns to `requirements-approved`.

An approval record must contain the work-item ID, stage, approver, approval mode, authority, timestamp, artifact hash, and optional note. In manual mode the implementing agent must not approve. In trusted mode it may approve, but the record must use `approvalAuthority: implementing-agent` and must never impersonate a human reviewer.
