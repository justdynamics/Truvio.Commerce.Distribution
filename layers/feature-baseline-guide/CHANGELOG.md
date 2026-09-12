# Changelog — feature-baseline-guide

## 1.0.0

Initial release (foundry.mydwsite4.com e2e session, 2026-09-12). Content-only, **zero custom code**,
**zero catalogue rows**.

- Adds the **Baseline guide** page tree under area 3 (`/Baseline guide`, storefront `/en-us/baseline-guide`):
  one page per baseline feature area (content, navigation, PIM, catalog, pricing, B2B, users and
  permissions, checkout, RMA, search, integration hooks, headless probes) plus the branding path and the
  customer-context convention. Written for an agent reader in the vocabulary of the dynamicweb/skills
  bundles; every page names the layer that ships the feature, the skill that covers it, the MCP tools
  that brand it and one assert.
- Serialized with `config/baseline-guide-2.4.json` (one Replace Content predicate) on Serializer 0.9.0-beta.
- Depends on `surface-swift` for area 3; placed after it in the `swift-demo` edition.
