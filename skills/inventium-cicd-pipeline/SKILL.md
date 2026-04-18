---
name: inventium-cicd-pipeline
description: House CI/CD pipeline shape used across Inventium repos (check / attest / deploy). Captures the conventions an agent needs when adding a new repo to the pipeline or standardizing an existing one.
disable-model-invocation: true
---

# Inventium CI/CD Pipeline

Three-phase GitHub Actions pipeline used across Inventium repos. This
skill is a rough draft preserving development-earned conventions;
polish it further when rolling out the next repo.

For the Solana attestation job specifically, see the
`solana-cicd-hash` skill — that job is one phase of this pipeline.

## Three phases

1. **check** — runs on every push and PR. Tests, lint, format, audits,
   security scans. Parallel jobs where possible. Each check uploads its
   results as artifacts (`retention-days: 90`).
2. **attest** — runs on `main`/`master` push only, `needs:` all check
   jobs. Downloads every artifact, zips, hashes, anchors the hash on
   Solana, uploads to S3. See `solana-cicd-hash`.
3. **deploy** — runs on `main`/`master` push only, `needs: [check]`
   (not `attest` — deploys shouldn't block on on-chain confirmation).

```text
on: push, pull_request

check (parallel jobs) ──► attest (main push only)
                    └──► deploy (main push only)
```

## Decision tree

- New repo joining the pipeline → apply all three phases.
- Existing repo with attestation inlined into a check job (slacronym,
  baa-or-not pattern) → refactor attest into its own job (see
  `solana-cicd-hash`), preserve the check phase as-is.
- Existing repo missing attestation → add only the attest phase.

## Check phase: artifact capture pattern

Every check step that emits results for compliance writes a file with
a commit-hash header, then uploads it as an artifact. This pattern
lets the attest job reconstruct *what ran for what commit*, months
later, from the zipped bundle alone.

```bash
set -o pipefail
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
{ echo "# commit: ${COMMIT_SHA}"; echo "---"; } > lint-results.txt
npx markdownlint-cli2 "**/*.md" 2>&1 | tee -a lint-results.txt
```

Upload each output:

```yaml
- name: Upload lint artifact
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: lint-results
    path: lint-results.txt
    retention-days: 90
```

Tool-native outputs (Brakeman JSON, RuboCop JSON, SBOM CycloneDX) can
skip the header; they carry enough metadata internally.

## Attest phase

A single job, `attest`, with `needs:` covering every check job,
gated on `main` push. The job is implemented by the
`solana-cicd-hash` skill. Keep it in its own job: inlining it into a
check job runs it on PRs, couples it to unrelated check failures, and
burns Solana fees on throwaway branches.

## Deploy phase

Separate job, also gated on `main` push, also `needs: [check]`. Does
not depend on `attest` — a green check phase should be sufficient to
ship; Solana/S3 flakiness must not block deploys.

Where language/framework supports it, add
`actions/attest-build-provenance` on the deploy zip for SLSA provenance
as a companion to (not replacement for) the Solana attestation.

## Conventions

- **Workflow location:** `.github/workflows/ci.yml`.
- **Permissions at the workflow level:**
  `{ contents: read, id-token: write }`. Add
  `attestations: write` only when using
  `actions/attest-build-provenance`.
- **`if:` guards over `continue-on-error`.** Optional steps (S3 upload
  when `S3_COMPLIANCE_BUCKET` is unset, Solana memo when
  `SOLANA_KEYPAIR` is unset) skip cleanly via `if:`. Reserve
  `continue-on-error` for genuinely tolerable runtime failures.
- **Per-repo OIDC role**, trust-scoped to `repo:<owner>/<repo>:*`.
  Don't share roles across repos.
- **Retention:** `retention-days: 90` on every `upload-artifact`.

## Compliance bucket hardening

When the check/attest flow writes to a shared compliance bucket, the
bucket itself needs:

- Block public access (all four flags).
- AES256 server-side encryption.
- Versioning enabled.
- Bucket policy denying `s3:*` on `aws:SecureTransport = false`.
- Lifecycle: indefinite retention, transition to `GLACIER_IR` at 365
  days. **No expiration rules** — a 24-hour or 7-day expiry common on
  transient-output buckets silently destroys compliance records.
- IAM policies scoped to `s3:PutObject` on `<bucket>/<repo>/ci/*` only.

Verify before first use:

```bash
aws s3api get-bucket-lifecycle-configuration --bucket <bucket>
```

## Pitfall: attest inlined into check

When the attest steps live inside the check job:

- They run on every PR (Solana fees, noise, failing PRs for flaky RPC).
- A lint failure blocks attestation of an otherwise complete run.
- The attest step ends up gated by `if: always() && github.ref == ...`
  compounds that should be a job-level `if:`.

Refactor into a dedicated `attest` job with `needs:` the check jobs.

## Pitfall: `set -o pipefail` surfaces latent lint warnings

The artifact capture pattern uses `set -o pipefail` and pipes the tool
through `tee`. This correctly propagates non-zero exits — including
RuboCop "convention" warnings, ESLint warnings that were previously
tolerated, etc.

Before enabling the capture pattern on a repo that has been tolerant,
fix the violations or add exceptions. Do not loosen `pipefail`.

## Pitfall: S3 lifecycle expires compliance records

See `solana-cicd-hash`. Applies anywhere CI writes evidence.

## Cross-references

- Solana attestation job and script: `solana-cicd-hash`.
- CM02 `.github/workflows/golden-pipeline.yml` — reusable workflow
  example (`workflow_call`) for multi-repo standardization.
- `form-terra` — source of truth for the compliance bucket
  (`inventium-artifacts`), per-repo OIDC roles, and bucket policies.
