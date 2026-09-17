# theme-default changelog

## 2.3.7

### The stock column holds its width, so the columns beside it stop moving (Foundry #1279)

2.3.6 removed the five phantom columns and pinned the image inside its own column, and the
PLP still measured a drifting description: Foundry gate `20260917-140643` read
`shortDescription` at x 681.39 / 646.36 / 681.39 at 1440 and 623.39 / 588.36 / 623.39 at
1366 - a 35.03px spread on the middle row, at two viewports, with every cell present.

THE CAUSE IS THE STOCK COLUMN, and it is a column that is not one. Block 27 left
`swift-v2_productstock` at `flex: 0 0 auto` with a `min-width: 5.5rem` floor, and that floor
never applied: the block's own `section > [data-swift-container] > * { min-width: 0 }`
catch-all out-specifies it (0,3,2 against 0,3,1). So the cell computed to `min-width: 0px`
and took its width from its content - 0px on a product with no stock row, 70.06px on one
rendering "12 In stock". Those 70.06px come out of the two `flex: 1 1` columns beside it,
35.03px each, which is the spread exactly. One row in three on this catalogue reports stock,
so one row in three had a different layout, and a human reads that as a ragged list.

A CONTENT DIFFERENCE MUST NOT BE A LAYOUT DIFFERENCE. The column now carries a real basis,
`flex: 0 0 5.5rem`, which `min-width: 0` cannot defeat, and the floor is dropped because a
basis does the job a floor was being asked to do. The column is 88px whether the product has
stock to report or not, and the description starts at the same x on every card.

Measured on foundry.mydwsite4.com before and after the rule: spread 35.03px -> 0px at both
1440 and 1366, card height unchanged at 136px and 120px, well inside the 180px row cap.


## 2.3.6

### The PLP list row drops its phantom columns, and the anchor strip keeps the query (Foundry #1279 #1280)

Two defects an owner hit on the same visit, one in the stylesheet and one in the script.

BLOCK 27 GAINS TWO RULES. The card row is `12ColumnsFlex` and the card fills seven columns,
so Swift emits five empty `data-dw-itemtype=""` columns, each carrying `flex-fill`. Block 27
makes the row WRAP - that is the fix for the width budget and it stays - and a wrapping row
with five growable empties puts real cells on a second line at a different x per row, which
is what made every card ~230px tall for ~120px of content. Swift 2.4 ships no seven-column
flex row definition, so the empty columns cannot be removed in content (surface-swift 1.13.7
records the definition inventory); they are removed here, where they are visible, with
`display: none`. The rule names an EMPTY attribute value, so it can only ever match a column
Swift itself declared empty.

The second rule stops an authored image width from overflowing the column it is pinned in.
The image column is `flex: 0 0 72px` and drops to 56px between 992 and 1440, while the figure
carries a pixel width from content. surface-swift 1.13.7 brings that width to 72, and the
figure is now told to fill its column instead, so the narrow band is covered as well and no
image can paint over the SKU cell at any width.

