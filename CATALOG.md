# Catalog

Every published baseline, its tested platform version, and its status. Status
values: **Stable** (passed the clean-room round-trip gate, suitable for use),
**In progress** (being authored, not yet gated), **Deprecated** (superseded).

| Package | Version | Solution | DW version tested | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| [`swift/2.2`](packages/swift/2.2/) | 2.2.0 | Swift storefront (B2C/B2B commerce) | DW 10.26.7 | Stable | 17 Deploy + 18 Seed predicates; English + Dutch language layer. Round-trip verified (HTTP 200, zero escalations, page parity, frontend all-2xx). See [BASELINE](packages/swift/2.2/BASELINE.md). |
| [`digital-asset-portal/1.0`](packages/digital-asset-portal/1.0/) | 1.0.0 | Digital Asset Portal | — | In progress | First capture pending; see [authoring guide](docs/authoring-a-baseline.md). |

## Release tags

Each package is released independently with a `<product>/<semver>` tag, which
builds an Upload-ready `.zip` and attaches it to a GitHub Release:

- `swift/2.2.0`
- `digital-asset-portal/1.0.0`

The baseline version tracks the **source solution** version; the patch digit
bumps for content fixes within that solution version.
