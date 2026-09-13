# feature-reordering — Reordering+ (quick order + express buy)

Data-only feature layer (**zero custom code**) delivering the B2B **reordering** capability on top of
the framework base + surface-swift Swift content: a **Quick Order pad** and the stock **Express Buy**
buy-it-again surface. Split out of the retired `feature-reordering-pricing` bundle (P3, RUN-DISTRIBUTION-QUALITY,
decision D-D); the pricing half moved to `feature-pricing`.

## What the layer delivers

| Capability | How | Artifact |
|------------|-----|----------|
| Quick-order pad (CAND-01) | SKU + quantity grid with paste-from-Excel/CSV (tab-separated first, comma/semicolon fallback), feed-based SKU validation, one-click `cartcmd=addmulti` cart fill — all client-side parsing, zero custom server code | `templates/Designs/Swift-v2/Paragraph/PackQuickOrderPad.cshtml`, `itemtypes/ItemType_PackQuickOrderPad.xml`, Quick Order page fragment, shipped in the `Swift 2` (area 3, `/en-us/quick-order`) nav tree, navigationTag `QuickOrderPadPage` |
| Editable buy-it-again (empty-cart safe) | **The stock Express Buy `?OrderID=` prefill flow the base/surface already routes to** — `OrderViewSearchList.cshtml` renders the Reorder button to `ExpressBuyPage?OrderID=<id>`; the flow prefills an editable quantity grid and submits `cartcmd=addmulti`, which needs no active cart. The layer PROVES this flow (probes on `/en-us/express-buy`), it does not rebuild it | `layer.json` asserts (`http-body-contains` on Express Buy, criticalPath) |

## Zero custom code

This layer ships **no `src/` and no `customCode` block**. The pad's paste-parse, SKU validation, and
cart fill are entirely client-side JavaScript over the stock DW cart engine (`cartcmd=addmulti`). All
pricing behaviour — quantity-tier and customer-contract pricing, and the compile-optional
`ReorderingPricingQtyBreakProvider` — lives in the sibling **`feature-pricing`** layer. The pad renders
whatever user-scoped price the index feed returns and posts to the cart unchanged.

## Catalog dependency (sample-data)

The pad validates SKUs against the **ProductsFrontend** repository feed (the same feed Express Buy, the
Shop PLP and the Kit Configurator use). `ProductsFrontend/Products.query` is what the Swift files
overlay deploys and what every working sibling `eCom_ProductCatalog` paragraph binds; a
`<IndexQuery>` naming a repository that is not on disk yields an empty feed body with HTTP 200 and no
error, so every SKU reads "Unknown SKU". The `sku-validation` probe resolves the sample-data catalog SKU **`FIXT-0001`**, so the
layer's live probes require an edition with `sampleData: true` (e.g. `swift-demo`). The **content
fragment deserialize is isolated** (the Quick Order pages attach only to base-provided structural
ancestors — area, Navigation, Secondary Navigation — never re-shipping them, per the base-contract
content-path collision rule); only the runtime feed probe needs the demo catalog. The layer ships **no
catalog rows of its own** — reordering is about the shop's real catalog.

## Fragment portability

The Quick Order page fragment attaches under **base/surface-provided structural ancestors** — the area
(`Swift 2` = area 3), the `Navigation` / `Navigation/Secondary
Navigation` structural-stub pages, plus the fragment-root `area.yml` and `templates.manifest.yml`. Those
paths are **surface-owned anchors**: the fragment references them by path and deliberately leaves them to
the surface (additions bind to the base contract, never re-ship it). Consequence: the fragment
deserializes cleanly onto any edition that composes base + surface-swift first, but is **not** standalone
onto a bare host. To apply on a renamed area, rename the `merge/_content/<area>` folders and update the
matching `areaName`/`areaId` in `merge/merge-manifest.json` + `fragmentContent[].areaId` in `layer.json`.

## Probe expectations

| Probe | Expectation |
|-------|-------------|
| `http-body-contains /en-us/quick-order` | addmulti form marker (`name="cartcmd" ... value="addmulti"`) |
| `http-body-contains /en-us/express-buy` | `id="ExpressBuySearchForm"` (buy-it-again surface, anonymous) |
| `sku-validation /en-us/quick-order` (sku `FIXT-0001`) | the Quick Order feed resolves the sample-data catalog SKU — proves the pad's index-feed wiring |

