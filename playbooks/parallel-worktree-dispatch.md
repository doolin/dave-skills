# Parallel worktree dispatch

How to run two or more subagents at once, each in its own git worktree,
and get their work onto main without losing any of it. Read BEFORE any
dispatch with `isolation: "worktree"` where more than one agent will run
at the same time, and before the first worktree dispatch in a repo you
have not done this in. Reference impl: dbb — `scripts/dispatch-preflight`,
`scripts/integrate-worktree`, `~/.claude/skills/clean-worktrees`, and the
DBB-0244 Network Lab epic (2026-05-23, five worktrees, one 25-call
conflict) that produced most of what follows.

Everything here was learned by losing work or tokens to it. The order is
the order you will meet them.

## The facts that shape the pipeline

1. **Subagents cannot commit.** The sandbox blocks `git commit`, `git mv`,
   `git rm` and most other git mutations regardless of what the
   allowlist says. The subagent leaves staged changes in its worktree;
   the orchestrator owns the commit and the cherry-pick. This is a clean
   cost split, not a limitation to work around: the expensive agent does
   the work, the orchestrator does thirty seconds of bookkeeping.

2. **Worktree isolation is CWD isolation, and absolute paths bypass it.**
   The subagent's shell and tools resolve relative paths against
   `.claude/worktrees/agent-<id>/`. A brief that names
   `/Users/you/src/repo/app/foo.rb` sends the write to main's tree; the
   worktree is created, locked, and never touched. Symptom: the agent's
   output appears in main's `git status` as uncommitted edits and the
   worktree is empty. Three incidents before the cause was found (dbb
   DBB-0418, DBB-0253, DBB-0419). **Repo-relative paths only, for every
   work target.**

3. **Worktree creation can fail silently above about five concurrent
   dispatches.** Concurrent `git worktree add` calls race on the `.git`
   index lock; the harness does not fail fast, the agent runs in the
   parent's CWD, writes land on main, and the agent reports success
   (dbb DBB-0422: 11 dispatched, 1 leaked). The brief carries a guard,
   run before the first write:

   ```bash
   [[ $PWD == */.claude/worktrees/* ]] || { echo "ERR: expected worktree CWD, got: $PWD" >&2; exit 1; }
   ```

4. **A worktree's base can lag main.** `git worktree add` captures HEAD
   at creation, and empirically that HEAD can predate a cherry-pick that
   already landed — even when the dispatch call is issued afterwards. A
   dependent agent then re-derives its dependency's work from the old
   base, and the cherry-pick conflicts at integration time, when context
   is high (dbb DBB-0251). **Dispatch a dependent only after its
   dependency's cherry-pick is on main and main is green.** Wave the
   dependency graph; within a wave, nothing depends on anything else in
   it.

5. **Two agents appending to the end of the same file collide.** Git's
   auto-merge alternates their blocks into four-plus conflict zones
   (dbb DBB-0255, a spec file, ~25 tool calls to resolve). Either
   serialize, or pre-place named anchor markers in the shared file so
   each agent appends between its own pair:

   ```erb
   <%# DBB-NNNN:START %>
   <%# DBB-NNNN:END %>
   ```

   ```js
   // ── DBB-NNNN tests ────────────
   ```

   Appends between anchors merge as pure additions.

6. **Lint from main, never from inside a worktree.** RuboCop treats any
   path containing `/.` as hidden and bypasses `AllCops/Exclude`
   entirely (`target_finder.rb`, `HIDDEN_PATH_SUBSTRING`); a run from
   `.claude/worktrees/<id>/` reports hundreds of phantom offenses that
   no `.rubocop.yml` change can suppress. Treat a worktree's lint output
   as advisory. The real run happens on main after the cherry-pick.

7. **Background subagents cannot prompt, so an unlisted tool is a silent
   denial.** Anything not in `permissions.allow` auto-fails with no
   surfaced prompt. Foreground subagents can prompt. Approvals the
   orchestrator accepted this session are **not** inherited — every
   subagent starts fresh. Three misreads follow from this:
   - *"Bash is denied"* usually means one destructive shell pattern was
     denied after an Edit/Write denial pushed the agent to `cat >` or
     `sed -i`. Probe `pwd`, `ls`, `git status` separately when triaging.
   - Agents will invoke `fewer-permission-prompts` or `update-config` to
     "fix" a denial themselves and burn the dispatch. The brief says not
     to invoke any skill.
   - Agents will decline pre-emptively — "I need Bash permission" —
     without having tried, when a brief lists many shell commands and
     sounds uncertain. Say the patterns are pre-approved and to attempt
     each step and report what happens.

8. **Reported success is not verified success.** Agents, Haiku in
   particular, have reported "cannot run checks due to permissions" while
   the checks, run by the orchestrator, found real failures; and have
   reported "verified empirically" without a measurement. Every brief
   that asks for a check asks for the check's output in the report. The
   orchestrator runs the repo's full gate on the integrated result
   regardless.

9. **Negative instructions are weak.** "Do NOT draft a commit message"
   produced a commit message; the agent matched the verb and did the
   thing. Phrase every instruction as the positive action: "end the run
   with everything staged and a one-line summary in the final report."

10. **Delegation is strictly downward.** The orchestrator's tier
    delegates to lower tiers only; Haiku is terminal. An agent that finds
    its task is above its tier surfaces and stops rather than spawning
    upward. Cost decreases monotonically down the tree and the tree
    terminates. The brief names the tier explicitly; without that line
    agents default unpredictably.

