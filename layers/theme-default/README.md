# theme-default

The CSS that makes stock Swift look great — **the starting point of every customer
re-skin**, not a brand. One neutral, restrained presentation layer (kind `theme`,
disk-overlay only per SPEC-06): calm greys, quiet buttons, clean typography, and a
header menu bar that reads as a menu. A customer re-skin starts by overwriting the
`--td-*` tokens and the three Style pairs; everything structural underneath keeps working.

## What it ships (`files/**` mirrors `wwwroot/Files/**`)

| Path | Purpose |
|------|---------|
| `System/Styles/ColorSchemes/default.{css,json}` | 7 neutral schemes (light / lightgrey1 / lightgrey2 / dark / darksubtle / primary / secondary) |
| `System/Styles/Buttons/default.{css,json}` | Quiet buttons: 0.35rem radius, 1px border |
| `System/Styles/Typography/default.{css,json}` | Inter, 16px base, 1.2 scale — no uppercase shouting |
| `Templates/Designs/Swift-v2/Custom/default_custom.css` | Polish layer: button/footer/nav/card refinement **+ the header menu-bar affordance** (carets, hover/active states, reachable dropdowns — LRN-nav-03/04/05) |
| `Templates/Designs/Swift-v2/Custom/DefaultHeadInclude.cshtml` | Links `default_custom.css`, then `brand.css`, + inlines the render-critical tokens |
| `Templates/Designs/Swift-v2/Custom/brand.css` | **The brand slot**: the demo's sheet, loaded after `default_custom.css`. Ships with a sentinel and a commented token block, no paint |
| `Templates/Designs/Swift-v2/Custom/brand.tokens.json` | The brand slot's input: colours per scheme, typography, buttons, logo, favicon, radius and the `--td-*` token values. Ships holding the theme's own neutral values |

No serialized DB content, no custom code, no template forks, **no icon files** — the
`data-nav-icon` hook in `default_custom.css` is opt-in and binds against the DW10 stock
icon set (`/Files/Images/Icons/`, ~80 SVGs); see the 3-step recipe in the CSS comment.

## Data prerequisite (menu-bar affordance)

Dropdown carets/panels only render when top navigation nodes HAVE children
(`base.contract.json` `navDepth`). A childless bar stays flat text — that is a data gap,
not a CSS defect. Author child nav nodes (the `save_groups` recipe) to exercise the
dropdowns.

## The brand slot

A demo brands the site by rewriting two files the theme already ships and serves, never by
appending to `default_custom.css`:

| File | The demo writes | Theme ships |
|------|-----------------|-------------|
| `Custom/brand.tokens.json` | The brand's values: `schemes[]` (the seven fixed scheme ids with background, foreground, primary and secondary button, optional accent), `typography` (the Typography model keys plus the font import URL), `buttons` (the Buttons model keys plus the radius), `brand.logo` / `favicon` / `appleTouchIcon` / `edgeMask`, and `css` (the `--td-*` token values) | The neutral values of this layer, so the file is a true description of the unbranded site |
| `Custom/brand.css` | The `css` token values in a `:root:root` block, then brand-only component rules | A sentinel rule, the commented token block and the authoring guards. No paint |

The delivery sequence, in a demo-local copy of the layer (the `cil-brand` pattern):

1. Copy `layers/theme-default` into the demo's layers folder.
2. Write `brand.tokens.json`.
3. Generate from it: the `css` section into the token block of `brand.css`; `schemes`,
   `typography` and `buttons` into the three Style pairs (both `.css` and `.json` of each
   pair, same pass; ladder step 2); `logo` and `favicon` into the `Swift-v2_Logo`
   paragraphs and the `Swift-v2_Master` `Favicon` / `AppleTouchIcon` / `MetaImage` fields,
   which are content, not theme files.
4. Add brand-only rules to `brand.css` below the token block.
5. Deliver the copy. A theme upgrade is a fresh copy plus the demo's two files, never a
   re-append.

