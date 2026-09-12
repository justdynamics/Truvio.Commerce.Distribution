# Changelog — sample-data


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
