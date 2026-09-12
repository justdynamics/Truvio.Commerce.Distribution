# Changelog — surface-swift



## 1.7.1

Two measurements from the closing round of the v5 end-to-end on DW 10.28.10, both of the same
family: a value that is one escape level too deep, and a gate that reads a field nobody declared.

**The PDP spec band threw on every product, because `DisplayGroups` carried three backslashes.**
`Shop/Product Details/grid-row-6/paragraph-c1-10.yml` wrote the field as
`"[\\\"tc_specs\\\"]"`. YAML resolves `\\` to one backslash and `\"` to one quote, so what
landed in the item table was `[\"tc_specs\"]` — a literal backslash where JSON expects a quote —
and Swift's parse of the field raised
`System.Text.Json.JsonException: "'\' is an invalid start of a value"` into a `dw-error` on the
detail page of every product in the catalogue. The band rendered nothing and the exception rendered
instead.

The value is now `"[\"tc_specs\"]"`, which lands as `["tc_specs"]`. That is the encoding the other
JSON-array fields in this content tree already use and always used —
`Product Details/grid-row-2/paragraph-c1-7.yml` writes `"ImageAssets": "[\"Images\",\"Product_details\"]"`
and both checkout pages write `"DisabledWeekdays": "[\"6\",\"0\"]"`. This paragraph was the only
file in the tree carrying the deeper form, which is why nothing else on the site threw.

**Five gates across four item types read fields nobody declared, so five shipped paragraphs
rendered nothing and said nothing.** The PLP renders five product rows and none of them carried a SKU
(Foundry 1115). The `Swift-v2_ProductNumber` paragraph on the Product List Card is present, active,
bound to a real grid column and pointed at a product whose `ProductNumber` is populated; the stock
template emits `itemprop="sku"`. The only gate past `product is object` is
`Model.Item.GetBoolean("HideProductNumber")` — and `ItemType_Swift-v2_ProductNumber.xml` declared
`Title` and `HorizontalAlignment` and nothing else, which the host item table confirms column for
column. No exception, no `dw-error`: the cell simply did not render and Swift dropped the empty grid
column.

`HideProductNumber` is now declared on the item type, `System.Boolean` with a `CheckboxEditor` and
`defaultValue="False"`, copied verbatim from `ItemType_Swift-v2_EmailProductCatalog.xml`, which has
carried the identical declaration all along — the two templates read the same field and only one
half of the pair was ever declared.

A sweep of the whole surface then asked whether anything else gates the same way. Every
`Item.GetBoolean("…")` call site in the Swift 2.4 design tree — 222 in all, of which 148 read the
current paragraph's own item and the rest read runtime loop objects no item type governs — was
mapped to its owning item type and checked against this layer's XML. Four more were undeclared, and
all four are the same silent shape:

| item type | field | what did not render |
|---|---|---|
| `Swift-v2_ProductStock` | `HideStockState` | the stock state band (`!hideStock`) |
| `Swift-v2_ProductMediaTable` | `DefaultImageFallback` | the default-image fallback path |
| `Swift-v2_ProductMediaTable` | `ShowOnlyPrimaryImage` | the primary-image-only asset path |
| `Swift-v2_ProductComponentSlider` | `Autoplay` | slider autoplay, on the shared `ProductSliderComponent` partial |

All four are declared now, each copied verbatim from the sibling item type in this layer that
already declares it — the label, description, editor and default are not authored here, they are the
ones the surface already ships. `AutoplayInterval` comes with `Autoplay` because autoplay without
its interval is half a feature and `ProductSliderComponent.cshtml` reads both. The sweep is clean at
zero: no template in the tree gates on a field its own item type does not declare.

The shared partials needed their caller traced rather than their path parsed.
`Components/Specifications/*` renders on `Model` from `Swift-v2_ProductFieldDisplayGroups` and its
accordion sibling; `ProductListFacets/*` on the facets paragraph; `OrderDeliveryDate.cshtml` on the
`Swift-v2_CheckoutApp` paragraph; and `ProductSliderComponent.cshtml` on whichever paragraph posted
its own `Model.ID` as the `ParagraphId` form field — which is how `Autoplay` was found: the partial is
shared with `Swift-v2_ProductGroupSlider`, which declares the field, and the naive path-to-item-type
mapping reads the call site as satisfied because *some* item type declares it. Two call sites in
`Components/VariantSelector.cshtml` pass a variable rather than a literal field name and cannot be
checked statically at all; they are recorded here rather than silently counted as clean.

