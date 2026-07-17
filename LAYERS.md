# Layers & Editions catalog

Everything this Distribution ships, proven on **Swift 2.4** / **DW 10.28.1-PreRelease** (rolling latest-only; the stable re-prove sweep runs when DW 10.28 reaches NuGet stable). See
[GLOSSARY.md](GLOSSARY.md) for the vocabulary. Every layer validates against
[`layers/layer.schema.json`](layers/layer.schema.json); every edition against
[`editions/edition.schema.json`](editions/edition.schema.json), enforced by CI.

## Taxonomy — prefix = kind, traceable to the workflow lanes

The layer directory name carries its **kind as a prefix**, so a clone reads its own shape
and every layer traces to a lane of the ecosystem workflow (the Foundry's
[`docs/WORKFLOW.md`](https://github.com/justdynamics/Truvio.Commerce.Foundry/blob/main/docs/WORKFLOW.md)).

| Prefix | Kind | Workflow lane / component | What it carries |
|--------|------|---------------------------|-----------------|
| `base` | base | Foundry → Distribution (the privileged scaffold) | FRAMEWORK-ONLY since 3.0.0 (Swift 2.4 base split): framework SQL + `base.contract.json`; zero catalog, zero content. Singleton. |
| `feature-*` | feature | Distribution (published content) | A customization-tier bundle; MAY carry a compile-optional `src/` provider. |
| `surface-*` | surface | Distribution → Storefront (frontend leg) | What a frontend needs — headless content + Delivery-API, or a content area. |
| `theme-*` | theme | Distribution (presentation) | Disk-overlay-only presentation (SPEC-06), applied via `themes[]`. The distribution ships **one** default theme (`theme-default`) — the neutral starting point of every customer re-skin. |
| `sample-data` | sample-data | Distribution (published content) | Demo identities + demo shop catalog + contract data, shipped as SQL. Singleton. |

## Layers (`layers/<name>/`)

| Layer | Kind | Version | Role |
|-------|------|---------|------|
| `base` | base | 3.0.1 | The privileged FRAMEWORK-ONLY scaffold (Swift 2.4 base split): the 16 framework SQL sets + [`base.contract.json`](layers/base/base.contract.json); **zero catalog, zero content areas** — all Swift content moved to `surface-swift`. Proven on DW 10.28.1-PreRelease. |
| `surface-swift` | surface | 1.0.1 | The Swift storefront content surface (born in the base split): both content areas (EN + NL), the entire merge tree, `UrlPath`, and its own 128 Swift v2.4.0 item-type XMLs (self-contained). 1.0.1 adds the durable image-crop normalization + the List-mode PLP card (SKU/price/stock/qty/add-to-cart). Proven on DW 10.28.1-PreRelease. |
| `sample-data` | sample-data | 2.0.2 | Demo identities (buyer/CSR) + the demo product catalog (EcomProducts 20 / EcomGroups 3) + contract pricing, shipped as SQL under `merge/_sql/`. 2.0.2 seeds the delivered order + RMA link for `feature-rma`. Activated when an edition sets `sampleData: true`. |
| `feature-reordering` | feature | 1.0.0 | Quick Order pad + Express Buy nav/pages (data-only, zero customCode). Split from `feature-reordering-pricing`. |
| `feature-pricing` | feature | 1.0.0 | Quantity-break tiers + customer-contract pricing; carries the compile-optional `ReorderingPricingQtyBreakProvider`. Split from `feature-reordering-pricing`. |
| `feature-rma` | feature | 1.0.0 | Data-only RMA seed (`EcomRmas`); the My-returns page + RMA state machine are OOTB (surface-swift + platform). |
| `feature-reordering-pricing` | feature | 1.2.1 | **DEPRECATED / tombstoned** (superseded by `feature-reordering@1.0.0` + `feature-pricing@1.0.0`). Retained one release for consumers still pinning 1.2.1; no edition composes it. Do not add to new editions. |
| `feature-subscription-orders` | feature | 1.1.1 | Subscriptions + recurring-order scheduled task. |
| `feature-bom-configurator` | feature | 1.1.1 | Kit / BOM configurator. |
| `surface-headless` | surface | 2.3.3 | Headless content surface: `Headless_*` item types + repository + Delivery-API. 2.3.3 migrates the serializer config off the retired Deploy/Seed predicate modes. |
| `surface-dap-portal` | surface | 1.0.3 | Digital Asset Portal content area (area 26, ~32 Swift-v2 pages). Content-only add-on surface. 1.0.3 migrates the serializer config off the retired modes and re-points the Area style ids to the shipped `default` scheme. |
| `theme-default` | theme | 1.0.2 | The one presentation layer (disk-only, SPEC-06): the CSS that makes stock Swift look great — neutral palette, quiet buttons, Inter typography, and the header menu-bar affordance folded in. 1.0.2 adds durable image-height caps for `Swift-v2_Image` bands + slider covers. The starting point of every customer re-skin, not a brand. |

## Editions (`editions/<name>.json`)

A build is a composition: `from` a base + an ordered `add` (+ `surfaces`, `sampleData`, `themes`).

| Edition | Composition | Status |
|---------|-------------|--------|
| `base-only` | base 3.0.1 alone — framework-only, no theme (nothing to skin) | **Proven on DW 10.28.1-PreRelease** — API/DB-level proof (framework row-count contract + /Admin/; zero pages by design). |
| `swift-demo` | base + `surface-swift` + five feature layers (`feature-reordering` + `feature-pricing` + `feature-rma` + `feature-subscription-orders` + `feature-bom-configurator`) + sample data + theme `default` | **Proven on DW 10.28.1-PreRelease** — the full Swift 2.4 storefront (20 / 3 / 96). |
| `headless-demo` | base + `surface-headless` + sample data | **Proven on DW 10.28.1-PreRelease** — headless Delivery-API (A1–A9), ZERO Swift design-package dependency. |
| `dap-portal` | base + `surface-dap-portal` + sample data | **Proven on DW 10.28.1-PreRelease** — the DAP content surface (area 26). |

## Consuming

This repo is **git-clone distribution** — there are no release archives. Clone it, pick an
edition, and activate its layers against a Dynamicweb 10 host (the Foundry harness does
this end-to-end). Modes are `replace` (source-wins) / `merge` (field-level). Annotated tags
`layers/<name>/<semver>` and `editions/<name>/<semver>` pin each proven artifact to the gate
run + Swift version it was proven against.
