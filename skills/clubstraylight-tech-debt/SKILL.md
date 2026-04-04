---
name: clubstraylight-tech-debt
description: Tracks AWS infrastructure technical debt across clubstraylight Lambda apps — OIDC role sharing, S3 bucket sprawl, permission creep, and remediation plan.
disable-model-invocation: true
---

# Clubstraylight Infrastructure Technical Debt

Accumulated during rapid deployment of Lambda apps behind the
clubstraylight.com CloudFront distribution. All items discovered
during the baa-or-not (2026-04-04) deployment exercise.

## 1. OIDC role sharing (critical)

**Problem:** The slacronym GitHub OIDC role has `repo:*` trust,
meaning any GitHub repository can assume it. When baa-or-not needed
CI/CD access, it was expedient to reuse this role rather than wire
up the scoped role that already exists in `baa-or-not.tf`.

**Current state:**

- `slacronym-github-oidc-role` trust: `repo:*` (should be `repo:doolin/slacronym:*`)
- baa-or-not `AWS_ROLE_ARN` secret points to the slacronym role
- The slacronym role's Lambda deploy policy now includes both
  `aws_lambda_function.slacronym.arn` and `aws_lambda_function.baa_or_not.arn`
- The slacronym role's S3 policy now includes both `slacronym-artifacts`
  and `baa-or-not-deployments` buckets
- The slacronym role has `cloudfront:CreateInvalidation` on the
  entire clubstraylight distribution

**Remediation:**

1. Tighten slacronym role trust to `repo:doolin/slacronym:*`
2. Remove baa-or-not resources from slacronym role policies
3. Wire up `baa-or-not-github-oidc-role` (already in baa-or-not.tf):
   - Add S3 compliance policy for `inventium-backups/baa-or-not/ci/*`
   - Add CloudFront invalidation permission
   - Add `lambda:GetFunctionConfiguration` to its Lambda deploy policy
4. Update baa-or-not `AWS_ROLE_ARN` secret to point to its own role
5. Update `S3_COMPLIANCE_BUCKET` variable from `slacronym-artifacts`
   to `inventium-backups`

**Files to change:**

- `form-terra/slacronym.tf` — revert Lambda/S3/CF additions, tighten trust
- `form-terra/baa-or-not.tf` — add missing policies
- GitHub secret: `gh secret set AWS_ROLE_ARN --repo doolin/baa-or-not`
- GitHub variable: `gh variable set S3_COMPLIANCE_BUCKET --repo doolin/baa-or-not`

## 2. S3 compliance bucket mismatch

**Problem:** CI attestation artifacts for baa-or-not land in
`slacronym-artifacts` because that's what the shared OIDC role has
access to. The correct bucket is `inventium-backups` with a
`baa-or-not/ci/` prefix (matching the dbb pattern).

**Current state:**

- `S3_COMPLIANCE_BUCKET` variable: `slacronym-artifacts`
- Attestation artifacts written to `slacronym-artifacts/baa-or-not/ci/...`
- No lifecycle policy verification on slacronym-artifacts

**Remediation:**

- Add `inventium-backups` write policy to the baa-or-not OIDC role
  (scoped to `baa-or-not/ci/*` prefix)
- Update GitHub variable to `inventium-backups`
- Verify `inventium-backups` has no lifecycle rule that expires objects
  before 90 days (`aws s3api get-bucket-lifecycle-configuration`)

## 3. Lambda deploy policy incomplete

**Problem:** The `baa-or-not-github-oidc-role` in `baa-or-not.tf`
only has `lambda:UpdateFunctionCode`. The deploy script's
`aws lambda wait function-updated` requires `lambda:GetFunctionConfiguration`.

**Current state:** The permission was added to the slacronym role
as a workaround. The baa-or-not role is missing it.

**Remediation:** Add `lambda:GetFunction` and
`lambda:GetFunctionConfiguration` to the baa-or-not role's Lambda
deploy policy in `baa-or-not.tf`.

## 4. CloudFront invalidation permission missing from baa-or-not role

**Problem:** `baa-or-not.tf` has no `cloudfront:CreateInvalidation`
permission. This was added to the slacronym role instead.

**Remediation:** Add a policy statement to the baa-or-not OIDC role:

```hcl
{
  Effect   = "Allow"
  Action   = ["cloudfront:CreateInvalidation"]
  Resource = aws_cloudfront_distribution.clubstraylight_distribution.arn
}
```

## 5. No shared OIDC role strategy

**Problem:** Each new Lambda app either creates its own OIDC role
(correct but verbose) or piggybacks on an existing one (wrong but
fast). There's no documented pattern for when to share vs scope.

**Recommendation:** Every app gets its own role, scoped to its repo.
The cost is one IAM role + 2-3 policies per app. The alternative
(shared roles with expanding permissions) is a security risk that
scales poorly. Document this in the `clubstraylight-lambda` skill
and enforce it for all new apps.

## 6. Solana keypair reuse

**Problem:** baa-or-not uses `dbb-attestation.json` as its Solana
keypair. All apps sharing this keypair will show transactions from
the same public key, making it impossible to distinguish which app
produced which attestation without reading the memo payload.

**Remediation (low priority):** Generate per-app keypairs. Fund each
on devnet. Update GitHub secrets. The memo JSON payload already
contains the repo name, so on-chain disambiguation is possible
without separate keys — this is cosmetic rather than functional.

## Remediation order

1. Fix baa-or-not.tf policies (items 3, 4, 2)
2. Tighten slacronym role trust (item 1)
3. Switch baa-or-not secrets/variables to its own role (item 1)
4. Revert slacronym.tf workarounds (item 1)
5. Verify attestation lands in correct bucket (item 2)
6. Document per-app OIDC pattern (item 5)
7. Per-app Solana keypairs if desired (item 6)
