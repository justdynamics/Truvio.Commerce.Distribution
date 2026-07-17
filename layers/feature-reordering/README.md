# feature-reordering — Reordering+ (quick order + express buy)

Data-only feature layer (**zero custom code**) delivering the B2B **reordering** capability on top of
the framework base + surface-swift Swift content: a **Quick Order pad** and the stock **Express Buy**
buy-it-again surface. Split out of the retired `feature-reordering-pricing` bundle (P3, RUN-DISTRIBUTION-QUALITY,
decision D-D); the pricing half moved to `feature-pricing`.

## What the layer delivers

| Capability | How | Artifact |
|------------|-----|----------|
| Quick-order pad (CAND-01) | SKU + quantity grid with paste-from-Excel/CSV (tab-separated first, comma/semicolon fallback), feed-based SKU validation, one-click `cartcmd=addmulti` cart fill — all client-side parsing, zero custom server code | `templates/Designs/Swift-v2/Paragraph/PackQuickOrderPad.cshtml`, `itemtypes/ItemType_PackQuickOrderPad.xml`, Quick Order page fragment, shipped in **both** the `Swift 2` (area 3, `/swift-2/quick-order`) and `Swift 2 Nederlands` (area 27) nav trees, navigationTag `QuickOrderPadPage` |
| Editable buy-it-again (empty-cart safe) | **The stock Express Buy `?OrderID=` prefill flow the base/surface already routes to** — `OrderViewSearchList.cshtml` renders the Reorder button to `ExpressBuyPage?OrderID=<id>`; the flow prefills an editable quantity grid and submits `cartcmd=addmulti`, which needs no active cart. The layer PROVES this flow (probes on `/swift-2/express-buy`), it does not rebuild it | `layer.json` asserts (`http-body-contains` on Express Buy, criticalPath) |

## Zero custom code

This layer ships **no `src/` and no `customCode` block**. The pad's paste-parse, SKU validation, and
cart fill are entirely client-side JavaScript over the stock DW cart engine (`cartcmd=addmulti`). All
pricing behaviour — quantity-tier and customer-contract pricing, and the compile-optional
`ReorderingPricingQtyBreakProvider` — lives in the sibling **`feature-pricing`** layer. The pad renders
whatever user-scoped price the index feed returns and posts to the cart unchanged.

## Catalog dependency (sample-data)

The pad validates SKUs against the gate-provisioned **Products** repository feed (the same feed Express
Buy uses). The `sku-validation` probe resolves the sample-data catalog SKU **`FIXT-0001`**, so the
layer's live probes require an edition with `sampleData: true` (e.g. `swift-demo`). The **content
fragment deserialize is isolated** (the Quick Order pages attach only to base-provided structural
ancestors — area, Navigation, Secondary Navigation — never re-shipping them, per the base-contract
content-path collision rule); only the runtime feed probe needs the demo catalog. The layer ships **no
catalog rows of its own** — reordering is about the shop's real catalog.

## Fragment portability

The Quick Order page fragment attaches under **base/surface-provided structural ancestors** — the area
(`Swift 2` = area 3, `Swift 2 Nederlands` = area 27), the `Navigation` / `Navigation/Secondary
Navigation` structural-stub pages, plus the fragment-root `area.yml` and `templates.manifest.yml`. Those
paths are **surface-owned anchors**: the fragment references them by path and deliberately leaves them to
the surface (additions bind to the base contract, never re-ship it). Consequence: the fragment
deserializes cleanly onto any edition that composes base + surface-swift first, but is **not** standalone
onto a bare host. To apply on a renamed area, rename the `merge/_content/<area>` folders and update the
matching `areaName`/`areaId` in `merge/merge-manifest.json` + `fragmentContent[].areaId` in `layer.json`.

## Probe expectations

| Probe | Expectation |
|-------|-------------|
| `http-body-contains /swift-2/quick-order` | addmulti form marker (`name="cartcmd" ... value="addmulti"`) |
| `http-body-contains /swift-2/express-buy` | `id="ExpressBuySearchForm"` (buy-it-again surface, anonymous) |
| `sku-validation /swift-2/quick-order` (sku `FIXT-0001`) | the Quick Order feed resolves the sample-data catalog SKU — proves the pad's index-feed wiring |

## Known cycle limitation (declared, gate honors as WARN)

Inherited verbatim from `feature-reordering-pricing` 1.1.0: after a deactivate→reactivate cycle the
2-page area 3 + area 27 NL-mirror Quick Order fragment does not fully re-bind (the page 404s), so the two
`/swift-2/quick-order` cycle asserts (`http-body-contains` + `sku-validation`, phase `behavior-cycle`)
fail in the gate's Step 12c cycle leg. Declared in `layer.json` `knownCycleLimitations`; the gate records
them as **`KNOWN-LIMITATION` (WARN)**, not FAIL. Scope: toggle-cycle only — first activation and every
first-activation assert are unaffected, and `/swift-2/express-buy` survives the cycle. A full
re-deserialize of the base + this layer restores the page.

## Provenance

Split from `feature-reordering-pricing@1.2.1` (P3, 2026-07-17). Fresh `1.0.0`. The combined layer is
tombstoned (deprecated, kept one release).
