# sample-data (kind: sample-data)

The one-shot **fully functioning demo shop**: the catalogue, the identities, the orders and
the storefront copy that make a freshly composed Dynamicweb 10 site look and behave like a
real Truvio Commerce store the moment it comes up. It is one layer, and it is the whole demo
dataset — an agent rebrands it in place rather than assembling one.

**Activated by `sampleData: true`** in an edition (`editions/<name>.json`). Singleton: there
is exactly one layer of kind `sample-data`, and it is never an `add[]` ref. The composer
stages it **last, after `surfaces[]`**, so the storefront copy below wins the paths it shares
with a surface layer.

What a consumer binds to is **not this layer** but the `sampleData` block of
[`layers/base/base.contract.json`](../base/base.contract.json): every subject a feature
layer's probe addresses is named there, with the probe that addresses it.

## The naming rule (D-B, binding)

**No real-world product domain appears anywhere.** Every group, product, category field,
variant axis, option, persona and order draws exclusively on **PIM, Commerce and CMS
vocabulary**, so the catalogue doubles as a platform-terminology tour and can never be
mistaken for a real business. `Size` and `Finish` are worldly, so they are *not* the variant
axes — `Tier` and `Mode` are.

**And the frontend filter is binding on top of it: an example ships only if Swift SHOWS it.**
A quantity price renders on the page, so it belongs; a PIM workflow is backend-only, so it
does not. Each of the twelve subgroups points at a component:

| Top group | Subgroup | What Swift shows |
|---|---|---|
| Data Models | `Variants` | the variant selector |
| Data Models | `Units & Measures` | the unit selector on add-to-cart |
| Data Models | `Bundles & BOM` | the package-contents list |
| Commerce | `Price Structures` | the quantity price table |
| Commerce | `Discounts` | the price-before-discount line |
| Commerce | `Stock & Delivery` | the stock count, status and delivery line |
| Content | `Documents` | the documents table |
| Content | `Media & Galleries` | the gallery and its thumbnails |
| Content | `Relations` | the related-products strip |
| Users | `Assortments` | which rows a signed-in persona sees |
| Users | `Contract Pricing` | your price against list |
| Users | `Currencies & VAT` | the figure itself |

All 28 category fields obey the same filter — a dimension in the platform's own unit
vocabulary, a material class, a rating, a compatibility note, a commercial term.

| Shape | Example |
|---|---|
| Top group | `Data Models`, `Commerce`, `Content`, `Users` |
| Product name | `Truvio <Concept> <Unit> <NN>` — `Truvio Variant Master 01`, `Truvio Price Matrix 20` |
| SKU | `TC-<CONCEPT>-<nnnn>` — `TC-VAR-0001`, `TC-PRC-0020`, `TC-SUB-0061` |
| Product id | `TCPROD0001` … `TCPROD0061` |
| Group id | `TCGRP-VARIANTS`, `TCGRP-DATA-MODELS` |
| Order id | `TCO-0001` … `TCO-0012` |
| Persona | `buyer@truvio-demo.example`, `csr@…`, `admin@…` |

The accent colour is industrial green (~`#2E7D5B`) wherever a colour is *data* — the product
tiles under `files/Images/TruvioCommerce/`. This layer is **data, not theme**: presentation
stays in `theme-default` (SPEC-06).

## What it ships

Every row is **serialized SqlTable YAML** under [`merge/_sql/<Table>/`](merge/_sql/), one file
per row key, listed in [`merge/merge-manifest.json`](merge/merge-manifest.json) and fenced by
the 29 merge predicates in [`config/sample-data-2.4.json`](config/sample-data-2.4.json), which
Compose-Edition unions into the composed `Serializer.config.json`. The rows land through the
ordinary merge deserialize, so an online build (URL + Admin API key, no SQL channel) delivers
the layer exactly as a local one does.

