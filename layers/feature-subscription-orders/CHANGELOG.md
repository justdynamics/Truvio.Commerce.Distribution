# Changelog — feature-subscription-orders


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