`brand.css` loads after `default_custom.css`, so a brand rule wins a cascade tie without
`!important`. Tokens go in `:root:root` (specificity 0,2,0): the head include inlines a
`:root` copy of six tokens, and the doubled root beats it whatever the order of the two in
`<head>`. A rule that would help every demo is not a brand rule; it is a theme fix and goes
upstream into `default_custom.css`. The `css` section includes four sizing levers the theme
reads: `--td-logo-h` (header logo max-height), `--td-logo-w-phone` (logo figure below 768),
`--td-logo-w-laptop` (logo figure 768 to 1439) and `--td-hero-max-h` (the image-band and
hero cap: the image-height caps and block #32). A generated scheme accent goes into the ColorSchemes `.json` as
`CustomColors` `accent` and `accent-contrast` as well as into the `.css`, or an admin Styles
save drops it.

## Re-skin ladder

1. Override the `--td-*` tokens (accent, ink, hairline) in `brand.css` (the brand slot).
   **Retire a token by aliasing it, never by deleting it** — `:root { --td-legacy:
   var(--td-accent) !important; }`. DB-authored content can carry
   `style="...var(--td-legacy)"` inline, and the render-critical copy in
   `DefaultHeadInclude.cshtml` keeps the old definition alive after you edit the sheet.
2. Replace the three Style pairs (`ColorSchemes`/`Buttons`/`Typography`) with brand values —
   and set `--dw-color-accent` (+ `-rgb` / `-contrast`) per scheme: the brand accent slot.
   `.text-accent` / `.bg-accent` / `.dw-eyebrow` in `default_custom.css` consume it and fall
   back to button-primary when unset, so the accent never has to hijack the button color.
   **A palette change is a multi-file deploy.** Buttons paint from
   `--dw-color-button-primary`, declared *only* in `ColorSchemes/default.css` (as hex **and**
   rgb triplet, once per scheme — 7 schemes, 14 literals). Editing tokens in the custom sheet
   alone turns eyebrows, links and icon tiles and leaves every primary button on the old
   brand. Do not override `--dw-color-button-primary` from the custom sheet: it leaves the
   generated file lying and the next design save reverts the site. And the `.css` is
   *generated* from its sibling `.json` model (`Schemes[]` with `PrimaryButtonColor` etc.) —
   **edit both, in the same pass**, or a regeneration silently undoes the edit. Enumerate
   every literal of the outgoing colour in both notations across both files and assert an
   exact count, so a silent miss aborts the deploy instead of shipping a half-rebrand.
3. Add brand-only rules to `brand.css`. `default_custom.css` is the theme's file: the
   affordance section is brand-agnostic and survives any palette swap (everything paints
   with `currentColor` / the `--td-accent` token), and a generic fix goes upstream into it.

## Opt-in hooks (inert until a build opts in)

| Hook | What it does |
|------|--------------|
| `data-nav-icon="<name>"` on a nav node | Binds a stock DW10 icon into the menu bar (3-step recipe in the CSS) |
| `--dw-color-accent` (+ `-rgb` / `-contrast`) per scheme | The brand accent slot consumed by `.text-accent` / `.bg-accent` / `.dw-eyebrow` |
| class `td-header-overlay` on any element inside the page header | Turns the sticky bar into a floating/transparent overlay header with a hero-behind composition (block #16): fixed bar, one rounded pill painted by `::before` with **no** `overflow:hidden`, DOM-keyed clearance, top-anchored first-row poster crop. Tune with `--td-bar-top` / `--td-bar-inset` / `--td-bar-h` / `--td-bar-h-phone` / `--td-bar-radius` / `--td-bar-bg` / `--td-container-cap`. |
| `--td-btn-hover-bg` / `--td-btn-hover-ink` / `--td-tint-bg` / `--td-tint-ink`, per scheme | The hover pair of a filled button and of the soft-tint variants (outline, ghost, link, `outline-*`, empty), resolved on the colour-scheme element so the nearest scheme wins (block #35). Light schemes keep the neutral values; dark schemes tint with the scheme foreground and keep the generated button ink. A brand overrides them per scheme in `brand.css`, then measures the hover at 4.5:1. |
| class `td-visually-hidden` on a label | The sanctioned visually-hidden idiom (`clip` + `clip-path`, no `overflow`) — safe inside the header, keeps the accessible name |
| `data-td-full-bleed` on a grid row or any ancestor of one | Opts a width-4 row OUT of the main-scoped gutter restore (block #21), returning `--dw-container-gutter` to `0rem`. For rows that are meant to touch the viewport edge: posters, full-width image bands, maps. |
| `--td-button-primary-ink-<scheme>` (or `--td-button-primary-ink` for all schemes) | Overrides the ink a **filled** primary button paints its label with, per colour scheme, without touching the generated `ColorSchemes` pair (block #30, Foundry #1184). Unset, it resolves to `--dw-color-button-primary-contrast` exactly as the generator wrote it. |

### Button ink is chosen by lightness, not by contrast ratio (Foundry #1184)

The platform colour-scheme generator picks `--dw-color-button-primary-contrast` from a
**lightness threshold**, not by comparing the WCAG ratios of black and white against the fill.
A mid-luminance brand primary therefore lands on the wrong side of it: `#B8860B` is generated
with `#fff` ink at **3.25:1**, failing WCAG AA, where `#14181D` on the same fill measures
**5.48:1**. Amber, orange and light green all do this. The generator fix is upstream.

Until it lands, set the per-scheme hook in the brand sheet or the head include — anywhere that
lands after `default_custom.css`:

```css
:root { --td-button-primary-ink-primary: #14181D; }
```

Per scheme, so a dark-on-amber `primary` scheme does not drag the neutral `light` scheme's
white ink with it. Do **not** hand-edit `--dw-color-button-primary-contrast` in
`ColorSchemes/default.css`: that file is generated (ladder step 2) and the next design save
reverts the edit. Then **measure** the rendered label against the rendered fill — at least
4.5:1. The token is a hook, not a correction; the wrong ink here fails as loudly as the
generator's did.

Block #21 also applies without any opt-in: in stock Swift, ContainerWidth 4 sets
`--dw-container-gutter: 0rem` and re-adds `calc(2rem)` only under the header and footer, so a
width-4 Text or product-list row in `main` renders at x=0. The block restores `calc(2rem)` in
`main`, excluding nested containers and anything marked `data-td-full-bleed`. It restores the
gutter, never the width.

The edge motif (block #22) paints one fill per instance: `--td-edge-fill-hero` (the home hero
row's bottom edge), `--td-edge-fill-alt` (the first colour-scheme boundary after it) and
`--td-edge-fill-footer` (the crest over the site footer). Unset, each one follows a scheme that
contrasts with the ground the band sits on: block 26 of `default_custom.js` copies onto the
owner the first `--dw-color-background` that differs from the owner's own, reading the
adjoining row, then the first scheme-bearing element inside the owner, then the first inside
the adjoining row; the footer crest reads the footer's first scheme-bearing row, because the
`<footer>` element itself is unpainted. `--td-edge-fill` is the last resort. **A brand sets the
three tokens in its own sheet** when the derived colour is not the brand's edge colour, and must
set one where no candidate differs from the ground, since then the edge is invisible while its
mask is present.

## Not fixable from a theme — upstream asks

A disk-overlay theme is CSS, style assets and disk files; it forks no Swift template
(SPEC-06). These are recorded so nobody re-derives them from a stylesheet:

| Limit | Why CSS cannot reach it | Disposition |
|-------|-------------------------|-------------|
| **PDP gallery media weight** (block #20, Foundry #161) — Swift emits every gallery asset up to three times (gallery / modal / thumbnail), each with a hard-coded `preload="auto"`; one 5MB video costs a ~15MB PDP (measured 15,318 KB) | `preload` is an HTML **attribute**. CSS cannot read, set or remove one, and no property or at-rule suppresses a media fetch — a *hidden* `preload="auto"` video still downloads, so the duplicate copies cost full weight while invisible. The emitting files are stock Swift design templates (`Paragraph/Swift-v2_ProductMediaGallery.cshtml`, `Components/VideoPlayer.cshtml`), which this layer must not overlay | **Upstream (Swift):** `preload="none"` + a poster on every gallery video, and render each asset once. **Consuming build, until then:** a solution-owned Custom script that shows the poster and fetches the source on click — proven at 133 KB with 0 media bytes before interaction. That asset belongs to the build, not to the neutral theme |
| **Slider cards load eagerly below the fold** (Foundry #553) — `Paragraph/Swift-v2_Slider/CardCoverNavInline.cshtml` emits its card `<img>` with no `loading` attribute and no quality override, so four below-fold cards fetched ~150 KB of a ~447 KB critical window in parallel with the LCP hero (mobile Perf 86, LCP 3.6s) | `loading="lazy"`, `decoding="async"` and the image quality are HTML **attributes** on a stock Swift design template this layer must not overlay. `content-visibility` and any CSS hiding still let the browser fetch the image | **Upstream (Swift):** `loading="lazy" decoding="async"` and a quality below 95 on slider card images. **Consuming build, until then:** a Custom-lane copy of the template repointed per paragraph, measured at Perf 93 and LCP 2.73s |
| Mega-menu burger/offcanvas (block #8), `.flex-fill` on columnar PLP layouts (#10), which component owns the anon CTA (#11), a native open-table spec display mode (#12) | Template/markup concerns; the CSS rules present are mitigations, not fixes | Upstream (Swift templates) |

## Authoring guards

Extending `default_custom.css` means honouring G1–G4 in the file header: never type a
comment terminator inside comment prose (it swallows the next rule and no byte-level check
can see it); open every numbered block with its `[data-td-block="<n>"]` marker so a CSSOM
assert can prove the block parsed; `!important` every override of a Bootstrap/Swift-managed
flex column, in *every* responsive tier; and never write a numeric-leading id selector —
scope a page by `body[data-dw-page-id="1234"]` and the whole catalog by
`body[data-dw-itemtype="swift-v2_shop"]` (block #18).
