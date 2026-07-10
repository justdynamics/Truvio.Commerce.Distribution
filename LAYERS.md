# Layers & Editions catalog

Everything this Distribution ships, proven on **Swift 2.3** (rolling latest-only). See
[GLOSSARY.md](GLOSSARY.md) for the vocabulary. Every layer validates against
[`layers/layer.schema.json`](layers/layer.schema.json); every edition against
[`editions/edition.schema.json`](editions/edition.schema.json), enforced by CI.

## Layers (`layers/<name>/`)

| Layer | Kind | Version | Role |
|-------|------|---------|------|
| `base` | base | 2.3.0 | The privileged scaffold every edition builds on. Ships the framework + [`base.contract.json`](layers/base/base.contract.json); **zero sample catalog** (scaffolding-only). |
| `fixture-catalog` | catalog | 1.0.0 | The demo product catalog (EcomProducts 20 / EcomGroups 3). Added by editions that need products. |
| `sample-data` | sample-data | 1.0.0 | Demo identities (buyer/CSR) + contract data. Activated when an edition sets `sampleData: true`. |
| `reordering-pricing` | feature | 1.1.0 | Quick-order reordering + quantity-break pricing. |
| `subscription-orders` | feature | 1.1.0 | Subscriptions + recurring-order scheduled task. |
| `bom-configurator` | feature | 1.1.0 | Kit / BOM configurator. |
| `headless` | surface | 2.3.0 | Headless content surface: `Headless_*` item types + repository + Delivery-API. |
| `dap-portal` | surface | 1.0.0 | **BETA** — Digital Asset Portal content area (area 26). Not yet gate-proven on Swift 2.3; see [`layers/dap-portal/BASELINE.md`](layers/dap-portal/BASELINE.md). |
| `theme-tech-saas` | theme | 2.3.0 | Tech/SaaS brand overlay (disk-only, SPEC-06). |
| `theme-fashion-lifestyle` | theme | 2.3.0 | Fashion/Lifestyle brand overlay. |
| `theme-industrial-b2b` | theme | 2.3.0 | Industrial B2B brand overlay. |
| `theme-nav-polish` | theme | 1.0.0 | Header menu-bar affordance overlay (Option B): carets, hover/active, reachable dropdowns. Always-on `overlays` entry (not a `themes` swap); layers on top of any demo theme. Icons opt-in. |

## Editions (`editions/<name>.json`)

A build is a composition: `from` a base + an ordered `add` (+ `surfaces`, `sampleData`, `themes`, `overlays`).

| Edition | Composition | Status |
|---------|-------------|--------|
| `base-only` | base + theme `tech-saas`; no catalog, no identities | **Proven** — the empty-shop scaffold (EcomProducts 0 / 0 / EcomCountries 96). |
| `swift-demo` | base + fixture-catalog + reordering-pricing + subscription-orders + bom-configurator + sample data + all 3 themes + `nav-polish` affordance overlay | **Proven** — the full Swift storefront (20 / 3 / 96). |
| `headless-demo` | base + fixture-catalog + `headless` surface + sample data | **Proven** — headless Delivery-API (A1–A9). |
| `dap-portal` | base + fixture-catalog + `dap-portal` surface | **BETA** — gate-prove pending a Swift-2.3 re-capture (see the layer's BASELINE.md). |

## Consuming

This repo is **git-clone distribution** — there are no release archives. Clone it, pick an
edition, and activate its layers against a Dynamicweb 10 host (the Foundry harness does
this end-to-end). Modes are `replace` (source-wins) / `merge` (field-level). Annotated tags
`layers/<name>/<semver>` and `editions/<name>/<semver>` pin each proven artifact to the gate
run + Swift version it was proven against.
