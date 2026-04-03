# Skill: Add CI/CD Hash to Solana Program

Add a verifiable build hash to a Solana program's CI/CD pipeline. This
ensures the on-chain deployed program matches the source code by computing
a deterministic hash of the program binary and making it available for
verification.

## When to use

Use this skill when setting up or updating CI/CD for a Solana program
that needs build verification. This applies to both Anchor and native
Solana programs.

## Steps

### 1. Add a deterministic build step

For **Anchor** projects, add a verifiable build to the CI pipeline:

```yaml
# .github/workflows/verifiable-build.yml
name: Verifiable Build

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  verifiable-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Solana CLI
        run: |
          sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"
          echo "$HOME/.local/share/solana/install/active_release/bin" >> $GITHUB_PATH

      - name: Install Anchor CLI
        run: |
          cargo install --git https://github.com/coral-xyz/anchor avm --force
          avm install latest
          avm use latest

      - name: Build verifiable
        run: anchor build --verifiable

      - name: Compute program hash
        id: hash
        run: |
          PROGRAM_SO=$(find target/verifiable -name "*.so" | head -1)
          HASH=$(sha256sum "$PROGRAM_SO" | awk '{print $1}')
          echo "program_hash=$HASH" >> $GITHUB_OUTPUT
          echo "program_path=$PROGRAM_SO" >> $GITHUB_OUTPUT
          echo "## Program Hash" >> $GITHUB_STEP_SUMMARY
          echo "\`$HASH\`" >> $GITHUB_STEP_SUMMARY

      - name: Verify against on-chain program
        if: github.ref == 'refs/heads/main'
        run: |
          PROGRAM_ID=$(grep -r "declare_id" programs/*/src/lib.rs | head -1 | grep -oP '"[^"]*"' | tr -d '"')
          echo "Program ID: $PROGRAM_ID"
          solana program dump "$PROGRAM_ID" /tmp/onchain.so --url mainnet-beta || echo "Program not yet deployed"
          if [ -f /tmp/onchain.so ]; then
            ONCHAIN_HASH=$(sha256sum /tmp/onchain.so | awk '{print $1}')
            BUILD_HASH=${{ steps.hash.outputs.program_hash }}
            echo "On-chain hash: $ONCHAIN_HASH"
            echo "Build hash:    $BUILD_HASH"
            if [ "$ONCHAIN_HASH" = "$BUILD_HASH" ]; then
              echo "MATCH: Build matches on-chain program"
            else
              echo "MISMATCH: Build does not match on-chain program"
            fi
          fi

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: verifiable-build
          path: ${{ steps.hash.outputs.program_path }}
```

For **native** (non-Anchor) Solana programs, replace the build step:

```yaml
      - name: Build program
        run: cargo build-sbf

      - name: Compute program hash
        id: hash
        run: |
          PROGRAM_SO=$(find target/deploy -name "*.so" | head -1)
          HASH=$(sha256sum "$PROGRAM_SO" | awk '{print $1}')
          echo "program_hash=$HASH" >> $GITHUB_OUTPUT
          echo "program_path=$PROGRAM_SO" >> $GITHUB_OUTPUT
```

### 2. Add a Makefile target

```makefile
.PHONY: hash verify

# Compute the sha256 hash of the built program binary
hash:
	@PROGRAM_SO=$$(find target/deploy -name "*.so" -o -name "*.so" -path "target/verifiable/*" | head -1); \
	if [ -z "$$PROGRAM_SO" ]; then echo "No .so found. Run build first."; exit 1; fi; \
	HASH=$$(sha256sum "$$PROGRAM_SO" | awk '{print $$1}'); \
	echo "$$HASH  $$PROGRAM_SO"; \
	echo "$$HASH" > .build-hash

# Verify local build hash matches on-chain program
verify:
	@if [ -z "$(PROGRAM_ID)" ]; then echo "Usage: make verify PROGRAM_ID=<address>"; exit 1; fi
	@solana program dump $(PROGRAM_ID) /tmp/onchain.so --url mainnet-beta
	@ONCHAIN=$$(sha256sum /tmp/onchain.so | awk '{print $$1}'); \
	LOCAL=$$(cat .build-hash 2>/dev/null || echo "none"); \
	echo "On-chain: $$ONCHAIN"; \
	echo "Local:    $$LOCAL"; \
	[ "$$ONCHAIN" = "$$LOCAL" ] && echo "MATCH" || echo "MISMATCH"
```

### 3. Store the hash

Add `.build-hash` to `.gitignore` (it's a local artifact). The canonical
hash lives in the CI workflow output and build artifacts.

For releases, include the hash in the GitHub Release notes or as a
release asset.

### 4. Wire into existing CI

If the project already has a CI workflow, add the hash computation step
after the build step rather than creating a separate workflow. The key
pieces to add are:

1. The `sha256sum` computation step
2. Writing the hash to `$GITHUB_STEP_SUMMARY`
3. Uploading the `.so` as a build artifact

## Verification

After implementation, verify by:

1. Running `make hash` locally and confirming it outputs a sha256 hash
2. Pushing to trigger CI and checking the workflow summary for the hash
3. If deployed, running `make verify PROGRAM_ID=<address>` to compare
