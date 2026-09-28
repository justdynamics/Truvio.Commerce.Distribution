# Base layer — the contract every edition builds on

The **base** is the one privileged layer (`kind: base`). Since the Swift 2.4 base split (3.0.0) it is **framework-only**: shop structure, countries/currencies/languages/VAT, payment/shipping/order flow with the quote states, a neutral US B2B market default, stock locations with their categories, the Swift 2 product group fields, the hidden `reference_category` template row, and five permission groups; **zero catalog, zero content areas, zero pages**. The Swift storefront content (areas 3 + 27, both mode trees) and `UrlPath` moved to the **`surface-swift`** layer; the headless content lives in `surface-headless`. Editions compose the base with additions (`feature`, `sample-data`, `surface`, `theme` layers).

The machine-readable guarantees live in [`base.contract.json`](base.contract.json) (v3.1.0); the gate reads that file for the base-contract collision check. Content-scoped contract bits (content anchors, per-environment Area exclusions, protected Swift item types, navDepth, title rules) moved to `layers/surface-swift/surface.contract-notes.json`. This doc is the human companion. **Additions bind only to the base contract; never to each other.**

## Delivery target: a blank DW10 database

Every edition delivers onto a **blank DW10 database**: the schema and seed rows the **stock DW10 setup wizard** creates at the pinned platform version, and nothing else. No Swift-derived starting database is assumed, and none is supported. The host carries the Swift release Files (the GitHub asset named in `base.contract.json` `deliveryTarget.hostFiles`), the apps `compat.apps` names, and a licence; the **first setup step is the edition deserialize**. Everything the storefront needs beyond the wizard's database comes from the Distribution (owner rulings `distribution-self-sufficient-blank-dw10`, Foundry #1352, and `foundry-starting-db-retired`, Foundry #1421).

What the wizard's database carries, and what the Distribution adds on top of it, is recorded in `base.contract.json` `deliveryTarget`:

