# CLAUDE.md

## Project overview

dave-skills is a collection of reusable Claude Code skills. Skills live
at `skills/<kebab-name>/SKILL.md` — intentionally at the top level, not
in `.claude/`, for portability and extraction.

## Skills in this repo

- **software-engineering** — The discipline: atomic and minimal changes,
  commit hygiene, public vs private history, testing, code quality.
  Auto-invoked by Claude.
- **software-development-workflow** — The process: collaborative
  framework with clear ownership (Developer, Claude, Together) for
  each step from requirements through merge. Auto-invoked by Claude.
- **commit-message** — Commit message conventions from tasteful-commits
  gist. 52-57 char line targets, templates per change type, co-author
  credit. Auto-invoked by Claude.
- **solana-cicd-hash** — Bundle all CI/CD artifacts, hash them, generate
  PDF attestation report, post root hash to Solana, upload to S3.
- **deploy-commit-sha** — Placeholder. Display deployed git commit SHA
  on a web page. Implementation to be ported from local machine.

## Conventions

- Skills use SKILL.md with YAML frontmatter (name, description)
- `disable-model-invocation: true` for manual-only skills
- Claude never pushes to master/main — all work on feature branches
- CI: markdownlint runs on all PRs (pinned to commit SHA, least-privilege permissions)
- Commit messages follow tasteful-commits: imperative mood, 52-57 char
  summary, body explains the why, co-author credit for Claude
- Lint before committing: `npx markdownlint-cli2 "**/*.md"`

## Related repos to investigate

- **doolin/dbb** — Has CI/CD hash implementation (private, needs MCP access)
- **doolin/slacronym** — Has CI/CD hash implementation (private, needs MCP access)

## Blog references

- [Atomic and minimal](http://dool.in/) — SRP for commits
- [Git commit hygiene](http://dool.in/2022/05/13/git-commit-hygiene.html) — rebase/squash, clean linear history
- [Git public vs private history](http://dool.in/2022/01/30/git-public-vs-private-history.html) — public history as an asset
- [tasteful-commits gist](https://gist.github.com/doolin/32d0430388405765e508c150831c4ac8) — commit message conventions
