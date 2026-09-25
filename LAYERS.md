# Layers & Editions catalog

Everything this Distribution ships, on the current latest Swift (**Swift 2.4**, rolling latest-only). Which
editions a gate run proved, on which Dynamicweb milestone, is recorded in [`layers/INDEX.json`](layers/INDEX.json)
`gateProven` and nowhere else. See
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
| `sample-data` | sample-data | Distribution (published content) | The whole demo dataset on the `sampleData` toggle: the browsable catalogue, the personas on their B2B account, the orders, the storefront copy, the demo clock and the email statistics. Singleton, and never an `add[]` ref. |

## Layers (`layers/<name>/`)

| Layer | Kind | Version | Role |
|-------|------|---------|------|
| `base` | base | 4.0.0 | The privileged framework-only scaffold: 20 `replace` SqlTable sets (735 rows) and [`base.contract.json`](layers/base/base.contract.json) (contract 3.0.0); zero catalogue, zero content areas. Countries, currencies, languages, tax groups, the shop `SHOP1`, stock locations, the `reference_category` template row, payments, shippings, the order flows with the quote states `QuotePending` / `QuoteSent` / `QuoteAccepted` / `QuoteRejected`, and the three customer-center permission groups (1325, 1270, 1292). Since 4.0.0 it ships a neutral US B2B market default: USD default currency, `PAY2` On account (Net 30), Standard ground / Express / Freight / LTL / Customer pickup, Tax labels; the Danish methods stay as inactive rows because a `replace` never deletes. See [`layers/base/BASE.md`](layers/base/BASE.md). |
| `surface-swift` | surface | 1.16.1 | The Swift storefront content surface: the `Swift 2` (en-US, area 3) content area in both mode trees, `UrlPath`, its own 130 item-type XMLs (the Swift v2.4.0 set plus `TC_AnchorNav`), the `TruvioCommerce` product repository, and a 40-file overlay (the 32 templates Swift added in 2.4.0, the Swift version stamp, corrected stock templates). The customer center carries per-role permissions and, on `Overview`, the Swift 2.4 dashboard widgets per role with one row of example tiles. The area serves USD. Declares the authenticated My returns probe (`requiresFixtures` `TCO-0001`). |
| `sample-data` | sample-data | 6.0.0 | **The one-shot fully functioning demo shop**, activated by `sampleData: true`: 2,098 rows of `merge` SqlTable YAML across 39 tables, `merge/_content` + `replace/_content` storefront copy, 287 images and documents under `files/`, and three declared scripts (demo clock, email statistics, id counters). The Truvio catalogue (97 product rows, 21 groups including the PIM tree), three personas on one B2B account (`TC-100200`), and for the buyer the customer-center data the dashboard draws: 26 orders, 7 quotes, 2 carts, 2 favourite lists, all USD, plus the demo return request `PACK-RMA-0001` on order `TCO-0001`. A customer demo copies the layer and rewrites it ([`layers/sample-data/REWRITE.md`](layers/sample-data/REWRITE.md)). |
| `feature-reordering` | feature | 1.0.4 | Quick Order pad + Express Buy navigation and pages; data-only, zero custom code. Probe: `sku-validation` on `TC-VAR-0001`. |
| `feature-pricing` | feature | 1.1.3 | Quantity-break tiers and customer contract pricing on sample-data prices; carries the compile-optional `ReorderingPricingQtyBreakProvider`. Probes: `cart-price` on `TCPROD0020` (quantity 10, 96) and `TCPROD0046` (36.90 at `TC-100200`). |
| `feature-subscription-orders` | feature | 1.2.2 | Subscribe page, subscriptions account page and the recurring-order scheduled task (disabled by default). Probe: `checkout-recurring` on `TCPROD0061`, `PAY2` / `SHIP9`. |
| `feature-bom-configurator` | feature | 1.2.3 | Kit / BOM configurator pages. Probe: `bom-cart-lines` on the configurable kit `TCPROD0042`. |
| `feature-b2b-comms` | feature | 1.0.6 | Five dealer emails and the email-marketing onboarding flow (`EmailMarketingFlowFolder`, `EmailMarketingFlow`, `EmailMarketingFlowStep`, campaign emails and messages); page ids bind by page GUID through `pageRefs`. |
| `surface-headless` | surface | 2.3.3 | Headless content surface: `Headless_*` item types, repository and Delivery-API content (areas Headless and Headless Nederlands). |
| `surface-dap-portal` | surface | 1.0.5 | Digital Asset Portal content area (area 26, about 32 `Swift-v2` pages). |
| `theme-default` | theme | 2.5.0 | The one presentation layer (disk-only, SPEC-06): neutral palette, quiet buttons, Inter typography, the header menu-bar affordance, mobile and PLP fixes. Since 2.5.0 it ships the brand slot (`Custom/brand.css`, loaded after `default_custom.css`, plus `Custom/brand.tokens.json`) that a demo rewrites in a demo-local copy, and absorbs the generic demo fixes (header wrap, phone poster cap, PDP sections that hide when empty, mega-menu hover apron, per-scheme hover contrast). The starting point of every customer re-skin. |

