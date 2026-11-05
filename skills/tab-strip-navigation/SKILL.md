---
name: tab-strip-navigation
description: How to build hierarchical (tiered) tab-strip navigation in a server-rendered web app, so every page shows where it sits at every level - a site bar, a section tier beneath it, page or context tiers below that. Covers how a tier is built, how the current tab is found at each tier, how tiers nest, URL scheme, styling by depth, capability filtering and unavailable entries, the separate case of in-page panel tabs, and the request specs that prove each tier. Use when adding a tab tier, giving a section sub-sections, or putting a switcher above an existing strip.
---

# Tab-strip navigation

Tiers of tabs, stacked top to bottom, each answering one question about
where the reader is:

```text
Tier 0  site bar       Straylight  Development  Inventory  Notifications
Tier 1  section tabs   Books  Games
Tier 2  page tabs      Dashboard  Library  Plays  Statistics  Add games
        content
```

Two principles drive every rule below.

- **Context is chrome, never memory.** From the page alone the reader can
  see the current choice at every tier. Nothing about where they are is
  held in their head, a session, or a dropdown they have to open.
- **Siblings are visible.** The sub-sections at a level are tabs at that
  level, not a menu. This is progressive disclosure: one level at a time,
  and everything at that level on screen.

## Two kinds of tab

Decide which one you are building before writing anything. They look
alike and behave differently.

| | Navigation tier | Panel tabs |
| --- | --- | --- |
| A tab is | a link to its own URL | a control that shows a panel of this page |
| Current marked by | `aria-current="page"` | `aria-selected="true"` |
| The choice lives in | the path, or a query parameter | `?tab=` |
| Switching | a full navigation | `history.replaceState`, no history entry |

If the tab's content is another page, with its own action and its own
data, it is a tier. If it is another view of data the page already
loaded, it is panel tabs (see the last section).

## Rules for a tier

1. **One `<nav>` per tier, each with its own `aria-label`**
   ("Development tools", "Inventory sections", "Games"). The label is how
   a screen reader announces the tier and how a spec finds it.
2. **One current tab per tier, on every page of the section**, marked
   `aria-current="page"`. A section usually spans more than one prefix:
   dbb's Inventory tab is current on `/books`, `/book_imports`,
   `/book_photo_imports`, `/kindle_notebook_imports` and `/games`. Write
   that membership list once, in the parent tier, and derive both the
   parent's highlight and whether the child tier renders from it.
3. **A child tier is rendered by its parent.** The site bar renders the
   Inventory tier when Inventory is current. Pages do not render child
   tiers themselves, so no page can show a child tier with its parent
   unmarked, or forget the tier on one page of the section.
4. **Say how a tab is current.** There are three ways, and a tier uses
   one: a path prefix, a query parameter (`?artifact_type=prd`), or a
   local the caller passes (`active_tab: "games"`). The partial's header
   comment states which.
   - Prefix trap: `start_with?("/games")` also matches `/gamesmaster`.
     Match `path == "/games" || path.start_with?("/games/")`. Two
     sections whose prefixes overlap (`/project`, `/projects`)
     highlight the wrong tab.
5. **On the lowest tier, the current page is text, not a link**
   (`<span aria-current="page">Library</span>`). A link to the page you
   are on does nothing. The other links on that tier carry the state the
   page was reached with: from a game's page, the Library link keeps the
   filters that led there.
6. **A tier shows only what its context has.** A repo with no PRDs gets
   no PRDs tab, not a disabled one. The absence of the thing is the
   absence of the tab. This is filter-state honesty applied to
   navigation: the strip never implies something exists that does not.
7. **Unavailable differs from absent.** An entry that belongs in the tier
   but cannot be reached right now (a sibling checkout missing on this
   machine) renders muted, with the reason in its tooltip, and opening it
   explains the reason in the content area. It is never dropped (a tab
   that vanishes reads as a bug) and never a 500.
8. **Switching at tier N carries tier N+1 over when it can.** Moving from
   one repo to another keeps the artifact type when the target repo has
   it, and falls back to the target's first tab when it does not. Filters
   and search reset, because they belong to what was left.

## URLs

- **The default context pays nothing.** Omit it from the URL, so links
  made before the tier existed still work; put the others in the path
  (`/development_board` for the home repo,
  `/development_board/repos/openclose` for another).
- **One URL per page.** The default's explicit form
  (`/development_board/repos/dbb`) redirects to the short one.
- **Literal segments before wildcards.** Declare `repos/:repo` before
  `:id`, or the router reads `repos` as an id. An unknown slug is a 404.
- **Engines lose the host's route helpers.** A tier rendered inside a
  mounted engine's layout cannot call `development_board_path`, so its
  paths are plain strings. Say so in the partial's header, with the list
  of paths to update if a mount point moves.

