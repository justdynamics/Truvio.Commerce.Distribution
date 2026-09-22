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
| Product Structure | `Variants` | the variant selector |
| Product Structure | `Units & Measures` | the unit selector on add-to-cart |
| Product Structure | `Bundles & BOM` | the package-contents list |
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
| Top group | `Product Structure`, `Commerce`, `Content`, `Users` |
| Product name | `Truvio <Concept> <Unit> <NN>` — `Truvio Variant Master 01`, `Truvio Price Matrix 20` |
| SKU | `TC-<CONCEPT>-<nnnn>` — `TC-VAR-0001`, `TC-PRC-0020`, `TC-SUB-0061` |
| Product id | `TCPROD0001` … `TCPROD0061` |
| Group id | `TCGRP-VARIANTS`, `TCGRP-PRODUCT-STRUCTURE` |
| Data model id | `TCDM-COMMERCE`, `TCDM-PRODUCT-STRUCTURE` — the PIM tree, never a storefront group |
| PIM shop id | `TCSHOP-PIM` (`Truvio PIM`) |
| Order id | `TCO-0001` … `TCO-0012` |
| Persona | `buyer@truvio-demo.example`, `csr@…`, `admin@…` |

The accent colour is industrial green (~`#2E7D5B`) wherever a colour is *data* — the product
tiles under `files/Images/TruvioCommerce/`. This layer is **data, not theme**: presentation
stays in `theme-default` (SPEC-06).

## What it ships

Every row is **serialized SqlTable YAML** under [`merge/_sql/<Table>/`](merge/_sql/), one file
per row key, listed in [`merge/merge-manifest.json`](merge/merge-manifest.json) and fenced by
the 35 merge predicates in [`config/sample-data-2.4.json`](config/sample-data-2.4.json), which
Compose-Edition unions into the composed `Serializer.config.json`. The rows land through the
ordinary merge deserialize, so an online build (URL + Admin API key, no SQL channel) delivers
the layer exactly as a local one does.

| Row family | Tables | Rows |
|---|---|---:|
| Catalogue | `EcomGroups`, `EcomShopGroupRelation`, `EcomGroupRelations`, `EcomProducts`, `EcomGroupProductRelation` | 338 |
| Variants | `EcomVariantGroups`, `EcomVariantsOptions`, `EcomVariantGroupProductRelation`, `EcomVariantOptionsProductRelation` | 55 |
| Prices, BOM, stock | `EcomPrices`, `EcomProductItems`, `EcomStockUnit` | 292 |
| Category fields and specs | `EcomProductCategory`, `EcomProductCategoryTranslation`, `EcomProductCategoryField`, `EcomProductCategoryFieldTranslation`, `EcomProductCategoryFieldValue`, `EcomFieldDisplayGroups`, `EcomFieldDisplayGroupTranslation`, `EcomFieldDisplayGroupFields` | 577 |
| Imagery, documents, relations | `EcomDetailsGroup`, `EcomDetails`, `EcomProductsRelatedGroups`, `EcomProductsRelated` | 704 |
| Identities and orders | `AccessUser`, `AccessUserGroupRelation`, `AccessUserSecondaryRelation`, `EcomOrders`, `EcomOrderLines` | 43 |
| Product field settings | `EcomProductField` | 6 |
| PIM structure | `EcomShops`, `EcomShopLanguageRelation`, `EcomCompletionRules`, `DynamicStructures`, `DynamicStructureLevels` | 9 |

2,024 rows in 35 tables. The per-table figures are `layer.json` `costHints.expectedRows`; the
counts an edition asserts are `EcomProducts` **97** and `EcomGroups` **21**.

