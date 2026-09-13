# Changelog — truvio-demo

## 1.6.0

### The gallery row is derived from its own master, not assigned (Foundry #1137)

#1157 gave every master its own pair and the retest found the residual: of the 276 rows in
asset category `Images`, 192 pointed at a per-product picture and **84 still pointed at
another band's concept tile** - `TC-GAL-TCPROD0042-2`, a Bundles master, pointing at
`tc-tile-price-structures.svg`.

The rekey did not reach them because they were never keyed on the product. The gallery row
was a fixed literal drawn from a twelve-tile ring by seed position, and the anti-repeat
pass beneath it picked *the first tile this master does not already carry* - an ordering
over the ring, not a fact about the product. And the row it produced named a picture that
is shipped, categorised, correctly sorted and served 200, so the path guard, the row count,
the scenic-residue guard and the 404 check were **all green** while the page put a
Price-structures illustration on a kit.

**Derived, not assigned.** Every master owns `tc-tile-<band>-<nnnn>.svg` as its default and
`tc-detail-<band>-<nnnn>.svg` as its hover, and the band and the index are both readable
off the default row. Strip the `-<nnnn>` index off the default's filename and what remains
is that master's own band concept tile:

| row | value | sort |
|---|---|---:|
| `TC-DETAIL-TCPROD0042` | `.../products/tc-tile-bundles-0042.svg` | 0 |
| `TC-HOVER-TCPROD0042` | `.../products/tc-detail-bundles-0042.svg` | 1 |
| `TC-GAL-TCPROD0042-2` | `.../products/tc-tile-bundles.svg` | 2 |

No per-product literal, no ring, no position. The only band a row can name is its own, and
the 60 rows converge in place on a seeded host.

**Three pictures is the ceiling**, so the second gallery row is retired rather than
repointed. The layer ships two generated pictures per master plus twelve band tiles; a
fourth slide could only repeat one of the three, and a strip that steps from an image to
itself is what the distinctness guard already forbids. The 24 `TC-GAL-*-3` literals leave
the seed and a scoped `DELETE` retires them on a host that carries them. **84 gallery rows
become 60**, one per master.

**Guards.** A new band guard counts unstamped gallery rows that do not equal the tile
derived from their own master's default - it must be 0, and it is the only check here that
could have seen this state. The distinctness guard moves from *fewer than 2 distinct
pictures* to *fewer than 3*, which is the real floor now. The Images-category floor moves
84 -> 60. `expectedRows.EcomDetails` 396 -> 372.

### The trees are declared, the tiles are eol-insensitive, the PDP link carries both ids (Foundry #1167, #1157)

`layer.json` gains `repositories: []` and `itemtypes: []` - both empty and both deliberate,
because an empty array states positively that this layer stages neither tree, which the
gate now treats as a different claim from an absent key. This layer's whole staging surface
is its 140 `files[]` paths, and it is now derivable from the manifest.

A root `.gitattributes` marks `*.svg -text`. The #1157 retest diffed a fresh `make-tiles.py`
run and got **120 of 120 DIFFERENT** against the working tree and **120 of 120 IDENTICAL**
against the committed blobs - a line-ending delta alone (`core.autocrlf=true`, no
`.gitattributes`, CRLF 1124 B in the tree against LF 1113 B in the blob). The generator was
deterministic throughout; the checkout was what moved.

And the README's PDP flow now records that `/en-us/shop?ProductID=...` **404s** on its own
for a bundle master: the shop page resolves a product through its group context, so every
demo link carries `GroupID` and `ProductID` together.

### Consumer impact

SQL only, all of it converging. A host on 1.5.x is brought to this state by re-running
`truvio-pdp.sql` - 60 rows updated in place, 24 deleted. No Replace, no restage.

## 1.5.1

### The short descriptions stop sharing a stem, and a guard stops them starting again (Foundry #1158)

The census measured one templated sentence per subgroup: 60 `ProductShortDescription`
values, the component rendering on 5 of 5 PLP rows, every presence assert green, and five
neighbouring cards differing only by a trailing index on the one surface a buyer scans in
order to tell products apart. 1.3.0 replaced the template with sixty written sentences and
closed most of that. What it did not close is what this release measures:

- three sentences ran to **17 words** (`TCPROD0001`, `0003`, `0010`), past the band where
  a PLP cell reads without truncating;
- seven bands opened two or three of their five sentences on the **same stem** - three
  "Priced per" in Units, three "Related to" in Relations, two "Datasheet" in Documents, and
  four bands repeating an article. Five cards that all begin with the same two words scan
  as one card however different their endings are;
- and **nothing asserted any of it**. The file counted no descriptions at all.

