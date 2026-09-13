# Changelog — truvio-demo

## 1.2.0

Density parity, data half (V5-PLAN round two, items 1-4), against the measured parity
report `parity-gaps.md` (2026-09-13): marine's PLP row and flagship PDP compared
element-for-element with truvio's, and the owner's filter made binding on the result -
**an example ships only if Swift shows it.**

### The taxonomy is re-screened (report section 3, "Backend-only taxonomy")

Eight of the twelve subgroups named a concept with no storefront surface at all. The
report's own table proposed the replacements and they are taken, with two of its
alternatives chosen for the Pages/Paragraphs pair:

| Retired | Replaced by | What draws it |
|---|---|---|
| Workflows | **Units & Measures** | the unit selector on add-to-cart |
| Completeness | **Stock & Delivery** | the stock count, status and delivery line |
| Permissions | **Documents** | the documents table |
| Impersonation | **Relations** | the related-products strip |
| Item Types | **Bundles & BOM** | the package-contents list |
| Pages | **Media & Galleries** | the gallery and its thumbnails |
| Paragraphs | **Currencies & VAT** | the figure itself |
| Groups | **Contract Pricing** | your price against list |

`Variants`, `Price Structures`, `Discounts` and `Assortments` are unchanged - all four
were already showable. Twelve total, three under each of the four top groups, which took
six bands re-homing so each top keeps 15 products and every child reads under its parent.

Concept tokens, SKUs, names and concept tiles follow the group, and so do the order-line
snapshots: a demo order history citing `TC-CMP-0007` against a catalogue that no longer
has that number is a broken page. D-B is untouched - every new name is still PIM,
Commerce or CMS vocabulary, never a real product domain.

The 28 category fields were re-screened by the same filter. `Completeness Score` was the
report's named example - an enrichment metric rendered as a shopper-facing spec row - and
it is gone with `Workflow State`, `Permission Grant`, `Impersonation Scope` and the rest.
What replaces them is what a buyer reads: unit of measure, pack quantity, net weight,
dimensions, material class, rating, compatibility, and commercial terms named from
commerce vocabulary.

A new section 0 runs first and converges a host seeded under the retired taxonomy:
renames in place across the five tables a GroupId reaches, rather than inserting a second
taxonomy beside the first. The category values are rebuilt rather than patched - after a
re-screen a value can be stale three ways at once, and reconciling them one at a time
left four survivors on the first measured pass.

### The row carries B2B information, richer than marine's (report section 1)

The report found marine's signed-in half **faked**: 22 `EcomPrices` rows, none with a
user group, no dealer discount rows anywhere, the anonymous GA4 payload already carrying
the figure the signed-in dealer sees. `truvio-b2b.sql` makes it data.

- 60 short descriptions, one sentence each, every one distinct.
- 60 stock positions on a five-step profile - healthy, low, zero-but-orderable against a
  date the row carries, mid, deep - with 60 matching stock-unit rows on the default
  location. SHOP1 carries `ShopStockLocationID = 0`, so the storefront reads the
  product-level number and these are the breakdown a multi-warehouse demo switches on,
  summing to exactly the same figure so the two can never disagree.
- **96 real `PriceUserGroupId` prices** scoped to the group the buyer persona belongs to:
  60 masters and all 36 variant combinations, because a tier change that threw the buyer
  back to list price reads as a bug. Four in five discount and the fifth is at list on
  purpose, so the demo has a control. Every amount is derived from the row's own list
  price rather than typed.
- 30 quantity-break rows - a three-step ladder on all six variant masters and all five
  Price Structures masters - where 1.1.x shipped one ladder on one product.
- 5 new contract prices on `TC-100200` beside the one already there, which is kept: the
  band named for the mechanism demonstrated none of it.

### The detail page is filled (report section 2)

The report counted marine's flagship PDP at 21 sections and truvio's at 8, four empty, the page
measuring 84 characters of main text. `truvio-pdp.sql` supplies the data half:

- **Gallery**, 2 to 4 images per master: the concept tile plus the photographic frame its
  top group is branded with, plus a detail shot on two rows in five. The photographic
  targets are the Distribution's own `brand/brand-assets.manifest.json` entries by their
  `target` path - fetched at brand time, never committed - so a solution that has not run
  its brand step shows the tile alone rather than a broken page.