`EcomGroups` 21 is **16 browsable storefront groups + 5 PIM groups**, and the two trees sit in
different shops — see [The PIM structure](#the-pim-structure). `EcomProducts` stays 97: the PIM
tree adds relations, never products. Two of the figures above are *corrections* and not
additions — `EcomShopGroupRelation` was declared as 4 while sixteen rows sat on disk (the twelve
4.1.3 added), and `EcomPrices` was declared as 233 while 4.1.2 left 221. 5.0.0 regenerates
`merge-manifest.json` `files[]` from disk, so the manifest, the declaration and the tree now
agree in both directions.

Three things do not fit a row file and ship as loose scripts under `merge/_sql/`, declared in
`layer.json` `sql[]` (the serializer manifest has no provider for a whole script, so a
composer that reads only the manifests would stage them and execute nothing):

| Script | Phase / order | What it does |
|---|---|---|
| `email-stats.sql` | `after-replace-deserialize`, 1 | the email-marketing statistics backfill |
| `demo-clock.sql` | `after-replace-deserialize`, 2 | the anchor table, the shifter and the daily task |
| `number-counters.sql` | `after-merge-deserialize`, 1 | raises every `EcomNumbers` counter to the highest id in use |

None takes a `sqlcmd` variable, and none writes a catalogue row.

**The number counters (Foundry #1322).** Dynamicweb mints a new id as `NumberPrefix` plus the
next `EcomNumbers` counter value, and a deserialize writes ids verbatim without advancing the
counter. A composed host therefore starts with counters behind the ids it holds (the base's
`OS1`-`OS14`, `SHIP3`-`SHIP13`, `PAY1`-`PAY3`; measured on `foundry.mydwsite4.com`: `SHIP`
counter 5 with `SHIP13` present), and a create without an explicit id overwrites a shipped
row. `number-counters.sql` reads, for every counter whose `NumberTableName` and
`NumberColumnName` are set, the highest id of the exact form `<prefix><digits><postfix>` and
raises `NumberCounter` to it. It never lowers a counter and ignores ids outside that form, so
the `TC*` keys this layer ships move nothing. It runs after the merge deserialize so every
layer's rows are in place, and it is idempotent.

**Local installs only.** Like every `sql[]` script, it runs where the applier has a SQL channel.
An online host (URL + Admin API key) has none, and no MCP tool or Management API command
writes `EcomNumbers`, so an online host applies the script through its own SQL route (the
hosting provider's SQL access) or passes an explicit unused id on every create until it does.
Editions without `sampleData` (`base-only`, `base-swift`) do not compose this layer and do not
get the script; their base `OS`/`SHIP`/`PAY` counters lag the same way.

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
| Home hero | "One catalogue for every product structure, price structure and content block"; buttons **Shop the catalogue** and **Browse Product Structure** (`GroupID=TCGRP-PRODUCT-STRUCTURE`) |
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

## The PIM structure

The layer shipped four product categories, 28 fields and 61 masters and, until 5.0.0, **nothing
to attach them to**: no `ShopType 4` shop, no `GroupType 2` data model, no `reference_category`
mirror, no completion rule, no workspace. Every category was a set of fields nothing plumbed to a
product, so a PIM demo on a delivered host opened an empty **Data models** tree and a blank
completeness panel while every row count read green.

**The tree**, in its own shop, separate from the storefront catalogue:

```
EcomShops  TCSHOP-PIM  "Truvio PIM"  ShopType 4 (DataStructure)   ShopAutoId 100130
└── TCDM-TRUVIO-COMMERCE   "Truvio Commerce"    GroupType 1 (folder, no category)
    ├── TCDM-COMMERCE          "Commerce"          GroupType 2 → tc_commerce           16 masters
    ├── TCDM-CONTENT           "Content"           GroupType 2 → tc_content            15 masters
    ├── TCDM-PRODUCT-STRUCTURE "Product Structure" GroupType 2 → tc_product_structure  15 masters
    └── TCDM-USERS             "Users"             GroupType 2 → tc_users              15 masters
```

- **`ShopType` is the whole discriminator.** `4` (DataStructure) is the only value the admin's
  **Data models** section lists; `1` (Shop) and `3` (Channel) sit together under **Channels**.
  A data model tree parked on the commerce shop is in the wrong tree, not in a second one.
- **`GroupType` is the other one, and no read surface reports it.** `2` (DataModel) is
  indistinguishable from `0` (Common) through every MCP group tool: same shop, same relations,
  same shape. `NULL` silently means `0`. Read it from `EcomGroups` before any group-tree audit.
- **Every group carries its own `EcomShopGroupRelation` row, the folder included.** DW resolves a
  group to its shop through that table and does **not** walk the parent chain, so a group without
  one renders in the tree and resolves zero products — with a live 200, a right heading and no
  error anywhere.
- **Each DataModel group needs `ProductCategoryId`**, or its seven fields reach no product.
- **The 61 master relations are `IsPrimary` false.** Each master relates to the data model of its
  band, derived from the top-group relation it already carried. Its primary home stays its
  catalogue subgroup, so no storefront URL, PLP or canonical moves.

### Completion rules, and why the mirrors matter

Four rules, `100160`-`100163`, one per data model, each naming its category's seven fields and
excluding variants. They are assigned on the data-model group itself, through
`EcomGroups.GroupCompletionRules` = the rule id plus `GroupCompletionLanguageIds` = `ENU`, which
is the shape a measured DW 10.28 PIM host carries.

The field names are the **authoring** system name, `ProductCategory|<category>|<field>`. The
**index** name for the same field is `CustomField_<systemName>`; a rule holding the index form
matches nothing, and a bare field id matches nothing on either side.

The layer also ships **28 `reference_category` mirror fields and their 28 ENU translations**.
`reference_category` is DW's hidden `CategoryType 2` template category, and it is where the admin
resolves every rule and completeness lookup. **Its absence has no visible symptom except the one
that matters**: rules validate, assignments persist, `ProductCompletenessRulesByProductId` returns
correct data, and the Data Completeness panel on the product renders empty. The **parent**
`reference_category` row and its translation are base-owned (base 3.6.0); the per-field mirrors
are here.

Two gates this layer cannot ship as rows, and does not claim: the **Completeness feature** flag
(Settings → Feature management) and an index build with `SkipCompletionRules` `False`. Without
both, `CompletionRule|<id>` index fields never populate and completeness is unusable as a query
term. Rules written by SQL also need a **host restart** — `CompletionRuleService` and
`ProductCategoryService` hold their `ServiceCache` rows until one.

### The Dynamic Workspace

One workspace, `DynamicStructures` `100170` **"Truvio PIM - by data model"**, levelled on
`DATAMODEL_Truvio_PIM` (level `100171`) then `GroupNames` (level `100172`). Its backing query is
[`repositories/TruvioCommerce/PimWorkspace.query`](repositories/TruvioCommerce/PimWorkspace.query),
which this layer ships beside the rows that name it — `DynamicStructureQueryId` is that file's
`Id` GUID, and `DynamicStructureLevels.DynamicStructureLevelStructureId` is the structure's
`UniqueId` GUID held as text, never its int id.

A workspace is a **projection, not storage**: it moves no product row. The canonical home of a
product is still its `EcomGroupProductRelation` rows.

**Why the field is called `DATAMODEL_Truvio_PIM`.** DW derives the data-model index field from the
**shop name**, not its id: `DATAMODEL_<Shop Name with spaces as underscores>`. The shop is named
`Truvio PIM`, so the field is `DATAMODEL_Truvio_PIM`. **Rename the shop and that field name moves
with it**, orphaning level `100171` — which is why the shop name is a `configRows` assertion and
not a free string.

**What the index has to do.** The field is emitted by the `Products.index` `Full` build **only**
with `SkipDataModels` `False`, which surface-swift ships from 1.14.0. With it `True` the workspace
opens, the level renders, and every node is empty: no error, no warning, a correct document count.
Both level sources are deliberately **non-analysed keyword** fields — an analysed free-text source
enumerates lower-cased Lucene term fragments (`"Hot-Shot"` becomes `hot` and `shot`) and a numeric
source enumerates nodes that open onto zero rows, and neither errors. Check a level by the **sum**
of its node counts against the backing query's own total, never by drilling one node.

`PimWorkspace.query` is not `Products.query`. The storefront query resolves
`Dynamicweb.Ecommerce.Context` macros that exist only on a server-rendered storefront request; a
workspace runs in the backend, where those resolve to nothing and the query silently matches
nothing. So the workspace query states `LanguageID` as a constant, filters `IsVariant` false
(masters only — a level counts index *documents*, so the variant and language fan-out would make
every node count overshoot), and applies no `Active` filter: a PIM workbench must show the product
that is not live yet, which is exactly the one that still needs enriching.


### The workspace row and the heap table it lands in (#1305)

`DynamicStructures` has **no primary key on DW 10.28**: it is a heap, with no unique index
either. Serializer 1.0.2-beta and earlier had no key to match a row on and wrote the table as
`DELETE FROM [table]` followed by insert-all, **under Merge exactly as under Replace**. Measured
on the `20260919-153644` gate run against `foundry.mydwsite4.com`: the merge of our single row
removed the three baseline workspaces (`DynamicStructureId` 1, 3 and 4) and left their seven
`DynamicStructureLevels` rows behind as orphans.

**From 5.0.1 the layer requires Serializer 1.0.3-beta** (the base-contract floor) and declares
`keyColumns: ["DynamicStructureUniqueId"]` on the `sample-data DynamicStructures` predicate and
its `merge-manifest.json` entry. 1.0.3-beta resolves a match key for a heap (primary key, then
the declared `keyColumns`, then a unique index, then all columns), upserts, and a Merge never
deletes: the host's own workspaces survive. The run log's summary carries a `Deleted` count,
which the Foundry `pim-structure` leg asserts is 0 for the delivery.

Two consequences of the natural key:

- The identity is **not** written. On a host with no row carrying this `UniqueId` the target
  assigns `DynamicStructureId`; on a host delivered before, the existing row keeps its id.
  Nothing joins on the int id: the levels join on `DynamicStructureUniqueId`.
- The engine logs one `WARNING: [DynamicStructures] has no primary key; rows matched by
  keyColumns` line per run.

A host delivered by 1.0.2-beta already lost its workspaces, and nothing restores them. Its
orphan level rows still need deleting by hand: both scripts under [`tools/`](tools/) carry an
idempotent orphan-level delete for exactly this.

`DynamicStructures` is the **only heap table this layer writes**. Every other one of its 35
tables has a primary key. Check `_meta.yml` `keyColumns` against the live `sys.indexes` before
adding a table to this layer, and declare `keyColumns` on any heap.

## Removing the catalogue from a branded demo

A branded demo starts from a composed `swift-demo` host and then loads the customer's own
catalogue. The sample catalogue is then not a neutral placeholder — it is wrong data in the
customer's channel. Two operator scripts under [`tools/`](tools/) handle it. **Neither is declared
in `layer.json` `sql[]`**: a declared script is one the composer *runs*, and whether a host keeps
the sample catalogue is a per-delivery editorial decision.

| Script | When | What it does |
|---|---|---|
| [`tools/scrub-sample-catalogue.sql`](tools/scrub-sample-catalogue.sql) | after **every** delivery onto a branded host | removes the whole sample catalogue **and** the PIM structure, plus any orphaned workspace levels |
| [`tools/retire-4x-ids.sql`](tools/retire-4x-ids.sql) | **once**, before delivering 5.0.0 onto a 4.x host | removes the ids 5.0.0 renamed, the orphan workspace levels and the orphan shop-group relations |

**The scrub keeps what is not catalogue**: the three personas and their B2B account, the twelve
orders `TCO-0001`-`TCO-0012`, the storefront copy on Home / About / Contact / header / footer /
mega-menu, the demo clock and its tables, the email statistics, the `Images` and `Manuals` asset
categories (infrastructure a branded catalogue's own assets need), the six `TCFIELD-*`
variant-editing settings rows, and every base row. It removes the `TC*` / `tc_*` rows, the
`TCSHOP-PIM` shop, the `TCDM-*` groups, the four completion rules, the workspace and its levels,
and the 28 `reference_category` mirrors — **not** the `reference_category` parent row, which is
base-owned, and **not** the stock locations, which base 3.6.0 ships neutral. It is idempotent and
must be re-run after every delivery, because **a merge deserialize re-inserts every row it
removes**. Rebuild the product index and restart the host afterwards.

**The retire script exists because merge never deletes.** 5.0.0 renames the band id *and* name
(`TCGRP-DATA-MODELS` → `TCGRP-PRODUCT-STRUCTURE`, `tc_data_models` → `tc_product_structure`, and
the two PDFs). Delivering 5.0.0 onto a host that holds 4.x therefore *inserts* the new ids and
*leaves* the old ones: two top groups in the menu, two categories in the field picker, fifteen
duplicate spec values per master, two datasheet rows on thirty product pages — and no error
anywhere. The three subgroups and the fifteen masters keep their ids across the rename; only their
parent changes. A clean-room host needs nothing. (Same precedent as the twelve retired price rows
in the 4.1.2 changelog.)

## Key families

This layer owns the `TC*` family: `TCGRP-*`, `TCDM-*`, `TCSHOP-PIM`, `TCPROD*`, `TCVG-*`,
`TCVGR-*`, `TCVO-*`, `TC-PRICE-*`, `TC-BOM-*`, `TC-DETAIL-*`, `TC-HOVER-*`, `TC-GAL-*`,
`TC-DOC-*`, `TCREL-*`, `TCO-*`, `TCFIELD-*` and the `tc_*` product categories — the family
[`base.contract.json`](../base/base.contract.json) `idRules.reservedFixtureKeys` reserves. Its
int-identity rows sit at reserved ids above the contract's `100000` floor and the serializer
writes them verbatim with `IDENTITY_INSERT`: `AccessUser` `100100`-`100103`, `EcomDetailsGroup`
`100110` (`Images`) and `100111` (`Manuals`), `EcomFieldDisplayGroups` `100120` (`tc_specs`),
`EcomStockUnit` `100201`-`100261`, `EcomProductField` `100130`-`100135`, and for the PIM
structure `EcomShops` `100130`, `EcomShopLanguageRelation` `100131`, `EcomGroups`
`100140`-`100144`, `EcomShopGroupRelation` `100145`-`100149`, `EcomProductCategoryField`
`100150`-`100177`, `EcomCompletionRules` `100160`-`100163`, `DynamicStructures` `100170`,
`DynamicStructureLevels` `100171`-`100172`, `EcomGroupRelations` `100178`-`100181`,
`EcomGroupProductRelation` `100200`-`100260`, `EcomProductCategoryFieldTranslation`
`100300`-`100327`. **The ranges are per TABLE**, so `EcomProductField` `100130`-`100135` and
`EcomShops` `100130` are not a collision. The storefront binds the asset categories and the display
group by system name, not by id. An addition writing its own rows into a base-owned table uses
its `PACK-<NAME>-` prefix instead.

## Variant combinations

Each of the six variant masters (`TCPROD0001`, `0011`, `0016`, `0031`, `0041`, `0051`) carries
two variant groups, `Tier` (3 options) and `Mode` (2 options), and six variant product rows
whose `ProductVariantId` is the dotted combination, `TCVO-TIER-<t>.TCVO-MODE-<m>`.
`EcomVariantOptionsProductRelation` holds exactly those combinations, one row per
`ProductVariantId`, 36 in all, and **no bare option rows**. That is the shape Dynamicweb itself
builds: on the stock Swift database (`dw10-demo`, `dw10-swift`) a master with two or more
variant groups carries only dotted combination rows in this table, a single-group master
carries its bare options, and every variant product row has its relation row.

The relation row is what makes a combination sellable. Without it the cart refuses the line
(`Not a valid variant combination for product TCPROD0001 with variant ID
TCVO-TIER-ENT.TCVO-MODE-PUB` in the event log, while `cartcmd=add` answers 200 with no line)
and Admin API `VariantCombinationsByProductId` answers 500 `Index was outside the bounds of the
array` on the bare rows (Foundry #1255, #1269). The rows sit at the reserved identities
`100400`-`100435`.

**A host delivered from 5.0.0 or earlier** keeps its 30 bare option rows after a 5.0.1
delivery, because a merge deserialize never deletes a row. Run
[`tools/retire-bare-variant-options.sql`](tools/retire-bare-variant-options.sql) once, before
or after the delivery. A clean-room host needs nothing.

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
