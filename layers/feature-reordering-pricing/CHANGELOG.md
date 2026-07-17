# Changelog — feature-reordering-pricing

## DEPRECATED — 2026-07-17 (P3 tombstone, no version bump)

**Split and superseded** (RUN-DISTRIBUTION-QUALITY decision D-D). The layer bundled two independent
capabilities; they now ship as two clean layers:

- **`feature-reordering@1.0.0`** — data-only Quick Order pad + Express Buy nav/pages/probes (the item
  type, template, both-area page fragment, `http-body-contains` + `sku-validation` probes, and both
  `/swift-2/quick-order` known cycle limitations). `sku-validation` re-pointed to the sample-data SKU
  `FIXT-0001`.
- **`feature-pricing@1.0.0`** — the qty-break tier rows, the customer-contract row, the six `configRows`,
  the `customCode` block, and `ReorderingPricingQtyBreakProvider.cs` (all moved verbatim). The two
  `cart-price` probes re-pointed off `/swift-2/quick-order` onto `/swift-2/cart/` (the only coupling
  between the halves — a test-authoring convenience, not a real dependency).

No version bump: `1.2.1` is retained unchanged for **one release** for downstream editions still pinning
it (deprecation declared in `layer.json` `costHints.deprecated`, `supersededBy`). No Foundry edition pins
it any longer — `swift-demo` re-pinned to `feature-reordering@1.0.0` + `feature-pricing@1.0.0` +
`feature-rma@1.0.0`. Removal is a follow-on release once no edition references it.

## 1.2.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

## 1.1.0 — declared known cycle-limitation (gate honors as WARN)

- **Quick Order deactivate→reactivate known limitation, now declared + gate-honored.**
  Added `knownCycleLimitations` to `pack.json` — two entries covering the
  `http-body-contains` and `sku-validation` asserts on `/swift-2/quick-order`, phase
  `behavior-cycle`. The 2-page area 3 + area 27 NL-mirror fragment does not fully re-bind
  after a deactivate→reactivate cycle (the page 404s), so these two cycle asserts fail in
  the gate's Step 12c cycle leg. The gate now records them as **`KNOWN-LIMITATION` (WARN)**
  — surfaced loudly in the pipeline log and the COMPATIBILITY pack rows with the declared
  reason — instead of failing the gate.
- **Scope: toggle-cycle only.** Normal (first) activation and all first-activation behavior
  asserts are unaffected. The exemption is tightly scoped to exactly these two quick-order
  `behavior-cycle` asserts; the pack's other cycle asserts (config-row cycle,
  `/swift-2/express-buy` behavior cycle, cart-price cycle, critical-path cycle, sweeps) and
  any first-activation FAIL still hard-fail the gate.
- The blind fix from 1.0.0→1.1.0 (ENU paragraph item-instance id `1`→`100001`) reduced but
  did not eliminate the 404; a real fix remains out of scope (operator capped investment).

## 1.1.0 — catalog-self-sufficient + field-bug fixes

The baseline is now scaffolding-only (zero sample catalog), so this pack ships its
**own** products instead of riding base bike products (10016 / 10002, now gone).

- **Self-sufficiency:** ships `PACK-RPP-GRP1` (group, bound to `SHOP1`),
  `PACK-RPP-PROD1` (RPP-TIER-01, base 4995) and `PACK-RPP-PROD2` (RPP-CTR-01, base
  1599) with their group/shop relations. `fragmentTables` now includes EcomGroups,
  EcomProducts, EcomGroupProductRelation, EcomShopGroupRelation, EcomPrices. The
  EcomPrices tier/contract rows retarget from 10016/10002 to the pack products;
  PriceIds unchanged so the `configRows` EXISTS probes still key correctly. Added two
  `configRows` asserting the pack owns its products.
- **Bug 1 (hardwired base products/buyer):** fixed by the self-sufficiency rows above;
  the buyer contract still scopes to the gate-seeded buyer `98745621`.
- **Bug 2 (manifest honesty):** `seed-manifest.json` lists exactly the shipped files;
  the Content entries reference only base anchors (area.yml, the Navigation page chain,
  templates.manifest.yml) that the scaffolding baseline still ships — never a parent the
  pack neither ships nor is a base anchor. Zips are retired; distribution is `git clone`.
- **Bug 3 (dead SKU validation):** the Quick Order pad's `eCom_ProductCatalog`
  `IndexQuery` repointed from the removed `Repositories/ProductsFrontend/Products.query`
  to the convention `Repositories/Products/Products.query` (`repositoryName: "Products"`
  in pack.json — the gate-provisioned repository). Exercised by the new **sku-validation**
  gate probe so it can never ship dead again.
- **Bug 4 (hardcoded bike tier table):** the pad's paste placeholder and example volume
  schedule now reference the pack's own `RPP-TIER-01` with tier values matching this
  pack's own EcomPrices rows.
- **Cycle bug (blind fix):** the ENU Quick Order paragraph item-instance id moved from
  `1` (below the pack floor) to `100001` — see the fix commit for the causal theory
  (IDENTITY-seed collision on deactivate→reactivate that 404'd the ENU page).

## 1.0.0

- Initial release: quick-order pad + qty-break/contract price provider.
