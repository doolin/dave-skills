# Skill: Add CI/CD Hash to Solana

Bundle all CI/CD pipeline artifacts — test output, coverage reports,
linting reports, build artifacts, and anything else the pipeline
produces — into a single package, hash it, and prepare signatures
for posting as an on-chain attestation on Solana.

## When to use

Use this skill when a project needs verifiable, on-chain proof that
its CI/CD pipeline ran and what it produced. This creates a tamper-proof
record on Solana linking a git commit to its full set of CI/CD results.

## Overview

1. Collect all CI/CD artifacts into a bundle directory
2. Generate a manifest of every artifact with individual hashes
3. Hash the entire bundle to produce a single root hash
4. Sign the root hash with a Solana keypair
5. Post the signature and hash on-chain as a memo or custom transaction

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
          # Hash every file individually into a manifest
          find . -type f -not -name 'manifest.txt' | sort | while read f; do
            sha256sum "$f"
          done > manifest.txt

          cd ..
          # Root hash: hash the manifest itself
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

      # --- Sign and post to Solana ---
      - name: Post hash to Solana
        if: github.ref == 'refs/heads/main'
        env:
          SOLANA_KEYPAIR: ${{ secrets.SOLANA_KEYPAIR }}
          SOLANA_RPC_URL: ${{ vars.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com' }}
        run: |
          # Write keypair to temp file
          echo "$SOLANA_KEYPAIR" > /tmp/keypair.json
          solana config set --keypair /tmp/keypair.json --url "$SOLANA_RPC_URL"

          ROOT_HASH=${{ steps.hash.outputs.root_hash }}
          COMMIT=${{ github.sha }}
          MEMO="cicd:${COMMIT}:${ROOT_HASH}"

          # Post as a Solana memo transaction
          solana transfer --allow-unfunded-recipient \
            --with-memo "$MEMO" \
            $(solana-keygen pubkey /tmp/keypair.json) \
            0 \
            --fee-payer /tmp/keypair.json

          # Clean up
          rm -f /tmp/keypair.json

          echo "## On-chain Attestation" >> $GITHUB_STEP_SUMMARY
          echo "Memo posted: \`$MEMO\`" >> $GITHUB_STEP_SUMMARY

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
.PHONY: cicd-bundle cicd-hash cicd-post

SOLANA_RPC_URL ?= https://api.mainnet-beta.solana.com
KEYPAIR ?= ~/.config/solana/id.json

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
	cd cicd-bundle && find . -type f -not -name 'manifest.txt' | sort | \
		while read f; do sha256sum "$$f"; done > manifest.txt
	@ROOT_HASH=$$(sha256sum cicd-bundle/manifest.txt | awk '{print $$1}'); \
	echo "Root hash: $$ROOT_HASH"; \
	echo "$$ROOT_HASH" > .cicd-root-hash

# Post the root hash to Solana as a memo transaction
cicd-post: cicd-hash
	@ROOT_HASH=$$(cat .cicd-root-hash); \
	COMMIT=$$(cat cicd-bundle/git-commit.txt); \
	MEMO="cicd:$$COMMIT:$$ROOT_HASH"; \
	echo "Posting memo: $$MEMO"; \
	solana transfer --allow-unfunded-recipient \
		--with-memo "$$MEMO" \
		$$(solana-keygen pubkey $(KEYPAIR)) \
		0 \
		--keypair $(KEYPAIR) \
		--url $(SOLANA_RPC_URL) \
		--fee-payer $(KEYPAIR)
```

### 3. Configure secrets

Add these to the GitHub repository settings:

- **`SOLANA_KEYPAIR`** (secret): The JSON keypair file contents for the
  signing wallet. This wallet pays transaction fees for the memo.
- **`SOLANA_RPC_URL`** (variable, optional): Custom RPC endpoint.
  Defaults to mainnet-beta.

The signing wallet only needs enough SOL to cover memo transaction fees
(fractions of a cent per transaction).

### 4. Wire into an existing CI pipeline

If the project already has a CI workflow, add these pieces after the
existing build/test/lint steps:

1. The artifact collection step (copying outputs into `cicd-bundle/`)
2. The manifest generation and root hash computation
3. The Solana memo posting step (main branch only)
4. The artifact upload step

Adapt the artifact collection to capture whatever the existing pipeline
produces. The key principle: **everything the pipeline generates goes
into the bundle**.

## Memo format

The on-chain memo follows this format:

```
cicd:<git-commit-sha>:<root-hash>
```

This allows anyone to:
1. Find the memo transaction on a Solana explorer
2. Match it to a git commit
3. Download the CI/CD bundle artifact from GitHub
4. Recompute the manifest hash and verify it matches the on-chain record

## Verification

After implementation, verify by:

1. `make cicd-hash` locally — should produce a root hash
2. Push to trigger CI — check the workflow summary for the hash and manifest
3. On main branch merges — confirm the memo transaction appears on-chain
4. Download the bundle artifact and re-hash to confirm it matches