- **Documents** as the platform shape the report names: one `Manuals` `EcomDetailsGroup`
  (extensions `pdf`, `InheritanceType 3`, `ControlType 0`) with 120 `EcomDetails` rows,
  which is what `Swift-v2_ProductMediaTable` binds to when configured
  `ImageAssets=["Manuals"]`. Those three column values are read off a live DW 10 solution
  carrying a working group rather than guessed - a NULL `ControlType`/`InheritanceType`
  there is the silent failure the report records - and a host already carrying the
  half-made group is converged.
- **Eight one-page PDFs** in `files/Documents/TruvioCommerce/`, a datasheet and an install
  guide per top group, generated by `tools/make-documents.py` and about a kilobyte each
  because the base-14 Helvetica face embeds nothing. The generator is byte-deterministic,
  so regenerating what is committed shows no diff.
- **324 relations** in three groups. Related products gives every master the other three
  rows in its band; Accessories gives it the same slot in the two sibling bands under its
  top group; Spare parts carries the kit story both ways, because a relation that reads
  from one end only is half a demo. Marine's own "you'll also need" strip is an empty div
  under a stranded head; every master here shows between five and eight.
- **Specification density to seven of seven** on every page, 240 more values.

### The variant selector had no axes to draw (report section 3)

The report found it empty even signed in, on the product whose own Overview copy tells the
reader to open it, with every count correct and nothing erroring. Diagnosed on the live
host: `EcomVariantGroupProductRelation` held **zero rows**, for this layer and for the
whole database. That table answers the selector's first question - which axes does this
product use. The option relations answer which values on an axis a product offers; the
combination rows answer what each intersection costs. Neither answers the first, and with
no answer the control draws nothing. `ProductVariantGroupCounter = 0` on every master was
the same fact stated a second way.

Twelve rows fix it, and they go into section 4 beside the variant data they complete. The
id column is a NOT NULL nvarchar key rather than an identity, measured off `sys.columns`;
the counters are derived from the rows rather than typed.

### Guards, not row counts

Every new section ends in a **resolution guard** that asserts what the PAGE needs, because
a row count was green throughout the period the spec band, the selector and the signed-in
price were each silently empty. Masters priced below list for the persona; two images, two
documents, two relations and exactly seven specification values per master; and six
variant masters each binding two axes that offer at least two options the master carries.

### Currency: already fixed, and verified

The report's closing defect (`$4,500.00` where `$45.00` belongs) was real at the step-7
capture and is **already closed** by 1.1.1's section 8, which moves every currency row
still at the placeholder rate 1 to 100. Verified on the live host this round:
`EcomCurrencies` reads `USD 100` and `EUR 100 (default)`, with the eight other enabled
currencies at their own real rates. No change was made here; the report cites pre-fix
evidence.

Proven on `dwsalesweb\SQL2022` / `foundry.mydwsite4.com` with all four scripts applied in
order inside a single rolled-back transaction. Nothing on the live host was modified.

## 1.1.1

**The spec group existed, was flagged for the frontend, carried 28 members — and resolved to
nothing.** 1.1.0 closed the missing-half finding by seeding `EcomFieldDisplayGroups.tc_specs`
and 28 relation rows, and the closing v5 measurement on DW 10.28.10 found the band rendering a
heading over an empty `.table-responsive`: `1408 × 52`, `dw-error` 0, every row count in the
database correct. `GetProductDisplayGroupFieldsByGroupSystemNames(["tc_specs"])` returned no
fields at all.

The cause is the member NAME. A display-group member is not a field id, it is a *reference* to a
field, and the two field families are referenced differently. A **global** product field
(`EcomProductField`, which also owns its own column on `EcomProducts`) is referenced bare, by
system name. A **category** field is referenced in a qualified, pipe-delimited form:

```
ProductCategory|<FieldCategoryId>|<FieldId>
```

1.1.0 wrote the bare `EcomProductCategoryField.FieldId`, which sends the resolver at
`EcomProductField` — empty on the e2e host, and empty on any host this layer composes, because
this layer ships category fields and no global ones. Nothing matched, and nothing said so.

