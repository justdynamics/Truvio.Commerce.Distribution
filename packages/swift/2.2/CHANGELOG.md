# Changelog — swift/2.2

All notable changes to the Swift 2.2 baseline. Versions track the source
solution version; the patch digit bumps for content fixes.

## 2.2.0

- Initial published baseline for Swift 2.2 on DW 10.26.7.
- Deploy tree (17 predicates): Swift 2 content area + ecommerce reference tables
  (countries, currencies, languages, VAT, shops, payments, shipping, order state
  machine) + URL routing.
- Seed tree (18 predicates): customer-owned content subtrees (Homepage, Site
  chrome, About, Starter blog posts, Find dealers, footers, Newsletter examples)
  + starter catalog (groups, products, variants, discounts).
- Includes the Dutch language layer (`Swift 2 Nederlands`).
- Verified round-trip into a clean database: deploy + seed deserialize HTTP 200,
  zero escalations, row/page parity (both language areas 123 pages, EcomProducts
  2051), frontend smoke all-2xx.
- Config: `config/swift-2.2.json`.
