---
name: solana-cicd-hash
description: Add CI/CD artifact hashing and on-chain attestation to a Solana project. Bundles all pipeline output (tests, coverage, linting, build artifacts), generates a PDF report, posts the root hash to Solana, and uploads everything to S3.
disable-model-invocation: true
---

# Add CI/CD Hash to Solana

Bundle all CI/CD pipeline artifacts — test output, coverage reports,
linting reports, build artifacts, and anything else the pipeline
produces — into a single package, hash it, generate a PDF attestation
report, sign the root hash, post it on-chain to Solana, and upload
everything to S3 for durable storage.

## When to use

Use this skill when a project needs verifiable, on-chain proof that
its CI/CD pipeline ran and what it produced. This creates a tamper-proof
record on Solana linking a git commit to its full set of CI/CD results,
backed by a PDF report and S3 archive.

## Overview

1. Collect all CI/CD artifacts into a bundle directory
2. Generate a manifest of every artifact with individual hashes
3. Hash the entire bundle to produce a single root hash
4. Generate a PDF attestation report summarizing everything
5. Sign the root hash with a Solana keypair
6. Post the signature and hash on-chain as a memo transaction
7. Upload the full bundle (including PDF) to S3

## Steps

### 1. Collect all CI/CD artifacts

Add a step to the CI pipeline that gathers everything into a single
directory. This runs **after** all build, test, lint, and coverage
steps have completed.

