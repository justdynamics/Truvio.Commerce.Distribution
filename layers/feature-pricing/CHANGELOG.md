# Changelog — feature-pricing


## 1.1.0

**Zero catalogue rows (Foundry 960).** The two demo products (`PACK-RPP-PROD1/2`), their group
(`PACK-RPP-GRP1`), the group and shop relations and all four `EcomPrices` rows moved to the
`sample-data` layer (`merge/_sql/feature-fixtures.sql`), ids unchanged. This layer's whole merge
tree went with them, so `fragmentModes`, `fragmentTables` and the six catalogue `configRows` are
gone from `layer.json`: what remains is the compile-optional price provider and the two `cart-price`
probes, which address the same product ids as before.

Why the rows could not stay: `sampleData: false` is the distribution's statement that the shop is
empty, and a layer that ships catalogue rows outside that toggle makes the statement false without
the gate being able to say which layer did it. Self-sufficiency was a real argument — the base
ships no catalogue — but it bought a per-layer catalogue at the cost of the one invariant every
consumer reads.

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
