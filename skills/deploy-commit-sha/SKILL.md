---
name: deploy-commit-sha
description: Add the current deployed git commit SHA to a web page. Makes it visible which exact commit is running in any environment. Placeholder — full implementation to be ported from local machine.
disable-model-invocation: true
---

# Deploy Commit SHA

Display the current deployed git commit SHA on a web page so anyone
can verify exactly which commit is running in any environment.

## Status

**Placeholder** — full implementation exists locally and will be
ported here. See gist at https://gist.github.com/doolin for
reference material.

## Intent

- Inject the git commit SHA at build time or deploy time
- Display it on the web page (footer, meta tag, health endpoint, etc.)
- Works across frameworks and deploy targets
- Ties a running deployment back to a specific commit in the repo

## TODO

- [ ] Port implementation from local machine
- [ ] Add framework-specific examples (Rails, React, static sites, etc.)
- [ ] Add CI/CD integration steps for injecting the SHA at build time
- [ ] Add verification instructions
