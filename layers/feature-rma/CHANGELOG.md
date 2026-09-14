# Changelog — feature-rma

## 1.0.2

The seeded return is repointed onto the brand order, and the layer now ships the link row it used to
borrow. The subject moves from a row the sample-data layer used to ship as a marker-string fixture to a row of the browsable brand catalogue, and the probe now binds to a subject the base contract guarantees (`base.contract.json` `sampleData.guaranteedRows`, new in base 3.5.0) rather than to a layer. sample-data 4.0.0 is the merge of the two sample-data layers; the `gate-fixtures` edition is deleted and `swift-demo` sets `sampleData: true`, so this probe resolves in the demo edition itself.

- **`EcomRmas` `PACK-RMA-0001`** keeps its id, type and state and moves onto the demo account:
  `RmaCustomerNumber` `TC-100200`, company `Truvio Demo Account`, name `Truvio Buyer`, e-mail
  `buyer@truvio-demo.example`. Country codes are unchanged.
- **`EcomRmaOrderLines` `100301` is new and owned here.** It links `PACK-RMA-0001` to `TCO-0001-1`,
  the first line of the delivered order `TCO-0001` (state `OS2`, buyer `100101`). The table was
  previously seeded by a sample-data raw-SQL script because `RmaOrderLineId` is an int IDENTITY PK;
  it ships as merge-mode SqlTable YAML with `identityColumns: [RmaOrderLineId]` instead, which the
  engine writes verbatim under `IDENTITY_INSERT`, and `100301` sits above the base contract's 100000
  floor. `fragmentTables` and `merge/merge-manifest.json` declare it.
- The `authenticated-body-contains` probe's `requiresFixtures` becomes `TCO-0001`; the pattern, the
  path and the `criticalPaths` entry are unchanged. The layer still ships no `fragmentContent`: the
  My returns page stays surface-swift's.
- The gate finding is unchanged and still applies: a directly-seeded RMA does not list-render in the
  `eCom_CustomerCenter` RMA view, which surfaces RMAs created through its own request flow. The
  automated proof stays page 200 + the seeded row + the authenticated render of the RMA app; the
  "buyer creates a return and it appears" path is the manual UAT, now driven from `TCO-0001`.

## 1.0.1

Every probe and criticalPath moves from the `/swift-2/` area segment to the `/en-us/` culture root (Foundry #965). `AreaUrlName` `swift-2` is decorative on a single-area host: Dynamicweb prefixes the area segment only when more than one area competes for the host and otherwise serves the culture segment, so every `/swift-2/` path answered 404 on a healthy, fully deserialized site while the same pages answered under `/en-us/`. Page targets are unchanged; only the prefix moves. README probe tables follow.

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
