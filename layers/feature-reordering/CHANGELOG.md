# Changelog — feature-reordering

## 1.0.0

Initial release. Split out of `feature-reordering-pricing@1.2.1` (P3 feature surgery,
RUN-DISTRIBUTION-QUALITY decision D-D) as the **data-only reordering half**:

- **Kept from the combined layer, verbatim:** the Quick Order pad item type
  (`PackQuickOrderPad`), its template, and the Quick Order page fragment in both the
  `Swift 2` (area 3) and `Swift 2 Nederlands` (area 27) nav trees; the `http-body-contains`
  probes on `/swift-2/quick-order` (addmulti) and `/swift-2/express-buy`
  (`ExpressBuySearchForm`); both `/swift-2/quick-order` `knownCycleLimitations`.
- **Removed (moved to `feature-pricing`):** all catalog + `EcomPrices` rows
  (`PACK-RPP-*`), the `customCode` block, the `ReorderingPricingQtyBreakProvider`
  source, and the two `cart-price` probes. This layer now ships **zero custom code and
  zero SQL rows** — content fragment only.
- **`sku-validation` re-pointed:** off the removed `RPP-TIER-01` (a pricing-owned product)
  onto the sample-data catalog SKU `FIXT-0001` — the pad validates the shop's real catalog,
  not a private throwaway product.
- **Template cleanup:** dropped the pricing-specific "Volume pricing" tier table (it
  referenced the moved `PACK-RPP-0001..0003` rows) and neutralised the paste-example SKUs
  to `FIXT-0001` / `FIXT-0002`.

`swiftVersion` claim 2.4.0; proven on the `swift-demo` edition (see the RUN-DISTRIBUTION-QUALITY
P3 gate stamp).
