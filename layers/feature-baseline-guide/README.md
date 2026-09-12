# feature-baseline-guide — the agent-facing guide to the Swift 2 baseline (content-only)

Ships the **Baseline guide** page tree (`/Baseline guide` in area 3 "Swift 2") that turns a freshly
deserialized `swift-demo` edition into a self-describing site: every page documents one baseline
feature area, says which layer guarantees it, which skill covers it, which MCP tools brand it and how
to verify it, and the **Branding path** page fixes the order in which an agent brands the boilerplate
toward a customer (customer context, theme overlay, areas and languages, catalog and PIM data model,
users and groups, pricing and assortments, checkout, verification).

## What the layer ships

| Piece | Where | Notes |
|---|---|---|
| Page tree `/Baseline guide` (root + 14 children) | `replace/_content/Swift 2/Baseline guide/**` | pure Swift 2.4 item types (`Swift-v2_Text`, `Swift-v2_Accordion*`, `Swift-v2_Card`); no custom item types, no templates |
| Serialize config | `config/baseline-guide-2.4.json` | one `Replace` Content predicate on `/Baseline guide`; excludes nothing, acknowledges no orphans |

Nothing else: no SQL, no catalogue rows, no users, no files overlay.

## Dependencies

- `surface-swift` (area 3 "Swift 2" and its master/layout) must be deserialized first; the fragment
  resolves `areaId: 3`. Declared in `costHints.dependsOn` and enforced by edition ordering.

## Verification

- `GET /en-us/baseline-guide` → 200 and the body contains "Baseline guide".
- `GET /en-us/baseline-guide/branding-path` → 200.
- `SELECT COUNT(*) FROM Page WHERE PageMenuText = 'Baseline guide'` = 1 after a one-shot deserialize.
