# Changelog — feature-b2b-comms

## 1.0.1

Fix the `SqlTable` flow predicates so they deserialize against the live DW 10.28.1 physical
schema. The `EmailMarketingFlow` and `EmailMarketingFlowStep` YAML rows named their non-PK
columns with short, unprefixed names (`FolderId`, `Name`, `RecipientsIds`, `Active`,
`StartDate`, … and step `FlowId`, `EmailId`, `DelayUnit`, `Delay`); the step PK was also
unprefixed (`StepId`). DW's physical schema prefixes every column with the table name, so the
inserts 400'd with "column not present on target schema" and **0 rows landed** in the Foundry
gate run. Every non-PK key is renamed to `<TableName>` + short name, and the step PK
`StepId` → `EmailMarketingFlowStepId`; the already-correct flow PK `EmailMarketingFlowId` is
kept. Values are unchanged — key names only. Cross-checked against the passing `feature-pricing`
(`EcomPrices` → `Price*`) and `feature-subscription-orders` (`ScheduledTask` → `Task*`) layers,
which fully prefix every column including the PK.

## 1.0.0

Initial release (P18 B2B email-pack fold, marine-demo evidence 2026-07-18). A data-only
feature layer that adds a B2B dealer email pack + the email-marketing onboarding flow on top
of `surface-swift`'s newsletter-email system:

- **5 dealer email content pages** under a new `/Newsletter Emails/Dealer Emails/` subtree
  (area 3, merge tree): *Dealer welcome*, *How to order*, *Seasonal promotion*, *Product
  compliance notice*, *Cart reminder*. Each is a `Swift-v2_Email` page with `1ColumnEmail`
  rows built from the shipped `Swift-v2_Email*` item suite (Header / Heading / Article /
  Product Catalog / Button / Footer). All marine specifics (Northwind, SPIFF codes, REC ids,
  hull counts) are neutralised. Product rails reference the real sample-data catalog SKUs
  (`FIXT*`), `HideProductPrice: True` (pre-login B2B), `Layout: "2"` (numeric-string column
  count — a non-numeric value crashes the template with DivideByZero).
- **Onboarding flow** serialized via new `SqlTable` predicates (`merge/_sql`): one
  `EmailMarketingFlow` ("Dealer onboarding", active, `ScheduledRepeatInterval` 1440) + three
  `EmailMarketingFlowStep` rows with delays +0 / +3 / +7 days (report finding F1 schema). The
  SqlTable provider is generic — these are config rows, not an engine change (precedent:
  sample-data ships orders/users/prices via `merge/_sql`).

**Ids** — nvarchar PK prefix `PACK-B2BC-` (reserved, none used yet); item-instance `fields.Id`
in the `100300+` band; marketing int-identity PKs in the `100500+` band (flow 100500, steps
100501-100503) — all at/above the base-contract `intIdentityFloor` (100000).

**Deferred to the Foundry demo bootstrap** (documented residue — see README + PR body): the
campaign `Email` rows (the report supplies only the `EmailSave` API model, not raw
`EmailMarketing*` email/recipient table columns — guessing them would ship broken
serialization), the abandoned-cart `AbandonedCartRecipientProvider` XML config, recipient-group
binding (the report's `RecipientsIds` parse quirk), the delivery provider (SMTP/Save decision),
and the "Email Marketing Flow Scheduler" scheduled-task row (AddInTypeName not determinable).

`swiftVersion` claim 2.4.0. Composed by `editions/swift-demo.json`; proven in the Foundry gate.