## `Template file not found` on the Quick Order page is platform noise, not a layer defect (Foundry #143)

Every render of a page carrying an `eCom_ProductCatalog` paragraph writes one line into
`Files/System/Log/Templates/Errors/`:

```
Template file not found. Filename='eCom/ProductCatalog/List/ExpressBuySearchResponse.cshtml',
Path='...\wwwroot\Files\Templates\eCom\ProductCatalog\List\ExpressBuySearchResponse.cshtml',
Layout='/Files/Templates/Designs/Swift-v2/Swift-v2_Page.cshtml', Url=...Default.aspx?ID=207
```

The stack names `EcommerceTemplateHelper.TryCreateTemplate(templateName, folder, fallbackFolder, …)`.
That helper probes the module's **default** folder (`eCom/ProductCatalog/List/`) first and logs the miss,
then resolves the template from the **design** folder (`Designs/Swift-v2/eCom/ProductCatalog/`) where
Swift actually ships it. The render succeeds on the fallback — the log line is the first probe, not a
failed render.

Swift-wide, not layer-scoped. The same gate host logs the identical entry for:

| Page | Template | Owner |
|------|----------|-------|
| `ID=31` Express Buy | `ExpressBuySearchResponse.cshtml` | stock Swift + `surface-swift` |
| `ID=51` Shop (PLP) | `ProductListRenderGrid.cshtml` | stock Swift + `surface-swift` |
| `ID=211` / `ID=217` Kit Configurator | `PackBomDetailRenderGrid.cshtml` | `feature-bom-configurator` (ships it at the **design** path) |
| `ID=207` Quick Order | `ExpressBuySearchResponse.cshtml` | this layer |

And the Quick Order feed demonstrably renders. The `sku-validation` probe reads the **module-only** feed
body (`Content.CreateFeedContent`, not the page), and it PASSes with *"resolved ProductNumber `FIXT-0001`
in an ExpressBuySearchResponse article"* on the same host, in the same run that logged the error (Foundry
run `20260727-193109`). A missing list template returns an empty feed body and FAILs that probe.

Both candidate fixes are therefore **rejected**:

- **Shipping a copy at the root `templates/eCom/ProductCatalog/List/` path** puts a layer-frozen fork of a
  stock Swift template on the probe path that is tried *first* — so it would win over the design copy for
  *every* consumer of `ExpressBuySearchResponse.cshtml`, including `surface-swift`'s Express Buy page,
  which this layer does not own. It buys a silenced log line and pays with a cross-layer template fork
  that goes stale at the next Swift release.
- **Repointing `<ProductListTemplate>`** breaks the markup contract that both the pad's client-side
  validation and the `sku-validation` probe read (`article` carrying `.productNumber` / `.productId` /
  `.productPrice`), and the paragraph ships in a `merge` (destination-wins) fragment, so the repoint would
  not reliably reach a host on which the paragraph already exists.

Consequence for the harness: a lookout asserting *"the template-error log is empty after smoke"* cannot be
adopted as written — it fails on stock Swift's own Shop and Express Buy pages. Scope such a check to
entries whose template no design folder in the composition ships, or drop it.

## Known cycle limitation (declared, gate honors as WARN)

Inherited verbatim from `feature-reordering-pricing` 1.1.0: after a deactivate→reactivate cycle the
2-page area 3 Quick Order fragment does not fully re-bind (the page 404s), so the two
`/en-us/quick-order` cycle asserts (`http-body-contains` + `sku-validation`, phase `behavior-cycle`)
fail in the gate's Step 12c cycle leg. Declared in `layer.json` `knownCycleLimitations`; the gate records
them as **`KNOWN-LIMITATION` (WARN)**, not FAIL. Scope: toggle-cycle only — first activation and every
first-activation assert are unaffected, and `/en-us/express-buy` survives the cycle. A full
re-deserialize of the base + this layer restores the page.

## Provenance

Split from `feature-reordering-pricing@1.2.1` (P3, 2026-07-17). Fresh `1.0.0`. The combined layer is
tombstoned (deprecated, kept one release).
