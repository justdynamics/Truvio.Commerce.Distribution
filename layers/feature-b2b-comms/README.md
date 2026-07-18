# feature-b2b-comms

A **data-only feature layer** (`kind: feature`, no `customCode`/`src`) that adds a B2B **dealer
email pack** and the **email-marketing onboarding flow** to a Swift storefront. Composes on
**`surface-swift`** (it reuses that surface's `Swift-v2_Email*` item types, the `/Newsletter
Emails` subtree, and the shipped *Unsubscribe confirmation page*). Merge mode only.

## What it ships

### Content — 5 dealer emails (`merge/_content`, area 3)
Under a new `/Newsletter Emails/Dealer Emails/` folder:

| Page | Purpose |
|---|---|
| Dealer welcome | Partner-network welcome, `{{UserManagement:User.Name}}` greeting, catalog CTA |
| How to order | SKU/facet search, reorder-from-history, same-day cut-off |
| Seasonal promotion | Pre-order / allocation pitch (de-marined from the SPIFF email) |
| Product compliance notice | Neutral compliance notice (de-marined from the recall email) |
| Cart reminder | Abandoned-cart nudge, held pricing/allocation |

Each is a `Swift-v2_Email` page with `1ColumnEmail` rows: **Header / Heading / Article /
Product Catalog / Button / Footer**. Product rails reference the sample-data catalog SKUs
(`FIXT*`); `HideProductPrice: True`; `Layout: "2"` (a numeric-string column count — non-numeric
crashes the template with DivideByZero, report finding F3). `EmailButton` page-link targets are
left blank because Swift page ids are assigned at deserialize and are not stable to hardcode.

### Marketing objects — serialized via `SqlTable` predicates (`merge/_sql`)
- `EmailMarketingFlow/100500.yml` — "Dealer onboarding", `Active`, `ScheduledRepeatInterval` 1440.
- `EmailMarketingFlowStep/{100501,100502,100503}.yml` — three steps, delays +0 / +3 / +7 days
  (`DelayUnit` 0 = days), pointing at reserved campaign-email anchors `EmailId` 100510-100512.

Raw column names are the report's F1 schema. The serializer's `SqlTable` provider is generic;
these rows are **config, not an engine change** (same pattern as sample-data's `merge/_sql`).

## Id discipline (base contract)
- **nvarchar PK prefix:** `PACK-B2BC-` (reserved for this layer; none consumed yet).
- **item-instance `fields.Id`:** `100300+` band (pages/rows/paragraphs).
- **marketing int-identity PKs:** `100500+` band (flow + steps), `EmailId` anchors `100510+`.

All at/above `intIdentityFloor` (100000). No `_sql/<Table>/<key>` collides with any other layer
(the two `EmailMarketing*` tables are new to the Distribution).

## Deferred to the Foundry demo bootstrap (residue)
These need state the report did not capture as authoritative raw schema, or host config that is
not serializable — the swift-demo Foundry gate run (deserialize + recycle) is the proving step:

1. **Campaign `Email` rows** — the report gives the `EmailSave` API *model* (F2), not the raw
   `EmailMarketing*` email/recipient table columns. Guessing 15+ column names would ship broken
   serialization (the discipline the report applies to the scheduler AddInTypeName). Bootstrap
   creates the 5 campaign emails via the proven `EmailSave` API at the anchor ids 100510-100514
   and wires them to the 5 pages, sender "Dealer Services" `<dealer-services@example.com>`,
   unsubscribe = the shipped Unsubscribe confirmation page, recipients = sample-data group 1325
   (Customers).
2. **Abandoned-cart provider** — `AbandonedCartRecipientProvider` XML (240 min / 14 days / require
   login; shop id = the serialized SHOP1) rides on the cart-reminder email row (deferred with #1).
3. **Recipient-group binding** — the flow's `RecipientsIds` ("G1325") did not parse into
   `recipientGroups` on marine (encoding unknown, report operator step); set in the admin UI.
4. **Delivery provider** — SMTP is host-blocked; demos default to the Save provider (emails to
   disk). A host/global-settings decision, not layer content.
5. **"Email Marketing Flow Scheduler" scheduled task** — the exact `AddInTypeName` is not
   determinable from any available source; a wrong value creates a broken task, so it is left as
   the one remaining operator step (nothing sends until it exists).

## Recipient-group mapping note
Marine used dealership user groups (1346/1354/1355). The Distribution's sample-data ships
`Customers` (1325) / `Account Admin` (1270) / `CSR` (1292); the B2B buyer (1328) is a member of
`Customers`. This pack targets **group 1325 (Customers)** as the dealer-network recipient group.
