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

Improving the Nation's Cybersecurity.
The foundational directive. Section 4 mandates secure software
development practices, SBOMs, and supply chain transparency for
software sold to the federal government.

- [Full text](https://www.whitehouse.gov/briefing-room/presidential-actions/2021/05/12/executive-order-on-improving-the-nations-cybersecurity/)
- [NIST summary](https://www.nist.gov/itl/executive-order-14028-improving-nations-cybersecurity)

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

- [Full text](https://csrc.nist.gov/pubs/sp/800/218/final)
- [SSDF practices quick reference](https://csrc.nist.gov/projects/ssdf)

### OMB Memorandum M-22-18 (September 2022)

Enhancing the Security of the Software Supply Chain through
Secure Software Development Practices.
Requires federal agencies to obtain self-attestation from software
producers that they follow SSDF practices. Sets deadlines for
compliance. The pipeline produces machine-readable evidence that
supports self-attestation.

- [Full text](https://www.whitehouse.gov/wp-content/uploads/2022/09/M-22-18.pdf)

### OMB Memorandum M-24-15 (June 2024)

Expands M-22-18 with stronger requirements for third-party
assessment, continuous monitoring, and machine-readable compliance
artifacts. Specifically calls for OSCAL-formatted assessment results.

The pipeline's OSCAL generation stage directly addresses this.

- [Full text](https://www.whitehouse.gov/wp-content/uploads/2024/06/M-24-15-Modernizing-the-Federal-Risk-and-Authorization-Management-Program-FedRAMP.pdf)

### OMB Memorandum M-21-31 (August 2021)

Improving the Federal Government's Investigative and Remediation
Capabilities Related to Cybersecurity Incidents.
Requires comprehensive logging and event forwarding. The pipeline
emits structured JSON audit events at each stage. The deploy job
emits a final audit summary.

- [Full text](https://www.whitehouse.gov/wp-content/uploads/2021/08/M-21-31-Improving-the-Federal-Governments-Investigative-and-Remediation-Capabilities-Related-to-Cybersecurity-Incidents.pdf)

### OSCAL (Open Security Controls Assessment Language)

NIST's machine-readable format for security assessment results,
component definitions, and system security plans. M-24-15 requires
OSCAL artifacts. The pipeline generates three OSCAL documents per
run.

- [OSCAL project page](https://pages.nist.gov/OSCAL/)
- [OSCAL reference](https://pages.nist.gov/OSCAL/reference/)
- [OSCAL GitHub](https://github.com/usnistgov/OSCAL)

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

1. Add repo-specific deploy/attest jobs as needed
1. Add OSCAL generation script (`scripts/generate-oscal.js`)
1. Add evidence verification script (`scripts/verify-evidence.js`)
1. Ensure all local CI checks pass before pushing:

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

### Env-vars override profile-based test config

Spring Boot (and most framework config systems) loads properties
from both profile files and environment variables, with env vars at
the top of the precedence chain. Setting `SPRING_PROFILES_ACTIVE=test`
to activate an in-memory H2 profile **and** leaving
`SPRING_DATASOURCE_URL=jdbc:postgresql://...` in the job env will
silently override H2 back to Postgres — the profile activates but
its datasource never wins.

For hermetic tests, set only the profile variable and let the profile
file own the datasource config. Same principle applies to Rails
`RAILS_ENV=test` vs `DATABASE_URL`, Django `DJANGO_SETTINGS_MODULE`
vs `DATABASE_URL`.

### Findings visible only to desktop reviewers

The human-readable Trivy table and surefire reports are behind a
log-drill-down only a desktop reviewer is likely to tolerate.
Reviewers on a phone see the red ✗ and nothing else actionable.
Surface the signal up into the PR checks UI with
`$GITHUB_STEP_SUMMARY`:

```yaml
- name: Summarize Trivy findings in PR
  if: always()
  run: |
    count=$(jq '[.Results[]?.Vulnerabilities[]?] | length' trivy-results.json)
    {
      echo "## Trivy findings"
      echo
      echo "**Total fixable at severity gate:** $count"
      echo
      if [ "$count" -gt 0 ]; then
        echo "| CVE | Severity | Package | Installed | Fixed in |"
        echo "| --- | --- | --- | --- | --- |"
        jq -r '[.Results[]?.Vulnerabilities[]?] | unique_by(.VulnerabilityID + .PkgName) | .[] | "| \(.VulnerabilityID) | \(.Severity) | \(.PkgName) | \(.InstalledVersion) | \(.FixedVersion // "-") |"' trivy-results.json
      fi
    } >> "$GITHUB_STEP_SUMMARY"
```

Run the JSON-evidence Trivy scan first (non-gating, `exit-code: 0`),
then the summary step, then the gating table scan. That ordering
guarantees the summary populates even when the gate fails. Same
pattern works for surefire reports on the test job — parse
`target/surefire-reports/*.txt` into a failed-class listing on
`if: failure()`.

## Adapting for non-Node.js projects

The golden pipeline is Node.js-oriented but the structure adapts:

| Language | Test step | Audit step | SBOM tool |
| --- | --- | --- | --- |
| Node.js | `npm test` | `npm audit` | `anchore/sbom-action` (CycloneDX) |
| Java / Maven | `./mvnw -B -ntp verify` | Trivy (parses `pom.xml` directly) | `anchore/sbom-action` — requires `./mvnw dependency:resolve -DincludeScope=runtime` before syft so the full runtime tree is resolved on disk |
| Ruby | `bundle exec rspec` | `bundle audit check` | `anchore/sbom-action` or `cyclonedx-ruby` |
| Python | `pytest` | `pip-audit` | `cyclonedx-py` |
| Go | `go test ./...` | `govulncheck ./...` | `cyclonedx-gomod` |
| Rust | `cargo test` | `cargo audit` | `cyclonedx-rust-cargo` |

Replace the test and audit commands via `workflow_call` inputs. The
SBOM generation step may need a different action. Secrets scan,
OSCAL generation, and evidence verification are language-agnostic.

### Multi-language projects (e.g. Spring Boot + Angular)

Repos that ship a backend plus a bundled SPA need both toolchains in
the test job — don't split. Pair `actions/setup-java` with
`actions/setup-node`, run `./mvnw verify` (which invokes the frontend
build via `frontend-maven-plugin`), then run the frontend's unit
tests (Karma / Jest) as a separate step. `npm audit --omit=dev` runs
in the frontend subdirectory; Trivy covers the Maven tree via its
`pom.xml` scanner in a single filesystem scan.

For the SBOM job, run language-specific pre-resolve steps before
invoking syft from the repo root so it picks up both trees in one
pass:

```yaml
- run: ./mvnw -B -ntp dependency:resolve -DincludeScope=runtime
- run: npm --prefix src/main/frontend ci --omit=dev
- uses: anchore/sbom-action@<sha>
  with:
    path: .
    format: cyclonedx-json
    output-file: sbom.cyclonedx.json
```

### Legacy / EOL frameworks with unfixable CVEs

Apps pinned to an EOL framework (Spring Boot 2.7, Rails 5.x, etc.)
routinely surface CRITICALs that have no in-series patch. Two
remediation patterns, in order of preference:

1. **BOM property overrides.** Most framework BOMs expose version
   properties that downstream projects can redefine to pull patched
   transitive versions in without bumping the framework itself.
   Example (Spring Boot 2.7.18 → clears CVE-2024-1597 / 2024-38821 /
   2024-50379 / 2024-56337 / 2022-1471 / etc.):

   ```xml
   <properties>
       <spring-framework.version>5.3.39</spring-framework.version>
       <spring-security.version>5.7.14</spring-security.version>
       <tomcat.version>9.0.117</tomcat.version>
       <logback.version>1.2.13</logback.version>
       <snakeyaml.version>2.6</snakeyaml.version>
       <postgresql.version>42.7.10</postgresql.version>
   </properties>
   ```

   Verify `./mvnw verify` still passes after each bump — the newer
   patch must remain API-compatible with the framework line.

2. **Scoped `.trivyignore` with justification + removal condition.**
   When a CVE is only fixed in the next framework major (e.g.
   requires Spring Boot 3 / Jakarta), or when the finding is a
   verifiable false positive (the "fixed" version removes an API
   this codebase doesn't use), suppress **that specific CVE ID** —
   never blanket-ignore. Each entry must carry a justification and
   a removal condition:

   ```text
   # CVE-2016-1000027 — spring-web HttpInvokerServiceExporter
   # Only "fixed" by removing the feature in Spring Framework 6.0.
   # Verified unused in this codebase (grep HttpInvoker returns 0).
   # False positive. Remove after Spring Boot 3 migration.
   CVE-2016-1000027
   ```

   Wire it into the Trivy action with `trivyignores: .trivyignore`
   on **every** Trivy step — both the JSON-evidence step and the
   gating step. Inconsistent ignore lists cause the two scans to
   disagree and produce confusing audit trails.

## Adapting for GitLab CI

The golden pipeline is designed for GitHub Actions but the structure
maps to GitLab CI. Key differences and pitfalls discovered during
the javasprang GitLab CI mirror:

### Structural differences

- **No `workflow_call`** — GitLab has no reusable workflow primitive.
  Use `include: local:` to pull a shared pipeline definition into the
  caller. The included file defines jobs; the caller defines stages,
  variables, and caller-specific jobs.
- **Artifact passing** — Use `needs: [{job: x, artifacts: true}]`
  instead of `actions/download-artifact`. Artifacts from `needs:`
  jobs are automatically restored to the workspace.
- **No `$GITHUB_STEP_SUMMARY`** — Findings only appear in job logs,
  not the MR checks UI. Reviewers on a phone see the red X and
  nothing else actionable. Consider a bot comment or MR note as a
  workaround.
- **`workflow:rules` replaces `on:` triggers** — Controls which
  pipelines run. Define in the caller, not the included file.

### Docker image entrypoint conflicts

Images like `gitleaks` and `trivy` set the binary as the Docker
entrypoint. GitLab CI prepends `sh -c` to script commands, producing
`gitleaks sh -c "..."` which fails with "unknown command sh".

Fix: override the entrypoint in the job definition:

```yaml
image:
  name: zricethezav/gitleaks:v8.22.1
  entrypoint: [""]
```

GitHub Actions `uses:` actions manage their own invocation, so this
problem does not surface there.

### Ubuntu snap chromium stub in Docker

The `chromium` apt package on Ubuntu-based images (including
`eclipse-temurin`) is a snap redirect, not a real binary. Snap does
not work inside Docker containers. `apt-get install chromium`
succeeds but the resulting `/usr/bin/chromium-browser` wrapper
demands snap at runtime.

Install Google Chrome from Google's apt repo instead:

```yaml
before_script:
  - apt-get update -qq && apt-get install -y -qq curl wget gnupg
  - wget -q -O- https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
  - echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
  - apt-get update -qq && apt-get install -y -qq google-chrome-stable
variables:
  CHROME_BIN: /usr/bin/google-chrome-stable
```

Docker containers run as root, so Chrome also needs `--no-sandbox`.
Add a Karma custom launcher:

```js
customLaunchers: {
  ChromeHeadlessCI: {
    base: 'ChromeHeadless',
    flags: ['--no-sandbox']
  }
}
```

GitHub Actions runners have Chrome pre-installed and run as non-root,
so neither issue surfaces there.

### Environment variables do not persist across script steps

GitLab CI runs each `before_script` / `script` list item in its own
shell context. `export FOO=bar` in `before_script` is lost by the
time `script` runs. Use job-level `variables:` for values that must
be visible across steps.

### `$CI_JOB_STATUS` only works in `after_script`

During `script` execution, `$CI_JOB_STATUS` is always `running`.
Move structured audit event JSON to `after_script` where it correctly
reports `success` or `failed`. The GitHub Actions equivalent
`${{ job.status }}` works in `if: always()` steps.

### `npm audit --json` exits non-zero under implicit `set -e`

GitLab CI runs scripts with implicit `set -e`. When `npm audit`
finds vulnerabilities, the JSON-capture line exits non-zero and
kills the job before Trivy runs. Add `|| true` to the JSON-capture
line; the subsequent human-readable gating run still fails the job
properly. GitHub Actions steps are independent — one step failing
does not prevent the next from starting.

### `workflow:rules` and `$CI_OPEN_MERGE_REQUESTS`

Using `$CI_OPEN_MERGE_REQUESTS == ""` in `workflow:rules` to
prevent duplicate pipelines can prevent pipelines from triggering
on branch pushes entirely. Simpler rules are more reliable:

```yaml
workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH && $CI_PIPELINE_SOURCE == "push"'
```

This allows duplicate pipelines (MR + push) for branches with open
MRs, but is reliable. Deduplicate later with
`interruptible: true` once the pipeline is stable.

### Pipeline visualization ignores `needs:` DAG

GitLab's pipeline graph shows stage-based grouping, not the actual
`needs:` dependency edges. A job like `oscal` that only
`needs: vulnerability-scan` appears downstream of all
`compliance-check` jobs in the visualization, even though it starts
as soon as `vulnerability-scan` finishes. The runtime behavior is
correct; the graph is misleading. Add a comment in the YAML so
reviewers understand the actual dependency.

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

### GitHub Actions

- `CM02/.github/workflows/golden-pipeline.yml` — reusable workflow
- `CM02/.github/workflows/ci-cd.yml` — caller with deploy + attest
- `CM02/scripts/generate-oscal.js` — OSCAL artifact generation
- `CM02/scripts/verify-evidence.js` — evidence manifest + drift detection
- `CM02/scripts/attest.mjs` — Solana attestation script

### GitLab CI

- `javasprang/.gitlab-ci.yml` — caller with package stage
- `javasprang/.gitlab/ci/golden-pipeline.yml` — included pipeline
  (mirrors the GitHub Actions golden-pipeline.yml)
