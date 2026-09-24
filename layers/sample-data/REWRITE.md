# Rewriting sample-data for a customer demo

This guide is for an agent that turns the Truvio sample data into a customer's demo data. The
strategy is fixed (owner ruling 2026-09-24): **copy the layer, rewrite the YAML, deliver the
copy.** A demo never delivers this layer and cleans it up afterwards, and it never edits the
Distribution's own copy.

1. Copy `layers/sample-data/` into the demo's own layer folder, for example
   `<demo>/layers/<customer>-data/`, the same pattern a demo-local brand layer uses. Set
   `layer.json` `name` to the folder name and keep `kind` `sample-data`.
2. Rewrite values in the copy, file by file, using the tables below. Keep every key in
   [What must stay stable](#what-must-stay-stable).
3. Keep the four inventories in step with the tree (see [Inventories](#inventories)).
4. Compose the demo edition with the copy in place of `sample-data` and deliver it. A merge
   deserialize writes the rewritten rows; nothing needs deleting afterwards.

Rewrite before the first delivery. A merge deserialize never deletes and never renames, so a host
that already received the Truvio rows keeps them next to the rewritten ones.

## Where the content lives

Paths are relative to the layer root. Every row file is one row: the file name is the row key
(composite keys join with `$$`), the first two lines are the `ownership` header, and each
`"Column": value` line is one column. Edit values in place; copy a neighbouring file to add a row.

| Content | Files | Columns to rewrite |
|---|---|---|
| Product names, numbers (SKUs), copy, list price, stock | `merge/_sql/EcomProducts/TCPROD*$$ENU$$*.yml` (61 masters + 36 variant rows) | `ProductName`, `ProductNumber`, `ProductShortDescription`, `ProductLongDescription`, `ProductMetaTitle`, `ProductMetaDescription`, `ProductPrice`, `ProductStock`, `ProductImageSmall` / `Medium` / `Large` |
| Catalogue groups and data models | `merge/_sql/EcomGroups/*.yml` | `GroupName`, `GroupDescription`, `GroupMetaTitle` |
| Prices: list, customer group, quantity tiers, contract | `merge/_sql/EcomPrices/TC-PRICE-*.yml` (221) | `PriceAmount`, `PriceQuantity`, `PriceCurrency` (USD; see [Currency](#currency)) |
| Variant axes and options | `merge/_sql/EcomVariantGroups/`, `merge/_sql/EcomVariantsOptions/` | `VariantGroupName`, `VariantOptionName` |
| Specification fields and values | `merge/_sql/EcomProductCategory*/`, `EcomProductCategoryField*/`, `EcomProductCategoryFieldValue/` | category and field labels (`*Name`, `*Label`), `FieldValueValue` |
| Images and documents per product | `merge/_sql/EcomDetails/TC-DETAIL-*`, `TC-DOC-*`, `TC-GAL-*`, `TC-HOVER-*` | `DetailValue` (a `/Files/...` path), `DetailsName`, `DetailsKeywords`, `DetailDescription` |
| Related products | `merge/_sql/EcomProductsRelated/`, `EcomProductsRelatedGroups/` | related group names; the pairs themselves are keys |
| Bundles and BOM slots | `merge/_sql/EcomProductItems/TC-BOM-*.yml` | `ProductItemName`; the slot keys stay |
| Personas and the B2B account | `merge/_sql/AccessUser/100100.yml` to `100103.yml` | `AccessUserName`, `AccessUserEmail`, `AccessUserCompany`, `AccessUserAddress`, `AccessUserZip`, `AccessUserCity`, `AccessUserCountryCode`, `AccessUserPhone` |
| Orders, quotes and carts | `merge/_sql/EcomOrders/TCO-*.yml`, `merge/_sql/EcomOrderLines/TCO-*.yml` | customer and delivery name / company / address columns, `OrderReference`, `QuoteRequest`, `OrderDisplayName`; lines: `OrderLineProductNumber`, `OrderLineProductName`, unit and line prices |
| Favourite lists | `merge/_sql/EcomCustomerFavoriteLists/1004*.yml`, `merge/_sql/EcomCustomerFavoriteProducts/*.yml` | `Name`, `Description`; products are keys (list id, product id) |
| Return request (RMA) | `merge/_sql/EcomRmas/PACK-RMA-0001.yml` | customer and delivery name / company / email / country columns |
| PIM tree | `merge/_sql/EcomShops/TCSHOP-PIM.yml`, `EcomCompletionRules/`, `DynamicStructures/`, `DynamicStructureLevels/`, `repositories/TruvioCommerce/PimWorkspace.query` | display names only (see the PIM trap below) |
| Storefront copy | `merge/_content/Swift 2/` (`Home`, `About`, `Header _ Footer`, `Navigation`, `Posts`) and `replace/_content/Swift 2/Navigation/` | paragraph `fields` text: `Title`, `Subtitle`, `Text`, button labels, image paths, alt text |
| Images and documents on disk | `files/Images/TruvioCommerce/{brand,people,products,scenic}/`, `files/Documents/TruvioCommerce/` | replace the files; keep or rewrite every path that points at them |

Product tiles are generated (`tools/make-tiles.py`, SVG authored, PNG shipped because
`GetImage.ashx` cannot decode SVG). A customer catalogue replaces them with its own raster
images; point `ProductImage*` and the `EcomDetails` `DetailValue` rows at the new files.

## What must stay stable

These keys are named in [`base.contract.json`](../base/base.contract.json) `sampleData.guaranteedRows`
or read by a gate leg, a layer probe or a template. Rewrite the display values on these rows, not
the keys.

| Key | Why it must stay |
|---|---|
| `AccessUser` `100100` (account), `100101` buyer, `100102` CSR, `100103` account admin, and the user names `TruvioBuyer`, `TruvioCsr`, `TruvioAdmin` | The gate persona legs sign in as these user names, and the Foundry credential tool sets the password by id. Rename the display name, company and e-mail freely. |
| Customer number `TC-100200` on the account, the three personas, the contract price and every order | Contract prices, account-wide favourites and the CSR account listing compare the string exactly. Change it only everywhere at once. |
| Group memberships `1325` / `1292` / `1270` | Base-owned permission groups; the customer-center pages and the dashboard rows grant by these ids. |
| `TCPROD0001` with product number `TC-VAR-0001` | `feature-reordering` `sku-validation` types that number into the Quick Order pad. |
| `TCPROD0020` and `TC-PRICE-Q05-0020`, `TC-PRICE-Q10-0020`, `TC-PRICE-Q25-0020`, `TC-PRICE-GRP-0020` | `feature-pricing` `cart-price` adds quantity 10 and expects 96. Keep the ladder amounts, or change the probe with them. |
| `TCPROD0046` and `TC-PRICE-CTR-0046` (36.90 at `TC-100200`) | `feature-pricing` contract `cart-price` expects 36.90. |
| `TCPROD0042`, slots `TC-BOM-0042-1` / `TC-BOM-0042-2`, children `TCPROD0002`, `TCPROD0003`, `TCPROD0051`, `TCPROD0052` | `feature-bom-configurator` `bom-cart-lines` posts these slot ids with a non-default child. |
| `TCPROD0061` / `TC-SUB-0061` | `feature-subscription-orders` `checkout-recurring` buys it on `PAY2` / `SHIP9`. |
| `TCO-0001`, line `TCO-0001-1`, `PACK-RMA-0001`, `EcomRmaOrderLines` `100301` | The My returns probe (surface-swift) needs the buyer's delivered order and the return request against its first line. |
| Persona `100101` as the owner of the orders, quotes, carts and favourite lists | The surface-swift dashboard widgets read the signed-in buyer's own rows. Re-owning them to another persona empties the buyer's dashboard. |
| Quote `OrderStateId` values `QuotePending`, `QuoteSent`, `QuoteAccepted`, `QuoteRejected` | Base 4.0.0 states; the Pending quotes widget asks for `QuotePending` by id. |
| `EcomDetailsGroup` system names `Images` and `Manuals`, display group `tc_specs` | Swift binds the PDP gallery, the documents table and the spec table by system name. |
| `TCFIELD-*` rows in `EcomProductField` | The variant-editing settings for the six master-only fields; without them a master save overwrites every variant row. |
| `TCSHOP-PIM` and its name `Truvio PIM` | The index field `DATAMODEL_Truvio_PIM` is derived from the shop name and the workspace level `100171` reads it. Renaming the shop means renaming that level's field too. |
| The `TC*` key families (`TCGRP-*`, `TCDM-*`, `TCPROD*`, `TCVG-*`, `TCVGR-*`, `TCVO-*`, `TC-PRICE-*`, `TC-BOM-*`, `TC-DETAIL-*`, `TC-DOC-*`, `TC-GAL-*`, `TC-HOVER-*`, `TCREL-*`, `TCO-*`, `TCFIELD-*`, `tc_*`) | Every predicate in `config/sample-data-2.4.json` fences its rows with a `where` on these prefixes. A key outside the fence is neither harvested nor recognised as this layer's. |
| The reserved int ids (`layer.json` `costHints.reservedKeyNote`) | Written verbatim with `IDENTITY_INSERT`; other rows point at them. |

## Re-keying safely

Prefer rewriting values to re-keying. A customer's SKU belongs in `ProductNumber`, and
`ProductId` can stay `TCPROD0007`: the storefront, the URLs and the search index show the number
and the name, never the id. When a key must change:

1. Change the key column in the row file and rename the file to match (the file name is the key;
   composite keys join with `$$`, an empty key part leaves a trailing `$$`).
2. Change every row that points at it. For a product id that is `EcomGroupProductRelation`,
   `EcomVariantGroupProductRelation`, `EcomVariantOptionsProductRelation`, `EcomPrices`,
   `EcomDetails`, `EcomStockUnit`, `EcomProductCategoryFieldValue`, `EcomProductsRelated` (both
   sides), `EcomProductItems`, `EcomOrderLines`, `EcomCustomerFavoriteProducts`, and the variant
   rows of the same master. Search the whole copy for the old key.
3. Keep the new key inside the predicate fence, or widen the `where` in
   `config/sample-data-2.4.json`.
4. Update the inventories below.

Deliver a re-keyed copy to a fresh host. On a host that already holds the old keys, the old rows
stay beside the new ones.

## What not to rename

- Upstream identifiers: item types `Swift-v2_*`, table and column names, the `ownership` header,
  the `_meta.yml` files. They describe the schema, not the demo.
- Base-owned ids the rows point at: `SHOP1`, the language `ENU`, the order states, `PAY2`,
  `SHIP9`, the stock location `3`, the permission groups.
- Date columns. Every date is absolute at the harvest day 2026-09-13 and `demo-clock.sql` moves
  them all by whole days. Keep new dates on or before that day, or move the anchor in
  `demo-clock.sql` with them.

## Currency

Every `EcomPrices` and `EcomOrders` row is USD, the base default, and the surface-swift area
serves USD. The dashboard's Spent this month and Monthly spending widgets sum one currency and
print `-` when orders mix currencies. A demo for another market rewrites `PriceCurrency` and
`OrderCurrencyCode` on every row to the one currency its area serves, in the same copy.

## Inventories

The tree and four inventories must agree, or the serializer warns (strict mode fails) and the
validator fails:

- `merge/merge-manifest.json` `entries[].files`: every row file, per table.
- `config/sample-data-2.4.json`: one predicate per table, fencing the keys.
- `layer.json`: `fragmentTables`, `files[]` (every file under `files/`), `repositories[]`,
  `configRows`, `costHints.expectedRows`.
- The edition's `expectedCounts` when product or group counts change.

## After delivery

Set the persona passwords (the Foundry `tools/secrets/Set-DemoCredential.ps1`, Management API
`UserSetPassword`), restart the host, rebuild the product index, and check the storefront, the
customer-center dashboard as the buyer, and the gate legs the demo claims.
