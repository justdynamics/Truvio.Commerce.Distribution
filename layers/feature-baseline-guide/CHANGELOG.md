# Changelog — feature-baseline-guide

## 1.0.2

- **The branding path gets content probes (Foundry #1106).** It was a `criticalPath` only, so a
  branding pass that overwrote its content left one automated statement about it: HTTP 200.
  `asserts.behaviorProbes` adds two probes on `/en-us/baseline-guide/branding-path`, one for the
  page title `Branding path` and one for the `The two standing rules` heading, both guide content
  that a correct branding pass leaves in place. The existing index probe's kind is corrected
  from `body-contains`, which is not a registered probe kind and fails closed, to
  `http-body-contains`.
- **Step 3 asserts the commerce bindings by value (Foundry #1112).** The Assert asks
  `get_area_by_id` for non-empty `ecomShopId`, `ecomLanguageId`, `ecomCurrencyId` and
  `ecomCountryCode` equal to the values bound, with `domain` optional, and states why the
  header/footer page check alone passes on an unbound area: on a single-shop, single-language,
  single-currency host Swift falls back to them. The bindings stay unserialized
  (`replace/replace-manifest.json` `excludeAreaColumns`).
- **The Rule 1 note cites its enforcement point (Foundry #1016).** The boxed note under the
  standing rules claimed no guarded-write preflight exists on `distribution\layers\` (Finding
  F-G1). It now cites `dw-demo-base/SKILL.md` "Three guarded-writes (always-on rules)", rule 3
  *Distribution layer path*, and records F-G1 as resolved by that rule.
- **Step 2's zero-state pass includes the meta description (Foundry #1109, guide half).** The
  frontpage meta description, which `og:description` repeats, joins the title and meta title,
  with the admin page settings named as the write surface (no MCP tool writes it) and a
  served-head assert that the vendor sentence is gone.
- **Step 2 prints the button shape as a name (Foundry #1108).** The "What this site actually
  ships" block read `Shape 2`, an ordinal that is Rounded under one reading and Pill under the
  other. It now prints `Shape Pill`, the value `get_button_styles` returns, with the rule that a
  shape is `Squared`, `Rounded` or `Pill`, never an integer.

## 1.0.1

The Pricing page states the currency rate base 3.4.0 ships: `USD$$ENU` at `CurrencyRate` 100 (parity
with the default, a demo value), and a rate of 1 on any currency renders every price a hundred times
over (Foundry #971). Text-only change to one paragraph.

## 1.0.0

Initial release (foundry.mydwsite4.com e2e session, 2026-09-12). Content-only, **zero custom code**,
**zero catalogue rows**.

- Adds the **Baseline guide** page tree under area 3 (`/Baseline guide`, storefront `/en-us/baseline-guide`):
  one page per baseline feature area (content, navigation, PIM, catalog, pricing, B2B, users and
  permissions, checkout, RMA, search, integration hooks, headless probes) plus the branding path and the
  customer-context convention. Written for an agent reader in the vocabulary of the dynamicweb/skills
  bundles; every page names the layer that ships the feature, the skill that covers it, the MCP tools
  that brand it and one assert.
- Serialized with `config/baseline-guide-2.4.json` (one Replace Content predicate) on Serializer 0.9.0-beta.
- Depends on `surface-swift` for area 3; placed after it in the `swift-demo` edition.
