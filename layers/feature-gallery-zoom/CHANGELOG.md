# Changelog: feature-gallery-zoom

## 1.0.0

**New layer. A zoomable, full-screen product gallery lightbox, opt-in per edition (Foundry #1392,
option B).**

The Swift 2.4 product gallery opens its images in a Bootstrap modal with no zoom, and its carousel
blocks the browser's own pinch (`touch-action: pan-y`). This layer replaces the lightbox with
PhotoSwipe 5.4.4 and adjusts the gallery's presentation for mixed image sizes, without forking a
Swift template:

- `addon.js`: PhotoSwipe on the stock slide links, slide list read from the stock modal carousel,
  2400px GetImage sources with the size corrected after load, open-original button, stock modal as
  the fallback.
- `addon.css`: tinted letterbox, square cover thumbnails, zoom-in cursor.
- `photoswipe/`: the vendored library (MIT).

A separate layer rather than a theme-default change, because it passes all three CONTRIBUTING tests
for a new layer: a consumer opts in (image-heavy demos only), it has its own lifecycle (PhotoSwipe
releases), and it has its own files. It is behaviour, not presentation, so "presentation improvements
fold into theme-default" does not apply.

Needs theme-default 2.6.0 (the add-on slot). Measured on foundry.mydwsite4.com through request
interception before delivery (2026-09-28): desktop 1440, the lightbox opens at 480px (the source
width) and one click zooms to 960px; mobile 390, fit 390px, double-tap 960px, pinch 2340px; no
modal, no page errors, no horizontal overflow.
