# bom-configurator

Pack #3 — a bill-of-materials (BOM) product configurator delivered on the Phase 6-8
feature-pack contract. A shopper picks one product per BOM slot (radio groups) on a
pack-owned Product Detail page and adds the configured kit to the cart; the DW cart
engine creates the parent order line plus one child line per slot, each carrying its
slot identity natively in `EcomOrderLines.OrderLineBOMItemId`.

Everything the storefront does here is **stock platform + stock Swift 2.3**. The pack
is **zero custom code** — it contributes only BOM structure data, page/template wiring,
one ~10-line render-grid template, and gate proof.

## Requirements delivered

- **PK3-01** — single-group BOM on the PDP, template-only, native BOM loops.
- **PK3-02** — multi-group with per-child disambiguation via the engine-native
  `EcomOrderLines.OrderLineBOMItemId` slot id (no custom code).
- **PK3-03** — gate PASS via a declared `bom-cart-lines` probe + `configRows` EXISTS probes.

## PK3-01 requirement reinterpretation — "native BOM loops"

The roadmap/REQUIREMENTS text for PK3-01 names the legacy `BOMConfigurators` /
`BOMProducts` template-tag loops (the documentation-9 / Rapido tag API). Swift 2.3
ships the **current** native surface instead: `product.GetBomConfiguration()` returning
`BomConfigurationViewModel { Groups, Items }`, rendered by the stock
`Paragraph/Swift-v2_ProductBom.cshtml`. This pack delivers "native BOM loops" via that
ViewModel surface — the same native platform capability, current API. The verifier must
accept this equivalence (recorded here and in 09-02-SUMMARY.md per orchestrator decision).

## What ships

| Artifact | Purpose |
|----------|---------|
| `baseline-fragment/seed/_sql/EcomProductItems/PACK-BOM3-000{1,2,3}.yml` | BOM slot rows (Rule-A data, LRN-BASE-07 recipe) |
| `baseline-fragment/seed/_sql/EcomProducts/PACK-BOM-0001.yml` | Rule-B multi-group parent product (ProductType 2) |
| `baseline-fragment/seed/_content/.../Kit Configurator` | page A — hosts the `eCom_ProductCatalog` app |
| `baseline-fragment/seed/_content/.../Kit Configurator Detail` | page B — hidden detail grid (stock BOM + AddToCart paragraphs) |
| `templates/Designs/Swift-v2/eCom/ProductCatalog/PackBomDetailRenderGrid.cshtml` | pack Z-copy render-grid (new path only) |

## BOM data (LRN-BASE-07 recipe)

