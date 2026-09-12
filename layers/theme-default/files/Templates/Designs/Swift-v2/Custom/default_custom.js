/* default_custom.js — the theme's JavaScript entry point. Ships EMPTY, on purpose.
 *
 * WHAT THIS IS
 * The counterpart of default_custom.css: a file that already exists, is already
 * registered, and is already served, so adding behaviour to a Swift site is an edit
 * and never a create. It is registered from DefaultHeadInclude.cshtml with
 * AddScript(..., true), which puts it after the design package's own scripts
 * and after the document has parsed.
 *
 * WHY IT EXISTS AS A PLACEHOLDER
 * There was no JS entry point in this theme at all. Everything a re-skin has needed
 * so far fell into three shapes, none of which a stylesheet can express:
 *   1. accessibility naming — giving a platform-generated dialog or landmark an
 *      accessible name the template does not expose;
 *   2. rewriting hrefs at runtime — Dynamicweb emits a sitewide <base href>, so a
 *      bare "#section" anchor navigates to the front page instead of scrolling; an
 *      in-page jump strip has to repoint its own links on load;
 *   3. stripping a hard-coded media attribute — the stock video component sets
 *      preload="auto", which downloads whole video files on page load; a
 *      MutationObserver that rewrites it to "none" is the only fix available from
 *      outside the design package (the layout-variant route in Paragraph/ is the
 *      other, and is preferred when the component has a variant slot).
 *
 * THE FILL-IN RECIPE
 *   1. Write your code inside the IIFE below. Keep it dependency-free: this file
 *      loads with `defer` and nothing guarantees a framework is present.
 *   2. Guard every selector. This file runs on EVERY page of the site, including
 *      admin-side previews and the Visual Editor, so a null check is not optional.
 *   3. Prefer a Paragraph layout variant over a runtime DOM rewrite whenever the
 *      component has one — a variant is server-rendered and costs nothing.
 *   4. A customer theme adds its own <brand>_custom.js and registers it from its own
 *      head include, AFTER this one. It does not edit this file.
 *
 * THE NO-MARKER RULE
 * This file must never write a marker string into the page. The design gate scans
 * rendered textContent for placeholder markers (/placeholder/i, "Sample Product NN",
 * stock corporate copy) and fails the publish tier on a hit. A placeholder that
 * announces itself in the DOM is not inert — it is content. The same rule kills the
 * obvious debugging habit: no console banner naming this file, no data-attribute
 * stamped onto <body> to prove the script ran. Proof that it parsed belongs in the
 * gate (a served-200 plus a parse), not in the document.
 *
 * Deliberately empty below this line. An empty IIFE is valid, parses, and renders
 * nothing — which is exactly the contract.
 */
(function () {
    "use strict";

    // Theme behaviour goes here. Nothing ships enabled.

})();
