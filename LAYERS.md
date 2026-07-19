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
| `base` | base | 3.1.1 | The privileged FRAMEWORK-ONLY scaffold (Swift 2.4 base split): the 16 framework SQL sets + [`base.contract.json`](layers/base/base.contract.json); **zero catalog, zero content areas** — all Swift content moved to `surface-swift`. 3.1.1 (patch) fixes the `EcomCurrencies` multi-default defect: 16 EUR rows shipped `CurrencyIsDefault: true` (one per language), which DW cannot resolve to a single default — now only the en-US (`EUR$$ENU`) row is default, the other 15 EUR rows false, so the shop resolves DEFCUR=EUR unambiguously. 3.1.0 reshapes the shipped shop languages to en-US (sole default) / es-MX / fr-CA and drops the DAN/DEU/FRA/ITA shop attach (`EcomLanguages` 18→20, `EcomShopLanguageRelation` rewritten on SHOP1). Proven on DW 10.28.1-PreRelease. |
| `surface-swift` | surface | 1.3.0 | The Swift storefront content surface (born in the base split): the `Swift 2` (en-US) content area, the entire merge tree, `UrlPath`, and its own 128 Swift v2.4.0 item-type XMLs (self-contained). 1.3.0 authors bodies for the two OOTB newsletter-email shells (Announcement/Sale) that shipped empty. 1.2.1 (patch) normalizes the one non-canonical raw page-id link found in the merge tree — the `About us` page shortcut `Default.aspx?Id=165` → `Default.aspx?ID=165` (canonical casing, matching every other in-tree link so the serializer's page-id remap resolves it). 1.2.0 removes the `Swift 2 Nederlands` (area 27) content area and its feature coupling (nld dropped from the Distribution). 1.1.0 shipped the product short/long descriptions in the product-page composition (buy-panel teaser + full-width "Overview", en-US area). 1.0.1 added the durable image-crop normalization + the List-mode PLP card (SKU/price/stock/qty/add-to-cart). Proven on DW 10.28.1-PreRelease. |
| `sample-data` | sample-data | 2.0.2 | Demo identities (buyer/CSR) + the demo product catalog (EcomProducts 20 / EcomGroups 3) + contract pricing, shipped as SQL under `merge/_sql/`. 2.0.2 seeds the delivered order + RMA link for `feature-rma`. Activated when an edition sets `sampleData: true`. |
| `feature-reordering` | feature | 1.0.0 | Quick Order pad + Express Buy nav/pages (data-only, zero customCode). Split from `feature-reordering-pricing`. |
| `feature-pricing` | feature | 1.0.0 | Quantity-break tiers + customer-contract pricing; carries the compile-optional `ReorderingPricingQtyBreakProvider`. Split from `feature-reordering-pricing`. |
| `feature-rma` | feature | 1.0.0 | Data-only RMA seed (`EcomRmas`); the My-returns page + RMA state machine are OOTB (surface-swift + platform). |
| `feature-b2b-comms` | feature | 1.0.0 | Data-only B2B dealer email pack (5 dealer emails under `/Newsletter Emails/Dealer Emails/`) + the email-marketing onboarding flow serialized via `SqlTable` predicates (`EmailMarketingFlow` + `EmailMarketingFlowStep`). Composes on `surface-swift`. |
| `feature-reordering-pricing` | feature | 1.2.1 | **DEPRECATED / tombstoned** (superseded by `feature-reordering@1.0.0` + `feature-pricing@1.0.0`). Retained one release for consumers still pinning 1.2.1; no edition composes it. Do not add to new editions. |
| `feature-subscription-orders` | feature | 1.1.1 | Subscriptions + recurring-order scheduled task. |
| `feature-bom-configurator` | feature | 1.1.1 | Kit / BOM configurator. |
| `surface-headless` | surface | 2.3.3 | Headless content surface: `Headless_*` item types + repository + Delivery-API. 2.3.3 migrates the serializer config off the retired Deploy/Seed predicate modes. |
| `surface-dap-portal` | surface | 1.0.3 | Digital Asset Portal content area (area 26, ~32 Swift-v2 pages). Content-only add-on surface. 1.0.3 migrates the serializer config off the retired modes and re-points the Area style ids to the shipped `default` scheme. |
| `theme-default` | theme | 1.2.1 | The one presentation layer (disk-only, SPEC-06): the CSS that makes stock Swift look great — neutral palette, quiet buttons, Inter typography, and the header menu-bar affordance folded in. 1.2.1 (patch) folds in a real-device fix on the mobile list-mode PLP: the mobile flex bases lacked `!important` so `.flex-fill` let the SKU column grow content-driven and tip some rows' CTA onto their own line while others stayed inline — mobile bases now enforced (like desktop), thumbs uniform 56px squares, SKU type compacted, and the price pill right-anchored so it aligns right both inline and wrapped. 1.2.0 folds in the "mobile pass": a scrollable mobile category bar (the desktop mega-menu never collapsed and blew the 390px canvas past 1300px), flex/footer rows that wrap below md, list-mode PLP column discipline (Bootstrap `.flex-fill` was defeating the bases), an open two-column spec table (no harmonica), and a clamped mobile logo lockup. 1.1.0 folds in the "fresh pass": pill buttons, a radius + soft-elevation system with hover lift, muted secondary-text tier, calmer motion, a slim two-row header (`<=170px`), rounded imagery. 1.0.2 added durable image-height caps for `Swift-v2_Image` bands + slider covers. The starting point of every customer re-skin, not a brand. |

## Editions (`editions/<name>.json`)

A build is a composition: `from` a base + an ordered `add` (+ `surfaces`, `sampleData`, `themes`).

| Edition | Composition | Status |
|---------|-------------|--------|
| `base-only` | base 3.1.1 alone — framework-only, no theme (nothing to skin) | **Proven on DW 10.28.1-PreRelease** — API/DB-level proof (framework row-count contract + /Admin/; zero pages by design). |
| `swift-demo` | base + `surface-swift` + six feature layers (`feature-reordering` + `feature-pricing` + `feature-rma` + `feature-subscription-orders` + `feature-bom-configurator` + `feature-b2b-comms`) + sample data + theme `default` | **Proven on DW 10.28.1-PreRelease** — the full Swift 2.4 storefront (20 / 3 / 96). |
| `headless-demo` | base + `surface-headless` + sample data | **Proven on DW 10.28.1-PreRelease** — headless Delivery-API (A1–A9), ZERO Swift design-package dependency. |
| `dap-portal` | base + `surface-dap-portal` + sample data | **Proven on DW 10.28.1-PreRelease** — the DAP content surface (area 26). |

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
  generalizing the `feature-reordering-pricing` `supersededBy` precedent (L-04: *retired ≠ silent*).
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