- **Wizard seed the layers build on or replace.** Area 1 `Standard` (a one-area composition is delivered onto it; headless-demo's two areas are created beside it), `EcomLanguages` `LANG1`, `EcomShops` `SHOP1`, order flow 1 with `OS1`-`OS4`, the `Images` details group (id 1, where sample-data files every product image), the sixteen `EcomFieldType` rows, the `EcomNumbers` counters and the `Angel` / `Administrator` / `Admin` users. The base's whole-table Replace sets upsert on top of these; none is deleted.
- **Declared by the Distribution because the wizard leaves it empty.** The base ships the two stock location categories its own stock locations and the Customer pickup method use (`EcomStockLocationCategory`), the seven Swift 2 product group field definitions with their `EcomGroups` columns (`EcomProductGroupField`, `schemaSync: EcomGroupFields`), and the `Employees` (1249) and `Find dealers` (95) groups surface-swift's pages list. surface-swift ships the checkout validation its cart paragraphs bind (`EcomValidation*`).
- **Retired columns.** Twenty columns a Swift-derived database carried and the wizard does not create (fourteen DW9-era columns, three unused test fields, the two Swift 1 order fields and `EcomCurrencies.CurrencyUseCurrencyCodeForFormat`) are gone from every layer; `deliveryTarget.retiredColumns` lists them and the validator (check 16) fails a layer that ships one. The quote text the Swift 1 `QuoteRequest` column held is in `OrderCustomerComment`, where Swift 2 posts it.
- **Retired row ids.** A row id a layer shipped for something the wizard already creates is retired in favour of the wizard's row: `EcomDetailsGroup` `100110` (a second `Images` group) gave way to group 1 (owner ruling `vnext-images-detail-group`). `deliveryTarget.retiredIds` lists each id with the columns that reference it, and the validator (check 16) fails a layer that ships one as the row or as a reference.

A Replace never deletes, so a host delivered from a Swift-derived database keeps its extra rows and columns; they are inert, and nothing in the Distribution reads them.

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

The floor applies to the int ids a layer **mints**. The one explicit exception is the base's own permission groups `1325` / `1270` / `1292` / `1249` / `95`, which sit below the floor by contract and ship as base SqlTable rows. Every identity the sample-data layer mints is above it: the B2B account `100100` and the personas `100101` / `100102` / `100103`. Any other id below `100000` is out of contract. No validator checks the int-identity floor; it is an authoring rule.

## Guaranteed anchors (additions may bind to these)

**Permission groups** (`AccessUser`, type 2 — DW 10.26.9 has no `AccessUserGroup` table):
- `1325` Customers · `1270` Account Admin · `1292` CSR
- `1249` Employees · `95` Find dealers (listed by id by surface-swift's Employees and Find dealers pages)

**Users** (`AccessUser`, type 5), **present only when an edition activates `sampleData: true`** (`presentOnlyWhen: sampleData` in the contract):
- `100101` **TruvioBuyer** (buyer, `buyer@truvio-demo.example`) — member of `1325`
- `100102` **TruvioCsr** (CSR, `csr@truvio-demo.example`) — member of `1292`
- `100103` **TruvioAdmin** (account admin, `admin@truvio-demo.example`) — member of `1270`

All three are contacts on one B2B account (`AccessUser` `100100`, **customer number `TC-100200`**) and carry that same customer number: contract prices, account-wide favourites and the CSR account listing compare the string exactly, so a per-contact suffix would limit them to one contact. The rows and their memberships ship in the sample-data layer as merge-mode SqlTable YAML, not in the base, and carry **no password**: the layer's predicate excludes `AccessUserPassword` and the credential is set online through the Management API `UserSetPassword` command. An edition with `sampleData: false` has neither user nor membership, so a persona, sign-in or customer-number binding against them finds no row. A layer probe that needs one names it in its `requiresFixtures`.

## What sample data guarantees (`sampleData` block)

`base.contract.json` carries a `sampleData` block beside `guaranteedRows`: the subjects the one sample-data layer guarantees, so a feature layer binds to the contract and never to the layer. It names the three personas above, the SKU-validation product `TC-VAR-0001` (`TCPROD0001`), the quantity-tier product `TCPROD0020` with its ladder (120 list; 108 / 96 / 84 at 5 / 10 / 25) and its customer-group row, the contract-price product `TCPROD0046` / `TC-PRICE-CTR-0046` at `TC-100200`, the configurable Bundle Kit `TCPROD0042` with its two `EcomProductItems` slots, the subscription plan `TCPROD0061`, the delivered order `TCO-0001`, the RMA `PACK-RMA-0001` bound to that order (a sample-data row since sample-data 6.0.0, when `feature-rma` was folded in), and `customerCenter`: the buyer's orders, quotes, carts and favourite lists the surface-swift dashboard draws, all in USD. Each entry names the probe that addresses it. The block also pins the catalogue counts an edition asserts: `EcomProducts` 97, `EcomGroups` 21.

**Content:** none — the base ships zero content areas (3.0.0). Content anchors (area 3, langPrefix `/swift-2`) are surface-swift-owned.

**Reference category:** `reference_category` (`EcomProductCategory`, CategoryType 2, `CategoryAutoId` 100136) + its `ENU` translation “Reference category” (`CategoryTranslationAutoId` 100135) — the hidden template category Dynamicweb's completeness-rule and category-field admin UI reads, and the subject of DemoVerifier Check 2. **The base actually ships both rows only from 3.6.0** (Foundry #1304): this doc claimed the row from 3.0.0, but no predicate carried it and the Foundry gate synthesised it pre-host-start instead (`tools/harness/Invoke-SeedVerify.ps1`, Step 3b), so a consumer deserializing the Distribution outside the gate never got it. They ship as two **filtered** Replace predicates (FILTER-02 / FILTER-03) — the concrete `tc_*` categories are sample-data merge rows and a whole-table Replace would wipe them. The gate seed stays, `IF NOT EXISTS`-guarded on the category id, so a host it already seeded with a `LANG1` translation keeps that row alongside the shipped `ENU` one.

**Shop:** `SHOP1` (B2B Commerce Store) is the only shop and ships `ShopDefault` true, with no completion rules and no completion languages (no layer ships a completion rule). `ShopProductPrimaryPageId` ships `0` because the product page id is per-environment: binding it is a surface-swift consumer obligation.

**Currency rates:** `EcomCurrencies.CurrencyRate` is hundredths against the default currency. Since 4.0.0 USD is the default at `100`, flagged on every `USD$$<lang>` row; EUR ships at `100` as well (parity with the default, a demo value and not an exchange rate). No shipped row carries a rate at or below `1`, which renders every price a hundred times over. The currency a storefront serves is its area binding (`AreaEcomCurrencyId`), owned by the surface layer that ships the area, not this flag.

## Market defaults (4.0.0): US / B2B

The base ships a neutral US B2B market, so an edition with no market work checks out on account in USD. A demo for another market rewrites these rows the other way in a demo-local layer.

| Table | Id | 4.0.0 | Active |
|---|---|---|---|
| `EcomCurrencies` | `USD` | default currency, rate 100 (EUR stays at 100) | |
| `EcomPayments` | `PAY2` | On account (Net 30), terms `NET30`, gateway-less checkout handler, US default | yes |
| `EcomPayments` | `PAY1` | Credit card, no gateway bound | no |
| `EcomPayments` | `PAY3` | Inactive payment method (was MobilePay) | no |
| `EcomShippings` | `SHIP9` | Standard ground, US default | yes |
| `EcomShippings` | `SHIP11` | Express | yes |
| `EcomShippings` | `SHIP6` | Freight / LTL | yes |
| `EcomShippings` | `SHIP5` | Customer pickup (stock-location provider on `STOCKLOCCAT1`) | yes |
| `EcomShippings` | `SHIP3`, `SHIP4`, `SHIP8`, `SHIP10`, `SHIP12`, `SHIP13` | Inactive shipping method (the Danish carriers) | no |
| `EcomVatGroups` | `VATGRP1`, `VATGRP2` | Tax (DK), Tax default; VAT name `Tax` | |

Every id is kept and only renamed, reconfigured or deactivated. A `Replace` predicate never deletes a row missing from the tree, so a dropped carrier would stay active on a host delivered from 3.x; shipped inactive, it is switched off there too. `PAY2` / `SHIP9` are also the ids `feature-subscription-orders` posts in its checkout probe. The `DAN` language rows of the same ids carry Danish translations of the neutral names. The base has no default-country column: the storefront's default country is the area's `AreaEcomCountryCode`, and the base makes US the default in the method-country relations (`CREL3001` / `CREL3002` added for `SHIP9` / `SHIP11`). See `base.contract.json` `marketDefaults`.

## Quote states (4.0.0)

The `Default Quote flow` (`OrderFlowId` 3) carries `QuotePending` (default), `QuoteSent`, `QuoteAccepted` and `QuoteRejected`. The ids are Swift's literal ids: the Swift 2.4 Pending quotes dashboard widget asks for `StateId=QuotePending`. The stock `OS8` New and `OS9` Price given stay in the flow without the default flag. No state rule is added, so every transition stays open. See `base.contract.json` `quoteStates`.

**Contract price:** `EcomPrices` row `TC-PRICE-CTR-0046` on `TCPROD0046` (customer number `TC-100200`, 36.90 against a 45.00 list and a 39.60 customer-group row) — ships in the sample-data layer, present when an edition activates `sampleData: true`.

**Repositories:** a composition needs two, each under its own folder name. `ProductsFrontend` / `Products.index` / `Products.query` / `Products.facets`, at `wwwroot/Files/System/Repositories/ProductsFrontend/`, ships with the host's Swift design package (present at the Swift 2.4.0 tag next to `ProductsBackend`), not with any layer in this Distribution, so `provisionedByGate` is `false`: the composition references it, the host supplies it. It is bound by path by the surface-swift desktop header search, Express Buy and the two related-products service pages; surface-dap-portal Product Assets and Search results; feature-bom-configurator Kit Configurator; and feature-reordering Quick Order. `TruvioCommerce`, at `wwwroot/Files/System/Repositories/TruvioCommerce/`, is shipped by surface-swift (`repositories/TruvioCommerce/`) and bound by the surface-swift Shop PLP (`IndexQuery` and `FacetGroups`), the product and content search results, the favorites list service and the variant selector service. Deploy it under exactly that name: renamed to `ProductsFrontend` it leaves the Shop PLP empty. `base.contract.json` `repositories` lists every binding (`boundBy`, `layerShipped`); a layer's `repositoryName` is descriptive only. A PLP that cannot list products answers HTTP 200 in both failure shapes: with the repository present over an index of zero documents it carries an in-page Lucene `numHits must be > 0` error, and with the repository absent it renders an empty app div with no error text at all. Gate the PLP on a positive subject (at least one product card) plus `dw-error == 0`, never on status or on the absence of error text.

## Base-owned tables

**Whole-table (`replace`), 19 tables:** EcomCountries, EcomCountryText, EcomCurrencies, EcomLanguages, EcomVatGroups, EcomVatCountryRelations, EcomShops, EcomShopLanguageRelation, EcomShopGroupRelation, **EcomStockLocationCategory** (4.1.0), **EcomStockLocation** (3.6.0), **EcomStockLocationTranslations** (3.6.0), **EcomProductGroupField** (4.1.0, `schemaSync: EcomGroupFields`), EcomPayments, EcomShippings, EcomMethodCountryRelation, EcomOrderFlow, EcomOrderStates (keyed by `OrderStateId` since 4.1.0), EcomOrderStateRules. (UrlPath: surface-swift-owned since 3.0.0.)

`EcomShopGroupRelation` is base-owned but ships **zero rows** from 3.6.0 (Foundry #1198). It carried 31 `GROUP<n>$$SHOP1` rows harvested from a Swift database, every one of them pointing at a numeric `EcomGroups` id that **no layer in this Distribution ships**; the base ships zero catalogue and the sample-data groups are all `TCGRP-*`. The entry keeps its `_meta.yml`, so the table stays base-owned, and the real shop-group rows arrive as merge rows from `sample-data`. Dropping the files stops the replay only: a `Replace` predicate is an upsert by key and never deletes a row absent from the tree (Serializer 1.0.2-beta, `docs/swift-replace-merge-analysis.md` D-5; measured on foundry.mydwsite4.com, gate run 20260919-153644), so a host delivered from 3.5.3 or earlier keeps its orphans until `sample-data/tools/retire-4x-ids.sql` deletes them. The Foundry `pim-structure` leg asserts zero orphans.

**Filtered (`replace`):**

- **FILTER-01**: `AccessUser where AccessUserType = 2 AND AccessUserName IN ('Customers','Account Admin','CSR','Employees','Find dealers')`: only the five groups are base-owned; user rows ship in sample-data, never in the base.
- **FILTER-02** (3.6.0) — `EcomProductCategory where CategoryId = 'reference_category'`: the hidden template category only. The `tc_*` categories are sample-data merge rows.
- **FILTER-03** (3.6.0) — `EcomProductCategoryTranslation where CategoryTranslationCategoryId = 'reference_category'`: its `ENU` display name, on the same reasoning.

### Stock locations (3.6.0, Foundry #1303)

Stock locations are framework configuration, not catalogue, and the base owns **all three** tables whole: `EcomStockLocationCategory`, `EcomStockLocation` and `EcomStockLocationTranslations`. The translation table matters as much as the parent: **it is where the name Dynamicweb actually renders lives**. The base ships three neutral locations in each location table:

| Id | Name | ExternalId | Sort | Category |
|---|---|---|---|---|
| 1 | Central warehouse | `CENTRAL` | 1 | `STOCKLOCCAT1` |
| 2 | Regional warehouse | `REGIONAL` | 2 | `STOCKLOCCAT2` |
| 3 | Default stock location | `DEFAULT` | 3 | `STOCKLOCCAT1` |

`EcomStockLocationTranslations` carries the same three ids keyed `ENU` with those same names and an empty description; it has **no identity column**, so the composite `StockLocationId` + `LanguageId` is the whole key. Language `ENU` throughout; every other column empty or `0`.

`EcomStockLocationCategory` carries `STOCKLOCCAT1` “Click and collect” and `STOCKLOCCAT2` “Warehouse” (identities 4 and 5). The stock DW10 setup wizard creates the table empty, so the base ships both rows: the locations above sit in them, and the base's own Customer pickup delivery method (`EcomShippings/Customer pickup.yml`, `SHIP5`, named Click & Collect before 4.0.0) lists the pickup locations of `STOCKLOCCAT1`.

**The ids 1-3 are deliberately kept, not rekeyed above the `intIdentityFloor`**: all 61 `EcomStockUnit` rows in the sample-data layer carry `StockUnitStockLocationId` 3, and `EcomShops.ShopStockLocationID` addresses the same id space (`SHOP1` ships `0`). A rekey would orphan the stock units. Like the permission groups, these are base-owned rows on the ids a Swift database used, kept so existing bindings hold; an addition that needs a stock location of its own mints one at or above `100000`. See `base.contract.json` → `stockLocations`.

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
