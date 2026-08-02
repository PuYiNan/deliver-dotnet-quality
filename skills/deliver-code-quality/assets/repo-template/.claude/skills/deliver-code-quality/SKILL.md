---
name: deliver-code-quality
description: Deliver software changes across .NET, Node, Python, custom stacks, and polyglot repositories through an approved specification, plan, test contract, executable multi-adapter Full gate, UI evidence when applicable, and recorded acceptance.
---

# Deliver code quality

Read `.ai-quality/agent-policy.md` and run `pwsh ./aq.ps1 status` before any edit.

Obey the active state. Inspect and write the specification before Requirements approval; write the plan and test contract after approval; modify product code only after Tests approval. Require an adapter for every affected stack and run the complete multi-adapter Full gate. Fill `delivery.md` from actual evidence and validate it before acceptance. Never self-approve in manual mode. In trusted mode, self-approve only through `aq.ps1` after readiness checks pass and disclose that no independent review occurred. Never weaken a check, invent evidence, or claim completion for an unavailable stack.
