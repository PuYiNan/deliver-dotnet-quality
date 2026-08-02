# Language verification selection

## Node.js and TypeScript

- Use a committed package-manager lockfile and select npm or pnpm explicitly. The adapter fails closed without a lockfile unless dependencies are deliberately pre-provisioned with `skipInstall`.
- Require the package scripts that define the project's contract. At minimum require tests; for TypeScript applications normally require lint, typecheck, test, and build.
- Do not accept a missing package script as a skipped success. Add or correct the project check through a reviewed plan.
- Keep browser or Electron journeys in the UI hook so screenshots, traces, and environment details remain first-class evidence.

## Python

- Select `unittest` or `pytest` explicitly when repository conventions are clear.
- Use `installMode` deliberately: `requirements`, `editable`, `auto`, or `none` for dependency-free projects.
- Enable Ruff and mypy only when they are part of the approved repository contract; once required, never disable them to obtain green status.
- Keep virtual-environment and platform expectations in the test matrix.

## Other stacks

- Use the `command` adapter with argument arrays for Java, Go, Rust, native builds, packaging, security scans, and deployment validation.
- Include dependency restore, static checks, compilation/type checks, tests, and packaging checks appropriate to the stack.
- Prefer repository-owned wrapper executables such as Gradle Wrapper over ambient global tools.
- Split independent roots into separate required adapters. This preserves failure attribution and prevents one successful package from masking another.
