# theme-default changelog

## Unreleased

- **Image-height caps (RUN-DISTRIBUTION-QUALITY T1-01, D-A).** `default_custom.css`
  now caps `Swift-v2_Image` paragraph bands (`aspect-ratio: 16/9`,
  `max-height: min(60vh, 640px)`, `object-fit: cover`) and the `Swift-v2_Slider`
  featured-carousel cover cards (`height: clamp(15rem, 34vh, 21rem)`, overriding the
  template's inline `min-height: 25rem`, cover image `object-fit: cover`). Durable,
  image-agnostic: survives a fresh deserialize with any swapped-in photo, because
  `Swift-v2_Image` ships no serialized height field. Disk-overlay only (SPEC-06).
  Version bump + tag deferred to the run's P5 publish phase.

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
