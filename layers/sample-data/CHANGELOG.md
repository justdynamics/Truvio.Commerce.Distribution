# Changelog — sample-data

## 4.1.2

### Variant price rows win, gallery rows carry a name, group buttons keep their group, the account group is a system account with a CSR grant

**PATCH. Four data defects the 5.1 experiment arm B surfaced on a delivered swift-demo, fixed in
the layer. 12 price rows removed and 20 re-keyed, 253 asset rows named, two buttons re-addressed,
one group typed, one table added (`AccessUserSecondaryRelation`, one row). No id changes.**

**1. A variant's own price never rendered (Foundry #1254).** Each of the six variant masters
(`TCPROD0001`, `0011`, `0016`, `0031`, `0041`, `0051`) shipped a master-level list row
(`TC-PRICE-LIST-*`, no variant id, 45) and a master-level customer-group row (`TC-PRICE-GRP-*`,
group 1325, 39.60) beside the per-combination rows `TC-PRICE-VAR-*` (45 to 79.20) and
`TC-PRICE-GRPV-*` (39.60 to 69.70). Dynamicweb resolves the lowest matching row, and a row with
an empty `PriceProductVariantId` matches every combination, so `ENT.PUB` resolved 45 anonymously
and all 36 combinations showed one price; signed in, the master-level contract row (36.90)
undercut the lot.

The shape now: **a variant master ships no master-level list or customer-group row.** The 12
`TC-PRICE-LIST-*` and `TC-PRICE-GRP-*` rows of the six masters are removed; `TC-PRICE-VAR-*` and
`TC-PRICE-GRPV-*` are the list and customer-group rows, one per combination. The rows that were
derived from the master's `ProductPrice` 45 (the quantity ladders `TC-PRICE-Q05/Q10/Q25-*` at
40.50 / 36 / 31.50 on the six masters, and the contract rows `TC-PRICE-CTR-0001` 36.90 and
`TC-PRICE-CTR-0051` 35.10) are keyed to the combination that IS priced 45,
`TCVO-TIER-STD.TCVO-MODE-DRAFT`, so the ladder and the contract price demonstrate on that
combination and never undercut the other five. Chosen over variant-keyed copies of the list row
because the copies would have duplicated the `VAR` rows exactly. With no variant selected the
master falls through to `EcomProducts.ProductPrice` (45), unchanged.

Gate subjects untouched: `TCPROD0046` contract 36.90 (`TC-PRICE-CTR-0046`) and the `TCPROD0020`
ladder 120 / 108 / 96 / 84. The customer-group row count is 90 (54 `GRP` + 36 `GRPV`);
`EcomPrices` ships 221 rows. A new `configRow` asserts `TC-PRICE-VAR-0006` at 79.20 on `ENT.PUB`.

**A host delivered from 4.1.1 or earlier keeps the 12 removed rows**: a merge deserialize never
deletes. Before a re-gate on such a host, delete `TC-PRICE-LIST-0001/0011/0016/0031/0041/0051`
and `TC-PRICE-GRP-0001/0011/0016/0031/0041/0051`; a clean-room gate needs nothing.