The form was not guessed. It was read off six unrelated DW 10 solutions on the same SQL instance,
every one of which uses it and no other prefix: `marine-demo` 65 of 65 member rows,
`momar` 1264, `burco` 121, `gerflor` 111, `dw10-demo` 91, `sapporo` 91. In `dw10-demo`, 75 of the
91 qualified names join cleanly to a live `EcomProductCategoryField` row and **zero** bare names
do. `burco`, the one solution that also fills the denormalised `FieldDisplayGroupFieldIds`
column, fills it with the same qualified names, comma-joined — most solutions leave that column
`NULL`, which is the second half of the same lesson: the relation table is what resolves, the
denormalised list is a convenience beside it.

Then it was proved on the host rather than argued. Group 18's 28 members were rewritten to the
qualified form, the pool recycled, and the same PDP fetched anonymously: `dw-error` 0 and a
populated table — *Facet: Group*, *Variant Axis: Tier*, *Completeness Score: 40* — where the
identical request had rendered an empty `<tbody>`. Three rows because `TCPROD0001` carries three
of its category's seven values; a product carries what section 7 gave it, and the band shows
exactly that.

Two earlier hypotheses are recorded as disproven, because a reader will have them too: binding
the group to `SHOP1` through `EcomFieldDisplayGroupShops` (probe W-E — `dw10-demo` binds 8 of its
13 groups and leaves 5 unbound, so the binding is not what gates resolution), and a dot-qualified
`tc_data_models.tcFacet` (probe W-F — the separator is a pipe and the `ProductCategory` segment
is not optional). Both left the table empty and both were reverted.

**The 7c guard now asserts that the group RESOLVES, not that its columns exist.** The shape guard
introduced in 1.1.0 checks `sys.columns` and it was green on the run that shipped an empty band —
column shape was never the thing that was wrong, and a guard that can only pass is not a guard.
The new one counts values reached along the platform's own join path, member name →
`EcomProductCategoryField` → `EcomProductCategoryFieldValue` on a `TCPROD%` product, and raises
severity 16 at zero. Measured both ways on the host inside a rolled-back transaction: **180**
resolving values with the qualified names, **0** with the bare names 1.1.0 shipped. It would have
failed the 1.1.0 apply.

**A host seeded by 1.1.0 converges rather than doubling.** The INSERT is guarded on the qualified
name, so a re-run on a 1.1.0 host would otherwise leave 56 rows of which 28 resolve. The section
now rewrites each bare member to its qualified form in place and deletes any bare row left over,
then rebuilds the denormalised list from the relation as before. Exercised on the e2e host in a
rolled-back transaction: 28 bare → 28 qualified, total unchanged at 28, guard green at 180.

These fixes are authored against measured schema and worked-around host state; their rendered
proof on a clean deserialize is one re-run away.

## 1.1.0

Four measurements from the v5 end-to-end session on DW 10.28.10, each one a thing the
layer claimed and did not do.

**The reassignment seeded but never repaired.** 1.0.1 moved all twelve orders onto the
buyer, and the host still measured 8 on the buyer, 3 on the CSR and 1 on the admin after a
clean re-run: every order insert in `truvio-identities.sql` is `IF NOT EXISTS`-guarded, so on
a host seeded by 1.0.0 not one of the twelve was written and nothing else touched them. The
buyer's *My orders* rendered 8 of 12. New section 4 states the reassignment a second time as
an existence-guarded UPDATE over the whole `TCO-%` range, covering the customer identity block
as a unit - the access-user id the my-orders scope filters on, and the customer number, name
and email the order grids and the receipt render. Guarded on the rows that DIFFER, so a
converged host is not written to. Applied against the e2e host inside a rolled-back
transaction: 8/3/1 before, 12/0/0 after.

