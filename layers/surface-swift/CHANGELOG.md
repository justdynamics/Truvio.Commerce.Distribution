# Changelog — surface-swift

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
