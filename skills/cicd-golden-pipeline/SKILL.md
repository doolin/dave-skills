---
name: cicd-golden-pipeline
description: Reusable GitHub Actions CI/CD pipeline implementing NIST SSDF, EO 14028, OMB M-22-18, and M-24-15 compliance. Covers secrets scanning, testing, vulnerability scanning, SBOM, OSCAL, evidence verification, build provenance, S3 archival, and Solana attestation.
disable-model-invocation: true
---

# CI/CD Golden Pipeline

A reusable GitHub Actions workflow (`workflow_call`) that implements
a compliance-aware CI/CD pipeline. Every push and PR runs the full
check suite; deploys and attestation run only on the main branch.

The pipeline is designed to satisfy federal software supply chain
requirements while remaining practical for small teams.

## Regulatory context

This pipeline addresses requirements from several overlapping federal
directives. Understanding which directive drives which pipeline stage
helps prioritize work and justify the pipeline's existence to
stakeholders.

### Executive Order 14028 (May 2021)

**"Improving the Nation's Cybersecurity"**

The foundational directive. Section 4 mandates secure software
development practices, SBOMs, and supply chain transparency for
software sold to the federal government.

- Full text: https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/
- NIST summary: https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity

### NIST Secure Software Development Framework (SSDF) SP 800-218

The technical standard EO 14028 references. Defines practices (PO,
PS, PW, RV) that software producers must attest to. The golden
pipeline implements several PW (Protect the Software) practices
directly:

| Practice | Description | Pipeline stage |
| --- | --- | --- |
| PW.4 | Reuse existing, well-secured software | SBOM generation |
| PW.6 | Configure the compilation, interpreter, and build processes to improve executable security | Secrets scan |
| PW.7 | Review and/or analyze human-readable code to identify vulnerabilities | Vulnerability scan (npm audit) |
| PW.8 | Test executable code to identify vulnerabilities not found by other means | Vulnerability scan (Trivy) |
| PS.1 | Protect all forms of code from unauthorized access | Build provenance attestation |
| PS.2 | Verify the integrity of the software release | Build provenance attestation |

- Full text: https://csrc.nist.gov/pubs/sp/800/218/final
- SSDF practices quick reference: https://csrc.nist.gov/projects/ssdf

### OMB Memorandum M-22-18 (September 2022)

**"Enhancing the Security of the Software Supply Chain through
Secure Software Development Practices"**

Requires federal agencies to obtain self-attestation from software
producers that they follow SSDF practices. Sets deadlines for
compliance. The pipeline produces machine-readable evidence that
supports self-attestation.

- Full text: https://www.whitehouse.gov/wp-content/uploads/2022/09/M-22-18.pdf

### OMB Memorandum M-24-15 (June 2024)

Expands M-22-18 with stronger requirements for third-party
assessment, continuous monitoring, and machine-readable compliance
artifacts. Specifically calls for OSCAL-formatted assessment results.

The pipeline's OSCAL generation stage directly addresses this.

- Full text: https://www.whitehouse.gov/wp-content/uploads/2024/06/M-24-15-Modernizing-the-Federal-Risk-and-Authorization-Management-Program-FedRAMP.pdf

### OMB Memorandum M-21-31 (August 2021)

**"Improving the Federal Government's Investigative and Remediation
Capabilities Related to Cybersecurity Incidents"**

Requires comprehensive logging and event forwarding. The pipeline
emits structured JSON audit events at each stage. The deploy job
emits a final audit summary.

- Full text: https://www.whitehouse.gov/wp-content/uploads/2021/08/M-21-31-Improving-the-Federal-Governments-Investigative-and-Remediation-Capabilities-Related-to-Cybersecurity-Incidents.pdf

### OSCAL (Open Security Controls Assessment Language)

NIST's machine-readable format for security assessment results,
component definitions, and system security plans. M-24-15 requires
OSCAL artifacts. The pipeline generates three OSCAL documents per
run.

- OSCAL project page: https://pages.nist.gov/OSCAL/
- OSCAL reference: https://pages.nist.gov/OSCAL/reference/
- OSCAL GitHub: https://github.com/usnistgov/OSCAL

## Architecture

```text
on: push, pull_request

golden-pipeline.yml (workflow_call, runs on every push/PR)
├── secrets-scan       (PW.6)      — gitleaks, full history scan
├── test                           — format check + test suite
├── vulnerability-scan (PW.7/PW.8) — npm audit + Trivy filesystem scan
├── sbom              (PW.4)       — CycloneDX SBOM (needs: test)
├── oscal             (M-24-15)    — OSCAL artifacts (needs: vulnerability-scan)
└── verify-evidence                — evidence manifest (needs: vuln-scan, sbom, oscal)

ci-cd.yml (per-repo, calls golden-pipeline.yml)
├── compliance         — calls golden-pipeline.yml
├── deploy             — Lambda deploy + S3 evidence archival (needs: compliance, main only)
└── attest             — Solana on-chain attestation (needs: compliance + deploy, main only)
```

