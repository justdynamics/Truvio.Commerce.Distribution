# Headless product repository — search surface (ADR-001, option a)

DW repository definitions consumed by the Delivery API search endpoints
(`POST /dwapi/ecommerce/products` / `GET /dwapi/ecommerce/products/search` with
`RepositoryName=Headless`, `QueryName=Products`). The harness-owned `Products` repository ships an
**index only** (no `.query`), so query resolution 400/404s against it — PLP, faceted navigation,
and text search are dead without a resolvable named query. This directory closes that gap for the
headless baseline.

```
repositories/
└─ Headless/                  ← RepositoryName
   ├─ Products.index          # ProductIndexBuilder (Lucene), ENU/SHOP1 rows via Ecommerce.Context
   ├─ Products.query          # QueryName "Products": text (q/eq), GroupID, sku + facet params
   └─ Products.facets         # 3 facet groups: Manufacturer, Group, Price buckets
```

## Design notes

- **Schema uses only fields with backing rows in the harness DB**: default `ProductIndexBuilder`
  fields plus `ProductName`/`ProductNumber`/`ManufacturerName` sources, a `ProductPrice` bucket
  grouping (`PriceRange`), and a `freetext` copy-field. Deliberately **no** `ProductCategory|*`
  custom-field sources — the E2E overlay's own Products.index is the known-bad variant that
  references those with zero backing rows (see `tools/harness/Invoke-HostProvision.ps1`,
  `Deploy-VerifyIndexDefinition` doc block).
- **Locale scoping is runtime, not baked in**: `LanguageID == Dynamicweb.Ecommerce.Context:LanguageID`
  and `ShopIDs MatchAny Dynamicweb.Ecommerce.Context:ShopID` macros — the storefront's canonical
  defaults are `ENU` + `SHOP1` (see BASELINE.md, Locale/area contract).
- **Paging/sort** are Delivery API runtime parameters (`PageSize`/`PageIndex`/`SortBy`/`SortOrder`);
  the query ships a `_score` default sort and a stored `NameForSort` field for name sorting.

## Gate staging contract (disk-overlay surface, like `itemtypes/`)

The gate must stage this tree to the host **before** host start, mirroring
`Deploy-VerifyIndexDefinition` (file-sentinel idempotent copy, harness-owned artifact — SPEC-06
boundary: gate tooling / disk overlay, never serialized DB content):

1. Copy `repositories/Headless/*` → `<hostPath>\wwwroot\Files\System\Repositories\Headless\`.
2. After baseline deserialize (products present), trigger a **Full** build of `Headless` /
   `Products.index` instance `Products` and poll via the same admin API endpoints Invoke-Verify
   uses (`indexStatusPath` / `instanceStatusPath` in `config/gate-config.json`).
3. Assert: build completes; `POST /dwapi/ecommerce/products` with
   `{"RepositoryName":"Headless","QueryName":"Products"}` returns HTTP 200 with a **non-zero**
   product count; facet groups Manufacturer/Group/Price are present in the response.

See BASELINE.md "Gate-assert plan" (A7-A9) for the full assert set.
