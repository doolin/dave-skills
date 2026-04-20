---
name: linear-walkthrough
description: Create a structured code walkthrough using Showboat. Agent reads source, plans a linear explanation, then builds the document with showboat note for commentary and showboat exec for verified code snippets.
---

# Linear Walkthrough

Build a structured walkthrough of code that explains how it
works in detail, using Showboat to mix commentary with
verified code snippets. Based on Simon Willison's agentic
engineering pattern.

## When to use

- Onboarding: explaining a codebase to a new developer.
- Documenting a CI/CD pipeline, deployment process, or
  architecture for stakeholders.
- Capturing how "vibe coded" projects actually work before
  you forget.
- Creating a presentation-ready document from existing code.

## Why Showboat

Showboat solves the hallucination problem. Instead of manually
copying code into a document (risking errors), `showboat exec`
runs shell commands and captures real output. The document is
both readable and verifiable — `showboat verify` re-runs every
code block and diffs the output.

## Process

### 1. Read and plan

Read the source files that will be covered. Plan the
walkthrough as a linear narrative — the reader should be able
to follow from top to bottom without jumping around. Identify
the natural order: entry point first, then each stage or
component in execution order.

### 2. Initialize

```bash
uvx showboat init <file>.md "<Title>"
```

### 3. Build the document

Alternate between commentary and code:

- **`uvx showboat note <file>.md "<text>"`** — add markdown
  commentary explaining what comes next and why it matters.
- **`uvx showboat exec <file>.md bash "<command>"`** — run a
  command and capture the output. Use `sed`, `grep`, `cat`,
  or `head` to extract the relevant snippet. Never manually
  copy code into a note — always use exec.

### 4. Fix mistakes

If a command produces wrong output or an exec block is
unnecessary:

```bash
uvx showboat pop <file>.md
```

Removes the most recent entry. Re-do it correctly.

### 5. Verify

```bash
uvx showboat verify <file>.md
```

Re-runs every code block and confirms outputs still match.
Run this before committing.

## Code snippet conventions

- Use `sed -n 'START,ENDp'` for exact line ranges.
- Use `grep -n` or `grep -A` for pattern-based extraction.
- Use `head -N` for file headers.
- Keep snippets focused — show the relevant 10-30 lines, not
  the entire file.
- When showing dependencies or structure, `grep` for key
  patterns rather than dumping the full file.

## Commentary conventions

- Lead each section with a heading (`## Section Name`).
- Explain the *why* before showing the *what*.
- Call out pitfalls, non-obvious design decisions, and
  regulatory/compliance mappings.
- Keep paragraphs short — this is documentation, not prose.

## Walkthrough structure

A typical walkthrough follows this skeleton:

1. **Introduction** — what the code does, who it's for.
2. **Architecture overview** — high-level structure, phases,
   dependencies.
3. **Linear walk** — each component in execution order, with
   code snippets and explanations.
4. **Summary** — what the reader should take away.

## Example prompt

> Read the CI pipeline files and plan a linear walkthrough
> explaining how the pipeline works. Use `uvx showboat` to
> build the document — `showboat note` for commentary and
> `showboat exec` with sed/grep/cat to include verified code
> snippets. Never manually copy code into notes.

## Cross-references

- [Simon Willison: Linear Walkthroughs](https://simonwillison.net/guides/agentic-engineering-patterns/linear-walkthroughs/)
- [Showboat](https://github.com/simonw/showboat)
- `cicd-golden-pipeline` — reference pipeline documented
  with this pattern in javasprang
