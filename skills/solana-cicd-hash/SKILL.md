---
name: solana-cicd-hash
description: Add CI/CD artifact attestation to any project. Collects pipeline output, zips it, SHA-256 hashes the archive, posts the hash as a JSON memo on Solana, generates a PDF attestation report, and uploads everything to S3.
disable-model-invocation: true
---

# CI/CD Hash Attestation on Solana

Create a tamper-proof, on-chain record that a CI/CD pipeline ran for a
specific commit and what it produced. Implemented in `scripts/attest.mjs`
(Node.js). Ruby variant in `dbb` uses `Ci::Attester` + `Database::SolanaAnchor`.

## How it works

1. Each CI check step writes output to a file with a commit-hash header
2. A separate `attest` job downloads all artifacts and zips them
3. SHA-256 the **zip archive** (not individual files)
4. Post a JSON memo to the Solana memo program via `@solana/web3.js`
5. Generate a PDF attestation report with `pdfkit`
6. Upload zip + PDF to S3

Solana and S3 steps are fault-tolerant -- failures are logged, CI continues.

## Pipeline structure

Two jobs in `.github/workflows/`:

- **`check`** (or named by tool: `markdown-lint`, `scan_ruby`, etc.) --
  runs CI steps, uploads artifact files with `retention-days: 90`
- **`attest`** -- runs on `main` push only, downloads all artifacts,
  runs `node scripts/attest.mjs`

## Key decisions

- **`printf '%s'` not `echo`** for the keypair -- `echo` adds a trailing
  newline that corrupts the JSON array
- **`chmod 600`** on the temp keypair file immediately after creation
- **`if: always()`** on keypair cleanup -- runs even when prior steps fail
- **OIDC for AWS** via `aws-actions/configure-aws-credentials` -- no
  static key/secret stored as secrets
- **`merge-multiple: true`** on `download-artifact` -- flattens all
  artifact directories into one
- **Attest job conditional** on `main` push -- no on-chain noise from PRs

## Pitfall: Memo program version

Solana has two Memo programs. **Always use Memo v2**
(`MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`). The v1 program
(`Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMMG`) no longer exists on
devnet and will fail with `ProgramAccountNotFound`. When hardcoding
the 32-byte public key, verify the base58 round-trips correctly --
a single wrong byte silently targets a nonexistent program.

## Pitfall: ARTIFACT_FILES drift

`scripts/attest.mjs` only zips files listed in `ARTIFACT_FILES`. If CI
adds a new `upload-artifact` step but `ARTIFACT_FILES` is not updated,
the attestation succeeds silently with an incomplete bundle. Treat
`ARTIFACT_FILES` as a manifest and keep it in sync with every
`upload-artifact` step in the workflow.

## Artifact capture pattern

Every check step prepends a commit-hash header to its output file:

```bash
set -o pipefail
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
{ echo "# commit: ${COMMIT_SHA}"; echo "---"; } > lint-results.txt
npx markdownlint-cli2 "**/*.md" 2>&1 | tee -a lint-results.txt
```

## Memo payload format

JSON object posted to the Solana memo program:

```json
{
  "s3_key": "repo/ci/2026/04/01/120000-abc1234/ci-artifacts.zip",
  "artifact_checksum": "sha256:<hex>",
  "commit": "<full-sha>",
  "timestamp": "2026-04-01T12:00:00.000Z"
}
```

`s3_key` makes the memo self-contained -- anyone with S3 access can
retrieve and re-verify the exact artifact bundle.

## Required secrets and variables

| Name | Type | Description |
| --- | --- | --- |
| `SOLANA_KEYPAIR` | Secret | 64-byte keypair as JSON array |
| `AWS_ROLE_ARN` | Secret | IAM role ARN for OIDC assume-role |
| `S3_COMPLIANCE_BUCKET` | Variable | S3 bucket name (empty = skip S3) |
| `AWS_REGION` | Variable | AWS region (default: `us-east-1`) |
| `SOLANA_NETWORK` | Variable | `devnet` or `mainnet-beta` (default: `devnet`) |

Set with: `gh secret set SOLANA_KEYPAIR < ~/.config/solana/keypair.json`

**S3 bucket prerequisite**: verify the target bucket has no lifecycle
rule that expires objects before 90 days. A 24-hour or 7-day expiry
(common for transient-output buckets) will silently destroy compliance
records. Check with `aws s3api get-bucket-lifecycle-configuration`.

## IAM role

The OIDC role trust condition:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:<owner>/<repo>:*"
}
```

Inline policy needs only `s3:PutObject` on the compliance bucket prefix.
See `form-terra/slacronym.tf` for the full Terraform pattern.

A role with `repo:*` trust (or `repo:<org>/*`) can serve multiple repos
without creating a new role per project. Prefer reusing an existing role
over proliferating roles when the bucket permissions are acceptable.

## Ruby variant

`dbb` implements the same pattern in Ruby:

- `app/utils/database/solana_anchor.rb` -- memo via `ed25519` + raw RPC
- `app/utils/ci/attester.rb` -- zip -> checksum -> memo -> PDF -> S3
- `lib/tasks/ci_attest.rake` -- entry point: `bundle exec rake ci:attest`

Memo format and S3 layout are identical to the Node.js version.

## Verification

1. Find the transaction on Solana Explorer (`?cluster=devnet` for devnet)
2. Extract `s3_key` and `artifact_checksum` from the memo JSON
3. Download the zip from S3 using the `s3_key`
4. `sha256sum ci-artifacts.zip` -- must match `artifact_checksum`
