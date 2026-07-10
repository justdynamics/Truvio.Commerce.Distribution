# Layers & Editions catalog

Everything this Distribution ships, proven on **Swift 2.3** (rolling latest-only). See
[GLOSSARY.md](GLOSSARY.md) for the vocabulary. Every layer validates against
[`layers/layer.schema.json`](layers/layer.schema.json); every edition against
[`editions/edition.schema.json`](editions/edition.schema.json), enforced by CI.

## Taxonomy — prefix = kind, traceable to the workflow lanes

The layer directory name carries its **kind as a prefix**, so a clone reads its own shape
and every layer traces to a lane of the ecosystem workflow (the Foundry's
[`docs/WORKFLOW.md`](https://github.com/justdynamics/Truvio.Commerce.Foundry/blob/main/docs/WORKFLOW.md)).

| Prefix | Kind | Workflow lane / component | What it carries |
|--------|------|---------------------------|-----------------|
| `base` | base | Foundry → Distribution (the privileged scaffold) | Framework + `base.contract.json`; zero catalog. Singleton. |
| `catalog-*` | catalog | Distribution (published content) | Shop catalog content (groups / products / prices). |
| `feature-*` | feature | Distribution (published content) | A customization-tier bundle; MAY carry a compile-optional `src/` provider. |
| `surface-*` | surface | Distribution → Storefront (frontend leg) | What a frontend needs — headless content + Delivery-API, or a content area. |
| `theme-*` | theme | Distribution (presentation) | A **swappable** brand: disk-overlay-only (SPEC-06), applied one at a time via `themes[]`. |
| `overlay-*` | overlay | Distribution (presentation) | An **always-on affordance**: disk-overlay-only (SPEC-06), layered on top of the active theme via `overlays[]`. |
| `sample-data` | sample-data | Distribution (published content) | Demo identities + contract data. Singleton. |

## Layers (`layers/<name>/`)

| Layer | Kind | Version | Role |
|-------|------|---------|------|
| `base` | base | 2.4.1 | The privileged scaffold every edition builds on. Ships the framework + [`base.contract.json`](layers/base/base.contract.json); **zero sample catalog** (scaffolding-only). |
| `catalog-fixture` | catalog | 1.0.0 | The demo product catalog (EcomProducts 20 / EcomGroups 3). Added by editions that need products. |
| `sample-data` | sample-data | 1.0.0 | Demo identities (buyer/CSR) + contract data. Activated when an edition sets `sampleData: true`. |
| `feature-reordering-pricing` | feature | 1.2.0 | Quick-order reordering + quantity-break pricing (compile-optional provider). |
| `feature-subscription-orders` | feature | 1.1.0 | Subscriptions + recurring-order scheduled task. |
| `feature-bom-configurator` | feature | 1.1.0 | Kit / BOM configurator. |
| `surface-headless` | surface | 2.3.1 | Headless content surface: `Headless_*` item types + repository + Delivery-API. |
| `surface-dap-portal` | surface | 1.0.0 | Digital Asset Portal content area (area 26, ~32 Swift-v2 pages). Content-only add-on surface. |
| `theme-tech-saas` | theme | 2.3.0 | Tech/SaaS brand theme (disk-only, SPEC-06). |
| `theme-fashion-lifestyle` | theme | 2.3.0 | Fashion/Lifestyle brand theme. |
| `theme-industrial-b2b` | theme | 2.3.0 | Industrial B2B brand theme. |
| `overlay-nav-polish` | overlay | 1.0.0 | Header menu-bar affordance overlay: carets, hover/active, reachable dropdowns. Always-on `overlays` entry (not a `themes` swap); layers on top of any theme. Icons opt-in. |

## Editions (`editions/<name>.json`)

A build is a composition: `from` a base + an ordered `add` (+ `surfaces`, `sampleData`, `themes`, `overlays`).

| Edition | Composition | Status |
|---------|-------------|--------|
| `base-only` | base + theme `tech-saas`; no catalog, no identities | **Proven** — the empty-shop scaffold (EcomProducts 0 / 0 / EcomCountries 96). |
| `swift-demo` | base + catalog-fixture + feature-reordering-pricing + feature-subscription-orders + feature-bom-configurator + sample data + all 3 themes + `nav-polish` affordance overlay | **Proven** — the full Swift storefront (20 / 3 / 96). |
| `headless-demo` | base + catalog-fixture + `surface-headless` + sample data | **Proven** — headless Delivery-API (A1–A9). |
| `dap-portal` | base + catalog-fixture + `surface-dap-portal` | **Proven** — the DAP content surface (area 26), gate-proven end-to-end on Swift 2.3. |

## Consuming

This repo is **git-clone distribution** — there are no release archives. Clone it, pick an
edition, and activate its layers against a Dynamicweb 10 host (the Foundry harness does
this end-to-end). Modes are `replace` (source-wins) / `merge` (field-level). Annotated tags
`layers/<name>/<semver>` and `editions/<name>/<semver>` pin each proven artifact to the gate
run + Swift version it was proven against.

## Migration — the taxonomy big-bang rename

Layer directories were renamed to prefix-equals-kind. Old tags stay immutable; editions
re-pin to the new names. Layer **versions carry over unchanged** (a rename is not a content change).

| Old name | New name |
|----------|----------|
| `fixture-catalog` | `catalog-fixture` |
| `headless` | `surface-headless` |
| `dap-portal` | `surface-dap-portal` |
| `reordering-pricing` | `feature-reordering-pricing` |
| `subscription-orders` | `feature-subscription-orders` |
| `bom-configurator` | `feature-bom-configurator` |
| `theme-nav-polish` | `overlay-nav-polish` (kind `theme` → `overlay`) |

Unchanged: `base`, `sample-data`, `theme-tech-saas`, `theme-fashion-lifestyle`, `theme-industrial-b2b`.
