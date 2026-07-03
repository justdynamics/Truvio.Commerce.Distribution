# Catalog

Every published baseline, its tested platform version, and its status. Status
values: **Stable** (passed the clean-room round-trip gate, suitable for use),
**In progress** (being authored, not yet gated), **Deprecated** (superseded).

| Package | Version | Solution | DW version tested | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| [`swift/2.3`](packages/swift/2.3/) | 2.3.2 | Swift storefront (B2C/B2B commerce) — scaffolding-only | DW 10.26.9 | Stable | 18 Deploy + 10 Seed (Content) predicates; English + Dutch. **Scaffolding-only:** framework + starter content/pages, zero sample catalog. Catalog is authored per-demo. See [BASELINE](packages/swift/2.3/BASELINE.md). |
| [`digital-asset-portal/1.0`](packages/digital-asset-portal/1.0/) | 1.0.0 | Digital Asset Portal | DW 10.26.7 | Beta | Portal area (area 26) captured; deploys as an add-on to Swift. Needs the Swift-v2 design (incl. `Swift-v2_VerticalNavigation` item type) on the target. See [BASELINE](packages/digital-asset-portal/1.0/BASELINE.md). |

## Distribution

Baselines are distributed by **`git clone`** of this repository (or a
sparse-checkout of a single `packages/<product>/<version>/`). There are no
release zips or tags to resolve. Pin reproducibility by **commit SHA** — record
the SHA you deployed in the consuming demo's CUSTOMISATIONS.md.

Swift support is **rolling latest-only**: exactly one Swift baseline version is
maintained at a time (the current latest). When the next Swift version ships,
maintenance rolls forward and the prior package is removed.
