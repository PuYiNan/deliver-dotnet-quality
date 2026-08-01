---
name: deliver-dotnet-quality
description: Deliver software changes across .NET, Node, Python, custom stacks, and polyglot repositories through an approved specification, plan, test contract, executable multi-adapter Full gate, UI evidence when applicable, and recorded acceptance.
---

# Deliver code quality

Read `.ai-quality/agent-policy.md` and run `pwsh ./aq.ps1 status` before any edit.

Follow the state-reported allowed action exactly:

1. In `discovery`, inspect only and complete `spec.md`.
2. After Requirements approval, complete `plan.md` and `test-matrix.md`.
3. After Tests approval, implement small slices mapped to `AC-###` criteria and keep every affected technology stack in scope.
4. Run `pwsh ./aq.ps1 verify -WorkItemId <id> -Mode Full`; require every configured adapter to pass.
5. Complete `delivery.md`, then run `pwsh ./aq.ps1 check-delivery -WorkItemId <id>`.
6. In manual mode, never approve a stage for the user. In trusted mode, self-approve only through `aq.ps1` after readiness checks pass, and identify it as Agent approval. Never report complete without passing evidence.

If an expected check cannot run, report `INCOMPLETE` with the missing evidence.