Each slot is one `EcomProductItems` row: `ProductItemBomGroupId` = a **real** `EcomGroups`
id (that group's products become the radio options), `ProductItemDefaultProductId` set,
`ProductItemBomProductId` / `ProductItemBomVariantId` blank.

| Slot row | Parent | Group (pack-owned) | Default | (a non-default option) |
|----------|--------|--------------------|---------|------------------------|
| PACK-BOM3-0002 | `PACK-BOM-0001` | `PACK-BOM-FORKS` | `PACK-BOM-FORK-1` | `PACK-BOM-FORK-2` |
| PACK-BOM3-0003 | `PACK-BOM-0001` | `PACK-BOM-RACKS` | `PACK-BOM-RACK-1` | `PACK-BOM-RACK-2` |

- **Catalog-self-sufficient (1.1.0).** The baseline is scaffolding-only, so this pack ships
  **all** of its own catalog: the Rule-B parent `PACK-BOM-0001` (`ProductNumber 10004kit`,
  `ProductType=2`), two child groups (`PACK-BOM-FORKS`, `PACK-BOM-RACKS`) each with two
  pack-owned child products, and the parent's own group `PACK-BOM-GRP1` — all bound to
  `SHOP1` via `EcomShopGroupRelation`. No base products/groups (PROD290/GROUP49/GROUP161/
  10028/10119) are referenced.
- **PK3-02** rides `PACK-BOM-0001` with two slots in the two pack-owned groups; the
  `bom-cart-lines` probe selects the non-default child in each slot to prove per-child
  native disambiguation (`OrderLineBOMItemId` = slot id, `OrderLineProductId` = the chosen
  non-default).
- The prior **PK3-01** slot on base `PROD290` is removed — a slot on a base product has no
  meaning once the baseline ships no catalog; both slots now ride the pack's own parent.

## PDP wiring (no base edits)

Base PDP content is base-owned, so the pack provides its own detail path:

1. **Page A "Kit Configurator"** hosts an `eCom_ProductCatalog` app whose `ProductTemplate`
   is the pack Z-copy `PackBomDetailRenderGrid.cshtml`.
2. That template stashes the `ProductViewModel` into `Context.Items["ProductDetails"]` and
   `RenderGrid(GetPageIdByNavigationTag("PackBomDetail"))`.
3. **Page B "Kit Configurator Detail"** (hidden, `navigationTag=PackBomDetail`) carries the
   stock `Swift-v2_ProductBom` + `Swift-v2_ProductAddToCart` paragraphs. `Swift-v2_ProductBom`
   renders one radio group per slot (marker `js-product-bom-configurator`); stock `swift.js`
   appends the checked `.js-bom-variant` selections to the add-to-cart POST.

Two pages (not one) because rendering the same page that hosts the app recurses — this is
exactly how the base Shop app / Product Details pages are split.

> **Note — bare BOM cards.** `Swift-v2_ProductBom` renders each option's card via
> `RenderGrid(ListComponentSource)`. This pack ships `ListComponentSource` empty for
> cross-Swift-version robustness (a hardcoded base component page id would drift across
> 2.1/2.2/2.3), so the radio inputs render with minimal labels. Pointing `ListComponentSource`
> at the base "Product List Card" component page for full product cards is a **swift/2.3.1**
> theme-polish item.

## Pack-parent PDP behavior

Adding `PACK-BOM-0001` from a plain Shop PDP (no configurator UI) creates default child
sub-lines from the slots' `ProductItemDefaultProductId`. This is acceptable — the cart
renders them natively and the defaults are sensible — but route the demo journey through
the pack "Kit Configurator" page, where the shopper actually chooses.

## PK3-02 disambiguation — engine-native, zero custom code

Each BOM child order line carries its slot identity natively in
`EcomOrderLines.OrderLineBOMItemId` (= the slot's `EcomProductItems.ProductItemId`),
populated by the platform when the cart engine expands the BOM. Per-child slot
disambiguation is therefore answerable from data alone — no subscriber, no stamp,
no `.cs`. The gate's `bom-cart-lines` probe proves this directly: each declared slot
selection lands a child line matched on `OrderLineBOMItemId = <slot>` AND
`OrderLineProductId = <non-default product>` (LRN-BOM-02).

> An earlier revision shipped a `Cart.Line.Added` subscriber that additionally stamped
> `OrderLineFieldValues["PackBomSlot"]`. It was removed: the native `OrderLineBOMItemId`
> is the proven, canonical disambiguation, so the stamp was dead weight — and dropping it
> makes the pack zero-custom-code.

Showing the slot label **in the cart UI** would require overlaying a base cart template,
which is forbidden (base cart templates must not be overlaid). Cart-visible slot labels are
queued as a **swift/2.3.1** / theme idea (RESEARCH Open Question 1).

## Before publish — mandatory storefront-render UAT gate (WR-02)

The `bom-cart-lines` probe ships with **`renderProof: false`** in `pack.json`
(behaviorProbes[0]). This is deliberate and permanent for this harness: the clean-room
gate does **not** provision the storefront index, so the harness genuinely cannot render
the configurator page. `renderProof` therefore stays `false` — do not flip it.

The cost of `renderProof: false` is that no in-gate check exercises the render path:
the `js-product-bom-configurator` marker + radio-group check and the template
compile-error-dump guard (`Test-PackBodyIsTemplateErrorDump`) are skipped, so a Razor
compile failure or a broken `GetPageIdByNavigationTag("PackBomDetail")` lookup in
`PackBomDetailRenderGrid.cshtml` would ship green from the harness.

**Because pack.json cannot carry a comment (strict, schema-validated JSON), this is the
binding note:** the configurator storefront render is a **real-Swift-host UAT item**
tracked as `09-UAT.md` item 1. **Publish is BLOCKED until that morning UAT gate is
human-verified on a provisioned Swift host** — confirm the configurator page renders,
shows one radio group per BOM slot, and adds the configured kit to the cart. Do not open
or merge the downstream baseline/theme PR for this pack before that UAT item passes.

This pack ships **no `.cs`** — `csLedger` is empty. The baseline stays configuration and
content only, and so does the pack.