## Model classes

| Work | Tier |
| --- | --- |
| Mechanical sweeps — component flips, frontmatter audits, render-and-check a page in a browser | Haiku |
| Implementation on an established pattern with a written spec | Sonnet |
| Novel architecture, multi-system reasoning, the orchestrator itself | Opus / Fable |

Choose on task complexity at dispatch time, not on convenience. A fresh
Haiku that reads five files and then asks for permission it already has
is a brief problem (fact 7), not a tier problem.

## The pipeline

### Stage 0 — Preflight

Run the repo's collision predictor (dbb: `scripts/dispatch-preflight
<ticket>...`), which reads each ticket's *files likely affected* and
reports any path two tickets both claim. A collision found here costs
nothing; the same collision at cherry-pick time cost ~25 tool calls once.
Then wave the tickets by dependency: wave 1 has no dependencies; wave 2
depends only on wave 1; and so on. Two tickets that touch the same file
are either in different waves or get anchor markers (fact 5).

### Stage 1 — The brief

Every worktree brief carries, in this order:

- **Tier line.** "You are a Sonnet-class agent; do not delegate."
- **CWD guard** (fact 3), to run before the first write.
- **Repo-relative paths only** for every file the agent will touch
  (fact 2). Absolute paths are acceptable only for resources outside the
  repo the agent must read — memory files, references.
- **The repo's pre-commit tools, enumerated**, with the exact
  invocations and the note that they are pre-approved (fact 7). For dbb
  that is the `scripts/gate` step list; for any repo, the gate is the
  source of truth and the brief copies it rather than paraphrasing.
  Include the repo's known traps in the same block — for dbb, never pass
  `.erb` files to `bin/rubocop`.
- **What to do with checks:** run them, include the output in the final
  report (fact 8).
- **The ending:** "stage everything and stop; put the suggested commit
  message in your final report" (facts 1 and 9). Never "commit".
- **Two prohibitions, phrased as what to do instead:** work only in the
  files named; report a permission failure with the command that failed
  rather than invoking any skill (fact 7).
- **Anchor markers** if the ticket shares a file with another in the
  wave (fact 5).

### Stage 2 — Dispatch

Send the whole wave in one message — one `Agent` call per ticket, all
`isolation: "worktree"`, all `run_in_background: true`. Calls in one
message run concurrently; calls in successive messages serialize. Keep a
wave at five or fewer unless you accept the leak risk in fact 3 and will
check for it.

### Stage 3 — Verify before integrating

When a wave completes, and before touching any worktree:

1. `git status --short` on main. Anything the agents were supposed to
   write, appearing here, is a leak (fact 2 or fact 3). The work is
   salvageable — commit it from main — but the brief is wrong and the
   worktree is a ghost to remove.
2. `git worktree list`. Every dispatched agent id should have one.
3. For each worktree, `git -C <worktree> status --short` — the staged set
   is what you are about to commit.

### Stage 4 — Integrate, one worktree at a time

The cycle is fixed; script it (dbb: `scripts/integrate-worktree
<agent-id> -m "<message>"`):

1. Commit in the worktree, with the full co-author trailer.
2. Cherry-pick onto main.
3. Run the repo's **full** gate on main (fact 6, fact 8). Not the
   agent's report of it; the merge itself creates defects — duplicated
   targets, a missing brace — that no single side had.
4. Only then the next worktree.

On a cherry-pick conflict: the worktree commit is in the reflog even
after `git branch -D`. When the conflict is content-vs-content on a file
the worktree built from scratch and the agent likely re-derived the
dependency's scaffolding (fact 4), `git checkout --theirs <file>` takes
the worktree's version whole; then run the gate before amending. Do
**not** `cp` files from a worktree to main as a shortcut — it works for
one pending integration and breaks the moment a second worktree's
cherry-pick collides with the file you already copied.

Push is a separate consent gate from commit in every repo that follows
this convention; the integration script's `--push` is opt-in.

### Stage 5 — Clean

Remove integrated worktrees and their branches (dbb:
`~/.claude/skills/clean-worktrees`). The tool skips anything with
uncommitted content and anything unintegrated without `--force`; that is
the safety, so do not bypass it by hand.

## Non-negotiables

- Relative paths in briefs. Always.
- The CWD guard in every brief above two concurrent dispatches.
- Dependents dispatch after the dependency is on main and main is green.
- The orchestrator commits; the agent stages and stops.
- The full gate runs on main after every cherry-pick, whatever the agent
  reported.
- Lint from main, never from a worktree.
- Downward delegation only; the brief names the tier.

## Anti-patterns

- Serial round-trips — `git status`, then a Read, then a Bash, each in
  its own turn — when none depends on another. The operator's wall-clock
  cost is the same for one call or four in a turn.
- "Let me check first" as a reason not to parallelize. If the worst case
  of a parallel attempt is that you learn something, go.
- Trusting "verified" without the measurement in the report.
- A brief that says "do not X". Say what to do.
- Copying worktree files to main by hand.

## Adapting to a new repo

The facts hold everywhere the Claude Code harness does; the scripts are
dbb's. A new repo needs, at minimum: a gate command the brief can name
(even if it is three lines), a collision check (grep the tickets' file
lists by hand until it hurts), and an integration script once the cycle
has run twice by hand. Write the anchor-marker convention into the
repo's AGENTS.md the first time two agents share a file.
