# Changelog — feature-reordering

## 1.0.1

**Investigation + ledger entry: the Quick Order `Template file not found` log line is stock-Swift
platform noise, not a layer defect (Foundry #143).** No functional change — the pad template, the item
type, the content fragment and every probe declaration are untouched. What ships is the finding,
recorded in the README so it is not re-derived a third time.

- **Mechanism.** `EcommerceTemplateHelper.TryCreateTemplate(templateName, folder, fallbackFolder, …)`
  probes the module's *default* folder `eCom/ProductCatalog/List/` first and LOGS that miss, then
  resolves the template from the *design* folder `Designs/Swift-v2/eCom/ProductCatalog/` where Swift
  ships it. The render succeeds on the fallback; the logged root path is the first probe.
- **Swift-wide, not layer-scoped.** The same gate host logs the identical entry for stock Swift's
  Express Buy (`ID=31`), the Shop PLP (`ID=51`, `ProductListRenderGrid.cshtml`) and
  `feature-bom-configurator`'s Kit Configurator (`ID=211`/`217`, `PackBomDetailRenderGrid.cshtml` — a
  template that layer ships at the design path, and which renders).
- **The Quick Order feed does render.** `sku-validation` reads the module-only feed body
  (`Content.CreateFeedContent`), and it PASSed with "resolved ProductNumber 'FIXT-0001' in an
  ExpressBuySearchResponse article" in Foundry run `20260727-193109` — the same run whose log carries
  the error. A missing list template returns an empty feed body and FAILs that probe.
- **Both proposed fixes rejected**, with reasons carried in the README. A root-path template copy would
  fork a stock Swift template *onto the first-tried probe path* and win over the design copy for every
  consumer, including `surface-swift`'s Express Buy page, which this layer does not own. Repointing
  `<ProductListTemplate>` breaks the markup contract the pad's validation and the probe both read, and
  a `merge` (destination-wins) fragment cannot reliably repoint an already-existing paragraph.
- **Harness note.** The issue's proposed lookout ("template-error log empty after smoke") cannot be
  adopted as written — it fails on stock Swift's own pages. Scope it to templates no design folder in
  the composition ships, or drop it.
- **`feature-reordering-pricing` deliberately NOT touched.** The tombstoned bundle carries the identical
  Quick Order paragraph, but the finding is that the paragraph is *correct*, so there is nothing to
  change there; and its deprecation entry pins the contract "no version bump — `1.2.1` is retained
  unchanged for one release for downstream editions still pinning it". A README-only edit would either
  break that pin (bumping) or ship an undeclared divergence (not bumping). The ledger entry lives here,
  in the live successor.

Runtime proof: the upcoming Foundry gate run on the current latest Swift.

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