```yaml
# .github/workflows/cicd-hash.yml
name: CI/CD Artifact Hash

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Solana CLI
        run: |
          sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
          echo "$HOME/.local/share/solana/install/active_release/bin" >> $GITHUB_PATH

      - name: Install PDF tools
        run: |
          pip install weasyprint markdown2

      # --- Build ---
      - name: Build
        run: cargo build-sbf 2>&1 | tee build-output.txt

      # --- Tests ---
      - name: Run tests
        run: cargo test 2>&1 | tee test-output.txt

      # --- Coverage ---
      - name: Run coverage
        run: |
          cargo install cargo-tarpaulin || true
          cargo tarpaulin --out xml --output-dir . 2>&1 | tee coverage-output.txt

      # --- Linting ---
      - name: Lint (clippy)
        run: cargo clippy --all-targets 2>&1 | tee lint-output.txt

      - name: Format check
        run: cargo fmt --check 2>&1 | tee fmt-output.txt

      # --- Bundle all artifacts ---
      - name: Bundle CI/CD artifacts
        id: bundle
        run: |
          mkdir -p cicd-bundle

          # Build artifacts
          cp -r target/deploy/*.so cicd-bundle/ 2>/dev/null || true
          cp build-output.txt cicd-bundle/

          # Test output
          cp test-output.txt cicd-bundle/

          # Coverage
          cp cobertura.xml cicd-bundle/ 2>/dev/null || true
          cp coverage-output.txt cicd-bundle/

          # Linting
          cp lint-output.txt cicd-bundle/
          cp fmt-output.txt cicd-bundle/

          # Git metadata
          echo "${{ github.sha }}" > cicd-bundle/git-commit.txt
          echo "${{ github.ref }}" > cicd-bundle/git-ref.txt
          echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > cicd-bundle/timestamp.txt

      # --- Generate manifest and root hash ---
      - name: Generate artifact manifest and root hash
        id: hash
        run: |
          cd cicd-bundle
          find . -type f -not -name 'manifest.txt' | sort | while read f; do
            sha256sum "$f"
          done > manifest.txt

          cd ..
          ROOT_HASH=$(sha256sum cicd-bundle/manifest.txt | awk '{print $1}')
          echo "root_hash=$ROOT_HASH" >> $GITHUB_OUTPUT

          echo "## CI/CD Artifact Hash" >> $GITHUB_STEP_SUMMARY
          echo "**Root hash:** \`$ROOT_HASH\`" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** \`${{ github.sha }}\`" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "<details><summary>Manifest</summary>" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          cat cicd-bundle/manifest.txt >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
          echo "</details>" >> $GITHUB_STEP_SUMMARY

      # --- Generate PDF attestation report ---
      - name: Generate PDF attestation report
        id: pdf
        env:
          ROOT_HASH: ${{ steps.hash.outputs.root_hash }}
        run: |
          python3 - <<'PYTHON'
          import markdown2
          from weasyprint import HTML
          from datetime import datetime, timezone
          import os

          root_hash = os.environ["ROOT_HASH"]
          commit = open("cicd-bundle/git-commit.txt").read().strip()
          ref = open("cicd-bundle/git-ref.txt").read().strip()
          timestamp = open("cicd-bundle/timestamp.txt").read().strip()
          manifest = open("cicd-bundle/manifest.txt").read().strip()

          # Read CI output summaries (first 100 lines each to keep PDF reasonable)
          def read_summary(path, max_lines=100):
              try:
                  lines = open(path).readlines()
                  text = "".join(lines[:max_lines])
                  if len(lines) > max_lines:
                      text += f"\n... ({len(lines) - max_lines} more lines truncated)\n"
                  return text
              except FileNotFoundError:
                  return "(not available)"

          test_output = read_summary("cicd-bundle/test-output.txt")
          coverage_output = read_summary("cicd-bundle/coverage-output.txt")
          lint_output = read_summary("cicd-bundle/lint-output.txt")
          fmt_output = read_summary("cicd-bundle/fmt-output.txt")
          build_output = read_summary("cicd-bundle/build-output.txt")

          md = f"""# CI/CD Attestation Report

          **Generated:** {timestamp}
          **Commit:** `{commit}`
          **Ref:** `{ref}`
          **Root Hash (SHA-256):** `{root_hash}`

          ---

          ## Artifact Manifest

          Each file in the CI/CD bundle with its individual SHA-256 hash:

          ```
          {manifest}
          ```

          ---

          ## Build Output

          ```
          {build_output}
          ```

          ## Test Output

          ```
          {test_output}
          ```

          ## Coverage Output

          ```
          {coverage_output}
          ```

          ## Lint Output (Clippy)

          ```
          {lint_output}
          ```

          ## Format Check Output

          ```
          {fmt_output}
          ```

          ---

          ## Attestation

          This report attests that the CI/CD pipeline for commit `{commit}`
          produced the artifacts listed in the manifest above. The root hash
          `{root_hash}` is the SHA-256 hash of the manifest file, which
          contains individual SHA-256 hashes of every artifact.

          This root hash has been posted on-chain to Solana as a memo
          transaction in the format:

          ```
          cicd:{commit}:{root_hash}
          ```

          The full artifact bundle is archived in S3 and can be independently
          verified by recomputing the manifest hashes.
          """

          html = markdown2.markdown(md, extras=["fenced-code-blocks", "tables"])
          styled = f"""<html><head><style>
          body {{ font-family: sans-serif; margin: 40px; font-size: 12px; }}
          code, pre {{ font-family: monospace; font-size: 11px; background: #f5f5f5; padding: 2px 4px; }}
          pre {{ padding: 12px; overflow-x: auto; }}
          h1 {{ border-bottom: 2px solid #333; padding-bottom: 8px; }}
          h2 {{ border-bottom: 1px solid #ccc; padding-bottom: 4px; margin-top: 24px; }}
          </style></head><body>{html}</body></html>"""

          HTML(string=styled).write_pdf("cicd-bundle/attestation-report.pdf")
          print("PDF generated: cicd-bundle/attestation-report.pdf")
          PYTHON

      # --- Sign and post to Solana ---
      - name: Post hash to Solana
        if: github.ref == 'refs/heads/main'
        id: solana
        env:
          SOLANA_KEYPAIR: ${{ secrets.SOLANA_KEYPAIR }}
          SOLANA_RPC_URL: ${{ vars.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com' }}
        run: |
          echo "$SOLANA_KEYPAIR" > /tmp/keypair.json
          solana config set --keypair /tmp/keypair.json --url "$SOLANA_RPC_URL"

          ROOT_HASH=${{ steps.hash.outputs.root_hash }}
          COMMIT=${{ github.sha }}
          MEMO="cicd:${COMMIT}:${ROOT_HASH}"

          TX_SIG=$(solana transfer --allow-unfunded-recipient \
            --with-memo "$MEMO" \
            $(solana-keygen pubkey /tmp/keypair.json) \
            0 \
            --fee-payer /tmp/keypair.json \
            | tail -1)

          rm -f /tmp/keypair.json

          echo "tx_signature=$TX_SIG" >> $GITHUB_OUTPUT
          echo "$TX_SIG" > cicd-bundle/solana-tx-signature.txt
          echo "$MEMO" > cicd-bundle/solana-memo.txt

          echo "## On-chain Attestation" >> $GITHUB_STEP_SUMMARY
          echo "Memo posted: \`$MEMO\`" >> $GITHUB_STEP_SUMMARY
          echo "Transaction: \`$TX_SIG\`" >> $GITHUB_STEP_SUMMARY

      # --- Upload to S3 ---
      - name: Upload bundle to S3
        if: github.ref == 'refs/heads/main'
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: ${{ vars.AWS_REGION || 'us-east-1' }}
          S3_BUCKET: ${{ vars.CICD_S3_BUCKET }}
        run: |
          COMMIT=${{ github.sha }}
          TIMESTAMP=$(cat cicd-bundle/timestamp.txt)
          S3_PREFIX="s3://${S3_BUCKET}/cicd/${COMMIT}/${TIMESTAMP}"

          pip install awscli
          aws s3 cp cicd-bundle/ "${S3_PREFIX}/" --recursive

          echo "## S3 Archive" >> $GITHUB_STEP_SUMMARY
          echo "Uploaded to: \`${S3_PREFIX}/\`" >> $GITHUB_STEP_SUMMARY

      # --- Upload bundle as GitHub artifact ---
      - name: Upload CI/CD bundle
        uses: actions/upload-artifact@v4
        with:
          name: cicd-bundle
          path: cicd-bundle/
          retention-days: 90
```

