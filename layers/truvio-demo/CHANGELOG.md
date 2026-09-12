# Changelog — truvio-demo

## 1.0.0

The first release of the **Truvio Commerce brand data** as its own layer (V5-PLAN §2.4,
decisions **D-B** and **D-D**).

Until now an edition had exactly one place to put demo rows, and it was the layer the gate
uses for its own fixtures. That forced a choice nobody wants to make: either the marker
strings the design gate scans for (`Placeholder …`, the `FIXT*` keys, the RMA order) live
inside the catalogue a prospect is shown, or the brand catalogue displaces the fixtures the
gate asserts on. `truvio-demo` ends the choice. It is a second layer of kind `sample-data`
— no new kind was invented, per D-D — and the two key families are disjoint by
construction: `FIXT*` / `PACK-*` there, `TC*` here. `swift-demo` composes both;
`base-swift` composes neither.

**The naming rule is the substance of the layer.** No real-world product domain appears
anywhere. Four top groups (`Data Models`, `Commerce`, `Content`, `Users`) each carry three
subgroups named from platform vocabulary, the 60 masters read `Truvio <Concept> <Unit>
<NN>` against SKU `TC-<CONCEPT>-<nnnn>`, and the variant axes are `Tier` and `Mode` rather
than `Size` and `Finish`, which are worldly. The 28 category fields are `Facet`, `Variant
Axis`, `Completeness Score`, `Price Matrix`, `Grid Row`, `Permission Grant` and their kin.
The result is a catalogue that doubles as a platform-terminology tour and cannot be
mistaken for a real business — which is the point: demo data that reads as a plausible
supply house is demo data someone eventually ships to a customer by accident.

**What lands** (`merge/_sql/`, all three scripts declared in `layer.json` `sql[]`, phases
and orders after `sample-data`'s):

- `truvio-catalog.sql` — 16 groups (4 top + 12 sub), 60 masters + 36 variant combination
  rows, 40 prices, 1 BOM kit with two group-bound slots, 2 services, a three-step quantity
  ladder, one contract price scoped by customer number, 4 product categories × 7 category
  fields, 180 field values.
- `truvio-identities.sql` — the B2B account, three personas on the fictional
  `truvio-demo` domain, 6 memberships, 12 orders with 20 lines.
- `truvio-images.sql` — the 12 concept tiles attached as the default image of all 96
  product rows.

**Four decisions worth keeping in view.**

Every variant combination carries its **own** `EcomPrices` row. A variant with no price row
inherits the master's, and the whole tier ladder then reads as one price on the PDP — the
axis renders, the selector works, and nothing changes when you use it.

The identities script runs `after-replace-deserialize` rather than `before-host-start`,
where `sample-data`'s identities live, because its orders FK the shop, currency and
catalogue rows. DW caches identity state at startup, so the personas become first-class on
the host restart the catalogue already requires — one restart covers all three scripts.

The orders use only `OrderFlowId 1` states (`OS1 New`, `OS2 Completed`, `OS3 Rejected`).
`OS12`/`OS13`/`OS14` belong to flow 4, and an order carrying a state from another flow
reads as a broken record in every Commerce grid.

Imagery is attached through `EcomDetails` with the column list resolved from `sys.columns`,
and mirrored onto the legacy `EcomProducts.ProductImage*` columns where a build still has
them. The optional detail columns differ across platform builds, and an `INSERT` naming a
column the build lacks takes the whole script down. A missing `EcomDetails` table raises
rather than skips: a demo that seeds no image and reports success is the failure the file
exists to prevent.

Every insert is `IF NOT EXISTS`-guarded on its own key, so a re-run converges. Nothing in
this layer deletes.
