# sample-data (kind: sample-data)

Optional demo identities the gate seeds so authenticated flows (customer center, reorder,
subscription checkout, contract pricing) have a canonical buyer + CSR to run as (E2E-03).

**Activation is SQL-seed, not serializer YAML.** The content is the hardcoded builder
`Get-SeedGatingSql` in `tools/harness/Invoke-SeedGating.ps1`; the gate activates this layer at
Step 3c2 (before host start — DW caches identity at startup) with `-SkipContractRow` (the fixture
contract price is seeded by [`catalog-fixture`](../catalog-fixture/README.md) once products exist).

Seeds (exact ids, idempotent): `AccessUser` permission groups 1325 Customers / 1270 Account Admin /
1292 CSR (type 2) + users 1328 **IMCUser** (buyer, cust 98745621) / 1326 **IMCSalesrep** (CSR, cust
7789765) (type 5); `AccessUserGroupRelation` 1328→1325, 1326→1292. All anchors are base-contract rows.
