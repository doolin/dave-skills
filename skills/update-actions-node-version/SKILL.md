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
that targets the new Node version. Additionally, the runner injects
implicit actions (e.g. `actions/cache` for `setup-node`'s `cache:`
feature) that you can't pin directly.

Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` at the **workflow level** to
cover both explicit and runner-injected actions:

```yaml
name: My Workflow

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

on:
  push:
```

This is cleaner than adding the flag per-step, and catches implicit
dependencies like `actions/cache` that don't appear in your workflow
files.

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
- **Runner-injected actions.** `setup-node` with `cache: npm` causes
  the runner to inject `actions/cache` implicitly. You can't pin this
  in your workflow file — use the workflow-level
  `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` env var to cover it.

## Node 20 → 24 upgrade map

Verified working upgrades as of April 2026:

| Action | Old (Node 20) | New (Node 24) | SHA |
| --- | --- | --- | --- |
| `actions/checkout` | v4 | v5.0.0 | `08c6903cd8c0fde910a37f88322edcfb5dd907a8` |
| `actions/setup-node` | v4 | v6.3.0 | `53b83947a5a98c8d113130e565377fae1a50d02f` |
| `actions/upload-artifact` | v4 | v7.0.1 | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` |
| `actions/download-artifact` | v4 | v8.0.1 | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` |
| `actions/attest-build-provenance` | v2 | v4.1.0 | `a2bbfa25375fe432b6a289bc6b6cd05ecd0c4c32` |
| `aws-actions/configure-aws-credentials` | v4 | v6.1.0 | `ec61189d14ec14c8efccab744f656cffd0e33f37` |
| `gitleaks/gitleaks-action` | v2 (node20) | v2.3.9 + `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` | `ff98106e4c7b2bc287b24eaf42907196329070c7` |
| `hashicorp/setup-terraform` | v3 (node20) | v4.0.0 | `5e8dbf3c6d9deaf4193ca7a8fb23f2ac83bb6c85` |

Actions that already use Node 24 or composite (no update needed):

- `aquasecurity/trivy-action` — composite runner
- `anchore/sbom-action` v0.24.0 — Node 24

## Example commits

From CM02:

- `e59314d` — checkout v5, gitleaks v2.3.9 + step-level force flag
- `fe7ae23` — setup-node v6, upload-artifact v7, download-artifact v8,
  attest-build-provenance v4, configure-aws-credentials v6
- `d7a262e` — workflow-level `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24` to
  cover runner-injected `actions/cache`