Fifteen sentences are rewritten - the three over-length ones trimmed, twelve re-opened on a
distinct stem - and all sixty now sit at 8 to 16 words with sixty distinct values and no
two in a band sharing their first three words. The rewrites are converging `UPDATE`s like
every other row in this file: the predicate names the OLD text, so a host seeded at 1.5.0
moves to the new sentence and a host that never had the old one is untouched.

TWO GUARDS are added at the end of section 1, and both judge what the page would show:

| guard | what it catches |
|---|---|
| `@TcTemplatedBands > 0` | a band whose distinct description count is below its product count - **the state #1158 names**, and the one a row count reads as perfect |
| `@TcEmptyDescriptions > 0` | a master with no description at all, which satisfies the distinctness test exactly once per band and paints an empty component |

No data shape changes: 60 rows before, 60 after. `truvio-b2b.sql` passes `SET PARSEONLY`
on SQL Server 2022.

## 1.5.0

### Every product gets its own picture, and a second one to hover onto (Foundry #1157)

Measured on the composed host: all five PLP rows carried an image component, so the row
was at parity with marine, and the subject was not. Every card on the site showed a flat
concept tile named for its subgroup - `tc-tile-variants.svg` on all of `TCGRP-VARIANTS`,
`tc-tile-documents.svg` on all of `TCGRP-DOCUMENTS` - seventeen tiles over ninety-six
products, five or six products per tile. `TCPROD0001` carried seven `EcomDetails` rows of
the same file. And no product nominated a second image at all, so the hover swap the card
component is configured for had no subject: `ShowAlternativeImageOnHover` true, and
nothing to swap to.

Marine shows a real photograph per product with a 640/1280 webp srcset and a hover swap.
This layer cannot ship photographs - a data layer references no asset outside its own
`files[]`, and the scenic set is a brand-time fetch. What it can ship is a picture that is
actually about one product.

**120 new SVGs**, two per master, generated by the new `tools/make-tiles.py`:
`tc-tile-<concept>-<nnnn>.svg` is the default image and `tc-detail-<concept>-<nnnn>.svg`
is the second. `<nnnn>` is the master's own TCPROD index, so a file name traces to a
product without a lookup and two products in a band cannot share a path by accident.

**The differentiator is geometric, because the old one was typographic.** A PLP card paints
the tile at 120px; a concept word set at 34px in a 480-unit box arrives there around eight
pixels tall, which is exactly why twelve tiles that differed only in their wording read as
one tile. Each tile now carries a two-digit numeral filling a third of the panel, a pip row
whose COUNT is the product's position in its band, a corner mark turned per position, and a
hue per band. The detail image is the same product in the other register - light panel on a
dark ground, marks enlarged - so a hover reads as a second look at one product and never as
a second product. Self-contained: no `<image>`, no font file, no CSS, no script.

The twelve concept tiles STAY. `truvio-pdp.sql`'s gallery strip still draws them, and a
picture a product does not own is what a strip is for. `files[]` goes 20 -> 140.

**The hover row sorts at 1, and that is load-bearing.**
`Swift-v2_ProductDefaultImage.cshtml` builds its alternative by filtering
`product.AssetCategories` to the one category the paragraph's `GetAlternativeImageFrom`
radio names (`Images`), removing the default image from what that yields, and taking the
FIRST of what is left. So the second image must be in the Images asset category -
`truvio-pdp.sql`'s path-scoped `UPDATE` puts it there, which is why `truvio-images.sql`
still does not name the category - and it must sort ahead of the gallery rows at 2 and 3.
Default 0, hover 1, gallery 2 and 3. The `DetailSortOrder` probe is new beside the existing
`DetailSorting` one: 1.4.0 probed only the name this platform build does not have, so its
default rows landed with no sort order at all.

`#TcTile` is keyed on `ProductId` rather than on a group id, and variant rows join it on
`ProductId`, so a combination inherits its master's pair - which is what a variant should
show: the same product in another configuration. The `TC-DETAIL-*` ids are derived from the
product key and therefore unchanged, so a host seeded at 1.4.0 is CONVERGED in place by a
targeted `UPDATE` rather than given a second set of rows beside the first. The new hover
rows take `TC-HOVER-*`.

FOUR MEASURED GUARDS replace one, and all four judge the end state rather than the insert
count, which is legitimately 0 on a re-run:

| guard | what it catches |
|---|---|
| `@attached = 0` | nothing carries a tile - the pre-1.0 empty-grey-box failure |
| `@hoverRows = 0` | no product has a second image; the hover swaps to nothing, silently |
| `@TcSharedDefaults > 0` | two products in one group share a default image - **the 1.4.0 state**, which no row count could see: 96 rows over 12 pictures counts exactly as well as 96 over 96 |
| `@TcMastersWithoutSecond > 0` | a master with fewer than two distinct images |

