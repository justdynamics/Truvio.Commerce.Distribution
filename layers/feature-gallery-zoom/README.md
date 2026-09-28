# feature-gallery-zoom

An opt-in upgrade of the Swift 2 product image gallery for image-heavy demos. Plan and evidence:
Foundry [`docs/SWIFT-GALLERY-PLAN.md`](https://github.com/justdynamics/Truvio.Commerce.Foundry/blob/main/docs/SWIFT-GALLERY-PLAN.md)
(option B).

## What it changes

| Stock Swift 2.4 | With this layer |
|---|---|
| Clicking the main image opens a Bootstrap `modal-xl` with a second carousel, the page visible around it | PhotoSwipe 5 full screen: counter, swipe between images, swipe down or Esc to close, open-original button |
| No zoom of any kind; `touch-action: pan-y` on the carousel also blocks the browser's own pinch | pinch, double-tap, click, wheel and button zoom to 4x, with pan |
| Lightbox image capped at 1920px | 2400px from GetImage (never upscaled; the real size is read after load) |
| Letterbox bars on a transparent background | a faint tint from the colour scheme's text colour, so the bars read as a frame |
| Thumbnails contain-fitted in 4:3 boxes, ragged with mixed sources | square, cover-fitted thumbnails |

## How it loads

The layer ships files only, under `Templates/Designs/Swift-v2/Custom/Addons/gallery-zoom/`. It does not
edit any Swift or theme file. theme-default 2.6.0 and later registers `addon.css` and `addon.js` of
every folder under `Custom/Addons/` (the add-on slot in `DefaultHeadInclude.cshtml`), so composing
this layer is the whole install, and leaving it out leaves the stock gallery.

`addon.js` listens for clicks in the capture phase on `window`, ahead of Bootstrap's data-api handler,
on the stock slide link (`[data-bs-toggle="modal"][data-bs-target^="#modal_"]` inside the gallery
item). It builds the slide list from the stock modal carousel, so the order and the index match
`data-bs-slide-to`, and opens PhotoSwipe at that index. Swift already prevents the default on that
link before Bootstrap opens the modal, so the script does not stand down on `defaultPrevented`.
Video slides keep the stock modal and player.

Fallback: if `addon.js`, PhotoSwipe or the slide list fails, the stock Bootstrap modal opens and the
reason is logged to the console as `[gallery-zoom]`.

## Markup contract (Swift 2.4.0)

Two things, re-checked on every Swift roll:

1. The main slide link carries `data-bs-toggle="modal"` and `data-bs-target="#modal_<ID>"`, and an
   element inside it carries `data-bs-slide-to="<index>"`.
2. The modal `#modal_<ID>` holds `.carousel-inner > .carousel-item` in the same order, each with an
   `img` whose `srcset` or `src` is a GetImage URL (or the file itself with DisableGetImage).

The Foundry GALLERY-ZOOM probe fails loud if either moves.

## Proof

- Layer probes (`asserts.behaviorProbes`): the home page references `addon.js`, and the vendored
  lightbox module is served.
- Foundry design leg, GALLERY-ZOOM on the `swift-demo` PDP (TCPROD0001, which sample-data 6.2.0 gives
  five mixed-ratio photos): the lightbox opens instead of the modal, and double-tap, click and pinch
  zoom the image, at 1440 and at 390.

## Vendored

PhotoSwipe 5.4.4, MIT (`photoswipe/LICENSE.txt`), unmodified `dist` files. To update: replace the
three dist files and the licence from the npm package, and bump this layer.
