# Glossary — Truvio Commerce Distribution vocabulary

Authoritative terms for the layer/edition model. Use these everywhere (docs,
commit messages, issues).

| Term | Meaning |
|------|---------|
| **distribution** | The repo of everything needed to make Dynamicweb 10 run as Truvio Commerce. One clone tells the whole story. |
| **layer** | One versioned unit: a `layer.json` manifest + its content (mode trees `replace/`+`merge/`) and/or a `files/` disk overlay. |
| **kind** | Layer classification (the dir-name prefix equals the kind): `base`, `catalog`, `feature`, `theme`, `sample-data`, `surface`. |
| **base** | The one privileged layer every edition builds on. Ships the framework + the base contract; zero sample catalog (scaffolding-only). |
| **base contract** | `layers/base/base.contract.json` — the machine-readable guarantees the base makes to additions (reserved ID prefixes, base-owned tables, anchors). Additions bind ONLY to it, never to each other. |
| **edition** | A named, gate-proven **composition**: `from` a base + an ordered `add` of layers (+ `surfaces`, `sampleData`, `themes`). See `editions/`. |
| **addition** | A non-base layer listed in an edition's `add` (feature layers). |
| **surface** | A layer carrying what a frontend needs — headless content + Delivery-API probes, or a content area (e.g. `surface-dap-portal`). |
| **sample data** | Optional layer of demo content: buyer/CSR identities + the demo product catalog + contract prices, shipped as SQL under `merge/_sql/`. Toggled per edition by `sampleData`. |
| **catalog** | Layer kind reserved for standalone shop-catalog content; the demo catalog ships inside the `sample-data` layer. |
| **theme** | A disk-overlay-only layer (SPEC-06): styles + CSS + assets under `files/`, no serialized DB content. Applied via `themes[]`. The distribution ships **one** default theme (`theme-default`) — the neutral starting point every customer re-skin overwrites. |
| **`replace` / `merge`** | Serializer merge modes: source-wins / field-level merge. The mode dirs at each layer root. |
| **Foundry** | The upstream repo: the factory + gate that produces and proves this Distribution. |

## Reference resolution

Layer references are `<name>@<semver>` (e.g. `base@2.4.1`, `feature-reordering-pricing@1.2.0`). The
gate/CI resolves each to `layers/<name>/` and checks `layer.json` `version` equals the
pinned semver — the ref is a claim that is proven, never trusted. An edition's `themes: ["X"]`
resolves to `layers/theme-X` (kind theme).
