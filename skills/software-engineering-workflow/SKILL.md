---
name: software-engineering-workflow
description: Collaborative software engineering workflow establishing shared responsibilities between the developer and Claude. Covers the full cycle from understanding requirements through CI-green PR.
disable-model-invocation: true
---

# Software Engineering Workflow

A collaborative framework for making code changes. Each step identifies
who owns it: **Developer**, **Claude**, or **Together**.

## 1. Understand the work — Together

- **Developer**: Provides the issue, requirement, or description of the work
- **Claude**: Reads the issue, explores the relevant code, identifies
  acceptance criteria, and asks clarifying questions before writing code
- If anything is ambiguous, Claude asks — don't guess

## 2. Branch — Claude

- Create a feature branch from the default branch
- Use a descriptive branch name: `<type>/<short-description>`
  - Types: `feat/`, `fix/`, `refactor/`, `chore/`, `docs/`
- Never commit or push to the default branch — all work happens on feature branches

## 3. Make changes — Together

- **Developer**: Makes design decisions, approves direction
- **Claude**: Writes the code, following existing style and patterns
- Work in small, focused commits — each one should compile and pass tests
- Write the test first when fixing a bug (red-green-refactor)
- Don't change code unrelated to the task

## 4. Validate locally — Claude

Run the full CI pipeline locally before pushing:

1. **Build** — confirm it compiles
2. **Test** — run the full test suite, not just new tests
3. **Lint** — run the project's linter
4. **Format** — run the project's formatter

Fix anything that fails before moving on. Don't push broken code.

## 5. Commit — Claude

- Write clear commit messages: imperative mood, explain the "why"
- Keep commits atomic — one logical change per commit
- Don't bundle unrelated changes
- Never force push, never skip hooks

## 6. Push and open PR — Together

- **Claude**: Pushes the branch to the remote
- **Claude**: Opens a PR only when the developer asks for one
- PR should have:
  - A short title (under 70 characters)
  - A summary describing what changed and why
  - A test plan — how to verify the change works
  - Link to the issue if there is one
- **Developer**: Reviews the PR description before it goes up

## 7. Code review — Together

- **Developer**: Reviews the code, leaves comments
- **Claude**: Remediates all review comments — fix the code, push
  new commits, and confirm each comment is addressed
- Push fixes as new commits (don't force-push during review)
- **Developer**: Re-reviews and approves

## 8. CI enforcement — Claude

CI must pass before merging. This is non-negotiable.

- All builds, tests, linting, and formatting must be green
- If CI fails, fix it — don't merge around it
- **Audit trail (optional)**: Projects may use attestation mechanisms to
  create a verifiable record of CI/CD results. Supported mechanisms include:
  - Solana blockchain (on-chain memo of artifact hashes)
  - OpenTimestamps (timestamp proof of build artifacts)
  - Other mechanisms as configured per project
- When attestation is configured, CI bundles all artifacts and posts
  the hash before merge is allowed

## 9. Merge — Developer

- **Developer**: Merges when CI is green and review is approved
- Squash or merge per the project's convention
- Delete the feature branch after merge
