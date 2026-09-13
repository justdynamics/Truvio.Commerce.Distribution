# Changelog — feature-bom-configurator


## 1.2.1

Every probe and criticalPath moves from the `/swift-2/` area segment to the `/en-us/` culture root (Foundry #965). `AreaUrlName` `swift-2` is decorative on a single-area host: Dynamicweb prefixes the area segment only when more than one area competes for the host and otherwise serves the culture segment, so every `/swift-2/` path answered 404 on a healthy, fully deserialized site while the same pages answered under `/en-us/`. Page targets are unchanged; only the prefix moves. The cart target is `/en-us/cart/`: `Shopping cart` is a non-clickable folder with `urlIgnoreForChildren`, so its `Cart` page resolves without the folder segment.

## 1.2.0

**Zero catalogue rows (Foundry 960).** The BOM parent `PACK-BOM-0001`, its four child products, the
three groups (`PACK-BOM-GRP1`, `PACK-BOM-FORKS`, `PACK-BOM-RACKS`), their shop and group relations
and both `EcomProductItems` slot rows moved to `sample-data` `merge/_sql/feature-fixtures.sql` with
every id unchanged. `fragmentTables` keeps only what the layer still writes; the catalogue
`configRows` are removed. The `bom-cart-lines` probe is untouched and still selects the non-default
child in each slot.

The layer keeps what actually makes it a BOM feature: the two content pages, the
`PackBomDetailRenderGrid.cshtml` detail template and the slot wiring recipe in the README.

## 1.1.1

Swift 2.4 roll-forward re-prove (RUN-SWIFT-24): `swiftVersion` claim rolls to **2.4.0**
on the split composition (base 3.0.0 framework-only + surface-swift carries the Swift
content). No data/content changes. **Proven on DW 10.28.1-PreRelease**
(stable re-prove due when DW 10.28 lands stable on NuGet).

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
