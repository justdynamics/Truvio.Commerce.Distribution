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

    /* ----------------------------------------------------------------------
     * THE ANCHOR STRIP. Shape 2 from the list above, and the reason that entry
     * is there at all.
     *
     * Dynamicweb emits a sitewide <base href>, so a bare "#overview" href
     * resolves against the FRONT PAGE and navigates away instead of scrolling.
     * Every link in the strip therefore has to carry the current path in front
     * of its fragment. TC_AnchorNav.cshtml already emits them that way; this
     * re-points them after load, which is what keeps them right on a page whose
     * URL the client changed (a facet, a variant, a paging step).
     *
     * IT ALSO FILLS AN EMPTY STRIP. Swift stores a repeater as an item-list id,
     * so a serialized layer can ship the TC_AnchorNav paragraph but not its
     * TC_AnchorNav_Item children - the strip lands on the page with no links in
     * it. When the list is empty this builds it from the section headings the
     * page actually renders: every `main h2[id]`, in document order, using the
     * heading's own text as the label. A skeleton and a hand-maintained jump
     * list drift apart; reading the headings means they cannot.
     *
     * An editor who wants different words or a different order fills the
     * repeater, and the discovered list is not used at all.
     *
     * No marker string is written and no state is stamped on <body>: the strip
     * either has links in it or it does not, and that is the whole proof.
     * -------------------------------------------------------------------- */
    function anchorStrip() {
        var navs = document.querySelectorAll("[data-td-anchornav]");
        if (!navs.length) { return; }

        var path = window.location.pathname || "";

        Array.prototype.forEach.call(navs, function (nav) {
            var list = nav.querySelector(".td-anchornav__list");
            if (!list) { return; }

            if (!list.querySelector("a")) {
                var main = document.querySelector("main") || document.body;
                var headings = main ? main.querySelectorAll("h2[id]") : [];

                Array.prototype.forEach.call(headings, function (heading) {
                    var label = (heading.textContent || "").trim();
                    if (!heading.id || !label) { return; }

                    var li = document.createElement("li");
                    li.className = "td-anchornav__item";

                    var a = document.createElement("a");
                    a.className = "td-anchornav__link";
                    a.setAttribute("data-td-anchor", heading.id);
                    a.textContent = label;
                    a.href = path + "#" + heading.id;

                    li.appendChild(a);
                    list.appendChild(li);
                });
            }

            Array.prototype.forEach.call(list.querySelectorAll("[data-td-anchor]"), function (a) {
                a.href = path + "#" + a.getAttribute("data-td-anchor");
            });
        });
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", anchorStrip);
    } else {
        anchorStrip();
    }

})();
