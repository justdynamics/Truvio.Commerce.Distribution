# Changelog — base

## 4.0.0

Major: the base ships the quote order states and a neutral US / B2B market default (owner rulings
Q2 and Q9, 2026-09-24, distribution layer analysis). The default currency moves from EUR to USD and
the payment, shipping and tax rows change meaning, which is a breaking change for any consumer that
read them. `baseContractVersion` 2.4.0 -> 3.0.0. No floor in `versions/spine.json` moves, no table is
added or removed, and every row key is kept.

**Quote states (Q2).** Four `EcomOrderStates` rows in the `Default Quote flow` (`OrderFlowId` 3,
order type 1): `QuotePending` "Quote pending" (the flow default, allow edit), `QuoteSent` "Quote
sent" (allow order), `QuoteAccepted` "Quote accepted" (allow order) and `QuoteRejected` "Quote
rejected". The ids are the literal ids Swift 2.4 uses: `Swift-v2_Dashboard_List/QuotesPending.cshtml`
asks the order search for `StateId=QuotePending`, so without that exact id the Pending quotes widget
renders its empty state forever. Five demos built these states by hand (marine, Leatherman, Hewitt,
Burco, Team Horner). The stock `OS8` New loses the default flag, so a submitted quote lands in
`QuotePending`; `OS8` and `OS9` Price given stay in the flow at sort 5 and 6. No
`EcomOrderStateRules` row is added: the four states carry no rule, so every transition stays open,
the shape the marine demo ran on. The whole-table `EcomOrderStates` predicate already covers the new
rows. New contract block `quoteStates`.

**Market defaults (Q9).** A neutral US B2B market instead of the Swift demo's Danish one:

| Row | 3.6.0 | 4.0.0 |
|---|---|---|
| `EcomCurrencies` `USD$$*` (17 rows) | rate 100, not default | **default**, rate 100 |
| `EcomCurrencies` `EUR$$*` (16 rows) | default, rate 100 | rate 100 (parity) |
| `EcomPayments` `PAY2` ENU / DAN | Invoice / Faktura | **On account (Net 30)** / På konto (netto 30), terms `NET30`, active |
| `EcomPayments` `PAY1` ENU / DAN | Creditcard / Kreditkort, QuickPay icon | Credit card / Kreditkort, no icon, **inactive** (no gateway) |
| `EcomPayments` `PAY3` ENU | MobilePay | Inactive payment method (PAY3), **inactive** |
| `EcomShippings` `SHIP9` ENU / DAN | Home delivery / Hjemmelevering | **Standard ground** / Standard levering |
| `EcomShippings` `SHIP11` ENU / DAN | Business delivery / Firmalevering | **Express** / Ekspres |
| `EcomShippings` `SHIP6` ENU / DAN | UPS | **Freight / LTL** / Fragt / LTL |
| `EcomShippings` `SHIP5` ENU | Click & Collect delivery method, inactive | **Customer pickup**, active |
| `EcomShippings` `SHIP3`, `SHIP4`, `SHIP8`, `SHIP10`, `SHIP12`, `SHIP13` | GLS, PostNord, DAO, Bring | Inactive shipping method (SHIPn), **inactive**, provider cleared |
| `EcomVatGroups` `VATGRP1` / `VATGRP2` | Moms / VAT Default, VAT name Moms / VAT | Tax (DK) / Tax default, VAT name Tax |
| `EcomMethodCountryRelation` US | PAY1 and SHIP6 default | **PAY2 and SHIP9 default**; `CREL3001` (SHIP9) and `CREL3002` (SHIP11) added |

Rows are renamed and deactivated, never dropped. A `Replace` predicate is an upsert by key and never
deletes a row missing from the tree, so a dropped carrier would stay active on every host delivered
from 3.x; shipped inactive, it is switched off there too, and the row counts an edition pins
(`EcomPayments` 5, `EcomShippings` 17) hold. `PAY2` and `SHIP9` keep their meaning for
`feature-subscription-orders`, whose checkout probe posts both: `PAY2` stays the gateway-less
checkout handler (`PaymentAddInType` None, `IRecurring`). The base has no default-country column,
so "US as default country" is the method-country default here and the area's
`AreaEcomCountryCode` in the surface layer that ships the area. New contract block
`marketDefaults`; `currencyRates` gains `defaultCurrency` and a rewritten note.

Editions: every edition pins `base@4.0.0`; `base-only` pins `EcomOrderStates` 18 (14 + the four
quote states).

## 3.6.0