### Why `workflow_call`

The golden pipeline is a reusable workflow so that multiple repos
can share the same compliance pipeline without copy-pasting. Each
repo's `ci-cd.yml` calls it with repo-specific inputs (node version,
test command, etc.).

## Pipeline stages

### 1. Secrets Scan (PW.6)

Runs gitleaks with `fetch-depth: 0` (full history) to catch secrets
that were committed and later removed.

```yaml
secrets-scan:
  name: Secrets Scan (PW.6)
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@... # v5
      with:
        fetch-depth: 0
    - uses: gitleaks/gitleaks-action@... # v2.3.9
      env:
        GITHUB_TOKEN: ${{ github.token }}
```

### 2. Test

Runs the project's format check and test suite. Commands are
configurable via `workflow_call` inputs.

```yaml
test:
  name: Test
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@...
    - uses: actions/setup-node@...
      with:
        node-version: ${{ inputs.node-version }}
        cache: npm
    - run: npm ci
    - run: ${{ inputs.format-check-command }}
    - run: ${{ inputs.test-command }}
```

### 3. Vulnerability Scan (PW.7, PW.8)

Two scanners, both must pass:

- **npm audit** — checks production dependencies against the npm
  advisory database. Fails the build on high/critical findings.
  **Do not use `|| true`** — swallowing audit failures is a
  compliance violation.
- **Trivy** — filesystem scan for known CVEs in dependencies and
  configuration files.

Both produce JSON evidence artifacts uploaded with 90-day retention.

### 4. SBOM Generation (PW.4)

Generates a CycloneDX JSON SBOM from production dependencies
(`npm ci --omit=dev`). Uses `anchore/sbom-action`. Runs after test
to avoid generating SBOMs for broken builds.

### 5. OSCAL Generation (M-24-15)

Consumes vulnerability scan results and generates three OSCAL
documents:

- **Assessment results** — findings from npm audit and Trivy
- **Component definition** — the software component being assessed
- **SSP fragment** — system security plan fragment

These are machine-readable compliance artifacts that satisfy M-24-15
requirements for automated assessment evidence.

### 6. Evidence Verification

Downloads all artifacts (SBOM, scan results, OSCAL) and verifies
completeness. Generates an evidence manifest with SHA-256 checksums
for each artifact. This is the drift detection step — if an upstream
job silently stopped producing an artifact, this job catches it.

## Caller workflow (ci-cd.yml)

The per-repo workflow calls the golden pipeline and adds
repo-specific jobs:

### Deploy

- Runs only on main branch push
- `needs: compliance` — will not deploy if any check failed
- Generates `version.json` with commit SHA
- Packages and deploys to Lambda
- Generates SLSA build provenance (`actions/attest-build-provenance`)
- Archives all evidence artifacts to S3 with SHA-256 checksums
- Runs a smoke test against the deployed Lambda
- Emits a structured audit event (M-21-31)

### Attest

- Runs only on main branch push
- `needs: [compliance, deploy]`
- Downloads all CI artifacts, zips them, computes SHA-256
- Anchors the hash on Solana via memo transaction
- Generates a PDF attestation report
- Uploads attestation artifacts to S3
- See `solana-cicd-hash` skill for details

## Adding a new repo to the pipeline

1. Copy `golden-pipeline.yml` to `.github/workflows/golden-pipeline.yml`
2. Create `ci-cd.yml` that calls it:

```yaml
name: CI/CD

env:
  FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true

on:
  push:
  pull_request:
    branches: [main]

permissions:
  contents: read
  id-token: write
  attestations: write
  security-events: write

jobs:
  compliance:
    name: Golden Pipeline
    uses: ./.github/workflows/golden-pipeline.yml
    with:
      node-version: "20"
    permissions:
      contents: read
      id-token: write
      attestations: write
      security-events: write
    secrets: inherit
```

3. Add repo-specific deploy/attest jobs as needed
4. Add OSCAL generation script (`scripts/generate-oscal.js`)
5. Add evidence verification script (`scripts/verify-evidence.js`)
6. Ensure all local CI checks pass before pushing:

```bash
npm run format:check
npm test
npm audit --audit-level=high --omit=dev
```

## Configurable inputs

