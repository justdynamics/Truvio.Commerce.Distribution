# surface-swift — the Swift storefront content surface

**Kind:** `surface` · **Swift:** 2.4.0 · **Proven on DW 10.28.1-PreRelease**

Born in the Swift 2.4 roll-forward base split: `base` 3.0.0 became **framework-only** and
ALL Swift content moved here. This layer is what the Swift (Razor) frontend needs, packaged
as a self-contained surface — the exact mirror of `surface-headless` for the classic
storefront leg.

## What this layer ships

| Piece | Content |
|---|---|
| `replace/_content` | The full structural page tree of the `Swift 2` area (EN, area 3) — framework pages (Customer Center incl. per-role permissions, checkout, account, navigation), item types bindings, layouts. |
| `merge/_content` | The ENTIRE former base merge tree: bootstrap content (Home, site chrome, About, posts, dealers, footer navs, newsletter examples) in the Swift 2 area — field-level merge, customer edits survive. |
| `replace/_sql/UrlPath` | The friendly-URL redirect table (see the UrlPath decision below). |
| `repositories/TruvioCommerce` | The storefront product repository: `Products.index`, `Products.query`, `Products.facets` and `Build+Index.task`. On a host whose index builds are drained by the Repository task handler, a repository folder with no `Build+Index.task` is never rebuilt, whatever a build call reports. |
| `files/` | Template overrides and the assets they read, including `Images/Icons/cube.svg`, the icon every `Swift-v2_Dashboard_*` template reads. |
| `itemtypes/` | **Its own 128 `ItemType_Swift-v2_*.xml` definitions from the official Swift v2.4.0 design package** — the surface registers its item types itself (self-contained; the gate overlays them via `Deploy-LayerFilesOverlay` before deserialize). |
| `config/swift-content-2.4.json` | The content predicates: `Site framework` (Deploy, areaId 3) + the 10 Seed content predicates + UrlPath + the content-scoped exclude maps (`excludeFieldsByItemType`, `excludeXmlElementsByType`). |
| `surface.contract-notes.json` | The content-scoped contract bits that moved OUT of `base.contract.json`: content anchors (area 3, `/swift-2`), per-environment Area exclusions, protected Swift item types, navDepth obligation, title rules — and the UrlPath decision record. |
| Area ecommerce binding | The `Swift 2` area ships `AreaEcomShopId` `SHOP1`, `AreaEcomCurrencyId` `EUR` and `AreaEcomLanguageId` `ENU` in both mode trees (1.13.3). They are base-owned constants, not per-environment values, and an unbound area on DW 10.28 resolves the request culture's currency — an `/en-us/` storefront then serves USD carts and every EUR `EcomPrices` row is inert (Foundry #1232). `AreaEcomCountryCode`, `AreaFrontpage` and `AreaStockLocationID` stay per-environment. |

## The UrlPath decision (recorded here per RUN-SWIFT-24)

**UrlPath ships in surface-swift, not in base 3.0.0.**

The table's single row is a 301 friendly-URL redirect (`products-*` →
`Default.aspx?ID=50`) bound to `UrlPathAreaId 3` **and** a Swift page id. Friendly URLs
resolve against pages; a framework-only base ships no areas and no pages, so a base-owned
UrlPath row would dangle (route with no target) and force base re-proves on every Swift
page churn. Friendly URLs → pages ⇒ the row travels with the content it routes.
The same decision is recorded in `layers/base/BASE.md`.

## Composition

Editions compose this surface via `surfaces: ["surface-swift@<version>"]`, where `<version>`
is the `version` in this layer's `layer.json`; copy the ref from an edition that already pins
it (`editions/swift-demo.json`, `editions/base-swift.json`) rather than typing it. The gate
rejects a ref whose semver differs from `layer.json`. Gate order: base framework → sample-data catalog →
**surface-swift** → feature fragments (features add content INTO these areas, so the
surface lands first). The content asserts (language-layer round-trip, permissions parity,
title integrity) bind to this layer's trees.

## Provenance

- Content: the curated commerce content trees carried forward from base 2.4.1 and
  re-proven on Swift 2.4 / DW 10.28.1-PreRelease by the gate. **Every demo-facing
  string is a function-descriptive placeholder** (1.4.0): visible copy reads
  `Placeholder — <function>`, e.g. `Placeholder — hero headline (customer value
  proposition)`. The literal word `Placeholder` is the machine-detectable marker a
  design gate scans for (`/placeholder/i`), so copy left un-replaced at build time
  fails loudly rather than shipping to a prospect. `Page presets/` follows the same
  convention: a preset is the reinfection vector — a builder clones it to make a page,
  so any real-world copy left there comes back on every page built from it.
- Item types: official Swift v2.4.0 design package (`Swift_v2.4.0_Files.zip`,
  github.com/dynamicweb/Swift release v2.4.0).
- **PreRelease attestation:** proven on DW **10.28.1-PreRelease** (operator-approved
  override of the stable-only rule). A stable re-prove sweep is mandatory when DW 10.28
  reaches NuGet stable.
