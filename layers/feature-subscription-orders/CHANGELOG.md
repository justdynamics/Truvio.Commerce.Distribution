# Changelog — feature-subscription-orders


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