| Input | Default | Description |
| --- | --- | --- |
| `node-version` | `"20"` | Node.js version for setup-node |
| `test-command` | `"npm test"` | Test suite command |
| `format-check-command` | `"npm run format:check"` | Formatter/linter check |
| `trivy-severity` | `"CRITICAL,HIGH"` | Trivy severity filter |
| `npm-audit-level` | `"high"` | npm audit minimum severity |

## Action versions (Node 24)

All actions must use Node 24. Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24:
true` at the workflow level to cover runner-injected actions like
`actions/cache`. See `update-actions-node-version` skill for the
full upgrade map and SHA pins.

## Conventions

- **All actions pinned to full 40-character SHAs.** Tags can be
  force-pushed; SHAs cannot.
- **`retention-days: 90` on every `upload-artifact`.** Evidence must
  be retained for audit. Never reduce below 90 days.
- **Vulnerability scans must fail the build.** No `|| true`, no
  `continue-on-error`. A swallowed finding is a compliance gap.
- **`--omit=dev` on npm audit.** Only production dependencies are
  deployed, so only production dependencies are audited for
  compliance. Dev dependency vulnerabilities are tracked separately.
- **OIDC for AWS auth.** Use `aws-actions/configure-aws-credentials`
  with `role-to-assume`, not static access keys. Per-repo IAM roles
  trust-scoped to `repo:<owner>/<repo>:*`.
- **Structured JSON audit events.** Every significant event emits a
  JSON object with `event`, `severity`, `timestamp`, and context
  fields. This satisfies M-21-31 logging requirements.
- **Evidence archived to S3 with checksums.** Each artifact is
  uploaded with `--checksum-algorithm SHA256` and metadata including
  the commit SHA, run ID, and artifact type.

## Pitfalls

### npm audit `|| true` swallows findings

The golden pipeline must fail the build when `npm audit` finds
high/critical vulnerabilities. Using `|| true` to suppress failures
creates a compliance gap — vulnerability scan evidence shows findings
but the pipeline reports success. Fix vulnerabilities or update
dependencies; do not suppress the check.

### SBOM generated from dev dependencies

The SBOM must reflect what is deployed, not what is used for
development. Always use `npm ci --omit=dev` before generating the
SBOM. Including dev dependencies inflates the SBOM and creates
false positives in downstream analysis.

### Evidence artifact retention

GitHub Actions artifacts default to 90-day retention. Do not rely
on this for long-term compliance storage. The deploy job archives
evidence to S3, which has indefinite retention with Glacier
transition at 365 days. GitHub artifacts are a convenience copy.

### S3 lifecycle deletes compliance records

Ensure the compliance bucket has no expiration rules. Transition to
`GLACIER_IR` at 365 days is fine; deletion is not. See
`inventium-cicd-pipeline` skill for bucket hardening details.

### Trivy scan runs twice

The pipeline intentionally runs Trivy twice: once for human-readable
`table` output in the logs, once for machine-readable `json` output
as evidence. This is not a bug.

## Adapting for non-Node.js projects

The golden pipeline is Node.js-oriented but the structure adapts:

| Language | Test step | Audit step | SBOM tool |
| --- | --- | --- | --- |
| Node.js | `npm test` | `npm audit` | `anchore/sbom-action` (CycloneDX) |
| Ruby | `bundle exec rspec` | `bundle audit check` | `anchore/sbom-action` or `cyclonedx-ruby` |
| Python | `pytest` | `pip-audit` | `cyclonedx-py` |
| Go | `go test ./...` | `govulncheck ./...` | `cyclonedx-gomod` |
| Rust | `cargo test` | `cargo audit` | `cyclonedx-rust-cargo` |

Replace the test and audit commands via `workflow_call` inputs. The
SBOM generation step may need a different action. Secrets scan,
OSCAL generation, and evidence verification are language-agnostic.

## Cross-references

- `inventium-cicd-pipeline` — higher-level pipeline conventions
  (three-phase pattern, decision tree, bucket hardening)
- `solana-cicd-hash` — Solana attestation job details
- `update-actions-node-version` — GitHub Actions Node.js version
  upgrade map with SHA pins
- `deploy-commit-sha` — build SHA display in deployed apps
- CM02 `golden-pipeline.yml` — reference implementation
- CM02 `ci-cd.yml` — reference caller workflow

## Reference implementation

- `CM02/.github/workflows/golden-pipeline.yml` — reusable workflow
- `CM02/.github/workflows/ci-cd.yml` — caller with deploy + attest
- `CM02/scripts/generate-oscal.js` — OSCAL artifact generation
- `CM02/scripts/verify-evidence.js` — evidence manifest + drift detection
- `CM02/scripts/attest.mjs` — Solana attestation script
