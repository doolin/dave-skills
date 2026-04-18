---
name: solana-cicd-hash
description: Attest a CI/CD run on Solana. Zips CI artifacts, SHA-256s the archive, posts the hash as a JSON memo on Solana, generates a PDF attestation report, and uploads everything to S3.
disable-model-invocation: true
---

# CI/CD Hash Attestation on Solana

Create a tamper-proof, on-chain record that a CI/CD pipeline ran for a
specific commit and what it produced. The attestation runs as its own
GitHub Actions job after check/test jobs complete, on `main` pushes only.

For the broader pipeline shape (check / attest / deploy) and for CI
conventions outside this job, see the `inventium-cicd-pipeline` skill.

## When to use

Apply this skill when:

- Adding compliance/audit evidence to a new repo.
- A repo has the attestation inlined into a check job and needs it
  split into its own job (so it doesn't run on PRs or block on check
  failures).
- The attest script or memo format needs updating across repos.

## What ships with the skill

- `scripts/attest.mjs` — Node implementation (canonical).
- `scripts/attest.rb` — standalone Ruby implementation.
- `workflow/attest-job.yml` — drop-in `attest` job for `.github/workflows/ci.yml`.

For Rails projects, the Ruby implementation can be adapted into
`Ci::Attester` + `Database::SolanaAnchor` classes; see `dbb` for a
reference implementation.

## Quick start: add to a repo

1. Copy `scripts/attest.mjs` (or `scripts/attest.rb`) from this skill into
   the target repo at `scripts/attest.mjs`.
2. For Node: add `@solana/web3.js`, `archiver`, and `pdfkit` to `package.json`.
   For Ruby: add `ed25519` to `Gemfile`.
3. Copy `workflow/attest-job.yml` into `.github/workflows/ci.yml` as a
   new job. Replace `<check-jobs>` in `needs:` with the actual check job
   id(s).
4. Set repo secrets:
   - `SOLANA_KEYPAIR` — 64-byte keypair as JSON array.
   - `AWS_ROLE_ARN` — IAM role ARN for OIDC assume-role.
5. Set repo variables:
   - `S3_COMPLIANCE_BUCKET` — target bucket (unset → skip S3, keep Solana + PDF).
   - `EVIDENCE_BUNDLE` — S3 key prefix root, e.g. `<repo>/ci` (optional;
     unset → auto-derive from `GITHUB_REPOSITORY`).
   - `AWS_REGION` — default `us-east-1`.
   - `SOLANA_NETWORK` — `devnet` or `mainnet-beta` (default `devnet`).
6. Push to `main` and verify the Solana transaction on Solana Explorer,
   then confirm the zip hash matches the memo (see Verification below).

Set the keypair secret with:

```bash
gh secret set SOLANA_KEYPAIR < ~/.config/solana/keypair.json
```

## Attest job shape

Three invariants the job must preserve (see `workflow/attest-job.yml`
for the full, copy-paste-ready version):

1. `needs: [<check-jobs>]` — attest runs after check, not alongside.
2. `if: github.ref == 'refs/heads/main' && github.event_name == 'push'` —
   no on-chain noise from PRs, no wasted Solana fees.
3. `permissions: { id-token: write, contents: read }` — required for
   OIDC assume-role.

The job downloads every artifact uploaded by check jobs
(`merge-multiple: true`), then runs `node scripts/attest.mjs`.

## S3 layout

The script derives the S3 key as:

```text
s3://<S3_COMPLIANCE_BUCKET>/<prefix>/YYYY/MM/DD/HHMMSS-<shortsha>/ci-artifacts.zip
```

Where `<prefix>` is:

- `EVIDENCE_BUNDLE` env var if set (e.g. `slacronym/ci`); or
- `<repo>/ci` derived from `GITHUB_REPOSITORY` as a fallback.

Set `EVIDENCE_BUNDLE` in repo variables when the target bucket
enforces a specific prefix layout (e.g. a shared compliance bucket
with per-repo IAM policies). Leave it unset for ad-hoc buckets; the
fallback produces a sensible `<repo>/ci/...` key by default.

## Memo payload format

