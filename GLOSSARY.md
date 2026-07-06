# Glossary — Truvio Commerce Distribution vocabulary

Authoritative terms for the v3.0 layer/edition model. Use these everywhere (docs,
commit messages, issues). "Baseline" survives only inside the serializer engine's own
docs; "pack" survives only in git history.

| Term | Replaces | Meaning |
|------|----------|---------|
| **distribution** | baseline catalog / Baselines repo | The repo of everything needed to make Dynamicweb 10 run as Truvio Commerce. One clone tells the whole story. |
| **layer** | baseline, pack, theme (as artifact classes) | One versioned unit: a `layer.json` manifest + its content (mode trees `replace/`+`merge/`) and/or a `files/` disk overlay. |
| **kind** | — | Layer classification: `base`, `catalog`, `feature`, `theme`, `sample-data`, `surface`. |
| **base** | scaffold / Swift framework baseline | The one privileged layer every edition builds on. Ships the framework + the base contract; zero sample catalog (scaffolding-only). |
| **base contract** | scattered pack-contract ID rules / CATALOG notes / seed-gating docs | `layers/base/base.contract.json` — the machine-readable guarantees the base makes to additions (reserved ID prefixes, base-owned tables, anchors). Additions bind ONLY to it, never to each other. |
| **edition** | stack / scenario / demo build | A named, gate-proven **composition**: `from` a base + an ordered `add` of layers (+ `surfaces`, `sampleData`, `themes`). See `editions/`. |
| **addition** | — | A non-base layer listed in an edition's `add` (catalog / feature). |
| **surface** | frontend leg | A layer carrying what a frontend needs — headless content + Delivery-API probes, or a content area (e.g. `dap-portal`). |
| **sample data** | demo data / demo orders / seeded fixtures | Optional layer of demo content (buyer/CSR identities, orders, contract prices). Toggled per edition by `sampleData`. |
| **catalog** | — | The demo product catalog layer (`fixture-catalog`) an edition adds when it needs products. |
| **theme** | DemoThemes payload | A disk-overlay-only layer (SPEC-06): styles + CSS + assets under `files/`, no serialized DB content. |
| **`replace` / `merge`** | `deploy` / `seed` | Serializer merge modes: source-wins / field-level merge. The mode dirs at each layer root. |
| **Foundry** | harness / BaselineUpdater | The upstream repo: the factory + gate that produces and proves this Distribution. |

## Reference resolution

Layer references are `<name>@<semver>` (e.g. `base@2.3.0`, `fixture-catalog@1.0.0`). The
gate/CI resolves each to `layers/<name>/` and checks `layer.json` `version` equals the
pinned semver — the ref is a claim that is proven, never trusted. An edition's `themes: ["X"]`
resolves to `layers/theme-X`.
