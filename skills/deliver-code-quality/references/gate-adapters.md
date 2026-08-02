# Gate adapter protocol

Keep the workflow core language-neutral. Configure one required adapter for every affected build or package root in `.ai-quality/config.json`.

## Selection rules

1. Prefer explicit `gate.adapters` configuration over automatic detection.
2. Treat each adapter `workingDirectory` as a repository-relative trust boundary.
3. Use stable unique IDs. Evidence qualifies every step as `<adapter-id>:<step>`.
4. Require all affected adapters. Use `required: false` only for genuinely optional environments and report any skip.
5. Never edit config or adapter scripts merely to make a failing implementation pass; they are workflow controls requiring reviewed changes.
6. Use the built-in `dotnet`, `node`, and `python` types where possible. Use `command` for Java, Go, Rust, packaging, security scans, or project-specific tools.

## Declarative example

```json
{
  "gate": {
    "adapters": [
      {
        "id": "api",
        "type": "dotnet",
        "workingDirectory": "services/api",
        "target": "Api.slnx",
        "required": true,
        "settings": { "requireFormatCheck": true }
      },
      {
        "id": "web",
        "type": "node",
        "workingDirectory": "apps/web",
        "target": "",
        "required": true,
        "settings": { "packageManager": "pnpm", "requiredScripts": ["lint", "test", "build"] }
      },
      {
        "id": "worker",
        "type": "python",
        "workingDirectory": "services/worker",
        "target": "pyproject.toml",
        "required": true,
        "settings": { "installMode": "editable", "testRunner": "pytest", "requireRuff": true }
      }
    ]
  }
}
```

## Command adapter

Put command steps in `settings.steps`. Use an executable plus argument array, not a shell command string. Limit steps by `modes` when needed.

```json
{
  "id": "go-service",
  "type": "command",
  "workingDirectory": "services/go",
  "required": true,
  "settings": {
    "steps": [
      { "name": "vet", "filePath": "go", "arguments": ["vet", "./..."], "modes": ["Full"] },
      { "name": "tests", "filePath": "go", "arguments": ["test", "./..."], "modes": ["Quick", "Full"] }
    ]
  }
}
```

The core records adapter type, target, required flag, adapter-script hash, commands, working directories, exit codes, logs, and common status in schema-version-2 evidence.

## Compatibility

When `gate.adapters` is absent or empty in a v1.x config, the resolver creates one implicit `dotnet` adapter from `solution` and `requireFormatCheck`. Migrate explicitly only after the generated plan matches existing behavior.