**2. The PDP gallery alt was the asset row id (Foundry #1246).** Arm B measured the Swift gallery
thumbnail `img alt` equal to the `EcomDetails.DetailId` on every row whose `DetailsName` was
empty, so `TC-DETAIL-*`, `TC-HOVER-*` and `TC-GAL-*` leaked onto every PDP, and no online verb
renames an asset row. Every Images-group row (253: 97 `TC-DETAIL`, 96 `TC-HOVER`, 60 `TC-GAL`)
now carries `DetailsName` = the product's `ProductName`; variant rows share the master's name. The
120 Manuals rows already carried their document names. That Swift renders the name where one
exists is what the re-gate proves.

**3. The two group buttons opened the unfiltered shop (Foundry #1248).** Swift renders a
`LinkType page` button as the page's friendly URL and drops the stored query, so
`Default.aspx?ID=50&GroupID=TCGRP-DATA-MODELS` (Home hero, "Browse Data Models") and
`...&GroupID=TCGRP-COMMERCE` (catalogue pitch, "Browse Commerce") both rendered `/en-us/shop`.
Both buttons now ship `LinkType url` with the culture-segment address `/en-us/shop?GroupID=<group>`
and an empty `SelectedValue`, which Swift passes through verbatim (measured by browser click in
arm B). The address is bound to the `en-us` culture of the Swift 2 area surface-swift ships; a
consumer on another culture re-points it like any other copy.

**4. The account group was untyped and the CSR held no grant (Foundry #1261).** The Swift CSR
Accounts app (`UserGroups`, `ListGroupType SystemAccount`) lists only groups whose user-and-group
type is `SystemAccount`; group 100100 shipped `AccessUserUserAndGroupType` empty, so the CSR
persona saw only the package's own sample accounts, and CSR Users was empty because group 1292
(CSR) held no impersonation right over 100100. Now `AccessUser` 100100 carries
`AccessUserUserAndGroupType: SystemAccount` (the system name of the user type the Swift package
declares under `Files/System/UserTypes/SystemAccount.xml`), and the layer ships its first
`AccessUserSecondaryRelation` row, `1292$$100100`: `AccessUserSecondaryRelationUserId` 1292 is
the impersonator, `AccessUserSecondaryRelationSecondaryUserId` 100100 the account impersonated
(DW's naming runs the other way from how it reads). The table is added to `fragmentTables`, to
`config/sample-data-2.4.json` as a Merge predicate keyed on the pair, and to
`merge/merge-manifest.json`. Its `_meta.yml` is authored from the documented three-column shape
(`AutoId` identity, `UserId`, `SecondaryUserId`) rather than harvested; the gate's row-count
parity is what proves it. Two `configRows` assert the type and the grant. Impersonation resolves
through the Secondary users index and the user cache, so a host that receives this by merge needs
that index rebuilt (`Secondary users` / `Users.index`) beside the restart the delivery already
owes.

## 4.1.1

### The orders carry their price columns, and variant editing ships with the layer

**PATCH. Two data defects the live 5.1 arms surfaced, fixed in the layer. No id change, no
row removed; six settings rows added.**

**1. Orders landed with zero totals online (Foundry [#1239], arm B).** The 12 `TCO-*` orders
shipped `OrderTotalPrice` and the lines shipped `OrderLinePriceWithVAT`, but every VAT-split
column Swift actually reads was empty, so My orders and the order detail rendered `0` after a
clean delivery. `OrderRecalculate` on a host repaired them, which is why the defect never
reached a gate leg.

The column set was derived by running `OrderRecalculate` on ONE order (`TCO-0012`) on
`foundry.mydwsite4.com` and diffing the row before and after, not from guesswork. The price
columns it writes, now shipped on all 12 orders and 20 lines:

| `EcomOrders` | `EcomOrderLines` |
|---|---|
| `OrderPriceWithVAT`, `OrderPriceWithoutVAT`, `OrderPriceVAT`, `OrderPriceVATPercent` | `OrderLinePriceWithVAT`, `OrderLinePriceWithoutVAT`, `OrderLinePriceVAT`, `OrderLinePriceVATPercent` |
| `OrderPriceBeforeFeesWithVAT`, `OrderPriceBeforeFeesWithoutVAT`, `OrderPriceBeforeFeesVAT`, `OrderPriceBeforeFeesVATPercent` | `OrderLineUnitPriceWithVAT`, `OrderLineUnitPriceWithoutVAT`, `OrderLineUnitPriceVAT`, `OrderLineUnitPriceVATPercent` |
| `OrderShippingFeeWithVAT` / `WithoutVAT` / `VAT` / `VATPercent`, `OrderPaymentFeeWithVAT` / `WithoutVAT` / `VAT` / `VATPercent` | `OrderLineTotalDiscountWithVAT`, `OrderLineTotalDiscountWithoutVAT`, `OrderLineTotalDiscountVAT`, `OrderLineTotalDiscountVATPercent` |
| `OrderTotalDiscountWithVAT` / `WithoutVAT` / `VAT` / `VATPercent` | |

The values follow the layer's own VAT rule (`OrderVAT 0`) rather than the recalculated ones:
`WithVAT = WithoutVAT =` the amount, `VAT = 0`, `VATPercent = 0`; line totals are
`OrderLineUnitPrice x OrderLineQuantity`; unit columns are `OrderLineUnitPrice`;
`OrderPriceBeforeFees*` is the line sum; the shipping and payment fees stay as shipped (`0` on
every order). The line sum equals `OrderTotalPrice` on all 12 orders, so nothing moved:
`TCO-0001` = 60 x 2 + 75 x 1 = **195**.

`OrderRecalculate` is deliberately NOT the fix. It re-prices every line from the LIVE catalogue
(`TCO-0012-1` came back unit 60 -> 51, line 120 -> 102) and leaves `OrderLineUnitPrice` stale,
so a historical order would stop being historical on every host.

A new `configRow` asserts `EcomOrders` `TCO-0001` `OrderPriceWithVAT = 195`, so the gate proves
the totals from now on.

**2. The six master-only product fields reset the variant rows (Foundry [#1253], [#1238], arm
B).** DW 10.28 keeps `ProductNumber`, `ProductPrice`, `ProductStock`,
`ProductShortDescription`, `ProductMetaTitle` and `ProductMetaDescription` master-only by
default. This layer ships 36 variant rows with their own number, price and stock, so the first
save of a variant master through any route wiped them.

The setting lives in the DATABASE, not in `GlobalSettings.Ecom.config`: one row per field in
**`EcomProductField`**, column **`ProductFieldAllowChangesAcrossVariants`**, with
`ProductFieldIsStandard = 1`. The `/Ecom/ProductLanguageControl/Variant/*` nodes in the config
file are the pre-migration store (DW carries a `MigrationToDatabaseDone` flag beside them) and
still read `True` for `ProductNumber` on a host whose behaviour is master-only. So the layer
SHIPS the setting: six `merge/_sql/EcomProductField/TCFIELD-*.yml` rows behind a new merge
predicate, with a `configRow` on `TCFIELD-PRODUCTNUMBER` proving it landed. The PKs are
`TCFIELD-<SYSTEMNAME>` rather than the `FIELD<n>` the `EcomNumbers` `FIELD` counter mints,
because a deserialize does not advance that counter; the identities `100130`-`100135` are in
the layer's reserved range above the `100000` floor.

The base is untouched: it ships no `EcomProductField` row and owns no part of this setting.

Rows 1,871 -> 1,877; tables 28 -> 29; predicates 28 -> 29.

[#1239]: https://github.com/justdynamics/Truvio.Commerce.Foundry/issues/1239
[#1253]: https://github.com/justdynamics/Truvio.Commerce.Foundry/issues/1253
[#1238]: https://github.com/justdynamics/Truvio.Commerce.Foundry/issues/1238

## 4.1.0

### The brand assets ship in the layer, and the logo and the home images are bound

**MINOR. New files, new content bindings, no id or row change.** The demo came up with no
logo and no picture on the front page: the header Logo paragraph and the three home
paragraphs that carry an `Image` field all shipped `Image: ""`, and every path in
`brand/brand-assets.manifest.json` answered 404 because no layer put the bytes on disk and no
tool ever fetched them. The manifest described a brand step that did not exist.

**What ships now.** The fifteen assets the manifest names are committed under
`files/Images/TruvioCommerce/{brand,scenic,people}/` and declared in `files[]`, the same way
the 264 product tiles and the 8 datasheets already are. Each was fetched from its
`source` and verified byte count and sha256 against the manifest before it was committed;
`.gitattributes` marks `*.webp`, `*.jpeg` and `*.jpg` binary so a checkout cannot rewrite a
byte the pin depends on. The manifest stays where it is and keeps its role: it is the
provenance and integrity record for what the layer ships, not a download list for a step a
consumer has to run.

**The bindings.** Seven paragraphs in `merge/_content`, `Image` field only (plus the `AltText`
beside it where the new picture made the old sentence wrong):

| Paragraph | Item type | Image |
|---|---|---|
| `Header _ Footer/Desktop Header/grid-row-3/paragraph-c1-17.yml` | `Swift-v2_Logo` | `brand/truvio-logo.svg` |
| `Header _ Footer/Mobile Header/grid-row-2/paragraph-c2-4.yml` | `Swift-v2_Logo` | `brand/truvio-logo.svg` |
| `Header _ Footer/Desktop Footer/grid-row-1/paragraph-c1-28.yml` | `Swift-v2_Logo` | `brand/truvio-logo.svg` |
| `Header _ Footer/Mobile Footer/grid-row-1/paragraph-c1-15.yml` | `Swift-v2_Logo` | `brand/truvio-logo.svg` |
| `Home/grid-row-1/paragraph-c1-18.yml` | `Swift-v2_Poster` | `scenic/product-shot-1.webp` |
| `Home/grid-row-4/paragraph-c1-19.yml` | `Swift-v2_Image` | `scenic/abstract-patterns.jpeg` |
| `Home/grid-row-7/paragraph-c1-8.yml` | `Swift-v2_Image` | `people/office-collaboration.webp` |

**Why the logo is the SVG and the bands are raster.** `Swift-v2_Logo/Plain.cshtml` and
`Swift-v2_Image/Plain.cshtml` both branch on `image.IsSvg()`: an SVG is inlined with
`ReadFile(image.Path)` and never touches `GetImage.ashx`, so the ImageSharp "no SVG decoder"
rule that puts the product tiles on PNG does not reach the logo. The item type says so itself
("We recommend you to use a SVG file. SVG files are scalable and support theming"). The four
logo paragraphs therefore get `truvio-logo.svg`, the monochrome primary, which reads on the
light header and the light footer; `truvio-logo-footer.svg` is the white-on-dark variant and
stays unbound because neither header nor footer carries a dark color scheme. The band images
go through `image.ToGetImage()`, so they are raster, and **all three are opaque on purpose**:
`GetImage.ashx` answers a `format=webp` and a no-format request with JPEG (Foundry #1240), so a
picture with an alpha channel is flattened against whatever the encoder fills, and a hero whose
white heading sits on it cannot be allowed to depend on that. `scenic/product-visual.png`,
`scenic/ui-composite.webp`, `brand/truvio-symbol.png` and `brand/truvio-og-card.png` all carry
alpha; all four ship in `files/` and none of them is bound to a paragraph.

**The bands that have no `Image` field.** `Home/grid-row-6` c1-5, c2-6 and c3-7 are
`Swift-v2_Feature`, which carries `Icon`, not `Image`, and all three already point at a bound
`/Files/Images/Icons/*.svg`. They are left alone. No other paragraph in the layer's storefront
copy carries an empty `Image`.

## 4.0.0

### One sample-data layer: the brand catalogue and the demo clock in the same layer

**MAJOR. The `truvio-demo` layer is retired and merged into this one, and every subject a
feature-layer probe addresses changes id.** A consumer pinning `origin/main` gets the merged
layer; a consumer that referenced `truvio-demo@1.9.0` finds a tombstone in
[`layers/INDEX.json`](../INDEX.json) naming `sample-data` as its successor.

**Why the split existed and why it is gone.** Two layers carried kind `sample-data`: this one
with marker-string gate fixtures on the `sampleData` toggle, and `truvio-demo` with the brand
catalogue as an `add[]` ref. The split was the owner decision on Foundry #1074: the fixture rows
leaked 12 bare placeholder product strings onto the unfiltered PLP and 6 placeholder group
values into the facet rail of the storefront a prospect opens, so the demo edition had to turn
`sampleData` off and take its catalogue from a second layer. The merged layer carries **no
placeholder row at all**, so the reason is gone — and with it the `gate-fixtures` edition that
existed only to give the fixture probes a composition to resolve in.

**What ships now.** Everything `truvio-demo` 1.9.0 shipped: 28 tables of serialized merge-mode
SqlTable YAML, the `merge/_content` storefront copy, `replace/_content` mega-menu documents,
`files/` (272 images and documents), the predicates (renamed
`config/truvio-demo-2.4.json` -> `config/sample-data-2.4.json`, every predicate name renamed
with it), the `tools/` gallery-photo converger, and the `fragmentTables` / `configRows` /
`files` / `costHints` declarations. Plus, from the old layer, exactly two loose scripts:

| Kept | Dropped |
|---|---|
| `merge/_sql/demo-clock.sql` | `merge/_sql/identities.sql` |
| `merge/_sql/email-stats.sql` | `merge/_sql/catalog.sql` |
| | `merge/_sql/feature-fixtures.sql` |

Dropped with them: every `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` / `FIXT-ORDER-*` /
`PACK-RPP-*` / `PACK-BOM-*` / `PACK-BOM3-*` / `PACK-SUB-*` row, the users `1328` / `1326`, the
customer numbers `98745621` / `7789765`, and the three `sqlcmd` variables `identities.sql`
declared. The layer now declares **no `sqlcmd` variable at all**: passwords are set online
through the Management API `UserSetPassword` command, never written into a row.

### The new subscription plan

`PACK-SUB-PROD1` was the only probe subject with no brand equivalent, so the catalogue gains
one product: **`TCPROD0061`, `TC-SUB-0061`, "Truvio Subscription Plan 61"** in
`TCGRP-PRICE-STRUCTURES` (primary) and `TCGRP-COMMERCE`, EUR list 49 on
`TC-PRICE-LIST-0061`, stock 240 on `EcomStockUnit` `100261`, the seven `tc_commerce` spec
values its siblings carry, two related products (`TCPROD0020`, `TCPROD0016`) and a primary
image reusing the `Price Structures` band tile. No new asset was authored: the band tile is
already the shipped fallback for that concept and it now lands as default on one product row
(6 usages, well under the bulk-attach-tail ceiling of 11). It follows D-B and the frontend
filter — a plan is a price structure with a period attached, which the quantity price table
shows.

### The demo clock now anchors the brand orders

The clock's anchor was seeded with `GETDATE()`, which was right when `catalog.sql` seeded its
rows with `GETDATE()` too. The merged layer's rows are serialized YAML carrying **absolute
dates frozen at the harvest day 2026-09-13**: the twelve orders `TCO-0001`..`TCO-0012` ladder
back from 2026-09-12 and every product carries `ProductCreated` and `ProductExpectedDelivery`
from the same harvest. A `GETDATE()` anchor would therefore read delta 0 on a fresh install and
leave the orders frozen in 2026-09 forever while the task reported Success. The anchor is now
the literal `2026-09-13`, so the first run carries a real delta and moves the whole dataset onto
today's calendar in one pass. **The brand orders ride the clock**, and the rewind-and-run recipe
at the foot of the script now captures `TCO-0001`. Neither script otherwise depended on a
dropped row; `email-stats.sql`'s two references (`FIXT-RCPT-` recipient keys, a
`/shop?ProductID=FIXT0002` tracked link) are repointed to `TC-RCPT-` and to the PDP link shape
the layer documents, `GroupID` and `ProductID` together.

### Counts

| Table | 4.0.0 | Table | 4.0.0 |
|---|---:|---|---:|
| `AccessUser` | 4 | `EcomProductCategory` | 4 |
| `AccessUserGroupRelation` | 6 | `EcomProductCategoryField` | 28 |
| `EcomDetails` | 373 | `EcomProductCategoryFieldTranslation` | 28 |
| `EcomDetailsGroup` | 2 | `EcomProductCategoryFieldValue` | 427 |
| `EcomFieldDisplayGroupFields` | 28 | `EcomProductCategoryTranslation` | 4 |
| `EcomFieldDisplayGroupTranslation` | 1 | `EcomProductItems` | 10 |
| `EcomFieldDisplayGroups` | 1 | `EcomProducts` | **97** |
| `EcomGroupProductRelation` | 122 | `EcomProductsRelated` | 326 |
| `EcomGroupRelations` | 12 | `EcomProductsRelatedGroups` | 3 |
| `EcomGroups` | **16** | `EcomShopGroupRelation` | 4 |
| `EcomOrderLines` | 20 | `EcomStockUnit` | 61 |
| `EcomOrders` | 12 | `EcomVariantGroupProductRelation` | 12 |
| `EcomPrices` | 233 | `EcomVariantGroups` | 2 |
| `EcomVariantOptionsProductRelation` | 30 | `EcomVariantsOptions` | 5 |

**1,871 rows**, 15 more than the 1,856 the brand harvest measured — all fifteen belong to
`TCPROD0061`: 1 product, 2 group relations, 1 price, 1 detail, 1 stock unit, 2 relations and 7
spec values. `EcomProducts` 97 = 60 masters + 36 variant rows + the plan. `EcomGroups` 16 = 4
top + 12 sub, unchanged. Every figure equals the row-file count in `merge/merge-manifest.json`.

### The contract subjects

The five feature layers stop naming rows this layer ships and name subjects the base contract
guarantees (`base.contract.json` `sampleData.guaranteedRows`, new in base 3.5.0):

| Probe | Was | Is |
|---|---|---|
| feature-reordering `sku-validation` | `FIXT-0001` | `TC-VAR-0001` (`TCPROD0001`) |
| feature-pricing `cart-price` tier | `PACK-RPP-PROD1`, qty 5, 4500 | `TCPROD0020`, qty 10, **96** |
| feature-pricing `cart-price` contract | `PACK-RPP-PROD2`, qty 1, 1399 | `TCPROD0046`, qty 1, **36.90** |
| feature-bom-configurator `bom-cart-lines` | `PACK-BOM-0001` + 2 slots | `TCPROD0042` + `TC-BOM-0042-1` / `TC-BOM-0042-2` |
| feature-subscription-orders `checkout-recurring` | `PACK-SUB-PROD1` | `TCPROD0061` |
| feature-rma `authenticated-body-contains` | buyer `1328`, order `FIXT-ORDER-RMA1` | buyer `100101`, order `TCO-0001` |

### Activation

`sampleData: true` now means *the demo shop*, so `swift-demo` sets it true and drops its
`truvio-demo@1.9.0` ref; `headless-demo` and `dap-portal` keep it true and pin
`EcomProducts` 97 / `EcomGroups` 16; `base-swift` and `base-only` keep it false and stay
catalogue-free. `editions/gate-fixtures.json` is deleted.

---

## Prior releases

The 4.0.0 layer is the merge of two layers, and both histories are kept. The entries of the
retired `truvio-demo` layer are labelled as such.

### sample-data 2.3.4

#### The password variables carry the platform hash (Foundry #1104, password half)

`identities.sql` writes `BuyerPassword` and `CsrPassword` verbatim into `AccessUserPassword`,
and the host stores a 128-character hex SHA512 string there. The descriptions said "demo
password", so a caller passing the plaintext seeded buyer and CSR rows that could never sign
in, with no error anywhere.

- `layer.json`: both variables declare `valueShape: "dw-password-hash"` (new in
  `layers/layer.schema.json`) and their descriptions state the value is the platform hash
  (lowercase hex of SHA512 over UTF8(password + "DwSecret")), never the plaintext. The Foundry
  composer `sql[]` applier (Foundry PR #1213, #1066) reads `valueShape`, takes the plaintext and
  hashes it once.
- `identities.sql`: the same shape guard `truvio-identities.sql` carries runs before
  `BEGIN TRAN`. Any value that is not 128 hex characters raises an error naming the variable and
  `RETURN`s, so nothing is written with or without `sqlcmd -b`. The header states the contract.
- No row, id or count changes. A caller that still passes the plaintext now fails loudly
  instead of seeding users that cannot sign in.

### sample-data 2.3.3

**The fixtures stop being demo content, and not one row changes (Foundry #1074, #1174, #1127,
#1134).** Two defects were filed against the rows this layer ships on purpose. On the unfiltered
`/en-us/shop` the branded v5 host served **12 bare `Placeholder product.` strings** inside
`itemprop="disambiguatingDescription"`, from 22 `FIXT*` / `PACK-*` masters (28 `EcomProducts`
rows) - and no assert saw them, because `design-assert.publish.json`'s `placeholderRegex` requires
a dash after the marker word and these carry a space (#1174). On the PLP the Group facet rail
rendered **6 `Sample Group N` values**, the permanent `STOCKCOPY-01` FAIL the design leg cannot
pass while sample data is composed: one leg asserts those names must render correctly (the 2.3.2
em-dash repair) and another asserts they must not render at all (#1127, rail re-screened in
#1134).

Neither is a rendering bug and neither is fixed by rewriting a row. The rows are doing what they
were written to do - be stable, id-addressable subjects for the gate's layer-declared probes. The
defect is that they were composed into the storefront a prospect opens. The owner decision on
#1074 (2026-09-13, round-three close-out) resolves it in `editions/`:

- `editions/swift-demo.json` sets **`sampleData: false`**. Its catalogue is `truvio-demo@1.7.0`,
  and `expectedCounts` is pinned to what that layer ships (96 / 16 / 96, measured) because
  `Set-ConfigFromEdition` derives the product and group counts from the `sampleData` toggle alone.
- `editions/gate-fixtures.json` is **new** and is the only composition that sets
  `sampleData: true` on the Swift surface. It carries the same seven feature layers at the pins
  swift-demo carried before this change, because `behaviorProbes` are LAYER asserts and the five
  fixture legs need a composition that still ships their subjects: `sku-validation FIXT-0001`,
  `cart-price PACK-RPP-PROD1/PROD2`, `bom-cart-lines PACK-BOM-0001`,
  `checkout-recurring PACK-SUB-PROD1`, and feature-rma's authenticated `/my-returns` probe, which
  needs buyer 1328 and `FIXT-ORDER-RMA1`.

`headless-demo` and `dap-portal` keep `sampleData: true`: neither renders the Swift PLP or its
facet rail, and `surface-headless`'s own query deliberately drops the shop and language macros.

**This layer's SQL is unchanged.** Every `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` / `PACK-*` id, row,
count and price is byte-identical to 2.3.2 - `EcomProducts` 20 + 8, `EcomGroups` 3 + 5,
`EcomPrices` 4 + 4, the 2 BOM slots and `FIXT-ORDER-RMA1`. The only edit to `catalog.sql` is a
comment: the NEUTRALIZATION CONVENTION block said "on any edition with `sampleData: true` this is
the catalogue a prospect sees", which is now false, and the block records why the marker word
stays - several asserts key on it, so the next pass must not neutralize the strings instead of the
composition.



### sample-data 2.3.2

**The PLP facet sidebar rendered mojibake where the layer has an em dash (Foundry #1095).**
Measured on the branded v5 e2e host: 3 `FIXTGRP*` group names and 20 `FIXT*` product names
carried `U+00E2 U+20AC U+201D` in place of `U+2014`. The layer file was never wrong - it is
clean UTF-8 - but a UTF-8 em dash is the three bytes `E2 80 94`, and an applier that runs
`sqlcmd` without `-f 65001` reads them in the machine's ANSI code page and stores three
characters instead of one. The file cannot control how it is read, so it stops depending on
it: every separator is now written as its code point, `N'...' + NCHAR(8212) + N'...'`, and
no name literal in `catalog.sql` carries a non-ASCII byte. The displayed value is unchanged,
and the script now seeds the identical em dash under either code page - verified by applying
it twice on the 10.28.10 host, once with `-f 65001` and once without.

New section 6 repairs a host that was already seeded. It rewrites the CP1252 misdecode
signature back to `U+2014` across `EcomGroups.GroupName`, `EcomProducts.ProductName` /
`ProductShortDescription` and the `EcomOrderLines` name snapshot on the `FIXT-ORDER-%` keys,
existence-guarded so a clean host is never written to. Section 0's DELETE-then-INSERT already
converges the rows this file owns; section 6 states the convergence rather than leaving it
implicit, and reaches the snapshot columns a reset does not.

### sample-data 2.3.1

**`demo-clock.sql` did not compile on SQL Server (Foundry v5 e2e, DW 10.28.10).** Three
compile-time and insert-time faults, all measured on a live apply, none of them reachable by the
script's own shape guards because the batch never got that far.

`usp_DemoClockShift` joins its own `dbo._demoClockExclusion` / `dbo._demoClockGuard` sysname
columns against `sys.tables.name` and `sys.columns.name`. The catalog carries
`Latin1_General_100_CI_AS_KS_WS_SC`; the layer's tables take the database default
`Latin1_General_100_CI_AS`. The two compares (the exclusion `NOT EXISTS`, and the guard
`LEFT JOIN`) raised a collation conflict at compile time, so the procedure never ran. Both now
carry `COLLATE DATABASE_DEFAULT`, which follows whatever collation the target database was
created with rather than hardcoding one.

The `ScheduledTask` registration then failed with Msg 2628: `TaskComment` is `NVARCHAR(255)` and
the literal was 364 characters. Shortened to 251, meaning kept — what it shifts, by what delta,
that the shift is whole-day and uniform, and where the exclusions and guards live.

No behaviour change beyond the script now executing: the shift semantics, the anchor mechanic and
the task recurrence are untouched.

### sample-data 2.3.0

**The feature layers' catalogue rows moved here (Foundry 960).** Composed with `sampleData: false`
the distribution was supposed to have an empty catalogue, and the acceptance criterion said so; the
e2e host measured `EcomProducts = 8`, `EcomGroups = 5`, `EcomPrices = 4` on exactly that run. The
rows were not smuggled — they were shipped openly by three feature layers, each README calling it
catalog self-sufficiency, because the base is scaffolding-only. The reason the gate could not name
the owner is that `Set-ConfigFromEdition` *derives* `EcomProducts = 0` from the toggle instead of
measuring what the composed layers insert, so eight products arriving looked like a count mismatch
rather than a finding with an address.

The fix is the plain invariant, restored: the catalogue rides the single `sampleData` toggle and
nothing else. `merge/_sql/feature-fixtures.sql` (declared, phase `after-replace-deserialize`,
order 2) now seeds the 5 groups, 8 products, 4 prices and 2 BOM slots that `feature-pricing`,
`feature-bom-configurator` and `feature-subscription-orders` used to ship in their own mode trees.
**Every id is unchanged** — `PACK-RPP-*`, `PACK-BOM-*`, `PACK-SUB-*` — because each layer's
`behaviorProbes` and demo pages address these products by id; only the owner moved. `email-stats`
and `demo-clock` shift to order 3 and 4.

Consequence worth stating out loud: a feature layer's behaviour probe is now meaningful only on an
edition that also carries sample data. `swift-demo` does; `base-swift` composes no feature layers
at all, which is the composition the emptiness claim was always about.

### sample-data 2.2.0

Two things this layer promised and never delivered: a composer could not FIND its SQL, and
what the SQL seeded went stale the week after it landed.

**The loose scripts are now declared and discoverable (Foundry #427).** `merge/_sql/*.sql`
carried no `merge-manifest.json` entry, so a `sampleData: true` composition staged the
files and executed nothing: DemoAgent's `Compose-Edition` reported `{replace:0, merge:0},
files 3`, the storefront came up with 8 products (all feature-layer fixtures) and no
sample-data catalogue, and the flag lied end to end. The Foundry gate never saw it because
it seeds both scripts by explicit path.

The serializer manifest has no shape for a loose script. Its only `providerType`s are
`Content` and `SqlTable`, and `SqlTable` is row-per-YAML under `_sql/<Table>/<key>.yml`, so
there was nothing to add an entry to. The fix is a new **`sql[]` declaration in
`layer.json`**, added to `layers/layer.schema.json` alongside `fragmentTables` /
`fragmentContent` / `files`: per script the file, the mode tree, the phase
(`before-host-start` / `after-replace-deserialize` / `after-merge-deserialize`), the order
within that phase, whether the host must be restarted afterwards, and every `sqlcmd`
variable the caller must supply. A layer shipping a loose `.sql` under a mode tree must now
declare it there.

**The demo clock ships (Foundry #25).** `demo-clock.sql` creates the `_demoClock(Id,
AnchoredTo)` anchor table, `usp_DemoClockShift`, and the daily `Truvio demo clock` task on
the stock `RunSqlScheduledTaskAddIn`.

- The shift is **whole-day and uniform**: every operational date column moves by
  `DATEDIFF(day, AnchoredTo, today)`, which preserves intra-day ordering and every relative
  gap, then the shifter re-anchors its own row. Idempotent (`+1` then `-1` nets zero) and
  catch-up safe after idle days.
- Date columns are **discovered from `sys.columns` on every run**, never hardcoded: a
  reference build shifted 142 columns across 49 tables, every commerce feature spells its
  timestamps differently, and discovery is what keeps the shifter correct across a platform
  upgrade.
- Config and logging tables are excluded through `dbo._demoClockExclusion`, `ScheduledTask`
  first among them: `TaskNextRun` is what the scheduler reads, and the clock's own run
  history must stay readable. Sentinel values outside `[1900-01-02, 2900-01-01)` are left
  alone, so a `9999-12-31` never overflows `DATEADD` and aborts the batch.
- State-marker columns carry a guard in `dbo._demoClockGuard`. `GiftCardCancel` writes no
  reversing transaction and sets no status flag: it cancels by rewriting
  `GiftCardExpiryDate` to now and keeping the balance, so on a cancelled card that column is
  a cancellation timestamp. The shipped guard shifts only cards still in the future, and a
  cancelled card still reads inactive after a run.
- The task's `TaskAddInSettings` value is `EXEC dbo.usp_DemoClockShift;` — the shift SQL
  lives in the procedure precisely so the literal XML carries no metacharacter to escape.

**The email-marketing statistics backfill ships (Foundry #25).** `email-stats.sql` seeds,
per campaign email, one `EmailMessage` send-log row, 24 `EmailRecipient` sends of which 2
carry a delivery error, 3 tracked `OMCLink` rows and 13 `OMCLinkClick` clicks split 5/4/4
across the links, so the backend Marketing dashboards read as a real campaign instead of 0
sent / 0 clicked.

- The grid joins are the whole difficulty and are now carried in the script:
  `RecipientStatisticsByEmail` resolves recipients through
  `EmailMarketingEmail.EmailOriginalMessageId` = `EmailRecipient.RecipientMessageId` (NOT
  `EmailMessageId`), and per-recipient clicked is a count over `OMCLinkClick` joined to
  `OMCLink` where `LinkReferenceKey` is the message id as a string, `LinkReferenceType` is
  `EmailMessaging`, and `LinkClickClickerKey` is the recipient id as a string. Either key
  alone yields 0.
- **Opened is pixel-only and is not attempted.** The per-recipient opened column and the
  `EmailById` aggregates are materialized by the live open-tracking pixel handler and are
  not reproducible from raw SQL.
- The backfill is **discovery-driven**: it seeds every `EmailMarketingEmail` row with no
  send history and is a clean no-op on a composition that ships none. sample-data authors no
  campaign emails of its own, and an addition binds to the base contract, never to another
  layer's rows.
- Idempotent through a marker: every row it writes carries
  `EmailMessage.MessageDomainUrl = 'https://sample-data.example.invalid'`, and the script
  deletes its own marked rows before re-seeding. An email whose send history points at an
  unmarked message is left alone, so a real send is never overwritten.

Unchanged: every reserved key (`FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`), every product number,
every price, the variant structure, and the `EcomProducts = 20` / `EcomGroups = 3`
determinism contract. Minor bump: two new scripts and a new declaration, no existing shape
moved.

New reserved names owned by this layer: `dbo._demoClock`, `dbo._demoClockExclusion`,
`dbo._demoClockGuard`, `dbo.usp_DemoClockShift`, the `ScheduledTask` row named
`Truvio demo clock`, and the `FIXT-RCPT-*` recipient key prefix.

### sample-data 2.1.0

The demo catalogue carries no real-world product domain. `catalog.sql` seeded 20 products
literally named "Fixture House Blend" / "Fixture Single Origin" / "Fixture Decaf" into
groups "Fixture Beverages" / "Fixture Equipment" / "Fixture Accessories", with no
description column in the INSERT at all - a coffee-shop test fixture standing in for the
storefront on every edition that sets `sampleData: true`.

Every demo-facing value is now a **function-descriptive placeholder** naming what the row
exists to demonstrate, so the build replaces it per customer:

- Products are `Sample Product NN — <role>` (`Master`, `Qty Tiers`, `Contract Price`,
  `Size Variants`); groups are `Sample Group N — <function>`.
- `ProductShortDescription` added to the master INSERT and carried through the six
  variant `SELECT` inserts, so the PDP/PLP description lane is no longer blank. Each one
  opens with the literal word `Placeholder`, the machine-detectable marker a design gate
  scans for (`/placeholder/i`).
- The RMA demo order line's `OrderLineProductName` follows the master it references.

Unchanged on purpose - this is the layer's determinism contract: every reserved key
(`FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`), every product number, every price, the variant
structure, and every row count. `EcomProducts = 20` / `EcomGroups = 3` still holds, so no
edition's derived row-count contract moves and `surface-swift`'s newsletter product rail
(which cites `FIXT0002/0004/0006/0010` by id) is unaffected. Minor bump: data content
changes, shape does not.

### sample-data 2.0.2

RMA demo interplay (P3, RUN-DISTRIBUTION-QUALITY item E). `catalog.sql` gains a section 5
seeding **one delivered order** `FIXT-ORDER-RMA1` (`OrderStateId OS2` Completed, buyer
`98745621`, order line on `FIXT0001`) for the new `feature-rma` layer to return against, plus
the `EcomRmaOrderLines` link to `feature-rma`'s `EcomRmas` request `PACK-RMA-0001`. The link is
seeded here (not in feature-rma) because `EcomRmaOrderLines.RmaOrderLineId` is an int IDENTITY PK
the serializer cannot natural-key insert; raw SQL handles it deterministically. No DB FK on the
RMA tables (verified), so the cross-layer header/link order is free. Idempotent DELETE+INSERT on
the demo keys; no impact on the EcomProducts=20 / EcomGroups=3 / EcomCountries=96 row-count
contract, and harmless (orphan link + one extra completed order) in editions without feature-rma.

### sample-data 2.0.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). SQL verified against the 10.28 schema (solution custom columns come from cleandb-align-schema.sql, applied by every gate run before the catalog). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

### sample-data 2.0.0

The layer now ships its **entire content as SQL files** under `merge/_sql/` and absorbs
the demo shop catalog (previously the separate `catalog-fixture` layer, retired at 1.0.0).

- **Added `merge/_sql/identities.sql`** — the demo identities (permission groups
  1325/1270/1292, buyer 1328, CSR 1326, memberships) as a shipped, idempotent script.
  Demo credentials are `sqlcmd` variables (`BuyerUserName`, `BuyerPassword`,
  `CsrPassword`), never repo content.
- **Added `merge/_sql/catalog.sql`** — the demo shop catalog for SHOP1/ENU/EUR
  (EcomProducts 20, EcomGroups 3, Size variant axis, qty-tier price ladder), absorbed
  from `catalog-fixture`. The buyer contract price (`FIXT-PRICE-CONTRACT`, customer
  number 98745621) ships here, next to the product it scopes to.
- **Absorbed the reserved key prefixes** `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`
  (base contract `idRules.reservedFixtureKeys`).
- Editions activate everything above with the single `sampleData: true` toggle;
  `catalog-fixture@1.0.0` disappears from every edition's `add`.

### truvio-demo 1.9.0

#### Truvio Commerce storefront copy over surface-swift's placeholder convention (Foundry 5.1, STOCKCOPY-01)

surface-swift ships every demo-facing string in its `Placeholder` marker form on purpose: a
composition with no brand layer fails the design gate instead of shipping template copy. On
`swift-demo` the brand layer is this one, and until now it carried no content, so the home
page rendered the marker copy and STOCKCOPY-01 stayed red. This release adds the copy. It is
content added, so a minor release.

**What ships.** 43 content documents, each a copy of surface-swift 1.13.1's document at the
same mode-tree path with only the copy fields rewritten and an `ownership` header set to
`replace` (ids, item types, templates, colour schemes, icons and grid structure are unchanged):

| Page or block | Documents | Tree |
|---|---:|---|
| Home: hero, catalogue pitch, feature row, three features, account call to action, three figures, About button, two image alt texts, page meta | 14 | `merge/_content/Swift 2/Home/` |
| About: intro, three values, partner band, three figures, team heading, contact band, page meta | 11 | `merge/_content/Swift 2/About/` |
| Contact: intro, two contact details, page meta | 4 | `merge/_content/Swift 2/About/Contact/` |
| About us page meta, Employees intro, Posts intro | 3 | `merge/_content/Swift 2/Navigation/...`, `.../Posts/` |
| Four logo wordmarks, two footer copyright lines | 6 | `merge/_content/Swift 2/Header _ Footer/` |
| Mega-menu: two promo images, two promos, editorial column | 5 | `replace/_content/Swift 2/Navigation/` |

The copy follows D-B: the brand is Truvio Commerce and every noun is PIM, Commerce or CMS
vocabulary. Figures are this layer's own counts (60 masters, 12 groups, 36 variant rows, 4 top
groups, 96 customer-group prices, 324 relations). Calls to action point at real pages through
`Default.aspx?ID=N` links, so the serializer's page-id remap resolves them: Shop (50), Shop with
`GroupID=TCGRP-DATA-MODELS` and `GroupID=TCGRP-COMMERCE` (the query tail sits outside the link
pattern and survives the remap), About (165) and Contact (166). Every document was scanned with
the publish design config's `placeholderRegex`: zero matches.

**How it wins, and the one dependency.** The composed SerializeRoot holds one file per path, and
Compose-Edition copies layers in composition order with the later layer's file winning. The
engine walks that tree and, at Serializer 933d4c2, writes paragraph item fields source-wins in
both passes (`SaveItemFields`); only pages merge-fill. So whichever document sits at the path in
the composed tree is the copy the host gets, on a fresh database and on a host that already
holds the marker copy. The `ownership: replace` header additionally makes the four `page.yml`
documents overwrite an existing meta description instead of merge-filling around it.
surface-swift's existing manifest entries (`content/area-3/Home` and siblings) already list
every one of these paths, so this layer adds no Content entry and no duplicate merge entry.

Compose-Edition at Foundry `0cfc247f` composes `base -> add[] -> surfaces[]`. truvio-demo is
an `add[]` ref and surface-swift a `surfaces[]` ref, so on that composer surface-swift's
document wins every shared path and this release does not reach the storefront. It needs the
composer to place `add[]` layers of kind `sample-data` after `surfaces[]`. With that one change
applied to a scratch copy of the composer, `swift-demo` composes all 43 documents
byte-identical and no document on a rendered path carries the marker; `base-swift` composes
byte-identical to before (manifest timestamps aside).

`layer.json`: `fragmentModes` gains `replace` for the mega-menu documents.

### truvio-demo 1.8.0

#### The commerce dataset ships as serialized SqlTable YAML (Foundry #1215)

The five loose scripts (`truvio-catalog.sql`, `truvio-identities.sql`, `truvio-images.sql`,
`truvio-b2b.sql`, `truvio-pdp.sql`) are gone, and so is `layer.json` `sql[]`. Their end state
now ships as merge-mode SqlTable rows: `merge/_sql/<Table>/<key>.yml` for 28 tables (1,856 row
files plus one `_meta.yml` per table), `merge/merge-manifest.json` (schemaVersion 2, complete),
and the 28 merge predicates in `config/truvio-demo-2.4.json`. `layer.json` declares
`fragmentModes: ["merge"]`, the 28 `fragmentTables` and five `configRows`. The same rows
arrive through a new channel, so this is a minor release: an online build, which has no SQL
surface, now delivers the whole layer through the ordinary merge deserialize, and
`-SqlChannel online` no longer reports a truvio-demo script.

**How the rows were produced.** On `foundry-sqlsrc.mydwsite4.com` (DW 10.28.10, Swift 2.4,
Serializer 1.0.1-beta), `swift-demo` was composed from Distribution `d036eae7` with
truvio-demo 1.7.2 and applied locally: replace deserialize 1190 / 10 / 33 / 0 failed, the five
scripts Done, merge deserialize 279 / 17 / 0 / 0. After the rekey below, one scoped Serialize
per predicate wrote the YAML (harvest completed 2026-09-13T22:55:41Z).

**Row parity, SQL route against YAML, table by table:**

| Table | SQL rows | YAML rows |
|---|---:|---:|
| `AccessUser` | 4 | 4 |
| `AccessUserGroupRelation` | 6 | 6 |
| `EcomGroups` | 16 | 16 |
| `EcomShopGroupRelation` | 4 | 4 |
| `EcomGroupRelations` | 12 | 12 |
| `EcomVariantGroups` | 2 | 2 |
| `EcomVariantsOptions` | 5 | 5 |
| `EcomProducts` | 96 | 96 |
| `EcomGroupProductRelation` | 120 | 120 |
| `EcomVariantGroupProductRelation` | 12 | 12 |
| `EcomVariantOptionsProductRelation` | 30 | 30 |
| `EcomPrices` | 232 | 232 |
| `EcomProductItems` | 10 | 10 |
| `EcomProductCategory` | 4 | 4 |
| `EcomProductCategoryTranslation` | 4 | 4 |
| `EcomProductCategoryField` | 28 | 28 |
| `EcomProductCategoryFieldTranslation` | 28 | 28 |
| `EcomProductCategoryFieldValue` | 420 | 420 |
| `EcomFieldDisplayGroups` | 1 | 1 |
| `EcomFieldDisplayGroupTranslation` | 1 | 1 |
| `EcomFieldDisplayGroupFields` | 28 | 28 |
| `EcomDetailsGroup` | 2 | 2 |
| `EcomDetails` | 372 | 372 |
| `EcomProductsRelatedGroups` | 3 | 3 |
| `EcomProductsRelated` | 324 | 324 |
| `EcomStockUnit` | 60 | 60 |
| `EcomOrders` | 12 | 12 |
| `EcomOrderLines` | 20 | 20 |
| **Total** | **1,856** | **1,856** |

**Rekeyed before harvest.** The serializer writes int-identity keys verbatim and never remaps
them, and the base contract requires such rows at or above `100000`. Three row sets were
moved to reserved ids on the harvest host, with every referencing column repointed:
`EcomDetailsGroup` `Images` 7 to `100110` and `Manuals` 8 to `100111` (`EcomDetails` and the
group translations follow); `EcomFieldDisplayGroups` `tc_specs` 14 to `100120` (28 display
group fields repointed); `EcomStockUnit` TC rows 5..64 to `100201`..`100260`. The storefront
re-smoke after the rekey was identical: PLP Variants 5 products; PDP TCPROD0001 with 5 variant
selectors, 7 spec rows, 6 document rows, 9 gallery images, 5 related rows, 0 `dw-error`.
The reserved ids and the new key prefixes (`TC-DETAIL-*`, `TC-HOVER-*`, `TC-GAL-*`,
`TC-DOC-*`, `TCREL-*`, `TCVGR-*`) are recorded in `costHints`.

**Persona passwords move online.** The `AccessUser` predicate excludes `AccessUserPassword`
and the runtime login columns; no row file carries a password or a hash. The three
`sqlcmdVariables` (`TruvioBuyerPassword`, `TruvioCsrPassword`, `TruvioAdminPassword`) and
their `valueShape` declarations went with `sql[]`. Set each persona's password after the
deserialize with Foundry `tools/secrets/Set-DemoCredential.ps1` (Management API
`UserSetPassword`) for `100101`, `100102` and `100103`, locally and online alike.

**Dropped, because merge carries the end state only.** The currency UPDATE that moved rate-1
rows to 100 (the base replace tree already carries none), and every converge UPDATE and
DELETE for hosts seeded by older versions (renames, re-homing, retired fields, image and
price converges). Hosts seeded before 1.5 are out of scope.

**Frozen at harvest.** Values the scripts derived at run time are literals now: group, list,
ladder and contract prices derived from `ProductPrice`, relative order and delivery dates,
variant counters and the `tc_specs` field list. The YAML is the source of truth; re-harvest
only from a host deserialized from it.

**costHints corrected from the measurement.** `EcomVariantOptionsProductRelation` is 30
(6 masters x 5 options), not 36. `EcomPrices` is 232, not 233: `TCPROD0021` "Truvio Assortment
Kit 21" is ProductType 2 with ProductPrice 0, and the 1.7.2 list-price insert derived
`TC-PRICE-LIST-*` from ProductPrice, so no list row ever existed for it.

**Follow-up, not changed here.** `TC-PRICE-GRPV-<n>` ids were built from the harvest host's
`PriceAutoId`, so they are host-derived. A later release should rekey them to a
product-derived id. Renaming them now would break parity with the proven harvest.

**Not yet proven.** The online round trip on a second keyed clone (compose with
`-SqlChannel online`, deserialize, Set-DemoCredential, re-serialize and compare byte for byte)
has not run. The storefront on such a clone also needs `surface-swift`'s `TruvioCommerce`
repository staged, which no delivery path does yet (Foundry #1218); that is a verification
prerequisite, not a defect in this layer.

### truvio-demo 1.7.2

#### The password variables declare their value shape (Foundry #1104, password half)

`TruvioBuyerPassword`, `TruvioCsrPassword` and `TruvioAdminPassword` declare
`valueShape: "dw-password-hash"` (new in `layers/layer.schema.json`). 1.7.1 stated the hash
contract in prose and guarded it in SQL; the declaration makes it machine-readable, so the
Foundry composer `sql[]` applier (Foundry PR #1213, #1066) hashes the plaintext it is given
without a side list. No SQL, row or count changes.

### truvio-demo 1.7.1

#### Column-shape guards run in a batch of their own (Foundry #1100)

SQL Server binds column names when it compiles a batch, before any statement in the batch
runs. A `COL_LENGTH ... RAISERROR` guard written in the same batch as the writes it guards is
therefore dead code: a mismatch kills the batch at compile time with a bare `Msg 207 ...
Invalid column name` that names no layer, no script and no intent, and the guard above it
never executes. The three named column faults were fixed in earlier releases; the structure
that hid them was not.

Every column-shape guard now sits in its own `GO` batch ahead of the writes: the four in
`truvio-catalog.sql` (per-variant prices and the axis binding, the product-category fields,
`ProductLongDescription`, the field display groups), the one in `truvio-pdp.sql` and the one
in `truvio-b2b.sql`. `COL_LENGTH` takes its names as strings, so the guard batch compiles on
any shape, runs, and names the column; under `sqlcmd -b` that ends the apply before the batch
that would have failed. No variable crosses a new `GO`, and every write is byte-identical.
`truvio-images.sql` already reaches its column set through `sp_executesql` and is unchanged.

#### Persona password variables carry the platform hash (Foundry #1104)

`truvio-identities.sql` writes `TruvioBuyerPassword`, `TruvioCsrPassword` and
`TruvioAdminPassword` verbatim into `AccessUserPassword`, and the host stores a 128-character
hex SHA512 string there. Nothing stated which of the two the variables mean, and a plaintext
value produces personas that cannot sign in with no error anywhere.

The script header, the README and the three `sqlcmdVariables` descriptions now state that
each variable is the platform hash. A shape guard runs before `BEGIN TRAN`: any value that is
not 128 hex characters raises an error naming the variable and `RETURN`s, so nothing is
written with or without `sqlcmd -b`. Computing the hash from a plaintext secret is the
applier's job.

#### The CSR and the account admin carry the account's customer number (Foundry #1110)

The README, `layer.json` and the baseline guide's Step 5 all state that the three personas
share customer number `TC-100200`; the SQL gave the CSR `TC-100201` and the admin
`TC-100202`. `get_users_by_customer_numbers(["TC-100200"])` returned one user, and the
contract price `TC-PRICE-CONTRACT` resolved for the buyer alone.

Both contacts now insert with `TC-100200`. Because the inserts are `IF NOT EXISTS`, a host
seeded before this release is converged by an UPDATE guarded on the difference. Row counts
are unchanged.

### truvio-demo 1.7.0

#### Every product image is raster, because the handler cannot decode a vector (Foundry #1171)

Dynamicweb's `GetImage.ashx` decodes with **SixLabors.ImageSharp**, and ImageSharp ships no
SVG decoder. The 500 body names the set it does have:

    SixLabors.ImageSharp.UnknownImageFormatException: Image cannot be loaded.
    Available decoders: Webp, TIFF, GIF, TGA, JPEG, PNG, PBM, BMP

thrown from `Dynamicweb.Imaging.Providers.ImageSharpProviders.ImageSharpImageConverterProvider.ProcessImage`.
Nothing in that list parses XML vector markup.

Three isolating controls on the composed host inside one minute:

| request | answer |
|---|---|
| `/Files/Images/TruvioCommerce/products/tc-tile-bundles-0042.svg` | 200, `image/svg+xml`, 1209 bytes |
| the same file through `GetImage.ashx`, `width=180&format=webp` | 500 |
| the same file through `GetImage.ashx`, width alone | 500 |
| the same file through `GetImage.ashx`, no parameters at all | 500 |
| a `.png` through the identical handler | 200 |

So it is neither the webp conversion nor a sizing argument. One PDP load produced **17
`tc-*` image requests and 17 of 17 answered 500**, across all three call sites - hero
gallery at `width=180`, relations strip at `width=30`, recommendation rail with no width -
and the three hero slides read `complete=true`, `naturalWidth=0`, `naturalHeight=0`, box
126x95.

Swift's card and gallery components only ever ask through that handler, because they need
its width and crop arguments. So **every `tc-*` product image has been a broken image
behind a correctly-counted `img` node since 1.2.0**: the node is in the DOM, the count is
right, the row is green, and the page paints a broken-image glyph. Same blind-spot class as
#1151 - presence judged without paint - applied to media.

**The layer ships raster.** `tools/make-tiles.py` now writes a PNG beside each SVG it
already wrote, plus a PNG twin of the twelve band tiles: 132 files, 480x480, 8-bit
truecolour. The PNG is not a rasterisation - no rasteriser is available and none is being
added as a dependency - it is a second drawing of the SAME per-product differentiators, so a
PNG tile still traces to one product: the two-digit numeral, the pip row whose COUNT is the
band position, the corner mark turned per position, the concept word, the band hue, and the
light-on-dark inversion for the detail. The writer is `zlib` + `struct` and a 5x7 bitmap
alphabet, nothing installed. Output is byte-identical run to run: no `tIME` chunk, a fixed
filter byte, a pinned deflate configuration. Largest file **3430 bytes**, smallest 2203, 132
files totalling 407 KB.

**The SVGs stay.** They are the authoring sources, they stay on disk and they stay in
`files[]`. Only what a row POINTS AT changed.

| row | 1.6.0 | 1.7.0 |
|---|---|---|
| `TC-DETAIL-TCPROD0042` | `.../tc-tile-bundles-0042.svg` | `.../tc-tile-bundles-0042.png` |
| `TC-HOVER-TCPROD0042` | `.../tc-detail-bundles-0042.svg` | `.../tc-detail-bundles-0042.png` |
| `TC-GAL-TCPROD0042-2` | `.../tc-tile-bundles.svg` | `.../tc-tile-bundles.png` |
| `EcomProducts.ProductImage*` | the `.svg` tile | the `.png` tile |

**Converging, both rows.** `truvio-images.sql` already converged `TC-DETAIL-*` in place off
a product-derived id; the hover row now gets the same treatment, so a host seeded at 1.5.0
or 1.6.0 is updated rather than given a second set. The gallery row needs no new statement:
it is DERIVED from the master's own default by stripping the `-<nnnn>` index, and `-0042.png`
is the same nine characters `-0042.svg` was.

**Two new guards, and neither weakens one that existed.** `truvio-images.sql` fails if any
`TC-DETAIL-*` or `TC-HOVER-*` row still carries an `.svg`; `truvio-pdp.sql` fails if any
unstamped `TC-GAL-*` row does. Every guard already in those files - attach count, hover
count, shared defaults, masters without a second image, foreign-band gallery, uncategorised
images, thin galleries, same-shot galleries - was **green** through the whole 1.2.0 to 1.6.0
window this defect ran, which is the reason to add a guard that asks the one question they
could not.

`.gitattributes` gains `*.png binary` beside the `*.svg -text` pin, so a regeneration check
measures the generator on either kind of file.

The `GetImage.ashx` 200 proof on the new `.png` paths rides the next restage: this change
writes no host.

### truvio-demo 1.6.0

#### The gallery row is derived from its own master, not assigned (Foundry #1137)

#1157 gave every master its own pair and the retest found the residual: of the 276 rows in
asset category `Images`, 192 pointed at a per-product picture and **84 still pointed at
another band's concept tile** - `TC-GAL-TCPROD0042-2`, a Bundles master, pointing at
`tc-tile-price-structures.svg`.

The rekey did not reach them because they were never keyed on the product. The gallery row
was a fixed literal drawn from a twelve-tile ring by seed position, and the anti-repeat
pass beneath it picked *the first tile this master does not already carry* - an ordering
over the ring, not a fact about the product. And the row it produced named a picture that
is shipped, categorised, correctly sorted and served 200, so the path guard, the row count,
the scenic-residue guard and the 404 check were **all green** while the page put a
Price-structures illustration on a kit.

**Derived, not assigned.** Every master owns `tc-tile-<band>-<nnnn>.svg` as its default and
`tc-detail-<band>-<nnnn>.svg` as its hover, and the band and the index are both readable
off the default row. Strip the `-<nnnn>` index off the default's filename and what remains
is that master's own band concept tile:

| row | value | sort |
|---|---|---:|
| `TC-DETAIL-TCPROD0042` | `.../products/tc-tile-bundles-0042.svg` | 0 |
| `TC-HOVER-TCPROD0042` | `.../products/tc-detail-bundles-0042.svg` | 1 |
| `TC-GAL-TCPROD0042-2` | `.../products/tc-tile-bundles.svg` | 2 |

No per-product literal, no ring, no position. The only band a row can name is its own, and
the 60 rows converge in place on a seeded host.

**Three pictures is the ceiling**, so the second gallery row is retired rather than
repointed. The layer ships two generated pictures per master plus twelve band tiles; a
fourth slide could only repeat one of the three, and a strip that steps from an image to
itself is what the distinctness guard already forbids. The 24 `TC-GAL-*-3` literals leave
the seed and a scoped `DELETE` retires them on a host that carries them. **84 gallery rows
become 60**, one per master.

**Guards.** A new band guard counts unstamped gallery rows that do not equal the tile
derived from their own master's default - it must be 0, and it is the only check here that
could have seen this state. The distinctness guard moves from *fewer than 2 distinct
pictures* to *fewer than 3*, which is the real floor now. The Images-category floor moves
84 -> 60. `expectedRows.EcomDetails` 396 -> 372.

#### The trees are declared, the tiles are eol-insensitive, the PDP link carries both ids (Foundry #1167, #1157)

`layer.json` gains `repositories: []` and `itemtypes: []` - both empty and both deliberate,
because an empty array states positively that this layer stages neither tree, which the
gate now treats as a different claim from an absent key. This layer's whole staging surface
is its 140 `files[]` paths, and it is now derivable from the manifest.

A root `.gitattributes` marks `*.svg -text`. The #1157 retest diffed a fresh `make-tiles.py`
run and got **120 of 120 DIFFERENT** against the working tree and **120 of 120 IDENTICAL**
against the committed blobs - a line-ending delta alone (`core.autocrlf=true`, no
`.gitattributes`, CRLF 1124 B in the tree against LF 1113 B in the blob). The generator was
deterministic throughout; the checkout was what moved.

And the README's PDP flow now records that `/en-us/shop?ProductID=...` **404s** on its own
for a bundle master: the shop page resolves a product through its group context, so every
demo link carries `GroupID` and `ProductID` together.

#### Consumer impact

SQL only, all of it converging. A host on 1.5.x is brought to this state by re-running
`truvio-pdp.sql` - 60 rows updated in place, 24 deleted. No Replace, no restage.

### truvio-demo 1.5.1

#### The short descriptions stop sharing a stem, and a guard stops them starting again (Foundry #1158)

The census measured one templated sentence per subgroup: 60 `ProductShortDescription`
values, the component rendering on 5 of 5 PLP rows, every presence assert green, and five
neighbouring cards differing only by a trailing index on the one surface a buyer scans in
order to tell products apart. 1.3.0 replaced the template with sixty written sentences and
closed most of that. What it did not close is what this release measures:

- three sentences ran to **17 words** (`TCPROD0001`, `0003`, `0010`), past the band where
  a PLP cell reads without truncating;
- seven bands opened two or three of their five sentences on the **same stem** - three
  "Priced per" in Units, three "Related to" in Relations, two "Datasheet" in Documents, and
  four bands repeating an article. Five cards that all begin with the same two words scan
  as one card however different their endings are;
- and **nothing asserted any of it**. The file counted no descriptions at all.

Fifteen sentences are rewritten - the three over-length ones trimmed, twelve re-opened on a
distinct stem - and all sixty now sit at 8 to 16 words with sixty distinct values and no
two in a band sharing their first three words. The rewrites are converging `UPDATE`s like
every other row in this file: the predicate names the OLD text, so a host seeded at 1.5.0
moves to the new sentence and a host that never had the old one is untouched.

TWO GUARDS are added at the end of section 1, and both judge what the page would show:

| guard | what it catches |
|---|---|
| `@TcTemplatedBands > 0` | a band whose distinct description count is below its product count - **the state #1158 names**, and the one a row count reads as perfect |
| `@TcEmptyDescriptions > 0` | a master with no description at all, which satisfies the distinctness test exactly once per band and paints an empty component |

No data shape changes: 60 rows before, 60 after. `truvio-b2b.sql` passes `SET PARSEONLY`
on SQL Server 2022.

### truvio-demo 1.5.0

#### Every product gets its own picture, and a second one to hover onto (Foundry #1157)

Measured on the composed host: all five PLP rows carried an image component, so the row
was at parity with marine, and the subject was not. Every card on the site showed a flat
concept tile named for its subgroup - `tc-tile-variants.svg` on all of `TCGRP-VARIANTS`,
`tc-tile-documents.svg` on all of `TCGRP-DOCUMENTS` - seventeen tiles over ninety-six
products, five or six products per tile. `TCPROD0001` carried seven `EcomDetails` rows of
the same file. And no product nominated a second image at all, so the hover swap the card
component is configured for had no subject: `ShowAlternativeImageOnHover` true, and
nothing to swap to.

Marine shows a real photograph per product with a 640/1280 webp srcset and a hover swap.
This layer cannot ship photographs - a data layer references no asset outside its own
`files[]`, and the scenic set is a brand-time fetch. What it can ship is a picture that is
actually about one product.

**120 new SVGs**, two per master, generated by the new `tools/make-tiles.py`:
`tc-tile-<concept>-<nnnn>.svg` is the default image and `tc-detail-<concept>-<nnnn>.svg`
is the second. `<nnnn>` is the master's own TCPROD index, so a file name traces to a
product without a lookup and two products in a band cannot share a path by accident.

**The differentiator is geometric, because the old one was typographic.** A PLP card paints
the tile at 120px; a concept word set at 34px in a 480-unit box arrives there around eight
pixels tall, which is exactly why twelve tiles that differed only in their wording read as
one tile. Each tile now carries a two-digit numeral filling a third of the panel, a pip row
whose COUNT is the product's position in its band, a corner mark turned per position, and a
hue per band. The detail image is the same product in the other register - light panel on a
dark ground, marks enlarged - so a hover reads as a second look at one product and never as
a second product. Self-contained: no `<image>`, no font file, no CSS, no script.

The twelve concept tiles STAY. `truvio-pdp.sql`'s gallery strip still draws them, and a
picture a product does not own is what a strip is for. `files[]` goes 20 -> 140.

**The hover row sorts at 1, and that is load-bearing.**
`Swift-v2_ProductDefaultImage.cshtml` builds its alternative by filtering
`product.AssetCategories` to the one category the paragraph's `GetAlternativeImageFrom`
radio names (`Images`), removing the default image from what that yields, and taking the
FIRST of what is left. So the second image must be in the Images asset category -
`truvio-pdp.sql`'s path-scoped `UPDATE` puts it there, which is why `truvio-images.sql`
still does not name the category - and it must sort ahead of the gallery rows at 2 and 3.
Default 0, hover 1, gallery 2 and 3. The `DetailSortOrder` probe is new beside the existing
`DetailSorting` one: 1.4.0 probed only the name this platform build does not have, so its
default rows landed with no sort order at all.

`#TcTile` is keyed on `ProductId` rather than on a group id, and variant rows join it on
`ProductId`, so a combination inherits its master's pair - which is what a variant should
show: the same product in another configuration. The `TC-DETAIL-*` ids are derived from the
product key and therefore unchanged, so a host seeded at 1.4.0 is CONVERGED in place by a
targeted `UPDATE` rather than given a second set of rows beside the first. The new hover
rows take `TC-HOVER-*`.

FOUR MEASURED GUARDS replace one, and all four judge the end state rather than the insert
count, which is legitimately 0 on a re-run:

| guard | what it catches |
|---|---|
| `@attached = 0` | nothing carries a tile - the pre-1.0 empty-grey-box failure |
| `@hoverRows = 0` | no product has a second image; the hover swaps to nothing, silently |
| `@TcSharedDefaults > 0` | two products in one group share a default image - **the 1.4.0 state**, which no row count could see: 96 rows over 12 pictures counts exactly as well as 96 over 96 |
| `@TcMastersWithoutSecond > 0` | a master with fewer than two distinct images |

The sharing guard is scoped to masters (`DetailVariantId = ''`), because variant rows
legitimately share their master's tile.

`expectedRows.EcomDetails` 300 -> 396: the 96 hover rows are the whole of the difference.

### truvio-demo 1.4.0

Six data defects from the v5 round-two census, and every one of them was green on
some count while the page it fills showed nothing.

#### The images join an asset category (Foundry #1145)

Swift's ProductMedia component reads the ASSET CATEGORIES its paragraph names and
then the rows that belong to them. `EcomDetailsGroup` held one row on the composed
host - `Manuals`, which this layer creates for its pdf rows - and all 180 image rows
carried `DetailsGroupId NULL`. Not one image in the database belonged to any asset
category, so no category-filtered component could have seen them whatever the
paragraph named.

`truvio-pdp.sql` now creates the `Images` category and puts every image row this
layer owns into it. The column set is marine-demo's own `Images` row read off this
SQL instance rather than guessed - InheritanceType 1, ControlType 0,
IsSystemGroup 1, HasPrimaryImageRule 1 - with one stated deviation: the extension
list gains `svg` and `webp`, because this layer's tiles are SVG and two of the five
brand photographs are WebP. The rows are assigned by PATH, so the default-image rows
`truvio-images.sql` writes and the gallery rows this file writes are both covered by
one statement; the pdf rows live under `/Files/Documents/` and stay with `Manuals`
without being named. The guard asserts what the page needs - zero image rows outside
the category - rather than a row count, which is what measured green over 180 rows
in no category at all.

surface-swift 1.10.0 is the other half: it names `Images` and nothing else.

#### The gallery converges instead of skipping (Foundry #1137)

The 1.3.0 tile repoint was insert-only. Every gallery row is guarded
`IF NOT EXISTS` on `DetailId`, and the DetailIds did not change between 26bb0a06 and
4a4cd05b - only `DetailValue` did - so a host seeded at 1.2.0 already had all 84 rows
and nothing was written. Measured there: 45 + 24 + 15 = **84 scenic gallery rows and
zero tile gallery rows**, while the script closed with "all of them concept tiles this
layer ships" and exit 0, because the resolution guard accepted both prefixes.

Each of the 84 rows now carries an `ELSE` beside its `INSERT` that converges
`DetailValue` onto the shipped value, and a new guard fails on a scenic path with no
opt-in stamp.

**The stamp.** `tools/truvio-gallery-photos.sql` stamps every row it swaps
`DetailsName = 'brand-photograph'`, and the convergence skips a stamped row, so a
Replace cannot silently undo a swap a brand step chose to make. The stamp is the only
thing that can distinguish the two states - 1.2.0's residue and the opt-in's result
point at the same five files - which is also why the opt-in's own "rows swapped > 0"
guard was green on a run that swapped nothing. It counts stamped rows now. Its header
is corrected too: the "what the default is without it" paragraph described 1.3.0's
seed and was false of exactly the hosts it was most likely to run against.

#### The spec group proves it is complete (Foundry #1147)

`EcomFieldDisplayGroups` id 14 carried six names in `FieldDisplayGroupFieldIds`
against 28 members in `EcomFieldDisplayGroupFields`, and the sixth name -
`ProductCategory|tc_content|tcMedia` - is not a field on any host; the real system
name is `tcMediaSet`. The seed already derives both stores from
`EcomProductCategoryField`, so it cannot type a name; what it could not do was notice
that a host disagreed with it.

Four guards, each naming its own numbers: the relation holds every `tc_*` category
field; it holds every one of them PER CATEGORY (a missing category is invisible on
three products in four, because each product carries values in exactly one); every
name in the denormalised column resolves to a live category field - the assertion
that would have caught `tcMedia`; and the column's element count equals the
relation's. The existing resolution guard still runs last: completeness is not
resolution.

#### The Bundles band owns kits that have contents (Foundry #1161)

`EcomProductItems` held four rows in the whole database - two on TCPROD0021, two on
sample-data's PACK-BOM-0001 - and every product in `TCGRP-BUNDLES` owned zero. With
the ProductBom component now present on the PDP, the Package contents section
rendered a visible heading over zero rows.

TCPROD0042-0045 become real BOM parents with two slots each, in the shape TC-BOM-0001
and TC-BOM-0002 already prove: each slot binds a GROUP and names a default child,
which is what makes the configurator a picker. The slots reach the products the demo
path visits - a Variants component into `TCGRP-VARIANTS`, a Documentation component
into `TCGRP-DOCUMENTS`, where TCPROD0051 lives. TCPROD0041 is left alone: it is a
variant master, and variant-master-plus-BOM-parent is a shape this catalogue does not
claim and the gate has never proven.

**The band stays empty on TCPROD0001 and TCPROD0051.** Neither is a kit, and giving a
variant master BOM rows to make a section non-empty would be seeding for the assert
rather than for the demo.

#### Every master carries a list price (Foundry #1150)

TCPROD0001 carried 16 `EcomPrices` rows and not one master-level quantity-1 row with
`PriceUserGroupId` NULL; TCPROD0051 the same sixteen and the same gap.
`ProductDefaultVariantComboId` is NULL on every product, so the PDP resolves to the
MASTER and looked up a row shape only ever written for the children. Both of the
demo's price stories were therefore unreachable from the products it points at.
`EcomProducts.ProductPrice` is not that row - it is a field on the product, not a
price the engine resolves.

Rung one of the ladder now exists on every master, read from `ProductPrice` rather
than typed, with a converging UPDATE if it drifts. The quantity breaks at 5, 10 and
25 were rungs two, three and four of a ladder that began part way up. Contract rows
at TC-100200 land on TCPROD0001 and TCPROD0051 - the products the design profile and
the PDP pointer name - beside the five the layer already had. `EcomCurrencies` is
untouched: EUR rate 100 IsDefault 1 is correct here.

#### The selector guard says what it measured (Foundry #1133)

#1133 is fixed and verified; the census recorded that its subject is EXACTLY six
against a threshold of six, so the margin is zero. The RAISERROR now builds its
message with the measured count in it and states that six is the whole catalogue,
so a 5 reads as one master that lost an axis rather than as an unmet quota.

### truvio-demo 1.3.0

Three defects the round-two e2e measured on a PRISTINE host, every one of them invisible
to the row counts this layer ships (`costHints.expectedRows` matched exactly while all
three were live).

#### The taxonomy is seeded under its final names (Foundry #1134)

1.2.0 re-screened eight subgroup names in the section-0 **converge** block only - a
guarded `UPDATE` for a host already seeded under the retired taxonomy. On a clean install
there is nothing to converge, the predicate is false, and the `INSERT` literals below it
still carried `Item Types`, `Groups`, `Paragraphs`, `Permissions`, `Pages`,
`Impersonation`, `Completeness` and `Workflows` - the exact eight words the 1.2.0 entry
says were retired, reaching the shop navigation and the PLP facet rail.

The final `GroupName` is now in the `INSERT` literal, which is the only place a clean
install reads. The section-0 `UPDATE` stays, unchanged, as the converge path for seeded
hosts: a rename must never be the ONLY place the final name appears. A new taxonomy guard
after the group section joins all twelve subgroup ids against their final names and
`RAISERROR`s with the offending `GroupId=GroupName` pairs, so the next drift names itself
instead of counting sixteen rows and passing.

#### The gallery points at pictures this layer ships (Foundry #1137)

All 84 gallery rows pointed at five photographs under `Images/TruvioCommerce/scenic/` -
artefacts of the previous round's brand pass, which had happened to leave them in that
host's `Files` tree. No layer ships them, so a clean install seeded a gallery of 404s, and
the `@TcThinGalleries` guard passed because it counted `EcomDetails` ROWS.

The committed default is now self-contained: every gallery row points at one of the twelve
concept tiles in this layer's own `files/`, with a converging `UPDATE` that moves any row
colliding with its master's default tile onto the first tile that master does not already
carry, so no strip steps from an image to itself. The guard asserts the PATH now - a
gallery row outside `products/` (shipped) or `scenic/` (brand-manifest, brand-step) is a
loud failure - and a second guard asserts the pictures in a strip are distinct.

The photographs remain available as an opt-in: `tools/truvio-gallery-photos.sql` swaps the
gallery onto the five `scenic/` targets `brand/brand-assets.manifest.json` declares, to be
run by hand AFTER a brand step has put them on disk. It is under `tools/` and deliberately
NOT in `layer.json` `sql[]`, because a declared script is one the composer runs and this
one would re-seed 84 404s on any host that skipped the brand step. SQL cannot test for a
file on disk, so that gate is a human step; the README carries the four-line sequence.

#### The variant selector guard runs after the rows it asserts (Foundry #1133)

`truvio-catalog.sql`'s selector guard sat between the axis relations and the OPTION
relations it measures, so on a pristine database it read an empty
`EcomVariantOptionsProductRelation`, raised severity 16, and - because a severity-16
`RAISERROR` does not abort the batch - the script carried on, seeded the options, and
printed its own success line on the same run that had just reported failure. Under
`sqlcmd -b` that is exit 1 on a first run and exit 0 on every re-run, which is why it had
never been seen. The guard is moved verbatim to the end of the variant section, after the
last option relation and the last combination row. The assertion itself is unchanged; it
was always the right assertion, in the wrong place.

### truvio-demo 1.2.0

Density parity, data half (V5-PLAN round two, items 1-4), against the measured parity
report `parity-gaps.md` (2026-09-13): marine's PLP row and flagship PDP compared
element-for-element with truvio's, and the owner's filter made binding on the result -
**an example ships only if Swift shows it.**

#### The taxonomy is re-screened (report section 3, "Backend-only taxonomy")

Eight of the twelve subgroups named a concept with no storefront surface at all. The
report's own table proposed the replacements and they are taken, with two of its
alternatives chosen for the Pages/Paragraphs pair:

| Retired | Replaced by | What draws it |
|---|---|---|
| Workflows | **Units & Measures** | the unit selector on add-to-cart |
| Completeness | **Stock & Delivery** | the stock count, status and delivery line |
| Permissions | **Documents** | the documents table |
| Impersonation | **Relations** | the related-products strip |
| Item Types | **Bundles & BOM** | the package-contents list |
| Pages | **Media & Galleries** | the gallery and its thumbnails |
| Paragraphs | **Currencies & VAT** | the figure itself |
| Groups | **Contract Pricing** | your price against list |

`Variants`, `Price Structures`, `Discounts` and `Assortments` are unchanged - all four
were already showable. Twelve total, three under each of the four top groups, which took
six bands re-homing so each top keeps 15 products and every child reads under its parent.

Concept tokens, SKUs, names and concept tiles follow the group, and so do the order-line
snapshots: a demo order history citing `TC-CMP-0007` against a catalogue that no longer
has that number is a broken page. D-B is untouched - every new name is still PIM,
Commerce or CMS vocabulary, never a real product domain.

The 28 category fields were re-screened by the same filter. `Completeness Score` was the
report's named example - an enrichment metric rendered as a shopper-facing spec row - and
it is gone with `Workflow State`, `Permission Grant`, `Impersonation Scope` and the rest.
What replaces them is what a buyer reads: unit of measure, pack quantity, net weight,
dimensions, material class, rating, compatibility, and commercial terms named from
commerce vocabulary.

A new section 0 runs first and converges a host seeded under the retired taxonomy:
renames in place across the five tables a GroupId reaches, rather than inserting a second
taxonomy beside the first. The category values are rebuilt rather than patched - after a
re-screen a value can be stale three ways at once, and reconciling them one at a time
left four survivors on the first measured pass.

#### The row carries B2B information, richer than marine's (report section 1)

The report found marine's signed-in half **faked**: 22 `EcomPrices` rows, none with a
user group, no dealer discount rows anywhere, the anonymous GA4 payload already carrying
the figure the signed-in dealer sees. `truvio-b2b.sql` makes it data.

- 60 short descriptions, one sentence each, every one distinct.
- 60 stock positions on a five-step profile - healthy, low, zero-but-orderable against a
  date the row carries, mid, deep - with 60 matching stock-unit rows on the default
  location. SHOP1 carries `ShopStockLocationID = 0`, so the storefront reads the
  product-level number and these are the breakdown a multi-warehouse demo switches on,
  summing to exactly the same figure so the two can never disagree.
- **96 real `PriceUserGroupId` prices** scoped to the group the buyer persona belongs to:
  60 masters and all 36 variant combinations, because a tier change that threw the buyer
  back to list price reads as a bug. Four in five discount and the fifth is at list on
  purpose, so the demo has a control. Every amount is derived from the row's own list
  price rather than typed.
- 30 quantity-break rows - a three-step ladder on all six variant masters and all five
  Price Structures masters - where 1.1.x shipped one ladder on one product.
- 5 new contract prices on `TC-100200` beside the one already there, which is kept: the
  band named for the mechanism demonstrated none of it.

#### The detail page is filled (report section 2)

The report counted marine's flagship PDP at 21 sections and truvio's at 8, four empty, the page
measuring 84 characters of main text. `truvio-pdp.sql` supplies the data half:

- **Gallery**, 2 to 4 images per master: the concept tile plus the photographic frame its
  top group is branded with, plus a detail shot on two rows in five. The photographic
  targets are the Distribution's own `brand/brand-assets.manifest.json` entries by their
  `target` path - fetched at brand time, never committed - so a solution that has not run
  its brand step shows the tile alone rather than a broken page.
- **Documents** as the platform shape the report names: one `Manuals` `EcomDetailsGroup`
  (extensions `pdf`, `InheritanceType 3`, `ControlType 0`) with 120 `EcomDetails` rows,
  which is what `Swift-v2_ProductMediaTable` binds to when configured
  `ImageAssets=["Manuals"]`. Those three column values are read off a live DW 10 solution
  carrying a working group rather than guessed - a NULL `ControlType`/`InheritanceType`
  there is the silent failure the report records - and a host already carrying the
  half-made group is converged.
- **Eight one-page PDFs** in `files/Documents/TruvioCommerce/`, a datasheet and an install
  guide per top group, generated by `tools/make-documents.py` and about a kilobyte each
  because the base-14 Helvetica face embeds nothing. The generator is byte-deterministic,
  so regenerating what is committed shows no diff.
- **324 relations** in three groups. Related products gives every master the other three
  rows in its band; Accessories gives it the same slot in the two sibling bands under its
  top group; Spare parts carries the kit story both ways, because a relation that reads
  from one end only is half a demo. Marine's own "you'll also need" strip is an empty div
  under a stranded head; every master here shows between five and eight.
- **Specification density to seven of seven** on every page, 240 more values.

#### The variant selector had no axes to draw (report section 3)

The report found it empty even signed in, on the product whose own Overview copy tells the
reader to open it, with every count correct and nothing erroring. Diagnosed on the live
host: `EcomVariantGroupProductRelation` held **zero rows**, for this layer and for the
whole database. That table answers the selector's first question - which axes does this
product use. The option relations answer which values on an axis a product offers; the
combination rows answer what each intersection costs. Neither answers the first, and with
no answer the control draws nothing. `ProductVariantGroupCounter = 0` on every master was
the same fact stated a second way.

Twelve rows fix it, and they go into section 4 beside the variant data they complete. The
id column is a NOT NULL nvarchar key rather than an identity, measured off `sys.columns`;
the counters are derived from the rows rather than typed.

#### Guards, not row counts

Every new section ends in a **resolution guard** that asserts what the PAGE needs, because
a row count was green throughout the period the spec band, the selector and the signed-in
price were each silently empty. Masters priced below list for the persona; two images, two
documents, two relations and exactly seven specification values per master; and six
variant masters each binding two axes that offer at least two options the master carries.

#### Currency: already fixed, and verified

The report's closing defect (`$4,500.00` where `$45.00` belongs) was real at the step-7
capture and is **already closed** by 1.1.1's section 8, which moves every currency row
still at the placeholder rate 1 to 100. Verified on the live host this round:
`EcomCurrencies` reads `USD 100` and `EUR 100 (default)`, with the eight other enabled
currencies at their own real rates. No change was made here; the report cites pre-fix
evidence.

Proven on `dwsalesweb\SQL2022` / `foundry.mydwsite4.com` with all four scripts applied in
order inside a single rolled-back transaction. Nothing on the live host was modified.

### truvio-demo 1.1.1

**The spec group existed, was flagged for the frontend, carried 28 members — and resolved to
nothing.** 1.1.0 closed the missing-half finding by seeding `EcomFieldDisplayGroups.tc_specs`
and 28 relation rows, and the closing v5 measurement on DW 10.28.10 found the band rendering a
heading over an empty `.table-responsive`: `1408 × 52`, `dw-error` 0, every row count in the
database correct. `GetProductDisplayGroupFieldsByGroupSystemNames(["tc_specs"])` returned no
fields at all.

The cause is the member NAME. A display-group member is not a field id, it is a *reference* to a
field, and the two field families are referenced differently. A **global** product field
(`EcomProductField`, which also owns its own column on `EcomProducts`) is referenced bare, by
system name. A **category** field is referenced in a qualified, pipe-delimited form:

```
ProductCategory|<FieldCategoryId>|<FieldId>
```

1.1.0 wrote the bare `EcomProductCategoryField.FieldId`, which sends the resolver at
`EcomProductField` — empty on the e2e host, and empty on any host this layer composes, because
this layer ships category fields and no global ones. Nothing matched, and nothing said so.

The form was not guessed. It was read off six unrelated DW 10 solutions on the same SQL instance,
every one of which uses it and no other prefix: `marine-demo` 65 of 65 member rows,
`momar` 1264, `burco` 121, `gerflor` 111, `dw10-demo` 91, `sapporo` 91. In `dw10-demo`, 75 of the
91 qualified names join cleanly to a live `EcomProductCategoryField` row and **zero** bare names
do. `burco`, the one solution that also fills the denormalised `FieldDisplayGroupFieldIds`
column, fills it with the same qualified names, comma-joined — most solutions leave that column
`NULL`, which is the second half of the same lesson: the relation table is what resolves, the
denormalised list is a convenience beside it.

Then it was proved on the host rather than argued. Group 18's 28 members were rewritten to the
qualified form, the pool recycled, and the same PDP fetched anonymously: `dw-error` 0 and a
populated table — *Facet: Group*, *Variant Axis: Tier*, *Completeness Score: 40* — where the
identical request had rendered an empty `<tbody>`. Three rows because `TCPROD0001` carries three
of its category's seven values; a product carries what section 7 gave it, and the band shows
exactly that.

Two earlier hypotheses are recorded as disproven, because a reader will have them too: binding
the group to `SHOP1` through `EcomFieldDisplayGroupShops` (probe W-E — `dw10-demo` binds 8 of its
13 groups and leaves 5 unbound, so the binding is not what gates resolution), and a dot-qualified
`tc_data_models.tcFacet` (probe W-F — the separator is a pipe and the `ProductCategory` segment
is not optional). Both left the table empty and both were reverted.

**The 7c guard now asserts that the group RESOLVES, not that its columns exist.** The shape guard
introduced in 1.1.0 checks `sys.columns` and it was green on the run that shipped an empty band —
column shape was never the thing that was wrong, and a guard that can only pass is not a guard.
The new one counts values reached along the platform's own join path, member name →
`EcomProductCategoryField` → `EcomProductCategoryFieldValue` on a `TCPROD%` product, and raises
severity 16 at zero. Measured both ways on the host inside a rolled-back transaction: **180**
resolving values with the qualified names, **0** with the bare names 1.1.0 shipped. It would have
failed the 1.1.0 apply.

**A host seeded by 1.1.0 converges rather than doubling.** The INSERT is guarded on the qualified
name, so a re-run on a 1.1.0 host would otherwise leave 56 rows of which 28 resolve. The section
now rewrites each bare member to its qualified form in place and deletes any bare row left over,
then rebuilds the denormalised list from the relation as before. Exercised on the e2e host in a
rolled-back transaction: 28 bare → 28 qualified, total unchanged at 28, guard green at 180.

These fixes are authored against measured schema and worked-around host state; their rendered
proof on a clean deserialize is one re-run away.

### truvio-demo 1.1.0

Four measurements from the v5 end-to-end session on DW 10.28.10, each one a thing the
layer claimed and did not do.

**The reassignment seeded but never repaired.** 1.0.1 moved all twelve orders onto the
buyer, and the host still measured 8 on the buyer, 3 on the CSR and 1 on the admin after a
clean re-run: every order insert in `truvio-identities.sql` is `IF NOT EXISTS`-guarded, so on
a host seeded by 1.0.0 not one of the twelve was written and nothing else touched them. The
buyer's *My orders* rendered 8 of 12. New section 4 states the reassignment a second time as
an existence-guarded UPDATE over the whole `TCO-%` range, covering the customer identity block
as a unit - the access-user id the my-orders scope filters on, and the customer number, name
and email the order grids and the receipt render. Guarded on the rows that DIFFER, so a
converged host is not written to. Applied against the e2e host inside a rolled-back
transaction: 8/3/1 before, 12/0/0 after.

**The rate fix moved the wrong currency.** 1.0.1 moved the DEFAULT currency to rate 100 and
the e2e measured the hundredfold intact and merely relabelled: the storefront serves USD,
whose rate was still 1, so a stored 45.00 rendered as `$4,500.00`. The guard now reads the
placeholder rate rather than the default flag - every currency row still at 1 moves to 100.
Measured on the host, only USD is at 1; EUR is at 100 and the other eight (HUF 2, DKK 15,
CZK 29, GBP 86, HRK 99, RON 150, PLN 163, BGN 380) already carry real rates relative to the
default and are left alone, which is why the guard is `= 1` and not `<> 100`. USD becoming
1:1 with EUR is deliberate demo semantics, stated in the script: the catalogue carries one
set of round numbers and they stay readable on the currency the storefront actually serves,
and inventing an FX rate would put wrong money on a prospect's screen. The durable home is
still the base layer's currency seed.

**No product had a long description, so the PDP had no body.** The detail page carries a
full-width Overview band and it rendered at height 0 on every product; the probe measured the
whole PDP collapsing to 84 characters of main text. New section 7b gives all 60 masters two or
three sentences in the same platform-vocabulary voice the names use - what the concept is,
what that row demonstrates, what a prospect can do with it on the page - in
`EcomProducts.ProductLongDescription`, guarded on absence so an edited copy survives and a
1.0.x host is filled. Variant rows inherit the master's body.

**The spec table had nothing to bind to.** The PDP spec paragraph does not name a product
category: Swift's `Swift-v2_ProductFieldDisplayGroups` takes field-display-group system names,
resolved against `EcomFieldDisplayGroups`. This layer shipped 28 category fields and 180 values
and no display group, which is why `surface-swift` 1.5.0 removed the band as permanently empty
and why the e2e found no spec element on the page at all. New section 7c seeds the `tc_specs`
group, its translation and a relation row per `tc_*` category field, derived from the fields
themselves so the two lists cannot disagree; `surface-swift` 1.7.0 brings the band back and
names it. Column names read off `sys.columns` on the 10.28.10 host in this file's own
discipline - `FieldDisplayGroupId` is an `INT IDENTITY`, so the group is addressed by system
name everywhere and the id is looked up. The denormalised `FieldDisplayGroupFieldIds` column is
written from the relation with `STRING_AGG` rather than the `FOR XML` idiom, because the XML
`value()` method needs `QUOTED_IDENTIFIER ON` and `sqlcmd` runs these scripts with it off - the
`FOR XML` form fails Msg 1934 on a real apply, measured.

The whole amended `truvio-catalog.sql` was applied to the e2e host inside a rolled-back
transaction: clean compile, 60 long descriptions written, 28 display-group relations, USD moved
to 100, nothing left behind.

### truvio-demo 1.0.1

Everything below was measured on a live DW 10.28.10 host (SQL Server) during the Foundry v5
end-to-end session. Nothing here is a design change; it is the layer doing what 1.0.0 said
it did.

**Three scripts did not compile.** `truvio-catalog.sql` addressed `EcomPrices.PriceVariantId`
(the column is `PriceProductVariantId`) and wrote the category fields as `FieldTypeId` /
`FieldSort` / `FieldLocked` (the columns are `FieldType` / `FieldSortOrder`, there is no
locked column, and `FieldTemplateTag` is `NOT NULL` and was never supplied). The platform
writes `FieldTemplateTag` as the field's own system name verbatim — `FieldTemplateTag` =
`FieldId` on every row of every reference seed measured — so the inserts now supply it.
`truvio-images.sql` addressed `EcomDetails.DetailProductVariantId`; the column is
`DetailVariantId`. Each of these is a compile-time Msg 207, which is why the scripts' own
`COL_LENGTH` shape guards — a runtime check — never fired; the guards now assert the real
column names.

**`truvio-images.sql` claimed success unconditionally.** Its tail PRINTed a fixed line
naming 12 tiles and 96 rows whether or not a row moved. It now reports the measured
`@@ROWCOUNT` of each write plus the attached total, and raises with a rollback when the
attached total is zero. The attached total, not the insert count, is the assertion: the
attach is idempotent, so 0 inserted on a re-run is correct and 0 attached never is.

**Four of the twelve orders were invisible.** The customer-centre page grants group `1325`
and the *My orders* scope and nothing else, so the orders stamped with the CSR (`100102`)
or the admin (`100103`) reached no persona that can open the page — the order list rendered
eight of twelve. All twelve now carry the buyer (`100101`). CSR and admin reach a buyer's
orders through impersonation, the platform's own path, rather than through widened page
grants; the layer README states this.

**60.00 EUR rendered as 6000.00 USD.** `EcomCurrencies.CurrencyRate` is hundredths and the
platform's own seed ships the default currency at `100`; the host carried `1`.
`truvio-catalog.sql` now ships an existence-guarded UPDATE setting the default currency's
rate to 100. This is a stopgap in the right place for now and the wrong place forever: the
durable home is the base layer's currency seed, queued for the next base release.

### truvio-demo 1.0.0

The first release of the **Truvio Commerce brand data** as its own layer (V5-PLAN §2.4,
decisions **D-B** and **D-D**).

Until now an edition had exactly one place to put demo rows, and it was the layer the gate
uses for its own fixtures. That forced a choice nobody wants to make: either the marker
strings the design gate scans for (`Placeholder …`, the `FIXT*` keys, the RMA order) live
inside the catalogue a prospect is shown, or the brand catalogue displaces the fixtures the
gate asserts on. `truvio-demo` ends the choice. It is a second layer of kind `sample-data`
— no new kind was invented, per D-D — and the two key families are disjoint by
construction: `FIXT*` / `PACK-*` there, `TC*` here. `swift-demo` composes both;
`base-swift` composes neither.

**The naming rule is the substance of the layer.** No real-world product domain appears
anywhere. Four top groups (`Data Models`, `Commerce`, `Content`, `Users`) each carry three
subgroups named from platform vocabulary, the 60 masters read `Truvio <Concept> <Unit>
<NN>` against SKU `TC-<CONCEPT>-<nnnn>`, and the variant axes are `Tier` and `Mode` rather
than `Size` and `Finish`, which are worldly. The 28 category fields are `Facet`, `Variant
Axis`, `Completeness Score`, `Price Matrix`, `Grid Row`, `Permission Grant` and their kin.
The result is a catalogue that doubles as a platform-terminology tour and cannot be
mistaken for a real business — which is the point: demo data that reads as a plausible
supply house is demo data someone eventually ships to a customer by accident.

**What lands** (`merge/_sql/`, all three scripts declared in `layer.json` `sql[]`, phases
and orders after `sample-data`'s):

- `truvio-catalog.sql` — 16 groups (4 top + 12 sub), 60 masters + 36 variant combination
  rows, 40 prices, 1 BOM kit with two group-bound slots, 2 services, a three-step quantity
  ladder, one contract price scoped by customer number, 4 product categories × 7 category
  fields, 180 field values.
- `truvio-identities.sql` — the B2B account, three personas on the fictional
  `truvio-demo` domain, 6 memberships, 12 orders with 20 lines.
- `truvio-images.sql` — the 12 concept tiles attached as the default image of all 96
  product rows.

**Four decisions worth keeping in view.**

Every variant combination carries its **own** `EcomPrices` row. A variant with no price row
inherits the master's, and the whole tier ladder then reads as one price on the PDP — the
axis renders, the selector works, and nothing changes when you use it.

The identities script runs `after-replace-deserialize` rather than `before-host-start`,
where `sample-data`'s identities live, because its orders FK the shop, currency and
catalogue rows. DW caches identity state at startup, so the personas become first-class on
the host restart the catalogue already requires — one restart covers all three scripts.

The orders use only `OrderFlowId 1` states (`OS1 New`, `OS2 Completed`, `OS3 Rejected`).
`OS12`/`OS13`/`OS14` belong to flow 4, and an order carrying a state from another flow
reads as a broken record in every Commerce grid.

Imagery is attached through `EcomDetails` with the column list resolved from `sys.columns`,
and mirrored onto the legacy `EcomProducts.ProductImage*` columns where a build still has
them. The optional detail columns differ across platform builds, and an `INSERT` naming a
column the build lacks takes the whole script down. A missing `EcomDetails` table raises
rather than skips: a demo that seeds no image and reports success is the failure the file
exists to prevent.

Every insert is `IF NOT EXISTS`-guarded on its own key, so a re-run converges. Nothing in
this layer deletes.
