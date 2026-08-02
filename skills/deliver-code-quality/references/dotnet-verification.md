# .NET verification selection

Apply only layers relevant to the changed behavior, but require all configured layers in Full mode.

| Risk | Verification |
|---|---|
| Compile/API compatibility | Release build with warnings as errors |
| Business rules | xUnit, NUnit, or MSTest unit tests, including boundaries and negative cases |
| ASP.NET Core request pipeline | `WebApplicationFactory<TEntryPoint>` integration tests |
| SQL/Redis/broker behavior | Real disposable dependency, preferably Testcontainers |
| External HTTP service | Contract test or deterministic stub such as WireMock.Net |
| Serialization and public contracts | Golden contract/schema tests and compatibility checks |
| Concurrency/retry/idempotency | Deterministic integration tests with repeated/parallel calls |
| Security-sensitive change | Authorization-negative tests, secret scan, dependency audit, human review |

Coverage is diagnostic evidence, not proof of correctness. Never add assertions without behavioral value merely to reach a percentage.

Prefer repository-pinned SDK and package versions. Confirm unfamiliar APIs from installed packages or primary documentation before coding.
