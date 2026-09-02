# AGENTS

Guidance for any coding agent — Claude Code, Cursor, Codex, etc. — working
in this repo. Tool-specific files (e.g. `CLAUDE.md`) defer to this document;
they should only hold instructions that genuinely differ by tool.

## Project overview

`dave-skills` is a collection of reusable [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills).
Skills live at `skills/<kebab-name>/SKILL.md` — intentionally at the top
level, not under `.claude/` or `.cursor/`, so they stay portable and easy
to lift into other repos.

## Playbooks

`playbooks/` holds cross-project reference procedure — harvested,
hard-won process write-ups (map digitization, counter-sheet
extraction, framework migration, ...). Playbooks are NOT skills:
no `SKILL.md` frontmatter, never client-invoked; an agent Reads
one before starting matching work. The operator's global
`CLAUDE.md` indexes them by path.

Symlink contract: `~/.claude/playbooks` is ONE whole-directory
symlink to this repo's `playbooks/` (unlike skills, which link
per-directory into `~/.claude/skills/`). Playbooks have exactly
one source, and a new playbook committed here appears at
`~/.claude/playbooks/<name>.md` without re-linking. Every
playbook path referenced elsewhere resolves through that
symlink — renaming or removing a playbook breaks those
references, so treat filenames as public API.

## Hooks

`hooks/` holds Claude Code lifecycle hooks shared across repos, with
their bats tests under `hooks/test/`. Hooks are NOT skills: no
`SKILL.md`, never client-invoked; the harness runs them on an event
named in a repo's `.claude/settings.json`.

Symlink contract: hooks link **per file** from the consuming repo's
`.claude/hooks/<name>.sh` to `hooks/<name>.sh` here, because that
directory also holds the repo's own local hooks. The consuming repo
registers the local path and commits the symlink. See
`hooks/README.md`.

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
- Whether `.development/` is scaffolded per the self-host-development-light
  skill; run setup if not

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
- **banned-words** — The operator's banned-words list: words that
  read as bafflegab, filler, or euphemism, each with scope,
  replacements, and carve-outs. Applies to all agent-produced
  prose; grows by operator decree.
- **cold-reader** — Editorial precepts for durable documents
  (reports, ADRs, PRDs, design docs): write for the reader who
  holds only the artifact and its citations, not the session that
  produced it. Generalizes the commit-message anti-patterns; ends
  with a four-sweep audit to run before a document ships or
  prints.
- **document-drift** — Audit a repo for stale documentation: broken
  cross-references, outdated indexes, orphaned mentions, and drift
  between docs and the actual codebase.
- **index-drift-audit** — Keep a `.development/` document set from
  rotting silently: an auditor-managed `INDEX.md` manifest plus a
  deterministic reconciler that flags orphaned, missing, and stale
  documents. Cheap enough for a recurring small-model pass.
- **json-diff** — Structural (semantic) diff of two JSON files in
  pure-stdlib Ruby: parses both and compares as data, so key order
  and formatting never register. Reports changed/added/removed paths;
  exit code doubles as a script guard.
- **linear-walkthrough** — Create a structured code walkthrough using
  Showboat. Reads source, plans a linear explanation, builds the document.
- **pause-session** — Capture session context and next steps before
  stepping away, keyed to the ticket or thread the work advanced. In a
  full-form `.development` repo it updates the ticket's `## Next` in
  place (read back by `hooks/session-resume.sh`); in the light form it
  writes a `threads/` file plus the `next.md` index.
- **index-audit** — One-shot audit of the git index before a commit:
  staged diffstat, warnings for never-commit paths (env files, keys,
  logs, coverage, tmp), and the changes left outside the index. Runs
  in place of the `git diff --cached --stat` + `git status --short`
  pair, in any repo, `-C DIR` for a sibling.
- **rspec-summary** — Digest a full rspec run into the lines that
  decide the pre-commit gate: example tally, SimpleCov line and branch
  totals, coverage-floor breach, failures grouped by spec directory.
  `--run` runs the suite through it. Any rspec + SimpleCov repo.
- **self-host-development-light** — Lightweight self-hosted project
  management using markdown files in `.development/` — one file per
  concern (roadmap, backlog, todo, changelog, decisions, requirements,
  design, stewardship, lessons learned, operator capture) plus saved
  plans, with the rule for growing any concern into its full
  directory form.
- **development-with-ticketing** — Marisu's fork of
  self-host-development-light (copied as-is 2026-07-02), to be
  extended in place for Jira-tracked development (GEN-### commits via
  marisu-jira). Expect it to diverge; the light skill stays
  ticket-free.
- **session-telemetry** — Append-only JSONL session event log for
  agent efficacy review: session boundaries, commits, ticket
  transitions, blockers, and lapses, with a hypothesis-report
  stopping rule. Status: proposal.
- **update-family-graph-entry** — Correct your own entry in the family
  knowledge graph (knowledge.json in clubstraylight.com): mechanical
  corrections only, every graph location, validated, one
  CSL-0027-prefixed commit, never pushed. Manual-load and rarely
  needed — only when the operator asks you to bring your entry
  current.

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
- Check before committing: `scripts/check` (markdownlint at the
  CI-pinned version, shellcheck, every bats suite). Self-locating, so
  it runs from another repo's cwd without a `cd` chain.

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
