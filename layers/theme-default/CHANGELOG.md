# theme-default changelog

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
