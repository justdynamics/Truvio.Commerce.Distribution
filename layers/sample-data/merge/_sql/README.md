# sample-data `_sql` — executable demo-content scripts

Unlike the serializer-captured `_sql/<Table>/<key>.yml` trees other layers ship, the
sample-data layer's content is **plain T-SQL scripts**, applied with `sqlcmd` (or any SQL
client) against the target Dynamicweb database. Both scripts are idempotent and
transactional (`SET XACT_ABORT ON`).

| Script | What it inserts | When to apply |
|---|---|---|
| `identities.sql` | Permission groups 1325 Customers / 1270 Account Admin / 1292 CSR, buyer 1328 (cust 98745621), CSR 1326 (cust 7789765), memberships | **Before the host starts** — DW caches identity state at startup |
| `catalog.sql` | Demo shop catalog for SHOP1/ENU/EUR: 3 groups, 20 products (14 masters + 6 Size variants), qty-tier ladder + the buyer contract price (`FIXT-PRICE-CONTRACT`) | **After the base layer deserialize** (FK targets SHOP1/EUR must exist), then restart the host (startup catalog cache) |
| `email-stats.sql` | Per campaign email: one `EmailMessage`, 24 `EmailRecipient` sends (2 bounced), 3 `OMCLink` tracked links, 13 `OMCLinkClick` clicks | **After `catalog.sql`**, before the clock. No-op when the composition ships no `EmailMarketingEmail` rows |
| `demo-clock.sql` | `_demoClock` anchor + `_demoClockExclusion` + `_demoClockGuard` + `usp_DemoClockShift` + the daily `Truvio demo clock` RunSql task | **Last** — it anchors what the other scripts seeded. Restart the host: a SQL-inserted `ScheduledTask` row is invisible to a running app |

## Discovery, not guesswork

The serializer manifest cannot carry a loose script (`providerType` is only `Content` or
`SqlTable`, and `SqlTable` is row-per-YAML), so these four files are declared in
[`../../layer.json`](../../layer.json) under `sql[]` instead: file, mode, phase, order,
restart requirement and every `sqlcmd` variable. A composer reads that array; without it a
composition stages the files and executes nothing while reporting success.

## Two traps these scripts already carry

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

`identities.sql` takes three `sqlcmd` variables so demo credentials never live in the repo:

```
sqlcmd -S <server> -d <database> -b -i identities.sql `
  -v BuyerUserName="IMCUser" BuyerPassword="<demo password>" CsrPassword="<demo password>"
```

All ids and anchors are base-contract values (`layers/base/base.contract.json`): the
reserved key prefixes `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` belong to this layer; no other
layer may use them.
