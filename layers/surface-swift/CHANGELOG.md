# Changelog — surface-swift

## 1.13.5

Patch: the PDP gallery THUMBNAIL strip reads the asset's display name for its `alt` instead of the
asset's key (Foundry #1246). `Swift-v2_ProductMedia.cshtml` built the thumbnail `alt` from
`asset.Name`, which is the `EcomDetails` row key, so a serialized id such as `TC-DETAIL-TCPROD0001`
was read out to a screen reader. sample-data 4.1.2 ships `DetailsName` on all 253 Images rows and
that value surfaces on the asset as `DisplayName` (measured on the Delivery API: the asset carries
`name` `TC-DETAIL-TCPROD0001` beside `displayName` `Truvio Variant Master 01`), so the data half of
#1246 landed but never reached the rendered page. The thumbnail now prefers `DisplayName` and falls
back to `Name` when a consumer ships an asset without one; the keyword suffix and every other
surface are untouched. The large gallery images already used the product name. Measured red first:
run 20260914-171139 on the standing host failed ALT-01 at all three viewports on exactly these
three thumbnails.

## 1.13.4

Patch: the three footer-navigation pages `Frequently asked`, `Cookie notice` and `Privacy policy`
ship their `Swift-v2_PageProperties` `Icon` empty instead of `/Files/Icons/1_none.svg`
(Foundry #1249). The stock value is the Swift icon picker's placeholder sentinel, not a "no icon"
instruction: the footer navigation template inlines whatever SVG the field names, and that file
draws the words NO ICON, so the served home rendered a visible glyph beside each of the three
links in the Help and info and About columns. Measured on arm B: clearing the three items left
0 glyphs on the served home. The remaining page-properties rows in this layer that carry the
sentinel (Home, About, the header and footer pages, the newsletter pages, Thank you, Secondary
Navigation, Languages/Preferences) reach no rendered navigation on the measured pages and are
left as shipped; a page that later joins a navigation with icons clears its own. No item type,
template or file changes.

## 1.13.3

Patch: the Swift area now SHIPS its ecommerce CURRENCY. `AreaEcomCurrencyId` is written as `EUR`
into both area documents (`replace/_content/Swift 2/area.yml`, `merge/_content/Swift 2/area.yml`)
and removed from the `Site framework` predicate's `excludeAreaColumns` in
`config/swift-content-2.4.json` and `replace/replace-manifest.json`.
`surface.contract-notes.json` records the narrowed exclusion. No content, item type, template or
file changes.

### Why the currency stopped being per-environment (Foundry #1232)

An unbound area is not neutral. Through DW 10.26 it resolved the DEFAULT currency; on DW 10.28 it
resolves the REQUEST CULTURE's currency, so an `/en-us/` storefront serves USD carts. Measured on
foundry-sd4v.mydwsite4.com against Distribution 2c89fe6e: cart `CART783` carried
`OrderCurrencyCode USD`, while all 233 `EcomPrices` rows sample-data ships are `PriceCurrency EUR`.
A USD price context matches no EUR row, so the contract price (`TC-PRICE-CTR-0046`, 36.90), the
customer-group price (`TC-PRICE-GRP-0046`, 39.60) and the quantity tiers on `TCPROD0020` were all
inert and every subject fell through to `EcomProducts.ProductPrice` (TCPROD0046 served 45.00).

`EUR` is a base-owned CONSTANT, not an environment value: it is `CurrencyIsDefault` on every
`EUR$$<lang>` row the base ships. And the obligation could not be discharged by a remote consumer at
all: reaching a standing host by URL and Admin API key gives no SQL channel, and
`/Admin/Api/AreaSave` refuses the area outright (`{"Default page template": ["The value is
required."]}`) when `layoutTemplate` is empty. A binding the price resolver depends on therefore
travels with the layer.

### What is deliberately NOT shipped

`AreaEcomShopId` stays per-environment and `consumerObligation.bindShop` stands. Binding it makes DW
enforce group-in-shop on every product page, and only the FOUR top groups carry an
`EcomShopGroupRelation` row, so a subgroup PDP dies with

```
System.NullReferenceException
   at Dynamicweb.Ecommerce.ProductCatalog.ProductCatalogFrontend.IsGroupInCorrectShop(String groupId, String shopId, String languageId)
```

rendered as a `dw-error` module block - measured on DW 10.28.10 at
`/en-us/shop?GroupID=TCGRP-VARIANTS&ProductID=TCPROD0001`, 36 design probes red. Price resolution
does not need it: every `EcomPrices` row the Distribution ships carries an EMPTY `PriceShopId`.
`AreaEcomLanguageId`, `AreaEcomCountryCode`, `AreaFrontpage`, `AreaCdnHost`, `AreaStockLocationID`
and the timestamps also stay per-environment.

## 1.13.2

Patch: the stock `Swift - Newsletter - Sale Email` product rail named `FIXT0002` / `FIXT0004` /
`FIXT0006` / `FIXT0010`, rows sample-data 4.0.0 no longer ships, so the rail would have rendered
empty on every composition. The four ids are repointed to the brand masters at the same ordinals
(`TCPROD0002` / `TCPROD0004` / `TCPROD0006` / `TCPROD0010`). No other content, item type, template
or file changes.

## 1.13.1

### Binding the shop's product primary page is a consumer obligation (Foundry #969)

`surface.contract-notes.json` `perEnvironmentAreaExclusions.consumerObligation` gains
`bindProductPrimaryPage`: after deserialize, set SHOP1's `ShopProductPrimaryPageId` to the
environment's Shop/Product Details page id, before the host restart. The base ships the column as 0
because page ids are allocated per environment, and nothing told a consumer to set it, so product URLs
generated outside a page context had no primary page to resolve against. The version moves because the
contract a consumer follows gains an obligation; released as 1.13.1 because 1.13.0 already shipped. No serialized content changes.

## 1.13.0

### The TruvioCommerce repository ships its Build+Index.task (Foundry #1070)

`repositories/TruvioCommerce/` shipped `Products.index`, `Products.query` and
`Products.facets` and no task file, and no layer in the distribution shipped one. On a host
whose index builds are drained by the Repository task handler, a repository folder with no
`Build+Index.task` is never rebuilt, while a build call still answers success. The layer now
ships `Build+Index.task` (the stock Swift 2.4 `ProductsFrontend` task: `Products.index`,
build `Full`, repeat 1440) and declares it in `repositories[]`.

### The dashboard templates' cube icon ships with them (Foundry #686)

Five `Swift-v2_Dashboard_*` templates read `/Files/Images/Icons/cube.svg`, and no layer
shipped it. `ReadFile` returns nothing for a missing file, so the tile rendered an empty
coloured badge with no error. `files/Images/Icons/cube.svg` is the stock Swift v2.4.0 icon,
byte-identical to the design package's, and is declared in `files[]`.

### Every colorSchemeId names a scheme the theme defines (Foundry #1003)

The About and Contact rows `grid-row-2` carried `lightgrey`, which no scheme group defines;
both read `lightgrey1`. The Desktop Footer `grid-row-2` and Mobile Footer `grid-row-4` rows
carried `Dark` against the id `dark`, and the theme CSS matches `[data-dw-colorscheme]` by
exact value; both read `dark`. `tools/ci/Validate-Distribution.ps1` check 11 fails any
non-empty `colorSchemeId` that no theme layer's `ColorSchemes/*.json` defines.

### The seo descriptions follow the placeholder convention (Foundry #976, #1109)

The five `seo.description` values on Home, the Home preset, About, Contact and the footer
About us page carried the design package's vendor copy into the meta description and
`og:description`. Each now reads as a function-descriptive `Placeholder` string, in the merge
tree and in `Page presets/`, so a page rebuilt from the preset does not reacquire the vendor
sentence.

### Smaller corrections

- `templates.manifest.yml` no longer lists `Swift-v2_ProductComponentSlider` as referenced by
  Product Details; no serialized paragraph uses it (Foundry #631).
- `Products.index` carries a commented global-field example (`Source="CustomField_<Field>"`)
  and states that a Source naming no indexed field builds silently and indexes nothing
  (Foundry #1197).
- The README carries no hard-coded version; the composition example points at the edition
  pin (Foundry #972).

## 1.12.1

### The ProductMedia header said the PLP was serving those SVGs; it was not (Foundry #1171)

Comment only, no template logic and no serialized content changed.

1.12.0's header wrote that because `Swift-v2_ProductDefaultImage.cshtml` applies no format
filter, "the identical SVG rows have been serving through GetImage.ashx on the listing page
the whole time". The first half is right and the conclusion is wrong. The listing page
EMITTED an `img` node for every SVG row, which is why its counts were green. It never served
one. The `src` on that node is a `GetImage.ashx` url, and `GetImage.ashx` decodes with
SixLabors.ImageSharp, which ships no SVG decoder:

    Image cannot be loaded. Available decoders: Webp, TIFF, GIF, TGA, JPEG, PNG, PBM, BMP

Measured on the composed host: **17 of 17** `tc-*` image requests on one page load answered
HTTP 500 - with no width argument, with width alone and with `width&format` alike - and the
slides read `complete=true` with `naturalWidth=0`.

The asymmetry between the two templates is still real and still the finding, only narrower
than it was written: this template renders no node, the other renders a node that paints
nothing. The catalogue half is fixed in `truvio-demo` 1.7.0, which points every product row
at a PNG.

## 1.12.0

### The buy panel gets a row per component, so nine paragraphs render nine (Foundry #1165)

1.11.0 put the three missing components into rows that were already occupied, and the fix
was inert by construction. `Product Info (right side)` carried NINE active paragraphs
across FOUR `1ColumnFlex` rows and the PDP rendered FOUR - the lowest sort in each row,
the rest emitted with no markup, no `dw-error` and no empty wrapper. Dropped: 22564 SKU,
22565 Stock and 22566 Documents teaser, all three of 1.11.0's, plus 22379
`ProductShortDescription` and 22381 `ProductPriceTable`, which were already being dropped
before it. Those last two are what prove the renderer and not 1.11.0 is the cause.

Same shape as #1136 on a ProductComponent page rather than the ProductDetails page, and
the same fix: **one paragraph per grid row**. Four rows become nine, sequenced 1..9 in
the order the panel reads.

| row | paragraph | item type |
|---:|---|---|
| 1 | `paragraph-c1-1.yml` | `Swift-v2_ProductHeader` |
| 2 | `paragraph-c1-7.yml` | `Swift-v2_ProductNumber` |
| 3 | `paragraph-c1-9.yml` | `Swift-v2_ProductShortDescription` |
| 4 | `paragraph-c1-2.yml` | `Swift-v2_ProductPrice` |
| 5 | `paragraph-c1-3.yml` | `Swift-v2_ProductPriceTable` |
| 6 | `paragraph-c1-4.yml` | `Swift-v2_ProductVariantSelector` |
| 7 | `paragraph-c1-5.yml` | `Swift-v2_ProductStock` |
| 8 | `paragraph-c1-6.yml` | `Swift-v2_ProductAddToCart` |
| 9 | `paragraph-c1-10.yml` | `Swift-v2_ProductMediaTable` |

No paragraph identity moves: every one keeps its `paragraphUniqueId`, `sourceParagraphId`,
`sortOrder` and fields, and only the row it hangs off is new. Four rows keep their own id
too, each staying with the occupant it was already rendering, so a seeded host converges
by gaining five rows rather than by having its panel replaced. The rhythm is unchanged -
the panel opens on `topSpacing` 5, the header block closes on 3, the variant selector
keeps its 4/4 band, and the panel closes on `bottomSpacing` 5.

All eighteen paths are in `replace-manifest.json`, replacing the thirteen that described
the four-row shape.

### The PDP gallery stops discarding the pictures it resolved (Foundry #1166)

`swift-v2_productmedia` painted an EMPTY `carousel-inner` on every PDP - 0 `img` and 0
`video` inside the block on three products, all 200 with `dw-error` 0, after a recycle and
a full rebuild of both repositories. #1145 had already fixed the data and the symptom did
not move.

**It was never the data.** Read-only against the host's stock Swift 2.4
`Paragraph/Swift-v2_ProductMedia.cshtml`, images resolve by asset-category **system name**:

```csharp
product.AssetCategories.Where(x => selectedAssetCategories.Contains(x.SystemName))
```

That is the `EcomDetailsGroupSystemName`, and nothing else - not `ProductAssetCategory`,
not the media folder, not an id. Paragraph 22402 asks for `["Images"]`, `EcomDetailsGroup`
8 is named `Images`, 276 rows carry it. The rows resolved.

They were then thrown away by a **format allowlist** hardcoded in the template:

```csharp
supportedImageFormats = new string[] { ".jpg", ".jpeg", ".webp", ".png", ".gif", ".bmp", ".tiff" };
```

No `.svg`, while `EcomDetailsGroup` 8 itself declares svg among its
`DetailsGroupExtensions`. Every image this distribution ships is an SVG.

And that is why the symptom was an empty container rather than a missing one:
`totalAssets` counts only what the allowlist accepts, so it was 0; with
`DefaultImageFallback` true the next branch forces the list to the default image and
`totalAssets` to 1, so the outer block renders - carousel, rails and modal all paint - and
then each slide is gated on the same allowlist a second time and the default image is the
same `.svg`. Not one `carousel-item` is emitted.

The PLP was green throughout because `Swift-v2_ProductDefaultImage.cshtml` applies **no
format filter at all**. That asymmetry between two stock templates is the whole finding.

`files/Templates/Designs/Swift-v2/Paragraph/Swift-v2_ProductMedia.cshtml` is a one-token
override of the stock render path, alongside the layer's one existing override
(`RelatedProductsList.cshtml`) and documented in-file the same way: `".svg"` added to
`supportedImageFormats`, everything else stock byte for byte, so a Swift roll is a re-copy
plus the same one edit. Declared in `files[]` and in `placeholders[]`.

Scoped to `ProductMedia`. `ProductMediaGallery` carries the same allowlist but no layer
paragraph uses it; `ProductMediaTable` carries it too but serves PDFs, which the stock
document formats already accept.

### repositories[] and itemtypes[] are declared (Foundry #1167)

`layer.json` grows `repositories` (3) and `itemtypes` (130), in the same composed-site
Files-relative vocabulary `files[]` and `placeholders[].path` already use. Before this,
133 of this layer's staged paths were declared nowhere: a consumer staging from `files[]`
staged none of them, an audit comparing `files[]` to disk called the layer clean, and a
retired definition could not be detected as retired. `layers/layer.schema.json` carries
the two new arrays and `tools/ci/Validate-Distribution.ps1` check 10 diffs all three
against disk in both directions, and asserts every placeholder resolves into them.

### Consumer impact

Content ymls changed, so a host on 1.11.x needs a **surface-swift Replace** before the
buy panel renders nine. A template was added, so the `files/` overlay needs restaging
before the gallery renders images. No re-seed: no data change ships here.

## 1.11.0

### The PDP buy panel gets the four children it was short (Foundry #1160)

Container-scoped inside `[data-dw-itemtype='swift-v2_productcomponentselector']`, on both
PDPs and in both identities, the panel held exactly four painted components:
`productheader` 22 px, `productprice` 99 px anonymous / 30 px signed in,
`productvariantselector` 172 px, `productaddtocart` 0 px anonymous / 60 px signed in.
Marine's holds eight. Absent: `swift-v2_productnumber`, `swift-v2_productstock` (both 0
matched page-wide) and the buy-panel documents teaser - the one
`swift-v2_productmediatable` on the page is the section table further down, 0 inside the
panel.

Nothing was wrong with the data or the templates. `ProductNumber` is set on all 96
products, all 60 `EcomStockUnit` rows are populated at qty 148, `EcomDetailsGroup` 7
(`Manuals`) holds 2 pdf rows per product, and the PLP card renders SKU, description and
stock from these same three components on these same products. The paragraphs were never
in the composition: #1136 split the five SECTION heads from their components and did not
touch the panel.

Three paragraphs are added to `Product Components/Product Info (right side)`, placed so
the panel reads in marine's order rather than appended at the end:

| where | sort | item type | why there |
|---|---|---|---|
| `grid-row-1/paragraph-c1-7.yml` | 7 | `Swift-v2_ProductNumber` | between the title (1) and the lede (9), which is marine's `title, SKU, lead` |
| `grid-row-2/paragraph-c1-5.yml` | 5 | `Swift-v2_ProductStock` | after price (2) and the quantity-break table (3), before the variant selector in row 3 |
| `grid-row-4/paragraph-c1-10.yml` | 10 | `Swift-v2_ProductMediaTable` | after add to cart (6), the teaser marine closes its panel with |

The fourth of the marine children, the lede, is `Swift-v2_ProductShortDescription`, and it
is already on disk at `grid-row-1/paragraph-c1-9.yml` and already registered - 1.10.0
landed that registration. "Lead" in the parity census is the lede paragraph, not a
delivery lead time; the layer needs no new field for it and the data layer seeds none.

Field values are lifted from the PLP card instances of the same components, which are the
proven-rendering ones: the stock component keeps `HideInventory` and `HideStockState`
both false, because the area gates price and cart and never stock, and the SKU keeps
`HorizontalAlignment start`. The teaser binds `ImageAssets ["Manuals"]` - the one asset
category that exists on a composed host, the same discipline #1145 imposed on the gallery
- with `DefaultImageFallback false`, so a product with no manual shows nothing rather
than its own photograph in a documents list, and `HideThumbnails true` with a `h6`
`Documents` title, so it reads as a teaser and not as a second copy of the section table.

MARINE'S `hideForPhones` ON THE TEASER IS NOT REPRODUCED, and not by choice: the
serializer's paragraph fragment carries no visibility block at all. The twelve keys a
`paragraph-*.yml` can hold are `paragraphUniqueId`, `sourceParagraphId`, `sortOrder`,
`itemType`, `header`, `template`, `colorSchemeId`, `moduleSystemName`, `moduleSettings`,
`fields`, `permissions`, `columnId` - visibility exists on `page.yml` and nowhere else.
The teaser therefore ships visible at every width. Hiding it on phones is a theme
decision until the fragment grows the field.

All three are registered in `replace-manifest.json`. That is the known drift class here:
a paragraph file no manifest path names is a file the deserializer never creates, and it
fails silently and looks like a content bug. The new `sourceParagraphId` values are
90023-90025 in the reserved 90000+ band.

VALIDATION is container-scoped, never page-wide:
`[data-dw-itemtype=swift-v2_productcomponentselector] [data-dw-itemtype]` on both PDPs,
with the SKU rendering the `ProductNumber` literal and the stock line rendering
`In stock`. #1155 is the same measurement taken page-wide and getting it wrong.

## 1.10.1

### The related-products table served the prices the padlock withholds (Foundry #1154)

A DATA LEAK, and the only defect in this round that is not a cosmetic one. Area 3
ships `AnonymousUsers = cart-price`. The gate demonstrably works for the two PDP
components that read it - the price column renders the sign-in lock and the
add-to-cart column measures `0 px` anonymous, `60 px` signed in. The related-products
list does not read it. Measured anonymously on both PDPs at Distribution 4a4cd05b:
`main [itemprop='price']` totals **5**, all five inside
`[data-dw-itemtype='swift-v2_relatedproductslist']`, each with a matching
`.text-price` and an `itemprop='priceCurrency'` content of `USD`. Signed in the total
is 6 - the same five plus the one the price column is allowed to show. So the exact
figures the padlock exists to withhold are in the served HTML of the same page,
machine-readable, and scraping a gated B2B price list needs no session: it needs the
PDP of one product that relates to others.

The render path is `Swift-v2_RelatedProductsList.cshtml` -> a ServicePage ->
`eCom/ProductCatalog/RelatedProductsList.cshtml`, and the stock 2.4 file of that path
is where the row is built. This layer now ships an OVERRIDE of it. That is a different
kind of file from everything else the layer carries: a layout variant is inert until a
paragraph's `Template` field names it, whereas a file at a stock render path takes
effect the moment the layer is on disk. The override is therefore kept byte-minimal -
**seven inserted lines and zero modified stock lines**, verified by diff against the
2.4 tree:

- two booleans beside the two the stock file already computes and then never uses -
  `hidePrice` and `hideAddToCart`, spelled exactly as `Swift-v2_ProductPrice.cshtml`
  and `Swift-v2_ProductAddToCart.cshtml` spell them, so the three files read as one
  idiom;
- `@if (!hidePrice)` around the contents of the price cell;
- `@if (!hideAddToCart)` around the cart form, because the same gate's other half is
  the third copy of the figure - the form's hidden `ProductPrice` input - and the PDP
  buy panel already hides its cart anonymously, so the row now matches it.

Both cells KEEP their `<td>`. The table's header row is unconditional, and a dropped
cell shifts every column after it. Suppressing contents and not the cell is what the
stock slider card (`eCom/ProductCatalog/ProductSliderStandard/Product.cshtml`) does in
the same situation, and it is the whole of the pattern being copied.

No lock badge is rendered here. The affordance is the theme's
`Swift-v2_ProductPrice/PriceWithSignIn` variant and it is deliberately the one place
on the page that states the gate; a badge per related row would be noise and would
break the assert that counts `.td-price-lock` as exactly 1.

On an area whose `AnonymousUsers` value does not contain `price`, neither branch is
reached and the file renders byte-identical output to the stock one.

VALIDATION is the mirror, not the absence: anonymously `main [itemprop='price']` and
`main .text-price` must both be 0 on both PDPs while `.td-price-lock` and its
`__action` anchor stay at 1, and signed in both counts must be 6. A selector that
matches nothing reads the same as a subject correctly hidden, so the control is
flipping the area's `AnonymousUsers` value off and watching the anonymous count rise.

## 1.10.0

Four composition defects from the v5 round-two census, all the same shape: a
paragraph or a repository file naming something that does not exist, or omitting
something a template dereferences. None raised an error and every row count
around them was correct.

### The gallery named two asset categories and got neither (Foundry #1145)

The PDP hero gallery set `ImageAssets ["Images","Product_details"]` with
`DefaultImageFallback 0`. Both names are stock Swift's, where `Images` is a system
asset category and `Product_details` sits beside it; the Distribution's base ships
neither, so on a composed host `EcomDetailsGroup` holds one row - `Manuals`,
created by the data layer for its pdf rows - and both names filtered to nothing at
`Swift-v2_ProductMedia.cshtml:129`. The default-image fallback at `:145` could not
fire either: it requires `selectedAssetCategories.Count() == 0` and the count was
2. The component emitted its wrapper and no children - childCount 0, innerHTML
length 0, `358 x 0 px` at 390, 0 `img` page-wide at 1440, on both measured products
in both identities.

The paragraph now names one category, `Images`, and sets `DefaultImageFallback 1`.
truvio-demo creates that category and puts its 180 image rows in it - the data half
of contract (a) in the issue. `Product_details` is dropped rather than also created:
a second category holding the same rows is a second thing to keep true, and the
gallery reads one strip. The fallback flag matters independently - with it at 0 the
failure mode is an empty wrapper that paints non-zero at desktop and zero at mobile
from identical DOM, which is what made a paint-judged presence assert flip by
viewport.

surface-swift still ships no asset category of its own. A surface NAMES categories;
a data layer creates them.

### Related products shipped Fields NULL into an unguarded Count (Foundry #1146)

`Swift-v2_RelatedProductsList.cshtml` reads
`Model.Item.GetList("Fields")?.GetRawValue().OfType<string>().ToList()` and then
calls `.Count()` on it with no null guard. `GetList` returns null for a field never
written, the `?.` short-circuits the chain, and the `.Count()` after it dereferences
null. The yml carried fourteen of the item type's fifteen fields and omitted this
one, so the component emitted nothing at all -
`[data-dw-itemtype='swift-v2_relatedproductslist']` matched 0 on both PDPs, in both
identities, at both viewports - while `EcomProductsRelated` held 324 rows, 6 of them
on TCPROD0001 and 5 on TCPROD0051.

`Fields` now ships as `"[]"`, the empty list the stock composition writes for an
unselected checkbox list. Empty and not populated: `Fields` on this item type is a
DISPLAY-GROUP picker, so naming a group would bind the surface to something only a
data layer creates. Same class as #1129.

### The spec band states what the group it names must contain (Foundry #1147)

The PDP Specifications paragraph binds `DisplayGroups ["tc_specs"]`, and the group
was landing with 28 members in `EcomFieldDisplayGroupFields` against 6 names in the
denormalised `FieldDisplayGroupFieldIds` column, one of which -
`ProductCategory|tc_content|tcMedia` - is not a field on any host; the real system
name is `tcMediaSet`. No yml, item-type XML or repository file in this layer carries
that string, and no `ItemType_*` row on the measured host does either. It exists in
that one column only, residue of a seed that typed the list beside the member table
instead of deriving it. The row half is truvio-demo's.

What this layer owns is the naming, so `surface.contract-notes.json` records the
guarantees a composing data layer has to keep for the band to draw anything: the
frontend flag the paragraph's own option query filters on, the
`ProductCategory|<FieldCategoryId>|<FieldId>` reference form, the rule that the
denormalised column is WRITTEN FROM the relation rather than typed beside it, that
every name in it must resolve to a live `EcomProductCategoryField` row, and
`tcMedia -> tcMediaSet` as a known wrong name. The scope note is the part that is
easy to get backwards: `tc_specs` spans four categories and a product renders only
the fields it holds a value for, so seven of twenty-eight on one product is correct
behaviour - the remedy is spreading values, never shortening the group.

### The PLP rail gets attribute facets (Foundry #1149)

`Products.index` set `SkipCategoryFields True`, so the index carried no
`ProductCategory|...` field while the database held 28 category fields with 420
values, and no attribute facet could be added at all. The rail rendered Group (24
values) and Price (2 of its 4 declared bands) against marine's three, the third
being a real attribute facet.

Four changes, and they only work together - a facet is decorative unless the Field
is a SystemName in the index, the QueryParameter is a Parameter in the query with a
`MatchAny` expression in the prunable group, and the Facet is declared in the facets
file:

- `SkipCategoryFields` **True -> False**, or every `ProductCategory|` Source resolves
  empty.
- `SkipDetailImages` **True -> False**: an asset-category gallery and a hover
  alternative image are detail-image rows, and an index that skips them cannot serve
  either to a list surface. This is the index leg of #1145.
- **Four attribute fields**, sourced in the qualified form -
  `tc_data_models|tcMaterialClass`, `tc_commerce|tcDeliveryLeadTime`,
  `tc_content|tcLanguageCoverage`, `tc_users|tcAccountTerms` - measured at 5, 5, 5
  and 4 distinct values over the fifteen products each category owns.
- **The Manufacturer facet is dropped.** It bound a field that resolves and indexes
  nothing: `EcomManufacturers` is empty and `ProductManufacturerId` is NULL on every
  row. `Condition HasValue` suppressed it, so the file declared three facets and the
  rail drew two. The index field and the query parameter STAY - a passed parameter
  with no expression filters to nothing - so a catalogue that ships manufacturers
  restores the facet in four lines.

Four attribute facets and not one because this catalogue PARTITIONS its products
across its four field categories: each owns fifteen products and has no value on the
other forty-five. `Condition HasValue` then does the honest work per listing. A
catalogue with catalogue-wide attributes ships one facet here; the count follows the
data, never the file.

### The replace manifest lists what is on disk, exactly

`replace-manifest.json` carried 294 files for `content/area-3` while 292 exist: eight
entries under `Customer center/CSR/grid-row-1|2|3` with no file behind them, and six
files under `Customer center/Overview/grid-row-6|7` named nowhere. Paragraph numbers
21-24 match across the two spellings and the grid-row indices shift by five, so this
is rename residue - two rows moved pages, the manifest kept the old names and never
learned the new ones. The manifest is the deploy inventory, so eight entries pointed
at nothing and six files were never staged, silently, in both directions at once.

**The two Overview rows have never been staged by any deploy of this layer**, so the
next run is the first on which they render. That is composition which has not been
seen, not composition that regressed, and it wants one look.
## 1.9.1

The Features and FAQ section heads get their bodies (V5-PLAN round two, item 3).

1.8.0 shipped `<h2 id="features">` and `<h2 id="faq">` as `Swift-v2_Text` paragraphs with
an empty `Text` field, on the stated understanding that the data half would fill them. It
does, here. Both are product-independent copy on the shared detail page, which is how
marine's own five-question FAQ works, so they live in the paragraph rather than on a
product row.

Features is six lines, and every one of them names something the page beside it actually
draws: the unit the quantity is calculated in, the account price against list, the
quantity ladder, the stock position, the documents table, the option selectors. FAQ is
six questions answering what a B2B shopper asks when a price is hidden until sign-in and
a row is orderable at zero stock.

A stranded section head is the defect the parity report named on marine's flagship page -
`RelationType='related'` over an empty div - and these two were the last of them on this
PDP.

## 1.9.0

Five PDP sections rendered a head over nothing. `Swift-v2_ProductLongDescription`,
`ProductFieldDisplayGroups`, `ProductMediaTable`, `ProductBom` and `RelatedProductsList`
emitted no markup at all on the flagship detail page - no gridcolumn, no wrapper, no
empty div - while their `h2[id]` anchors and the anchor nav above them all rendered
(Foundry #1136).

### One column slot holds one paragraph

The 1.8.0 skeleton paired each section head with its component in **column 1 of the same
`1Column` row**. A Swift grid row emits one `gridcolumn` per column, so the second
paragraph of the pair is dropped silently - the grid column binding law of #749, and the
same shape as #636. The proof was on the page: the two rows holding a `Swift-v2_Text`
alone (Features, FAQ) rendered their bodies, and the `2Columns` media row rendered both
of its paragraphs.

Each of the five sections is now **two rows**: the head keeps its own `1Column` row and
the component gets a `1Column` row of its own directly beneath it. Fifteen rows on the
page instead of ten, resequenced 1..15, with the head row's `bottomSpacing` dropped to 0
and the component row carrying the section's closing `bottomSpacing: 4`, so the vertical
rhythm is what it was. No paragraph identity changes: the five component paragraphs keep
their `paragraphUniqueId` and their fields, and only the row they hang off is new.

The alternative - a `2Columns` row per section - was rejected: it puts the head beside
its content rather than above it, which is not the measured marine shape.

**This changes content ymls.** A host built on 1.8.x needs a surface-swift Replace to
pick the new rows up; a data-only re-run will not move a paragraph between grid rows.

## 1.8.0

Density parity, structure half (V5-PLAN round two, item 1). The PLP row and the PDP are
rebuilt against the measured marine inventory. What this release ships is the SHAPE and
the COMPONENT CHOICES; what fills them is the data layer's half, and several sections
below will render empty until it lands. That is deliberate: an empty section that is
present, anchored and selectable is measurable, and a section that does not exist is a
gate entry that passes by finding nothing.

### The PLP card is one row, not four

The Product List Card shipped four components in four separate `1ColumnFlex` rows. The
measured marine card is ONE `12ColumnsFlex` / `Swift-v2_RowFlex` row with seven populated
columns and five empty, which is what makes a list row readable at 124px and assertable
per element instead of per stack.

Seven columns now, in marine's order: default image (120px, alternative-image hover),
`Swift-v2_ProductNumber`, the `h2.h6` header, `Swift-v2_ProductShortDescription`,
`Swift-v2_ProductStock` with the inventory count visible, `Swift-v2_ProductPrice`, and
`Swift-v2_ProductAddToCart`. Stock is NOT gated for anonymous visitors - marine gates
price and cart and nothing else - and the cart component's own stock band is suppressed,
because the stock column owns that line and two of them on one row read as a bug.

### The PDP has ten rows

Breadcrumb and the gallery/buy-panel row are unchanged. The gallery was already
configured for multiple assets (`ImageAssets: ["Images","Product_details"]`, thumbnails
bottom, `ShowOnlyPrimaryImage: false`) and needed no change to carry a real image set.
Then: an anchor strip, Overview, Specifications, Documents, Package contents, Related
products, Features, FAQ.

Overview and Specifications keep their existing components and gain a `Swift-v2_Text`
head each carrying the section's `<h2 id>`; both bodies get `HideTitle: true`, so the
heading is emitted once, by the element that owns the anchor.

Component choices, each from the Swift 2.4 vocabulary the parity report maps:

| section | component | binding |
|---|---|---|
| Documents | `Swift-v2_ProductMediaTable` | `ImageAssets: ["Manuals"]`, `HideThumbnails: true` - an `EcomDetailsGroup` system name, not a product file field |
| Package contents | `Swift-v2_ProductBom` | `ListComponentSource: "39"`, the Product List Card, so a BOM line renders as the same seven-component row the PLP renders |
| Related products | `Swift-v2_RelatedProductsList` | `SourceType: "related-products"`, service page 47 |
| Features, FAQ | `Swift-v2_Text` | heading in `Title`, body empty - the item fields the data layer fills |

Relations are the list renderer and NOT `Swift-v2_ProductComponentSlider`. The report
measures marine's own carousel rendering zero items on the aurora and leaving its section
head stranded; a list degrades to a visible empty list instead of an empty div inside a
slider shell, and the `Related products list` service page this layer repaired in 1.5 is
already wired for it.

### The anchor strip has a renderer, and fills itself

`TC_AnchorNav` has shipped as an unused item type since 1.6. It now has a paragraph on
the PDP and, for the first time, `Templates/Designs/Swift-v2/Paragraph/TC_AnchorNav.cshtml`.

Swift stores a repeater as an item-list id, so a serialized layer can ship the paragraph
but not its `TC_AnchorNav_Item` children - `AnchorNav_Items` is `0` and always would be.
The template emits its shell either way, and the theme's `default_custom.js` builds the
links from `main h2[id]` in document order when the list is empty. An editor who fills
the repeater overrides the discovered list entirely. Both paths emit the current path in
front of the fragment, because Dynamicweb's sitewide `<base href>` sends a bare
`#overview` to the front page.

### Manifest registration

Every paragraph added here is registered in `replace/replace-manifest.json`. So is
`Product Info (right side)/grid-row-2/paragraph-c1-3.yml`, the `Swift-v2_ProductPriceTable`
orphaned since 1.7.0: the file has been on disk and absent from the manifest, so the
deserializer never created it and the PDP has never had a quantity-break table even
though this layer ships one. An unregistered paragraph file fails silently and reads as a
content bug, which is why this is checked rather than remembered.

Known residual drift, unchanged here and named so it is not lost: six
`Customer center/Overview` files on disk are still unregistered, and nine
`Customer center/CSR` manifest paths still name files that do not exist. Both are
recorded in 1.7.0. Registering the first six would create two rows on the customer-center
overview that have never rendered, which is a behaviour change this release has no
measurement for.

### Selectors this release makes assertable

The gate binds to rendered markup, so here is what each addition emits. Swift stamps
`data-dw-itemtype` with the lowercased item-type system name on the grid column, which is
the stable half of every selector below.

PLP row, inside `main .product-list article.product[data-product-id]`:

| element | selector |
|---|---|
| image | `[data-dw-itemtype="swift-v2_productdefaultimage"] img` |
| SKU | `[data-dw-itemtype="swift-v2_productnumber"]`, `[itemprop="sku"]` |
| name | `[data-dw-itemtype="swift-v2_productheader"] h2` |
| short description | `[data-dw-itemtype="swift-v2_productshortdescription"]` |
| stock | `[data-dw-itemtype="swift-v2_productstock"]` |
| price | `[data-dw-itemtype="swift-v2_productprice"]`; signed out, `.td-price-lock` |
| add to cart | `[data-dw-itemtype="swift-v2_productaddtocart"]` |

PDP:

| section | selector |
|---|---|
| anchor strip | `main nav.td-anchornav[data-td-anchornav]`, links `.td-anchornav__link` |
| Overview | `main h2#overview`; body `[data-dw-itemtype="swift-v2_productlongdescription"]`, `[itemprop="description"]` |
| Specifications | `main h2#specifications`; body `[data-dw-itemtype="swift-v2_productfielddisplaygroups"]` |
| Documents | `main h2#documents`; table `[data-dw-itemtype="swift-v2_productmediatable"]` |
| Package contents | `main h2#package-contents`; `[data-dw-itemtype="swift-v2_productbom"]` |
| Related products | `main h2#related`; `[data-dw-itemtype="swift-v2_relatedproductslist"]` |
| Features | `main h2#features` |
| FAQ | `main h2#faq` |
| price lock, detail | `main .td-price-lock--pdp`, its anchor `.td-price-lock__action` |

Two dead selector arms the report names are now worth retiring rather than fixing:
`swift-v2_productname` and `swift-v2_productdescription` name item types that do not
exist in Swift 2.4, and never matched anything.

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