JSON posted to the Solana Memo v2 program:

```json
{
  "s3_key": "slacronym/ci/2026/04/17/120000-abc1234/ci-artifacts.zip",
  "artifact_checksum": "sha256:<hex>",
  "commit": "<full-sha>",
  "timestamp": "2026-04-17T12:00:00.000Z"
}
```

`s3_key` makes the memo self-contained: anyone with S3 access can
retrieve and re-verify the exact artifact bundle from the on-chain
record alone.

## IAM role

The attest job's OIDC role needs one inline policy, scoped to the
evidence bundle prefix only:

```json
{
  "Effect": "Allow",
  "Action": ["s3:PutObject"],
  "Resource": "arn:aws:s3:::<bucket>/<evidence-bundle>/*"
}
```

Trust condition scoped to the specific repo:

```json
"StringLike": {
  "token.actions.githubusercontent.com:sub": "repo:<owner>/<repo>:*"
}
```

## Required secrets and variables

| Name | Type | Description |
| --- | --- | --- |
| `SOLANA_KEYPAIR` | Secret | 64-byte keypair as JSON array |
| `AWS_ROLE_ARN` | Secret | IAM role ARN for OIDC assume-role |
| `S3_COMPLIANCE_BUCKET` | Variable | S3 bucket (unset → skip S3) |
| `EVIDENCE_BUNDLE` | Variable | S3 key prefix root (optional) |
| `AWS_REGION` | Variable | Default `us-east-1` |
| `SOLANA_NETWORK` | Variable | `devnet` or `mainnet-beta` (default `devnet`) |

## Pitfall: Memo program version

Solana has two Memo programs. Always use **Memo v2**
(`MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr`). Memo v1
(`Memo1UhkJRfHyvLMcVucJwxXeuD728EqVDDwQDxFMMG`) no longer exists on
devnet and will fail with `ProgramAccountNotFound`. When hardcoding
the 32-byte public key (as the Ruby variant does), verify the base58
round-trips correctly — a single wrong byte silently targets a
nonexistent program.

## Pitfall: keypair corruption from `echo`

Use `printf '%s'` to write `$SOLANA_KEYPAIR` to the temp file:

```bash
printf '%s' "$SOLANA_KEYPAIR" > "$KEYPAIR_FILE"
chmod 600 "$KEYPAIR_FILE"
```

`echo` appends a trailing newline that breaks JSON-array parsing —
the error surfaces as `Keypair must be a 64-byte JSON array` or as an
opaque ed25519 error, depending on the variant.

The cleanup step must run under `if: always()` so the temp file is
removed even when prior steps fail. `chmod 600` must run immediately
after creation, not after the attest script, to avoid leaving the
keypair world-readable during execution.

## Pitfall: `ARTIFACT_FILES` drift

If `ARTIFACT_FILES` is set (comma-separated manifest), only those
files are included in the zip. If CI adds a new `upload-artifact`
step but `ARTIFACT_FILES` is not updated, the attestation succeeds
silently with an incomplete bundle.

When `ARTIFACT_FILES` is unset, the script includes every regular
file in `ARTIFACT_DIR`. This is the safer default unless you need to
exclude a file that arrives in the artifact directory.

Treat `ARTIFACT_FILES` as a manifest: keep it in sync with every
`upload-artifact` step in the workflow, or leave it unset.

## Pitfall: S3 lifecycle expires compliance records

Before using a bucket for attestation, verify it has no lifecycle
rule that expires objects early:

```bash
aws s3api get-bucket-lifecycle-configuration --bucket <bucket>
```

A 24-hour or 7-day expiry (common on transient-output buckets) will
silently destroy compliance records. Compliance buckets should either
have no expiration, or transition to Glacier IR after a long retention
period.

## Verification

To verify any past attestation from the on-chain record alone:

1. Find the transaction on Solana Explorer (add `?cluster=devnet` for
   devnet). The attest script prints a direct link when Solana
   submission succeeds.
2. Extract `s3_key` and `artifact_checksum` from the memo JSON.
3. Download the zip from S3 using the `s3_key`.
4. `sha256sum ci-artifacts.zip` — must match `artifact_checksum`.
