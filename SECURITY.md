# Security policy

## Supported versions

Security fixes are provided for the latest published npm version and the current `main` branch.

## Reporting a vulnerability

Do not open a public Issue for credentials, arbitrary command execution, path traversal, approval bypass, evidence tampering, or supply-chain vulnerabilities. Use GitHub Private Vulnerability Reporting for this repository.

Include the affected version, reproduction steps, impact, and any suggested mitigation. Do not include real secrets or third-party data in the report.

## Supply-chain controls

- npm packages are built on GitHub-hosted runners from a GitHub Release commit.
- Release publication requires all package and workflow regressions to pass again.
- npm Trusted Publishing is preferred over long-lived tokens.
- Published packages include npm provenance when the repository and package are public.
