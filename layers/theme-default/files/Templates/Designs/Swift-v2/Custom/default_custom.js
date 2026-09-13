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

    /* ----------------------------------------------------------------------
     * BLOCK 26 - APPLYING THE EDGE. A fourth shape, and the reason it is here
     * rather than in the stylesheet or in content.
     *
     * WHY NOT A CSS CLASS FIELD. Swift grid rows have none. The stock
     * Grid/Page/RowTemplates/Swift-v2_Row.cshtml emits data-swift-gridrow, a
     * colour-scheme attribute and spacing attributes, and no class attribute
     * authored from content; grid-row serialization carries no cssClass key
     * either. A row therefore cannot opt itself in, and neither can a layer
     * that ships rows.
     *
     * WHY NOT A PURE-CSS SELECTOR. It would work - hang the pseudo-elements off
     * the adjacency of the colour-scheme attributes and the footer landmark, and
     * never name a class at all. It is rejected because the classes ARE the
     * contract: the clearance rules in block 22 key on them, a paintClearance
     * gate entry names them, and every future instance a site adds is then one
     * class rather than one more bespoke structural selector nobody can find.
     * Adding the class and letting block 22 do the rest keeps one mechanism.
     *
     * THE THREE INSTANCES, which are the three the gate measures:
     *   1. the home hero row            -> td-edge-bottom  (main .td-edge-bottom::after)
     *   2. the row BEFORE the first     -> td-edge-bottom  (+ td-edge-alt)
     *      colour boundary after it
     *   3. the site footer              -> td-edge-top     (footer::before)
     *
     * INSTANCE 2 IS A BOTTOM EDGE, NOT A TOP ONE (2.2.2, Foundry #1152). It used
     * to be td-edge-top on the boundary row itself, which put the band above that
     * row and therefore over the ink of the row before it - and made the instance
     * unmeasurable as well as unsafe. A top-anchored band is judged against the
     * ink of the scope it paints into, and for an owner inside <main> that scope
     * includes every row BELOW it, so a boundary halfway down the page measures
     * against ink 1700px underneath and is negative by construction whatever it
     * is padded with. Drawn as a bottom edge on the row ABOVE the boundary the
     * band lands in exactly the same place, the ink it covers is its owner's own,
     * and the owner reserves it. A top edge now belongs only to an owner that
     * terminates the ink it threatens - the footer.
     *
     * SCOPE. Instances 1 and 2 are found through the hero itself: the row is the
     * first direct child section of main that contains a Swift poster. A page
     * with no poster hero - a PLP, a PDP, the cart - gets neither, without this
     * file knowing any page id. Instance 3 is sitewide, which is what a crest
     * over the footer is.
     *
     * THE SILHOUETTE IS NOT DECIDED HERE. The shape comes from --td-edge-mask,
     * which defaults to the theme's neutral placeholder; a brand overrides the
     * token in its own sheet and all three instances change at once. Nothing
     * below knows or cares which path is in the token.
     *
     * THE FILL FOLLOWS THE ADJOINING SCHEME. A bottom edge points down into the
     * row below its owner, so the owner is given that row's
     * --dw-color-background as --td-edge-adjoin, which block 22 paints unless
     * the brand has set the instance's own --td-edge-fill-hero or
     * --td-edge-fill-alt. The footer crest needs nothing here: it inherits the
     * footer's own scheme. A row with no scheme of its own inherits main's, and
     * a value that does not resolve leaves the token unset, so block 22 falls
     * back to --td-edge-fill.
     *
     * IDEMPOTENT and marker-free: classList.add twice is once, setting the same
     * property twice is once, and the classes are function, not proof-of-run.
     * -------------------------------------------------------------------- */
    function adjoin(owner, next) {
        if (!next) { return; }
        var fill = window.getComputedStyle(next).getPropertyValue("--dw-color-background").trim();
        if (fill) {
            owner.style.setProperty("--td-edge-adjoin", fill);
        }
    }

    function edgeMotif() {
        var footer = document.querySelector("footer[data-swift-page-footer]");
        if (footer) {
            footer.classList.add("td-edge-top");
        }

        var main = document.querySelector("main");
        if (!main) { return; }

        var rows = main.querySelectorAll(":scope > section[data-swift-gridrow]");
        if (!rows.length) { return; }

        var heroIndex = -1;
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].querySelector("[data-swift-poster]")) { heroIndex = i; break; }
        }
        if (heroIndex === -1) { return; }

        rows[heroIndex].classList.add("td-edge-bottom");
        adjoin(rows[heroIndex], rows[heroIndex + 1]);

        var previousScheme = rows[heroIndex].getAttribute("data-dw-colorscheme") || "";
        for (var j = heroIndex + 1; j < rows.length; j++) {
            var scheme = rows[j].getAttribute("data-dw-colorscheme") || "";
            if (scheme !== previousScheme) {
                // The band goes on the row ABOVE the boundary, which is the row
                // whose own last line the band would otherwise cover. If that row
                // is the hero it already carries the motif and a second stamp on
                // the same element is nothing at all, so it is left alone.
                if (j - 1 > heroIndex) {
                    rows[j - 1].classList.add("td-edge-bottom");
                    rows[j - 1].classList.add("td-edge-alt");
                    adjoin(rows[j - 1], rows[j]);
                }
                return;
            }
            previousScheme = scheme;
        }
    }

    function run() {
        anchorStrip();
        edgeMotif();
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", run);
    } else {
        run();
    }

})();