**The rate fix moved the wrong currency.** 1.0.1 moved the DEFAULT currency to rate 100 and
the e2e measured the hundredfold intact and merely relabelled: the storefront serves USD,
whose rate was still 1, so a stored 45.00 rendered as `$4,500.00`. The guard now reads the
placeholder rate rather than the default flag - every currency row still at 1 moves to 100.
Measured on the host, only USD is at 1; EUR is at 100 and the other eight (HUF 2, DKK 15,
CZK 29, GBP 86, HRK 99, RON 150, PLN 163, BGN 380) already carry real rates relative to the
default and are left alone, which is why the guard is `= 1` and not `<> 100`. USD becoming
1:1 with EUR is deliberate demo semantics, stated in the script: the catalogue carries one
set of round numbers and they stay readable on the currency the storefront actually serves,
and inventing an FX rate would put wrong money on a prospect's screen. The durable home is
still the base layer's currency seed.

**No product had a long description, so the PDP had no body.** The detail page carries a
full-width Overview band and it rendered at height 0 on every product; the probe measured the
whole PDP collapsing to 84 characters of main text. New section 7b gives all 60 masters two or
three sentences in the same platform-vocabulary voice the names use - what the concept is,
what that row demonstrates, what a prospect can do with it on the page - in
`EcomProducts.ProductLongDescription`, guarded on absence so an edited copy survives and a
1.0.x host is filled. Variant rows inherit the master's body.

**The spec table had nothing to bind to.** The PDP spec paragraph does not name a product
category: Swift's `Swift-v2_ProductFieldDisplayGroups` takes field-display-group system names,
resolved against `EcomFieldDisplayGroups`. This layer shipped 28 category fields and 180 values
and no display group, which is why `surface-swift` 1.5.0 removed the band as permanently empty
and why the e2e found no spec element on the page at all. New section 7c seeds the `tc_specs`
group, its translation and a relation row per `tc_*` category field, derived from the fields
themselves so the two lists cannot disagree; `surface-swift` 1.7.0 brings the band back and
names it. Column names read off `sys.columns` on the 10.28.10 host in this file's own
discipline - `FieldDisplayGroupId` is an `INT IDENTITY`, so the group is addressed by system
name everywhere and the id is looked up. The denormalised `FieldDisplayGroupFieldIds` column is
written from the relation with `STRING_AGG` rather than the `FOR XML` idiom, because the XML
`value()` method needs `QUOTED_IDENTIFIER ON` and `sqlcmd` runs these scripts with it off - the
`FOR XML` form fails Msg 1934 on a real apply, measured.

The whole amended `truvio-catalog.sql` was applied to the e2e host inside a rolled-back
transaction: clean compile, 60 long descriptions written, 28 display-group relations, USD moved
to 100, nothing left behind.

## 1.0.1

Everything below was measured on a live DW 10.28.10 host (SQL Server) during the Foundry v5
end-to-end session. Nothing here is a design change; it is the layer doing what 1.0.0 said
it did.

**Three scripts did not compile.** `truvio-catalog.sql` addressed `EcomPrices.PriceVariantId`
(the column is `PriceProductVariantId`) and wrote the category fields as `FieldTypeId` /
`FieldSort` / `FieldLocked` (the columns are `FieldType` / `FieldSortOrder`, there is no
locked column, and `FieldTemplateTag` is `NOT NULL` and was never supplied). The platform
writes `FieldTemplateTag` as the field's own system name verbatim — `FieldTemplateTag` =
`FieldId` on every row of every reference seed measured — so the inserts now supply it.
`truvio-images.sql` addressed `EcomDetails.DetailProductVariantId`; the column is
`DetailVariantId`. Each of these is a compile-time Msg 207, which is why the scripts' own
`COL_LENGTH` shape guards — a runtime check — never fired; the guards now assert the real
column names.

**`truvio-images.sql` claimed success unconditionally.** Its tail PRINTed a fixed line
naming 12 tiles and 96 rows whether or not a row moved. It now reports the measured
`@@ROWCOUNT` of each write plus the attached total, and raises with a rollback when the
attached total is zero. The attached total, not the insert count, is the assertion: the
attach is idempotent, so 0 inserted on a re-run is correct and 0 attached never is.

**Four of the twelve orders were invisible.** The customer-centre page grants group `1325`
and the *My orders* scope and nothing else, so the orders stamped with the CSR (`100102`)
or the admin (`100103`) reached no persona that can open the page — the order list rendered
eight of twelve. All twelve now carry the buyer (`100101`). CSR and admin reach a buyer's
orders through impersonation, the platform's own path, rather than through widened page
grants; the layer README states this.

