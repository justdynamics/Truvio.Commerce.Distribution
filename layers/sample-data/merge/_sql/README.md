# sample-data `_sql`: serialized rows plus two local-only scripts

The layer's identities, catalogue, contract price and delivered order ship as serialized
**merge-mode SqlTable rows**: one `<Table>/` directory per table, one `<key>.yml` per row plus a
`_meta.yml` schema file, 14 tables and 93 rows. Every row file opens with the ownership header
`ownership: mode: merge`. `../merge-manifest.json` lists the 14 `SqlTable` entries and
`../../config/sample-data-2.4.json` carries the predicates that selected them. The merge
deserialize delivers them; nothing here needs a SQL channel.

| Directory | Rows | Key |
|---|---:|---|
| `AccessUser/` | 2 | `1326`, `1328` (contract-named ids, below the 100000 floor by contract) |
| `AccessUserGroupRelation/` | 2 | `1292$$1326`, `1325$$1328` |
| `EcomGroups/` | 8 | `FIXTGRP*`, `PACK-RPP-GRP1`, `PACK-BOM-GRP1`, `PACK-BOM-FORKS`, `PACK-BOM-RACKS`, `PACK-SUB-GRP1` |
| `EcomShopGroupRelation/` | 8 | `<group>$$SHOP1` |
| `EcomVariantGroups/` | 1 | `FIXTVG1` |
| `EcomVariantsOptions/` | 3 | `FIXTVO1..3` |
| `EcomProducts/` | 28 | `FIXT*`, `PACK-RPP-*`, `PACK-BOM-*`, `PACK-SUB-*` |
| `EcomGroupProductRelation/` | 22 | group + product |
| `EcomVariantOptionsProductRelation/` | 6 | option + product |
| `EcomPrices/` | 8 | `FIXT-PRICE-*`, `PACK-RPP-*` |
| `EcomProductItems/` | 2 | `PACK-BOM3-0002`, `PACK-BOM3-0003` |
| `EcomOrders/` | 1 | `FIXT-ORDER-RMA1` |
| `EcomOrderLines/` | 1 | `FIXT-ORDER-RMA1-1` |
| `EcomRmaOrderLines/` | 1 | `100301` (identity-only key, reserved id) |

No row file carries a password or a password hash: the `AccessUser` predicate excludes the
password, login and recovery columns. Set the buyer and CSR passwords after the deserialize
through Management API `UserSetPassword`, then recycle and verify sign-in.

## The two scripts (local installs only)

| Script | What it inserts | When to apply |
|---|---|---|
| `email-stats.sql` | Per campaign email: one `EmailMessage`, 24 `EmailRecipient` sends (2 bounced), 3 `OMCLink` tracked links, 13 `OMCLinkClick` clicks, and the `EmailMarketingEmail` binding the stats grid reads | **After the merge deserialize**, before the clock. No-op when the host has no `EmailMarketingEmail` rows |
| `demo-clock.sql` | `_demoClock` anchor (derived from `FIXT-ORDER-RMA1`, else the apply date) + `_demoClockExclusion` + `_demoClockGuard` + `usp_DemoClockShift` + the daily `Truvio demo clock` RunSql task | **Last**. Restart the host: a SQL-inserted `ScheduledTask` row is invisible to a running app |

Both are declared in [`../../layer.json`](../../layer.json) under `sql[]` (file, mode, phase,
order, restart requirement). Neither takes a `sqlcmd` variable. An online build has no SQL
surface and no route for either script, so the email statistics and the `Truvio demo clock`
task exist on local-channel hosts only.

## Two traps `demo-clock.sql` already carries

- **`SET QUOTED_IDENTIFIER ON` must be its own batch before `CREATE OR ALTER PROCEDURE`.**
  The setting is captured at procedure-creation time, and `sqlcmd -i` (how every documented
  apply path runs these files) defaults it OFF. Without it `usp_DemoClockShift` creates
  cleanly, sqlcmd exits 0, and the first invocation fails with `Msg 1934 ... 'QUOTED_IDENTIFIER'`
  because the plan builder calls the XML data type method `.value()`.
- **`TaskAddInSettings` holds LITERAL XML.** Only a parameter *value* is ever escaped; the
  document's own markup stays intact. XML-escaping the whole document stores a string the
  add-in loader cannot parse, and the task then exists, opens in admin, and does nothing.
  `demo-clock.sql` sidesteps escaping entirely by making the parameter value
  `EXEC dbo.usp_DemoClockShift;` and keeping the shift SQL in the procedure.

All ids and anchors are base-contract values (`layers/base/base.contract.json`): the
reserved key prefixes `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` belong to this layer; no other
layer may use them.