## Editions (`editions/<name>.json`)

A build is a composition: `from` a base + an ordered `add` (+ `surfaces`, `sampleData`, `themes`).

| Edition | Composition |
|---------|-------------|
| `base-only` | base alone: framework-only, no theme (nothing to skin). API and DB-level proof: the framework row-count contract and `/Admin/`, zero pages by design. |
| `base-swift` | base + `surface-swift` + theme `default`, no sample data and no feature layers: an empty shop in a complete themed storefront. `compatAxes` names dw + apps + swift, so an unmet floor fails; `criticalPaths` sit under the culture segment (Foundry 965, 1005). |
| `swift-demo` | base + `surface-swift` + five feature layers (`feature-reordering`, `feature-pricing`, `feature-subscription-orders`, `feature-bom-configurator`, `feature-b2b-comms`) + sample data + theme `default`. The demo a prospect sees (`EcomProducts` 97, `EcomGroups` 21, `EcomCountries` 96, pinned). Every layer-declared fixture probe resolves here. |
| `headless-demo` | base + `surface-headless` + sample data: the headless Delivery-API probes, no Swift design-package dependency. |
| `dap-portal` | base + `surface-dap-portal` + sample data: the DAP content surface (area 26). |

Whether an edition is proven is recorded in [`layers/INDEX.json`](layers/INDEX.json) `gateProven.editions`,
stamped by the Foundry publish flow from a gate run. An edition absent from it is unproven.

## Machine-readable index & retired layers ([`layers/INDEX.json`](layers/INDEX.json))

[`layers/INDEX.json`](layers/INDEX.json) is the **single source of truth** for what this
Distribution ships and what a dead layer name became. It carries three parts:

- **`gateProven`** — the latest gate-proven state of `main`: the gate run id(s), date, and
  edition set. **Stamped by the Foundry publish flow at release time** (`tools/harness/Write-IndexGateProven.ps1`),
  never hand-authored. This is how *"main IS the version"* (D-CONSUME (a)) means **latest
  gate-proven main**, not raw tip: a consumer pins `origin/main` and **asserts `INDEX.gateProven` is present**.
- **`layers`** — every live layer with `kind`, `version`, and `status` (`active` | `deprecated`).
  Regenerated from the live tree and **diffed clean** by `Validate-Distribution.ps1` (drift in
  *either* direction — a dir with no entry, or an entry with no dir — fails the merge gate).
- **`retired`** — a **tombstone per removed layer name** (`{ name, retired: true, supersededBy, note }`),
  (L-04: *retired ≠ silent*).
  A reference to a retired name resolves to **"retired → use `<supersededBy>`"**, never silence. The
  registry covers the retired presentation overlays and demo themes (→ the one default theme), the
  absorbed catalog fixtures (→ the sample-data layer), and the pre-kind-prefix layer names (→ their
  current `feature-*` / `surface-*` successors). **The authoritative dead-name list lives in
  [`layers/INDEX.json`](layers/INDEX.json) `retired` — never enumerate it in prose** (a dead name in a
  living doc is a latch-on target, which check 9e below forbids).

The merge gate ([`tools/ci/Validate-Distribution.ps1`](tools/ci/Validate-Distribution.ps1), check 9)
**fails** when an edition references a name absent from the live `layers` (naming the successor for
a retired hit) and when a living root doc latches onto a retired layer name (tombstones belong in
`INDEX.json`, not prose; CHANGELOG history and names that are a substring of a live identifier are out
of scope). Regenerate the `layers` array after any layer add/remove with
`pwsh tools/ci/Validate-Distribution.ps1 -RegenerateIndex`.

## Consuming

This repo is **git-clone distribution** — there are no release archives. **Pin `origin/main`**
(main IS the version, D-CONSUME (a)): clone, `git pull --ff-only`, assert `INDEX.gateProven` is
present, pick an edition, and activate its layers against a Dynamicweb 10 host (the Foundry harness
does this end-to-end). Modes are `replace` (source-wins) / `merge` (field-level). Annotated tags
`layers/<name>/<semver>` and `editions/<name>/<semver>` are **provenance-only** audit history
(cut automatically by CI on merge) — the gate run + Swift version each artifact was proven against —
**not a re-consumable frozen pin** (re-materializing an old layer set is out of policy, L-01).
