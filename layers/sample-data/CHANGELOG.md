# Changelog — sample-data

## 3.0.0

### The fixtures ship as serialized SqlTable YAML (Foundry #1215)

`identities.sql`, `catalog.sql` and `feature-fixtures.sql` are gone. Their end state now ships
as merge-mode SqlTable rows: `merge/_sql/<Table>/<key>.yml` for 14 tables (93 row files plus one
`_meta.yml` per table), `merge/merge-manifest.json` (schemaVersion 2, complete, 14 `SqlTable`
entries, host content exclusion maps emptied) and the 14 merge predicates in
`config/sample-data-2.4.json`. `layer.json` declares `fragmentModes: ["merge"]`, the 14
`fragmentTables` and six `configRows`, and gains `costHints` (reserved key prefixes, reserved int
ids, expected rows).

**Why major.** The declared script interface changes for existing consumers. The
`before-host-start` script is gone, the `catalog.sql` path a caller executed is gone, the three
`sqlcmdVariables` `BuyerUserName`, `BuyerPassword` and `CsrPassword` (and their `valueShape`
declarations) are gone, and applying the layer no longer yields users who can sign in until
their passwords are set through the Management API.

**How the rows were produced.** On `foundry-sqlsrc2.mydwsite4.com` (DW 10.28.10, Serializer
1.0.2-beta, MCP 0.6), `gate-fixtures` was composed from Distribution `dcb8e492` with sample-data
2.3.4 applied locally: `identities.sql` before host start; replace deserialize 1190 / 10 / 33 / 0
failed; `catalog.sql`, `feature-fixtures.sql`, `email-stats.sql` and `demo-clock.sql` after the
replace; merge deserialize 279 / 17 / 0 / 0; recycle. The storefront baseline on that SQL route:
`/en-us/shop` 12 products; the `PACK-BOM-0001` PDP HTTP 200 ("Truvio Kit Configurator (BOM)");
IMCUser and IMCSalesrep authenticate through `/dwapi/users/authenticate`; IMCUser's my-returns
page shows "Add new request". After the rekey below, one scoped Serialize per predicate wrote the
YAML (harvest completed 2026-09-14T10:08:32Z).

**Row parity, SQL route against YAML, table by table:**

| Table | SQL rows | YAML rows |
|---|---:|---:|
| `AccessUser` | 2 | 2 |
| `AccessUserGroupRelation` | 2 | 2 |
| `EcomGroups` | 8 | 8 |
| `EcomShopGroupRelation` | 8 | 8 |
| `EcomVariantGroups` | 1 | 1 |
| `EcomVariantsOptions` | 3 | 3 |
| `EcomProducts` | 28 | 28 |
| `EcomGroupProductRelation` | 22 | 22 |
| `EcomVariantOptionsProductRelation` | 6 | 6 |
| `EcomPrices` | 8 | 8 |
| `EcomProductItems` | 2 | 2 |
| `EcomOrders` | 1 | 1 |
| `EcomOrderLines` | 1 | 1 |
| `EcomRmaOrderLines` | 1 | 1 |
| **Total** | **93** | **93** |

The permission groups 1325 / 1270 / 1292 `identities.sql` inserted when absent are not shipped:
the base replace tree owns them.

**Rekeyed before harvest.** `EcomRmaOrderLines` has an identity-only key, which the serializer
writes verbatim and never remaps or warns on. The row linking `PACK-RMA-0001` to
`FIXT-ORDER-RMA1-1` moved from id 1 to the reserved id `100301` on the harvest host. Users 1326
and 1328 keep their contract-named ids, which the base contract names as exceptions to the 100000
id floor (base 3.4.2).

