# Tooling catalog

A cross-project index of the tools and skills available to Herman's
agents, so they're reachable everywhere instead of rediscovered per
project. One line each: **name → when to reach for it → model class**.

Model class is the *minimum* that does the job well: **Haiku** for
mechanical/lookup, **Sonnet** for ordinary judgment, **Fable-class** for
ambiguous design/orchestration calls. "any" means it's a plumbing tool
the class doesn't matter for.

---

## Orchestration & subagents

- **Agent** → delegate a scoped sub-task or fan-out search to a fresh
  context (Explore for read-only search, Plan for design, general-purpose
  for multi-step). Reach for it when a job would flood the main context
  or splits into independent parallel work. → any (picks its own class)
- **Workflow** → deterministic multi-agent orchestration (loops, fan-out,
  pipeline/parallel stages, adversarial verify). Use for comprehensive
  sweeps, audits, migrations, or anything one context can't hold. ONLY
  when the user explicitly opts in. → Fable-class to author the script.
- **TaskCreate / Get / List / Update / Stop / Output** → track or run
  background work as discrete tasks; check progress and collect output.
  Reach for it on multi-step jobs worth a visible checklist. → any
- **EnterWorktree / ExitWorktree** → isolate file-mutating work in a
  throwaway git worktree so parallel agents don't collide. Costly setup;
  use only when something actually writes in parallel. → any
- **EnterPlanMode / ExitPlanMode** → enter read-only planning, then
  present a plan for approval before editing. Use for non-trivial changes
  the user should sign off on first. → Sonnet+

## Scheduling & notification

- **schedule** (skill) / **CronCreate / Delete / List** → create/manage
  cloud agents that run on a cron schedule (or a one-time future run).
  Reach for it for recurring or deferred automation. → Sonnet+
- **loop** (skill) → run a prompt/slash-command on a repeating interval
  in THIS session (polling, babysitting). Not for one-offs. → any
- **Monitor** → block until a shell condition becomes true (wait on CI, a
  deploy, a queue) without burning turns polling. → any
- **PushNotification** → ping the user out-of-band when long work
  finishes or needs a decision. → any
- **RemoteTrigger** → fire a registered remote trigger/webhook. → any

## Web & research

- **WebSearch** → fan-out queries for current/external facts. Never
  answer LLM/pricing/API questions from memory — search. → any
- **WebFetch** → pull and read a specific URL's content. → any
- **deep-research** (skill) → multi-source, adversarially-verified, cited
  research report. Narrow the question first (ask 2-3 clarifiers if
  vague). → Fable-class for synthesis.

## Code review & quality

- **code-review** (skill) → review the current diff for correctness bugs;
  effort low→ultra (ultra = multi-agent cloud). User-triggered/billed.
  → Sonnet+ (ultra is its own fleet)
- **simplify** (skill) → apply reuse/simplification/efficiency cleanups to
  changed code. Quality only, no bug hunting. → Sonnet
- **security-review** (skill) → security pass over pending branch changes.
  → Fable-class
- **verify** / **run** (skills) → actually launch the app and observe a
  change working (verify = confirm a fix/PR; run = just start/screenshot
  it). Use before claiming something works. → Sonnet
- **watch-ci** (skill) → watch the latest GHA run on the branch until it
  finishes; launch in background right after every push. → any
- **pr-watch-check** (skill) → watch ALL checks on the branch's PR, then
  keep watching until it merges/closes — one background task covers the
  checks→merge arc; prefer over watch-ci whenever a PR is open. → any
- **mece-review** (skill) → check a doc/category set for overlap and gaps
  (Mutually Exclusive, Collectively Exhaustive). → Sonnet+
- **document-drift** (dave-skill) → audit a repo for stale docs: broken
  cross-refs, outdated lists, orphaned mentions, doc-vs-code drift.
  Produces a report + optional fixes. Ideal after a big change. → Sonnet

## Commits & engineering discipline

- **tasteful-commits** / **commit-message** (skills) → craft well-formed
  commit messages (52-57 char imperative summary, why-not-what body,
  co-author trailer). → any
