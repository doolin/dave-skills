# Dave's Skills

Because everyone knows a Dave.

A collection of reusable [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills)
for Claude Code, Cursor, and other skill-aware coding agents. Skills live at
`skills/<kebab-name>/SKILL.md` at the top level (not under `.claude/`) so they
stay portable and easy to extract into other repos.

## Layout

- `skills/` — one directory per skill, each with a `SKILL.md` (YAML
  frontmatter and body) plus any supporting scripts, workflows, or
  reference material.
- `scripts/` — repo-level scripts. Currently just `attest.mjs`, the dogfooded
  copy of the `solana-cicd-hash` attestation pipeline that runs in this repo's
  own CI.
- `terraform/` — infrastructure for the evidence bucket and OIDC role used by
  the attestation job.
- `.github/workflows/` — CI: markdownlint on every PR, Terraform validate, and
  the Solana-anchored attestation job on pushes to `master`.
- `AGENTS.md` — single source of truth for agent guidance (personas,
  conventions, skills index). `CLAUDE.md` defers to it.

## Skills

See [`AGENTS.md`](./AGENTS.md) for the annotated index. Highlights:

- **software-engineering**, **software-development-workflow**,
  **commit-message** — always-on defaults: atomic changes, clear ownership,
  tasteful commits.
- **solana-cicd-hash** — bundle CI artifacts, hash them, anchor the hash on
  Solana via a memo transaction, generate a PDF attestation, ship to S3.
- **cicd-golden-pipeline**, **inventium-cicd-pipeline** — reference CI/CD
  pipeline shapes.
- **clubstraylight-lambda**, **clubstraylight-tech-debt** — Lambda + CloudFront
  deploy patterns and the ongoing AWS tech-debt ledger.
- **deploy-commit-sha**, **update-actions-node-version**,
  **entertainment-disclaimer** — smaller focused skills.

## Using a skill elsewhere

Skills are self-contained directories. To adopt one in another repo, copy
`skills/<name>/` (or just the bits referenced by its `SKILL.md`) into the
target project and point your agent configuration at it. Skills that ship
runnable code (e.g. `solana-cicd-hash`) document their copy-in steps inside
their own `SKILL.md`.

## Local checks

```bash
npx markdownlint-cli2 "**/*.md"
terraform -chdir=terraform fmt -check -diff
terraform -chdir=terraform validate
```

## Conventions

See the Conventions section of [`AGENTS.md`](./AGENTS.md#conventions).
