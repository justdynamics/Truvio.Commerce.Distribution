# Base layer — the contract every edition builds on

The **base** is the one privileged layer (`kind: base`). Since the Swift 2.4 base split (3.0.0) it is **framework-only**: shop structure, countries/currencies/languages/VAT, payment/shipping/order flow, stock locations, the hidden `reference_category` template row, and the three permission groups — **zero catalog, zero content areas, zero pages**. The Swift storefront content (areas 3 + 27, both mode trees) and `UrlPath` moved to the **`surface-swift`** layer; the headless content lives in `surface-headless`. Editions compose the base with additions (`feature`, `sample-data`, `surface`, `theme` layers).

The machine-readable guarantees live in [`base.contract.json`](base.contract.json) (v2.4.0); the gate reads that file for the base-contract collision check. Content-scoped contract bits (content anchors, per-environment Area exclusions, protected Swift item types, navDepth, title rules) moved to `layers/surface-swift/surface.contract-notes.json`. This doc is the human companion. **Additions bind only to the base contract — never to each other.**

## The UrlPath decision (Swift 2.4 base split)

`UrlPath` ships in **surface-swift**, not in base 3.0.0. Its single row is a 301 friendly-URL redirect (`products-*` → a Swift page id) bound to area 3 — friendly URLs resolve against pages, and a framework-only base has no route targets. A base-owned UrlPath row would dangle and force base re-proves on Swift page churn. Recorded in both layer docs (this file + `layers/surface-swift/README.md`).

## The ecommerce URL providers — retired in 3.5.3 (Foundry #1298)

