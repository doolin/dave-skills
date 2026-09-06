# Renaming a project directory

Rename or move a repo's working directory (`~/src/old` → `~/src/new`)
without silently losing the agent's context or breaking its gates.
Reference run: `sabotage-1942` → `sabotage-1943`, 2026-09-06 — a rename
queued for three months, then executed outside a live session, with the
fallout found and repaired the next session.

**Sort the fallout by whether it warns you.** That is the whole method.
The loud breakage announces itself the first time you run anything and
costs a few minutes. The silent breakage costs a session's context and
gives no signal at all, so it goes first.

## Silent — fix these first

### Claude project memory is stranded

Memory is keyed by the working directory, encoded with every `/` as `-`:

    ~/.claude/projects/-Users-<user>-src-<repo>/memory/

A renamed repo gets a **fresh, empty** memory directory. An agent waking
there has no memories, no `MEMORY.md`, and **no way to detect the loss** —
it simply proceeds without its scroll. Nothing errors. This is the reason
this playbook exists.

Migrate, then repair the names inside:

1. Copy every `*.md` from the old project's `memory/` to the new one.
2. Rename any memory file named for the old project
   (`old-name-project.md` → `new-name-project.md`).
3. Fix that file's frontmatter `name:` and `description:`.
4. Repoint every `[[old-slug]]` wiki-link across *all* the memory files.
5. Fix the `MEMORY.md` index line — both its link text and its target.
6. Grep the memory directory for the old name and read each hit.

Step 6 needs judgment, not a scrub. A **stale pointer** ("the repo lives
at `~/src/old`") is a bug. A **historical note** ("renamed from `old` on
DATE, which broke X") is the record working as intended — keep it, and
add one if it isn't there.

### Docs that carry the rename as a pending task

The rename task outlives the rename. Whatever `NEXT.md`/`TODO`/ticket
said "rename this project" is now describing completed work as pending,
and the next agent will believe it. Same for anything else asserting the
old name as current.

While you are in that file, **check it for unrelated drift** — a resume
doc nobody has read since the rename was queued has usually rotted in
other ways too. In the reference run `NEXT.md` was a full work phase
behind: it named an already-built layer as the next step, listed half the
commits, and carried two architecture questions as open that had been
settled months earlier. Verify its claims against the source before
rewriting; don't just swap the name. Fable/Opus-class work — it requires
reading the code to know what is actually true.

## Loud — you find out on first run

### A Python venv does not survive a move

Every console script in `.venv/bin` carries an **absolute-path shebang**,
and `pyvenv.cfg` records the creation path:

    #!/Users/<user>/src/<old>/.venv/bin/python3.14

All of them fail with `bad interpreter: ... no such file or directory`,
which takes down every gate that shells through them. Recreate rather
than patch:

```sh
python3 -m venv --clear .venv          # use the SAME interpreter it was built from
.venv/bin/pip install -r requirements-dev.txt
```

Check `pyvenv.cfg`'s `home =` line for the original interpreter before
you start. The venv is gitignored, so nothing is committed.

### Absolute paths in local settings

`.claude/settings.local.json` accumulates allowlist entries with baked-in
absolute paths (`Bash(git -C /Users/.../old status --short)`). They can
never match again. Dead weight, not a failure — drop them. This file is
gitignored, so it is a local-only edit.

## Immune — verify, don't fix

- **Ruby/Bundler binstubs** are relative and come through untouched. In
  the reference run the engine gate passed unchanged, first try.
- **The git remote** is a URL, not a path.
- **The family graph** (`knowledge.json`) and the cross-project playbooks
  are usually already correct, especially if the rename was planned.
- **`~/.claude/history.jsonl`** records the old path forever. It is an
  append-only log. Leave it.

## Verify

1. `grep -rI '<old-name>' <repo> --exclude-dir=.git --exclude-dir=.venv`
   — expect zero hits.
2. Run the **full** gate, both halves, not just the one you touched.
3. `git status` — confirm the repair reformatted nothing.

Mostly Haiku-able mechanical work, except the drifted-docs pass above.

## What bites

**The repair smuggles in a toolchain bump.** Recreating a venv installs
whatever is current, not what was pinned in the old one. The reference
run came back with a newer OpenCV, numpy, and black across a patch bump
of Python itself. If the project has byte-pinned fixtures, that is the
moment to confirm they still match — they did there, which is a real
result about the emitters, but it was luck that it was checked. Run the
fixtures *and* `git status` after reinstalling, before concluding the
rename is clean.

**The old memory directory persists as a stale fork.** Copying leaves the
originals in place under the old project path. Harmless as a backup, but
it will drift from the live set. Decide explicitly: delete it, or
knowingly keep it.

**Check the commons/onboarding state while you are here.** A repo whose
identity just changed is worth checking against whatever family-wide
provisioning exists (`COMMONS.md` and friends). A rename does not break
it, but the audit is free once you are already looking.
