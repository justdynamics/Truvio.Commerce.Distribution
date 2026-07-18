# Changelog — surface-swift

## 1.1.0

Theme fresh-pass fold-in — product-page composition (marine-demo evidence, 2026-07-18).
Ships the two product-description partials that the enriched catalog already carries but
nothing rendered:

- **`Swift-v2_ProductShortDescription`** added to the buy panel (`Product Components/
  Product Info (right side)`), directly under the product title, in **both** content areas
  (`Swift 2` + `Swift 2 Nederlands`). Renders the product teaser under the header, above
  price.
- **`Swift-v2_ProductLongDescription`** added as a full-width **"Overview"** section on the
  `Shop/Product Details` page (new 1-column row at `sortOrder 3`, between the media/buy-panel
  row and the "Similar products" row; the trailing rows shift down one), in both areas
  (title `Overview` / `Overzicht`, `TitleFontSize: h4`, `TextReadability: max-width-on`).

Data-only serialized content (`replace/_content/**`), registered in `replace-manifest.json`
for both areas; new paragraph/row ids are fresh GUIDs, `sourceParagraphId` in a reserved
90000+ band. Deep deserialize proof (row-count parity, strict-mode) runs in the Foundry
gate — see the PR body.

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