The base shipped `files/System/Truvio/globalsettings.url.fragment.config` in 3.5.2, an activation
block for `/Globalsettings/System/Url/Providers` intended to fix Foundry #1281. It did not fix it,
and the leaf is **inert on Dynamicweb 10**: the DW9-era ecommerce URL providers
(`eComGroupPathProvider`, `eComProductProvider`, `eComProductAndVariantProvider`) no longer exist
in DW10. Friendly ecommerce URLs on DW10 come from a URL provider configured on the page's SEO tab
(`Page.PageUrlDataProvider` = `ShopUrlDataProvider`) — see
[the DW10 URL provider manual](https://doc.dynamicweb.dev/manual/dynamicweb10/content/url-provider.html).

The real cause of #1281 was area 3 carrying neither `AreaEcomShopID` nor `AreaEcomLanguageID`; the
fix is the area shop + language binding in **surface-swift 1.13.9** and **sample-data 4.1.3**,
proven by gate run `20260917-154558`.

Base 3.5.3 therefore ships **no files at all** — no `files[]`, no `placeholders[]`. The base is the
layer that must stay minimal, and dead configuration in it is worse than none: it is the first
wrong place a reader looks.

A rename still mints no 301 (Foundry #112): once friendly URLs are live, renaming a group or a
product regenerates the URL and the old one is not redirected. Anything pinned to a friendly
product URL is invalidated by a rename, silently.

## ID rules

| Key type | Rule |
|---|---|
| **nvarchar PK** on a base-owned table (`PriceId`, `ProductId`, `PaymentId`, …) | Namespace with a **`PACK-<NAME>-`** prefix (uppercase layer name) |
| **int-identity PK** on a SqlTable row | Reserve an id at or above the **`100000`** floor |
| sample-data demo catalogue | Reserves the `TC*` family (`TCGRP-*`, `TCPROD*`, `TCVG-*`, `TCVGR-*`, `TCVO-*`, `TC-PRICE-*`, `TC-BOM-*`, `TC-DETAIL-*`, `TC-DOC-*`, `TC-GAL-*`, `TC-HOVER-*`, `TCREL-*`, `TCO-*`, `tc_*`) |

The base ships **zero catalog** — `EcomGroups/EcomProducts/EcomPrices/EcomDiscount/EcomVariant*/EcomGroupProductRelation` are empty of base rows, so for those tables the collision surface is addition-vs-sample-data-vs-addition (arbitrated statically by the gate). There is deliberately **no per-itemType numeric range table** — the contract is prefix-based.

The floor does not reach `_content` item-instance ids (`ItemType_<systemName>` rows written through a page or paragraph). `ItemType_*` `Id` is a non-identity nvarchar the platform allocates on insert, and the Serializer re-creates item rows by page/paragraph uniqueId, so the target assigns its own id: a YAML `fields.Id` is informational and never lands as the stored id.

The floor applies to the int ids a layer **mints**. The one explicit exception is the base's own permission groups `1325` / `1270` / `1292`, which sit below the floor by contract and ship as base SqlTable rows. Every identity the sample-data layer mints is above it: the B2B account `100100` and the personas `100101` / `100102` / `100103`. Any other id below `100000` is out of contract. No validator checks the int-identity floor; it is an authoring rule.

## Guaranteed anchors (additions may bind to these)

**Permission groups** (`AccessUser`, type 2 — DW 10.26.9 has no `AccessUserGroup` table):
- `1325` Customers · `1270` Account Admin · `1292` CSR

**Users** (`AccessUser`, type 5), **present only when an edition activates `sampleData: true`** (`presentOnlyWhen: sampleData` in the contract):
- `100101` **TruvioBuyer** (buyer, `buyer@truvio-demo.example`) — member of `1325`
- `100102` **TruvioCsr** (CSR, `csr@truvio-demo.example`) — member of `1292`
- `100103` **TruvioAdmin** (account admin, `admin@truvio-demo.example`) — member of `1270`

All three are contacts on one B2B account (`AccessUser` `100100`, **customer number `TC-100200`**) and carry that same customer number: contract prices, account-wide favourites and the CSR account listing compare the string exactly, so a per-contact suffix would limit them to one contact. The rows and their memberships ship in the sample-data layer as merge-mode SqlTable YAML, not in the base, and carry **no password**: the layer's predicate excludes `AccessUserPassword` and the credential is set online through the Management API `UserSetPassword` command. An edition with `sampleData: false` has neither user nor membership, so a persona, sign-in or customer-number binding against them finds no row. A layer probe that needs one names it in its `requiresFixtures`.

## What sample data guarantees (`sampleData` block)

`base.contract.json` carries a `sampleData` block beside `guaranteedRows`: the subjects the one sample-data layer guarantees, so a feature layer binds to the contract and never to the layer. It names the three personas above, the SKU-validation product `TC-VAR-0001` (`TCPROD0001`), the quantity-tier product `TCPROD0020` with its ladder (120 list; 108 / 96 / 84 at 5 / 10 / 25) and its customer-group row, the contract-price product `TCPROD0046` / `TC-PRICE-CTR-0046` at `TC-100200`, the configurable Bundle Kit `TCPROD0042` with its two `EcomProductItems` slots, the subscription plan `TCPROD0061`, the delivered order `TCO-0001`, and the RMA `PACK-RMA-0001` that `feature-rma` itself owns and binds to that order. Each entry names the probe that addresses it. The block also pins the catalogue counts an edition asserts: `EcomProducts` 97, `EcomGroups` 16.

**Content:** none — the base ships zero content areas (3.0.0). Content anchors (area 3, langPrefix `/swift-2`) are surface-swift-owned.

**Reference category:** `reference_category` (`EcomProductCategory`, CategoryType 2, `CategoryAutoId` 100136) + its `ENU` translation “Reference category” (`CategoryTranslationAutoId` 100135) — the hidden template category Dynamicweb's completeness-rule and category-field admin UI reads, and the subject of DemoVerifier Check 2. **The base actually ships both rows only from 3.6.0** (Foundry #1304): this doc claimed the row from 3.0.0, but no predicate carried it and the Foundry gate synthesised it pre-host-start instead (`tools/harness/Invoke-SeedVerify.ps1`, Step 3b), so a consumer deserializing the Distribution outside the gate never got it. They ship as two **filtered** Replace predicates (FILTER-02 / FILTER-03) — the concrete `tc_*` categories are sample-data merge rows and a whole-table Replace would wipe them. The gate seed stays, `IF NOT EXISTS`-guarded on the category id, so a host it already seeded with a `LANG1` translation keeps that row alongside the shipped `ENU` one.

**Shop:** `SHOP1` (B2B Commerce Store) is the only shop and ships `ShopDefault` true, with no completion rules and no completion languages (no layer ships a completion rule). `ShopProductPrimaryPageId` ships `0` because the product page id is per-environment: binding it is a surface-swift consumer obligation.

**Currency rates:** `EcomCurrencies.CurrencyRate` is hundredths against the default currency. EUR is the default at `100`; USD, the currency the Swift storefront serves, ships at `100` (parity with the default, a demo value and not an exchange rate). No shipped row carries a rate at or below `1`, which renders every price a hundred times over.

**Contract price:** `EcomPrices` row `TC-PRICE-CTR-0046` on `TCPROD0046` (customer number `TC-100200`, 36.90 against a 45.00 list and a 39.60 customer-group row) — ships in the sample-data layer, present when an edition activates `sampleData: true`.

**Repository:** `ProductsFrontend` / `Products.index` / `Products.query` / `Products.facets`, at `wwwroot/Files/System/Repositories/ProductsFrontend/`. It ships with the host's Swift design package (present at the Swift 2.4.0 tag next to `ProductsBackend`), not with any layer in this Distribution, so `provisionedByGate` is `false`: the composition references it, the host supplies it. Every `eCom_ProductCatalog` surface the Distribution ships binds it by path (surface-swift Shop PLP, header search and Express Buy; surface-dap-portal Product Assets and Search results; feature-bom-configurator Kit Configurator). A PLP that cannot list products answers HTTP 200 in both failure shapes: with the repository present over an index of zero documents it carries an in-page Lucene `numHits must be > 0` error, and with the repository absent it renders an empty app div with no error text at all. Gate the PLP on a positive subject (at least one product card) plus `dw-error == 0`, never on status or on the absence of error text.

## Base-owned tables

**Whole-table (`replace`), 16 tables:** EcomCountries, EcomCountryText, EcomCurrencies, EcomLanguages, EcomVatGroups, EcomVatCountryRelations, EcomShops, EcomShopLanguageRelation, EcomShopGroupRelation, **EcomStockLocation** (3.6.0), EcomPayments, EcomShippings, EcomMethodCountryRelation, EcomOrderFlow, EcomOrderStates, EcomOrderStateRules. (UrlPath: surface-swift-owned since 3.0.0.)

`EcomShopGroupRelation` is base-owned but ships **zero rows** from 3.6.0 (Foundry #1198). It carried 31 `GROUP<n>$$SHOP1` rows inherited from the platform baseline, every one of them pointing at a numeric `EcomGroups` id that **no layer in this Distribution ships** — the base ships zero catalogue and the sample-data groups are all `TCGRP-*`. The entry keeps its `_meta.yml`, so the whole-table Replace still wipes the table on a target and the real shop-group rows arrive as merge rows from `sample-data` and `feature-reordering-pricing`.

**Filtered (`replace`):**

- **FILTER-01** — `AccessUser where AccessUserType = 2 AND AccessUserName IN ('Customers','Account Admin','CSR')`: only the three groups are base-owned; user rows are seeded, not serialized.
- **FILTER-02** (3.6.0) — `EcomProductCategory where CategoryId = 'reference_category'`: the hidden template category only. The `tc_*` categories are sample-data merge rows.
- **FILTER-03** (3.6.0) — `EcomProductCategoryTranslation where CategoryTranslationCategoryId = 'reference_category'`: its `ENU` display name, on the same reasoning.

### Stock locations (3.6.0, Foundry #1303)

`EcomStockLocation` is framework configuration, not catalogue, and the base now owns the whole table. The platform baseline shipped the Swift demo's own rows — `1 BikeShop Copenhagen`, `2 BikeShop Aarhus`, `3 Default stock location` — so **every composed edition delivered a bike shop's warehouse names**. The base ships three neutral rows on **the same ids**:

| Id | Name | ExternalId | Sort |
|---|---|---|---|
| 1 | Central warehouse | `CENTRAL` | 1 |
| 2 | Regional warehouse | `REGIONAL` | 2 |
| 3 | Default stock location | `DEFAULT` | 3 |

Language `ENU`; every other column empty or `0`. **The ids 1-3 are deliberately kept, not rekeyed above the `intIdentityFloor`**: all 61 `EcomStockUnit` rows in the sample-data layer carry `StockUnitStockLocationId` 3, and `EcomShops.ShopStockLocationID` addresses the same id space (`SHOP1` ships `0`). A rekey would orphan the stock units. Like the permission groups `1325`/`1270`/`1292`, these are base-owned rows the base **adopts** from the platform baseline rather than mints; an addition that needs a stock location of its own mints one at or above `100000`. See `base.contract.json` → `stockLocations`.

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
