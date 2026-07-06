# Digital Asset Portal 1.0 baseline

**Solution:** Digital Asset Portal — a digital-asset browsing/download portal built on Swift
**Baseline version:** 1.0.0
**Captured against:** DW 10.26.7
**Status:** **Beta.** Captures cleanly and renders on the source; a clean
strict-mode deploy requires a target carrying the complete Swift-v2 design (see
Deployment notes). Not yet demonstrated end-to-end on such a target.
**Config:** [`config/digital-asset-portal-1.0.json`](config/digital-asset-portal-1.0.json)

## Gate status (v3.0 layer) — BETA, prove PENDING

This layer (`kind: surface`) is carried in the Distribution as an **explicitly-Beta,
not-yet-gate-proven** layer. The harness gate deserializes content surfaces with the
base engine (`gate.ps1 -Edition dap-portal`, Step 10d-surface). On the current
**Swift 2.3** harness the DAP replace pass returns HTTP 400 — strict mode escalates
3 warnings to failure (gate run `20260706-132019`):

1. **Missing item-type template `Swift-v2_VerticalNavigation`** — referenced by the
   *My account information* page. This item type is **absent from Swift 2.3's design**
   (the harness overlay ships Breadcrumb/Navigation/OffCanvas/ProductListNavigation but
   no VerticalNavigation). DAP was captured against DW 10.26.7; the type was removed or
   renamed since.
2. **Unresolvable page-ID link `6869`** — in `Header _ Footer/Desktop Header/grid-row-1/paragraph-c1-6.yml`.
3. **Unresolvable page-ID link `8330`** — in `Sign in/Sign in/Sign in/grid-row-2/paragraph-c1-3.yml`
   (the config `acknowledgedOrphanPageIds` covers the orphan *page* 8330, not a *link* to it).

**To promote out of Beta:** re-capture DAP against the current latest Swift (updating the
account page to a current nav item type and repairing the two dangling links), then
`gate.ps1 -Edition dap-portal` must PASS and stamp `provenOn`. Until then this layer and
`editions/dap-portal.json` are shipped for reference/preview only.

The Digital Asset Portal is a content area (area 26, ~32 pages) built on the
Swift-v2 item types and design: a Home, a Digital Assets browser, a Download
Cart, a Customer center (profile, downloads), and Sign in. It reuses Swift's
commerce components, so it is an **add-on to a Swift commerce foundation**, not a
standalone solution.

## Deploy (`deploy/`) — 1 predicate

One Content predicate captures the whole portal area:

- **Digital Assets Portal** — area 26, full page tree (Deploy mode).

There is no seed split in this first baseline — the portal is structural content.

## Prerequisites

This package deploys *on top of* an existing Swift install. The target host must
already have:

1. **The Swift commerce foundation** — shop, products, countries, currencies,
   etc. Deploy the [`swift/2.3`](../../swift/2.3/) package first (the portal's
   product components reference the global catalog).
2. **The Swift-v2 design, including the `Swift-v2_VerticalNavigation` item type.**
   Item-type *schemas* live in the design/database, not in serialized content, so
   this baseline cannot carry them — they must already exist on the target.

## Deployment notes

1. **Requires the complete Swift-v2 design on the target.** The portal's Sign-in
   and account pages use the `Swift-v2_VerticalNavigation` item type — a Swift
   item type (listed among `Swift-v2_PageProperties`'s allowed child types and
   noted in Swift's v2.2.0 changelog; it renders fine on a complete Swift
   install). Item types belong to the **design layer**, which ships with the host
   (like templates), not with serialized content — see Not-serialized below.

   The serializer's strict-mode pre-flight **correctly** verifies that every
   referenced item type and template exists on the target before writing content.
   On a target whose Swift design is a subset (missing this item type/template),
   that check escalates under strict mode and the affected pages are skipped — the
   gate doing its job, not a baseline defect. Deploy onto a host with the full
   Swift-v2 design, or run the deserialize with strict mode off, to apply the
   portal in full.
2. **One dangling demo link.** The "My account information" page links to page
   8330, which no longer exists in the source data. It is acknowledged in the
   config (`acknowledgedOrphanPageIds: [8330]`) and surfaces as a warning. This is
   minor source-data cleanup, independent of the design requirement above.

## Not-serialized (per environment)

Same as Swift: live domain, secrets, analytics IDs, CDN host, and the **design
layer** — templates and item-type definitions (incl. `Swift-v2_VerticalNavigation`)
ship with the host's Swift design, not with this content baseline.

## Verification status

- **Serialize:** clean (HTTP 200, zero escalations, 122 YAML files).
- **Source renders:** the Sign-in / account pages render on the source host
  (HTTP 200), confirming the item type is functional, not orphaned.
- **Deserialize onto a Swift target:** area 26 created with 111 items; the two
  pages using `Swift-v2_VerticalNavigation` are skipped under strict mode because
  the test target's Swift design lacked that item type. A clean strict round-trip
  is pending a target provisioned with the complete Swift-v2 design — the same
  "design ships with the host" prerequisite the Swift baseline already documents.
