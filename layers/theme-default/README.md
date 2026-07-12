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
| `Templates/Designs/Swift-v2/Custom/DefaultHeadInclude.cshtml` | Links `default_custom.css` + inlines the render-critical tokens |

No serialized DB content, no custom code, no template forks, **no icon files** — the
`data-nav-icon` hook in `default_custom.css` is opt-in and binds against the DW10 stock
icon set (`/Files/Images/Icons/`, ~80 SVGs); see the 3-step recipe in the CSS comment.

## Data prerequisite (menu-bar affordance)

Dropdown carets/panels only render when top navigation nodes HAVE children
(`base.contract.json` `navDepth`). A childless bar stays flat text — that is a data gap,
not a CSS defect. Author child nav nodes (the `save_groups` recipe) to exercise the
dropdowns.

## Re-skin ladder

1. Override the `--td-*` tokens (accent, ink, hairline) in the customer's custom CSS.
2. Replace the three Style pairs (`ColorSchemes`/`Buttons`/`Typography`) with brand values.
3. Extend `default_custom.css` — the affordance section is brand-agnostic and survives
   any palette swap (everything paints with `currentColor` / the `--td-accent` token).
