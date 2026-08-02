# Release and npm publishing guide

## Release flow

1. Open an Issue with observable acceptance criteria.
2. Create a branch from `main`, implement the Issue, and use Conventional Commit messages.
3. Open a PR containing `Closes #<issue>` and wait for both Windows and Linux CI jobs.
4. Merge the feature PR. Release Please creates or updates a Release PR.
5. Review and merge the Release PR. The Release workflow creates the tag and GitHub Release, re-runs all checks, publishes npm, and uploads the tarball.

Use `feat:` for a SemVer minor release, `fix:` for a patch, and `feat!:` or another `!` type for a breaking major release.

## One-time GitHub configuration

1. Make the repository public after reviewing the repository and history for credentials or private data.
2. In repository Actions settings, allow GitHub Actions to create pull requests.
3. Keep workflow permissions restricted to the declarations in each workflow.
4. Optionally create a fine-grained `RELEASE_PLEASE_TOKEN` secret when Release Please PRs must trigger required PR workflows. Without it, GitHub suppresses workflows caused by the built-in token; publication tests still run inside `release.yml` before `npm publish`.

## First npm publication

The package name is `deliver-code-quality`. The first publication needs an npm owner because a Trusted Publisher cannot be attached until the package exists.

Recommended bootstrap:

1. Sign in with `npm login` and create a short-lived granular automation token limited to this package.
2. Store it without printing it:

   ```bash
   gh secret set NPM_TOKEN --repo PuYiNan/deliver-code-quality
   ```

3. Merge the first Release PR. `release.yml` publishes the package.
4. Configure npm Trusted Publisher for:
   - GitHub owner: `PuYiNan`
   - Repository: `deliver-dotnet-quality`
   - Workflow filename: `release.yml`
   - Allowed action: `npm publish`
5. Remove `NODE_AUTH_TOKEN` from the publish step so npm uses the GitHub OIDC identity. Keep the secret stored temporarily as a rollback credential, but do not inject it into `npm publish`.
6. Publish the next real release and verify the npm version, GitHub Actions run, and provenance before tightening access.
7. In npm package settings, select **Require two-factor authentication and disallow tokens**.
8. Remove the bootstrap token from GitHub and revoke it on npm:

   ```bash
   gh secret delete NPM_TOKEN --repo PuYiNan/deliver-code-quality
   ```

The workflow keeps `id-token: write`, uses a current npm 11 client, publishes without `NODE_AUTH_TOKEN`, and runs on a GitHub-hosted runner. npm then authenticates with short-lived OIDC credentials and generates provenance for the public package from the public repository. Do not delete the rollback secret until one OIDC release has succeeded.

References: [npm Trusted Publishing](https://docs.npmjs.com/trusted-publishers/) and [Release Please Action](https://github.com/googleapis/release-please-action).

## Failure behavior

- Version mismatch among `package.json`, `VERSION`, and the release tag stops publication.
- Any CLI, package, state-machine, upgrade, adapter, or PowerShell parsing failure stops publication.
- A failed publish does not rewrite the GitHub tag or silently mark npm as successful; fix authentication or package ownership and rerun the failed job.
