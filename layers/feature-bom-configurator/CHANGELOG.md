# Changelog — feature-bom-configurator

## 1.1.0 — catalog-self-sufficient parent + children

The baseline is scaffolding-only (zero sample catalog), so the pack now ships its
entire BOM catalog instead of riding base products/groups (PROD290/GROUP49/GROUP161/
10028/10119, all gone).

- Ships the Rule-B parent `PACK-BOM-0001`, two child groups (`PACK-BOM-FORKS`,
  `PACK-BOM-RACKS`) with two pack-owned child products each, the parent group
  `PACK-BOM-GRP1`, and all group/shop relations to `SHOP1`. `fragmentTables` now
  includes EcomGroups, EcomGroupProductRelation, EcomShopGroupRelation (plus the
  existing EcomProducts, EcomProductItems).
- Slots `PACK-BOM3-0002`/`0003` repointed to the pack-owned groups + default children.
- **Removed** the base-`PROD290` slot `PACK-BOM3-0001` — a slot on a base product is
  meaningless once the baseline ships no catalog; both slots now ride the pack parent.
- `bom-cart-lines` probe selections repointed to the pack-owned non-default children
  (`PACK-BOM-FORK-2`, `PACK-BOM-RACK-2`); `renderProof: false` retained (the clean-room
  provisions no storefront index for BOM render).

## 1.0.0

- Initial release: multi-group BOM configurator (native `EcomProductItems` slots).
