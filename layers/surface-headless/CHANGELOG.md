# Changelog — surface-headless baseline

## 2.3.3

Config predicate-mode migration (LRN-base232-03), mirroring the base + surface-swift
migration (`ee81375`). `config/headless-2.3.json` predicate modes migrated
`Deploy`→`Replace` (×13) and `Seed`→`Merge` (×10); the output-subfolder keys renamed
`deployOutputSubfolder`→`replaceOutputSubfolder` and `seedOutputSubfolder`→`mergeOutputSubfolder`
(values `replace`/`merge`, matching the on-disk `replace/`+`merge/` trees — the stale
`deploy`/`seed` values pointed at directories the base-split rename retired). Engine
`0.9.0-beta`'s `SerializerSettings` query validates predicate modes strictly (`ConfigLoader`:
only `Replace`/`Merge`) and the harness probes that query before deserializing, so the retired
`Deploy`/`Seed` enums returned HTTP 500 and aborted the whole headless deserialize. No
data/content changes; output split unchanged. Re-proven on DW 10.28.1-PreRelease
(full cold matrix).

## 2.3.2

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). Self-containment hardened: the headless gate leg no longer stages the Swift design package at all (base 3.0.0 is framework-only; this surface ships its own item types + repository). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

All notable changes to the `baseline/headless/2.3` package.

## 2.3.0 — unreleased (STOREFRONT-PHASE Stage 1, §4.3)

### Added
- New **distinct product line** `baseline/headless/2.3` (D5) — decoupled from `swift/2.3`, own
  lifecycle and gate pass.
- `config/headless-2.3.json` — serializer predicate list: Headless area Content predicates
  (deploy framework + seed home/about/catalog) and reused `Ecom*` commerce-domain SqlTable
  predicates.
- **`Headless_*` item-type layer (D6)** — 10 presentation-agnostic item-type definitions under
  `itemtypes/`: `Headless_Master`, `Headless_PageProperties`, `Headless_Page`,
  `Headless_ContentPage`, `Headless_Menu`, `Headless_MenuItem`, `Headless_CustomerCenter`,
  `Headless_AccountSection`, `Headless_SpecSheet`, `Headless_DownloadableAsset`. No Swift item-type
  rows reused.
- EN + NL content parity: `Headless` and `Headless Nederlands` areas.
  - Navigation: header menu (Products, About) + footer menu (Terms).
  - Customer center / B2B: Orders, Reorder, Users, Addresses sections mapped to Delivery API
    endpoints.
  - Content pages: Home, About, Catalog Landing (+ spec-sheet and downloadable-asset instances).
- Item-instance ID floor band **`200000–209999`** reserved for headless.
- `deploy/`+`seed/` `schemaVersion: 2` manifests (Content entries; `_sql` populated at
  serialize-capture time).
- **Product search surface (ADR-001, option a)** — `repositories/Headless/` ships the `Headless`
  repository: `Products.index` (ProductIndexBuilder, harness-safe schema — no `ProductCategory|*`
  sources), the named `Products.query` (q/eq text search, `GroupID`, `sku`, facet params;
  ENU/SHOP1 via `Ecommerce.Context` macros), and `Products.facets` (Manufacturer, Group, Price
  buckets). Resolvable by `POST /dwapi/ecommerce/products` / `GET /dwapi/ecommerce/products/search`
  with `RepositoryName=Headless`, `QueryName=Products`. Gate staging + asserts A7–A9 documented.

### Changed (ADR-001 resolution folded in)
- **Slug contract** recorded in BASELINE.md: product `handle` = product **number**
  (`EcomProducts.ProductNumber`), collection `handle` = **group id** (e.g. `GROUP1`) — stable
  across baseline rebuilds; the provider reshaper relies on it.
- **Locale/area contract** recorded in BASELINE.md: canonical defaults **ENU + SHOP1** (product
  data lives under ENU, not LANG1); areas carry shop/language/currency bindings (Swift area 3/27
  precedent); menus = `GET /dwapi/frontend/navigations/{areaId}` (recursive `nodes[]`); content
  pages = `/dwapi/content/pages` + `/dwapi/content/rows/{pageId}/{device}`.
- Open-items ledger updated: items 1 (menu shape) and 3 (area id/bindings) **resolved**;
  2 (account-section endpoints), 4 (`TargetRef` end-to-end resolution), 5 (reorder/CSR surface)
  remain open pending the provider implementation.

### Notes
- ADR-001 **decided**: option (a) — DW provider module behind the Vercel Commerce data-layer
  contract, consuming the Delivery API (`/dwapi/**`, REST/JSON only, no GraphQL/OData).
- File-authoring only: no gate run, no deserialize, no live host, no push (STOREFRONT-PHASE wave-1
  hard rules). Gate-assert plan documented in BASELINE.md for the orchestrator's serial gate run.
