# Changelog — feature-bom-configurator

## 1.2.3

Patch: the `bom-cart-lines` probe declares `groupId: TCGRP-BUNDLES`. The subject, the slots, the
selections and the expected child lines are unchanged; only the address the probe is driven at moves.

Measured on DW 10.28.10 / Swift 2.4 (Foundry #1233), signed in as the shipped buyer persona:

```
/en-us/kit-configurator                                            -> 200, no configurator marker
/en-us/kit-configurator?ProductID=TCPROD0042                       -> 404
/en-us/kit-configurator?GroupID=TCGRP-BUNDLES&ProductID=TCPROD0042 -> 200, js-product-bom-configurator
```

A Swift product page resolves through its group, so the un-qualified address the probe was declared
with 404s on the render proof and on the `cartcmd=add` POST. The BEHAVIOUR was never wrong: driven at
the group-qualified address the same probe produced exactly the declared result - `OL11312`
`TCPROD0042` with `OL11313` `TCPROD0003` and `OL11314` `TCPROD0052` as BOM child lines parented to
it, both chosen through the declared NON-default slots `TC-BOM-0042-1` and `TC-BOM-0042-2`.

`groupId` is a new OPTIONAL `behaviorProbes` field on `layers/layer.schema.json` rather than a query
string inside `path`: `path` stays path-only, because the probe runner refuses `?`, `=` and `&` there
(the T-09-02 injection guard). `asserts.criticalPaths` keeps the bare `/en-us/kit-configurator`,
which answers 200 as a group listing.

## 1.2.2

The `bom-cart-lines` probe moves from `PACK-BOM-0001` to `TCPROD0042`, the configurable Bundle Kit.
The subject moves from a row the sample-data layer used to ship as a marker-string fixture to a row of the browsable brand catalogue, and the probe now binds to a subject the base contract guarantees (`base.contract.json` `sampleData.guaranteedRows`, new in base 3.5.0) rather than to a layer. sample-data 4.0.0 is the merge of the two sample-data layers; the `gate-fixtures` edition is deleted and `swift-demo` sets `sampleData: true`, so this probe resolves in the demo edition itself.

**Why `TCPROD0042` and not `TCPROD0041`.** The brand catalogue's Bundles band carries both a fixed
kit and configurable ones. `TCPROD0041` ("Truvio Bundle Kit 41") is `ProductType 0` and ships **no**
`EcomProductItems` row: it is the fixed kit, the same members for every buyer, priced as one line,
and there is nothing for a configurator to pick. `TCPROD0042` is `ProductType 2` with two
group-bound slots, which is exactly the shape `PACK-BOM-0001` had.

**The selections.** `selections[].group` is the BOM SLOT id (`EcomProductItems.ProductItemId`), not
the `EcomGroups` id, so the two entries are `TC-BOM-0042-1` (binds `TCGRP-VARIANTS`, default
`TCPROD0002`) and `TC-BOM-0042-2` (binds `TCGRP-DOCUMENTS`, default `TCPROD0051`). Each selects the
**non-default** member of its slot — `TCPROD0003` and `TCPROD0052` — so the per-child disambiguation
leg proves the selection was consumed rather than the slot default. `expectedChildLines` stays 2:
two slots, two child lines. No page, template or fragment changes.

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
