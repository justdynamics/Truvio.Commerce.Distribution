# Base layer — the contract every edition builds on

The **base** is the one privileged layer (`kind: base`). Since the Swift 2.4 base split (3.0.0) it is **framework-only**: shop structure, countries/currencies/languages/VAT, payment/shipping/order flow, and the three permission groups — **zero catalog, zero content areas, zero pages**. The Swift storefront content (areas 3 + 27, both mode trees) and `UrlPath` moved to the **`surface-swift`** layer; the headless content lives in `surface-headless`. Editions compose the base with additions (`feature`, `sample-data`, `surface`, `theme` layers).

The machine-readable guarantees live in [`base.contract.json`](base.contract.json) (v2.0.0); the gate reads that file for the base-contract collision check. Content-scoped contract bits (content anchors, per-environment Area exclusions, protected Swift item types, navDepth, title rules) moved to `layers/surface-swift/surface.contract-notes.json`. This doc is the human companion. **Additions bind only to the base contract — never to each other.**

## The UrlPath decision (Swift 2.4 base split)

`UrlPath` ships in **surface-swift**, not in base 3.0.0. Its single row is a 301 friendly-URL redirect (`products-*` → a Swift page id) bound to area 3 — friendly URLs resolve against pages, and a framework-only base has no route targets. A base-owned UrlPath row would dangle and force base re-proves on Swift page churn. Recorded in both layer docs (this file + `layers/surface-swift/README.md`).

## ID rules

| Key type | Rule |
|---|---|
| **nvarchar PK** on a base-owned table (`PriceId`, `ProductId`, `PaymentId`, …) | Namespace with a **`PACK-<NAME>-`** prefix (uppercase layer name) |
| **int-identity PK** (incl. `ItemType_<systemName>` item-instance ids) | Reserve an id at or above the **`100000`** floor |
| sample-data demo catalog | Reserves `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` |

The base ships **zero catalog** — `EcomGroups/EcomProducts/EcomPrices/EcomDiscount/EcomVariant*/EcomGroupProductRelation` are empty of base rows, so for those tables the collision surface is addition-vs-sample-data-vs-addition (arbitrated statically by the gate). There is deliberately **no per-itemType numeric range table** — the contract is prefix-based.

## Guaranteed anchors (additions may bind to these)

**Permission groups** (`AccessUser`, type 2 — DW 10.26.9 has no `AccessUserGroup` table):
- `1325` Customers · `1270` Account Admin · `1292` CSR

**Users** (`AccessUser`, type 5):
- `1328` **IMCUser** (buyer, customer number `98745621`) — member of `1325`
- `1326` **IMCSalesrep** (CSR, customer number `7789765`) — member of `1292`

**Content:** none — the base ships zero content areas (3.0.0). Content anchors (areas 3/27, langPrefix `/swift-2`) are surface-swift-owned.

**Reference category:** `reference_category` (`EcomProductCategory`, CategoryType 2) + `LANG1` translation — required by DemoVerifier Check 2.

**Contract price:** `EcomPrices` row `FIXT-PRICE-CONTRACT` on `FIXT0001` (customer `98745621`, list × 0.8) — ships in the sample-data layer's `catalog.sql`, present when an edition activates `sampleData: true`.

**Repository:** `Products` / `Products.index` / `Products.query` / `Products.facets`, provisioned by the gate into `wwwroot/Files/System/Repositories/Products/`. (`ProductsFrontend` is dead/removed — never provisioned.)

## Base-owned tables

**Whole-table (`replace`):** EcomCountries, EcomCountryText, EcomCurrencies, EcomLanguages, EcomVatGroups, EcomVatCountryRelations, EcomShops, EcomShopLanguageRelation, EcomShopGroupRelation, EcomPayments, EcomShippings, EcomMethodCountryRelation, EcomOrderFlow, EcomOrderStates, EcomOrderStateRules. (UrlPath: surface-swift-owned since 3.0.0.)

**Filtered (`replace`, FILTER-01):** `AccessUser where AccessUserType = 2 AND AccessUserName IN ('Customers','Account Admin','CSR')` — only the three groups are base-owned; user rows are seeded, not serialized.

**Content:** none (framework-only).

## Collision checks (static, gate-enforced)

1. **Base SqlTable intersection** — addition row keys must be disjoint from base row keys per table.
2. **Cross-layer SqlTable intersection** (WR-10) — the same table+key from >1 active addition fails.
3. **Content path collision** (07-01) — `_content` paths disjoint from base; declared-footprint parity.
4. **Item-instance id collision** (WR-04) — `(itemType, fields.Id)` unique per `ItemType_<systemName>` table.

## Protected upstream strings (never renamed)

Item types `Swift-v2_*` (stock, not shipped by base) and `Headless_*` (shipped by the headless surface); PK tables `ItemType_<systemName>`. These are upstream DW/Swift identifiers — the vocabulary rewrite never touches them (plan §3.1).

---
*Operator-confirmed 2026-07-05 (`.planning/DISTRIBUTION-DECISIONS.md`). Serialized modes: `replace` (source-wins, was `deploy`) / `merge` (destination-wins field-level, was `seed`).*
