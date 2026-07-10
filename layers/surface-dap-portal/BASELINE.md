# Digital Asset Portal 1.0 baseline

**Solution:** Digital Asset Portal — a digital-asset browsing/download portal built on Swift
**Baseline version:** 1.0.0
**Captured against:** DW 10.26.7
**Status:** **Gate-proven (graduated out of Beta 2026-07-10).** Deserializes clean in
strict mode on the current Swift 2.3 harness and renders `/dap` end-to-end.
**Config:** [`config/digital-asset-portal-1.0.json`](config/digital-asset-portal-1.0.json)

## Gate status (v3.0 layer) — PASS (graduated)

This layer (`kind: surface`) is gate-proven end-to-end. The harness gate deserializes
content surfaces with the base engine (`gate.ps1 -Edition dap-portal`, Step 10d-surface).
On base **2.4.1** + engine **0.8.0-beta** the DAP replace pass returns **HTTP 200**
(117 created, 0 failed) and the `/dap` smoke is green — **gate run `20260710-162010`
PASS**, `provenOn` stamped.

The three prior strict-mode escalations are all resolved:

1. **`Swift-v2_VerticalNavigation`** — the account page uses `Swift-v2_Navigation` (an item
   type Swift 2.3 ships); the absent VerticalNavigation type is no longer referenced.
2. **Page-ID link `6869`** — the Desktop Header "< Swift Bikes Webshop" cross-link row was
   removed (base 2.3.2 DAP-decoupling B3).
3. **Page-ID link `8330`** — the Sign-in `UserAuthentication` module's `CreateUserPageId`
   referenced a non-existent create-account page; the portal has no self-registration flow,
   so the reference is blanked (data-only fix). The `acknowledgedOrphanPageIds` entry is
   cleared accordingly.

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
2. **The standard Swift-v2 design** (templates + item types). Item-type *schemas* live in
   the design/database, not in serialized content, so this baseline cannot carry them —
   they must already exist on the target. The portal uses only item types Swift 2.3 ships
   (e.g. `Swift-v2_Navigation`); it no longer references `Swift-v2_VerticalNavigation`.

## Deployment notes

1. **Uses only stock Swift-v2 item types.** The portal's Sign-in and account pages use
   `Swift-v2_Navigation` / `Swift-v2_OffCanvasNavigation` — item types present in the
   standard Swift 2.3 design — so the serializer's strict-mode pre-flight resolves every
   referenced item type and template and writes the content in full (no skipped pages).
2. **No dangling demo links.** The former create-account link to page 8330 (Sign-in
   `UserAuthentication` `CreateUserPageId`) is blanked — the portal has no self-registration
   flow — and the Desktop Header cross-link to 6869 was removed. `acknowledgedOrphanPageIds`
   is empty.

## Not-serialized (per environment)

Same as Swift: live domain, secrets, analytics IDs, CDN host, and the **design
layer** — templates and item-type definitions ship with the host's Swift design, not with
this content baseline.

## Verification status

- **Serialize:** clean (HTTP 200, zero escalations, 122 YAML files).
- **Deserialize (strict, gate-proven):** `gate.ps1 -Edition dap-portal` PASS on base 2.4.1 +
  engine 0.8.0-beta — DAP surface replace HTTP 200, 117 created, 0 failed, 0 skipped; `/dap`
  smoke green (gate run `20260710-162010`). Graduated out of Beta.
