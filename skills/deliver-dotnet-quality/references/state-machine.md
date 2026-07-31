# Workflow state machine

The active work item state is authoritative.

| State | Product edits | Required output | Exit authority |
|---|---:|---|---|
| `discovery` | No | Completed `spec.md` | Human requirements approval |
| `requirements-approved` | No | Completed `plan.md` and `test-matrix.md` | Human plan approval |
| `plan-approved` | No | Final executable test contract | Human tests approval |
| `implementation-authorized` | Yes | Code, tests, incremental evidence | Quality gate |
| `verification-passed` | No new scope | Full gate evidence and `delivery.md` | Human/PR acceptance |
| `verification-failed` | Fixes only | Failure evidence | Successful full gate |
| `accepted` | No | Archived evidence | Human/PR acceptance |

Allowed transitions:

`discovery -> requirements-approved -> plan-approved -> implementation-authorized -> verification-passed -> accepted`

`implementation-authorized -> verification-failed -> implementation-authorized`

Any material requirements change returns to `discovery`. Any material plan or test-contract change returns to `requirements-approved`.

An approval record must contain the work-item ID, stage, approver, timestamp, spec hash, and optional note. The implementing agent must not claim to be the approver.