## Styling

- **One active vocabulary at every tier:** an accent bottom border and
  dark text for the current tab (`border-b-2 border-blue-600
  text-slate-900`), muted text and a transparent border for the rest,
  darkening on hover (`text-slate-500 border-transparent
  hover:text-slate-700 hover:border-slate-300`), with `-mb-px` so the
  current tab's border sits on the strip's rule.
- **Tiers differ in size, so they read as levels.** A context switcher
  sits directly above the tabs it scopes and is smaller and denser than
  them (`px-3 py-1.5 text-xs uppercase tracking-wider` over
  `px-4 py-2 text-sm`). Tiers that scope each other share one bordered
  block, so they read as one instrument and not two unrelated rows.
- **Muted palette.** No saturated fills; no dark strip backgrounds.
- **Class strings live in one place.** Tailwind does not scan `.rb`
  files by default, so classes emitted from a helper or component need an
  `@source` entry or they are purged.

## Panel tabs

- The choice lives in `?tab=`, so a refresh, a bookmark and a pasted
  link all open the same panel.
- The server reads the parameter and renders the chosen panel visible in
  the first response, so the page does not flash its default and then
  swap. It accepts only ids the view renders, falling back to the
  default otherwise: an id matching no panel would hide every panel.

  ```ruby
  def resolve_tab(allowed, default)
    allowed.include?(params[:tab]) ? params[:tab] : default
  end
  ```

- On click, write the parameter with `replaceState`, built from the
  current URL so sibling parameters (`?period=`) survive. A tab flip is
  not a navigation: `pushState` would make Back walk the tabs instead of
  leaving the page.
- The script toggles the same classes the server renders for a current
  and an other tab, hover classes included, so a switch in the browser
  leaves the same DOM as a server render of that tab.

## One mechanism, not copies

The easy way to add a tier is to copy the last one: a partial that
repeats the tab classes link by link and finds its current tab its own
way. dbb has four of these. By the third, extract: a declaration per
section (label, path, how a tab is current, which context it needs) and
one renderer that draws any tier from it, at any depth. A new tier is
then a declaration, not a partial. The extraction is dbb's DBB-0583.

## Proving it

A request spec per tier, run against the HTML the server sends:

- Find the tier by its `aria-label` and reduce it to
  `{ text:, href:, current: }` per link. Assert the whole tier as one
  array: which tabs, in which order, which one current. One `eq` shows
  whichever of the three broke.
- A shared example, "a page in the Inventory section", run against a page
  at every level and every member page outside the main prefix. It checks
  the parent tier marks only its section current and the child tier marks
  the right tab.
- One page outside the section: the parent tab is unmarked and the child
  tier is absent (`eq([])`).
- On the lowest tier, the current page appears as `[label, nil, "page"]`:
  present, not linked, marked.
- A page rendered by an engine's layout still shows its tiers.
- Seen red once: change the expected current tab, and confirm the failure
  prints the tier.

Browser checks are end-to-end specs (Playwright through Capybara), not a
person clicking through.

## Adding a tier: checklist

1. Kind: navigation tier or panel tabs?
2. The tier's `aria-label`, its tabs in order, and how each is current.
3. The section's member paths, written once in the parent tier.
4. Rendered from the parent, not from pages.
5. Context filtering and the unavailable state, if the tier depends on
   context above it.
6. URLs: default omitted, explicit default redirected, literal routes
   before wildcards.
7. Styling from the shared vocabulary; size set by depth.
8. Request specs: the whole tier per level, the off-prefix members, one
   page outside, seen red.

## Reference implementation

dbb (`~/src/dbb`):

- `app/views/dev_tools/_nav.html.erb`: the site bar; the Inventory
  membership list, rendering the Inventory tier beneath it; the brittle
  points of hardcoded paths.
- `app/views/dev_tools/_inventory_tabs.html.erb`: Books and Games.
- `app/views/dev_tools/_repo_tabs.html.erb`: a context switcher with
  capability carry-over and unavailable repos.
- `app/views/dev_tools/_development_tabs.html.erb`: the artifact tabs,
  current by query parameter.
- `app/views/games/_nav.html.erb`: the page tier, current page as text,
  filters carried.
- `app/controllers/concerns/tabbed.rb` and
  `app/javascript/controllers/tabs_controller.js`: panel tabs.
- `app/views/layouts/prettytodo/application.html.erb`: tiers inside an
  engine layout.
- `spec/requests/inventory_navigation_spec.rb`,
  `spec/requests/games/nav_spec.rb`: the specs above.
- `.development/design/DES-0004-tiered-navigation.md`: the design;
  DBB-0583 for the single mechanism.
