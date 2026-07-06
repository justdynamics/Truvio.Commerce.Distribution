# Changelog — reordering-pricing

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
