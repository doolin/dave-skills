# AGENTS — rfcs/0001-cicd-golden-pipeline

This directory holds the mermaid source and rendered artifacts for a
CI/CD golden pipeline diagram intended for external use in an RFC.
The RFC prose itself lives outside this repo; only the diagram source
is maintained here.

The repo-wide [`AGENTS.md`](../../AGENTS.md) still applies. Guidance
below is scoped to this directory.

## Canonical skill

The diagram is a visual summary of the **`cicd-golden-pipeline`**
skill at [`skills/cicd-golden-pipeline/SKILL.md`](../../skills/cicd-golden-pipeline/SKILL.md).
That skill is the source of truth for the pipeline's structure, job
names, `needs:` edges, regulatory mapping, and caller workflow
(`ci-cd.yml`) shape. If the skill and this diagram disagree, the
skill wins — update the diagram to match.

## When to rebuild

Regenerate the rendered artifacts any time the upstream skill changes
in a way the diagram should reflect:

- Job added, removed, or renamed in `golden-pipeline.yml`
- `needs:` edges or `workflow_call` topology change
- Regulatory mapping changes (PW.*, M-22-18, M-24-15, M-21-31, etc.)
- Caller workflow (`ci-cd.yml`) deploy / attest shape changes
- Main-branch gating policy changes

Check for drift whenever `skills/cicd-golden-pipeline/SKILL.md` is
touched. Open `pipeline.mmd`, sync it to the skill's Architecture
section, then `make` to regenerate `pipeline.png` and `pipeline.svg`
locally and verify the render before committing the updated source.

## Rebuild

```bash
make          # regenerate pipeline.png and pipeline.svg
make clean    # remove rendered artifacts
```

Uses `@mermaid-js/mermaid-cli` via `npx` — no local install required,
but the first run will download Puppeteer / Chromium. Requires a
working Node.js (this repo targets Node 24).

## Conventions for this directory

- `pipeline.mmd` is the single source; never hand-edit `.png` / `.svg`.
- Rendered `.png` / `.svg` are **git-ignored** (see `rfcs/.gitignore`)
  — they are derived artifacts. Run `make` to regenerate them
  locally; attach the rendered file(s) directly to the RFC rather
  than version-controlling them here.
- Keep the diagram readable at RFC page width (~800 px). If it grows
  past that, split into layered diagrams rather than shrinking text.
- No colors tied to branding — RFC renderings should survive
  grayscale printing.