### 2. Add Makefile targets for local use

```makefile
.PHONY: cicd-bundle cicd-hash cicd-pdf cicd-post cicd-upload cicd-all

SOLANA_RPC_URL ?= https://api.mainnet-beta.solana.com
KEYPAIR ?= ~/.config/solana/id.json
S3_BUCKET ?= my-cicd-attestations
AWS_REGION ?= us-east-1

# Collect all CI artifacts into a bundle
cicd-bundle:
	mkdir -p cicd-bundle
	cargo build-sbf 2>&1 | tee cicd-bundle/build-output.txt
	cp -r target/deploy/*.so cicd-bundle/ 2>/dev/null || true
	cargo test 2>&1 | tee cicd-bundle/test-output.txt
	cargo clippy --all-targets 2>&1 | tee cicd-bundle/lint-output.txt
	cargo fmt --check 2>&1 | tee cicd-bundle/fmt-output.txt
	git rev-parse HEAD > cicd-bundle/git-commit.txt
	git rev-parse --abbrev-ref HEAD > cicd-bundle/git-ref.txt
	date -u +%Y-%m-%dT%H:%M:%SZ > cicd-bundle/timestamp.txt

# Generate manifest and root hash from the bundle
cicd-hash: cicd-bundle
	cd cicd-bundle && find . -type f \
		-not -name 'manifest.txt' \
		-not -name 'attestation-report.pdf' \
		| sort | while read f; do sha256sum "$$f"; done > manifest.txt
	@ROOT_HASH=$$(sha256sum cicd-bundle/manifest.txt | awk '{print $$1}'); \
	echo "Root hash: $$ROOT_HASH"; \
	echo "$$ROOT_HASH" > .cicd-root-hash

# Generate PDF attestation report
cicd-pdf: cicd-hash
	python3 scripts/generate-attestation-pdf.py

# Post the root hash to Solana as a memo transaction
cicd-post: cicd-hash
	@ROOT_HASH=$$(cat .cicd-root-hash); \
	COMMIT=$$(cat cicd-bundle/git-commit.txt); \
	MEMO="cicd:$$COMMIT:$$ROOT_HASH"; \
	echo "Posting memo: $$MEMO"; \
	TX=$$(solana transfer --allow-unfunded-recipient \
		--with-memo "$$MEMO" \
		$$(solana-keygen pubkey $(KEYPAIR)) \
		0 \
		--keypair $(KEYPAIR) \
		--url $(SOLANA_RPC_URL) \
		--fee-payer $(KEYPAIR) \
		| tail -1); \
	echo "$$TX" > cicd-bundle/solana-tx-signature.txt; \
	echo "$$MEMO" > cicd-bundle/solana-memo.txt; \
	echo "Transaction: $$TX"

# Upload the full bundle to S3
cicd-upload:
	@COMMIT=$$(cat cicd-bundle/git-commit.txt); \
	TIMESTAMP=$$(cat cicd-bundle/timestamp.txt); \
	S3_PREFIX="s3://$(S3_BUCKET)/cicd/$$COMMIT/$$TIMESTAMP"; \
	echo "Uploading to $$S3_PREFIX/"; \
	aws s3 cp cicd-bundle/ "$$S3_PREFIX/" --recursive --region $(AWS_REGION)

# Run the full pipeline: bundle, hash, PDF, post to Solana, upload to S3
cicd-all: cicd-pdf cicd-post cicd-upload
	@echo "Done. Bundle archived and attested on-chain."
```