The sharing guard is scoped to masters (`DetailVariantId = ''`), because variant rows
legitimately share their master's tile.

`expectedRows.EcomDetails` 300 -> 396: the 96 hover rows are the whole of the difference.

## 1.4.0

Six data defects from the v5 round-two census, and every one of them was green on
some count while the page it fills showed nothing.

### The images join an asset category (Foundry #1145)

Swift's ProductMedia component reads the ASSET CATEGORIES its paragraph names and
then the rows that belong to them. `EcomDetailsGroup` held one row on the composed
host - `Manuals`, which this layer creates for its pdf rows - and all 180 image rows
carried `DetailsGroupId NULL`. Not one image in the database belonged to any asset
category, so no category-filtered component could have seen them whatever the
paragraph named.

`truvio-pdp.sql` now creates the `Images` category and puts every image row this
layer owns into it. The column set is marine-demo's own `Images` row read off this
SQL instance rather than guessed - InheritanceType 1, ControlType 0,
IsSystemGroup 1, HasPrimaryImageRule 1 - with one stated deviation: the extension
list gains `svg` and `webp`, because this layer's tiles are SVG and two of the five
brand photographs are WebP. The rows are assigned by PATH, so the default-image rows
`truvio-images.sql` writes and the gallery rows this file writes are both covered by
one statement; the pdf rows live under `/Files/Documents/` and stay with `Manuals`
without being named. The guard asserts what the page needs - zero image rows outside
the category - rather than a row count, which is what measured green over 180 rows
in no category at all.

surface-swift 1.10.0 is the other half: it names `Images` and nothing else.

### The gallery converges instead of skipping (Foundry #1137)

The 1.3.0 tile repoint was insert-only. Every gallery row is guarded
`IF NOT EXISTS` on `DetailId`, and the DetailIds did not change between 26bb0a06 and
4a4cd05b - only `DetailValue` did - so a host seeded at 1.2.0 already had all 84 rows
and nothing was written. Measured there: 45 + 24 + 15 = **84 scenic gallery rows and
zero tile gallery rows**, while the script closed with "all of them concept tiles this
layer ships" and exit 0, because the resolution guard accepted both prefixes.

Each of the 84 rows now carries an `ELSE` beside its `INSERT` that converges
`DetailValue` onto the shipped value, and a new guard fails on a scenic path with no
opt-in stamp.

**The stamp.** `tools/truvio-gallery-photos.sql` stamps every row it swaps
`DetailsName = 'brand-photograph'`, and the convergence skips a stamped row, so a
Replace cannot silently undo a swap a brand step chose to make. The stamp is the only
thing that can distinguish the two states - 1.2.0's residue and the opt-in's result
point at the same five files - which is also why the opt-in's own "rows swapped > 0"
guard was green on a run that swapped nothing. It counts stamped rows now. Its header
is corrected too: the "what the default is without it" paragraph described 1.3.0's
seed and was false of exactly the hosts it was most likely to run against.

### The spec group proves it is complete (Foundry #1147)

`EcomFieldDisplayGroups` id 14 carried six names in `FieldDisplayGroupFieldIds`
against 28 members in `EcomFieldDisplayGroupFields`, and the sixth name -
`ProductCategory|tc_content|tcMedia` - is not a field on any host; the real system
name is `tcMediaSet`. The seed already derives both stores from
`EcomProductCategoryField`, so it cannot type a name; what it could not do was notice
that a host disagreed with it.

Four guards, each naming its own numbers: the relation holds every `tc_*` category
field; it holds every one of them PER CATEGORY (a missing category is invisible on
three products in four, because each product carries values in exactly one); every
name in the denormalised column resolves to a live category field - the assertion
that would have caught `tcMedia`; and the column's element count equals the
relation's. The existing resolution guard still runs last: completeness is not
resolution.

### The Bundles band owns kits that have contents (Foundry #1161)

`EcomProductItems` held four rows in the whole database - two on TCPROD0021, two on
sample-data's PACK-BOM-0001 - and every product in `TCGRP-BUNDLES` owned zero. With
the ProductBom component now present on the PDP, the Package contents section
rendered a visible heading over zero rows.

TCPROD0042-0045 become real BOM parents with two slots each, in the shape TC-BOM-0001
and TC-BOM-0002 already prove: each slot binds a GROUP and names a default child,
which is what makes the configurator a picker. The slots reach the products the demo
path visits - a Variants component into `TCGRP-VARIANTS`, a Documentation component
into `TCGRP-DOCUMENTS`, where TCPROD0051 lives. TCPROD0041 is left alone: it is a
variant master, and variant-master-plus-BOM-parent is a shape this catalogue does not
claim and the gate has never proven.