| Row family | Tables | Rows |
|---|---|---:|
| Catalogue | `EcomGroups`, `EcomShopGroupRelation`, `EcomGroupRelations`, `EcomProducts`, `EcomGroupProductRelation` | 251 |
| Variants | `EcomVariantGroups`, `EcomVariantsOptions`, `EcomVariantGroupProductRelation`, `EcomVariantOptionsProductRelation` | 49 |
| Prices, BOM, stock | `EcomPrices`, `EcomProductItems`, `EcomStockUnit` | 304 |
| Category fields and specs | `EcomProductCategory`, `EcomProductCategoryTranslation`, `EcomProductCategoryField`, `EcomProductCategoryFieldTranslation`, `EcomProductCategoryFieldValue`, `EcomFieldDisplayGroups`, `EcomFieldDisplayGroupTranslation`, `EcomFieldDisplayGroupFields` | 521 |
| Imagery, documents, relations | `EcomDetailsGroup`, `EcomDetails`, `EcomProductsRelatedGroups`, `EcomProductsRelated` | 704 |
| Identities and orders | `AccessUser`, `AccessUserGroupRelation`, `EcomOrders`, `EcomOrderLines` | 42 |
| Product field settings | `EcomProductField` | 6 |

1,877 rows in 29 tables. The per-table figures are `layer.json` `costHints.expectedRows`; the
counts an edition asserts are `EcomProducts` **97** and `EcomGroups` **16**.

Two things do not fit a row file and ship as loose scripts under `merge/_sql/`, declared in
`layer.json` `sql[]` (the serializer manifest has no provider for a whole script, so a
composer that reads only the manifests would stage them and execute nothing):

| Script | Phase / order | What it does |
|---|---|---|
| `email-stats.sql` | `after-replace-deserialize`, 1 | the email-marketing statistics backfill |
| `demo-clock.sql` | `after-replace-deserialize`, 2 | the anchor table, the shifter and the daily task |

Neither takes a `sqlcmd` variable, and neither writes a catalogue row.

**The YAML is the source of truth.** Several values were computed once by the pre-1.8.0 SQL
scripts on the harvest host and are now literals: the customer-group, list and ladder prices
derived from `ProductPrice`, the order and expected-delivery dates (frozen at the harvest day,
**2026-09-13**), the variant counters and the `tc_specs` field list. A later `ProductPrice`
edit does not move its group price. Edit the YAML, or re-harvest from a host that was
deserialized FROM this YAML with the predicates in `config/`; never re-harvest from a fresh
SQL run, or host-born values (GUIDs, timestamps, the `TC-PRICE-GRPV-*` ids) churn every file.

## Storefront copy

surface-swift ships its demo-facing strings in the `Placeholder` marker form on purpose, so a
composition with no brand data fails the design gate instead of shipping template copy. This
layer carries the copy that replaces the marker: 43 content documents, each surface-swift's own
document at the same path under `merge/_content/Swift 2/` or
`replace/_content/Swift 2/Navigation/`, with only the copy fields rewritten and an `ownership`
header set to `replace`.

| Where | What the prospect reads |
|---|---|
| Home hero | "One catalogue for every data model, price structure and content block"; buttons **Shop the catalogue** and **Browse Data Models** (`GroupID=TCGRP-DATA-MODELS`) |
| Home body | catalogue pitch with **Browse Commerce** (`GroupID=TCGRP-COMMERCE`), three features, an account call to action, **About Truvio Commerce** |
| About, Contact, Employees, Posts | company intro, three values, team heading, contact routes on `support@truvio-demo.example` |
| Header, footer, mega-menu | the `Truvio Commerce` wordmark, the copyright line, the Variants and Price Structures promos |

Rules for editing it:

- **Same path, same ids.** A document here stays a copy of surface-swift's document at the
  identical path (same `paragraphUniqueId`, item type, template, colour scheme, column). The
  composed SerializeRoot holds one file per path, so this copy wins by being the file at that
  path; a copy under any other filename is read as a second paragraph with the same GUID. When
  surface-swift changes one of these documents, re-derive this copy from it.
- **Composition order.** The copy reaches the host only because the composer stages the
  sampleData layer after `surfaces[]`.
