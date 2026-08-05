# Changelog — sample-data

## 2.1.0

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

## 2.0.2

RMA demo interplay (P3, RUN-DISTRIBUTION-QUALITY item E). `catalog.sql` gains a section 5
seeding **one delivered order** `FIXT-ORDER-RMA1` (`OrderStateId OS2` Completed, buyer
`98745621`, order line on `FIXT0001`) for the new `feature-rma` layer to return against, plus
the `EcomRmaOrderLines` link to `feature-rma`'s `EcomRmas` request `PACK-RMA-0001`. The link is
seeded here (not in feature-rma) because `EcomRmaOrderLines.RmaOrderLineId` is an int IDENTITY PK
the serializer cannot natural-key insert; raw SQL handles it deterministically. No DB FK on the
RMA tables (verified), so the cross-layer header/link order is free. Idempotent DELETE+INSERT on
the demo keys; no impact on the EcomProducts=20 / EcomGroups=3 / EcomCountries=96 row-count
contract, and harmless (orphan link + one extra completed order) in editions without feature-rma.

## 2.0.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). SQL verified against the 10.28 schema (solution custom columns come from cleandb-align-schema.sql, applied by every gate run before the catalog). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

## 2.0.0

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
