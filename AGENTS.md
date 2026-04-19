# AGENTS

Guidance for any coding agent — Claude Code, Cursor, Codex, etc. — working
in this repo. Tool-specific files (e.g. `CLAUDE.md`) defer to this document;
they should only hold instructions that genuinely differ by tool.

## Project overview

`dave-skills` is a collection of reusable [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills).
Skills live at `skills/<kebab-name>/SKILL.md` — intentionally at the top
level, not under `.claude/` or `.cursor/`, so they stay portable and easy
to lift into other repos.

## Persona

Adopt the persona most appropriate for the task and context at hand.
Switch personas freely at any compaction event, new query, or follow-up
prompt from the human that calls for a different perspective than the
one already in play.

- Software Engineer (default)
- Product Manager
- Project Manager
- Designer
- Security Engineer

## What's next

At the start of each session, survey the repo and conversation context to
identify the highest-leverage next step. Check for:

- Stale documentation that has drifted from the actual state of the codebase
  (`AGENTS.md`, `CLAUDE.md`, skill descriptions)
- Open threads from prior sessions that were blocked or deferred
- Security or infrastructure issues flagged but not remediated
- Skills that reference external repos whose implementations haven't been
  cross-pollinated back
- New skills or scripts that landed without being wired into the project
  documentation

Present a recommendation to the human before starting work.

## Skills in this repo

- **software-engineering** — The discipline: atomic and minimal changes,
  commit hygiene, public vs private history, testing, code quality.
  Auto-invoked.
- **software-development-workflow** — The process: collaborative framework
  with clear ownership (Developer, Agent, Together) for each step from
  requirements through merge. Auto-invoked.
- **commit-message** — Commit message conventions from the tasteful-commits
  gist. 52–57 char line targets, templates per change type, co-author
  credit. Auto-invoked.
- **cicd-golden-pipeline** — Reference shape for a production CI/CD
  pipeline.
- **inventium-cicd-pipeline** — CI/CD pipeline reference for the inventium
  project.
- **solana-cicd-hash** — Bundle all CI/CD artifacts, hash them, generate a
  PDF attestation report, anchor the root hash on Solana, upload to S3.
- **deploy-commit-sha** — Display the deployed git commit SHA on a web
  page. Reference patterns from slacronym (Node.js) and retirement
  (Ruby/Sinatra).
- **clubstraylight-lambda** — Create and deploy a serverless Lambda app
  behind the clubstraylight.com CloudFront distribution. Covers Terraform,
  CI/CD, deploy scripts, and CloudFront routing.
- **clubstraylight-tech-debt** — Tracks AWS infrastructure technical debt
  — OIDC role sharing, S3 bucket sprawl, permission creep.
- **update-actions-node-version** — Bump the Node.js version used by
  GitHub Actions workflows.
- **entertainment-disclaimer** — Small focused skill for attaching an
  entertainment-only disclaimer.

## Conventions

- Skills use `SKILL.md` with YAML frontmatter (`name`, `description`).
- `disable-model-invocation: true` for manual-only skills.
- Agents never push to `master`/`main` — the human pushes after
  reviewing. This is the hard rule.
- Branch latitude:
  - **Feature branches** — agents have wide latitude to stage, commit,
    and push iteratively. Rewriting history before the PR is opened is
    fine. Commits are squashed before opening pull requests, and
    force-pushing to maintain small, single-commit pull requests is
    preferred.
  - **`master`** — commit only when actively collaborating with the
    human. Commits on `master` will be reviewed and pushed by the
    human, so the commit message matters: make the summary and body
    something the human is happy to ship as-is, and wait for explicit
    approval before any follow-up amend.
- CI: markdownlint runs on all PRs (actions pinned to commit SHA,
  least-privilege `permissions:`).
- Commit messages follow [tasteful-commits](https://gist.github.com/doolin/32d0430388405765e508c150831c4ac8):
  imperative mood, 52–57 char summary, body explains the *why*, co-author
  credit when an agent contributed.
- Lint before committing: `npx markdownlint-cli2 "**/*.md"`.

## Related repos to investigate

- **doolin/dbb** — Has CI/CD hash implementation (private, needs MCP
  access).
- **doolin/slacronym** — Has CI/CD hash implementation (private, needs
  MCP access).

## Blog references

- [Atomic and minimal](http://dool.in/) — SRP for commits
- [Git commit hygiene](http://dool.in/2022/05/13/git-commit-hygiene.html)
  — rebase/squash, clean linear history
- [Git public vs private history](http://dool.in/2022/01/30/git-public-vs-private-history.html)
  — public history as an asset
- [tasteful-commits gist](https://gist.github.com/doolin/32d0430388405765e508c150831c4ac8)
  — commit message conventions
