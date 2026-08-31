# sample-data (kind: sample-data)

Optional demo content for an edition: the canonical **demo identities** (buyer, CSR,
permission groups) plus a small deterministic **demo shop catalog**. Together they give
authenticated flows (customer center, reorder, subscription checkout, contract pricing)
and catalog flows (browse, cart, facets) real rows to run against — the base ships zero
catalog and no frontend users.

**Activated by `sampleData: true`** in an edition (`editions/<name>.json`). Singleton —
there is exactly one sample-data layer.

## What it contains

All content ships as executable SQL under [`merge/_sql/`](merge/_sql/README.md):

- **`identities.sql`** — permission groups `1325 Customers` / `1270 Account Admin` /
  `1292 CSR` (`AccessUser` rows, type 2), buyer `1328` (customer number `98745621`) and
  CSR `1326` (customer number `7789765`), and their group memberships. Apply **before
  the host starts** (DW caches identity state at startup). Demo credentials are supplied
  as `sqlcmd` variables — they are not repo content.
- **`catalog.sql`** — the demo catalog for `SHOP1`/`ENU`/`EUR`: 3 groups
  (`FIXTGRP1..3`), 20 products (14 masters `FIXT0001..0014` + 6 `Size` variants), a
  qty-tier price ladder on `FIXT0002`, and the buyer-scoped contract price
  `FIXT-PRICE-CONTRACT` on `FIXT0001`. Apply **after the base layer deserialize**, then
  restart the host so the startup catalog cache includes the rows. Deterministic counts:
  `EcomProducts` 20, `EcomGroups` 3.
- **`email-stats.sql`** — the email-marketing statistics backfill. Per campaign email:
  one `EmailMessage` send-log row, 24 `EmailRecipient` sends (2 of them bounced), 3
  tracked `OMCLink` rows and 13 `OMCLinkClick` clicks split 5/4/4, so the backend
  Marketing dashboards do not read 0 sent / 0 clicked. Discovery-driven over whatever
  `EmailMarketingEmail` rows the composition has, and a clean no-op when it has none.
- **`demo-clock.sql`** — the demo clock. Creates `_demoClock(Id, AnchoredTo)`, the
  exclusion and per-column guard tables, `usp_DemoClockShift`, and the daily RunSql
  scheduled task `Truvio demo clock`. Apply **last**, so it anchors everything the other
  scripts seeded.

## Declaration (`layer.json` → `sql[]`)

The serializer manifest has no provider for a whole script: its only `providerType`s are
`Content` and `SqlTable`, and `SqlTable` is row-per-YAML under `_sql/<Table>/<key>.yml`.
A loose `.sql` therefore carries no `merge-manifest.json` entry and the manifest-driven
deserialize never executes it. A composer that reads only the manifests stages the four
files and silently runs nothing, which is how `sampleData: true` could compose green and
land an empty catalogue.

`layer.json` `sql[]` is the discovery contract that replaces that guesswork: it names each
script, the phase it must run in (`before-host-start` / `after-replace-deserialize`), the
order within that phase, whether the host must be restarted afterwards, and every `sqlcmd`
variable the caller has to supply. An applier that cannot supply a declared variable must
fail before executing the script, never substitute a blank. The schema is
[`layers/layer.schema.json`](../layer.schema.json) → `sql`.

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

Both scripts are idempotent and transactional; every id is a base-contract anchor
([`layers/base/base.contract.json`](../base/base.contract.json)), and the key prefixes
`FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` are reserved for this layer.
