# Changelog — theme-nav-polish

## 1.0.0 — first-class Distribution default

First first-class release: the header menu-bar affordance is promoted from a per-demo polish
capture to a Distribution default, composed as an always-on `overlays` entry on
`editions/swift-demo.json`. The version resets to **1.0.0** (from the demo-scoped 0.1.x line)
to mark the stable, genericized public contract — the customer wiring is gone and the layer is
now catalog-agnostic, so this is a new baseline, not a continuation of the brand-keyed capture.

Genericized for shared use (was demo-keyed 0.1.5):

- **Icon wiring removed from the default.** The five customer `a.nav-link[href$="<slug>"]::before`
  rules and the customer-named `Images/osteogen/nav-icons/` paths are gone. Icons are now an
  opt-in add-on keyed on a neutral `data-nav-icon="<name>"` hook, with the starter SVG set moved
  to the theme-neutral `Images/nav-icons/`. No icon fires until a demo tags a nav node, so the
  core renders cleanly on any catalog (no `[href$=]` rules, no 404'd masks). See README.md.
- **Accent decoupled from the brand.** `--navpolish-accent` no longer reads the customer
  `--og-*` tokens; it defaults to a neutral blue a demo MAY override. The overlay is otherwise
  brand-agnostic (currentColor icons), so it layers on top of any demo theme without replacing it.
- **Affordance core intact.** The carets, hover/active band, and reachable-dropdown fixes
  (LRN-nav-03 Popper-gap bridge, LRN-nav-04 `::after` caret/underline collision, LRN-nav-05
  `min-width:100%`) are unchanged from the proven 0.1.5 artifact — they are platform truths, not
  brand wiring, and are documented in the dw-demo-swift skill.

Data prerequisite (unchanged, now a base contract note): the top nav groups/pages must have
children for Swift to render the panel (`nodesExist = rootNode.Nodes.Any()`), recorded in
`layers/base/base.contract.json` → `navDepth`.

### Divergences (Swift roll-forward ledger)

- **Stock Swift ships a header bar with zero menu affordance.** A fresh Swift 2 storefront's
  `Swift-v2_MenuRelatedContent` bar renders as flat text next to text — no carets, no hover
  states, no dropdown reach — and the stock menu template only emits `data-bs-toggle="dropdown"`
  when a top node has children (`Menu.cshtml` ~line 132), so childless demos get the bare
  `nav-link` branch. This overlay supplies the missing affordance without a template fork. Worth
  reporting to the Dynamicweb Swift team; re-review these entries at the next Swift roll-forward
  (the layer targets the current latest Swift only — rolling latest-only policy).

## Provenance (demo-scoped 0.1.x)

Captured 2026-07-09 on the Solmetex/Impladent OsteoGen demo (Swift 2.3). The 0.1.0→0.1.5 line
built the affordance and debugged the three interaction fixes inline in Playwright (Popper-gap
bridge, `::after` collision, `min-width` reach). 0.1.x was brand-keyed (href-slug icons,
`--og-*` accent) and composed into nothing; 1.0.0 sheds that wiring and composes as the default.
