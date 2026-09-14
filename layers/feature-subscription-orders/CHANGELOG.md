# Changelog — feature-subscription-orders

## 1.2.2

The `checkout-recurring` probe buys `TCPROD0061` instead of `PACK-SUB-PROD1`. The subject moves from a row the sample-data layer used to ship as a marker-string fixture to a row of the browsable brand catalogue, and the probe now binds to a subject the base contract guarantees (`base.contract.json` `sampleData.guaranteedRows`, new in base 3.5.0) rather than to a layer. sample-data 4.0.0 is the merge of the two sample-data layers; the `gate-fixtures` edition is deleted and `swift-demo` sets `sampleData: true`, so this probe resolves in the demo edition itself.

`PACK-SUB-PROD1` was the one probe subject the brand catalogue had no equivalent for, so
sample-data 4.0.0 authors one: `TCPROD0061` / `TC-SUB-0061` "Truvio Subscription Plan 61" in
`TCGRP-PRICE-STRUCTURES`, EUR list 49, in stock, with the spec set its siblings carry. Everything
else about the probe is unchanged — `PAY2`, `SHIP9`, `checkoutStepIndex` 1, the delta assert on
`EcomRecurringOrder` — and so are the pages, the item types and the `Place recurring orders`
scheduled-task row.

## 1.2.1

Every probe and criticalPath moves from the `/swift-2/` area segment to the `/en-us/` culture root (Foundry #965). `AreaUrlName` `swift-2` is decorative on a single-area host: Dynamicweb prefixes the area segment only when more than one area competes for the host and otherwise serves the culture segment, so every `/swift-2/` path answered 404 on a healthy, fully deserialized site while the same pages answered under `/en-us/`. Page targets are unchanged; only the prefix moves. README probe tables follow.

## 1.2.0

**Zero catalogue rows (Foundry 960).** `PACK-SUB-PROD1`, its group `PACK-SUB-GRP1` and the group and
shop relations moved to `sample-data` `merge/_sql/feature-fixtures.sql`, id for id. `fragmentTables`
drops the four catalogue tables and keeps `ScheduledTask`, which is the only table this layer still
writes; the `EcomProducts` entry in `configRows` goes with the rows, while the `PAY2` / `SHIP9` /
`ScheduledTask` declarations stay — those were always dependencies, never fragments.

The `checkout-recurring` probe rides the same product id as before.

## 1.1.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