**The band stays empty on TCPROD0001 and TCPROD0051.** Neither is a kit, and giving a
variant master BOM rows to make a section non-empty would be seeding for the assert
rather than for the demo.

### Every master carries a list price (Foundry #1150)

TCPROD0001 carried 16 `EcomPrices` rows and not one master-level quantity-1 row with
`PriceUserGroupId` NULL; TCPROD0051 the same sixteen and the same gap.
`ProductDefaultVariantComboId` is NULL on every product, so the PDP resolves to the
MASTER and looked up a row shape only ever written for the children. Both of the
demo's price stories were therefore unreachable from the products it points at.
`EcomProducts.ProductPrice` is not that row - it is a field on the product, not a
price the engine resolves.

Rung one of the ladder now exists on every master, read from `ProductPrice` rather
than typed, with a converging UPDATE if it drifts. The quantity breaks at 5, 10 and
25 were rungs two, three and four of a ladder that began part way up. Contract rows
at TC-100200 land on TCPROD0001 and TCPROD0051 - the products the design profile and
the PDP pointer name - beside the five the layer already had. `EcomCurrencies` is
untouched: EUR rate 100 IsDefault 1 is correct here.

### The selector guard says what it measured (Foundry #1133)

#1133 is fixed and verified; the census recorded that its subject is EXACTLY six
against a threshold of six, so the margin is zero. The RAISERROR now builds its
message with the measured count in it and states that six is the whole catalogue,
so a 5 reads as one master that lost an axis rather than as an unmet quota.

## 1.3.0

Three defects the round-two e2e measured on a PRISTINE host, every one of them invisible
to the row counts this layer ships (`costHints.expectedRows` matched exactly while all
three were live).

### The taxonomy is seeded under its final names (Foundry #1134)

1.2.0 re-screened eight subgroup names in the section-0 **converge** block only - a
guarded `UPDATE` for a host already seeded under the retired taxonomy. On a clean install
there is nothing to converge, the predicate is false, and the `INSERT` literals below it
still carried `Item Types`, `Groups`, `Paragraphs`, `Permissions`, `Pages`,
`Impersonation`, `Completeness` and `Workflows` - the exact eight words the 1.2.0 entry
says were retired, reaching the shop navigation and the PLP facet rail.

The final `GroupName` is now in the `INSERT` literal, which is the only place a clean
install reads. The section-0 `UPDATE` stays, unchanged, as the converge path for seeded
hosts: a rename must never be the ONLY place the final name appears. A new taxonomy guard
after the group section joins all twelve subgroup ids against their final names and
`RAISERROR`s with the offending `GroupId=GroupName` pairs, so the next drift names itself
instead of counting sixteen rows and passing.

### The gallery points at pictures this layer ships (Foundry #1137)

All 84 gallery rows pointed at five photographs under `Images/TruvioCommerce/scenic/` -
artefacts of the previous round's brand pass, which had happened to leave them in that
host's `Files` tree. No layer ships them, so a clean install seeded a gallery of 404s, and
the `@TcThinGalleries` guard passed because it counted `EcomDetails` ROWS.

The committed default is now self-contained: every gallery row points at one of the twelve
concept tiles in this layer's own `files/`, with a converging `UPDATE` that moves any row
colliding with its master's default tile onto the first tile that master does not already
carry, so no strip steps from an image to itself. The guard asserts the PATH now - a
gallery row outside `products/` (shipped) or `scenic/` (brand-manifest, brand-step) is a
loud failure - and a second guard asserts the pictures in a strip are distinct.

The photographs remain available as an opt-in: `tools/truvio-gallery-photos.sql` swaps the
gallery onto the five `scenic/` targets `brand/brand-assets.manifest.json` declares, to be
run by hand AFTER a brand step has put them on disk. It is under `tools/` and deliberately
NOT in `layer.json` `sql[]`, because a declared script is one the composer runs and this
one would re-seed 84 404s on any host that skipped the brand step. SQL cannot test for a
file on disk, so that gate is a human step; the README carries the four-line sequence.

### The variant selector guard runs after the rows it asserts (Foundry #1133)

`truvio-catalog.sql`'s selector guard sat between the axis relations and the OPTION
relations it measures, so on a pristine database it read an empty
`EcomVariantOptionsProductRelation`, raised severity 16, and - because a severity-16
`RAISERROR` does not abort the batch - the script carried on, seeded the options, and
printed its own success line on the same run that had just reported failure. Under
`sqlcmd -b` that is exit 1 on a first run and exit 0 on every re-run, which is why it had
never been seen. The guard is moved verbatim to the end of the variant section, after the
last option relation and the last combination row. The assertion itself is unchanged; it
was always the right assertion, in the wrong place.

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
