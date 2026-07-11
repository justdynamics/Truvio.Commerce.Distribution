# Changelog — sample-data

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
