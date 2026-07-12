# surface-swift — the Swift storefront content surface

**Version:** 1.0.0 · **Kind:** `surface` · **Swift:** 2.4.0 · **Proven on DW 10.28.1-PreRelease**

Born in the Swift 2.4 roll-forward base split: `base` 3.0.0 became **framework-only** and
ALL Swift content moved here. This layer is what the Swift (Razor) frontend needs, packaged
as a self-contained surface — the exact mirror of `surface-headless` for the classic
storefront leg.

## What this layer ships

| Piece | Content |
|---|---|
| `replace/_content` | The full structural page trees of BOTH areas: `Swift 2` (EN, area 3) and `Swift 2 Nederlands` (NL language layer, area 27) — framework pages (Customer Center incl. per-role permissions, checkout, account, navigation), item types bindings, layouts. |
| `merge/_content` | The ENTIRE former base merge tree: bootstrap content (Home, site chrome, About, posts, dealers, footer navs, newsletter examples) in both areas — field-level merge, customer edits survive. |
| `replace/_sql/UrlPath` | The friendly-URL redirect table (see the UrlPath decision below). |
| `itemtypes/` | **Its own 128 `ItemType_Swift-v2_*.xml` definitions from the official Swift v2.4.0 design package** — the surface registers its item types itself (self-contained; the gate overlays them via `Deploy-LayerFilesOverlay` before deserialize). |
| `config/swift-content-2.4.json` | The content predicates: `Site framework` (Deploy, areaId 3, language layers included) + the 10 Seed content predicates + UrlPath + the content-scoped exclude maps (`excludeFieldsByItemType`, `excludeXmlElementsByType`). |
| `surface.contract-notes.json` | The content-scoped contract bits that moved OUT of `base.contract.json`: content anchors (areas 3/27, `/swift-2`), per-environment Area exclusions, protected Swift item types, navDepth obligation, title rules — and the UrlPath decision record. |

## The UrlPath decision (recorded here per RUN-SWIFT-24)

**UrlPath ships in surface-swift, not in base 3.0.0.**

The table's single row is a 301 friendly-URL redirect (`products-*` →
`Default.aspx?ID=50`) bound to `UrlPathAreaId 3` **and** a Swift page id. Friendly URLs
resolve against pages; a framework-only base ships no areas and no pages, so a base-owned
UrlPath row would dangle (route with no target) and force base re-proves on every Swift
page churn. Friendly URLs → pages ⇒ the row travels with the content it routes.
The same decision is recorded in `layers/base/BASE.md`.

## Composition

Editions compose this surface via `surfaces: ["surface-swift@1.0.0"]` (see
`editions/swift-demo.json`). Gate order: base framework → sample-data catalog →
**surface-swift** → feature fragments (features add content INTO these areas, so the
surface lands first). The content asserts (language-layer round-trip, permissions parity,
title integrity) bind to this layer's trees.

## Provenance

- Content: the curated, brand-neutral commerce content trees (bike-era copy neutralized,
  NL language layer included) carried forward from base 2.4.1 and re-proven on
  Swift 2.4 / DW 10.28.1-PreRelease by the gate.
- Item types: official Swift v2.4.0 design package (`Swift_v2.4.0_Files.zip`,
  github.com/dynamicweb/Swift release v2.4.0).
- **PreRelease attestation:** proven on DW **10.28.1-PreRelease** (operator-approved
  override of the stable-only rule). A stable re-prove sweep is mandatory when DW 10.28
  reaches NuGet stable.
