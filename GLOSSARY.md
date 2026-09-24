# Glossary — Truvio Commerce Distribution vocabulary

Authoritative terms for the layer/edition model. Use these everywhere (docs,
commit messages, issues).

| Term | Meaning |
|------|---------|
| **distribution** | The repo of everything needed to make Dynamicweb 10 run as Truvio Commerce. One clone tells the whole story. |
| **layer** | One versioned unit: a `layer.json` manifest + its content (mode trees `replace/`+`merge/`) and/or a `files/` disk overlay. |
| **kind** | Layer classification (the dir-name prefix equals the kind): `base`, `catalog`, `feature`, `theme`, `sample-data`, `surface`. |
| **base** | The one privileged layer every edition builds on. FRAMEWORK-ONLY since 3.0.0 (Swift 2.4 base split): the framework SQL sets (including the quote order states and a neutral US B2B market default since 4.0.0) + the base contract; zero catalog, zero content areas. |
| **base contract** | `layers/base/base.contract.json` — the machine-readable guarantees the base makes to additions (reserved ID prefixes, base-owned tables, anchors) plus `compat`, the compatibility floor (DW, Swift tag, AppStore apps) every addition inherits. Additions bind ONLY to it, never to each other. |
| **edition** | A named, gate-proven **composition**: `from` a base + an ordered `add` of layers (+ `surfaces`, `sampleData`, `themes`). See `editions/`. |
| **addition** | A non-base layer listed in an edition's `add` (feature layers). |
| **surface** | A layer carrying what a frontend needs — the Swift storefront content (`surface-swift`: both areas + UrlPath + own item types), headless content + Delivery-API probes (`surface-headless`), or a content area (`surface-dap-portal`). |
| **sample data** | The one optional layer of demo content and the whole demo dataset: the personas on their B2B account, the browsable catalogue with its prices, variants, specs and imagery, the buyer's orders, quotes, carts, favourite lists and return request, the storefront copy, the demo clock, the email statistics and the id counters. Shipped as serialized SqlTable YAML plus three declared scripts. A customer demo copies it into a demo-local layer and rewrites it (`layers/sample-data/REWRITE.md`). Toggled per edition by `sampleData`, never an `add` ref, and composed last so its copy wins the paths it shares with a surface. What an addition may bind to is the base contract's `sampleData` block. |
| **catalog** | Layer kind reserved for standalone shop-catalog content; the demo catalog ships inside the `sample-data` layer. |
| **theme** | A disk-overlay-only layer (SPEC-06): styles + CSS + assets under `files/`, no serialized DB content. Applied via `themes[]`. The distribution ships **one** default theme (`theme-default`) — the neutral starting point every customer re-skin overwrites. |
| **`replace` / `merge`** | Serializer merge modes: source-wins / field-level merge. The mode dirs at each layer root. |
| **Foundry** | The upstream repo: the factory + gate that produces and proves this Distribution. |

## Reference resolution

Layer references are `<name>@<semver>` (e.g. `base@3.0.0`, `surface-swift@1.0.0`). The
gate/CI resolves each to `layers/<name>/` and checks `layer.json` `version` equals the
pinned semver — the ref is a claim that is proven, never trusted. An edition's `themes: ["X"]`
resolves to `layers/theme-X` (kind theme).
