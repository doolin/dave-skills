---
name: software-engineering-workflow
description: Standard software engineering workflow for building features, fixing bugs, and making changes. Covers the full cycle from understanding requirements through CI-green PR.
disable-model-invocation: true
---

# Software Engineering Workflow

Follow this workflow for all code changes: features, bug fixes, refactors,
and chores.

## 1. Understand the work

- Read the issue or requirement fully before writing code
- Identify the acceptance criteria — what does "done" look like?
- Find the relevant code: grep for keywords, read the modules involved
- If anything is ambiguous, ask before coding

## 2. Branch

- Create a feature branch from the default branch
- Use a descriptive branch name: `<type>/<short-description>`
  - Types: `feat/`, `fix/`, `refactor/`, `chore/`, `docs/`

## 3. Make changes

- Work in small, focused commits — each one should compile and pass tests
- Write the test first when fixing a bug (red-green-refactor)
- Follow existing code style and patterns in the project
- Don't change code unrelated to the task

## 4. Validate locally

Run the full CI pipeline locally before pushing:

1. **Build** — confirm it compiles
2. **Test** — run the full test suite, not just your new tests
3. **Lint** — run the project's linter
4. **Format** — run the project's formatter

Fix anything that fails before moving on.

## 5. Commit

- Write clear commit messages: imperative mood, explain the "why"
- Keep commits atomic — one logical change per commit
- Don't bundle unrelated changes

## 6. Push and open PR

- Push the branch to the remote
- Open a PR with:
  - A short title (under 70 characters)
  - A summary describing what changed and why
  - A test plan — how to verify the change works
- Link the issue if there is one

## 7. Respond to review

- Address every comment — either fix it or explain why not
- Push fixes as new commits (don't force-push during review)
- Re-request review after addressing feedback

## 8. Merge

- Ensure CI is green
- Squash or merge per the project's convention
- Delete the feature branch after merge