- **extractable-commits** (skill, user-level) → decide commit BOUNDARIES:
  split a session's mixed work so each reusable unit (tool, harness, fix,
  lesson) is its own cherry-pickable commit. Pairs with the above for
  wording. → Sonnet+
- **shell-hygiene** (skill, user-level) → run Bash cleanly/autonomously:
  operate from the working dir without cd-ing into it, scope dir changes
  to a subshell, remember env never persists across calls (cwd does),
  prefer self-locating gate wrappers. Parameterized by project. → any
- **software-engineering** (skill) → principles for atomic, minimal,
  meaningful changes; commit hygiene, public vs private history, testing.
  → reference, any
- **software-development-workflow** (dave-skill) → the collaborative
  dev cycle from requirements to CI-green PR; shared dev/Claude
  responsibilities. → reference, any
- **fewer-permission-prompts** (skill) / **update-config** (skill) →
  mine transcripts for a safe allowlist / edit settings.json (perms,
  hooks, env, automated behaviors). Reach for "from now on when X". → any

## Session & project management

- **pause-session** (dave-skill) → before stepping away, write a resume
  brief to `.development/next.md` with a paste-ready starter prompt.
  → Sonnet
- **self-host-development-light** (dave-skill) → lightweight markdown
  project management in `.development/` (backlog, planning, todo,
  roadmap, saved plans). → any
- **next-ticket** (dave-skill) → next available ticket id for the current
  repo; auto-detects the prefix (DBB/CSL/OC/...) from `.development/`, so
  one skill serves every Straylight repo. → any
- **gem-update** (dave-skill) → Ruby gem stewardship pass: buckets
  outdated gems patch/minor/major, batch-applies patch bumps, runs the
  bundler-audit/brakeman/rubocop/rspec gauntlet. Any Ruby/Rails repo. → any
- **clean-worktrees** (skill) → remove integrated agent worktrees and
  their branches; run at session close or after worktree waves. → any
- **linear-walkthrough** (dave-skill) → build a structured Showboat code
  walkthrough (read source → plan → annotated, verified snippets).
  → Sonnet+

## Frontend & visualization

- **frontend-design** (skill) → distinctive, production-grade UI that
  avoids generic "AI slop"; commit to a bold aesthetic. The web-viewer
  work used this. → Sonnet+
- **html-color-swatches** / **terminal-color-swatches** (dave-skills) →
  render a palette for review — standalone HTML page (browser) or ANSI
  truecolor swatches (terminal). → Haiku
- **DesignSync** → sync a claude.ai design system into the project (read
  the `/design-sync` skill before using). → Sonnet+

## CI/CD & infra (Ruby/AWS/Solana stacks — see dave-skills)

- **cicd-golden-pipeline** → reusable GHA pipeline with NIST SSDF / EO
  14028 / OMB compliance: secrets scan, SBOM, OSCAL, provenance, S3,
  Solana attestation. → Fable-class to adapt
- **inventium-cicd-pipeline** → house check/attest/deploy pipeline shape
  for adding/standardizing an Inventium repo. → Sonnet
- **solana-cicd-hash** / **deploy-commit-sha** / **add-build-sha** →
  attest a CI run on Solana; surface the deployed commit SHA on a page.
  → Sonnet
- **update-actions-node-version** → bump GHA to newer Node when
  deprecation warnings appear (pinned SHAs, Node24 workaround). → Haiku
- **clubstraylight-lambda** / **clubstraylight-tech-debt** /
  **add-database-backup** / **add-shamrock-link** → clubstraylight AWS
  Lambda app creation, infra tech-debt tracking, and site-specific
  add-ons. → Sonnet
- **new-gem** / **close-ticket** / **commit-spike** / **add-shamrock-link**
  → Ruby project bootstrap and ticket/workflow helpers. → Sonnet

## Notebooks & integrations

- **NotebookEdit** → edit Jupyter notebook cells. → any
- **mcp__claude_ai_Gmail / Google_Calendar / Google_Drive** →
  authenticate, then read/act on the user's Gmail, Calendar, Drive.
  Absent in headless/cron runs (interactive auth). → any

---

Related: `map-digitization.md` (the scan→SVG→graph method this catalog
sits beside). The deferred tools above load via `ToolSearch` with
`select:<name>` before first call.
