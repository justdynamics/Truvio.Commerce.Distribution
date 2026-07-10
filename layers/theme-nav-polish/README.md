# theme-nav-polish

The Swift 2 header **menu-bar affordance overlay** — the "Option B" treatment that makes a
flat `Swift-v2_MenuRelatedContent` bar *read as a menu*: dropdown carets, hover + active
states, and reachable dropdowns. Pure disk-overlay CSS (SPEC-06): no template edit, no custom
code, no serialized DB content.

This is a first-class Distribution default: `editions/swift-demo.json` composes it as an
always-on `overlays` entry, so every Swift demo inherits the affordance without a per-demo copy
step. It is an **affordance overlay**, not a full theme — it layers on top of whichever demo
theme (tech-saas / fashion-lifestyle / industrial-b2b) is active and does not replace it.

## What ships

- `files/Templates/Designs/Swift-v2/Custom/nav-polish.css` — the affordance core (generic).
- `files/Images/nav-icons/{bone,shield-plus,layers,screw,instruments}.svg` — a theme-neutral
  starter icon set (mask-friendly line icons; fill/stroke colour irrelevant — painted with
  `background-color: currentColor` via `mask-image`, so they inherit the nav text colour).

## Data prerequisite (not CSS)

The top nav groups/pages must have **children** so Swift renders the dropdown/megamenu panel
(`nodesExist = rootNode.Nodes.Any()` in `Swift-v2_MenuRelatedContent/Menu.cshtml`). A childless
bar stays flat text no matter what this CSS does. The base makes this a machine-readable
contract note to additions — see `layers/base/base.contract.json` → `navDepth`. Editions that
promise a menu-bar default must ship or author nav depth (the dw-demo-swift skill documents the
`save_groups` child-authoring recipe).

## Accent colour

`--navpolish-accent` defaults to a neutral blue. A demo/theme MAY override it to brand-tint the
hover/active affordance, e.g. in its `<brand>_custom.css`:

```css
:root { --navpolish-accent: #B00020; }
```

The overlay is otherwise brand-agnostic (icons paint with `currentColor`).

## Icon add-on (opt-in, documented)

Icons are **not** wired into the default. They are keyed on a neutral hook — a
`data-nav-icon="<name>"` attribute set on the nav node's CSS-class/attributes field (NOT on
customer href slugs, which break on every catalog). No icon fires until a node opts in.

The starter set ships **ready to bind** — no CSS edit needed to use one:

1. Set the top nav node's CSS-class/attributes field to emit `data-nav-icon="bone"`
   (values: `bone`, `shield-plus`, `layers`, `screw`, `instruments`).

To add a **new** custom icon (the 5-line per-demo binding):

1. Drop `myicon.svg` into `files/Images/nav-icons/` (single-colour line art; the shape is what
   matters — it is masked, not drawn).
2. Add one binding line to the demo's own custom CSS (or a demo-local override sheet):
   ```css
   [data-swift-menu] a.nav-link[data-nav-icon="myicon"]::before {
     -webkit-mask-image: url("/Files/Images/nav-icons/myicon.svg");
             mask-image: url("/Files/Images/nav-icons/myicon.svg");
   }
   ```
3. Set the nav node's field to `data-nav-icon="myicon"`.

The `::before` box (size, currentColor paint, mask positioning) is already supplied by the core
`[data-nav-icon]::before` rule; the binding line only maps the name to an SVG.

## Platform truths this overlay encodes

Three interaction fixes that each cost real debugging and whose first-guess fixes were all wrong
(documented in the dw-demo-swift skill, `references/templates.md`):

- **LRN-nav-03 (Popper gap):** the dropdown opens ~16px below the trigger via an inline Popper
  `transform` — dead space that drops the hover mid-travel. Only an **item-anchored `::after`
  bridge gated on `:has(> .show)`** (the open state, never `:hover`) survives it.
- **LRN-nav-04 (`::after` collision):** on Swift nav links `::before` is the icon and `::after`
  is the underline-hover. The caret must **re-assert box AND position with `!important` in every
  open signal** or Swift's `text-decoration-*-hover` utilities collapse/relocate it.
- **LRN-nav-05 (min-width):** the stock `.dropdown-menu` is narrower than a long label;
  `min-width:100%` closes the horizontal dead strip. 03 (vertical) + 05 (horizontal) together
  are the complete reach fix.
