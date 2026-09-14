# truvio-demo (kind: sample-data)

The **Truvio Commerce brand data**: the catalogue, identities and orders a prospect
actually sees on the `swift-demo` edition. It is the second layer of kind `sample-data`,
and it is deliberately not a replacement for [`sample-data`](../sample-data/README.md):
that layer keeps the gate's marker-string fixtures (`FIXT*`, the `PACK-*` feature
fixtures, the demo clock, the email statistics), this one carries the brand rows.
The two families never touch the same row.

Specified by [V5-PLAN](https://github.com/justdynamics/Truvio.Commerce.Foundry/blob/main/docs/V5-PLAN.md)
§2.4 and decisions **D-B** (the brand and its naming rule) and **D-D** (brand data is its
own `sample-data` layer, no new kind, and feature layers carry zero catalogue rows).

## The naming rule (D-B, binding)

**No real-world product domain appears anywhere.** Every group, product, category field,
variant axis, option, persona and order draws exclusively on **PIM, Commerce and CMS
vocabulary**, so the catalogue doubles as a platform-terminology tour and can never be
mistaken for a real business. `Size` and `Finish` are worldly, so they are *not* the
variant axes — `Tier` and `Mode` are.

**And the frontend filter (round two, 2026-09-13) is binding on top of it: an example
ships only if Swift SHOWS it.** A quantity price renders on the page, so it belongs; a PIM
workflow is backend-only, so it does not. Eight subgroups named a concept the storefront
cannot draw — Workflows, Completeness, Permissions, Impersonation, Item Types, Pages,
Paragraphs, Groups — and every one was replaced by vocabulary a Swift page renders. Each of
the twelve now points at a component:

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

The category fields followed the same filter: all 28 are now things a buyer reads — a
dimension in the platform's own unit vocabulary, a material class, a rating, a
compatibility note, a commercial term. `Completeness Score`, which rendered as a
shopper-facing spec row, is gone along with every other backend concept beside it.

| Shape | Example |
|---|---|
| Top group | `Data Models`, `Commerce`, `Content`, `Users` |
| Subgroup | `Variants`, `Units & Measures`, `Bundles & BOM`, `Price Structures`, `Discounts`, `Stock & Delivery`, `Documents`, `Media & Galleries`, `Relations`, `Assortments`, `Contract Pricing`, `Currencies & VAT` |
| Product name | `Truvio <Concept> <Unit> <NN>` — `Truvio Variant Master 01`, `Truvio Price Matrix 16` |
| SKU | `TC-<CONCEPT>-<nnnn>` — `TC-VAR-0001`, `TC-PRC-0016` |
| Product id | `TCPROD0001` … `TCPROD0060` |
| Group id | `TCGRP-VARIANTS`, `TCGRP-DATA-MODELS` |
| Order id | `TCO-0001` … `TCO-0012` |
| Persona | `buyer@truvio-demo.example`, `csr@…`, `admin@…` |

The accent colour is industrial green (~`#2E7D5B`) wherever a colour is *data* — here,
the product tiles under `files/Images/TruvioCommerce/`. This layer is **data, not theme**:
presentation stays in `theme-default` (SPEC-06).

## What it ships

Since 1.8.0 (Foundry #1215) every row is **serialized SqlTable YAML** under
[`merge/_sql/<Table>/`](merge/_sql/), one file per row key, listed in
[`merge/merge-manifest.json`](merge/merge-manifest.json) and fenced by the 28 merge
predicates in [`config/truvio-demo-2.4.json`](config/truvio-demo-2.4.json), which
Compose-Edition unions into the composed `Serializer.config.json`. The rows land through the
ordinary merge deserialize, so an online build (URL + Admin API key, no SQL channel) delivers
the layer exactly as a local one does. The layer declares no `sql[]`.

| Row family | Tables | Rows |
|---|---|---:|
| Catalogue | `EcomGroups`, `EcomShopGroupRelation`, `EcomGroupRelations`, `EcomProducts`, `EcomGroupProductRelation` | 248 |
| Variants | `EcomVariantGroups`, `EcomVariantsOptions`, `EcomVariantGroupProductRelation`, `EcomVariantOptionsProductRelation` | 49 |
| Prices, BOM, stock | `EcomPrices`, `EcomProductItems`, `EcomStockUnit` | 302 |
| Category fields and specs | `EcomProductCategory`, `EcomProductCategoryTranslation`, `EcomProductCategoryField`, `EcomProductCategoryFieldTranslation`, `EcomProductCategoryFieldValue`, `EcomFieldDisplayGroups`, `EcomFieldDisplayGroupTranslation`, `EcomFieldDisplayGroupFields` | 514 |
| Imagery, documents, relations | `EcomDetailsGroup`, `EcomDetails`, `EcomProductsRelatedGroups`, `EcomProductsRelated` | 701 |
| Identities and orders | `AccessUser`, `AccessUserGroupRelation`, `EcomOrders`, `EcomOrderLines` | 42 |

Every predicate is **merge**: a re-deserialize fills unset columns and never resets a
persona, a price or a password that was set on the host. The per-table counts are in
[`CHANGELOG.md`](CHANGELOG.md) 1.8.0.

**The YAML is the source of truth.** Several values were computed once, by the 1.7.2 SQL
scripts on the harvest host, and are now literals: the customer-group, list and ladder prices
derived from `ProductPrice`, the order and expected-delivery dates (frozen at the harvest day,
2026-09-13), the variant counters and the `tc_specs` field list. A later `ProductPrice` edit
does not move its group price. Edit the YAML, or re-harvest from a host that was deserialized
FROM this YAML with the predicates in `config/`; never re-harvest from a fresh SQL run, or
host-born values (GUIDs, timestamps, the `TC-PRICE-GRPV-*` ids) churn every file.

## Storefront copy (1.9.0)

surface-swift ships its demo-facing strings in the `Placeholder` marker form so that a
composition with no brand layer fails the design gate (surface-swift README, CHANGELOG
1.4.0). On `swift-demo` this layer is the brand layer, so it carries the copy that replaces
the marker: 43 content documents, each surface-swift's own document at the same path under
`merge/_content/Swift 2/` or `replace/_content/Swift 2/Navigation/`, with only the copy fields
rewritten and an `ownership` header set to `replace`.

| Where | What the prospect reads |
|---|---|
| Home hero | "One catalogue for every data model, price structure and content block"; buttons **Shop the catalogue** (Shop) and **Browse Data Models** (`GroupID=TCGRP-DATA-MODELS`) |
| Home body | catalogue pitch with **Browse Commerce** (`GroupID=TCGRP-COMMERCE`), "Why buyers order from Truvio Commerce" over three features, an account call to action, the figures 60 / 12 / 36, **About Truvio Commerce** |
| About, Contact, Employees, Posts | company intro, three values, figures 4 / 96 / 324, team heading, contact routes on `support@truvio-demo.example` |
| Header, footer, mega-menu | the `Truvio Commerce` wordmark, the copyright line, the Variants and Price Structures promos |

Rules for editing it:

- **Same path, same ids.** A document here must stay a copy of surface-swift's document at
  the identical path (same `paragraphUniqueId`, item type, template, colour scheme, column).
  The composed SerializeRoot holds one file per path, so the brand copy wins by being the file
  at that path; a copy under any other filename is read as a second paragraph with the same
  GUID. When surface-swift changes one of these documents, re-derive this copy from it.
- **Composition order.** The copy reaches the host only when the composer stages this layer
  after surface-swift. Compose-Edition composes `add[]` before `surfaces[]`, so this depends
  on sample-data `add[]` layers being composed after `surfaces[]` (see CHANGELOG 1.9.0).
- **D-B and the design gate.** Brand and platform vocabulary only, no marker word, no lorem,
  no stock Swift strings: every document is checked against the publish design config's
  `placeholderRegex`. Figures quote this layer's own counts; change them with the rows.
- **Links.** Page links stay `Default.aspx?ID=N` so the serializer's page-id remap resolves
  them; a `GroupID` query tail survives the remap.

`base-swift` does not compose this layer and keeps surface-swift's marker copy.

## Identities

Three personas on the fictional `truvio-demo` domain — `buyer@`, `csr@`, `admin@` — all
members of one B2B account (`Truvio Demo Account`, customer number `TC-100200`, the number
the contract price resolves against) and each joined to the base-contract permission group
its role maps to: `1325 Customers`, `1292 CSR`, `1270 Account Admin`. All three contacts
carry the account's own customer number: contract prices, account-wide favourites and the
CSR account listing compare that string exactly, so a per-contact suffix would limit them to
one contact. The contract's `guaranteedRows` are untouched: these are new rows above the
`100000` int-identity floor, and they join the contract groups rather than inventing a fourth.

### Credentials

**No password is in the data.** The `AccessUser` predicate excludes `AccessUserPassword` and
the runtime login columns, so no row file carries a password or a hash (the column name
appears only in `AccessUser/_meta.yml`'s column list). After the deserialize and host
restart, set each persona's password through the Management API `UserSetPassword` command
with the Foundry's `tools/secrets/Set-DemoCredential.ps1`, once per persona `100101`,
`100102` and `100103`. It sets the password, proves sign-in and stores the credential outside
the repo. The route is the same for a local and an online build, and merge never overwrites
the password it set.

Their history is 12 orders across the `OrderFlowId 1` states — `OS1 New`, `OS2 Completed`,
`OS3 Rejected`. States from another flow (`OS12`/`OS13`/`OS14`) are deliberately unused: an
order carrying one reads as a broken record in the Commerce grids. `OrderCompletedDate` is
set only on a Completed order.

**All twelve orders belong to the buyer** (`OrderCustomerAccessUserId` = `100101`). This is
not a simplification, it is what the page permits: the customer-centre page grants group
`1325` and the *My orders* scope and nothing else, measured on DW 10.28.10, so the four
orders once stamped with the CSR (`100102`) or the admin (`100103`) were invisible to every
persona that can open the page — the order list rendered eight of twelve. **CSR and admin
reach a buyer's orders by impersonating the buyer**, which is the platform's own path for
it. Widening the page grants instead would demo a permission model Dynamicweb does not use,
and would put a second account's orders in a list the page labels *My orders*.

The personas, their memberships and their orders arrive in the merge deserialize, after the
base replace tree has landed the shop, currency and permission groups they reference. DW
caches identity state at startup, so the personas become first-class on the host restart the
catalogue already requires.

## Imagery

Every product carries an image, because a PLP card and a PDP with no image are an empty
grey box on the two pages the design gate measures. The tiles are this layer's own neutral
SVGs — a flat industrial-green plate with the concept word and the `TRUVIO` wordmark, a few
hundred bytes each — one per concept subgroup, plus the per-product pair `tc-tile-<concept>-<nnnn>.svg` and
`tc-detail-<concept>-<nnnn>.svg` that #1157 generates, all shipped under
`files/Images/TruvioCommerce/products/` and served from
`/Files/Images/TruvioCommerce/products/`. They are **data**: a product row points at a
file. Presentation is still `theme-default`'s.

The photographic brand assets stay in the Distribution's
[`brand/brand-assets.manifest.json`](../../brand/brand-assets.manifest.json), fetched at
brand time and sha256-pinned. They are deliberately **not** committed here.

### The PDP gallery, and the optional photographic upgrade

**The committed default is self-contained.** Each of the 60 gallery rows
(`TC-GAL-*`) points at the concept tile of **its own master's band**, and it is
DERIVED rather than assigned: the band and the index are read off that master's own
`TC-DETAIL-*` default row, so a row cannot name another band's picture. A master therefore
carries three distinct pictures — its own tile at sort 0, its own detail image at sort 1
(both from #1157), and its band's concept tile at sort 2 — and three is the ceiling this
layer can ship, which is why the second gallery row was retired rather than repointed: a
fourth slide could only repeat one of the three.

Two earlier states this replaced, both of which counted green throughout. The 1.2.0 gallery
pointed at five photographs under `Images/TruvioCommerce/scenic/` that no layer ships, so a
clean install seeded 84 rows of 404 (Foundry #1137). The 1.5.x gallery pointed at shipped,
categorised, correctly-served tiles drawn from a twelve-tile ring by seed position — 84 of
the 276 rows in asset category `Images` put another band's illustration on the product, a
Price-structures tile on a Bundles kit among them. The 1.7.x script guarded the band
itself, not just the path and the count, and the YAML carries that guarded end state.

### Linking to a PDP

A demo link to a product detail page carries **both** ids:

```
/en-us/shop?GroupID=TCGRP-BUNDLES&ProductID=TCPROD0042
```

`/en-us/shop?ProductID=...` on its own **404s** for a bundle master. The shop page resolves
a product through the group context, so a `ProductID` with no `GroupID` beside it has no
group to resolve in and the request never reaches a product. Every demo link, probe and
assert in this layer's documentation therefore carries the pair, and a link that drops the
`GroupID` is a broken link rather than a slower one.

**The photographs are an optional upgrade, run by hand after the brand step.** The brand
step already downloads the manifest's five `scenic/` targets into the host `Files` tree;
once they are on disk, `tools/truvio-gallery-photos.sql` converges the gallery rows onto
them:

```
1. compose the edition (the merge deserialize lands the gallery rows as concept tiles)
2. run the brand step (brand-assets.manifest.json -> Files/Images/TruvioCommerce/scenic/)
3. confirm the five scenic files are on disk
4. sqlcmd -i layers/truvio-demo/tools/truvio-gallery-photos.sql
```

It lives under `tools/`, **not** under `merge/_sql/`, and it is deliberately neither YAML
nor a declared `sql[]` script: anything the layer ships is something the composer delivers,
and delivering this before step 2 recreates exactly the defect it exists to retire. It is a
local-only SQL tool. SQL cannot test for a file
on disk, so the gate for this one is a human step and the script says so in its header.

Attachment is carried on two surfaces: `EcomDetails` (the attachment the storefront reads,
`DetailValue` + `DetailIsDefault`, the shape observed on a live DW 10.28 host) and the legacy
`EcomProducts.ProductImage*` columns with the same value. A target build that lacks those
legacy columns strips them with a serializer schema-drift warning. Each tile lands on at most 11 product rows and is default
on every one of them, so it can never become the un-audited extra gallery slot the
bulk-attach-tail check (#125) looks for.

## Key families

This layer owns the `TC*` family: `TCGRP-*`, `TCPROD*`, `TCVG-*`, `TCVGR-*`, `TCVO-*`,
`TC-PRICE-*`, `TC-BOM-*`, `TC-DETAIL-*`, `TC-HOVER-*`, `TC-GAL-*`, `TC-DOC-*`, `TCREL-*`,
`TCO-*` and the `tc_*` product categories. Its int-identity rows sit at reserved ids above
the contract's `100000` floor, and the serializer writes them verbatim with
`IDENTITY_INSERT`: `AccessUser` `100100`-`100103`, `EcomDetailsGroup` `100110` (`Images`)
and `100111` (`Manuals`), `EcomFieldDisplayGroups` `100120` (`tc_specs`), `EcomStockUnit`
`100201`-`100260`. The storefront binds the asset categories and the display group by system
name, not by id. They are disjoint from
`sample-data`'s reserved `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`
([`base.contract.json`](../base/base.contract.json) `idRules.reservedFixtureKeys`) and from
the `PACK-<NAME>-` prefix additions use. Int-identity rows respect the contract's 100000
floor. The next base release should record `TC*` in `reservedFixtureKeys` alongside
`FIXT*`; until it does, this README and `layer.json` `costHints.reservedKeyPrefixes` are
the statement of ownership.

## Traps the rows obey

- **Language row.** Every catalogue row is `ENU`. `LANG1` is the latent second `en-US`
  row, retained only for `reference_category` and one legacy sample order; rows written
  under it are invisible on the storefront.
- **Primary page id stays 0.** No group sets a primary page id. Swift's
  `ProductDetailRenderGrid` prefers a group's `PrimaryPageId` over the detail page, and a
  value aimed at the shop/PLP page makes the catalogue app re-render that page inside
  itself — the recursion guard then empties **every** PDP in the shop, with no error
  anywhere (Foundry #186). The base ships `ShopProductPrimaryPageId = 0` on `SHOP1` for
  the same reason.
- **No empty groups.** Navigation visibility and URL reachability are independent
  surfaces, so an empty group still serves a live 200 PLP reading "0 products" (#177).
  Every group here carries products: a master's primary relation is its subgroup, and it
  carries a second non-primary relation to its top group (15 products per top group).
- **Host restart.** The group-product relation cache is held in-process (#29) and the
  predicates name no service caches, so restart the host after the merge deserialize and
  before building the product index.
- **Merge, never overwrite.** Every predicate is merge: a re-deserialize fills unset columns
  on its own keys and converges rather than duplicating. Merge cannot rename or delete, so a
  host seeded by a pre-1.5 script keeps its stale values; editions deserialize to fresh
  hosts.

## Activation

Composed by the `swift-demo` edition (with `sampleData: false`); `base-swift` and
`gate-fixtures` never compose it (the foundational baseline stays catalogue-free).

The PLP and PDP read the `TruvioCommerce` product repository that `surface-swift` ships under
`repositories/`. Until a delivery path stages a layer's `repositories/` tree (Foundry #1218),
stage it by hand before judging the storefront; an empty PLP on such a host is that gap, not
a missing row here.