**Checked on the harvest.** 93 row files equal the SQL counts in all 14 tables; every row file
carries the ownership header; no row file contains `AccessUserPassword` or a 128-hex hash; no
protected string; no `1900-01-01` value (Serializer 1.0.2-beta round-trips NULL, issue #18).

**Persona passwords move to the Management API.** After the deserialize, set the passwords of
1328 IMCUser and 1326 IMCSalesrep through `UserSetPassword`, recycle, and verify with
`/dwapi/users/authenticate`. `AccessUserUserName` is fixed at `IMCUser`, the base anchor, so the
buyer login name is no longer steerable.

**Frozen at harvest.** `ProductCreated`, `ProductUpdated` and `GroupProductRelationCreated`,
`OrderDate` (2026-08-15) and `OrderCompletedDate` (2026-08-17) of `FIXT-ORDER-RMA1`, and its
`OrderLineDate`. The 24 host-born `ProductUniqueId` values and the users' `AccessUserUniqueId`
freeze too; re-harvest only from a host deserialized from this YAML.

**Dropped, because merge carries the end state only.** The DELETE-then-INSERT resets, the
mojibake repair UPDATEs (YAML is UTF-8 and carries U+2014 directly) and the password shape guard.

**Two scripts stay SQL, local installs only.** `sql[]` keeps `email-stats.sql` (order 1) and
`demo-clock.sql` (order 2), both now in phase `after-merge-deserialize` because the rows they read
arrive by the merge; every other flag is unchanged. Their descriptions state that an online build
has no route for them. `email-stats.sql` ends in an UPDATE of a pre-existing
`EmailMarketingEmail` row (the binding the statistics grid reads), which a merge row cannot move.
`demo-clock.sql` is DDL, a stored procedure and a RunSql task that calls it; the scheduled task
`Truvio demo clock` exists on local-channel hosts only.

**The demo clock anchors to the harvested dates.** The first anchor was `GETDATE()` at apply
time, correct while `catalog.sql` seeded the dates with `GETDATE()`. With the dates frozen at
harvest, a clock anchored to the apply day never makes up the harvest age. `demo-clock.sql` now
derives the anchor as `CAST(OrderDate AS date) + 30 days` of `FIXT-ORDER-RMA1` (harvested 30 days
old), falls back to the apply date when the order is absent, and clamps a future anchor to today.
An existing `_demoClock` row is left alone.

**Not yet proven.** Online delivery on a fresh clone and the remote gate on `gate-fixtures`.

## 2.3.4

### The password variables carry the platform hash (Foundry #1104, password half)

`identities.sql` writes `BuyerPassword` and `CsrPassword` verbatim into `AccessUserPassword`,
and the host stores a 128-character hex SHA512 string there. The descriptions said "demo
password", so a caller passing the plaintext seeded buyer and CSR rows that could never sign
in, with no error anywhere.

- `layer.json`: both variables declare `valueShape: "dw-password-hash"` (new in
  `layers/layer.schema.json`) and their descriptions state the value is the platform hash
  (lowercase hex of SHA512 over UTF8(password + "DwSecret")), never the plaintext. The Foundry
  composer `sql[]` applier (Foundry PR #1213, #1066) reads `valueShape`, takes the plaintext and
  hashes it once.
- `identities.sql`: the same shape guard `truvio-identities.sql` carries runs before
  `BEGIN TRAN`. Any value that is not 128 hex characters raises an error naming the variable and
  `RETURN`s, so nothing is written with or without `sqlcmd -b`. The header states the contract.
- No row, id or count changes. A caller that still passes the plaintext now fails loudly
  instead of seeding users that cannot sign in.

## 2.3.3

**The fixtures stop being demo content, and not one row changes (Foundry #1074, #1174, #1127,
#1134).** Two defects were filed against the rows this layer ships on purpose. On the unfiltered
`/en-us/shop` the branded v5 host served **12 bare `Placeholder product.` strings** inside
`itemprop="disambiguatingDescription"`, from 22 `FIXT*` / `PACK-*` masters (28 `EcomProducts`
rows) - and no assert saw them, because `design-assert.publish.json`'s `placeholderRegex` requires
a dash after the marker word and these carry a space (#1174). On the PLP the Group facet rail
rendered **6 `Sample Group N` values**, the permanent `STOCKCOPY-01` FAIL the design leg cannot
pass while sample data is composed: one leg asserts those names must render correctly (the 2.3.2
em-dash repair) and another asserts they must not render at all (#1127, rail re-screened in
#1134).

Neither is a rendering bug and neither is fixed by rewriting a row. The rows are doing what they
were written to do - be stable, id-addressable subjects for the gate's layer-declared probes. The
defect is that they were composed into the storefront a prospect opens. The owner decision on
#1074 (2026-09-13, round-three close-out) resolves it in `editions/`:

- `editions/swift-demo.json` sets **`sampleData: false`**. Its catalogue is `truvio-demo@1.7.0`,
  and `expectedCounts` is pinned to what that layer ships (96 / 16 / 96, measured) because
  `Set-ConfigFromEdition` derives the product and group counts from the `sampleData` toggle alone.
- `editions/gate-fixtures.json` is **new** and is the only composition that sets
  `sampleData: true` on the Swift surface. It carries the same seven feature layers at the pins
  swift-demo carried before this change, because `behaviorProbes` are LAYER asserts and the five
  fixture legs need a composition that still ships their subjects: `sku-validation FIXT-0001`,
  `cart-price PACK-RPP-PROD1/PROD2`, `bom-cart-lines PACK-BOM-0001`,
  `checkout-recurring PACK-SUB-PROD1`, and feature-rma's authenticated `/my-returns` probe, which
  needs buyer 1328 and `FIXT-ORDER-RMA1`.

`headless-demo` and `dap-portal` keep `sampleData: true`: neither renders the Swift PLP or its
facet rail, and `surface-headless`'s own query deliberately drops the shop and language macros.

**This layer's SQL is unchanged.** Every `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` / `PACK-*` id, row,
count and price is byte-identical to 2.3.2 - `EcomProducts` 20 + 8, `EcomGroups` 3 + 5,
`EcomPrices` 4 + 4, the 2 BOM slots and `FIXT-ORDER-RMA1`. The only edit to `catalog.sql` is a
comment: the NEUTRALIZATION CONVENTION block said "on any edition with `sampleData: true` this is
the catalogue a prospect sees", which is now false, and the block records why the marker word
stays - several asserts key on it, so the next pass must not neutralize the strings instead of the
composition.



## 2.3.2

**The PLP facet sidebar rendered mojibake where the layer has an em dash (Foundry #1095).**
Measured on the branded v5 e2e host: 3 `FIXTGRP*` group names and 20 `FIXT*` product names
carried `U+00E2 U+20AC U+201D` in place of `U+2014`. The layer file was never wrong - it is
clean UTF-8 - but a UTF-8 em dash is the three bytes `E2 80 94`, and an applier that runs
`sqlcmd` without `-f 65001` reads them in the machine's ANSI code page and stores three
characters instead of one. The file cannot control how it is read, so it stops depending on
it: every separator is now written as its code point, `N'...' + NCHAR(8212) + N'...'`, and
no name literal in `catalog.sql` carries a non-ASCII byte. The displayed value is unchanged,
and the script now seeds the identical em dash under either code page - verified by applying
it twice on the 10.28.10 host, once with `-f 65001` and once without.

New section 6 repairs a host that was already seeded. It rewrites the CP1252 misdecode
signature back to `U+2014` across `EcomGroups.GroupName`, `EcomProducts.ProductName` /
`ProductShortDescription` and the `EcomOrderLines` name snapshot on the `FIXT-ORDER-%` keys,
existence-guarded so a clean host is never written to. Section 0's DELETE-then-INSERT already
converges the rows this file owns; section 6 states the convergence rather than leaving it
implicit, and reaches the snapshot columns a reset does not.

## 2.3.1

**`demo-clock.sql` did not compile on SQL Server (Foundry v5 e2e, DW 10.28.10).** Three
compile-time and insert-time faults, all measured on a live apply, none of them reachable by the
script's own shape guards because the batch never got that far.

`usp_DemoClockShift` joins its own `dbo._demoClockExclusion` / `dbo._demoClockGuard` sysname
columns against `sys.tables.name` and `sys.columns.name`. The catalog carries
`Latin1_General_100_CI_AS_KS_WS_SC`; the layer's tables take the database default
`Latin1_General_100_CI_AS`. The two compares (the exclusion `NOT EXISTS`, and the guard
`LEFT JOIN`) raised a collation conflict at compile time, so the procedure never ran. Both now
carry `COLLATE DATABASE_DEFAULT`, which follows whatever collation the target database was
created with rather than hardcoding one.

The `ScheduledTask` registration then failed with Msg 2628: `TaskComment` is `NVARCHAR(255)` and
the literal was 364 characters. Shortened to 251, meaning kept — what it shifts, by what delta,
that the shift is whole-day and uniform, and where the exclusions and guards live.

No behaviour change beyond the script now executing: the shift semantics, the anchor mechanic and
the task recurrence are untouched.

## 2.3.0

**The feature layers' catalogue rows moved here (Foundry 960).** Composed with `sampleData: false`
the distribution was supposed to have an empty catalogue, and the acceptance criterion said so; the
e2e host measured `EcomProducts = 8`, `EcomGroups = 5`, `EcomPrices = 4` on exactly that run. The
rows were not smuggled — they were shipped openly by three feature layers, each README calling it
catalog self-sufficiency, because the base is scaffolding-only. The reason the gate could not name
the owner is that `Set-ConfigFromEdition` *derives* `EcomProducts = 0` from the toggle instead of
measuring what the composed layers insert, so eight products arriving looked like a count mismatch
rather than a finding with an address.

The fix is the plain invariant, restored: the catalogue rides the single `sampleData` toggle and
nothing else. `merge/_sql/feature-fixtures.sql` (declared, phase `after-replace-deserialize`,
order 2) now seeds the 5 groups, 8 products, 4 prices and 2 BOM slots that `feature-pricing`,
`feature-bom-configurator` and `feature-subscription-orders` used to ship in their own mode trees.
**Every id is unchanged** — `PACK-RPP-*`, `PACK-BOM-*`, `PACK-SUB-*` — because each layer's
`behaviorProbes` and demo pages address these products by id; only the owner moved. `email-stats`
and `demo-clock` shift to order 3 and 4.

Consequence worth stating out loud: a feature layer's behaviour probe is now meaningful only on an
edition that also carries sample data. `swift-demo` does; `base-swift` composes no feature layers
at all, which is the composition the emptiness claim was always about.

## 2.2.0

Two things this layer promised and never delivered: a composer could not FIND its SQL, and
what the SQL seeded went stale the week after it landed.

**The loose scripts are now declared and discoverable (Foundry #427).** `merge/_sql/*.sql`
carried no `merge-manifest.json` entry, so a `sampleData: true` composition staged the
files and executed nothing: DemoAgent's `Compose-Edition` reported `{replace:0, merge:0},
files 3`, the storefront came up with 8 products (all feature-layer fixtures) and no
sample-data catalogue, and the flag lied end to end. The Foundry gate never saw it because
it seeds both scripts by explicit path.

The serializer manifest has no shape for a loose script. Its only `providerType`s are
`Content` and `SqlTable`, and `SqlTable` is row-per-YAML under `_sql/<Table>/<key>.yml`, so
there was nothing to add an entry to. The fix is a new **`sql[]` declaration in
`layer.json`**, added to `layers/layer.schema.json` alongside `fragmentTables` /
`fragmentContent` / `files`: per script the file, the mode tree, the phase
(`before-host-start` / `after-replace-deserialize` / `after-merge-deserialize`), the order
within that phase, whether the host must be restarted afterwards, and every `sqlcmd`
variable the caller must supply. A layer shipping a loose `.sql` under a mode tree must now
declare it there.

**The demo clock ships (Foundry #25).** `demo-clock.sql` creates the `_demoClock(Id,
AnchoredTo)` anchor table, `usp_DemoClockShift`, and the daily `Truvio demo clock` task on
the stock `RunSqlScheduledTaskAddIn`.

- The shift is **whole-day and uniform**: every operational date column moves by
  `DATEDIFF(day, AnchoredTo, today)`, which preserves intra-day ordering and every relative
  gap, then the shifter re-anchors its own row. Idempotent (`+1` then `-1` nets zero) and
  catch-up safe after idle days.
- Date columns are **discovered from `sys.columns` on every run**, never hardcoded: a
  reference build shifted 142 columns across 49 tables, every commerce feature spells its
  timestamps differently, and discovery is what keeps the shifter correct across a platform
  upgrade.
- Config and logging tables are excluded through `dbo._demoClockExclusion`, `ScheduledTask`
  first among them: `TaskNextRun` is what the scheduler reads, and the clock's own run
  history must stay readable. Sentinel values outside `[1900-01-02, 2900-01-01)` are left
  alone, so a `9999-12-31` never overflows `DATEADD` and aborts the batch.
- State-marker columns carry a guard in `dbo._demoClockGuard`. `GiftCardCancel` writes no
  reversing transaction and sets no status flag: it cancels by rewriting
  `GiftCardExpiryDate` to now and keeping the balance, so on a cancelled card that column is
  a cancellation timestamp. The shipped guard shifts only cards still in the future, and a
  cancelled card still reads inactive after a run.
- The task's `TaskAddInSettings` value is `EXEC dbo.usp_DemoClockShift;` — the shift SQL
  lives in the procedure precisely so the literal XML carries no metacharacter to escape.

**The email-marketing statistics backfill ships (Foundry #25).** `email-stats.sql` seeds,
per campaign email, one `EmailMessage` send-log row, 24 `EmailRecipient` sends of which 2
carry a delivery error, 3 tracked `OMCLink` rows and 13 `OMCLinkClick` clicks split 5/4/4
across the links, so the backend Marketing dashboards read as a real campaign instead of 0
sent / 0 clicked.

- The grid joins are the whole difficulty and are now carried in the script:
  `RecipientStatisticsByEmail` resolves recipients through
  `EmailMarketingEmail.EmailOriginalMessageId` = `EmailRecipient.RecipientMessageId` (NOT
  `EmailMessageId`), and per-recipient clicked is a count over `OMCLinkClick` joined to
  `OMCLink` where `LinkReferenceKey` is the message id as a string, `LinkReferenceType` is
  `EmailMessaging`, and `LinkClickClickerKey` is the recipient id as a string. Either key
  alone yields 0.
- **Opened is pixel-only and is not attempted.** The per-recipient opened column and the
  `EmailById` aggregates are materialized by the live open-tracking pixel handler and are
  not reproducible from raw SQL.
- The backfill is **discovery-driven**: it seeds every `EmailMarketingEmail` row with no
  send history and is a clean no-op on a composition that ships none. sample-data authors no
  campaign emails of its own, and an addition binds to the base contract, never to another
  layer's rows.
- Idempotent through a marker: every row it writes carries
  `EmailMessage.MessageDomainUrl = 'https://sample-data.example.invalid'`, and the script
  deletes its own marked rows before re-seeding. An email whose send history points at an
  unmarked message is left alone, so a real send is never overwritten.

Unchanged: every reserved key (`FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`), every product number,
every price, the variant structure, and the `EcomProducts = 20` / `EcomGroups = 3`
determinism contract. Minor bump: two new scripts and a new declaration, no existing shape
moved.

New reserved names owned by this layer: `dbo._demoClock`, `dbo._demoClockExclusion`,
`dbo._demoClockGuard`, `dbo.usp_DemoClockShift`, the `ScheduledTask` row named
`Truvio demo clock`, and the `FIXT-RCPT-*` recipient key prefix.

## 2.1.0

The demo catalogue carries no real-world product domain. `catalog.sql` seeded 20 products
literally named "Fixture House Blend" / "Fixture Single Origin" / "Fixture Decaf" into
groups "Fixture Beverages" / "Fixture Equipment" / "Fixture Accessories", with no
description column in the INSERT at all - a coffee-shop test fixture standing in for the
storefront on every edition that sets `sampleData: true`.

Every demo-facing value is now a **function-descriptive placeholder** naming what the row
exists to demonstrate, so the build replaces it per customer:

- Products are `Sample Product NN — <role>` (`Master`, `Qty Tiers`, `Contract Price`,
  `Size Variants`); groups are `Sample Group N — <function>`.
- `ProductShortDescription` added to the master INSERT and carried through the six
  variant `SELECT` inserts, so the PDP/PLP description lane is no longer blank. Each one
  opens with the literal word `Placeholder`, the machine-detectable marker a design gate
  scans for (`/placeholder/i`).
- The RMA demo order line's `OrderLineProductName` follows the master it references.

Unchanged on purpose - this is the layer's determinism contract: every reserved key
(`FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`), every product number, every price, the variant
structure, and every row count. `EcomProducts = 20` / `EcomGroups = 3` still holds, so no
edition's derived row-count contract moves and `surface-swift`'s newsletter product rail
(which cites `FIXT0002/0004/0006/0010` by id) is unaffected. Minor bump: data content
changes, shape does not.

## 2.0.2

RMA demo interplay (P3, RUN-DISTRIBUTION-QUALITY item E). `catalog.sql` gains a section 5
seeding **one delivered order** `FIXT-ORDER-RMA1` (`OrderStateId OS2` Completed, buyer
`98745621`, order line on `FIXT0001`) for the new `feature-rma` layer to return against, plus
the `EcomRmaOrderLines` link to `feature-rma`'s `EcomRmas` request `PACK-RMA-0001`. The link is
seeded here (not in feature-rma) because `EcomRmaOrderLines.RmaOrderLineId` is an int IDENTITY PK
the serializer cannot natural-key insert; raw SQL handles it deterministically. No DB FK on the
RMA tables (verified), so the cross-layer header/link order is free. Idempotent DELETE+INSERT on
the demo keys; no impact on the EcomProducts=20 / EcomGroups=3 / EcomCountries=96 row-count
contract, and harmless (orphan link + one extra completed order) in editions without feature-rma.

## 2.0.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). SQL verified against the 10.28 schema (solution custom columns come from cleandb-align-schema.sql, applied by every gate run before the catalog). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

## 2.0.0

The layer now ships its **entire content as SQL files** under `merge/_sql/` and absorbs
the demo shop catalog (previously the separate `catalog-fixture` layer, retired at 1.0.0).

- **Added `merge/_sql/identities.sql`** — the demo identities (permission groups
  1325/1270/1292, buyer 1328, CSR 1326, memberships) as a shipped, idempotent script.
  Demo credentials are `sqlcmd` variables (`BuyerUserName`, `BuyerPassword`,
  `CsrPassword`), never repo content.
- **Added `merge/_sql/catalog.sql`** — the demo shop catalog for SHOP1/ENU/EUR
  (EcomProducts 20, EcomGroups 3, Size variant axis, qty-tier price ladder), absorbed
  from `catalog-fixture`. The buyer contract price (`FIXT-PRICE-CONTRACT`, customer
  number 98745621) ships here, next to the product it scopes to.
- **Absorbed the reserved key prefixes** `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*`
  (base contract `idRules.reservedFixtureKeys`).
- Editions activate everything above with the single `sampleData: true` toggle;
  `catalog-fixture@1.0.0` disappears from every edition's `add`.
