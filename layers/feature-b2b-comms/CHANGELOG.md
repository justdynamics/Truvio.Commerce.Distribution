# Changelog — feature-b2b-comms

## 1.0.6

The onboarding flow has a folder (Foundry #1338, owner ruling 2026-09-25). Since 1.0.0 flow row
100500 set `EmailMarketingFlowFolderId: 2`, and no layer shipped an `EmailMarketingFlowFolder`
row. The table is empty on a Swift 2.4 database, so the reference pointed at nothing on every
host. 1.0.6 ships the folder and points the flow at it:

- `EmailMarketingFlowFolder` 100530 "Dealer onboarding", `EmailMarketingFlowFolderParentId` 0
  (a top folder). The row has the three columns of the DW 10.28 table (identity key, nullable
  parent, name) and the top-folder shape of a folder created in the admin.
- `EmailMarketingFlow` 100500: `EmailMarketingFlowFolderId` 2 -> 100530.

`merge-manifest.json` gains the `sql/EmailMarketingFlowFolder` entry, which names the one row
file, and `layer.json` `fragmentTables` names the table. The table has a primary key, so merge
deletes no folder the host already has. swift-demo pins 1.0.6.

## 1.0.5

The onboarding flow now has emails to send (Foundry #632, owner decision 2026-09-22). Since
1.0.0 the three flow steps 100501-100503 pointed at `EmailId` 100510-100512, and no layer shipped
those rows, so a delivered flow referenced three emails that did not exist and the operator had
to create them by hand through `EmailSave`. 1.0.5 ships them, each with its `EmailMessage` row:

- `EmailMarketingEmail` 100510 / 100511 / 100512: "Onboarding 1 - Welcome", "Onboarding 2 -
  How to order", "Onboarding 3 - Seasonal promotion". Body pages are the layer's own
  *Dealer welcome*, *How to order* and *Seasonal promotion*; the unsubscribe page is
  surface-swift's *Unsubscribe confirmation page*.
- `EmailMessage` 100520 / 100521 / 100522, one per email (`EmailMessageId` and
  `EmailOriginalMessageId` point at them).

**Page ids travel by GUID.** `EmailPageId` and `EmailUnsubscribePageId` are integer page ids, and
the five layer pages carry `sourcePageId: 0`, so a source id means nothing on a target. The
`EmailMarketingEmail` entry lists `EmailPageId`, `EmailUnsubscribePageId` and
`EmailVariationPageId` in `resolveLinksInColumns`; Serialize writes a `pageRefs` block with each
page's `PageUniqueId`, and Deserialize binds the column to the local page with that GUID first
(Serializer #27, released in 1.0.4-beta). **Engine floor:** this needs Serializer 1.0.4-beta or
later; the base contract floor is already 1.0.6-beta, and `costHints.minSerializerVersion` states
1.0.6-beta as an advisory mirror of it (the schema has no per-layer floor field).

**Where the rows came from.** A SQL-built source host (a fresh clone of foundry-blank with
swift-demo delivered): the source solution's three onboarding emails and their messages copied
in by SQL, rekeyed into the layer's `100500+` band, then one scoped merge Serialize on
Serializer 1.0.6-beta. Treatment on the way in, same convention as 1.0.2:

- sender name -> `Placeholder — sender name`; sender address -> `sender@example.invalid`
- subjects -> `Placeholder — email subject (welcome to the dealer network)`,
  `(how to place an order)`, `(seasonal promotion)`; the source subjects named the source brand,
  a slogan and a product line
- the third email's name dropped the source incentive-programme term for the page name
- recipients: `IncludedUsers` -> `g1325` (the base contract's Customers group, the same group the
  flow's `RecipientsIds` names), not the source's own dealer groups
- folder: the source top folder is not shipped; the emails sit in top folder 1
  (`DefaultTopFolder:default`, present on every Swift 2.4 database), `EmailFolderId` 0
- `MessageDomainUrl` emptied (it named the source host); `EmailCreatedDate` fixed to
  2026-09-23, the scheduled send time cleared (scheduling is off)

Proven on a second fresh foundry-blank clone (Serializer 1.0.6-beta, DW 10.28.11, R1-NET10,
swift-demo delivered online): 3 + 3 rows created with no warning; all 183 cells match the source
host, NULLs included, page ids compared by GUID; flow steps 100501-100503 resolve to emails
100510-100512 whose `EmailPageId` is the local id of *Dealer welcome*, *How to order* and
*Seasonal promotion*, and whose message rows exist. A control re-deserialize with the YAML page
ids overwritten by ids that exist on no page bound all six columns to the right pages, so the
binding is by GUID. The three email pages and the unsubscribe page render identically on both
hosts (cache-buster query strings aside).

## 1.0.4

Patch: the five dealer emails' `Swift-v2_EmailProductCatalog` product pickers named `FIXT000N` rows
that sample-data 4.0.0 no longer ships, so every rail would have rendered empty. Each id is
repointed to the brand master at the same ordinal (`FIXT0001` -> `TCPROD0001`, and so on). Nothing
else changes: the same four-or-two product selection per email, the same layout, aspect ratio and
hidden-price settings, the same copy.

## 1.0.3

**Sanitization.** The README still named the source demo solution it was generalized from, in four
places. The layer's shipped content was already neutral; the prose around it was not, and a layer
README is repo content a consumer reads. Names replaced with what they actually mean - the source
solution, the source incentive email, the source recall email. No content, schema or behaviour
change.

## 1.0.2

Neutralization sweep (completes the pass that shipped `surface-swift` 1.4.0,
`sample-data` 2.1.0 and `surface-dap-portal` 1.0.4). The dealer email pack spoke in an
invented company voice: every email's `EmailHeader` and `EmailFooter` carried the sender
brand **"Dealer Services"**, and the article bodies made commitments on that company's
behalf ("Our seasonal program is open", "Stocked lines ordered before the daily cut-off
ship the same day", "your account manager will take it from there").

Neutralized onto the convention:

- sender brand -> `Placeholder — sender name` in all five headers, and
  `Placeholder — sender name. You can unsubscribe from these emails at any time.` in
  all five footers (the unsubscribe sentence is functional and stays)
- all five article headings and bodies -> `Placeholder — article heading|body (<what
  this email is for>)`
- all five product-rail headings -> `Placeholder — product rail heading (<what this
  rail shows>)`
- "Your parts counter, online" -> `Placeholder — email heading (how to place an
  order)`; it was a slogan and it carried a product domain

Kept, because they are already function-descriptive rather than branding: the page names
(`Cart reminder`, `Dealer welcome`, `How to order`, `Product compliance notice`,
`Seasonal promotion`), the flow name `Dealer onboarding`, the four remaining `<h1>`s that
name the email's trigger ("Your order is waiting", "Welcome to the dealer network",
"Product compliance notice", "Seasonal promotion — pre-order now"), and the five button
labels, which describe the action they perform. The
`{{UserManagement:User.Name}}` personalization token is retained inside the welcome
email's placeholder body so the merge-tag capability is still demonstrable.

Patch bump: 26 field values across 20 paragraphs; no page, row, id, flow step or
manifest entry changes.

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
