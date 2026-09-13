# Base layer — the contract every edition builds on

The **base** is the one privileged layer (`kind: base`). Since the Swift 2.4 base split (3.0.0) it is **framework-only**: shop structure, countries/currencies/languages/VAT, payment/shipping/order flow, and the three permission groups — **zero catalog, zero content areas, zero pages**. The Swift storefront content (areas 3 + 27, both mode trees) and `UrlPath` moved to the **`surface-swift`** layer; the headless content lives in `surface-headless`. Editions compose the base with additions (`feature`, `sample-data`, `surface`, `theme` layers).

The machine-readable guarantees live in [`base.contract.json`](base.contract.json) (v2.2.0); the gate reads that file for the base-contract collision check. Content-scoped contract bits (content anchors, per-environment Area exclusions, protected Swift item types, navDepth, title rules) moved to `layers/surface-swift/surface.contract-notes.json`. This doc is the human companion. **Additions bind only to the base contract — never to each other.**

## The UrlPath decision (Swift 2.4 base split)

`UrlPath` ships in **surface-swift**, not in base 3.0.0. Its single row is a 301 friendly-URL redirect (`products-*` → a Swift page id) bound to area 3 — friendly URLs resolve against pages, and a framework-only base has no route targets. A base-owned UrlPath row would dangle and force base re-proves on Swift page churn. Recorded in both layer docs (this file + `layers/surface-swift/README.md`).

## ID rules

| Key type | Rule |
|---|---|
| **nvarchar PK** on a base-owned table (`PriceId`, `ProductId`, `PaymentId`, …) | Namespace with a **`PACK-<NAME>-`** prefix (uppercase layer name) |
| **int-identity PK** on a SqlTable row | Reserve an id at or above the **`100000`** floor |
| sample-data demo catalog | Reserves `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` |

The base ships **zero catalog** — `EcomGroups/EcomProducts/EcomPrices/EcomDiscount/EcomVariant*/EcomGroupProductRelation` are empty of base rows, so for those tables the collision surface is addition-vs-sample-data-vs-addition (arbitrated statically by the gate). There is deliberately **no per-itemType numeric range table** — the contract is prefix-based.

The floor does not reach `_content` item-instance ids (`ItemType_<systemName>` rows written through a page or paragraph). `ItemType_*` `Id` is a non-identity nvarchar the platform allocates on insert, and the Serializer re-creates item rows by page/paragraph uniqueId, so the target assigns its own id: a YAML `fields.Id` is informational and never lands as the stored id.

## Guaranteed anchors (additions may bind to these)

**Permission groups** (`AccessUser`, type 2 — DW 10.26.9 has no `AccessUserGroup` table):
- `1325` Customers · `1270` Account Admin · `1292` CSR

**Users** (`AccessUser`, type 5), **present only when an edition activates `sampleData: true`** (`presentOnlyWhen: sampleData` in the contract):
- `1328` **IMCUser** (buyer, customer number `98745621`) — member of `1325`
- `1326` **IMCSalesrep** (CSR, customer number `7789765`) — member of `1292`

These rows and their memberships ship in the sample-data layer's `identities.sql`, not in the base. An edition with `sampleData: false` has neither user nor membership, so a persona, sign-in or customer-number binding against them finds no row. A layer probe that needs them names the fixture in its `requiresFixtures`.

**Content:** none — the base ships zero content areas (3.0.0). Content anchors (area 3, langPrefix `/swift-2`) are surface-swift-owned.

**Reference category:** `reference_category` (`EcomProductCategory`, CategoryType 2) + `LANG1` translation — required by DemoVerifier Check 2.

**Shop:** `SHOP1` (B2B Commerce Store) is the only shop and ships `ShopDefault` true, with no completion rules and no completion languages (no layer ships a completion rule). `ShopProductPrimaryPageId` ships `0` because the product page id is per-environment: binding it is a surface-swift consumer obligation.

**Currency rates:** `EcomCurrencies.CurrencyRate` is hundredths against the default currency. EUR is the default at `100`; USD, the currency the Swift storefront serves, ships at `100` (parity with the default, a demo value and not an exchange rate). No shipped row carries a rate at or below `1`, which renders every price a hundred times over.

**Contract price:** `EcomPrices` row `FIXT-PRICE-CONTRACT` on `FIXT0001` (customer `98745621`, list × 0.8) — ships in the sample-data layer's `catalog.sql`, present when an edition activates `sampleData: true`.

**Repository:** `ProductsFrontend` / `Products.index` / `Products.query` / `Products.facets`, at `wwwroot/Files/System/Repositories/ProductsFrontend/`. It ships with the host's Swift design package (present at the Swift 2.4.0 tag next to `ProductsBackend`), not with any layer in this Distribution, so `provisionedByGate` is `false`: the composition references it, the host supplies it. Every `eCom_ProductCatalog` surface the Distribution ships binds it by path (surface-swift Shop PLP, header search and Express Buy; surface-dap-portal Product Assets and Search results; feature-bom-configurator Kit Configurator). A PLP that cannot list products answers HTTP 200 in both failure shapes: with the repository present over an index of zero documents it carries an in-page Lucene `numHits must be > 0` error, and with the repository absent it renders an empty app div with no error text at all. Gate the PLP on a positive subject (at least one product card) plus `dw-error == 0`, never on status or on the absence of error text.

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