Both fixes are authored against measured host state — the item tables read off `sys.columns` on the
10.28.10 e2e host, the escape levels read off the landed item row — and their rendered proof is one
re-run away.

## 1.7.0

**The PLP row had no SKU, because the paragraph that renders it was never deployed.** The
branded PLP renders five rows and the design leg's `PLPROW-01` found no product number on any
of them. The cause is not a template gap and not an app setting: Swift 2.4 composes the PLP
card out of paragraphs on a component page, the card already carries a
`Swift-v2_ProductNumber` paragraph (`header: SKU`, `sourceParagraphId 22301`) on disk, and the
stock `Swift-v2_ProductNumber.cshtml` already emits `itemprop="sku"`. The file was simply
absent from `replace/replace-manifest.json`, so the deserializer never created it - and
reported `979 created, 0 failed` while not creating it. The paragraph-id gap in the rendered
page says the same thing: 22305, 22306, *22308*.

`Product List Card/grid-row-2/paragraph-c1-2.yml` is now registered, and so are the two
`grid-row-4` files (the row and its `Swift-v2_ProductAddToCart` paragraph) that had drifted out
of the manifest with it. No template ships and no content changes - the three files were
already authored.

**The PDP spec band is back, with the data it needs behind it.** 1.5.0 removed the
`Swift-v2_ProductFieldDisplayGroupsAccordion` band because no layer shipped an
`EcomFieldDisplayGroups` row, so it rendered empty on every deserialize. That was the right
call for the composition as it stood; it is no longer the composition. `truvio-demo` now seeds
the `tc_specs` display group over its 28 category fields, so the band has something to name.

It comes back as the always-visible variant rather than the accordion:
`Swift-v2_ProductFieldDisplayGroups` with `Layout: table`, titled *Specifications*, on a new
full-width row (`grid-row-6`, sortOrder 4) under the Overview band on `Shop/Product Details`.
`HideFieldsWithZeroValue` and `HideGroupHeaders` are on, so a product renders only the fields
it carries a value for and one group serves all four product categories. The accordion item
type stays available and unused; it depends on
`Swift-v2_ProductFieldDisplayGroupsLayoutSelector`, which this layer does not ship.

A composition without `truvio-demo` seeds no display group and the band renders empty, exactly
as it did before 1.5.0 - but `base-swift`, the only such composition that carries this page,
pins `EcomProducts 0`, so there is no product to open it on.

**`replace/_content/templates.manifest.yml` had drifted.** It declared neither
`Swift-v2_ProductNumber` nor `Swift-v2_ProductLongDescription`, and listed
`Swift-v2_ProductAddToCart` against `Product Info (right side)` only. All three now match the
content tree, alongside the new `Swift-v2_ProductFieldDisplayGroups` entry.

Known remaining drift, not touched here: `replace-manifest.json` still omits six
`Customer center/Overview` files and `Product Info (right side)/grid-row-2/paragraph-c1-3.yml`,
and still lists nine paths that no longer exist. A regeneration is the clean fix and is a
change of its own.

## 1.6.1

**The area now carries its own head include (Foundry 1031).** On a freshly deserialized site the
area item field `Swift-v2_Master.CustomHeadInclude` measured as the empty string, so
`default_custom.css` and its render-critical token block were absent from every rendered page while
the three Style-asset sheets linked normally. Nothing failed and the one-shot proof reported green,
because a missing stylesheet is not an error — it is a site that looks slightly wrong.

The field was in this layer's `excludeFieldsByItemType` for `Swift-v2_Master`, sitting in a list of
genuinely per-solution values (tag-manager id, favicon, verification meta, social ids). It does not
belong there: those are a customer's own values and this one is a path into a file the distribution
itself ships. While it was excluded, no serialized content could carry it and there was nowhere else
for the binding to live. It is removed from the exclusion list in the layer config and both mode
manifests, and both `area.yml` files now set
`/Files/Templates/Designs/Swift-v2/Custom/DefaultHeadInclude.cshtml`.