### 3. Add the PDF generation script

Create `scripts/generate-attestation-pdf.py` in the target project:

````python
#!/usr/bin/env python3
"""Generate a PDF attestation report from the CI/CD artifact bundle."""

import markdown2
from weasyprint import HTML
import os

def read_summary(path, max_lines=100):
    """Read a file, truncating to max_lines."""
    try:
        lines = open(path).readlines()
        text = "".join(lines[:max_lines])
        if len(lines) > max_lines:
            text += f"\n... ({len(lines) - max_lines} more lines truncated)\n"
        return text
    except FileNotFoundError:
        return "(not available)"

root_hash = open(".cicd-root-hash").read().strip()
commit = open("cicd-bundle/git-commit.txt").read().strip()
ref = open("cicd-bundle/git-ref.txt").read().strip()
timestamp = open("cicd-bundle/timestamp.txt").read().strip()
manifest = open("cicd-bundle/manifest.txt").read().strip()

# Read Solana transaction info if available
try:
    tx_sig = open("cicd-bundle/solana-tx-signature.txt").read().strip()
    memo = open("cicd-bundle/solana-memo.txt").read().strip()
    solana_section = f"""## On-chain Attestation

**Transaction signature:** `{tx_sig}`
**Memo:** `{memo}`
"""
except FileNotFoundError:
    solana_section = """## On-chain Attestation

(Not yet posted — run `make cicd-post` to post to Solana)
"""

md = f"""# CI/CD Attestation Report

**Generated:** {timestamp}
**Commit:** `{commit}`
**Ref:** `{ref}`
**Root Hash (SHA-256):** `{root_hash}`

---

## Artifact Manifest

Each file in the CI/CD bundle with its individual SHA-256 hash:

```
{manifest}
```

---

## Build Output

```
{read_summary("cicd-bundle/build-output.txt")}
```

## Test Output

```
{read_summary("cicd-bundle/test-output.txt")}
```

## Coverage Output

```
{read_summary("cicd-bundle/coverage-output.txt")}
```

## Lint Output (Clippy)

```
{read_summary("cicd-bundle/lint-output.txt")}
```

## Format Check Output

```
{read_summary("cicd-bundle/fmt-output.txt")}
```

---

{solana_section}

---

## S3 Archive

The full artifact bundle is uploaded to S3 at:

```
s3://<bucket>/cicd/{commit}/{timestamp}/
```

---

## Verification

To independently verify this attestation:

1. Download the artifact bundle from S3
2. Recompute SHA-256 hashes for each file
3. Verify they match the manifest above
4. Hash the manifest and compare to the root hash
5. Look up the Solana transaction and verify the memo contains the same root hash
"""

