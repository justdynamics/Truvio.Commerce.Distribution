# sample-data `_sql`

Two kinds of thing live here.

**Row files — `<Table>/<key>.yml`.** The layer's whole dataset: 1,871 serializer-captured rows
across 28 tables, one file per row key, keyed by the primary key with composite parts joined by
`$$`. Each table also carries a `_meta.yml` describing its columns. They are listed in
[`../merge-manifest.json`](../merge-manifest.json) and fenced by the merge predicates in
[`../../config/sample-data-2.4.json`](../../config/sample-data-2.4.json). They arrive through
the ordinary merge deserialize, so an online build with no SQL channel delivers them exactly as
a local one does. Every predicate is `Merge`: a re-deserialize fills unset columns on the
layer's own keys and never resets a persona, a price or a password set on the host.

**Two loose T-SQL scripts.** Neither writes a catalogue row, and neither fits a row file.

| Script | What it does | When to apply |
|---|---|---|
| `email-stats.sql` | Per campaign email: one `EmailMessage`, 24 `EmailRecipient` sends (2 bounced), 3 `OMCLink` tracked links, 13 `OMCLinkClick` clicks | **After the merge deserialize.** No-op when the composition ships no `EmailMarketingEmail` rows |
| `demo-clock.sql` | `_demoClock` anchor (seeded to the harvest day the rows carry) + `_demoClockExclusion` + `_demoClockGuard` + `usp_DemoClockShift` + the daily `Truvio demo clock` RunSql task | **Last.** Restart the host: a SQL-inserted `ScheduledTask` row is invisible to a running app |

Both are idempotent and transactional (`SET XACT_ABORT ON`), and neither takes a `sqlcmd`
variable.

## Discovery, not guesswork

The serializer manifest cannot carry a loose script (`providerType` is only `Content` or
`SqlTable`, and `SqlTable` is row-per-YAML), so a `.sql` file carries no `merge-manifest.json`
entry and the manifest-driven deserialize never executes it. The two scripts are declared in
[`../../layer.json`](../../layer.json) under `sql[]` instead: file, mode, phase, order and
restart requirement. A composer reads that array; without it a composition stages the files and
executes nothing while reporting success.

## Two traps `demo-clock.sql` already carries

- **`SET QUOTED_IDENTIFIER ON` must be its own batch before `CREATE OR ALTER PROCEDURE`.** The
  setting is captured at procedure-creation time, and `sqlcmd -i` (how every documented apply
  path runs the file) defaults it OFF. Without it `usp_DemoClockShift` creates cleanly, sqlcmd
  exits 0, and the first invocation fails with `Msg 1934 ... 'QUOTED_IDENTIFIER'` because the
  plan builder calls the XML data type method `.value()`.
- **`TaskAddInSettings` holds LITERAL XML.** Only a parameter *value* is ever escaped; the
  document's own markup stays intact. XML-escaping the whole document stores a string the add-in
  loader cannot parse, and the task then exists, opens in admin, and does nothing. The script
  sidesteps escaping entirely by making the parameter value `EXEC dbo.usp_DemoClockShift;` and
  keeping the shift SQL in the procedure.

The key families this layer reserves, and the subjects a feature layer binds to, are in
[`../../README.md`](../../README.md) and in
[`layers/base/base.contract.json`](../../../base/base.contract.json).