**60.00 EUR rendered as 6000.00 USD.** `EcomCurrencies.CurrencyRate` is hundredths and the
platform's own seed ships the default currency at `100`; the host carried `1`.
`truvio-catalog.sql` now ships an existence-guarded UPDATE setting the default currency's
rate to 100. This is a stopgap in the right place for now and the wrong place forever: the
durable home is the base layer's currency seed, queued for the next base release.

## 1.0.0

The first release of the **Truvio Commerce brand data** as its own layer (V5-PLAN §2.4,
decisions **D-B** and **D-D**).

Until now an edition had exactly one place to put demo rows, and it was the layer the gate
uses for its own fixtures. That forced a choice nobody wants to make: either the marker
strings the design gate scans for (`Placeholder …`, the `FIXT*` keys, the RMA order) live
inside the catalogue a prospect is shown, or the brand catalogue displaces the fixtures the
gate asserts on. `truvio-demo` ends the choice. It is a second layer of kind `sample-data`
— no new kind was invented, per D-D — and the two key families are disjoint by
construction: `FIXT*` / `PACK-*` there, `TC*` here. `swift-demo` composes both;
`base-swift` composes neither.

**The naming rule is the substance of the layer.** No real-world product domain appears
anywhere. Four top groups (`Data Models`, `Commerce`, `Content`, `Users`) each carry three
subgroups named from platform vocabulary, the 60 masters read `Truvio <Concept> <Unit>
<NN>` against SKU `TC-<CONCEPT>-<nnnn>`, and the variant axes are `Tier` and `Mode` rather
than `Size` and `Finish`, which are worldly. The 28 category fields are `Facet`, `Variant
Axis`, `Completeness Score`, `Price Matrix`, `Grid Row`, `Permission Grant` and their kin.
The result is a catalogue that doubles as a platform-terminology tour and cannot be
mistaken for a real business — which is the point: demo data that reads as a plausible
supply house is demo data someone eventually ships to a customer by accident.

**What lands** (`merge/_sql/`, all three scripts declared in `layer.json` `sql[]`, phases
and orders after `sample-data`'s):

- `truvio-catalog.sql` — 16 groups (4 top + 12 sub), 60 masters + 36 variant combination
  rows, 40 prices, 1 BOM kit with two group-bound slots, 2 services, a three-step quantity
  ladder, one contract price scoped by customer number, 4 product categories × 7 category
  fields, 180 field values.
- `truvio-identities.sql` — the B2B account, three personas on the fictional
  `truvio-demo` domain, 6 memberships, 12 orders with 20 lines.
- `truvio-images.sql` — the 12 concept tiles attached as the default image of all 96
  product rows.

**Four decisions worth keeping in view.**

Every variant combination carries its **own** `EcomPrices` row. A variant with no price row
inherits the master's, and the whole tier ladder then reads as one price on the PDP — the
axis renders, the selector works, and nothing changes when you use it.

The identities script runs `after-replace-deserialize` rather than `before-host-start`,
where `sample-data`'s identities live, because its orders FK the shop, currency and
catalogue rows. DW caches identity state at startup, so the personas become first-class on
the host restart the catalogue already requires — one restart covers all three scripts.

The orders use only `OrderFlowId 1` states (`OS1 New`, `OS2 Completed`, `OS3 Rejected`).
`OS12`/`OS13`/`OS14` belong to flow 4, and an order carrying a state from another flow
reads as a broken record in every Commerce grid.

Imagery is attached through `EcomDetails` with the column list resolved from `sys.columns`,
and mirrored onto the legacy `EcomProducts.ProductImage*` columns where a build still has
them. The optional detail columns differ across platform builds, and an `INSERT` naming a
column the build lacks takes the whole script down. A missing `EcomDetails` table raises
rather than skips: a demo that seeds no image and reports success is the failure the file
exists to prevent.

Every insert is `IF NOT EXISTS`-guarded on its own key, so a re-run converges. Nothing in
this layer deletes.