The second half of the finding is a warning for anyone repointing this field: it holds **one** path,
and `default_custom.css` is registered from *inside* `DefaultHeadInclude.cshtml`. Pointing the field
at a customer head include therefore unloads the theme's first tier silently — the customer include
must call `AddStylesheet` on `default_custom.css` first and its own sheet second.

## 1.6.0

**A repository this distribution owns, and the Shop paragraph bound to it (V5-PLAN 2.4).**
`repositories/TruvioCommerce/{Products.index, Products.query, Products.facets}`, staged before host
start the way `surface-headless` stages its own `Headless/` set, and the Shop page's
`Swift-v2_App` repointed from `/Files/System/Repositories/ProductsFrontend/` to it on both the
`IndexQuery` and the `FacetGroups` path.

Why not keep binding `ProductsFrontend`: it is host-supplied — the base contract records it as
`provisionedByGate: false`, no layer ships it — and its facet file still declares facets for the
design package's own demo catalogue, which are dead on any catalogue this distribution composes. A
facet whose field has no values is worse than a missing facet: it renders, takes a slot in the rail
and filters nothing. The host's files are **not** overwritten; the base contract carries no
file-path ownership rule, so two layers on one path would be an unguarded seam.

The three files are deliberately minimal and base-schema only — group, price range and manufacturer,
no category-field bindings, because the base ships no category fields. Each carries the fill-in
recipe for adding one, and the recipe names all three files, because a facet added to one of them
and not the other two is decorative. `Products.facets` also records the failure mode worth knowing:
a repository that is missing at request time returns **HTTP 200** with an in-page Lucene error, so a
repository is never asserted by status code.

**`TC_AnchorNav` and `TC_AnchorNav_Item`** join `itemtypes/`: an in-page jump strip as a real item
type, unused until a row adds it. It exists because the thing a site reaches for instead is a Text
paragraph holding hand-authored `<nav>` markup and an inline `<script>` — content no serializer
round-trips and no editor can safely edit. The child ships no field defaults on purpose: an empty
default renders visibly empty, where a realistic one renders plausible content for a field that
never arrived.

`layer.json` `placeholders[]` declares all five.

## 1.5.2

Patch: the layer ships the Swift version stamp — `files/System/Truvio/swift.stamp.json`,
overlaid to `wwwroot/Files/System/Truvio/swift.stamp.json`:

```json
{ "tag": "v2.4.0", "version": "2.4.0" }
```

A running site has had **no Swift marker at all**: the design package leaves nothing on disk
that names the release it came from, so a session (or a gate) could read the DW version and the
installed AppStore app versions off the host but had to *ask* which Swift it was looking at.
That is the one version axis of the v5 spine (V5-PLAN §2.2) with no observable artifact, and
this file is it. The preflight reads it by path; `tag` is the `dynamicweb/Swift` release tag,
`version` the same release in the 3-digit form this layer's `swiftVersion` already carries.

Declared in `layer.json` `files[]` like every other disk-overlay path this layer owns, so the
activation overlay copies and MD5-verifies it with the 32 design templates. Patch bump: no
content, no SQL, no item type and no template changes — one new inert file on disk.

## 1.5.1

Patch: the serializer config `swift-content-2.4.json` renames its output-subfolder keys onto
the 0.9.0 engine names (`replaceOutputSubfolder` / `mergeOutputSubfolder`); the 0.8.x names
are dead keys the loader ignores while silently defaulting both values. Output paths are
unchanged (the defaults matched). Foundry #561.

## 1.5.0

Four defects the layer shipped since the base split: a dead PDP band, an open CSR gate, two
service pages with no renderer, and no design-template overlay at all.

- **The PDP field-display-group band is gone.** `Product Components/Product Info (right side)/`
  `grid-row-5` held one `Swift-v2_ProductFieldDisplayGroupsAccordion` paragraph naming
  `FieldDisplayGroups: ["MainFeatures","All_specs"]`. No layer in this Distribution ships an
  `EcomFieldDisplayGroup` table, so neither group has ever resolved and the band rendered empty
  on every fresh deserialize, in every edition. The paragraph was the row's only occupant, so
  the row goes with it rather than leaving an empty band under a live heading. Wiring display
  groups to a customer data model is a re-skin step, not something the shipped PDP asserts.
  `templates.manifest.yml` drops the now-unreferenced
  `Swift-v2_ProductFieldDisplayGroupsAccordion` entry.
