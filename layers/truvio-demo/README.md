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

| Shape | Example |
|---|---|
| Top group | `Data Models`, `Commerce`, `Content`, `Users` |
| Subgroup | `Variants`, `Completeness`, `Workflows`, `Price Structures`, `Assortments`, `Discounts`, `Pages`, `Paragraphs`, `Item Types`, `Groups`, `Permissions`, `Impersonation` |
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

All content is executable T-SQL under [`merge/_sql/`](merge/_sql/), declared in
[`layer.json`](layer.json) `sql[]` (a loose script carries no serializer manifest entry,
so an undeclared script is staged and never executed — see the sample-data layer's
README for the full account of that trap).

| Script | Phase / order | What it lands |
|---|---|---|
| `truvio-catalog.sql` | `after-replace-deserialize` / 5 | 16 groups, 60 masters + 36 variant rows, 40 prices, 1 BOM kit (2 slots), 2 services, 4 categories × 7 category fields, 180 field values |
| `truvio-identities.sql` | `after-replace-deserialize` / 6 | The B2B account `100100`, the three personas `100101`/`100102`/`100103`, 6 memberships, 12 orders `TCO-0001`…`TCO-0012` with 20 lines |
| `truvio-images.sql` | `after-replace-deserialize` / 7 | The 12 concept tiles attached as the default image of all 96 `TCPROD` rows |

Phases and orders sit **after** `sample-data`'s (which occupies 1–4 in the same phase),
so on an edition carrying both, the brand rows land last and the two never interleave.

## Identities

Three personas on the fictional `truvio-demo` domain — `buyer@`, `csr@`, `admin@` — all
members of one B2B account (`Truvio Demo Account`, customer number `TC-100200`, the number
the contract price resolves against) and each joined to the base-contract permission group
its role maps to: `1325 Customers`, `1292 CSR`, `1270 Account Admin`. The contract's
`guaranteedRows` are untouched — these are new rows above the `100000` int-identity floor,
and they join the contract groups rather than inventing a fourth. Passwords arrive as
`sqlcmd` variables (`TruvioBuyerPassword`, `TruvioCsrPassword`, `TruvioAdminPassword`), so
no credential is repo content.

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

`truvio-identities.sql` runs `after-replace-deserialize` rather than `before-host-start`
(where `sample-data`'s identities live) because its orders FK the shop, currency and
catalogue rows. DW caches identity state at startup, so the personas become first-class on
the host restart the catalogue already requires — one restart covers both scripts.

## Imagery

Every product carries an image, because a PLP card and a PDP with no image are an empty
grey box on the two pages the design gate measures. The tiles are this layer's own neutral
SVGs — a flat industrial-green plate with the concept word and the `TRUVIO` wordmark, a few
hundred bytes each — one per concept subgroup, shipped under
`files/Images/TruvioCommerce/products/tc-tile-<concept>.svg` and served from
`/Files/Images/TruvioCommerce/products/`. They are **data**: a product row points at a
file. Presentation is still `theme-default`'s.

The photographic brand assets stay in the Distribution's
[`brand/brand-assets.manifest.json`](../../brand/brand-assets.manifest.json), fetched at
brand time and sha256-pinned. They are deliberately **not** committed here.

Attachment writes two surfaces: `EcomDetails` (the attachment the storefront reads —
`DetailValue` + `DetailIsDefault`, the shape observed on a live DW 10.28 host) with its
column list resolved from `sys.columns`, and the legacy `EcomProducts.ProductImage*`
columns where a build still has them, with the same value. A missing `EcomDetails` table
is a loud failure, never a skip. Each tile lands on at most 11 product rows and is default
on every one of them, so it can never become the un-audited extra gallery slot the
bulk-attach-tail check (#125) looks for.

## Key families

This layer owns the `TC*` family: `TCGRP-*`, `TCPROD*`, `TCVG-*`, `TCVO-*`, `TC-PRICE-*`,
`TC-BOM-*`, `TCO-*` and the `tc_*` product categories. They are disjoint from
`sample-data`'s reserved `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`
([`base.contract.json`](../base/base.contract.json) `idRules.reservedFixtureKeys`) and from
the `PACK-<NAME>-` prefix additions use. Int-identity rows respect the contract's 100000
floor. The next base release should record `TC*` in `reservedFixtureKeys` alongside
`FIXT*`; until it does, this README and `layer.json` `costHints.reservedKeyPrefixes` are
the statement of ownership.

## Traps these scripts obey

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
- **Host restart.** The group-product relation cache is held in-process (#29), so these
  raw inserts are invisible until the host restarts. `layer.json` declares
  `requiresHostRestart: true` for every script here.
- **Idempotent by existence guard.** Every insert is `IF NOT EXISTS`-guarded on its own
  key, so a re-run converges rather than duplicating or deleting. Nothing here deletes.

## Activation

Composed by the `swift-demo` edition beside `sample-data`; `base-swift` never composes it
(the foundational baseline stays catalogue-free).
