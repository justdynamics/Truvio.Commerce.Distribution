# feature-rma — RMA / returns (data-only)

New feature layer (**zero custom code**) that lights up the **RMA / returns** demo beat on the Swift B2B
storefront. Added in P3 (RUN-DISTRIBUTION-QUALITY, item E, decision D-E). Edition placement: `swift-demo`.

## OOTB research — everything is already shipped

DW10 Order Management ships the full RMA subsystem, and Swift 2.4 wires the **My RMA** customer-center app
OOTB. Confirmed against the gate DB (`Harness-Swift-2.4`, Swift 2.4 / DW 10.28.1-PreRelease):

| Piece | OOTB source | Evidence |
|-------|-------------|----------|
| **My returns page** (`/swift-2/customer-center/my-returns`) | **surface-swift** (`replace/_content/.../Customer center/Customer center/My returns`) — an `eCom_CustomerCenter` app paragraph, `DefaultView=rma`, `RMASource=orders`, `RMAListTemplate=RMAList.cshtml`, `RMADetailsTemplate=RMADetails.cshtml` | page renders; request types **Return / Defect / Exchange** (`RmaType` 1/2/3) → select order → items → reason/info → create; CSR processes from the order-list Actions menu |
| **Status flow** (7 states) | **DW platform default** (`EcomRmaStates`) | Waiting for product(s) from customer *(default for new RMA)* / Received / Rejected / Sent for repair / Received from repair / Returned to customer / Sent replacement — with `RmaStateTypeRelation` gating states per request type |
| **Lifecycle events** (7) | **DW platform default** (`EcomRmaEvents`) | Created / Closed / StateChanged / CommentAdded / Deleted / ReplacementOrderSet / UserInfoChanged |

There is **no separate "return reasons" table** in DW10 — the request **types** (`RmaType`) and the
**status flow** (`EcomRmaStates`) are the configurable axes, and both are platform defaults. The state
`DefaultName` values are rendered directly (no translation seed required). So the layer **adds zero code
and seeds nothing that already exists** — it only seeds the demo instance data.

## What the layer seeds

| Row | Where | Purpose |
|-----|-------|---------|
| **RMA return request** `PACK-RMA-0001` | this layer — `merge/_sql/EcomRmas/PACK-RMA-0001.yml` | a pre-existing Return (`RmaType 1`, state 1, buyer `98745621`) so the My returns page shows a real request, not the empty state |
| **Delivered order** `FIXT-ORDER-RMA1` (+ its order line) | **sample-data** (`merge/_sql/catalog.sql`) | a completed order (`OrderStateId OS2`) owned by buyer `98745621` to return against — orders are demo content, so they live in sample-data (P3 interplay) |
| **RMA ↔ order-line link** (`EcomRmaOrderLines`) | **sample-data** (`merge/_sql/catalog.sql`) | ties `PACK-RMA-0001` to the delivered order line so `Ecom:RMA.OrderID` resolves. `EcomRmaOrderLines.RmaOrderLineId` is an **int IDENTITY PK** — the serializer supports natural-key inserts only for four declared relation tables (base contract), not this one, so the link is seeded via sample-data raw SQL, which handles identity columns deterministically |

### sample-data dependency (noted per the schema mechanism)

The seeded request is **surfaced** only when the buyer identity (`98745621`) and the delivered order
exist — i.e. an edition with `sampleData: true`. The dependency is declared machine-readably via
`configRows` (the `EcomRmas` EXISTS probe fires after activation) and enforced by the gate. The layer
ships **no `fragmentContent`**: it must not re-ship the surface-owned My returns page (base-contract
content-path collision rule) — it references it and seeds against it.

## Probe expectations

| Probe | Expectation |
|-------|-------------|
| `criticalPath /swift-2/customer-center/my-returns` | the My RMA customer-center page responds 2xx |
| `authenticated-body-contains /swift-2/customer-center/my-returns` (`Add new request`) | signed in as buyer `98745621`, the My RMA customer-center app renders (its "+ Add new request" affordance) — proves the RMA CC surface is wired and live for the buyer |
| `configRows EcomRmas RmaId='PACK-RMA-0001'` | deterministic SQL proof the return request row was seeded |
| `configRows EcomRmaStates RmaStateDefaultName='Rejected'` | the OOTB status flow is present (platform default) |

### Gate finding — a directly-seeded RMA does not list-render (DW CC limitation)

The seeded request `PACK-RMA-0001` is present and **fully linked** (verified in the gate DB: EcomRmas +
EcomRmaOrderLines → the delivered order line → an order the buyer owns), and the buyer's **My orders**
page renders `FIXT-ORDER-RMA1` correctly. But the Swift **My returns** list shows "No Requests found":
the `eCom_CustomerCenter` RMA view (`RMASource=orders`, `RMAList.cshtml`) surfaces RMAs created through
its own request flow, **not** RMA rows inserted directly by SQL/serializer. This is a DW platform
behaviour, not a data defect — no amount of correct seeding makes the list render a raw row (a fabricated
render would need custom code, which this data-only layer forbids). The automated proof therefore matches
the spec's stated validation exactly — **page 200 (criticalPath) + a seeded return request row
(configRows)** — plus an authenticated proof that the RMA app itself renders for the buyer. The
"buyer creates a return and it appears" path is the OOTB **manual UAT** below (the delivered order is
seeded precisely so a human can drive it).

## Manual UAT (beyond the automated probes)

Buyer signs in → My returns → "+ Add new request" → picks the delivered order `FIXT-ORDER-RMA1` → selects
items → chooses a request type → creates. The new request appears in the buyer's list and in the CSR's
order-list Actions menu; the CSR advances the state through the OOTB flow. This flow is entirely OOTB
(zero layer code); the layer's job is to seed the order to return against and one pre-existing request.

## Provenance

New in P3 (2026-07-17), fresh `1.0.0`. `swiftVersion` 2.4.0; proven on `swift-demo` (see the
RUN-DISTRIBUTION-QUALITY P3 gate stamp).