- **The CSR customer-center subtree is gated, not deny-listed.** `Customer center/CSR/page.yml`
  denied three named groups (Account Admin, Customers, Anonymous) and granted the CSR group,
  with no `AuthenticatedFrontend` entry, while the parent `Customer center` grants
  `AuthenticatedFrontend` read. A signed-in user in none of the denied groups matched no rule,
  inherited the blanket read, and could open `/csr/accounts` and see another company's account
  grid. Deny-listing named groups does not gate a page. The CSR page now carries an explicit
  `AuthenticatedFrontend -> none` alongside its `CSR -> all` grant, and the four CSR-only child
  pages (`Accounts`, `Carts`, `Orders`, `Users`), which previously carried no permission block
  at all, carry the same explicit pair instead of inheriting.
- **The two related-product service pages have a renderer.** `Service Pages/Related products list`
  (tag `RelatedProductsListService`) and `Service Pages/Related products slider_grid` (tag
  `ProductSliderService`) shipped as bare `page.yml` records with zero grid rows and zero
  paragraphs, so the POST `swift.PageUpdater` sends them returned HTTP 200 and 0 bytes and every
  `Swift-v2_ProductComponentSlider` on the site painted nothing, including the stock "Others also
  bought" slider. Each page now carries a `1Column` grid row and one `Swift-v2_App` paragraph
  running `eCom_ProductCatalog` against
  `/Files/System/Repositories/ProductsFrontend/Products.query`, with `ProductListTemplate` set to
  the template the injector expects: `ProductSlider.cshtml` on the slider page (it dispatches on
  the `ProductListPartial` request parameter to `ProductSliderComponent` / `ProductGridComponent`)
  and `RelatedProductsList.cshtml` on the list page. Both pages also gain
  `layout: Swift-v2_PageClean.cshtml`, matching the sibling service pages that already work and
  matching the `LayoutTemplate` the injector posts. `FacetGroups` and `QueryConditions` are left
  empty so the posted `SourceType` / `MainProductId` / `ProductVariantId` / `isVariant`
  parameters govern the result; `PageSize` is 30, the service-page ceiling a consuming
  paragraph's own count overrides. New ids follow the layer convention: fresh GUIDs,
  `sourceParagraphId` 90004 / 90005 in the reserved 90000+ band, item-instance ids 100700-100703
  above the base contract's `intIdentityFloor`.
- **The layer ships a `files/` overlay: the 32 design templates Swift added between v2.3.0 and
  v2.4.0.** surface-swift shipped 128 Swift v2.4.0 item-type XMLs, four of them
  `Swift-v2_Dashboard_{Chart,List,Number,Product}`, and no design templates whatsoever, so a host
  whose Swift design package is v2.3-vintage resolved no template for the four Dashboard item
  types and rendered the v2.4 sign-in user picker, the customer-center Favorites set and the post
  pagination as missing regions behind an HTTP 200. The overlay is the exact v2.3.0 -> v2.4.0
  added-file set, computed by diffing the two tags' `Files/Templates/Designs/Swift-v2/` trees and
  fetched blob by blob from `v2.4.0`, each one verified by recomputing its git blob SHA-1 from
  the bytes and matching it to the tag's tree entry. Declared path by path in `layer.json`
  `files[]`, the convention `theme-default` already uses. Nothing under `Custom/` is touched, so
  the theme layer's disk footprint stays disjoint.

  Known gap: 66 further templates changed content between v2.3.0 and v2.4.0 and are **not**
  overlaid. A v2.3-vintage host keeps its older copies of those. The layer ships only what was
  added, because a missing template is the failure this closes and overwriting a template a
  customer may have edited is not something this layer has a mandate to do.

## 1.4.0

Fresh-deserialize presentability pass. Everything below was visible to a prospect on a
clean composition of this surface, and all of it lived in the layer source.

