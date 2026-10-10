# Portfolio dependency inventory

How to answer "which of my repositories carry X, at which version,
delivered how" across a whole portfolio, and turn the answer into a
managed fact rather than a one-off survey. Read BEFORE surveying any
dependency, framework, or tool across `~/src` by hand. Reference run:
clubstraylight CSL-0152 (`bin/check-component`, 2026-10-10), the
fourth time the family had built such an inventory (bundler-audit,
the Ruby version, Bootstrap, then Tailwind) and the first time as one
reader over a registry.

## The facts that shape it

1. **A dependency arrives five ways, and a manifest sees one.** A gem
   in a lockfile, an npm package in a package.json, a CDN tag in a
   layout, a vendored copy checked in, a stylesheet import that reads
   node_modules with nothing declared (Rails cssbundling reaches
   Bootstrap this way). A lockfile scan finds the first; the old
   sites in any portfolio use the other four. A bill of materials
   (CycloneDX, SPDX) sees the first two and nothing else.
2. **The name alone is a false positive.** "bootstrap" matches a
   Lambda bootstrap ADR, a budget described as bootstrapped, and
   Rails' own `bootstrap.rb`. Every rule reads the file it matched
   and confirms the shape: a version in a lockfile's specs, a
   dependency key in JSON, a URL on a known host, a file header, a
   directive at the start of a line.
3. **The version is wherever the delivery keeps it.** A lockfile's
   pin; a lockfile's entry beside the manifest, else the manifest's
   range with the operator stripped; the URL's `@5.3.3` or
   `/5.3.3/`; the vendored file's own header (`Bootstrap v3.3.4`);
   a directive that only one major has (`@import "tailwindcss"` is
   v4). Some hosts imply the version by themselves (Tailwind's Play
   CDN serves v3 only). A wrapper gem's major may not be the
   component's (tailwindcss-rails 2.x and 3.x both carry Tailwind 3):
   map it, with the reason beside the map.
4. **A native gem pins once per platform.** Seven lockfile lines for
   one tailwindcss-ruby version; the version is the part before the
   platform, counted once.
5. **Dead hosts are a finding of their own.** rawgit shut down in
   2019; a page loading from it has no stylesheet today, whatever
   version the tag names.
6. **A mixed repository is the most useful row.** Two majors at
   once is a repository mid-upgrade, or a layout still loading an
   old build the new gem replaced. The hand survey missed both
   cases the tool found.
7. **External remotes are read and set aside.** A fork may need
   updating too, so its deliveries go on record; it is still outside
   the population, so it is never an exception and never named by
   owner (the account firewall).
8. **Judgement is per repository, worst first.** mixed, dead-link,
   unknown, then the major; a supported major, no delivery, or
   external passes. A copy whose version cannot be read does not
   unsettle a major the other deliveries state.

## The procedure

1. **Survey by hand once, with the code index** (Zoekt, four queries:
   manifests and lockfiles, files named for the component, CDN
   hosts, template and stylesheet mentions). Write the table with
   group (family or fleet), delivery, version, remote class. This is
   the fixture the tool's first run is checked against.
2. **Fetch the vendor's own migration guide** for the version in
   question and record its facts in the epic: browser floor,
   removed and renamed surface, build and import mechanics, any
   upgrade tool or agent skill the vendor ships. Never plan from
   memory; the guide at an alpha will change, so say which version
   was read.
3. **Add the component to the registry**, not a tool. One entry:
   supported majors, gem names with any major map, npm names, CDN
   hosts with the URL version pattern and host-implied versions and
   dead hosts, the vendored basename and header patterns, the
   stylesheet markers with any major they fix. One caption in the
   tool registry (`tools.yaml`) so the audit site can read the
   page.
4. **Run it over the whole portfolio**, record the run, and check it
   against the hand table row by row. A disagreement is a rule to
   fix or a row the survey got wrong; both happened on the first
   run.
5. **Write the epic** with the table, the guide's facts, the stages
   by the framework-migration playbook (inventory, hold current,
   matrices, spike and swaps, retirement), the decisions that are the
   operator's, and the capability rule for the agents that do the
   swaps.
6. **Prefer the bill of materials when it exists.** The reader
   takes an SBOM per repository in place of its manifest rules and
   says which source it used; the CDN, vendored, and import rules
   still run, since no SBOM sees them.

## Non-negotiables

- Read-only over every target; a full run records, a probe of named
  repositories does not.
- The component's rules are data; a new component is an entry and
  a caption, with its first full run's tally in the ticket.
- The hand survey is kept in the epic as the check on the tool's
  first run, dated.
- The upgrade itself is never part of the inventory ticket: a
  framework update is its own action, one repository at a time,
  under the repository's own brief or persona, by an agent of the
  class the change needs.
