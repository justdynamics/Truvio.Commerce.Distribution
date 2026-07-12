# sample-data `_sql` — executable demo-content scripts

Unlike the serializer-captured `_sql/<Table>/<key>.yml` trees other layers ship, the
sample-data layer's content is **plain T-SQL scripts**, applied with `sqlcmd` (or any SQL
client) against the target Dynamicweb database. Both scripts are idempotent and
transactional (`SET XACT_ABORT ON`).

| Script | What it inserts | When to apply |
|---|---|---|
| `identities.sql` | Permission groups 1325 Customers / 1270 Account Admin / 1292 CSR, buyer 1328 (cust 98745621), CSR 1326 (cust 7789765), memberships | **Before the host starts** — DW caches identity state at startup |
| `catalog.sql` | Demo shop catalog for SHOP1/ENU/EUR: 3 groups, 20 products (14 masters + 6 Size variants), qty-tier ladder + the buyer contract price (`FIXT-PRICE-CONTRACT`) | **After the base layer deserialize** (FK targets SHOP1/EUR must exist), then restart the host (startup catalog cache) |

`identities.sql` takes three `sqlcmd` variables so demo credentials never live in the repo:

```
sqlcmd -S <server> -d <database> -b -i identities.sql `
  -v BuyerUserName="IMCUser" BuyerPassword="<demo password>" CsrPassword="<demo password>"
```

All ids and anchors are base-contract values (`layers/base/base.contract.json`): the
reserved key prefixes `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` belong to this layer; no other
layer may use them.
