# Changelog — feature-reordering

## 1.0.3

Every probe and criticalPath moves from the `/swift-2/` area segment to the `/en-us/` culture root (Foundry #965). `AreaUrlName` `swift-2` is decorative on a single-area host: Dynamicweb prefixes the area segment only when more than one area competes for the host and otherwise serves the culture segment, so every `/swift-2/` path answered 404 on a healthy, fully deserialized site while the same pages answered under `/en-us/`. Page targets are unchanged; only the prefix moves. README probe tables follow.

## 1.0.2

**Fix: the Quick Order pad binds `ProductsFrontend`, the repository that is actually on disk
(Foundry #576).** The pad's `eCom_ProductCatalog` paragraph shipped
`<IndexQuery>/Files/System/Repositories/Products/Products.query</IndexQuery>`, and no install
provisions a `Products` repository. A query file that is not on disk returns HTTP 200 with an EMPTY
body rather than an error, so the pad's own validation feed
(`GET <padPage>?feed=true&q=<sku>`) matched nothing and every typed or pasted SKU, including
baseline ones, read "Unknown SKU — excluded from cart". The pad could never fill a cart.

- **Change.** `merge/_content/Swift 2/Navigation/Secondary Navigation/Quick Order/grid-row-1/paragraph-c1-1.yml`
  now names `/Files/System/Repositories/ProductsFrontend/Products.query`, byte-for-byte the binding
  every working sibling already uses: `surface-swift`'s Express Buy and Shop PLP, and
  `feature-bom-configurator`'s Kit Configurator.
- **`repositoryName` corrected** to `ProductsFrontend` in `layer.json` so the declaration matches the
  binding the layer ships. The `sku-validation` probe exercises this feed.
- **Why the gate missed it.** The 1.0.x probes asserted that `/swift-2/quick-order` emits
  `name="cartcmd" value="addmulti"`, which stayed true for the whole time the pad was dead. The
  `sku-validation` probe is the one that reads the feed body; it is the composition-failure detector
  for this class of defect.
- **Verification on any install:** `SELECT ParagraphId, ParagraphModuleSettings FROM Paragraph WHERE
  ParagraphModuleSystemName = 'eCom_ProductCatalog'`, then confirm every `<IndexQuery>` names a
  repository that is on disk. Probe the feed with `curl -L` (the `/Default.aspx?ID=` form
  301-redirects to the friendly URL and returns 0 bytes without it).
- **`feature-reordering-pricing` deliberately NOT touched.** It carries the identical defect but is
  tombstoned at `1.2.1` and pinned by no edition; its deprecation entry holds the version unchanged
  for one release.

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
