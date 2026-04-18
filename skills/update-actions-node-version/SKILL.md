---
name: update-actions-node-version
description: Update GitHub Actions to newer Node.js versions when deprecation warnings appear. Covers pinned SHA upgrades, FORCE_JAVASCRIPT_ACTIONS_TO_NODE24 workaround for actions that haven't released Node 24 builds yet.
disable-model-invocation: true
---

# Update Actions Node Version

Fix GitHub Actions Node.js deprecation warnings by upgrading action
versions and, where necessary, forcing the runner to use a newer Node.

## When to use

GitHub emits warnings like:

> Node.js 20 actions are deprecated. The following actions are running
> on Node.js 20 and may not work as expected: actions/checkout@…

This skill covers the resolution pattern.

## Process

### 1. Identify affected actions

The warning lists specific action references (org/action@sha). Grep
the workflow files to find every occurrence:

```bash
grep -rn 'actions/checkout@<old-sha>' .github/workflows/
grep -rn 'gitleaks/gitleaks-action@<old-sha>' .github/workflows/
```

### 2. Check for upgraded releases

For each affected action, check whether a new major or minor version
exists that natively uses the target Node version:

```bash
# Get the SHA for a specific tag
gh api repos/<owner>/<action>/git/ref/tags/<tag> --jq '.object.sha'

# Check what Node version an action uses
gh api repos/<owner>/<action>/contents/action.yml --jq '.content' \
  | base64 -d | grep -i 'using:'
```

If a new major version exists (e.g. `actions/checkout` v4 → v5 for
Node 24), upgrade to it. Use the full 40-character SHA pin, not a tag
reference.

### 3. Force Node version for lagging actions

Some actions (e.g. `gitleaks/gitleaks-action`) may not have a release
that targets the new Node version. In that case:

1. Update to the latest available release SHA.
2. Add the force environment variable to that step:

```yaml
- uses: gitleaks/gitleaks-action@<latest-sha> # v2.3.9
  env:
    GITHUB_TOKEN: ${{ github.token }}
    FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true
```

This tells the runner to execute the action under Node 24 even though
its `action.yml` declares an older version.

### 4. Replace all occurrences

Actions like `actions/checkout` typically appear in every job. Use
replace-all to update every occurrence in both workflow files and
reusable workflows.

## Reference: Node.js deprecation timeline (2026)

| Date | Event |
| --- | --- |
| June 2, 2026 | Node 24 becomes default; Node 20 actions get forced to Node 24 |
| September 16, 2026 | Node 20 removed from runners entirely |

After June 2, `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` becomes
unnecessary — remove it in a follow-up cleanup.

## Temporary opt-out

If an action breaks under Node 24, you can temporarily revert with:

```yaml
env:
  ACTIONS_ALLOW_USE_UNSECURE_NODE_VERSION: true
```

This is a stopgap only — it will stop working September 16, 2026.

## Pitfalls

- **Runner version requirements.** Major version bumps (e.g. checkout
  v5) may require a minimum runner version. `ubuntu-latest` generally
  includes it, but self-hosted runners may not.
- **Don't use tag references.** Always pin to the full SHA. Tags can
  be force-pushed; SHAs cannot.
- **Annotated vs lightweight tags.** `gh api repos/.../git/ref/tags/v5`
  may return a tag object SHA, not a commit SHA. If the object type is
  `tag`, dereference it: `gh api repos/.../git/tags/<sha> --jq '.object.sha'`.
  Lightweight tags point directly to the commit.

## Example commit

From CM02 (`e59314d`):

- `actions/checkout` v4 → v5.0.0 (`08c6903...`)
- `gitleaks/gitleaks-action` old v2 → v2.3.9 (`ff98106...`) + `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`

Applied across `golden-pipeline.yml` (6 checkout refs, 1 gitleaks ref)
and `ci-cd.yml` (2 checkout refs).