html = markdown2.markdown(md, extras=["fenced-code-blocks", "tables"])
styled = f"""<html><head><style>
body {{ font-family: sans-serif; margin: 40px; font-size: 12px; }}
code, pre {{ font-family: monospace; font-size: 11px; background: #f5f5f5; padding: 2px 4px; }}
pre {{ padding: 12px; overflow-x: auto; }}
h1 {{ border-bottom: 2px solid #333; padding-bottom: 8px; }}
h2 {{ border-bottom: 1px solid #ccc; padding-bottom: 4px; margin-top: 24px; }}
</style></head><body>{html}</body></html>"""

HTML(string=styled).write_pdf("cicd-bundle/attestation-report.pdf")
print("PDF generated: cicd-bundle/attestation-report.pdf")
````

### 4. Configure secrets and variables

Add these to the GitHub repository settings:

**Secrets:**

- **`SOLANA_KEYPAIR`**: The JSON keypair file contents for the signing
  wallet. This wallet pays memo transaction fees.
- **`AWS_ACCESS_KEY_ID`**: AWS credentials for S3 upload.
- **`AWS_SECRET_ACCESS_KEY`**: AWS credentials for S3 upload.

**Variables:**

- **`SOLANA_RPC_URL`** (optional): Custom RPC endpoint. Defaults to
  mainnet-beta.
- **`CICD_S3_BUCKET`**: The S3 bucket name for artifact storage.
- **`AWS_REGION`** (optional): AWS region. Defaults to us-east-1.

The signing wallet only needs enough SOL to cover memo transaction fees
(fractions of a cent per transaction).

### 5. Wire into an existing CI pipeline

If the project already has a CI workflow, add these pieces after the
existing build/test/lint steps:

1. Install PDF tools (`pip install weasyprint markdown2`)
2. The artifact collection step (copying outputs into `cicd-bundle/`)
3. The manifest generation and root hash computation
4. The PDF attestation report generation
5. The Solana memo posting step (main branch only)
6. The S3 upload step (main branch only)
7. The GitHub artifact upload step

Adapt the artifact collection to capture whatever the existing pipeline
produces. The key principle: **everything the pipeline generates goes
into the bundle**.

## Memo format

The on-chain memo follows this format:

```text
cicd:<git-commit-sha>:<root-hash>
```

This allows anyone to:

1. Find the memo transaction on a Solana explorer
2. Match it to a git commit
3. Download the full bundle from S3
4. Recompute the manifest hash and verify it matches the on-chain record
5. Read the PDF attestation report for a human-readable summary

## What gets uploaded to S3

The S3 path structure is:

```text
s3://<bucket>/cicd/<commit-sha>/<timestamp>/
  ├── attestation-report.pdf    # Human-readable PDF of everything
  ├── manifest.txt              # File hashes
  ├── solana-tx-signature.txt   # On-chain transaction ID
  ├── solana-memo.txt           # The memo that was posted
  ├── git-commit.txt            # Commit SHA
  ├── git-ref.txt               # Branch/ref
  ├── timestamp.txt             # Build timestamp
  ├── build-output.txt          # Build log
  ├── test-output.txt           # Test results
  ├── coverage-output.txt       # Coverage report
  ├── cobertura.xml             # Coverage data (XML)
  ├── lint-output.txt           # Clippy output
  ├── fmt-output.txt            # Format check output
  └── *.so                      # Compiled program binaries
```

## Verification

After implementation, verify by:

1. `make cicd-hash` locally — should produce a root hash
2. `make cicd-pdf` — should generate `cicd-bundle/attestation-report.pdf`
3. Push to trigger CI — check the workflow summary for hash and manifest
4. On main branch merges — confirm the memo transaction appears on-chain
5. Check S3 bucket for the uploaded bundle and PDF
6. Download the bundle and re-hash to confirm it matches the on-chain record
