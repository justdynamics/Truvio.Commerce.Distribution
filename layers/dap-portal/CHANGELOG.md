# Changelog — digital-asset-portal/1.0

## Unreleased (beta)

- Removed the "< Swift Bikes Webshop" cross-link row from the Desktop Header
  (`Digital Assets Portal/Header _ Footer/Desktop Header/grid-row-1`, the
  `Swift-v2_Text` link to `Default.aspx?ID=6869`). Vice-versa half of the base
  layer 2.3.2 DAP-decoupling pass (RUN-BASE-2.3.2 item B3): the base Swift header
  no longer links to the DAP, and the DAP no longer links back to the Swift
  storefront. Stays Beta/untagged — no version graduation with this edit.

## 1.0.0 (beta)

- First captured baseline for the Digital Asset Portal on DW 10.26.7.
- Deploy tree (1 predicate): the Digital Assets Portal area (area 26) — Home,
  Digital Assets browser, Download Cart, Customer center, Sign in (~32 pages,
  122 YAML files).
- Built on Swift-v2 item types; deploys as an add-on to the `swift/2.2` baseline.
- Beta: requires the Swift-v2 design (incl. `Swift-v2_VerticalNavigation` item
  type) on the target; one acknowledged dangling demo link (page 8330). See
  BASELINE.md.
- Config: `config/digital-asset-portal-1.0.json`.