**Serializer floor `1.0.2-beta` -> `1.0.6-beta` (2026-09-22, Distribution #78, before 3.6.0 is
merged, so no new base version).** `compat.apps[Truvio.Commerce.Serializer].min` and the
`minSerializerVersion` alias move together, and `serializerTaughtSurfaceNote` gains the reason:
1.0.2-beta wrote a table with no primary key (`DynamicStructures`, `Languages`) as `DELETE FROM`
plus insert in every mode, so sample-data's one merged workspace row deleted every workspace the
host had (Foundry #1305, Serializer #21). 1.0.3-beta resolves a match key, never deletes under
Merge, and reports a `Deleted` count. sample-data 5.0.1 declares `keyColumns` on its
`DynamicStructures` predicate, which only 1.0.3-beta and later read; 1.0.5-beta rather than 1.0.3-beta because 1.0.3-beta and 1.0.4-beta log a WARNING for a heap entry even with declared `keyColumns`, and strict mode (the Management API default) fails the deserialize on it (Serializer #30, gate run `20260922-223534`). 1.0.5-beta logs a declared key as an info line. 1.0.6-beta rather than 1.0.5-beta because 1.0.3-beta to 1.0.5-beta stopped remapping page ids held in option-list fields (Swift's ProductListComponentSelector / ProductComponentSelector ComponentSource and ProductBom ListComponentSource, RadioButtonListEditor with valueField PageId), so a delivered storefront listed zero products (Serializer #32, gate run 20260922-231413); 1.0.6-beta resolves ItemType/Sql option sources with valueField PageId or ParagraphId through the page and paragraph maps whatever the editor. `baseContractVersion` stays 2.4.0:
the 3.6.0 contract is not yet on main.

Minor: the base stops shipping a bike shop's warehouse names, stops shipping 31 rows that point at
nothing, and finally ships the one row `BASE.md` has claimed since 3.0.0. Four tables are gained
(`EcomStockLocation`, `EcomStockLocationTranslations`, `EcomProductCategory`,
`EcomProductCategoryTranslation`), 31 orphan rows are dropped, and `baseContractVersion` moves 2.3.1 -> 2.4.0 (additive). No layer.json `files[]`, no SQL
set, no `sampleData` change.

**`EcomStockLocation` AND `EcomStockLocationTranslations` become base-owned, whole-table
`replace` (Foundry #1303).** The platform baseline carries the Swift demo's own rows in both -
`1 BikeShop Copenhagen`, `2 BikeShop Aarhus` (description `Warehouse west`), `3 Default stock
location` - and no predicate ever touched either table, so **every composed edition delivered a
bike shop's warehouse names** on a host the Distribution otherwise scrubbed of Swift demo
vocabulary. Measured on `foundry.mydwsite4.com`. The translation table is the one that matters
for what a user sees: **`EcomStockLocationTranslations` is where the rendered name lives**, so
correcting `EcomStockLocation.StockLocationName` alone would have shipped a cosmetic fix that
changed nothing on screen. The base now ships three neutral rows in each:

| Id | Name | ExternalId | Sort | Category |
|---|---|---|---|---|
| 1 | Central warehouse | `CENTRAL` | 1 | `STOCKLOCCAT1` |
| 2 | Regional warehouse | `REGIONAL` | 2 | `STOCKLOCCAT2` |
| 3 | Default stock location | `DEFAULT` | 3 | `STOCKLOCCAT1` |

`EcomStockLocationTranslations` mirrors the three ids on `ENU` with the same names and an empty
description. It has **no identity column**: the composite `StockLocationId` + `LanguageId` is the
whole key, so the `_meta.yml` carries `identityColumns: []`. Language `ENU` throughout, every
other column empty or `0`.

**`StockLocationCategoryId` is kept exactly as the baseline carries it** - `1` and `3` ->
`STOCKLOCCAT1`, `2` -> `STOCKLOCCAT2` - and is NOT blanked. `EcomStockLocationCategory` exists on
every host with `STOCKLOCCAT1` "Click and collect" and `STOCKLOCCAT2` "Warehouse", it stays
**baseline-owned** (no layer here serializes it), and the base's own Click & Collect delivery
method needs pickup locations sitting in that category. Blanking the column would have taken the
pickup locations out of Click & Collect to no purpose.

**The ids 1-3 are kept deliberately** and are not
rekeyed above `idRules.intIdentityFloor`: all 61 `EcomStockUnit` rows in the sample-data layer carry
`StockUnitStockLocationId` 3, and `EcomShops.ShopStockLocationID` addresses the same id space
(`SHOP1` ships `0`). A rekey would orphan the stock units for a cosmetic win. Like the permission
groups `1325`/`1270`/`1292`, these are rows the base **adopts** from the platform baseline rather
than mints; the new `stockLocations` block in `base.contract.json` records that exception so a
reader does not file it as a floor violation. `Replace`, not `Merge`, so a re-deserialize restores
the neutral set instead of leaving a previously delivered `BikeShop Copenhagen` in place.

**`reference_category` ships for real (Foundry #1304).** `BASE.md` line 65 has named
`reference_category` (`EcomProductCategory`, CategoryType 2) plus its translation as a guaranteed
anchor since 3.0.0, and `base.contract.json` has carried it in `guaranteedRows.referenceCategory`.
**Neither row ever shipped.** No predicate covered either table, and the only thing producing the
row was the Foundry gate, which synthesises it pre-host-start as Step 3b
(`tools/harness/Invoke-SeedVerify.ps1`, the prerequisite for DemoVerifier Check 2). A consumer who
deserialized the Distribution without the gate got a host with no template category - and DW's
completeness-rule and category-field admin UI read that row. The base now ships both rows as
**filtered** `Replace` predicates:

- **FILTER-02** - `EcomProductCategory where CategoryId = 'reference_category'`
  (`CategoryAutoId` 100136, `CategoryType` 2).
- **FILTER-03** - `EcomProductCategoryTranslation where CategoryTranslationCategoryId = 'reference_category'`
  (`ENU`, "Reference category", `CategoryTranslationAutoId` 100135).

Filtered and never whole-table: the concrete `tc_*` categories and their `tc_*$$ENU` translations
are sample-data-owned **merge** rows, and a whole-table `Replace` here would wipe the entire product
category model on every re-deserialize. The contract's `translation.languageId` moves `LANG1` ->
`ENU`, matching every other ENU-keyed display name in the Distribution; the gate's own seed stays
and is `IF NOT EXISTS`-guarded on the category id, so a host it already seeded with a `LANG1` row
keeps that row and simply gains the `ENU` one. Check 2 probes the parent row only, so it is
unaffected either way.

**`EcomShopGroupRelation` drops its 31 rows (Foundry #1198).** The base shipped
`GROUP1`/`GROUP2`/`GROUP5` ... `GROUP252`$$`SHOP1` - 31 relations inherited from the platform
baseline, every one binding `SHOP1` to a numeric `EcomGroups` id. **No layer in this Distribution
ships any of those groups**: the base ships zero catalogue (`idRules.baseCatalog` = `empty`) and
every group the sample-data and feature layers ship is `TCGRP-*` or `PACK-RPP-GRP1`. Verified by
grepping every `_sql/EcomGroups/*.yml` in the tree before the delete. The rows therefore landed on
each delivered host as 31 relations to groups that do not exist. The entry keeps its `_meta.yml`, so
the table stays base-owned, and the real rows arrive as merge rows from `sample-data` and
`feature-reordering-pricing`. **Dropping the files stops the replay; it does not remove rows a host
already carries.** Measured on the Serializer 1.0.2-beta source and on foundry.mydwsite4.com (gate
run 20260919-153644): a `Replace` predicate is an upsert by key and never deletes a row absent from
the tree (`docs/swift-replace-merge-analysis.md` D-5); only a table with no primary key is
`DELETE FROM` + inserted (`SqlTableProvider.cs:345-360`). A host delivered from 3.5.3 or earlier
keeps its 31 orphans until an operator deletes them; `sample-data/tools/retire-4x-ids.sql` carries
that delete, and the Foundry `pim-structure` gate leg asserts zero orphans. The pristine
`dw10-demo-empty` baseline carries no `EcomShopGroupRelation` row at all, so a fresh clone starts
clean.

`layer.json` gains `fragmentTables`, which the base had never declared, now listing all 20 tables it
ships (the static key-collision input the schema describes); the three new tables are in it.

Consumers: a host delivered from 3.5.x and re-deserialized from 3.6.0 gets the neutral stock-location
names in both tables, the `reference_category` pair, and an `EcomShopGroupRelation` wiped and refilled from the
addition layers only. Nothing to run by hand. A host that was never gated gains a template category
it was silently missing.

## 3.5.3

Patch: the base drops the one file 3.5.2 added —
`files/System/Truvio/globalsettings.url.fragment.config` — and with it the `files[]` and
`placeholders[]` registrations in `layer.json`. The base ships **no files at all** again. No SQL
set, no base row, no row count, no guaranteed row and no `base.contract.json` change;
`baseContractVersion` is unmoved.

The fragment was shipped in 3.5.2 to fix Foundry #1281. It did not. #1281 was caused by area 3
carrying neither `AreaEcomShopID` nor `AreaEcomLanguageID`, and was fixed by **surface-swift
1.13.9** + **sample-data 4.1.3** (Distribution #69, #70), proven by gate run `20260917-154558`.

The leaf is **inert on Dynamicweb 10**. Per
<https://doc.dynamicweb.dev/manual/dynamicweb10/content/url-provider.html>, the DW9-era ecommerce
URL providers (`eComGroupPathProvider`, `eComProductProvider`, `eComProductAndVariantProvider`) no
longer exist in DW10; friendly ecommerce URLs come from a URL provider configured on the page's
SEO tab (`Page.PageUrlDataProvider` = `ShopUrlDataProvider`). Measured on `foundry.mydwsite4.com`:
the leaf was live on the host through every one of the nine isolation recycles of the #1281
investigation and changed nothing on its own.

Shipping dead configuration in the base is worse than shipping none — it is the wrong place a
future reader looks first, and the base is the layer that must stay minimal. Foundry #1298.

**No behaviour change.** The removal takes away an inert file, so no re-gate was run: the proof
run `20260917-154558` covered base 3.5.2 with this file present and inert.

Consumers: nothing to do. A host that already merged the leaf into its own
`Files/GlobalSettings.config` keeps it; it is harmless and can be removed by hand. The Foundry's
`GlobalSettings.Fragment.ps1` allowlist and its mechanism stay — feature-pricing still ships
`Globalsettings/Features/Commerce/Newdiscountexperience` through it (Foundry #1291).

## 3.5.2

Patch: the base ships its FIRST file - `files/System/Truvio/globalsettings.url.fragment.config`,
the ecommerce URL provider activation block (Foundry #1281, owner decision 2026-09-17). No SQL
set, no base row, no row count, no guaranteed row and no `base.contract.json` change;
`baseContractVersion` is unmoved.

`/Globalsettings/System/Url/Providers` is EMPTY on a stock Dynamicweb 10 install - friendly
ecommerce URLs are opt-in, and no Distribution layer shipped any URL setting. With it empty,
every product and group link a composed storefront renders is a querystring
(`/en-us/shop?GroupID=TCGRP-BUNDLES&ProductID=TCPROD0041`), the PDP canonical is that same
querystring, and no `/en-us/shop/<group>/<product>` URL resolves at all. Measured on
`foundry.mydwsite4.com` (DW 10.28.10, Swift 2.4.0, edition `swift-demo`). The fragment sets the
three ecommerce providers only - `eComGroupPathProvider`, `eComProductProvider`,
`eComProductAndVariantProvider`; `NewsItemProvider` and `ForumUrlProvider` belong to modules this
distribution does not ship. `UseCanonicalInEcommerce` and `IncludeProductIdInUrlNames` are already
`True` by default and are not set here.

Two things a consumer has to act on:

- **The fragment requires a HOST RESTART.** It stages to `Files/System/Truvio/`, where nothing
  reads it; the Foundry harness merges it into the host's `Files/GlobalSettings.config`
  (`tools/harness/GlobalSettings.Fragment.ps1`, allowlisted leaf
  `Globalsettings/System/Url/Providers`, merge rule **comma-union** - the host's existing
  providers are kept and these three appended, nothing is dropped). The setting is read at
  application start, so a running host keeps rendering querystring URLs until it is recycled.
- **Page-list pointers move LATER, after the first rendered URL is read.** The exact friendly URL
  shape is not knowable from configuration; it is whatever the host renders. So gate page lists,
  critical paths and probe paths stay on their querystring pointers in this release and are
  repointed in the run that first delivers + restarts a host and reads a product link out of the
  rendered PLP. Note the caveat that comes with them: a group or product rename regenerates the
  friendly URL and **no 301 is minted** for the old one (Foundry #112), so anything pinned to a
  friendly product URL is invalidated by a rename, silently.

Every edition moves its base pin 3.5.1 -> 3.5.2.

## 3.5.1

Patch: the contract's `currencyRates.note` no longer states that USD is the currency the Swift
storefront serves. `baseContractVersion` moves 2.3.0 -> 2.3.1. No SQL set, no base row, no row
count and no guaranteed row changes.

The sentence was written from a MEASUREMENT of an unbound area, not from a decision. On DW 10.28 an
area with an empty `AreaEcomCurrencyId` resolves the request culture's currency, so an `/en-us/`
storefront served USD carts — measured on foundry-sd4v.mydwsite4.com, cart `CART783`
`OrderCurrencyCode USD` with an empty `OrderShopId`. Every `EcomPrices` row the Distribution ships
is `PriceCurrency EUR`, so nothing matched and `TCPROD0046` served `EcomProducts.ProductPrice`
45.00 instead of the contract price 36.90 (Foundry #1232). `surface-swift` 1.13.3 now ships the area
currency (`EUR`) and the storefront serves EUR, the default currency. The note also
records the distinction the old text blurred: `CurrencyRate` reasons about DISPLAY, while
`EcomPrices.PriceCurrency` FILTERING is decided by the area binding.

## 3.5.0

Minor: the contract gains a `sampleData` block and its guaranteed rows change subject.
`baseContractVersion` moves 2.2.2 -> 2.3.0. No SQL set, no base row and no base row count
changes; the base still ships the framework sets plus the three permission groups.

- **New `sampleData` block.** Beside `guaranteedRows`, the contract now states what the ONE
  sample-data layer guarantees to an addition that binds to it: `layer` (`sample-data`),
  `activatedBy` (`sampleData: true`), a `guaranteedRows` map naming every subject a shipped
  probe addresses, and the catalogue `counts` an edition asserts (`EcomProducts` 97,
  `EcomGroups` 16). The subjects are the buyer / CSR / account-admin personas, the
  SKU-validation product `TC-VAR-0001` (`TCPROD0001`), the quantity-tier product `TCPROD0020`
  with its ladder and customer-group row, the contract-price product `TCPROD0046` /
  `TC-PRICE-CTR-0046`, the configurable Bundle Kit `TCPROD0042` with its two
  `EcomProductItems` slots, the subscription plan `TCPROD0061`, the delivered order
  `TCO-0001`, and the RMA `PACK-RMA-0001` that `feature-rma` owns and binds to that order.
  Each entry carries a one-line note naming the probe that addresses it, so a feature layer
  binds to the contract and never to the sample-data layer.
- **Personas repointed to the brand identities.** `guaranteedRows.users` and
  `guaranteedRows.memberships` name `100101` buyer / `100102` CSR / `100103` account admin,
  all on customer number `TC-100200` and joined to `1325` / `1292` / `1270`. `anchors` follows.
  The previous pair sat below the 100000 id floor and had to be excepted from it; these do not,
  so `idRules.intIdentityNote` drops the persona exception and keeps only the base-owned
  permission groups. `usersNote` records that the rows ship as merge-mode SqlTable YAML and
  carry no password (the credential is set online through `UserSetPassword`).
- **Reserved key family moved to `TC*`.** `idRules.reservedFixtureKeys` lists the fourteen `TC*`
  prefixes the sample-data layer owns, and `reservedFixtureNote` states that an addition writing
  its own rows into a base-owned table uses its `PACK-<NAME>-` prefix instead.
- **`guaranteedRows.contractPrice`** names `TC-PRICE-CTR-0046` on `TCPROD0046` at `TC-100200`
  (36.90 against a 45.00 list and a 39.60 customer-group row).
- **Prose that named retired artefacts is rewritten**: `usersNote`,
  `reservedFixtureNote`, `intIdentityNote`, `serializerTaughtSurfaceNote`,
  `baseOwnedTables.replaceFiltered[0].note` and `BASE.md` no longer name the loose scripts, the
  retired key families or the retired persona ids. Salvaged from the 3.4.3 draft (Distribution
  PR #55): the `serializerTaughtSurfaceNote` rewrite that stops naming a layer version that never
  shipped.

## 3.4.2

Patch: the serializer floor rises and the id-floor rule names its exceptions. `baseContractVersion`
moves 2.2.1 -> 2.2.2. No key is added or removed, so this follows the 3.4.1 patch precedent; the
minor bumps (2.1.0, 2.2.0) were each triggered by keys additions read. No SQL, no content and no row
counts change. **The effective floor does change: upgrade the host's `Truvio.Commerce.Serializer`
to 1.0.2-beta or later before consuming this base.**

- **Serializer floor 0.9.0-beta -> 1.0.2-beta.** `compat.apps[id=Truvio.Commerce.Serializer].min`
  and the deprecated `minSerializerVersion` alias both carry `1.0.2-beta` (the validator enforces
  equality). Layers now ship serialized SqlTable rows with a per-document ownership header
  (truvio-demo 1.8.0, Foundry #1215; sample-data 3.0.0 follows). Serializer 1.0.1-beta and earlier
  wrote a NULL column as `1900-01-01` / `''` / `0` in Merge mode on a row where an empty-string
  column came before the NULL (Truvio.Commerce.Serializer issue #18); 1.0.2-beta is the first
  release that writes it back as NULL. PackageUnzip, the online file transport, is available from
  1.0.1-beta, and the ownership header needs 1.0.0-beta or later. `serializerTaughtSurfaceNote` is
  rewritten to state these reasons.
- **Id-floor exceptions stated.** `idRules.intIdentityNote` and `BASE.md` now say the 100000 floor
  applies to the int ids a layer mints. The contract-named AccessUser ids (groups 1325 / 1270 /
  1292, base-owned; personas 1326 / 1328, sample-data) are explicit exceptions a layer may ship as
  SqlTable rows. The validator has no int-identity floor check, and none is added.

## 3.4.1

Patch: the contract states one serializer floor. `baseContractVersion` moves 2.2.0 -> 2.2.1. The
effective floor does not change: `compat.apps[id=Truvio.Commerce.Serializer].min` stays
`0.9.0-beta`. No SQL, no content and no row counts change.

- **One serializer floor, not two (Foundry #1084).** The contract carried `compat.apps` at
  `0.9.0-beta`, which the Foundry compat leg enforces, beside the deprecated alias
  `minSerializerVersion` at `0.8.1-beta` and a `minSerializerVersionNote` restating `0.8.1-beta`.
  A host at `0.8.1-beta` satisfied the alias and breached the enforced floor. The alias now carries
  `0.9.0-beta`, its description names `compat.apps` as the only floor, and the stale note is
  removed. The alias stays because a skills page (`dw-users-permissions` `page-gating.md`) still
  names it in prose; no machine reader reads it (the Foundry `Test-CompatFloors` and the
  `dw-demo-base` install step both read `compat.apps`).
  `tools/ci/Validate-Distribution.ps1` now fails when `compat.apps` does not carry exactly one
  serializer entry with a `min`, or when the alias disagrees with it.

## 3.4.0

Minor bump, not patch: `base.contract.json` gains keys additions read (`presentOnlyWhen`,
`usersNote`, `currencyRates`). `baseContractVersion` moves 2.1.0 -> 2.2.0 (additive).

- **User rows are sample data, and the contract now says so (Foundry #967).**
  `guaranteedRows.users` (IMCUser 1328 / 98745621, IMCSalesrep 1326 / 7789765) and
  `guaranteedRows.memberships` were listed unqualified, while the same file's FILTER-01 note said
  the rows are seeded, not serialized. They ship in `sample-data` `merge/_sql/identities.sql`. Every
  user, membership and the contract-price entry now carries `presentOnlyWhen: sampleData`, a
  `usersNote` states what an edition with `sampleData: false` lacks, and `anchors.note` and `BASE.md`
  say the same. The probe-side half (`requiresFixtures` on the feature-rma and feature-pricing probes)
  is already in the tree.
- **SHOP1 no longer names completion rules and a language nothing ships (Foundry #968).**
  `ShopCompletionRules` `1004,2` and `ShopCompletionLanguageIds` `DAN,ENU` are blank. No layer ships a
  completion rule, and DAN has not been a SHOP1 language since 3.1.0. Same treatment 3.1.3 gave the
  dangling `CountryCurrencyCode` values.
- **SHOP1 is the default shop (Foundry #969).** It is the only `EcomShops` row, so `ShopDefault` is
  now `true`; code that resolves the default shop instead of the area's `AreaEcomShopId` finds it.
  `ShopProductPrimaryPageId` stays `0` (the product page id is per-environment); `surface-swift`
  1.13.0 declares binding it as a consumer obligation.
- **USD ships at `CurrencyRate` 100, not 1 (Foundry #971).** `CurrencyRate` is hundredths against the
  default (EUR at 100); USD at 1 rendered a stored 45.00 as $4,500.00 on DW 10.28.10. All 17
  `USD$$<lang>` rows move to 100, parity with the default, the same demo value `truvio-demo`'s
  existence-guarded currency UPDATE converges to (that UPDATE now finds no row and writes nothing).
  The contract gains `currencyRates` (default 100, no rate at or below 1). Other non-default rates are
  unchanged.
- **Both HTTP-200 shapes of a PLP that cannot list products (Foundry #1064).** `repositories.note`
  documented only the in-page Lucene `numHits must be > 0` error (repository present, zero documents).
  It now also documents the repository-absent shape: an empty `swift-v2_app` div with no error text,
  which passes a status scan and an error-text scan. Gate advice moves to a positive subject (a product
  card) plus `dw-error == 0`.
- **The 100000 id floor is scoped to SqlTable rows (Foundry #1008).** `intIdentityNote` said the floor
  applies equally to `ItemType_<systemName>` item-instance ids. It cannot: `ItemType_*` `Id` is a
  non-identity nvarchar, and the Serializer content provider re-creates item rows by page/paragraph
  uniqueId, so the target allocates the id (feature-b2b-comms YAML ids 100300-100365 landed as 48, 446
  and 139 on foundry). `fields.Id` in `_content` is informational.

Row counts are unchanged: 17 `EcomCurrencies` rows and one `EcomShops` row change value, none is added
or removed.

## 3.3.0

`base.contract.json` gains `compat` — the compatibility floor every addition inherits (v5
version spine, V5-PLAN §2.2). Minor bump, not patch, because the contract additions bind to
gained a block.

```jsonc
"compat": {
  "dw":    { "min": "10.28.1", "tfm": "net10.0" },
  "swift": { "tag": "v2.4.0", "version": "2.4.0" },
  "apps":  [ { "id": "Truvio.Commerce.Serializer", "min": "0.9.0-beta", "required": true },
             { "id": "Truvio.Commerce.MCP",        "min": "0.4.4",     "required": false } ]
}
```

Why it exists: the three version roots a consumer must match — the DW platform, the AppStore
apps, the Swift release — had no machine-readable home. `dwPlatformVersion` lived only in the
Foundry's hand-pinned gate config, there was no field for a Swift **tag** anywhere (only the
3-digit `swiftVersion`), and the engine floor was prose. A layer could claim nothing a reader
or a validator could check.

What it is and is not. `compat` states **floors plus one proven point**, never a support
matrix: rolling latest-only means the gate proves exactly one (dw, apps, swift tag) triple per
run, and what it proved is recorded upward in `layers/INDEX.json` `gateProven` — written by the
Foundry publish flow, never by hand. The dependency points **up**: this file states a floor, the
gate states what it proved. `apps[].required: false` marks an optional companion app (absent is
fine, present below `min` is not). An addition MAY restate `compat` in its own `layer.json` to
raise a floor; it may never lower one.

`minSerializerVersion` stays exactly where it is and keeps its value, now carrying a
`minSerializerVersionDeprecated` line that names it a deprecated alias of
`compat.apps[id=Truvio.Commerce.Serializer].min`. It is retained one release for consumers
still reading it; new readers use `compat.apps`. `baseContractVersion` moves 2.0.0 -> 2.1.0
(additive).

No SQL, no content and no row counts change: this release is the contract file only.

## 3.2.1

Patch: the serializer config `swift-2.4.json` renames its output-subfolder keys onto the
0.9.0 engine names (`replaceOutputSubfolder` / `mergeOutputSubfolder`). The 0.8.x names
(`deployOutputSubfolder` / `seedOutputSubfolder`) are dead keys the loader ignores while
silently defaulting both values, so the config declared intent the engine never read.
Output paths are unchanged (the defaults matched). Foundry #561.

## 3.2.0

`base.contract.json` `repositories` now names the repository the composition actually binds:
**`ProductsFrontend`**, at `wwwroot/Files/System/Repositories/ProductsFrontend/`, carrying
`Products.index` / `Products.query` / `Products.facets`. `provisionedByGate` drops to `false`
because no layer in this Distribution ships the repository at all: it arrives with the host's
Swift design package. Minor bump, not patch, because the contract every addition binds to
changes what it names.

Evidence:

- The Swift 2.4.0 design package ships `Files/System/Repositories/ProductsFrontend/` (with
  `Products.query`, `Products.facets`, `Products.index`) and `ProductsBackend/`. It ships no
  `Products` repository. Verified against the `v2.4.0` tag of `dynamicweb/Swift` and against a
  local `v2.4.0` Files overlay.
- No layer here ships `Files/System/Repositories/**` for the storefront. The only repository
  definition in the tree is `surface-headless/repositories/Headless/`, a different repository.
- Six shipped `eCom_ProductCatalog` surfaces bind `ProductsFrontend` by path: `surface-swift`
  Shop PLP (`IndexQuery` + `FacetGroups`), desktop header search, Express Buy;
  `surface-dap-portal` Product Assets and Search results; `feature-bom-configurator` Kit
  Configurator.
- Field runs on two hosts (`daye`, `agrihub`) found no `Products` repository on either, and a
  `/shop` that returned HTTP 200 with an in-page Lucene `numHits must be > 0` error until
  `ProductsFrontend` was built.

`layers/base/layer.json` `repositoryName` follows the contract (`Products` -> `ProductsFrontend`),
`BASE.md` restates the same shape, and `layers/layer.schema.json` documents the field against the
contract instead of asserting a `Products` default. The `feature-reordering` Quick Order pad still
binds a bare `Products` repository; that leg is tracked separately and is not changed here.

## 3.1.3

`EcomCountries` CA / NO / SE carried `CountryCurrencyCode` values (CAD, NOK, SEK) that no
shipped `EcomCurrencies` row backs. A country row pointing at a missing currency throws the
same opaque `DivideByZeroException` ('Error processing prices') as a zero rate does, during
every product index build. The three codes are now blank (the valid no-currency state the
province rows already use); the countries stay selectable for addresses. Ship the currency
row first if a demo ever needs CAD/NOK/SEK pricing.

## 3.1.2

`EcomCurrencies` **revert of the 3.1.1 single-default change** — restores
`CurrencyIsDefault: true` on all 16 `EUR$$<lang>` rows (DAN, DES, DEU, ENU, ESP, FRA, HRV,
ISL, ITA, NLD, NON, PLK, RUS, SRP, SVE, UKR).

Root cause (swift-demo gate RED, run 20260719-110318): DW's
`ProductIndexBuilder.ProcessProducts` calls `CurrencyService.GetDefaultCurrency()` **per
language context** — not once globally. The `ProductIndexBuilder` build context resolves to
a non-`ENU` language; with 3.1.1 leaving **only `EUR$$ENU`** flagged default, that language
had **no default currency**, so `GetDefaultCurrency()` threw
`InvalidOperationException: No default currency found` and the Full build aborted writing
**0 of 28 documents** (`Completed (0 / 28)`, index build diagnostic log). An empty Products
index means the Swift storefront resolves **zero products**: empty PLPs, the Quick-Order
SKU feed reads "Unknown SKU", and authenticated `cartcmd=addmulti` creates no order line.

3.1.1's premise ("DW expects exactly one currency flagged `CurrencyIsDefault`") was wrong:
DW's model is **one default currency per language**, and the pre-reshape base (all 16 EUR
rows default) was the gate-proven-green shape. Bisected live on the harness host: 16-default
→ 28/28 documents; ENU-only and {ENU,ESM,FRC}-only → 0/28. The reshape's new shop languages
`ESM`/`FRC` are **not** the build context and need no currency rows.

- 15 `EUR$$<lang>` rows flip `false` → `true`; `EUR$$ENU` already `true`. No other column
  touched; no non-EUR currency was default before or after. Patch bump — one-bit data
  revert, framework contract unchanged.

**Proven on DW 10.28.1-PreRelease** (live index build 28/28 + end-to-end frontend: PLP
products, SKU feed resolves, addmulti order line at contract price); re-gated in the Foundry.

## 3.1.1

`EcomCurrencies` single-default fix (runtime E2E deserialize, DW 10.27.6, risewell-e2e).
DW expects exactly one currency flagged `CurrencyIsDefault` per language context; the base
shipped **16 EUR rows** (one per currency-language: DAN, DES, DEU, ENU, ESP, FRA, HRV, ISL,
ITA, NLD, NON, PLK, RUS, SRP, SVE, UKR) all with `CurrencyIsDefault: true`, so the default-
currency resolution was ambiguous.

- Only the **en-US row (`EUR$$ENU`)** — matching the sole default language `ENU`
  (`EcomLanguages.LanguageIsDefault`) — keeps `CurrencyIsDefault: true`; the other **15 EUR
  rows flip to `false`**. Runtime resolved `DEFCUR=EUR`, which this preserves deterministically.
- No other column touched; no other currency was default before or after (all non-EUR rows
  were already `false`). Patch bump — one-bit data correction, framework contract unchanged.

**Proven on DW 10.28.1-PreRelease** (structural validator); re-gate in the Foundry.

## 3.1.0

Multi-language reshape (RUN-SWIFT-MULTILANGUAGE, P1/P2 — Foundry plan). Retargets the
shipped shop language set from the Danish-default legacy to en-US/es-MX/fr-CA:

- **`EcomLanguages`** 18 → 20 rows: add ESM (es-MX, AutoId 19) + FRC (fr-CA, AutoId 20);
  resolve the ENU/LANG1 dual en-US default in favour of ENU (`LANG1.LanguageIsDefault` →
  false; the LANG1 row is retained for `reference_category` + sample-order FK). The 15
  remaining seed rows stay inert (un-attached) so 120 `EcomCountryText` + 17 currency-format
  FK rows are not orphaned.
- **`EcomShopLanguageRelation`** on SHOP1 rewritten to exactly {ENU (default), ESM, FRC}:
  128 ENU flipped `IsDefault` true; new 132 ESM + 133 FRC; removed 127 DAN (was the shop
  default), 129 DEU, 130 FRA, 131 ITA. Danish is no longer the shop default — ENU is the
  sole default.
- **P2:** en-US fallback for es-MX/fr-CA country/currency formatting (no localized rows
  added). `base-only` edition `expectedCounts.EcomLanguages` 18 → 20.

Minor bump — additive language set + shop-relation reshape, framework contract unchanged.
**Proven on DW 10.28.1-PreRelease.**

## 3.0.1

Learnings triage fixes (RUN-TRIAGE-20260713 in the Foundry):

- **LRN-sapporo-01:** all 17 GBP `EcomCurrencies` rows shipped `CurrencyRate: 0` —
  any price-context path converting through GBP (the index price sweep computes
  prices per currency) threw `DivideByZeroException`, emptying PDP price/add-to-cart
  paragraphs. Rows now ship `CurrencyRate: 86`. Gate lint: no `EcomCurrencies` row
  may ship `CurrencyRate <= 0`.
- **LRN-hosted-publish-03:** `config/swift-2.4.json` declared the retired predicate
  mode enum (`"Deploy"` ×16), which engine 0.8.1-beta — this layer's own declared
  floor — rejects with a 500 on every serializer call including the read-only
  settings query. All predicates now `"mode": "Replace"`. Gate probe: after staging
  the config, `GET /Admin/Api/SerializerSettings` must return 200 with a non-empty
  `predicatesSummary`.

## 3.0.0

**Framework-only (the Swift 2.4 base split).** Breaking restructure, executed at the
Swift 2.4 roll-forward (RUN-SWIFT-24; FOLLOWUP bump plan):

- **ALL content moved out** to the new `surface-swift` 1.0.0 layer: `replace/_content`
  (areas 3 "Swift 2" + 27 "Swift 2 Nederlands") and the ENTIRE `merge/` tree. The base
  is now `fragmentModes: ["replace"]` — no merge pass.
- **UrlPath moved to surface-swift** (its one row is a friendly-URL redirect bound to
  area 3 + a Swift page id; no route targets exist in a framework-only base).
- **Kept:** the 16 framework `replace/_sql` sets (shops + relations, languages,
  currencies, countries + relations, VAT, order flow/states/rules, payments, shippings,
  AccessUser permission-group trio) + `base.contract.json` (2.0.0, framework anchors
  only) + the SQL-predicate config (`config/swift-2.4.json`).
- **Engine floor: Truvio.Commerce.Serializer 0.8.1-beta** (DW packages retargeted to
  10.28.1-PreRelease for Swift 2.4 / DW 10.28).
- **Why at the bump:** the base had to be re-proven against 2.4 anyway; the restructure
  rides that sweep, and future Swift content churn lands in surface-swift instead of
  forcing base re-proves. Framework SQL is never duplicated across frontends
  (swift-demo and headless-demo now share the identical framework root).

**Proven on DW 10.28.1-PreRelease** (operator-approved override; stable re-prove
mandatory when DW 10.28 reaches NuGet stable). Editions re-pin to `base@3.0.0`.

## 2.4.1

Brand-neutral starter content. The scaffolding base no longer reads as a bike shop:
the bike-era editorial copy is rewritten to industry-neutral commerce copy so every
demo starts from a clean, brand-agnostic slate.

- **Bike-era copy neutralized (both languages).** About, Home, the Home-preset,
  Employees, About-us/Delivery SEO descriptions and the store Terms heading no longer
  reference bikes/bicycles/cycling. Examples: "Your Trusted Partner in Bicycle Solutions"
  → "…in Commerce"; "High Quality Bikes & Parts" → "High Quality Products & Parts";
  "Electric bikes are here to stay" → "Innovative products are here to stay"; "Swift
  Bikes" team copy → generic. No posts deleted (the Posts index and its category pages
  were already brand-neutral). Page titles are untouched, so the title-integrity gate leg
  stays green (122 pages, DB Title == YAML).
- **Legit survivors, left intentionally.** The stock Swift sample rich-text under
  `Navigation` (mountain-trail review filler — no bike brand or model names) and the
  `Product Info` `FieldDisplayGroups` config (a product field-group data identifier list,
  not editorial copy) are not brand strings and remain.
- **Line endings normalized.** All base YAML is uniformly CRLF + UTF-8 BOM (the
  serializer-native convention); the 2.4.0-touched Customer Center subtree (40 files that
  were LF/mixed in the working tree) is normalized, so a serializer round-trip is
  byte-stable.

No behavior, permissions, or engine-floor change from 2.4.0 — content-only patch. Editions
re-pin to `base@2.4.1`.

Gate: base-only PASS (`runs/20260710-155148`) + swift-demo PASS (theme leg on); permissions
parity 133 and title integrity 122 both green.

## 2.4.0

Per-role Customer Center, fully derived from the layer YAML. What a consumer sees change
from 2.3.2:

- **Per-role tile dashboard on ONE shared Overview.** The buyer tiles (My orders, Quotes,
  Carts, Favorites, Addresses, Profile, Returns) and the CSR tiles (Accounts, Orders,
  Carts, Users) now live on the same `Overview` page. Each tile — and its grid row —
  carries a serialized `permissions:` block, so a signed-in **buyer** sees only the buyer
  tiles and a signed-in **CSR** sees only the CSR tiles, on the same URL, with zero custom
  code. English + Dutch. (Buyer tiles: Customers=all / CSR=none; CSR tiles: CSR=all /
  Customers=none; Anonymous=none everywhere.)
- **CSR split-landing retired.** The separate `CSR` tile dashboard (duplicated grid +
  HelloUser) is removed; the CSR function pages (Accounts / Orders / Carts / Users) stay,
  and a CSR now lands on the shared Overview. Nav stays permission-filtered.
- **Dutch Customer Center is now gated for anonymous.** The NL `/customer-center/*` subtree
  carries the same page-level `permissions:` blocks as the English side (Anonymous → sign-in),
  closing the 2.3.2 "both languages" gap. (NL rows/paragraphs are independent content —
  they do not inherit the EN master's permissions — so NL carries its own serialized blocks.)
- **Historical title smears corrected.** Three bike-era `fields.Title` values from an old
  engine link-resolution defect are fixed: NL "My profile", EN "Search result page", EN
  "Favorites list service". (EN "Home preset" = "Contact" and NL "Home preset" = "Home" are
  legitimate stock Swift preset labels — verified against the pristine control DB — and are
  left untouched.)
- **Engine floor.** This base carries render-time permissions on grid rows and paragraphs,
  which require **Truvio.Commerce.Serializer >= 0.8.0-beta**. Older engines silently drop
  those blocks → ungated tiles. The floor is machine-readable in
  `base.contract.json` (`minSerializerVersion`). **Upgrade the serializer before consuming
  this base.**

Editions that build on the base (`swift-demo`, `headless-demo`, `base-only`, `dap-portal`)
re-pin to `base@2.4.0`.

Gate: base-only + swift-demo green on the current latest Swift (2.3), theme leg on, with two
new gate legs — permissions-parity (every serialized page/row/paragraph block ⇔ matching
`UnifiedPermission` rows) and title-integrity (item Title == YAML). Real buyer + CSR role UAT
confirms the per-role tiles behaviorally.

## 2.3.2

B2B-default pass: the base layer now presents a business-buyer storefront out of
the box, gate-proven on Swift 2.3. What a consumer sees change from 2.3.1:

- **Anonymous pricing hidden.** Prices are hidden for anonymous visitors on the
  product list and detail pages; a sign-in nudge replaces them. Signed-in buyers
  see prices. (B1)
- **Single, neutrally-named shop.** The nine demo shops collapse to one —
  "B2B Commerce Store" (formerly "Bikes"). The eight extra shops
  (Product category, Partner, Brands, Additionals, Digital Assets Portal,
  Channel-Amazon, Printing catalogs, EU Packaging) and their shop/group and
  shop/language relation rows are removed. Bind the site root + shop after
  deserialize, then restart (see the base contract). (B5)
- **List-mode product listing.** The product list page defaults to list view with
  B2B-fit columns; the grid toggle stays available. Standard Swift building
  blocks only — no custom templates or code. (B4)
- **"Home Machines" page removed.** The demo Home Machines page is gone from both
  the English and Dutch content areas, with its navigation and merge-manifest
  entries pruned. (B2)
- **Digital Assets Portal header decoupled.** The Swift storefront header no
  longer carries a link to the Digital Assets Portal (desktop, English + Dutch);
  the reciprocal storefront back-link is removed from the `dap-portal` layer. (B3)
- **Customer Center Overview is a tile dashboard.** Signing in lands the buyer on
  a function-tile dashboard (Orders, Quotes, Carts, Favorites, Addresses,
  Profile, Returns) instead of an order list — each tile routes to its function
  page. English + Dutch. (B6)
- **CSR dashboard + page-level gating.** A separate CSR dashboard ships, with
  Customer Center pages gated by role (CSR vs. buyer) at the page level. (B7)
- **Returns (RMA) in the Customer Center.** A "My returns" / "Mijn retouren" page
  wired to the stock Swift returns components is added to the customer tree and
  the tile dashboard, English + Dutch. (B9)
- **Per-environment exclusions documented.** `base.contract.json` now enumerates
  the deliberately non-serialized per-environment Area columns (domain,
  frontpage, shop, country, language, currency, stock location) and the consumer
  obligation to bind site root + shop after deserialize and restart. (B10)

Editions that build on the base (`swift-demo`, `headless-demo`, `base-only`,
`dap-portal`) re-pin to `base@2.3.2`.

Known issues deliberately shipped (deferred, tracked): a few historical item
Titles carry bike-era text from an engine link-resolution defect fixed upstream
(no new occurrences), and the Dutch Customer Center subtree is not yet gated for
anonymous visitors (the English subtree is). Both are queued for a follow-up
pass.