ANCHORSTRIP KEEPS THE QUERY. `anchorStrip()` built every href from `window.location.pathname`
alone. On a PDP served as `?GroupID=..&ProductID=..` - the shape this host serves - each
anchor therefore pointed at the product LIST, both on the links it discovers from `main h2[id]`
and on the re-point pass over `[data-td-anchor]`, which share the one `path` variable. The base
is now `pathname + search`. Same mechanism as the group-href defect (Foundry #1248), a different
element; surface-swift 1.13.7 fixes the server-side twin in `TC_AnchorNav.cshtml`.

Disk-overlay only, tokens only, no brand colour.


## 2.3.5

### Button hover covers every Swift variant, and the header rule stops repainting button text (Foundry #1274 #1275 #1276)

Three hover defects that the design gate cannot see, all reported by an owner during a re-skin
sign-off rather than by a probe (Foundry #1277 proposes the missing probe).

The filled-button hover named three non-filled variants in its :not() chain. Swift 2.4 emits more:
`link` is a text button, `outline-primary` and `outline-secondary` are outline controls, and the
customer-center row action toggle carries an EMPTY `data-dw-button` attribute
(`<button class="btn btn-outline-secondary" data-dw-button>`). Each took the filled hover and painted
a solid disc under same-colour text or an icon: the link button measured bg rgb(50,63,75) under text
rgb(10,46,91), and the row chevron hovered to a filled disc with its chevron still at ink. The chain
now excludes all three shapes and they take the outline/ghost tint instead, so every variant has a
hover of its own.

`[data-swift-page-header] a:hover` recoloured BUTTON text as well as navigation links, because Swift
renders header CTAs as anchors carrying `data-dw-button`. On a re-skin whose accent is also its button
fill that lands accent on accent: a filled header button measured navy text on its own hover grey. The
header and navigation anchor hovers now carry `:not([data-dw-button])`; header buttons are styled by the
button rules, which is where they belong.

Block 29 is new: the icon-top Feature tile. Swift paints its icon figure on an inline
`background-color:var(--bs-body-color)` black square and does not make the tile a full-height column, so
the buttons across a three-column row sit at different heights. The tile becomes a column flexbox filling
its grid cell with the button wrapper pinned to the bottom, and the icon box takes the soft accent tint
at the theme radius. Measured on a 13-tile overview: one height per row (241/266/217/192 px) and one
button bottom. `align-self: flex-start` is load-bearing, or the column stretches the 56px box to the full
column width. The icon-LEFT variant renders `> div.d-flex` and is untouched.

Disk-overlay only, tokens only, no brand colour.



## 2.3.4

### The mobile header logo clamp makes room for a four-item header (Foundry #1260)

The below-md logo figure clamp moves from 150px to 132px.

surface-swift 1.13.6 fixes #1260 by moving the MiniCart out of its own grid row and into
the row that already carried the off-canvas trigger, the logo and My account, so the mobile
header paints ONE row instead of two. That is the right fix for the wrap, and it changes the
row budget: four action items now share the 358px container at a 390px canvas.

The anonymous My account control is the constraint, not the logo. Its anchor carries a
text-nowrap label and measures 137px at every logo width tested; with the cart added its
column fell to 121px, so the anchor overran its column by 16px and the canvas by 6.4px.
documentElement and body both read 396 against a requested 390, which is a COLLAPSE-01 FAIL
(the overflow clause is fixed at <= 1px and is not waivable, correctly).

The width was measured, not chosen by arithmetic. At 390 under a phone UA on home, shop and
the PDP: 150px overflows by 6px; 140px reaches 0 but leaves 3.6px of slack; 132px, 128px and
120px all reach 0 and all plateau at the same 382px right edge, i.e. 8px of slack. 132px is
therefore the smallest reduction that reaches the plateau. Signed in, Swift renders a ~48px
initials button instead, so the anonymous state measured here is the worst case.

No affordance is hidden: every control keeps its icon, its label and its accessible name.
Disk-overlay only, one declaration in the existing block 13.

## 2.3.3

### The edge fill contrasts with the ground it sits on (Foundry #1262)

On a stock swift-demo all three edge instances computed `background-color: rgb(255,255,255)`
over a white ground: the footer crest read `--dw-color-background` from the `<footer>` element,
which Swift leaves unpainted while the dark scheme sits on the footer's inner grid rows, and the
two Home edges read the row below their owner, which is white like the owner (the hero's dark
scheme is on the poster paragraph, not the row). The mask was present, nothing painted, and the
design leg's PAINT-01 rows do not assert contrast.

Block 26 of `default_custom.js` now derives every fill against the owner's own ground:
`adjoin()` takes the first `--dw-color-background` that resolves and differs from the owner's,
reading the adjoining element, then the first scheme-bearing element inside the owner, then the
first inside the adjoining element, and sets it on the owner as `--td-edge-adjoin`. The footer is
adjoined to its first scheme-bearing row the same way. Block 22 reads `--td-edge-adjoin` on the
footer crest too, ahead of the footer's own `--dw-color-background`. The per-edge tokens
`--td-edge-fill-hero`, `--td-edge-fill-alt` and `--td-edge-fill-footer` keep their meaning and
still win when a brand sets them; `--td-edge-fill` stays the last resort where no candidate
contrasts. Expected on a stock swift-demo: the hero edge in the poster's dark scheme, the footer
crest in the footer row's dark scheme. The re-gate measures it; this fold ships no host proof.

## 2.3.2

### One edge fill per instance, following the adjoining scheme (Foundry #1186)

With a custom `--td-edge-mask` on base-swift home, the computed `mask-image` was present on
all three `.td-edge` instances - hero bottom, alternate row, footer top - and nothing was
visible: 2.3.1 shipped one `--td-edge-fill` (`#FFFFFF`) for every edge, and the grounds on
either side were white or near-white. The single fill only ever read against the dark Truvio
hero. A probe that checks for `mask-image` passes while nothing paints.

Block **#22** now reads a fill per instance at the pseudo-element:
`--td-edge-fill-hero`, `--td-edge-fill-alt` and `--td-edge-fill-footer`. Unset, the two bottom
edges take the `--dw-color-background` of the row below their owner, which block 26 of
`default_custom.js` copies onto the owner as `--td-edge-adjoin`, and the footer crest takes the
footer's own `--dw-color-background`. `--td-edge-fill` stays as the last resort. The per-edge
tokens are never declared on `:root`: a custom property holding `var()` resolves where it is
declared, so a root default would resolve before any owner carried `--td-edge-adjoin`.

Where the grounds on both sides of an edge are the same colour no default can make it
visible, so the README now states that a brand sets all three tokens.

### The signed-in account name no longer widens the phone header (Foundry #1200)

Signed in as a persona whose name is 18 characters, COLLAPSE-01 failed at 390 on the PLP and
a PDP: overflowX 10px, anonymous 0px. Swift's MyAccount avatar dropdown renders the name in a
`div.text-nowrap` inside `button.nav-link.hstack` with no max-width, so the name set the width
of the header line (145px for "Veltrix Demo Buyer").

New block **#28**, below 768px: the `SignInDropdown_<id>` button gives up its automatic
minimum, and the name block takes `max-width: 6.5rem` with `overflow: hidden` and
`text-overflow: ellipsis`. The avatar initials stay visible, and the full name still reads in
the open dropdown panel. The overflow context is on the name block alone, which holds only its
own text, so block #23's guard against overflow on header elements that contain a panel is
unaffected.

### The slider cover-card cap no longer collapses the CardCoverFull hero (Foundry #947)

The cover-card cap written for the tile layouts selected every
`[data-dw-itemtype="swift-v2_slider"] .swiffy-slider .card`. On CardCoverFull it zeroed the
inline `min-height:55vh` with `!important`, and its `clamp(15rem, 34vh, 21rem)` height, not
`!important`, lost to the card's own `.h-100`. `height: 100%` of an auto-height chain
resolves to 0: the hero measured a 2px card inside a 58px strip holding only the indicator
dots.

The cap now applies only inside a `.slider-container` that does not carry
`--swiffy-slider-item-width: 100%`, the property CardCoverFull alone writes. For that
container the card keeps `min-height: 55vh` with `height: auto`, and its
`.card-img-overlay` joins the flow, so long hero copy grows the card rather than being
clipped at 390. Both rules were measured in a Tier 1 sheet before this fold (card 502px at
1400x900, 557px at 390x844, CTA inside the card).

## 2.3.1

### The PLP price lock gains the action the PDP lock has (Foundry #1159)

Measured anonymously at 1440, the listing rendered `.td-price-lock` on all five rows
with the text "Account price" and `.td-price-lock__action` **0 page-wide**. The same
lock on the detail page rendered the anchor, reading "Sign in for account pricing".
The two surfaces disagreed: the detail page invited the visitor to sign in, the listing
stated a fact and offered no way to act on it. Signed in, both locks are 0 and the PLP
column reads `$45.00 - $79.20 In stock`, so the swap itself was never the defect - only
the anonymous call to action. This was the last live remnant of the marine "PLP anon
price substitute" parity row.

The variant resolved the sign-in URL inside `if (!inProductList)`, so in list context
the href was `string.Empty` and the anchor's own emptiness guard dropped it. The
resolution now happens once, unconditionally, through the identical two lines the stock
`Swift-v2_MyAccount/UserAvatarDropdown.cshtml` uses -
`Services.Pages.GetFirstModulePageForArea(Pageview.AreaID, "UserAuthentication")` then
`SearchEngineFriendlyURLs.GetFriendlyUrl` - so both contexts point at the same page and
a site that renames or re-cultures its sign-in page carries both. On an area with no
`UserAuthentication` page the anchor is still omitted and the badge still renders.

`inProductList` survives and keeps its only remaining job: the `td-price-lock--pdp`
modifier. The two contexts now differ in SHAPE and not in capability - the detail
instance stacks and stretches the anchor onto its own full-width line, the list instance
stays a chip.

Block **#24** is amended for that chip. `.td-price-lock` gains `flex-wrap: wrap` and
`min-width: 0`, and the `align-self: stretch` on `.td-price-lock__action` is narrowed to
the `--pdp` instance; the list anchor takes `max-width: 100%` and `white-space: nowrap`
instead. The wrap is the point: the PLP price cell is `flex: 0 0 auto`, so anything it
cannot wrap it charges to the row, and 2.3.0's whole subject was a row with no width
left to give. The anchor drops under the label when the column is narrow rather than
widening it.

Block **#11** needed no change - it has dressed "the pill that renders INSIDE
swift-v2_productprice" on the PLP since P4, and has been styling an element that never
rendered.

VALIDATION: anonymously, `main .td-price-lock__action` must be >= 1 on the PLP as well
as the PDP, and 0 in both places signed in; the control is the identity flip, which
before this changed the PDP count and not the PLP count. The width control is #1156's:
`scrollWidth / clientWidth` on both roots, both identities, 1440 and 1366.

## 2.3.0

### The signed-in PLP row gets a width budget (Foundry #1156)

Blocks #10 and #15 sized the list card for the ANONYMOUS column set: five of the
seven columns carry non-shrinkable bases, only the header has `min-width: 0`, and
the row does not wrap. Signed in the row gains a real price figure and a real cart
control and nothing can give the width back, so the line overcommits and picks a
victim.

Measured, legs run 20260913-111100, both roots: `1454 / 1440` (14px) at desktop and
`1469 / 1366` (103px) at laptop, AUTHENTICATED only, with five
`swift-v2_productshortdescription` cells at `0 x 136 px` still carrying 77-89
characters. Anonymous measures `overflowX 0` at both widths and mobile passes in
both identities - the columns do not exist anonymously and the row stacks on mobile,
which is why five rounds of anonymous design runs never saw it. The 14-vs-103 spread
is the finding: the wrap point sits between the two widths.

New block **#27** fixes the budget rather than the victim, the same discipline as
block #23 and the search field. The non-shrinkable floor goes from
`72 + 150 + 280 + 100 + price + cart` to `72 + stock + price + cart`; number, header
and description become shrinkable against stated floors; the description wraps
instead of carrying block #10's nowrap + overflow + ellipsis trio, which is what
turned a too-narrow cell into a zero-height line; and the row wraps, so the cart
drops to a second line of the same card before the line can push the document.
Between 992 and 1440 the budget is tightened again - that is the band the 103px was
measured in.

No `overflow` is set on the row, the card or either root: the probe measures both
roots precisely to catch a theme hiding the scrollbar a human would have seen.

**The after-widths are a computed floor, not a measurement.** The session that wrote
this was read-only on the host, so the sheet has not been staged. Validation is the
e2e design leg with `-PersonaUser TruvioBuyer`; `-SkipPersona` cannot validate it.

## 2.2.2

Two live-measured defects from the v5 design leg, run 20260913-101914, both of
them invisible to every check except the one that measures what actually paints.

### The three edge instances painted into the content above them (Foundry #1152)

All three declared `.td-edge` instances failed PAINT-01 on every page and viewport
they appeared on - 21 FAIL rows - while every box-model number read healthy at the
same moment. The measured painted clearance: `footer::before` 0.00px sitewide in
both identities, `main .td-edge-top::before` -1700.11px on the home page,
`main .td-edge-bottom::after` -71.00px. Three separate causes, one doctrine error
behind all of them: the clearance was reserved on the element that DECLARES the
motif rather than on the element whose ink the band covers.

- **The footer crest, 0.00px.** The crest is sitewide, and the only rule that gave
  `main` any end padding was `main:has(> .td-edge-bottom:last-child)`, which
  matches no served page - the home page's last row is not the hero, and the PLP
  and PDP carry no bottom edge at all. So the band began exactly where the last
  ink in `main` ended. The reservation now sits on `main`, keyed on the footer
  actually carrying the crest, and the crest is anchored `bottom: 100%` so it
  rises out of the footer into that reserved gap instead of over the footer's own
  first rows. The footer's own `padding-block-start` rule is gone: it padded the
  owner, below the band, where nothing was ever at risk.
- **The bottom poster edge, -71.00px.** The owner's floor was expressed as
  `.td-edge-bottom { --dw-row-space-bottom: 16px }`, and Swift resolves a row's
  padding from `[data-swift-gridrow][data-dw-row-space-bottom="0"]`, whose (0,2,0)
  out-specifies a (0,1,0) class. Every poster hero is authored at spacing step 0,
  so the floor was discarded and the owner's last ink sat exactly on its own box
  bottom. It is now a padding PROPERTY sized off `--td-edge-h`, with the variable
  restated at attribute specificity so Swift's own declaration computes the same
  number.
- **The top boundary edge, -1700.11px.** Not underspacing: the instance was
  arranged so that it could never be cleared. A top-anchored band is judged
  against the ink of the scope it paints into, and for an owner inside `<main>`
  that scope includes every row BELOW the owner, so a boundary row halfway down
  the page measures against ink 1700px underneath it and is negative by
  construction at any padding value. A top anchor is sound only when its owner
  terminates the ink it threatens, which on a page is the footer and nothing else.
  Block 26 therefore draws an in-main boundary as a bottom edge on the row ABOVE
  it - the same band in the same place, with the ink it covers owned by the
  element that reserves it - and `.td-edge-top` stays the footer utility. The
  receiver rule for a hand-applied in-main top edge is kept so the utility is safe
  either way.

The neutral-bevel default, the three-knob token contract and the brand-time
one-declaration mask swap are all unchanged. Nothing was fixed with `z-index` and
nothing was shrunk to fit.

### `PriceWithSignIn.cshtml` still did not compile after 2.2.1 (Foundry #1135)

2.2.1 resolved the `PriceViewModel` ambiguity and introduced a different compile
error in the same file, so the observable symptom did not move: a `dw-error` dump
in the price column of every PLP card and both PDPs, `.td-price-lock` rendering
nowhere in either identity, and a PLP card 9,013px tall against marine's 124px.

```
Line 71: The type or namespace name 'Services' does not exist in the namespace
         'Dynamicweb'
```

There is no `Dynamicweb.Services` on 10.28.10. The service class is
`Dynamicweb.Content.Services`, and the bare `Services.Pages.…` form the file used
before 2.2.1 was correct - only the `@using` that brought it into scope was
removed alongside the ambiguity fix. Both the call and the directive are now the
verbatim stock forms, each verified present in a stock template on this host:

- `@using Dynamicweb.Content` - `Paragraph/Swift-v2_MyAccount/UserAvatarDropdown.cshtml:4`
- `Services.Pages.GetFirstModulePageForArea(Pageview.AreaID, "UserAuthentication")` -
  `Paragraph/Swift-v2_MyAccount/UserAvatarDropdown.cshtml:108`
- `Dynamicweb.Frontend.SearchEngineFriendlyURLs.GetFriendlyUrl(…)` -
  `Components/VariantSelector.cshtml:160`
- the three `Dynamicweb.Ecommerce.ProductCatalog.PriceViewModel` sites 2.2.1
  qualified are kept as they are; that is what removed the ambiguity, and
  `@using Dynamicweb.Content` does not reintroduce it.

Compiled against 10.28.10 on the host before release this time, which is the
standing lesson of two releases in a row shipping this file uncompiled.

### The signed-in Add to cart label at 1.62 contrast (Foundry #1153)

CONTRAST-01 failed six times, the variants PLP and the flagship PDP at all three
viewports, in the authenticated pass only - the control is hidden from anonymous
visitors, so the defect was structurally invisible until the persona step existed.

The 0.65 is Bootstrap's, not this theme's, and the control is genuinely disabled:
`Swift-v2_ProductAddToCart.cshtml` writes `disabled` whenever the product is a
variant master with no variant chosen, which is every card on a variants PLP and
the master PDP. Bootstrap dims the whole control with
`opacity: var(--bs-btn-disabled-opacity)`, and because the opacity is on the
button it multiplies the label's own alpha: white at alpha 1 x 0.65 composites to
`#dbe8e2` over a fill that is already pale, Swift building it as
`rgba(var(--dw-color-button-primary-rgb), 0.8)` and painting `#97bead`. 1.62
against a 4.5 floor, and the failing colour appears in no stylesheet.

An inactive control now states its state with a flat, opaque pair and keeps its
label at full alpha: `--td-slate` on `--td-hairline`, measured 7.10:1. The label
is 16px / 600, which is not large text by either threshold, so the floor that
applies is 4.5 and not 3.0. Darkening the label instead is the trap in this class
- the same 0.65 multiplies whatever is put there. Both values are existing theme
tokens, so a brand palette carries the tier with no new declaration.

## 2.2.1

`PriceWithSignIn.cshtml` did not compile on 10.28.10, so every paragraph that named
it rendered a `dw-error` block where the price belongs: 12 on the shop list, 5 on the
variants PLP, 1 on the flagship PDP. The lock affordance 2.2.0 exists to ship had
therefore never rendered anywhere, and neither had the price it guards (Foundry #1135).

Three compile faults, all in the file and none in the platform:

- **`@using Dynamicweb.Frontend` made `PriceViewModel` ambiguous.** The Razor host on
  10.28.10 resolves `Dynamicweb.Frontend.PriceViewModel` and
  `Dynamicweb.Ecommerce.ProductCatalog.PriceViewModel` in the same unit, so the bare
  name cannot bind. The using block is now exactly the stock
  `Paragraph/Swift-v2_ProductPrice.cshtml` block - `Dynamicweb.Ecommerce.ProductCatalog`
  and `Dynamicweb.Ecommerce.Products`, nothing else - and the three visual-editor
  placeholders name the type in full anyway. `@inherits` already qualified
  `Dynamicweb.Frontend.ParagraphViewModel`, which is the only thing the using bought.
- **`Services` is not in scope** in a `ViewModelTemplate<ParagraphViewModel>`. The
  sign-in lookup and the friendly-URL call are now
  `Dynamicweb.Services.Pages.GetFirstModulePageForArea(...)` and
  `Dynamicweb.Frontend.SearchEngineFriendlyURLs.GetFriendlyUrl(...)`.
- **`string?` needs a `#nullable` context** a generated Razor class does not have, and
  templates compile warnings-as-errors. `priceMin` / `priceMax` are plain `string`.

The render is unchanged in both states: signed out the area still gets `.td-price-lock`
with its sign-in anchor on the detail page, signed in it is the stock price rendering.
A template variant this central is compiled against the target platform before release.

## 2.2.0

Two additions and one rename, all of them in service of the round-two density parity
the surface layer ships alongside.

### `td-wave-*` becomes `td-edge-*`

Block 22 named its mechanism after one silhouette. A wave is a brand's fit, and this
layer is brand-free, so the name made every other shape read as a misuse of the utility.
The classes are `td-edge-bottom` / `td-edge-top` / `td-edge-alt` and the tokens
`--td-edge-mask` / `--td-edge-fill` / `--td-edge-h`. Every clearance rule is unchanged and
still sized off `--td-edge-h`. Nothing outside this branch referenced the old names.

The shipped silhouette is now deliberately dull - a barely-perceptible shallow bevel -
which is what a brand-free default should be. `Images/Brand/wave.svg` becomes
`Images/Brand/edge.svg` carrying that path.

`Images/Brand/edge-truvio.svg` lands beside it: the Truvio line, a softened zigzag with
gently rounded peaks, vertices every 120px alternating y=58 and y=20 with each apex
rounded over a 30px leg. Industrial rather than organic, and rounded so it does not read
as a warning stripe at 40px on a phone. **Nothing paints it.** Block 22 carries one
commented declaration showing the entire brand-time edit: set `--td-edge-mask` to that
path as a data URI in the brand's own sheet, loaded after this one, and all three
instances change at once.

**A Truvio-branded site must perform that flip.** The standing e2e site is branded
Truvio; until its branding step sets `--td-edge-mask` to the `edge-truvio.svg` path, the
three instances below paint the neutral bevel - correct, inert-looking, and not the brand.

### The motif is applied, so the paint asserts have subjects

All three `PAINT-01` entries SKIPped for want of a subject. Block 26 of
`default_custom.js` supplies three: the home hero row takes `td-edge-bottom`, the first
colour-scheme boundary after it takes `td-edge-top`, and the site footer takes
`td-edge-top` for the sitewide crest.

Owner selectors, one gate entry each: `main .td-edge-bottom::after`,
`main .td-edge-top::before`, `footer::before`.

It is applied from JavaScript because a Swift grid row cannot carry a class. The stock
`Grid/Page/RowTemplates/Swift-v2_Row.cshtml` emits `data-swift-gridrow`, a colour-scheme
attribute and spacing attributes, and no class authored from content; grid-row
serialization has no `cssClass` key either. The 2.0.0 note claiming the opt-in is "one
entry in a grid row's CSS-class field in the Visual Editor" was wrong, and is corrected
here.

Hanging the pseudo-elements straight off colour-scheme adjacency and the footer landmark
is the other available route and is rejected: the classes ARE the contract that block
22's clearance rules and a `paintClearance` gate entry both key on, and a site adding a
fourth instance should be adding one class rather than a fourth bespoke structural
selector nobody can find later.

Scope comes from content, not from a page id. The hero is the first direct child section
of `main` containing a Swift poster, so a PLP, a PDP or the cart gets neither main-side
instance and this file never learns a page number.

### The signed-out price column gets an affordance

`Paragraph/Swift-v2_ProductPrice/PriceWithSignIn.cshtml`: the stock Swift 2.4 price
component with one block ahead of it. When the area's `AnonymousUsers` field gates prices
and the visitor is anonymous, stock Swift renders an empty div - a blank column with no
explanation, which also lets a presence-only price assert pass vacuously. The variant
renders a neutral lock badge there instead, and on a detail page a sign-in anchor with it.

The copy is generic - "Account price", "Sign in for account pricing" - and both strings
go through `@Translate`, so a re-skin changes them in the translation table. Classes are
`td-price-lock`, `__icon`, `__label`, `__action` and the `--pdp` modifier. The href
resolves through `Services.Pages.GetFirstModulePageForArea(Pageview.AreaID,
"UserAuthentication")` and `SearchEngineFriendlyURLs`, the same two lines stock
`Swift-v2_MyAccount/UserAvatarDropdown.cshtml` uses, so it survives a renamed sign-in page
and a second culture.

It is a VARIANT, not an overlay of the stock file. Marine edits the default in place,
which makes price rendering a permanent customisation and masks the next Swift upgrade of
the component. A variant is inert until a paragraph's `Template` field names it, and inert
again on any area that does not gate prices.

Block 24 dresses it; block 25 dresses the surface layer's anchor strip
(`nav.td-anchornav`), sticky from 768 up only, with `scroll-margin-block-start` on
`main h2[id]` sized off the same variable as the strip's own height so a jump cannot land
a heading underneath it. Block 26 of `default_custom.js` also carries the strip's
base-href repointing and its empty-list fallback.

Everything above resolves through the `--td-*` tokens and `currentColor`, so a palette
swap carries it and no colour scheme is special-cased.

## 2.1.0

**Block #23 - the laptop band.** Home and the PLP overflowed horizontally by exactly 66px at
1366, and the header search field computed `0 x 58`, both at 1366 only. The sheet has three
breakpoints - 767.98, 991.98 and 992 - so 1366 and 1440 were one tier to every rule in it, and
nothing between 992 and infinity could tell them apart.

The header lays the logo lockup, the megamenu nav row, the icon cluster and the search field on
one flex line, and that line's min-content width is a fixed budget: a 210px inline-hardcoded
logo figure, the gap / `padding-inline` / caret this sheet adds to every nav item, and the stock
header container gap. None of it shrinks. At 1440 it fits with a few pixels of slack; at 1366 it
is 66px over. The identical 66px on two structurally unrelated page bodies is the proof that the
source is the header they share.

The search field was the casualty, not the cause. The relaxation in the header-affordance
section zeroes the 260px minimum Swift ships on the field's inner wrapper and supplies no basis
in its place, which makes it the one item on the line that can absorb the overcommit - so it
absorbed all of it and collapsed to zero while the line still overflowed.

Block #23 fixes the budget. Between 768 and 1440 the four contributions sized for 1440 close to
values the mobile tier already proves usable - logo figure to 170px, header container gap to
.5rem, nav gap to .1rem, nav-link `padding-inline` to .1rem and the caret to .34em with no
margin - and the search field is given a flex basis so it grows into what that frees. At the
seven-item bar `HEADER-01` measured: 40 + 14.4 + 44.8 + 14.6 = 113.8px returned against a 66px
overcommit, and every term but the logo is per-item, so the margin widens as the bar does.

The field keeps its `min-width: 0`. A hard floor would be a new fixed budget on the same line,
which is the shape of the bug. Nothing in the block sets `overflow` on a header element - an
overflow context there clips the megamenu and offcanvas panels, which at this width still open.

Authoring-time proof on the amended sheet: a string-aware comment and brace scan reports clean,
and a comment-stripped parse resolves 112 top-level rules with 16 block markers present and
contiguous (#8 through #23).

## 2.0.0

**The wave (V5-PLAN 2.5, decision D-E).** Block 22 of `default_custom.css`: one cubic path on a
1440x75 viewBox applied as a CSS mask to a pseudo-element carrying a flat background-color. The mask
carves the shape and a token supplies the colour, which is why one asset serves every colour scheme
and a brand changes the motif by changing a variable. Three knobs: `--td-wave-fill` (defaults to the
neutral page ground, so an un-themed wave reads as a carved edge and not as a stripe), `--td-wave-h`
(`clamp(40px, 5vw, 75px)`) and `--td-wave-mask`.

**It is inert.** Nothing in the block paints until `.td-wave-bottom` or `.td-wave-top` is applied,
and no element in a Swift document carries either, so a page that has not opted in gains exactly
zero pixels. Opting in is one entry in a grid row's CSS-class field in the Visual Editor: no
template edit and no serialized content from this layer, which keeps the theme disk-overlay-only.

**The clearance rules are the larger half of the block, and they are the point.** A top wave sits at
`top: 0` flipped, and a pseudo-element with a negative offset paints above its owner's border box.
Either way the crest paints over content while every box-model measurement reads healthy — the
element genuinely does not overlap, so a geometry probe finds nothing and the text is still sliced.
The fix is spacing, never stacking: the owner reserves padding sized off the wave's own clamp, so
the reservation tracks the wave at every viewport with nothing to re-tune per breakpoint. Raising
`z-index` on the content is the tempting fix and the wrong one — it repaints the text above the
crest and leaves the motif looking like a mistake. Rules ship for the sending row, the receiving
row, `main` when its last row carries a bottom wave, and the footer, which is the common sitewide
case and the easiest to get wrong.

`.td-wave-alt` flips on X as well, because two adjacent top waves otherwise read as one repeated
stamp.

Gate note recorded in the block: pseudo-element paint is invisible to every probe but the painted-
clearance one, so every wave instance a site ships needs its own `paintClearance` entry naming its
owner selector. A footer wave and a band boundary are two entries, not one.

Major, not minor: `:root` gains three tokens and the sheet gains a utility a consuming theme is
expected to build on.

## 1.4.0

**The placeholder footprint, declared and shipped (V5-PLAN 2.4).** A placeholder is a file that
already exists, is already wired and is already served, so a re-skin is an edit and never a create
followed by a hunt for the field that should have pointed at it. Four of them were missing; this
release ships them and `layer.json` `placeholders[]` now declares the whole set, each entry naming
its path, the kind of proof the gate owes it, and what a consumer fills it in for.

**`Custom/default_custom.js` plus its `AddScript` line.** There was no JavaScript entry point
in this theme at all. Everything a re-skin has needed so far falls into three shapes a stylesheet
cannot express: naming a platform-generated landmark for accessibility, repointing in-page anchors
at runtime (Dynamicweb emits a sitewide `<base href>`, so a bare `#section` navigates to the front
page), and stripping a hard-coded media attribute. The file ships empty, registered with `defer`
from `DefaultHeadInclude.cshtml`, and carries the fill-in recipe plus the **no-marker rule** in its
header: it must never write a marker string into the page, not even a console banner or a
`data-` attribute proving it ran. The design gate scans rendered text for placeholder markers and a
placeholder that announces itself is not inert, it is content.

**Three paragraph layout variants** — `Swift-v2_Poster/TextMiddleLeftLcp.cshtml`,
`Swift-v2_Image/Responsive.cshtml`, `Swift-v2_VideoPlayer/PosterLazy.cshtml`. Each is net-new, each
leaves the standard template untouched, and each renders nothing until a paragraph's Template field
names it. They exist because a layout variant is the only place a theme can reach the attributes
that decide media weight: `srcset`, `sizes`, `fetchpriority`, image quality, `loading`, and the
`preload="auto"` the video component hard-codes. The README has recorded those as "not fixable from
a theme" since 1.0.0; this is the fix. `Responsive.cshtml` ships its intrinsic-ratio map **empty**
rather than guessing a ratio, because a wrong width/height pair is worse than none.

**Two neutral brand assets**, `Images/Brand/logo.svg` and `wave.svg` — the first image files this
layer has ever shipped. The logo is a grey wordmark occupying the slot, not a logo. `wave.svg` is
the motif's readable source: one cubic path on a 1440x75 viewBox with **no fill attribute**, because
the shape is used as a mask and the fill comes from a token.

## 1.3.3

**ContainerWidth 4 keeps a gutter in main (Foundry #545).** In stock Swift, full width and
edge-to-edge are the same setting: `swift.css` declares
`[data-dw-container-width="4"]{--dw-container-width:100% !important;--dw-container-gutter:0rem}`
and re-adds `calc(2rem)` only under the header and footer landmarks. Width 4 is designed for
rows whose paragraph supplies its own inset (a poster has `--swift-poster-padding`); a Text,
Feature or product-list row at width 4 has none, and `--swift-content-padding` only applies
to grid columns carrying a colour scheme. A site-wide "make it full width" pass therefore put
main content at x=0: measured on `/en-ca/about`, the H1 and body copy went from a 24px edge
gap to 0px at 1440, and at 390 the breadcrumb, product titles and the primary CTA all went
from 16px to 0px.

New block #21 restores the gutter in `main` only, at `calc(2rem)` — Swift's own header/footer
value, so main matches the chrome instead of introducing a third measure. The width is left
alone: narrowing `--dw-container-width` back would cancel the setting the author chose.

- **Nested containers are excluded.** A width-4 container inside another would add a second
  gutter on top of the inherited custom property and double the inset.
- **Deliberate full-bleed rows opt out** with `data-td-full-bleed` on the row or any ancestor
  (the CSS-class/attribute field of the grid row in the Visual Editor is enough). Posters,
  full-width image bands and maps are supposed to touch the edge.
- Header and footer are untouched: nothing in the block is scoped outside `main`, and they
  already carry Swift's own `calc(2rem)` re-add.

Disk-overlay only (SPEC-06): one block appended to `default_custom.css`, no template edit and
no serialized DB content. P4 button `:not()` chains, P5 footer scoping and P10 nav scoping
untouched. Validate by measuring, not by eye: record edgeGap per container per viewport before
and after and assert main, header and footer all report a 16px edge gap at 1440/1920/2512/390
with body overflow 0.

## 1.3.2

**Breadcrumb contrast — the theme's own alpha stacking (Foundry #145's class,
found live by the gate).** The 1.1.0 breadcrumb rule dimmed the whole component
to opacity .65; Bootstrap's `.breadcrumb-item.active` carries its own
`rgba(…,.75)`, and the two MULTIPLY: effective alpha .488 → `#939597` on white,
3.02:1 — first measured by the new CONTRAST-01 gate probe (run 20260728-110700).
Component opacity replaced by a single `color-mix(in srgb, currentColor 72%,
transparent)` on every crumb (including `.active`, overriding Bootstrap's alpha
so stacking is impossible): composite ~5.1:1 on light schemes, currentColor-
driven on dark. Disk-overlay only (SPEC-06). Runtime proof: the upcoming
Foundry gate run.

## 1.3.1

**PDP gallery media weight recorded as an upstream ask — there is no CSS half to ship
(Foundry #161).** Disk-overlay only (SPEC-06); P4 button `:not()` chains, P5 footer scoping
and P10 nav scoping untouched. The neutral theme's rendering is unchanged: the release adds
one documentation block and a README table, no paint.

The reported defect is real and measured — Swift-v2 emits every PDP gallery asset up to
three times (inline gallery, lightbox modal, thumbnail strip) and hard-codes
`preload="auto"` on each `<video>`, so a single 5MB gallery video pulls a ~15MB PDP before
any interaction (15,318 KB observed). The layer leg is honest about what a theme can do
with it:

- **No CSS-side mitigation exists.** `preload` is an HTML *attribute*; CSS cannot read, set
  or remove one, and no property, at-rule or media feature suppresses a media fetch. Hiding
  is not a workaround either — a hidden `<video preload="auto">` still downloads, so the two
  duplicate copies cost full weight while invisible. Shipping *some* rule to look responsive
  would move zero bytes.
- **The template half is upstream-deferred.** The attribute is emitted by stock Swift design
  templates (`Paragraph/Swift-v2_ProductMediaGallery.cshtml`, three sites, and
  `Components/VideoPlayer.cshtml`). Overlaying either would fork a Swift template at a
  version and silently win over every later release — exactly what SPEC-06 keeps this layer
  out of. Same disposition as the standing asks at blocks #8, #10, #11 and #12.
- **Upstream ask (Swift):** `preload="none"` plus a poster on every gallery video, and each
  asset rendered once with the modal and thumbnail referencing it instead of three
  independent media elements.
- **Consuming build, until then:** a solution-owned Custom script that shows the poster and
  fetches the source on click — proven on a real demo PDP at 133 KB with zero media bytes
  before interaction, a 5.2 MB fetch on click, playback verified. That asset belongs to the
  consuming build, not the neutral theme: it changes PDP behaviour, and no gate edition ships
  a product carrying a gallery video to prove it against.

`default_custom.css`:

- **#20 Media-preload contract.** New numbered block carrying the above, with the G2 marker
  rule (`[data-td-block="20"]`) so a CSSOM assert can prove it parsed. Prose only — the block
  paints nothing, in the manner of the #18 scoping contract and the #19 palette deploy
  contract.

`README.md`: new **"Not fixable from a theme — upstream asks"** table, so the next re-skin
reads the limit before trying to solve it in a stylesheet.

Runtime proof: the upcoming Foundry gate run on the current latest Swift.

## 1.3.0

**Applied-learning pass — fold the demo-proven gate findings back as neutral defaults
(Foundry #34, #35, #45, #36/#39/#55/#66/#69, #46, #50, #65, #70, #96, #97).** Minor
rather than patch: three new structural conventions land (an opt-in floating-header
mode, the sanctioned visually-hidden idiom, and the CSSOM block-marker convention),
alongside two real defects the neutral theme was carrying. Every finding arrived from a
marine-demo re-skin; what ships here is the palette-agnostic, token-driven version.
Disk-overlay only (SPEC-06); P4 button `:not()` chains, P5 footer scoping and P10 nav
scoping are unchanged and honoured throughout.

Two defects in the shipped theme, fixed:

- **`.dw-eyebrow` lost to its own sheet (Foundry #35).** The 1.2.2 kicker utility
  (0,1,0) was out-specified by the 1.1.0 secondary-text softener
  (`main [data-dw-colorscheme=light] p`, 0,1,2), so a kicker authored as a `<p>` —
  the natural thing to type in a Swift heading Title field — rendered as muted body
  ink on every light band while the dark band rendered correctly. Fixed at the
  softener (`p:not(.dw-eyebrow)`) rather than by bumping the utility, so the kicker is
  safe in *any* element and stays a single plain class a brand can recolour.
- **`font-size: 0` removed from the mobile Favorites label (Foundry #70).** Block #13
  hid the label by destroying it — the idiom that strips a control's accessible name.
  Block #17 now does the hiding properly.

`default_custom.css`:

- **#15 Line-view PLP title discipline.** Block #10 left the title the only shrinkable
  child of a nowrap flex line whose other columns are fixed and non-shrinkable, so once
  they over-commit the lane the title collapses to width 0 and its text stacks one word
  per line (measured up to 9) straight across the description — an unreadable row that
  survived four gate PASSes because nothing asserted two sibling boxes do not intersect.
  Title gets a real basis (`0 1 320px`) + a 180px floor + a hard 2-line clamp; the
  description becomes the shrinkable single-line ellipsis lane (`1 1 140px`, `min-width:0`).
- **#16 Floating / overlay header — opt-in.** Swift 2.4 exposes no native
  transparent/overlay-header switch, so the hero-behind-the-menu motif is CSS-only and
  every brand re-derives the same four mechanics. Gated on a `td-header-overlay` class a
  build sets on the header's grid row (Visual Editor CSS-class field — no template edit,
  no serialized content), so the neutral default renders exactly as before. Ships: fixed
  (not sticky) bar; one rounded pill painted by `::before` with **no** `overflow:hidden`,
  which would clip the megamenu and offcanvas; clearance keyed on the DOM the server sent
  (`body:has(… swift-v2_offcanvasnavigation)`, outside every media query) because DW
  selects between a short phone header and a tall desktop header **by user-agent**, so a
  breakpoint-keyed token is fitted to whichever document was measured and silently wrong
  for the other — this was a 94px dead band on real phones that four headless PASSes
  never saw, and it self-corrects at every width (it fixed tablets with no tablet rule);
  a container `max-width` restored to `min(cap, 100%)` inside the bar, dropping the
  phantom 16px auto margin Swift's `calc(-32px + …)` cap creates; and a top-anchored
  first-row poster crop, because `object-fit:cover` on a fixed-height box is width-driven
  so a focal-point nudge only moves the failure to another viewport. All tuned through
  `--td-bar-*` / `--td-container-cap` tokens.
- **#17 Visually-hidden idiom.** `clip` + `clip-path: inset(50%)` with **no** `overflow`
  declaration, shipped as `.td-visually-hidden` and applied to the mobile Favorites label.
  Resolves the standing collision between the classic sr-only recipe and the
  no-`overflow`-in-the-header guard: the two constraints were never really in conflict,
  the idiom was just older than `clip-path`.
- **#18 Content-vs-catalog scoping contract.** Documented, collision-free hooks every
  Swift build already has: `body[data-dw-page-id="1234"]` scopes exactly one content page,
  `body[data-dw-itemtype="swift-v2_shop"]` the entire catalog (shop root + every PLP +
  every PDP). The theme ships no rule on either, which is what keeps them free for a
  consuming build.
- **#19 Palette deploy contract.** A brand colour lives in more than one file: buttons
  paint from `--dw-color-button-primary`, declared only in the *generated*
  `ColorSchemes/<design>.css` (hex **and** rgb triplet, 7 schemes = 14 literals), and that
  file is emitted from a sibling `.json` model written in the same operation. So a
  token-only rebrand leaves every primary button — the largest colour area on the site —
  on the old brand, and hand-editing only the `.css` is silently reverted by the next
  design save. Contract recorded here and in the README re-skin ladder; overriding the
  variable from this sheet is explicitly the wrong fix.
- **Retired tokens are aliased, never deleted (Foundry #34).** A token is bound in more
  places than the sheet you edit: DB-authored content can carry it in an inline `style`,
  and this layer's own `DefaultHeadInclude.cshtml` keeps a render-critical copy. Delete it
  from the sheet and the head-include copy becomes its only definition. Convention block
  added next to the tokens, with the matching warning in the head include itself.
- **Authoring guards G1–G4 in the file header.** G1 (Foundry #50): never type a comment
  terminator inside comment prose — it closes the banner early, the orphaned prose becomes
  a selector prelude that swallows the next real rule, and every byte-level check still
  reports the deploy healthy. G2 (Foundry #50): every numbered block now opens with an
  inert `[data-td-block="<n>"]` marker rule (retro-added to #8–#14) so a CSSOM assert can
  prove the block *parsed* and reached `document.styleSheets`, not merely that its bytes
  landed on disk. G3 (Foundry #65): Bootstrap/Swift utilities are declared `!important`,
  so any override of a platform-managed flex column must be `!important` in *every*
  responsive tier or the tiers disagree across a band of widths — the #9 rowflex and
  footer wrap bases were exactly this case and now carry it. G4: never write a
  numeric-leading id selector.

Runtime proof: the swift-demo gate theme leg on the current latest Swift — run id
recorded in the publishing PR. Authoring-time proof taken here: a string-aware
comment/brace scan reports clean, and a CSSOM parse resolves 93 top-level rules (matching
the source block count) with all 12 block markers and every new selector present.

## 1.2.2

**Brand accent slot + eyebrow utility (Foundry #32).** Two structural gaps in the
theme *recipe* surfaced by the marine-demo source analysis: brand themes had no
first-class home for their accent color (so it leaked into
`--dw-color-button-primary` and painted every button), and the tracked-caps
section-kicker voice existed only ad hoc (PDP spec-group labels here; poster
scopes in brand themes). Disk-overlay only (SPEC-06); P-guards untouched; the
neutral default's rendering is unchanged — every new consumer falls back to
button-primary until a brand opts in.

`default_custom.css`:

- **Accent slot convention.** `--dw-color-accent` / `--dw-color-accent-rgb` /
  `--dw-color-accent-contrast`, set per scheme in a brand's ColorSchemes CSS
  (re-skin ladder step 2). Consuming utilities `.text-accent` / `.bg-accent`
  carry the button-primary fallback, so the slot is additive and inert by default.
  Distinct from `--td-accent`, the theme's static interaction tint.
- **`.dw-eyebrow`.** The section kicker as one utility: `.78rem` / 600 / `.3em`
  tracked uppercase, accent-colored (same fallback). Apply to the kicker
  paragraph above a section h2.

Runtime proof: the swift-demo gate theme leg on the current latest Swift — run id
recorded in the publishing PR.

**Real-device fix — mobile list-mode PLP row consistency.** A phone screenshot
(marine reference; DemoAgent commit `24e0df4`) showed one PLP row wrapping its CTA
to its own line while its neighbours stayed inline. The #10 mobile flex bases carried
no `!important`, so Bootstrap `.flex-fill` (`flex:1 1 auto !important`, on every
list column) beat them and let the SKU column grow content-driven — 298px on the
longest product number — tipping only the longest-SKU rows over the edge. The desktop
#10 block already `!important`s every base for exactly this reason; the mobile bases
needed it too. Disk-overlay only (SPEC-06); P4 button `:not()` chains, P5 footer
scoping and P10 nav scoping are unchanged and honoured. Runtime proof: the Foundry
gate on the current latest Swift.

`default_custom.css` (`.product-list`-scoped so the PDP BOM that #10 mobile also
covers is untouched):

- **#14 Mobile PLP row consistency.** (a) Mobile flex bases re-asserted with
  `!important` so `.flex-fill` can't grow them — the SKU column pinned to `0 1 auto`
  (content width, never grows). (b) Uniform 56px square product thumbs. (c) Compact
  SKU type. (d) Price pill right-anchored (`margin-left:auto` + `justify-content:
  flex-end`, nowrap, compact padding) so it aligns to the right edge both when it
  fits inline (~430px) and when it wraps (~390px), independent of column widths.

## 1.2.0

**Mobile pass — kill the small-viewport layout blowout, wrap flex rows, align the
list-mode PLP, open the spec table.** Structural version of the marine-demo second
pass (2026-07-18, brief Part B addendum #8-13), made default in the neutral theme.
Disk-overlay only (SPEC-06); the P-guards (P4 button `:not()` chains, P5 footer
scoping, P10 nav scoping) are unchanged and honoured by the new rules.

`default_custom.css` (all token-driven — a palette swap carries it for free):

- **#8 Mega-menu collapse (the mobile bug).** `Swift-v2_MenuRelatedContent` renders
  a fixed-width megamenu bar (~1282px) at every viewport; at 390px it stretched the
  document canvas to 1356px (content squeezed left, blank right margin, broken
  lazy-image paint that read as "missing PLP images"). Below `lg` the bar is now a
  horizontally-scrollable category strip. A real burger/offcanvas is the durable fix
  — deferred upstream to the Swift menu template. *Probe lesson recorded inline:*
  `overflow-x:hidden` on `<body>` masks the blowout from
  `document.documentElement.scrollWidth` — measure `document.body.scrollWidth`.
- **#9 Flex rows wrap below md.** Any `NColumnsFlex` row (USP/feature bands) and the
  footer (marine stretched it to ~704px alone) now wrap their columns below `md`.
  Footer wrap is scoped to the `body>footer` / `[data-swift-page-footer]` landmark (P5).
- **#10 List-mode PLP column discipline.** Bootstrap `.flex-fill`
  (`flex:1 1 auto !important`) on every grid column defeated plain flex bases, so
  CTAs landed on a different x per row. Column bases reasserted with `!important` +
  a mobile stack; the durable fix (template dropping `.flex-fill` for columnar
  layouts) is deferred upstream. Structural here because list-mode PLP is the
  Distribution default.
- **#11 Anon CTA calm state.** The "sign in for dealer pricing" pill renders inside
  `swift-v2_productPRICE` (not add-to-cart); given a calm resting border + full
  accent on row hover (border/color only — P4 intact). Which component *owns* the
  anon CTA is a template normalization deferred upstream.
- **#12 Open spec table.** Collapsed-by-default field display groups showed nothing
  on the PDP; force-opened and restyled as two-column spec rows (headless style). A
  native "open table" display mode is the upstream ask.
- **#13 Mobile logo clamp.** The lockup is an inline SVG in a figure with a
  hardcoded 210px width (the old `figure img` hook misses inline SVG); clamped to
  150px below `md`, plus the Favorites link goes icon-only so the cart stays in view.

Runtime proof (overflow-x 0 at 390, header budget, PLP/PDP/home screenshots, design
probes) is the Foundry gate run on the current latest Swift — not this validator.

## 1.1.0

**Fresh pass — close the design gap to a modern headless storefront.** The marine-demo
re-skin defaults (2026-07-18), made structural in the neutral theme so every future demo
starts fresh instead of re-deriving the same layer. Disk-overlay only (SPEC-06); the
P-guards (P4 button `:not()` chains, P5 footer scoping, P10 nav scoping) are unchanged.

Style assets:

- **Buttons pill shape.** `Buttons/default.{css,json}`: `Shape 2`, `--dw-btn-border-radius:
  999px`, padding `0.55/1.4rem`. `Typography/default.{css,json}`: button weight `600`,
  tracking `0.01em` (no wide tracking).
- **Typography.** Heading letter-spacing `-0.01em → -0.02em`; line-height stays `1.15`
  (avoids descender clipping on Inter-class faces).

`default_custom.css` (structural, token-driven — a palette swap carries it for free):

- **Shape + elevation system.** New `--td-radius: 12px` / `--td-radius-sm: 8px` /
  `--td-shadow-soft` tokens. Cards get `12px` radius + hairline `rgba(fg,.08)` border;
  hover = border `.16` + soft layered shadow + `translateY(-2px)` (150ms). Radius applied
  to content/product media figures, product thumbnails (hairline-framed), accordion items;
  facet/sort dropdown toggles become pill chips.
- **Muted secondary-text tier.** `main` body copy on light schemes at `rgba(fg,.78)`;
  breadcrumbs `.85rem` at `65%` opacity.
- **Motion.** `main a` 120ms colour/bg/border; cards/buttons 150ms/100ms.
- **Header density.** Section padding scoped to `main` (never the header/footer landmarks)
  + header row/container trims — budgets the standard two-row header `<=170px` desktop
  (marine measured `261px → 165px`).
- **Template-gap mitigations (disk-overlay).** Poster-first-row top-padding exception
  (`:has()`), long-BOM cap+scroll frame, slider card title→block separator. Durable fixes
  are upstream in the Swift design package; these keep the default demo clean meanwhile.
- **Raw head-injection point.** `DefaultHeadInclude.cshtml` documents an inert, copy-ready
  `@Html.Raw` region for JSON-LD / `<meta>` (the Swift master's `CustomHeadInclude` *field*
  HTML-encodes; this Razor include is the unencoded output point).

## 1.0.2

- **Image-height caps (RUN-DISTRIBUTION-QUALITY T1-01, D-A).** `default_custom.css`
  now caps `Swift-v2_Image` paragraph bands (`aspect-ratio: 16/9`,
  `max-height: min(60vh, 640px)`, `object-fit: cover`) and the `Swift-v2_Slider`
  featured-carousel cover cards (`height: clamp(15rem, 34vh, 21rem)`, overriding the
  template's inline `min-height: 25rem`, cover image `object-fit: cover`). Durable,
  image-agnostic: survives a fresh deserialize with any swapped-in photo, because
  `Swift-v2_Image` ships no serialized height field. Disk-overlay only (SPEC-06).
  Re-proven by the swift-demo gate theme leg on DW 10.28.1-PreRelease
  (full cold matrix, run `20260717-030351`).

## 1.0.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24). Checked against the official Swift
v2.4.0 design package: the style-instance structure (`System/Styles/<Type>/<name>.{json,css}`)
and the `Templates/Designs/Swift-v2/Custom/` hook are unchanged in 2.4 — **zero CSS/var
adjustments needed**; the only change is the `swiftVersion` claim (2.4.0). Re-proven by
the swift-demo gate theme leg (incl. the folded menu-bar affordance probes) on
**DW 10.28.1-PreRelease** (stable re-prove due when DW 10.28 lands stable on NuGet).

## 1.0.0

- Initial release: the one default presentation layer of the distribution.
- Consolidates the presentation lane into a single neutral theme: structural and
  typographic quality derived from the strongest of the previous demo themes,
  neutralized toward restraint (calm slate/grey palette, Inter, quiet buttons).
- Header menu-bar affordance (dropdown carets, hover/active states, reachable
  dropdowns per LRN-nav-03/04/05) ships inside `default_custom.css` — always on,
  no separate overlay composition.
- Icon-free: the opt-in `data-nav-icon` hook binds against the DW10 stock icon set
  (`/Files/Images/Icons/`); the layer ships zero icon files.
