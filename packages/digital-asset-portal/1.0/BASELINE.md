# Digital Asset Portal 1.0 baseline

**Solution:** Digital Asset Portal — a digital-asset browsing/download portal built on Swift
**Baseline version:** 1.0.0
**Captured against:** DW 10.26.7
**Status:** **Beta.** Captures cleanly and deploys onto a properly provisioned
Swift target; not yet a clean strict-mode round-trip on a bare database (see
Known issues).
**Config:** [`config/digital-asset-portal-1.0.json`](config/digital-asset-portal-1.0.json)

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
   etc. Deploy the [`swift/2.2`](../../swift/2.2/) package first (the portal's
   product components reference the global catalog).
2. **The Swift-v2 design, including the `Swift-v2_VerticalNavigation` item type.**
   Item-type *schemas* live in the design/database, not in serialized content, so
   this baseline cannot carry them — they must already exist on the target.

## Known issues (why this is Beta)

1. **`Swift-v2_VerticalNavigation` item type must exist on the target.** Two pages
   (Sign in, My account information) embed a `Swift-v2_VerticalNavigation` item.
   The content serializer captures item *instances*, not item-type *definitions*,
   so on a target that lacks this type the deserialize escalates under strict mode
   (the rest of the portal deploys). Provision the Swift-v2 design with this item
   type, or deserialize with strict mode off, until item-type-schema carriage is
   added.
2. **One dangling demo link.** The "My account information" page links to page
   8330, which no longer exists in the source data. It is acknowledged in the
   config (`acknowledgedOrphanPageIds: [8330]`) and surfaces as a warning.

## Not-serialized (per environment)

Same as Swift: live domain, secrets, analytics IDs, CDN host, and the design
filesystem/item-type schemas (see Prerequisites).

## Verification status

- **Serialize:** clean (HTTP 200, zero escalations, 122 YAML files).
- **Deserialize onto a Swift target:** area 26 created with 111 items; the only
  failures are the two `Swift-v2_VerticalNavigation` pages on a design-incomplete
  target. A clean strict-mode round-trip is tracked for the Stable release once
  the target design carries the item type (or the serializer carries item-type
  schemas).