- **Swift eco-lorem removed from item-type defaults.** Ten of the most-used item types
  (`Text`, `Poster`, `VideoPoster`, `TextAndImage`, `Card`, `Feature`, `Blockquote`,
  `Accordion_Item`, `Slider_Item`, `Logo`) carried Swift's upstream nature/eco demo copy
  in their field `defaultValue` attributes, so every paragraph a demo builder created
  arrived pre-filled with it — and it returned after every re-save. Prose and branding
  defaults blanked (`Logo.LogoName` shipped the literal string "Swift"); generic
  scaffolding defaults kept (button labels, `Poster.Height`, `Logo.LogoWidth`).
- **Home `grid-row-6` authored.** Three side-by-side `Swift-v2_Feature` paragraphs
  ("Bulk ordering made easy" / "Competitive wholesale pricing" / "Dedicated account
  support") all carried the verbatim `Feature` default body, so three different B2B
  promises were each explained by the same sentence about caring for the planet.
- **Footer policy links are page references.** `PrivacyPolicyLink` /
  `CookiePolicyLink` were literal `/swift-2/...` paths while `AreaUrlName` shipped
  empty, so the segment was host-derived and both links 404 wherever culture drives the
  prefix. Now `Default.aspx?ID=224` / `Default.aspx?ID=232`, the link form the rest of
  the surface already uses. `AreaUrlName` is pinned to `swift-2` so the segment is
  deterministic on every consumer host — which is what makes the edition's
  `criticalPaths` a claim this layer can keep. (Foundry #439)
- **Desktop header stops overflowing the viewport.** `Desktop Header/grid-row-4` is a
  `2ColumnsFlex` row with `flexibleColumns: "0,0"` — flex-basis 0 on both columns, so
  the mega-menu and the search field both sized to content and neither could shrink.
  Now `"1,0"`. (Foundry #438)
- **Three empty home-page bands removed**, each of which sat under a live heading: the
  "Our products" slider (`Items: 323`), the "Latest travel guides" post list plus its
  button, and the "Frequently asked questions" accordion (`Accordion_Items: 324`). No
  `Slider_Item` / `Accordion_Item` child rows exist in any layer and none can be
  authored here — the serializer's fragment manifests carry only `Content` and
  `SqlTable` provider entries, and no layer ships a serialized ItemList table.
- **PDP "Similar styles" band removed.** Its `ProductComponentSlider` used
  `RelationType: "most-sold"`, which is empty on a host with no order history, and an
  empty relation makes the component render its whole source page inline. Its heading
  ("Similar styles") also disagreed with its own title ("Others also bought").
- **Alt text authored** on all six content-bearing image paragraphs. The surface
  previously shipped `AltText` set on zero paragraphs.
- **Category description copy is no longer hidden.** `Shop/Product List/grid-row-2`
  shipped `HideGroupDescription: true`, so group merchandising copy rendered nowhere
  site-wide; the sibling instance under `Product Components` already shipped `false`.

- **Every demo-facing string is now a function-descriptive placeholder.** The surface
  shipped a full B2B-distributor storyline (hero headline, feature copy, vanity stats,
  About-page mission and values, Contact copy, employee intro) plus leftover
  mountain-bike editorial in the mega-menu ("Lost Lake starts at its namesake
  trailhead", "the classic Downieville downhill route", two Merida press photos), the
  literal word "Swift" as the header/footer wordmark, and a "DynamicWeb Inc." copyright
  line. All of it is replaced with `Placeholder — <function>` copy naming the slot it
  fills, e.g. `Placeholder — hero headline (customer value proposition)`. The literal
  word `Placeholder` is deliberate: it is the machine-detectable marker a design gate
  scans for (`/placeholder/i`), so anything left un-replaced at build time fails
  loudly instead of shipping. 143 field writes across 58 files.
- **`Page presets/` neutralized too - it is the reinfection vector.** The Home preset is
  a full mirror of the Home page, so a builder cloning it re-creates every string the
  live page just had removed. Same failure class as the item-type `defaultValue`s above:
  fix the live instance only and the copy walks straight back in.
- **Image references that resolve nowhere are blanked** rather than left as broken
  `<img>`: `environment-2.jpg` (the home hero), `details-8.jpg`, both Merida press
  photos and `video-1.mp4` on the About page ship in no layer `files/` payload and are
  absent from the gate host too. Alt text carries the slot description.
- **PDP spec accordion display groups pruned.** `FieldDisplayGroups` listed `Engine`,
  `Battery`, `Equipment`, `Bike_spec`, `Clothing_spec` and `Short_clothes_info` - a bike
  and apparel data model. Reduced to the two generic names, `MainFeatures` and
  `All_specs`. (No layer in the distribution ships an `EcomFieldDisplayGroup` table, so
  none of the eight ever resolved; a customer data model has to supply them.)

Minor bump: item-type XMLs change and shipped rows are removed, but no page, item type
or field is added or renamed, and no consumer-facing id moves. Both fragment manifests'
`files` lists are updated in lockstep with the removals. Deep deserialize proof
(row-count parity, strict-mode) runs in the Foundry gate — see the PR body.

## 1.3.0

Newsletter-email shells fix (P18 B2B email-pack fold, marine-demo evidence 2026-07-18).
The Swift 2.4 serialization shipped the OOTB newsletter-email page SHELLS with no body
(page.yml only) — near-useless on a fresh deserialize. This authors generic-Swift bodies
for the two OOTB shells so demos start from designed emails:

- **`Swift - Newsletter - Announcement Email`** (Dark) — 5 `1ColumnEmail` rows:
  Header / Heading / Article / Button / Footer, brand-neutral announcement copy.
- **`Swift - Newsletter - Sale Email`** (Light) — 6 `1ColumnEmail` rows: Header / Heading /
  Article / **Product Catalog** / Button / Footer. The product rail references the real
  sample-data catalog SKUs (`FIXT0002/0004/0006/0010`), `Layout: "2"` (numeric-string column
  count — a non-numeric value crashes the template with DivideByZero), `HideProductPrice: False`
  (a Sale shows prices). `EmailButton` link targets left blank (Swift page ids are assigned at
  deserialize and are not stable to hardcode).

Data-only serialized content in the `merge/_content` tree, registered in `merge-manifest.json`;
new row/paragraph ids are fresh GUIDs with `sourceParagraphId: 0`, item-instance `fields.Id` in
the reserved `100600+` band (base-contract `intIdentityFloor`). `templates.manifest.yml` updated
to reference the new `Swift-v2_Email*` item types + `1ColumnEmail` rows. Item-type XMLs unchanged.
Minor bump — additive content only. Deep deserialize proof (row-count parity, strict-mode) runs
in the Foundry gate — see the PR body.

## 1.2.1

Raw page-id link hygiene (runtime E2E deserialize sweep, DW 10.27.6, risewell-e2e). A sweep
of the merge/replace trees for raw page-id link references (`Default.aspx?ID=<n>`, page
`shortCut`, and bare page-reference item fields) found every such link resolves to an
in-tree page **except one casing outlier**:

- **`About us` page shortcut** (`Navigation/Footer Navigation/About the shop/About us`):
  `"shortCut": "Default.aspx?Id=165"` → `"Default.aspx?ID=165"`. Every other link in the
  surface uses the canonical `ID=` casing; the lowercase `Id=` risked being skipped by the
  serializer's case-sensitive page-id remap, leaving a raw source id on the target. 165 is
  the in-tree `About` page (sourcePageId 165), so the target is unambiguous.

Data-only, one serialized-content line changed; item-type XMLs and the rest of the merge
tree unchanged. Patch bump. Deep deserialize proof (strict-mode, row-count parity) runs in
the Foundry gate — see the PR body.

## 1.2.0

Multi-language reshape (RUN-SWIFT-MULTILANGUAGE, P3 — Foundry plan). Drops the Dutch
content leg now that nld is removed from the Distribution shop languages (base 3.1.0):

- **Removes the `Swift 2 Nederlands` (area 27) content area** and its feature coupling —
  the entire NL `replace/_content` mirror and its manifest entry. The Distribution now ships
  the single `Swift 2` (en-US, area 3) content area.
- Composes on base 3.1.0 (en-US sole shop default). Data-only serialized content; deep
  deserialize proof (row-count parity, strict-mode) runs in the Foundry gate — see the PR body.

Minor bump — content-area removal, item-type XMLs + merge tree unchanged.

## 1.1.0

Theme fresh-pass fold-in — product-page composition (marine-demo evidence, 2026-07-18).
Ships the two product-description partials that the enriched catalog already carries but
nothing rendered:

- **`Swift-v2_ProductShortDescription`** added to the buy panel (`Product Components/
  Product Info (right side)`), directly under the product title. Renders the product teaser
  under the header, above price.
- **`Swift-v2_ProductLongDescription`** added as a full-width **"Overview"** section on the
  `Shop/Product Details` page (new 1-column row at `sortOrder 3`, between the media/buy-panel
  row and the "Similar products" row; the trailing rows shift down one; title `Overview`,
  `TitleFontSize: h4`, `TextReadability: max-width-on`).

Scoped to the `Swift 2` (en-US) content area only — the `Swift 2 Nederlands` (area 27)
mirror is intentionally omitted because that area is being deleted by the parallel
multi-language change (nld dropped from the Distribution). Data-only serialized content
(`replace/_content/**`), registered in `replace-manifest.json`; new paragraph/row ids are
fresh GUIDs, `sourceParagraphId` in a reserved 90000+ band. Deep deserialize proof
(row-count parity, strict-mode) runs in the Foundry gate — see the PR body.

## 1.0.1

Learnings triage fix (RUN-TRIAGE-20260713 in the Foundry):

- **LRN-uipass-03:** both areas wired `AreaColorSchemeGroupId: swift` /
  `AreaTypographyId: fonts` / `AreaButtonStyleId: buttons` — style-asset pairs that
  no layer (and no Swift release: `Files/System/Styles/` ships `ColorScheme.config`
  only) provides. `TryGet*Style` fails silently and the storefront renders with
  serif fallbacks. All three ids in both areas (replace AND merge trees) now point
  at `default`, which `theme-default` ships as `ColorSchemes/Buttons/Typography
  default.{json,css}`. Gate assert: after composing an edition with theme-default,
  the main area's three style ids resolve to files under `files/System/Styles/`,
  and the home `<head>` carries the three `Styles/` `<link>`s.
- **Config predicate-mode migration (LRN-base232-03):** `config/swift-content-2.4.json`
  predicate modes migrated `Deploy`→`Replace` (×2) and `Seed`→`Merge` (×9), matching the
  already-migrated base config. Engine `0.9.0-beta`'s `SerializerSettings` query validates
  predicate modes strictly (`ConfigLoader.ValidatePredicates`: only `Replace`/`Merge`) and
  returned HTTP 500 on the retired `Deploy`/`Seed` enums — the harness probes that query
  before deserializing, so the WHOLE surface content-deserialize aborted (no Swift areas
  created). With the modes migrated, the surface deserializes and persists the area.yml
  `properties` (incl. the four style columns) as intended. Output split (`replace/`+`merge/`
  dirs, `deployOutputSubfolder`/`seedOutputSubfolder` keys) unchanged.

## 1.0.0

Born in the Swift 2.4 base split (RUN-SWIFT-24; FOLLOWUP bump plan). The Swift
storefront content surface, extracted from `base` 2.4.1 when the base became
framework-only 3.0.0:

- `replace/_content`: both areas (3 "Swift 2" EN + 27 "Swift 2 Nederlands" NL) — the
  curated, brand-neutral structural trees incl. Customer Center per-role permissions.
- `merge/_content`: the ENTIRE former base merge tree (bootstrap content, both areas).
- `replace/_sql/UrlPath`: the friendly-URL redirect row — decision + rationale in
  `surface.contract-notes.json` and README.md (friendly URLs → pages ⇒ surface-owned).
- `itemtypes/`: 128 `ItemType_Swift-v2_*.xml` definitions from the OFFICIAL Swift
  v2.4.0 design package — the surface is self-contained (gate overlays them itself).
- `config/swift-content-2.4.json`: Site framework + 10 seed content predicates +
  UrlPath + the content-scoped exclude maps.
- `surface.contract-notes.json`: content anchors, per-environment Area exclusions,
  protected Swift item types, navDepth + title rules (moved from base.contract.json).

**Proven on DW 10.28.1-PreRelease** (stable re-prove due when DW 10.28 lands stable
on NuGet). Composed by `editions/swift-demo.json`.
