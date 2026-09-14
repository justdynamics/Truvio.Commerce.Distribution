# sample-data (kind: sample-data)

Optional demo content for an edition: the canonical **demo identities** (buyer, CSR,
permission groups) plus a small deterministic **demo shop catalog**. Together they give
authenticated flows (customer center, reorder, subscription checkout, contract pricing)
and catalog flows (browse, cart, facets) real rows to run against — the base ships zero
catalog and no frontend users.

**Activated by `sampleData: true`** in an edition (`editions/<name>.json`). Singleton —
there is exactly one sample-data layer.

> **These rows are GATE FIXTURES, not browsable demo content** (owner decision, Foundry
> #1074, 2026-09-13). They exist so the gate's layer-declared `behaviorProbes` have stable,
> id-addressable subjects. Composed into a storefront a prospect opens they are a measured
> defect: 12 bare `Placeholder product.` strings on the unfiltered `/en-us/shop` (#1174) and
> 6 `Sample Group N` values in the PLP facet rail, the permanent `STOCKCOPY-01` design FAIL
> (#1127 / #1134). On the Swift surface exactly ONE edition therefore sets
> `sampleData: true` - **`editions/gate-fixtures.json`** - and `swift-demo`, the edition a
> prospect sees, sets it false and takes its catalogue from the `truvio-demo` layer.
> `headless-demo` and `dap-portal` keep it true: neither renders the Swift PLP or its facet
> rail.

## What it contains

The identities, the catalogue, the contract price and the delivered order ship as
serialized **merge-mode SqlTable rows** under `merge/_sql/<Table>/<key>.yml`, listed in
[`merge/merge-manifest.json`](merge/merge-manifest.json) and selected by the 14 merge
predicates in [`config/sample-data-2.4.json`](config/sample-data-2.4.json). The ordinary
merge deserialize delivers them, on a local install and on an online build alike. 93 rows
over 14 tables:

| Table | Rows | What |
|---|---:|---|
| `AccessUser` | 2 | buyer `1328` IMCUser (customer number `98745621`) and CSR `1326` IMCSalesrep (customer number `7789765`), at the ids the base contract names |
| `AccessUserGroupRelation` | 2 | `1328` in `1325 Customers`, `1326` in `1292 CSR` (the groups are base rows) |
| `EcomGroups` | 8 | `FIXTGRP1..3` + the 5 `PACK-*` feature fixture groups |
| `EcomShopGroupRelation` | 8 | each group bound to `SHOP1` |
| `EcomVariantGroups` | 1 | the `Size` axis `FIXTVG1` |
| `EcomVariantsOptions` | 3 | `FIXTVO1..3` |
| `EcomProducts` | 28 | 14 masters `FIXT0001..0014` + 6 `Size` variant rows + 8 `PACK-*` feature fixture products |
| `EcomGroupProductRelation` | 22 | one per master |
| `EcomVariantOptionsProductRelation` | 6 | `FIXT0013` / `FIXT0014` x the three options |
| `EcomPrices` | 8 | the qty-tier ladder on `FIXT0002`, the buyer contract price `FIXT-PRICE-CONTRACT` on `FIXT0001`, 4 `PACK-RPP-*` prices |
| `EcomProductItems` | 2 | the two BOM slots on `PACK-BOM-0001` |
| `EcomOrders` | 1 | the delivered order `FIXT-ORDER-RMA1` for buyer `98745621` |
| `EcomOrderLines` | 1 | `FIXT-ORDER-RMA1-1` |
| `EcomRmaOrderLines` | 1 | the link from `PACK-RMA-0001` (feature-rma) to that line, at reserved id `100301` |

**Passwords are not data.** The `AccessUser` predicate excludes `AccessUserPassword` and the
login and recovery columns, so no row file carries a password or a hash, and merge never
overwrites a password set later. After the deserialize, set the buyer and CSR passwords
through Management API `UserSetPassword`, recycle the host (the call does not invalidate the
in-process user cache), and verify with `POST /dwapi/users/authenticate`.

**Dates are frozen at harvest.** `ProductCreated`, `ProductUpdated`, `OrderDate`,
`OrderCompletedDate` and `OrderLineDate` carry the values of the harvest host: `FIXT-ORDER-RMA1`
has `OrderDate` 2026-08-15 and `OrderCompletedDate` 2026-08-17 and ages from there. On a local
install the demo clock moves them forward; an online build has no clock.

Two scripts stay SQL, declared in `layer.json` `sql[]`, **local installs only**:

- **`email-stats.sql`**: the email-marketing statistics backfill. Per campaign email: one
  `EmailMessage` send-log row, 24 `EmailRecipient` sends (2 of them bounced), 3 tracked
  `OMCLink` rows and 13 `OMCLinkClick` clicks split 5/4/4, so the backend Marketing
  dashboards do not read 0 sent / 0 clicked. Discovery-driven over whatever
  `EmailMarketingEmail` rows the host has, and a clean no-op when it has none. Not
  serializable in a useful form: the grid binding it writes is an UPDATE of a pre-existing
  `EmailMarketingEmail` row no layer owns, which a merge row cannot express.
- **`demo-clock.sql`**: the demo clock. Creates `_demoClock(Id, AnchoredTo)`, the exclusion
  and per-column guard tables, `usp_DemoClockShift`, and the daily RunSql scheduled task
  `Truvio demo clock`. Not serializable: DDL, a stored procedure, and a task that only works
  with that procedure. The `Truvio demo clock` task therefore exists on local-channel hosts
  only.

## Declaration (`layer.json`)

`fragmentModes: ["merge"]`, the 14 `fragmentTables` and six `configRows` (existence probes for
`FIXT0001`, `PACK-BOM-0001`, user `1328`, `FIXT-PRICE-CONTRACT`, `FIXT-ORDER-RMA1` and the BOM
slot `PACK-BOM3-0002`) describe the rows. `costHints` records the reserved key prefixes, the
reserved int ids and the expected row counts.

`sql[]` declares the two local-only scripts. The serializer manifest has no provider for a
whole script: its only `providerType`s are `Content` and `SqlTable`. A loose `.sql` therefore
carries no `merge-manifest.json` entry and the manifest-driven deserialize never executes it.
`sql[]` names each script, its phase (`after-merge-deserialize`: both read rows the merge
delivers), its order (email statistics first, so the clock anchors the seeded send dates) and
whether the host must be restarted afterwards. An online build has no SQL surface and reports
both scripts with no route. The schema is [`layers/layer.schema.json`](../layer.schema.json)
-> `sql`.

## The demo clock

Every seeded demo decays: orders, carts, send history and campaign windows all carry
absolute dates, so a demo a few weeks old shows stale orders and empty dashboards. The
clock fixes it with an **anchor table plus a whole-day uniform shift** — one row per
shifter recording the date the fixtures were anchored to, and a procedure that moves every
operational date column by `DATEDIFF(day, AnchoredTo, today)` and then re-anchors.

- **Whole-day and uniform** is the whole trick: the same integer shift on every column
  preserves intra-day ordering and every relative gap, so send → click and order → ship
  sequences stay coherent. It is idempotent (`+1` then `-1` nets zero) and catch-up safe.
- **Date columns are discovered from `sys.columns` on every run, never hardcoded.** Every
  commerce feature spells its timestamps differently, and discovery is what keeps the
  shifter correct across a platform upgrade.
- **Config and logging tables are excluded** (`dbo._demoClockExclusion`), `ScheduledTask`
  first among them: `TaskNextRun` is what the scheduler reads, and the clock's own run
  history has to stay readable.
- **State-marker columns carry their own guard** (`dbo._demoClockGuard`). `GiftCardCancel`
  cancels a card by rewriting `GiftCardExpiryDate` to now and keeping the balance, so on a
  cancelled card that column is a cancellation timestamp; the shipped guard shifts only
  cards still in the future, and a cancelled card still reads inactive after a run.
- **A second date-shifting task must own its own anchor row.** The shifter re-anchors to
  today, so a second task reading row `Id=1` at a later slot sees delta 0 and shifts
  nothing, forever, while reporting Success.
- **The anchor is derived from the fixtures, not the apply date.** The rows ship with the
  dates of the harvest day, so the first anchor is `FIXT-ORDER-RMA1`'s `OrderDate` + 30 days
  (the order was harvested 30 days old), falling back to the apply date when the order is
  absent. Anchored to the apply date, the clock would never make up the harvest age.
- **Prove it with a rewind-and-run, never a bare run.** A fresh anchor is legitimately
  delta 0 on its first pass, so "the task ran" is not evidence that "the task shifts".
  Rewind the anchor by one day, run, and assert a known timestamp advanced by exactly one
  day. The recipe is at the foot of `demo-clock.sql`.

## Neutralization convention (what the demo-facing values say)

This layer ships **no real-world product domain**. Every value a visitor can see is a
**function-descriptive placeholder** — it names what the row exists to demonstrate, and
the build replaces it per customer:

| Value | Convention | Example |
|---|---|---|
| Product name | `Sample Product NN — <role>` | `Sample Product 02 — Qty Tiers` |
| Group name | `Sample Group N — <function>` | `Sample Group 3 — Variant Demos` |
| Short description | one sentence naming what the product demos, opening with `Placeholder` | `Placeholder product. Demonstrates the quantity-break price ladder (tiers at 5, 10 and 25).` |

The literal word **`Placeholder`** is deliberate: it is the machine-detectable marker a
design gate scans for (`/placeholder/i`), so any placeholder left un-replaced at
build time fails loudly instead of shipping to a prospect. The same convention governs
visible copy in `surface-swift` and `surface-dap-portal`.

Roles currently in use: `Master`, `Size Variants`, `Contract Price`, `Qty Tiers`. The
contract-price product is also the line item on the seeded delivered order the RMA flow
returns against.

**Keys are not placeholders.** `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` ids, product
numbers, prices, the variant structure and the row counts are the layer's determinism
contract and never change with a rename.

The two SQL scripts are idempotent and transactional; every id is a base-contract anchor
([`layers/base/base.contract.json`](../base/base.contract.json)), and the key prefixes
`FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` are reserved for this layer.
