# Changelog — surface-swift

## 1.4.0

Fresh-deserialize presentability pass. Everything below was visible to a prospect on a
clean composition of this surface, and all of it lived in the layer source.

- **Swift eco-lorem removed from item-type defaults.** Ten of the most-used item types
  (`Text`, `Poster`, `VideoPoster`, `TextAndImage`, `Card`, `Feature`, `Blockquote`,
  `Accordion_Item`, `Slider_Item`, `Logo`) carried Swift's upstream nature/eco demo copy
  in their field `defaultValue` attributes, so every paragraph a demo builder created
  arrived pre-filled with it — and it returned after every re-save. Prose and branding
  defaults blanked (`Logo.LogoName` shipped the literal string "Swift"); generic
  scaffolding defaults kept (button labels, `Poster.Height`, `Logo.LogoWidth`).
- **Home `grid-row-6` authored.** Three side-by-side `Swift-v2_Feature` paragraphs
  ("Bulk ordering made easy" / "Competitive wholesale pricing" / "Dedicated account
  support") all carried the verbatim `Feature` default body, so three different B2B
  promises were each explained by the same sentence about caring for the planet.
- **Footer policy links are page references.** `PrivacyPolicyLink` /
  `CookiePolicyLink` were literal `/swift-2/...` paths while `AreaUrlName` shipped
  empty, so the segment was host-derived and both links 404 wherever culture drives the
  prefix. Now `Default.aspx?ID=224` / `Default.aspx?ID=232`, the link form the rest of
  the surface already uses. `AreaUrlName` is pinned to `swift-2` so the segment is
  deterministic on every consumer host — which is what makes the edition's
  `criticalPaths` a claim this layer can keep. (Foundry #439)
- **Desktop header stops overflowing the viewport.** `Desktop Header/grid-row-4` is a
  `2ColumnsFlex` row with `flexibleColumns: "0,0"` — flex-basis 0 on both columns, so
  the mega-menu and the search field both sized to content and neither could shrink.
  Now `"1,0"`. (Foundry #438)
- **Three empty home-page bands removed**, each of which sat under a live heading: the
  "Our products" slider (`Items: 323`), the "Latest travel guides" post list plus its
  button, and the "Frequently asked questions" accordion (`Accordion_Items: 324`). No
  `Slider_Item` / `Accordion_Item` child rows exist in any layer and none can be
  authored here — the serializer's fragment manifests carry only `Content` and
  `SqlTable` provider entries, and no layer ships a serialized ItemList table.
- **PDP "Similar styles" band removed.** Its `ProductComponentSlider` used
  `RelationType: "most-sold"`, which is empty on a host with no order history, and an
  empty relation makes the component render its whole source page inline. Its heading
  ("Similar styles") also disagreed with its own title ("Others also bought").
- **Alt text authored** on all six content-bearing image paragraphs. The surface
  previously shipped `AltText` set on zero paragraphs.
- **Category description copy is no longer hidden.** `Shop/Product List/grid-row-2`
  shipped `HideGroupDescription: true`, so group merchandising copy rendered nowhere
  site-wide; the sibling instance under `Product Components` already shipped `false`.

Minor bump: item-type XMLs change and shipped rows are removed, but no page, item type
or field is added or renamed, and no consumer-facing id moves. Both fragment manifests'
`files` lists are updated in lockstep with the removals. Deep deserialize proof
(row-count parity, strict-mode) runs in the Foundry gate — see the PR body.

## 1.3.0

Newsletter-email shells fix (P18 B2B email-pack fold, marine-demo evidence 2026-07-18).
The Swift 2.4 serialization shipped the OOTB newsletter-email page SHELLS with no body
(page.yml only) — near-useless on a fresh deserialize. This authors generic-Swift bodies
for the two OOTB shells so demos start from designed emails:

- **`Swift - Newsletter - Announcement Email`** (Dark) — 5 `1ColumnEmail` rows:
  Header / Heading / Article / Button / Footer, brand-neutral announcement copy.
- **`Swift - Newsletter - Sale Email`** (Light) — 6 `1ColumnEmail` rows: Header / Heading /
  Article / **Product Catalog** / Button / Footer. The product rail references the real
  sample-data catalog SKUs (`FIXT0002/0004/0006/0010`), `Layout: "2"` (numeric-string column
  count — a non-numeric value crashes the template with DivideByZero), `HideProductPrice: False`
  (a Sale shows prices). `EmailButton` link targets left blank (Swift page ids are assigned at
  deserialize and are not stable to hardcode).

Data-only serialized content in the `merge/_content` tree, registered in `merge-manifest.json`;
new row/paragraph ids are fresh GUIDs with `sourceParagraphId: 0`, item-instance `fields.Id` in
the reserved `100600+` band (base-contract `intIdentityFloor`). `templates.manifest.yml` updated
to reference the new `Swift-v2_Email*` item types + `1ColumnEmail` rows. Item-type XMLs unchanged.
Minor bump — additive content only. Deep deserialize proof (row-count parity, strict-mode) runs
in the Foundry gate — see the PR body.

## 1.2.1

Raw page-id link hygiene (runtime E2E deserialize sweep, DW 10.27.6, risewell-e2e). A sweep
of the merge/replace trees for raw page-id link references (`Default.aspx?ID=<n>`, page
`shortCut`, and bare page-reference item fields) found every such link resolves to an
in-tree page **except one casing outlier**:

- **`About us` page shortcut** (`Navigation/Footer Navigation/About the shop/About us`):
  `"shortCut": "Default.aspx?Id=165"` → `"Default.aspx?ID=165"`. Every other link in the
  surface uses the canonical `ID=` casing; the lowercase `Id=` risked being skipped by the
  serializer's case-sensitive page-id remap, leaving a raw source id on the target. 165 is
  the in-tree `About` page (sourcePageId 165), so the target is unambiguous.

Data-only, one serialized-content line changed; item-type XMLs and the rest of the merge
tree unchanged. Patch bump. Deep deserialize proof (strict-mode, row-count parity) runs in
the Foundry gate — see the PR body.

## 1.2.0

Multi-language reshape (RUN-SWIFT-MULTILANGUAGE, P3 — Foundry plan). Drops the Dutch
content leg now that nld is removed from the Distribution shop languages (base 3.1.0):

- **Removes the `Swift 2 Nederlands` (area 27) content area** and its feature coupling —
  the entire NL `replace/_content` mirror and its manifest entry. The Distribution now ships
  the single `Swift 2` (en-US, area 3) content area.
- Composes on base 3.1.0 (en-US sole shop default). Data-only serialized content; deep
  deserialize proof (row-count parity, strict-mode) runs in the Foundry gate — see the PR body.

Minor bump — content-area removal, item-type XMLs + merge tree unchanged.

## 1.1.0

Theme fresh-pass fold-in — product-page composition (marine-demo evidence, 2026-07-18).
Ships the two product-description partials that the enriched catalog already carries but
nothing rendered:

- **`Swift-v2_ProductShortDescription`** added to the buy panel (`Product Components/
  Product Info (right side)`), directly under the product title. Renders the product teaser
  under the header, above price.
- **`Swift-v2_ProductLongDescription`** added as a full-width **"Overview"** section on the
  `Shop/Product Details` page (new 1-column row at `sortOrder 3`, between the media/buy-panel
  row and the "Similar products" row; the trailing rows shift down one; title `Overview`,
  `TitleFontSize: h4`, `TextReadability: max-width-on`).

Scoped to the `Swift 2` (en-US) content area only — the `Swift 2 Nederlands` (area 27)
mirror is intentionally omitted because that area is being deleted by the parallel
multi-language change (nld dropped from the Distribution). Data-only serialized content
(`replace/_content/**`), registered in `replace-manifest.json`; new paragraph/row ids are
fresh GUIDs, `sourceParagraphId` in a reserved 90000+ band. Deep deserialize proof
(row-count parity, strict-mode) runs in the Foundry gate — see the PR body.

## 1.0.1

Learnings triage fix (RUN-TRIAGE-20260713 in the Foundry):

- **LRN-uipass-03:** both areas wired `AreaColorSchemeGroupId: swift` /
  `AreaTypographyId: fonts` / `AreaButtonStyleId: buttons` — style-asset pairs that
  no layer (and no Swift release: `Files/System/Styles/` ships `ColorScheme.config`
  only) provides. `TryGet*Style` fails silently and the storefront renders with
  serif fallbacks. All three ids in both areas (replace AND merge trees) now point
  at `default`, which `theme-default` ships as `ColorSchemes/Buttons/Typography
  default.{json,css}`. Gate assert: after composing an edition with theme-default,
  the main area's three style ids resolve to files under `files/System/Styles/`,
  and the home `<head>` carries the three `Styles/` `<link>`s.
- **Config predicate-mode migration (LRN-base232-03):** `config/swift-content-2.4.json`
  predicate modes migrated `Deploy`→`Replace` (×2) and `Seed`→`Merge` (×9), matching the
  already-migrated base config. Engine `0.9.0-beta`'s `SerializerSettings` query validates
  predicate modes strictly (`ConfigLoader.ValidatePredicates`: only `Replace`/`Merge`) and
  returned HTTP 500 on the retired `Deploy`/`Seed` enums — the harness probes that query
  before deserializing, so the WHOLE surface content-deserialize aborted (no Swift areas
  created). With the modes migrated, the surface deserializes and persists the area.yml
  `properties` (incl. the four style columns) as intended. Output split (`replace/`+`merge/`
  dirs, `deployOutputSubfolder`/`seedOutputSubfolder` keys) unchanged.

## 1.0.0

Born in the Swift 2.4 base split (RUN-SWIFT-24; FOLLOWUP bump plan). The Swift
storefront content surface, extracted from `base` 2.4.1 when the base became
framework-only 3.0.0:

- `replace/_content`: both areas (3 "Swift 2" EN + 27 "Swift 2 Nederlands" NL) — the
  curated, brand-neutral structural trees incl. Customer Center per-role permissions.
- `merge/_content`: the ENTIRE former base merge tree (bootstrap content, both areas).
- `replace/_sql/UrlPath`: the friendly-URL redirect row — decision + rationale in
  `surface.contract-notes.json` and README.md (friendly URLs → pages ⇒ surface-owned).
- `itemtypes/`: 128 `ItemType_Swift-v2_*.xml` definitions from the OFFICIAL Swift
  v2.4.0 design package — the surface is self-contained (gate overlays them itself).
- `config/swift-content-2.4.json`: Site framework + 10 seed content predicates +
  UrlPath + the content-scoped exclude maps.
- `surface.contract-notes.json`: content anchors, per-environment Area exclusions,
  protected Swift item types, navDepth + title rules (moved from base.contract.json).

**Proven on DW 10.28.1-PreRelease** (stable re-prove due when DW 10.28 lands stable
on NuGet). Composed by `editions/swift-demo.json`.
