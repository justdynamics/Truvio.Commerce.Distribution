# Headless 2.3 baseline

**Product line:** `headless` — a distinct baseline product line (D5), fully decoupled from `swift/2.3`.
**Baseline version:** 2.3.0
**Target:** current latest Swift release (Swift 2.3) on DW 10.26.9 — rolling latest-only.
**Languages:** English (`Headless` area) + Dutch language layer (`Headless Nederlands`) — EN/NL parity, mirroring the Swift baseline's `Swift 2` / `Swift 2 Nederlands` precedent.
**Config:** [`config/headless-2.3.json`](config/headless-2.3.json)
**Consumer:** the `Truvio.Commerce.Storefront` Next.js headless frontend, via the DynamicWeb Delivery API.

This baseline carries exactly the content a **headless** frontend needs — catalog navigation/menus,
content pages, and B2B/customer-center structures — as **zero-custom-code YAML**. It is its own
product line with an independent lifecycle and its own gate pass; it shares **no** item-type rows
with Swift.

---

## Packaging decision — real serializer shape adopted (reconciles §4.3)

STOREFRONT-PHASE §4.3 sketches a simplified `baseline/headless/2.3/{config,content,BASELINE.md}`
tree. That sketch's single `content/` folder does **not** match the serializer the harness gate
actually consumes. The real catalog package shape (see
`Truvio.Commerce.Serializer.Baselines/packages/swift/2.3` and this harness's `baseline/swift/2.3`)
splits content by **serializer mode** — `deploy/` (source-wins) and `seed/` (field-level merge) —
each carrying its own `schemaVersion: 2` manifest plus `_content/` (page trees) and `_sql/`
(commerce rows) subtrees, driven by a `config/<name>.json` predicate list.

**Chosen shape (the gate consumes it):**

```
baseline/headless/2.3/
├─ BASELINE.md
├─ CHANGELOG.md
├─ config/
│  └─ headless-2.3.json          # serializer predicate list (Content + SqlTable)
├─ itemtypes/                     # D6 Headless_* item-type definitions (disk-overlay, zero code)
│  └─ Headless_*.json
├─ repositories/                  # product search surface (disk-overlay, zero code) — see its README
│  └─ Headless/                   # RepositoryName for /dwapi/ecommerce/products
│     ├─ Products.index           # ProductIndexBuilder (Lucene), ENU/SHOP1 via Ecommerce.Context macros
│     ├─ Products.query           # QueryName "Products" — q/eq, GroupID, sku + facet params
│     └─ Products.facets          # Manufacturer, Group, Price buckets
├─ deploy/                        # source-wins framework (nav, customer-center, area chrome)
│  ├─ deploy-manifest.json
│  ├─ _content/Headless/ …        # EN
│  ├─ _content/Headless Nederlands/ …   # NL parity
│  └─ _sql/                       # commerce reference tables (captured at serialize time)
└─ seed/                          # customer-owned bootstrap (home, about, catalog landing)
   ├─ seed-manifest.json
   ├─ _content/Headless/ …
   ├─ _content/Headless Nederlands/ …
   └─ _sql/                       # catalog/prices (captured at serialize time)
```

`content/` from the §4.3 sketch maps onto `deploy/_content/` + `seed/_content/`. The deploy/seed
split is mandatory because the serializer keys its merge behavior off the mode, and the gate stages
the two mode trees separately.

---

## Content model — the `Headless_*` item-type layer (D6)

New, **presentation-agnostic** item types under the `Headless_*` namespace. They never reuse or
share a Swift `ItemType_<systemName>` row — the same namespacing discipline the feature layers use
for IDs (the layer contract, `layers/layer.schema.json`). No Swift paragraph item type is ported;
the two candidates that are
genuinely presentation-free (spec-sheet, downloadable-asset) are defined **fresh** in this
namespace rather than lifted from Swift.

The **commerce/PIM domain model is reused, not the item types** — products, groups, variants,
prices, orders, users, and facets are delivered through the product/order Delivery API endpoints
(and captured as `Ecom*` SqlTable rows, see below), never as item types. Only field-type
*conventions* carry over.

| Item type | Category | Purpose | Instances in this baseline |
|---|---|---|---|
| `Headless_Master` | site | Area master: site name, locale, menu refs, contact. No layout/colorscheme/template fields. | area.yml (EN+NL) |
| `Headless_PageProperties` | page | Minimal structural page-property item (`AreaItemTypePageProperty` target). No Icon/SubmenuType. | every page's propertyFields |
| `Headless_Page` | page | Generic semantic content node (title/slug/summary/SEO). | reserved (schema shipped) |
| `Headless_ContentPage` | page | Rich content page; body is portable markdown/structured text. | Home, About, Catalog Landing |
| `Headless_Menu` | navigation | Menu container keyed by `MenuKey` (header/footer/catalog); maps to Vercel Commerce `Menu[]`. | Header Menu, Footer Menu |
| `Headless_MenuItem` | navigation | One nav entry → content path or commerce group/product id. No template selection. | Products, About, Terms |
| `Headless_CustomerCenter` | b2b | Customer-center root: auth requirement + permitted access-user groups. | Customer center |
| `Headless_AccountSection` | b2b | One account section mapped to a Delivery API endpoint + role (orders/reorder/users/addresses/…). | Orders, Reorder, Users, Addresses |
| `Headless_SpecSheet` | commerce-content | Presentation-free product spec sheet (JSON spec rows). Fresh D6 definition. | Product Spec Sheet |
| `Headless_DownloadableAsset` | commerce-content | Presentation-free downloadable datasheet/manual metadata. Fresh D6 definition. | Datasheet Download |

Independent evolution is the point: Swift item types roll with Swift's Razor building blocks;
`Headless_*` items roll with the Next.js component contract.

---

## Item-instance ID floor band

Per the layer contract (`layers/layer.schema.json` §3), item-instance ids are **global per itemType
across layers** because `(itemType, fields.Id)` pairs land as PK rows in the shared
`ItemType_<systemName>` tables. Occupied floors today: reordering `100001/100004`, subscription
`100001-100003`, bom `100010-100016`.

**This baseline reserves the `200000–209999` band** for all headless item instances — a distinct
floor band, well clear of the packs' `100000+` usage.

- EN instances use even offsets, NL instances use odd/next offsets, so EN and NL never collide
  within the same `ItemType_Headless_*` table (both language layers write the same tables).
- Current allocation: `200000–200003` masters/nav-folders, `200010–200031` menus/menu-items,
  `200040–200065` customer-center/account-sections, `200100–200119` content pages + spec-sheet +
  downloadable-asset. The full band is headless-owned; new headless content takes the next free id
  in `200000+`.
- Because `Headless_*` item types are brand-new tables that only this baseline writes, there is
  **zero** collision risk with Swift's `Swift-v2_*` rows regardless of id number.

---

## Commerce domain data (`_sql`)

The `Ecom*` SqlTable predicates in `config/headless-2.3.json` (countries, currencies, languages,
shops, payments, shippings, order flow/states, customer-center access groups; and the seed
catalog: groups, products, variants, prices) are **reused domain data (D6)**. Their row files are
**not hand-authored** — the orchestrator's `Invoke-Serialize` pass captures them from the live
harness host under `_sql/<Table>/<key>.yml`, exactly as the Swift baseline does. The `_sql/`
directories currently ship a README placeholder; the manifests list only the authored `_content`
entries (authored scope). See `deploy/_sql/README.md`.

The frontend consumes this commerce data through the Delivery API product/order endpoints, not
through item types.

---

## Product search surface — `Headless` repository + `Products` query (ADR-001)

ADR-001 resolved to **option (a)**: a DynamicWeb provider module behind the Vercel Commerce
data-layer contract, consuming the Delivery API (`/dwapi/**`, REST/JSON — no GraphQL/OData). PLP,
faceted navigation, and text search go through `POST /dwapi/ecommerce/products` /
`GET /dwapi/ecommerce/products/search`, which require a **RepositoryName + QueryName** pair. The
harness-owned `Products` repository ships an index with **no resolvable query** (probes → 400/404),
so this baseline ships its own complete search surface under `repositories/Headless/`:

- **`Products.index`** — `ProductIndexBuilder` (Lucene, single `Products` instance). Schema uses
  only fields with backing rows in the harness DB: `ProductName`/`ProductNumber` search fields,
  `ManufacturerName` facet field, a `ProductPrice` bucket grouping (`PriceRange`), a `freetext`
  copy-field, and `NameForSort`. Deliberately no `ProductCategory|*` custom-field sources (the
  known-bad variant documented in `tools/harness/Invoke-HostProvision.ps1`).
- **`Products.query`** — the named query (`QueryName=Products`). Runtime locale/shop scoping via
  `Dynamicweb.Ecommerce.Context:LanguageID` / `:ShopID` macros; parameters: `q`/`eq` (text search),
  `GroupID` (collection PLP), `sku`, plus the facet params. Paging/sort are Delivery API runtime
  parameters (`PageSize`/`PageIndex`/`SortBy`/`SortOrder`).
- **`Products.facets`** — three facet groups: **Manufacturer** (`Manufacturer_Facet`), **Group**
  (`ParentGroupIDs` → `GroupID`), **Price** (`PriceRange` buckets).

Staging contract (gate): copy `repositories/Headless/*` →
`<hostPath>\wwwroot\Files\System\Repositories\Headless\` pre-host-start, mirroring
`Deploy-VerifyIndexDefinition` (disk-overlay surface like `itemtypes/` — gate tooling / config,
never serialized DB content, zero custom code). Full details in
[`repositories/README.md`](repositories/README.md).

---

## Slug contract (ADR-001 — the provider reshaper relies on this)

Vercel Commerce routes on `handle` slugs; DW keys numeric/string `ProductId`/`GroupId`. Stable slug
sources, chosen so URLs survive baseline rebuilds:

| Domain type | `handle` source | Reverse resolution by the provider |
|---|---|---|
| Product | **product `number` field** (`EcomProducts.ProductNumber`) | `Products.query` param `sku` (In on `ProductNumber_Search`) or products endpoint number filter |
| Collection | **group id** (`EcomGroups.GroupId`, e.g. `GROUP1`) | `Products.query` param `GroupID` (MatchAny on `ParentGroupIDs`) |

Product numbers are business-stable identifiers that survive re-serialization and rebuilds;
database-assigned/auto ids and display names (rename-fragile) are explicitly **not** slug sources.
Menu items already follow this: `Headless_MenuItem.TargetRef` carries a `GroupId` for
`LinkType=ProductGroup` and would carry a product number for `LinkType=Product`.

---

## Locale/area contract (ADR-001)

- **Canonical storefront defaults: language `ENU` + shop `SHOP1`.** Product data lives under `ENU`
  (425 products) — **not** `LANG1`. The `Products.query` scopes by the runtime
  `Ecommerce.Context:LanguageID`/`:ShopID`, so the provider must establish that context
  (ENU/SHOP1) on every Delivery API call.
- **Areas carry the shop/language/currency bindings** (Swift precedent: area 3 `Swift 2` EN /
  area 27 `Swift 2 Nederlands` NL). The `Headless` (EN) and `Headless Nederlands` (NL) areas must
  be bound to `SHOP1` + their language at provisioning; the binding columns
  (`AreaEcomShopId`/`AreaEcomLanguageId`/`AreaEcomCurrencyId`) are per-environment and excluded
  from serialization (`excludeAreaColumns`), matching the Swift baseline.
- **Menu shape:** `GET /dwapi/frontend/navigations/{areaId}` — recursive `nodes[]`. The
  `Headless_Menu`/`Headless_MenuItem` structures are authored as a page subtree
  (`/Navigation/Header Menu/*`, `/Navigation/Footer Menu/*`) precisely so the navigations endpoint
  returns them as nodes; `MenuKey`/`Label`/`LinkType`/`TargetRef` item fields enrich the nodes for
  the provider's `Menu[]` reshaping.
- **Content pages:** `GET /dwapi/content/pages` (page list/tree) +
  `GET /dwapi/content/rows/{pageId}/{device}` (row/paragraph payload). `Headless_ContentPage`
  fields (`Slug`, `Lead`, `BodyMarkdown`, SEO) ride along as item fields in those responses.

---

## Open items pending ADR-001 (D2 backend integration)

ADR-001 is **decided**: option (a) — DW provider module behind the Vercel Commerce data-layer
contract, consuming the Delivery API (`/dwapi/**`, REST/JSON only). Status of the original open
items:

1. ~~**Menu shape / page-tree contract.**~~ **RESOLVED** — menus via
   `GET /dwapi/frontend/navigations/{areaId}` (recursive `nodes[]`), content pages via
   `/dwapi/content/pages` + `/dwapi/content/rows/{pageId}/{device}`. See Locale/area contract
   above.
2. **`Headless_AccountSection.DeliveryEndpoint` values.** STILL OPEN — placeholder generic paths
   (`/dwapi/orders`, `/dwapi/orders/reorder`, `/dwapi/users`, `/dwapi/users/addresses`); the real
   order/customer endpoints and auth model await the provider implementation.
3. ~~**Area integer id / bindings.**~~ **RESOLVED** — canonical defaults `ENU` + `SHOP1`; areas
   carry the shop/language/currency bindings per the Swift area 3/27 precedent (bindings are
   per-environment, excluded from serialization). The illustrative `areaId: 5` in `config` is
   host-assigned at serialize time and matched by area GUID/name on deserialize.
4. **`TargetRef` id conventions for menu items.** STILL OPEN as an end-to-end provider concern —
   the slug contract above pins products → product number and collections → group id, but the
   provider's reshaper must confirm page-ref resolution (`LinkType=ContentPage`).
5. **Reorder / CSR-impersonation** — STILL OPEN; represented as `Headless_AccountSection`
   descriptors + frontend-contract docs (feature-packs-as-docs, §4.4); their concrete Delivery API
   surface awaits the provider implementation.

---

## Live gate evidence (run 20260703-092134 — GATE PASS 9/9)

The headless gate leg is wired and **PASSes clean-room on Swift 2.3**. Runner:
`gate-headless.ps1` + `config/gate-config.headless.json` + `tools/harness/Invoke-Headless.ps1`
(unit suite `tests/Headless.Tests.ps1` 6/6). All A1–A9 PASS; evidence under `runs/<ts>/`
(`COMPATIBILITY.{json,md}`, `catalog/`, `headless/`, `index/`, `delivery-*.json`).

**Two decisions taken at gate time (were open):**

- **Catalog data = shared-catalog (Option a).** The headless leg deserializes as an
  *additional leg on top of the swift/2.3 deploy+seed* in the same clean-room DB. Deserialize is
  **manifest-driven** (`SerializerOrchestrator.DeserializeEntries(manifest.Entries)`); the headless
  deploy/seed manifests list **only Content entries**, so the shared `Ecom*` catalog (2051 products)
  comes from the Swift leg and is never touched by the headless POST. This honours U3's `_sql`
  serialize-capture deferral. **A6** is therefore *satisfied-by-shared-catalog*; the headless
  package's own `_sql` capture stays deferred.
- **Item-type format = DW item XML under `Files/System/Items`.** DW10 does **not** consume the
  shipped `itemtypes/Headless_*.json` directly — item types are materialized from
  `wwwroot\Files\System\Items\ItemType_<systemName>.xml` at host startup (the ItemManager creates
  the backing `ItemType_<systemName>` SQL table from the XML). `ConvertTo-HeadlessItemTypeXml`
  (in `Invoke-Headless.ps1`) renders the JSON defs to the exact DW XML shape (editor map: Text→
  TextEditor, LongText→LongTextEditor, Checkbox→CheckboxEditor, Integer→IntegerEditor, List→
  DropDownListEditor + Static options, Link→LinkEditor); `Deploy-HeadlessItemTypes` stages them
  pre-host-start (the `Deploy-VerifyIndexDefinition` disk-overlay precedent — gate tooling, zero
  custom code). The shipped JSON stays the human-authored source of truth; the XML is generated.

**Pinned Delivery-API contract (observed live — supersedes the ADR-001 sketch):**

- **Auth:** the Delivery API (`/dwapi/**`) rejects the Management-API token (401). It has its own
  auth: `POST /dwapi/users/authenticate` `{"UserName","Password"}` → `{"token":"<jwt>"}`, used as
  `Authorization: Bearer <token>`.
- **A5 (nav/content):** `GET /dwapi/frontend/navigations/{areaId}` → `{"nodes":[…]}` (recursive,
  `/headless/*` links). `GET /dwapi/content/pages/{pageId}` and `GET /dwapi/content/pages?pageId={id}`
  also 200. `GET /dwapi/content/pages` (no id) → 404 (not a route).
- **A8 (product search):** `GET /dwapi/ecommerce/products/search?RepositoryName=Headless&QueryName=Products&LanguageId=ENU&ShopId=SHOP1&PageSize=N`
  → 200 `{ "products":[…], "pageSize", "pageCount", "currentPage", "totalProductsCount", "sortOrder", "facetGroups" }`.
  **Product count JSON path: `totalProductsCount`** (378 under ENU/SHOP1). Each product: `id`,
  `variantId`, `languageId`, `name`, `title`, `shortDescription`, `longDescription`, …. The sibling
  `POST /dwapi/ecommerce/products` returns **400 for every probed body shape** — its request model is
  an **OPEN item** (the GET search endpoint is the query-resolution proof and is used for the gate).
- **A9 (facets):** in the A8 response, **`facetGroups[].facets[]`** (one group `Products.facets`
  with 3 facets). **Facet field paths:** `facetGroups[i].facets[j].{name, queryParameter,
  facetField, facetType, facetValue, options, optionCount, optionActiveCount,
  optionResultTotalCount, minimumFacetValue, maximumFacetValue}`. Observed: `Group` optionCount=103,
  `Price` optionCount=4 (both populated), `Manufacturer` optionCount=0 (no manufacturer rows in the
  ENU harness set — the group is present/defined; populate needs manufacturer data, an open item).

**Live findings folded into the wiring:**

- DW **reassigns content-item instance ids** on landing — the DB `Id` column is *not* the authored
  `fields.Id` (a fresh ContentPage row landed as `Id=1`, not `200100`). The `200000–209999` band is
  an **authoring convention verified statically in the YAML**, not a DB-observable column; A3 proves
  rows land across `ItemType_Headless_*` (no `Swift-v2_` touched) **and** all authored YAML ids in band.
- The NL language layer needs its **own Content manifest entry** (Swift pairs area 3 + area 27); the
  original single-entry manifests bundled EN+NL under one area-5 entry and created only EN. The
  deploy/seed manifests now carry **paired EN (`Headless`) + NL (`Headless Nederlands`) entries**.
  NL is authored as a **sibling area** (`AreaMasterAreaId: 0`) — deterministic and
  environment-independent; wiring it as a *true DW language layer* (host-assigned master id, like
  Swift's `AreaMasterAreaId: 3`) is an **open item**.

## Gate-assert plan (live results — run 20260703-092134, PASS 9/9)

Runner `gate-headless.ps1` on Swift 2.3, clean-room shared-catalog:

| # | Gate step (analog) | Assert | Level | Notes |
|---|---|---|---|---|
| A1 | Deploy deserialize (Step 10) | `deploy/` + `seed/` POST `SerializerDeserialize` return HTTP 200, zero escalations | Deserialize | Same assertion depth as the Swift baseline. Requires the `Headless_*` itemtype definitions present on the host (disk overlay) before deserialize. |
| A2 | Post-deserialize SQL | Both areas exist: `SELECT COUNT(*) FROM Area WHERE AreaName IN ('Headless','Headless Nederlands')` = 2 | SQL | Area-level parity check. |
| A3 | Post-deserialize SQL | Each `ItemType_Headless_*` table has the expected `(Id)` rows in the `200000–209999` band; EN+NL counts match per page | SQL | Item-instance landing proof; no `Swift-v2_*` row touched. |
| A4 | Content round-trip | Page count per area parity (EN == NL) for the authored tree | SQL | Mirrors Swift's "123 each" page-parity assertion. |
| A5 | Delivery API read | `GET /dwapi/content/{Headless area}/...` returns the nav + content pages as JSON with `Headless_*` fields | Delivery-API | Storefront-relevant read path; asserts the item-type fields serialize generically. |
| A6 | Commerce reference | `Ecom*` reference/catalog rows present after the serialize-captured `_sql` is deployed | SQL | Only after the serialize/capture pass fills `_sql/`. |
| A7 | Host provision (pre-start, Deploy-VerifyIndexDefinition analog) | `repositories/Headless/*` staged to `wwwroot\Files\System\Repositories\Headless\`; after deserialize, a **Full** build of `Headless`/`Products.index` instance `Products` completes within the verify timeout (poll `indexStatusPath`/`instanceStatusPath` from `config/gate-config.json`) | Index build | File-sentinel idempotent copy; build only after products exist in the DB (post-Step-10). |
| A8 | Delivery API search | `POST /dwapi/ecommerce/products` with `{"RepositoryName":"Headless","QueryName":"Products"}` returns HTTP 200 and a **non-zero** product count under ENU/SHOP1 context; `GET /dwapi/ecommerce/products/search?RepositoryName=Headless&QueryName=Products&q=<known term>` returns ≥1 hit | Delivery-API | The query-resolution proof the harness `Products` repository lacks (probes → 400/404). |
| A9 | Delivery API facets | The A8 response carries the three facet groups (Manufacturer, Group, Price) with ≥1 populated option; a faceted request (e.g. `GroupID=GROUP1`) returns a strict subset | Delivery-API | Faceted-navigation proof for the provider's PLP. |

**Harness facts that constrain the asserts (respect these):**

- **No `ProductsFrontend` index in the clean-room.** The harness clean-room does not provision the
  `ProductsFrontend` search index the `eCom_ProductCatalog` apps query, so **storefront product
  render is not gate-provable**. Design catalog/PLP/PDP asserts at the **SQL / Delivery-API** level
  (A2–A9), not via rendered HTML. Storefront render is a real-Swift-host UAT item (mirrors the
  feature-layer `renderProof:false` precedent, the layer contract `layers/layer.schema.json`). The `Headless` repository
  (A7–A9) closes the *search/query* gap for the Delivery API path; it does not (and need not)
  provision `ProductsFrontend` for Razor rendering.
- **Customer-group → page-permission grants don't materialize in-gate (LRN-HARNESS-03).**
  Customer-group → page-permission grants for the seeded buyer do not materialize during the gate.
  So `Headless_CustomerCenter` / `Headless_AccountSection` **permission-gated** pages cannot be
  asserted as access-gated in-gate — verify permission behavior on a **real host**. In-gate, assert
  only that the pages/rows deserialize and the `PermittedGroups` / `RequiredRole` fields persist
  (A3), not that access is enforced.

---

## Deviations / scope notes

- **Skeleton scope.** Representative content set demonstrating all four required surfaces (catalog
  navigation/menus, content pages, B2B/customer-center) in EN+NL parity — not a full Swift-scale
  page tree. New content takes the next free id in `200000+`.
- **`_sql` deferred to serialize-capture** (see Commerce domain data) — not invented by hand.
  At gate time the catalog is supplied by the **shared-catalog** swift/2.3 leg (Option a).
- **Item-type definitions** ship as human-authored JSON under `itemtypes/`; the gate converts them
  to DW `ItemType_<systemName>.xml` (`ConvertTo-HeadlessItemTypeXml`) and stages them into
  `Files/System/Items` pre-host-start (adapted at gate time — DW consumes XML, not the JSON).
- **Gated live on Swift 2.3** — `gate-headless.ps1` PASS 9/9 (run 20260703-092134). Publishing
  stays print-don't-run (no push performed).

## Open-items ledger (post-gate)

| Item | Status | Note |
|---|---|---|
| Catalog `_sql` own-capture | Deferred | Shared-catalog (swift/2.3) supplies it in-gate; own capture pending an `Invoke-Serialize` pass. |
| `POST /dwapi/ecommerce/products` body | Open | Returns 400 for every probed shape; A8 uses the proven `GET /products/search`. Provider must pin the POST model. |
| NL as true DW language layer | Open | Authored as sibling area (`AreaMasterAreaId: 0`) for deterministic parity; true language-layer link needs the host-assigned master id. |
| Manufacturer facet population | Open | Facet group present but `optionCount=0` — the ENU harness set has no manufacturer rows; needs manufacturer data. |
| `Headless_AccountSection.DeliveryEndpoint` real paths | Open | Placeholder generic paths; await provider (ADR-001 item 2). |
| Permission-gated access enforcement | Deferred (real host) | LRN-HARNESS-03 — grants don't materialize in-gate; fields persist (A3). |