- **D-B and the design gate.** Brand and platform vocabulary only, no marker word, no lorem, no
  stock Swift strings: every document is checked against the publish design config's
  `placeholderRegex`. Figures quote this layer's own counts; change them with the rows.
- **Links.** Page links stay `Default.aspx?ID=N` so the serializer's page-id remap resolves
  them; a `GroupID` query tail survives the remap.

An edition that composes no Swift content area carries these documents inertly.

## Identities and credentials

Three personas on the fictional `truvio-demo` domain — `buyer@`, `csr@`, `admin@` — all
contacts on one B2B account (`Truvio Demo Account`, `AccessUser` `100100`, customer number
`TC-100200`, the number the contract price resolves against) and each joined to the
base-contract permission group its role maps to: `1325 Customers`, `1292 CSR`,
`1270 Account Admin`. All three carry the account's own customer number — contract prices,
account-wide favourites and the CSR account listing compare that string exactly, so a
per-contact suffix would limit them to one contact.

**No password is in the data.** The `AccessUser` predicate excludes `AccessUserPassword` and
the runtime login columns, so no row file carries a password or a hash (the column name appears
only in `AccessUser/_meta.yml`'s column list). After the deserialize and host restart, set each
persona's password through the Management API `UserSetPassword` command with the Foundry's
`tools/secrets/Set-DemoCredential.ps1`, once per persona `100101`, `100102` and `100103`. It
sets the password, proves sign-in and stores the credential outside the repo. The route is the
same for a local and an online build, and merge never overwrites the password it set.

Their history is 12 orders across the `OrderFlowId 1` states — `OS1 New`, `OS2 Completed`,
`OS3 Rejected`. States from another flow (`OS12`/`OS13`/`OS14`) are deliberately unused: an
order carrying one reads as a broken record in the Commerce grids. `OrderCompletedDate` is set
only on a Completed order.

**All twelve orders belong to the buyer** (`OrderCustomerAccessUserId` = `100101`). This is not
a simplification, it is what the page permits: the customer-centre page grants group `1325` and
the *My orders* scope and nothing else, measured on DW 10.28.10, so an order stamped with the
CSR or the admin is invisible to every persona that can open the page. **CSR and admin reach a
buyer's orders by impersonating the buyer**, which is the platform's own path for it. The layer
ships what that path needs: the account group `100100` is typed `SystemAccount`, so the Swift CSR
Accounts app lists it, and the one `AccessUserSecondaryRelation` row `1292$$100100` grants the
base-contract CSR group impersonation over the account, which is what fills CSR Users.

`TCO-0001` is the completed order the RMA flow returns against: `feature-rma` ships the RMA
`PACK-RMA-0001` and its `EcomRmaOrderLines` link (id `100301`) pointing at its first line.

## The contract subjects

These are the rows a shipped probe addresses. They are stated machine-readably in
`base.contract.json` `sampleData.guaranteedRows`; a feature layer binds there, never here.

| Subject | Row | Probe that addresses it |
|---|---|---|
| buyer | `AccessUser` `100101` `TruvioBuyer`, `TC-100200`, group `1325` | every authenticated probe |
| CSR | `AccessUser` `100102` `TruvioCsr`, group `1292` | — (customer-centre surfaces) |
| account admin | `AccessUser` `100103` `TruvioAdmin`, group `1270` | — (account surfaces) |
| SKU validation | `TCPROD0001` / `TC-VAR-0001` | feature-reordering `sku-validation` |
| quantity tiers | `TCPROD0020`, list 120, 108 / 96 / 84 at 5 / 10 / 25 | feature-pricing `cart-price` (qty 10 → 96) |
| contract price | `TCPROD0046` / `TC-PRICE-CTR-0046` at `TC-100200` | feature-pricing `cart-price` (qty 1 → 36.90) |
| BOM kit | `TCPROD0042`, slots `TC-BOM-0042-1` / `TC-BOM-0042-2` | feature-bom-configurator `bom-cart-lines` |
| subscription plan | `TCPROD0061` / `TC-SUB-0061` | feature-subscription-orders `checkout-recurring` |
| delivered order | `TCO-0001` (`OS2`, buyer `100101`) | feature-rma `authenticated-body-contains` |
| RMA | `PACK-RMA-0001` + link `100301` — **owned by feature-rma** | feature-rma `configRows` |

`TCPROD0041` is the *fixed* Bundle Kit and carries no `EcomProductItems` slot, so the
configurable kit `TCPROD0042` is the BOM subject.

## The demo clock

Every seeded demo decays: orders, carts, send history and campaign windows all carry absolute
dates, and this layer's rows carry the **harvest day 2026-09-13**. The clock fixes it with an
**anchor table plus a whole-day uniform shift** — one row recording the date the rows were
anchored to, and a procedure that moves every operational date column by
`DATEDIFF(day, AnchoredTo, today)` and then re-anchors.

- **The anchor is seeded to the harvest day, not to `GETDATE()`.** The rows are serialized YAML
  with absolute dates, so a `GETDATE()` anchor reads delta 0 on a fresh install and the twelve
  orders stay frozen in 2026-09 forever while the task reports Success. With the harvest-day
  anchor the first run carries a real delta and moves the whole dataset onto today's calendar
  in one pass. **The brand orders ride the clock**, and so does every product date.
- **Whole-day and uniform** is the whole trick: the same integer shift on every column preserves
  intra-day ordering and every relative gap, so send → click and order → ship sequences stay
  coherent. It is idempotent (`+1` then `-1` nets zero) and catch-up safe.
- **Date columns are discovered from `sys.columns` on every run, never hardcoded.**
- **Config and logging tables are excluded** (`dbo._demoClockExclusion`), `ScheduledTask` first
  among them: `TaskNextRun` is what the scheduler reads.
- **State-marker columns carry their own guard** (`dbo._demoClockGuard`). `GiftCardCancel`
  cancels a card by rewriting `GiftCardExpiryDate` to now and keeping the balance, so the
  shipped guard shifts only cards still in the future.
- **A second date-shifting task must own its own anchor row**, or it reads delta 0 forever.
- **Prove it with a rewind-and-run, never a bare run.** Rewind the anchor by one day, run, and
  assert `TCO-0001`'s `OrderDate` advanced by exactly one day. The recipe is at the foot of
  `demo-clock.sql`.

## Email statistics

A campaign email that shows 0 sent / 0 clicked reads exactly like an unfinished build, and no
MCP or Admin API surface creates send history. `email-stats.sql` backfills it: per campaign
email one `EmailMessage` send-log row, 24 `EmailRecipient` sends (2 bounced), 3 tracked
`OMCLink` rows and 13 `OMCLinkClick` clicks. It is **discovery-driven** over whatever
`EmailMarketingEmail` rows the composition has — this layer authors none, so it is a clean
no-op on a composition that ships none. Opens are pixel-only and deliberately not attempted.
Every row it writes is marked `MessageDomainUrl = 'https://sample-data.example.invalid'` and
re-seeding deletes its own marked rows; real send history is never touched.

## Imagery

Every product carries an image, because a PLP card and a PDP with no image are an empty grey
box on the two pages the design gate measures. The tiles are this layer's own neutral SVGs — a
flat industrial-green plate with the concept word and the `TRUVIO` wordmark — one per concept
subgroup, plus the per-product pair `tc-tile-<concept>-<nnnn>` and `tc-detail-<concept>-<nnnn>`,
shipped as PNG under `files/Images/TruvioCommerce/products/` because `GetImage.ashx` decodes
with ImageSharp and ImageSharp has no SVG decoder. They are **data**: a product row points at a
file. The subscription plan reuses the `Price Structures` band tile.

Each of the 60 gallery rows (`TC-GAL-*`) points at the concept tile of **its own master's
band**, derived from that master's own `TC-DETAIL-*` default row so a row cannot name another
band's picture. A master therefore carries three distinct pictures: its own tile at sort 0, its
own detail image at sort 1, and its band's concept tile at sort 2.

The photographic brand assets are **shipped in `files/`**, under
`files/Images/TruvioCommerce/{brand,scenic,people}/`, and listed in the Distribution's
[`brand/brand-assets.manifest.json`](../../brand/brand-assets.manifest.json), which stays the
provenance and sha256 record for each of the fifteen: source URL, byte count and digest,
verified before the bytes were committed. The logo the header and footer bind is
`brand/truvio-logo.svg`, inlined by the Swift template and never handed to `GetImage.ashx`;
the home hero, the catalogue band and the content band bind `scenic/product-shot-1.webp`,
`scenic/abstract-patterns.jpeg` and `people/office-collaboration.webp`, all three opaque
because the handler answers those requests with JPEG and flattens an alpha channel. `tools/truvio-gallery-photos.sql` converges the gallery
rows onto the `scenic/` files **by hand**. Those files are now on disk the moment the layer
deploys, so the precondition its header names is satisfied by the layer itself, but the
script stays under `tools/` and stays out of `sql[]`: which photograph belongs on which
master is a per-master editorial choice, not something a composition should decide for a
consumer.

### Linking to a PDP

A demo link to a product detail page carries **both** ids:

```
/en-us/shop?GroupID=TCGRP-BUNDLES&ProductID=TCPROD0042
```

`/en-us/shop?ProductID=...` on its own **404s** for a bundle master. The shop page resolves a
product through the group context, so a `ProductID` with no `GroupID` beside it has no group to
resolve in. A link that drops the `GroupID` is a broken link, not a slower one.

## Key families

This layer owns the `TC*` family: `TCGRP-*`, `TCPROD*`, `TCVG-*`, `TCVGR-*`, `TCVO-*`,
`TC-PRICE-*`, `TC-BOM-*`, `TC-DETAIL-*`, `TC-HOVER-*`, `TC-GAL-*`, `TC-DOC-*`, `TCREL-*`,
`TCO-*`, `TCFIELD-*` and the `tc_*` product categories — the family
[`base.contract.json`](../base/base.contract.json) `idRules.reservedFixtureKeys` reserves. Its
int-identity rows sit at reserved ids above the contract's `100000` floor and the serializer
writes them verbatim with `IDENTITY_INSERT`: `AccessUser` `100100`-`100103`, `EcomDetailsGroup`
`100110` (`Images`) and `100111` (`Manuals`), `EcomFieldDisplayGroups` `100120` (`tc_specs`),
`EcomStockUnit` `100201`-`100261`, `EcomProductField` `100130`-`100135`. The storefront binds the asset categories and the display
group by system name, not by id. An addition writing its own rows into a base-owned table uses
its `PACK-<NAME>-` prefix instead.

## Variant editing on the six master-only fields

DW 10.28 keeps six **standard** product fields master-only out of the box — `ProductNumber`,
`ProductPrice`, `ProductStock`, `ProductShortDescription`, `ProductMetaTitle`,
`ProductMetaDescription`. With the setting off, a save of a variant **master** through any
route (the admin UI, Admin API `ProductSave`, MCP `patch_products_safe` / `update_products`)
copies the master's values onto **every** variant row, and a save of a variant row is silently
reverted while the tool echoes success (Foundry [#1253], [#1238], arm B).

This layer ships **36 variant rows with their own `ProductNumber`, price and stock**, so it
depends on that setting being ON. It therefore **ships the setting**, as six rows in
`merge/_sql/EcomProductField/`.

**Where DW keeps it.** Not in `GlobalSettings.Ecom.config`. The
`/Ecom/ProductLanguageControl/Variant/<field>` nodes there are the **pre-migration** store —
DW 10 carries a `/Ecom/ProductLanguageControl/MigrationToDatabaseDone` flag beside them and
reads the live value from the database. The live store is one row per field in
**`EcomProductField`**, column **`ProductFieldAllowChangesAcrossVariants`**, with
`ProductFieldIsStandard = 1` marking a settings row that stands for a standard field rather
than a custom one. Measured on `foundry.mydwsite4.com` (DW 10.28.10, Swift 2.4.0, 2026-09-14):
the table is **empty** on a stock host — the config file still says
`Variant/ProductNumber = True` while the behaviour is master-only — and Admin API
`ProductAttributeSettingsSave` **creates** one row per field. Writing the six rows and then
saving a master left all six variant rows of `TCPROD0001` byte-identical, with no host restart.

**Why the PKs are `TCFIELD-*`.** `ProductFieldId` is minted by the `EcomNumbers` `FIELD`
counter as `FIELD<n>`, and that counter is not advanced by a deserialize. A layer shipping
`FIELD<n>` ids would hand the next host-minted field the same key. `TCFIELD-<SYSTEMNAME>` is
outside the generator's shape, so the two never meet; the identities `100130`-`100135` sit in
the layer's reserved range above the contract's `100000` floor.

**Consumer note.** The rows are merge, so a host that already carries its own settings row for
one of these six keeps it and gains a second row for the same system name. On a host built
from these layers the table is empty and the six rows are the only ones.

[#1253]: https://github.com/justdynamics/Truvio.Commerce.Foundry/issues/1253
[#1238]: https://github.com/justdynamics/Truvio.Commerce.Foundry/issues/1238

## Traps the rows obey

- **Language row.** Every catalogue row is `ENU`. `LANG1` is the latent second `en-US` row,
  retained only for `reference_category`; rows written under it are invisible on the storefront.
- **Primary page id stays 0.** No group sets a primary page id. Swift's
  `ProductDetailRenderGrid` prefers a group's `PrimaryPageId` over the detail page, and a value
  aimed at the shop/PLP page makes the catalog app re-render that page inside itself — the
  recursion guard then empties **every** PDP in the shop, with no error anywhere.
- **No empty groups.** Navigation visibility and URL reachability are independent surfaces, so
  an empty group still serves a live 200 PLP reading "0 products". Every group here carries
  products: a master's primary relation is its subgroup, and it carries a second non-primary
  relation to its top group.
- **Host restart.** The group-product relation cache is held in-process and the predicates name
  no service caches, so restart the host after the merge deserialize and before building the
  product index. The `sql[]` scripts run in the same phase and `demo-clock.sql` declares the
  restart (a SQL-inserted `ScheduledTask` row is invisible to a running app).
- **Orders carry every price column, not just `OrderTotalPrice`.** Swift's My orders list and
  order detail read the VAT-split columns (`OrderPriceWithVAT` / `WithoutVAT` / `VAT` /
  `VATPercent`, the `OrderPriceBeforeFees*` set) and the line objects read
  `OrderLinePriceWith(out)VAT` and `OrderLineUnitPrice*`; `OrderTotalPrice` alone renders as
  zero (Foundry [#1239]). All 12 `TCO-*` orders and their 20 lines ship the full set at the
  layer's `OrderVAT 0`: `WithVAT = WithoutVAT = ` the amount, VAT and VATPercent `0`, unit
  prices from `OrderLineUnitPrice`, `BeforeFees` = the line sum, fees and discounts `0`.
  **Do not repair an order with `OrderRecalculate`**: it re-prices every line from the LIVE
  catalogue (measured: `TCO-0012-1` unit 60 -> 51, line 120 -> 102) and leaves
  `OrderLineUnitPrice` stale, so a historical order stops being historical.

[#1239]: https://github.com/justdynamics/Truvio.Commerce.Foundry/issues/1239

- **Merge, never overwrite.** Every predicate is merge: a re-deserialize fills unset columns on
  its own keys and converges rather than duplicating, and never resets a persona, a price or the
  password `UserSetPassword` set. Merge cannot rename or delete, so a host seeded by an older
  script keeps its stale values; editions deserialize to fresh hosts.

## Activation

Every edition that sets `sampleData: true` composes it: `swift-demo`, `headless-demo`,
`dap-portal`. `base-swift` and `base-only` set it false and stay catalogue-free —
`base-swift` keeps surface-swift's marker copy, which is the point of that edition.

The PLP and PDP read the `ProductsFrontend` product repository the host's Swift design package
ships (`base.contract.json` `repositories`, `provisionedByGate: false`); an empty PLP on a host
that lacks it is that gap, not a missing row here.
