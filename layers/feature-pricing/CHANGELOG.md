# Changelog — feature-pricing

## 1.0.0

Initial release. Split out of `feature-reordering-pricing@1.2.1` (P3 feature surgery,
RUN-DISTRIBUTION-QUALITY decision D-D) as the **pricing half**:

- **Moved verbatim from the combined layer:** the `customCode` block, `csLedger`, the
  six `configRows`, `src/ReorderingPricingQtyBreakProvider.cs`, and all
  `merge/_sql/PACK-RPP-*` rows (group `PACK-RPP-GRP1`, products `PACK-RPP-PROD1/PROD2`,
  their group/shop relations, and `EcomPrices` `PACK-RPP-0001..0004`). Keys unchanged so
  the provider, tier ladder, and contract row behave identically.
- **`cart-price` probes re-pointed:** both moved off `/swift-2/quick-order` (the reordering
  layer's Quick Order page) onto **`/swift-2/cart/`** — the last coupling between the two
  split layers, and only ever a test-authoring convenience. Contract/tier pricing resolves
  on any add-to-cart surface; `/swift-2/cart/` is provided by surface-swift in every edition.
- **Dropped (moved to `feature-reordering`):** the Quick Order pad item type + template + page
  fragment, the `http-body-contains` / `sku-validation` probes, and the `fragmentContent` +
  `knownCycleLimitations`. This layer ships **no content** — SQL rows + provider only.

`swiftVersion` claim 2.4.0; proven on the `swift-demo` edition (see the RUN-DISTRIBUTION-QUALITY
P3 gate stamp). Contract price 1399 charged uncompiled; tier 4500@qty5 charged when compiled.
