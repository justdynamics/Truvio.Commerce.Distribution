# Changelog — feature-rma

## 1.0.0

Initial release (P3 feature surgery, RUN-DISTRIBUTION-QUALITY item E, decision D-E). Data-only,
**zero custom code**.

- **OOTB research (confirmed against the gate DB):** DW10 Order Management ships the RMA state
  machine (`EcomRmaStates` — 7 states) + lifecycle events (`EcomRmaEvents` — 7); Swift 2.4 wires
  the **My RMA** customer-center app OOTB via surface-swift's `My returns` page
  (`eCom_CustomerCenter`, `DefaultView=rma`). Request types Return/Defect/Exchange are `RmaType`
  1/2/3; there is no separate reasons table. The layer therefore seeds **only the demo instance**.
- **Seeds** the RMA return request `PACK-RMA-0001` (`EcomRmas`, nvarchar PK — serializer-friendly)
  for buyer `98745621`, state 1 (default new-RMA state), type 1 (Return).
- **sample-data interplay:** the delivered order `FIXT-ORDER-RMA1` to return against, and the
  `EcomRmaOrderLines` link (an int IDENTITY-PK table the serializer cannot natural-key insert), are
  seeded in `sample-data`'s `catalog.sql` (raw SQL handles identity columns). Dependency declared via
  `configRows` + documented in the README.
- **Probes:** criticalPath + `authenticated-body-contains` on `/swift-2/customer-center/my-returns`
  (buyer sees `PACK-RMA-0001`); `configRows` EXISTS on the seeded request and on an OOTB state.
- Ships **no `fragmentContent`** (the My returns page is surface-owned — re-shipping it would trip the
  base-contract content-path collision check).

`swiftVersion` 2.4.0; proven on `swift-demo`.
