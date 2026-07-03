# Changelog — swift/2.3

All notable changes to the Swift 2.3 baseline. Versions track the source solution version;
the patch digit bumps for content fixes.

## 2.3.1

- **ProductPriceTable partial on the PDP (Deploy — 2 content files, EN + NL):** added a
  `paragraph-c1-3.yml` paragraph to the `Product Components/Product Info (right side)`
  component page in both language areas, wiring Swift's stock `Swift-v2_ProductPriceTable`
  partial into the standard product detail page. The partial is data-driven and renders only
  when a product carries multiple `EcomPrices` rows (quantity tiers or, for a signed-in buyer,
  a contract price such as this baseline's `PriceUserCustomerNumber` demo row) — single-price
  products render no artifact. Zero custom code; authored via live host round-trip.
- Clean-room attestation: run `20260703-131045` on DW 10.26.9 / Swift 2.3.0 — deploy + seed
  deserialize HTTP 200, zero escalations, row-count parity (EcomProducts 2051, EcomGroups 316,
  EcomCountries 96), all 3 demo themes PASS, frontend smoke all-2xx.

## 2.3.0

- Initial published baseline for Swift 2.3 on DW 10.26.9.
- Verified round-trip across three Swift platform releases (2.3.0, 2.2.0, 2.1.0) — deploy +
  seed deserialize HTTP 200, zero escalations, row/page parity (both language areas 123 pages,
  EcomProducts 2051), frontend smoke all-2xx.
- Deploy tree (18 predicates): Swift 2 content area + Customer Center groups + ecommerce
  reference tables (countries, currencies, languages, VAT, shops, payments, shipping, order
  state machine) + URL routing.
- Seed tree (19 predicates): customer-owned content subtrees (Homepage, Site chrome, About,
  Starter blog posts, Find dealers, footers, Newsletter examples) + starter catalog (groups,
  products, variants, discounts) + contract pricing.
- Includes the Dutch language layer (`Swift 2 Nederlands`).
- Config: `config/swift-2.3.json`.

## Changes from swift/2.2

- **Customer Center access control (Deploy — 1 new predicate):** added `Customer center user
  groups` Deploy predicate (`AccessUser` rows with `AccessUserType = 2` for the `Customers`,
  `Account Admin`, and `CSR` groups). Customer Center pages carry inline page-permission
  bindings that resolve against these groups on deserialize and write the access gate into
  `UnifiedPermission`, so the Customer Center is only accessible to authenticated members of
  the appropriate group.
- **Contract pricing (Seed — 1 new predicate):** added `Demo contract pricing` Seed predicate
  (`EcomPrices` rows scoped by `PriceUserCustomerNumber`). Demonstrates customer-specific
  contract pricing through the standard DW 10 price resolver without custom code.
- **DW platform version:** bumped from DW 10.26.7 (swift/2.2) to DW 10.26.9 (swift/2.3).
- **Predicate count:** 17 Deploy + 18 Seed (swift/2.2) → 18 Deploy + 19 Seed (swift/2.3).
