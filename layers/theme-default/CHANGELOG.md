# theme-default changelog

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
