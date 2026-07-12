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
| `feature-*` | feature | Distribution (published content) | A customization-tier bundle; MAY carry a compile-optional `src/` provider. |
| `surface-*` | surface | Distribution → Storefront (frontend leg) | What a frontend needs — headless content + Delivery-API, or a content area. |
| `theme-*` | theme | Distribution (presentation) | Disk-overlay-only presentation (SPEC-06), applied via `themes[]`. The distribution ships **one** default theme (`theme-default`) — the neutral starting point of every customer re-skin. |
| `sample-data` | sample-data | Distribution (published content) | Demo identities + demo shop catalog + contract data, shipped as SQL. Singleton. |

## Layers (`layers/<name>/`)

| Layer | Kind | Version | Role |
|-------|------|---------|------|
| `base` | base | 2.4.1 | The privileged scaffold every edition builds on. Ships the framework + [`base.contract.json`](layers/base/base.contract.json); **zero sample catalog** (scaffolding-only). |
| `sample-data` | sample-data | 2.0.0 | Demo identities (buyer/CSR) + the demo product catalog (EcomProducts 20 / EcomGroups 3) + contract pricing, shipped as SQL under `merge/_sql/`. Activated when an edition sets `sampleData: true`. |
| `feature-reordering-pricing` | feature | 1.2.0 | Quick-order reordering + quantity-break pricing (compile-optional provider). |
| `feature-subscription-orders` | feature | 1.1.0 | Subscriptions + recurring-order scheduled task. |
| `feature-bom-configurator` | feature | 1.1.0 | Kit / BOM configurator. |
| `surface-headless` | surface | 2.3.1 | Headless content surface: `Headless_*` item types + repository + Delivery-API. |
| `surface-dap-portal` | surface | 1.0.0 | Digital Asset Portal content area (area 26, ~32 Swift-v2 pages). Content-only add-on surface. |
| `theme-default` | theme | 1.0.0 | The one presentation layer (disk-only, SPEC-06): the CSS that makes stock Swift look great — neutral palette, quiet buttons, Inter typography, and the header menu-bar affordance (carets, hover/active, reachable dropdowns) folded in. The starting point of every customer re-skin, not a brand. |

## Editions (`editions/<name>.json`)

A build is a composition: `from` a base + an ordered `add` (+ `surfaces`, `sampleData`, `themes`).

| Edition | Composition | Status |
|---------|-------------|--------|
| `base-only` | base + theme `default`; no sample data (no catalog, no identities) | **Proven** — the empty-shop scaffold (EcomProducts 0 / 0 / EcomCountries 96). |
| `swift-demo` | base + feature-reordering-pricing + feature-subscription-orders + feature-bom-configurator + sample data + theme `default` | **Proven** — the full Swift storefront (20 / 3 / 96). |
| `headless-demo` | base + `surface-headless` + sample data | **Proven** — headless Delivery-API (A1–A9). |
| `dap-portal` | base + `surface-dap-portal` + sample data | **Proven** — the DAP content surface (area 26), gate-proven end-to-end on Swift 2.3. |

## Consuming

This repo is **git-clone distribution** — there are no release archives. Clone it, pick an
edition, and activate its layers against a Dynamicweb 10 host (the Foundry harness does
this end-to-end). Modes are `replace` (source-wins) / `merge` (field-level). Annotated tags
`layers/<name>/<semver>` and `editions/<name>/<semver>` pin each proven artifact to the gate
run + Swift version it was proven against.
