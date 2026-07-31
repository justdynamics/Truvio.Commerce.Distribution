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
