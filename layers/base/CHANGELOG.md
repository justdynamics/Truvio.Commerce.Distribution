# Changelog — base

## 3.0.1

Learnings triage fixes (RUN-TRIAGE-20260713 in the Foundry):

- **LRN-sapporo-01:** all 17 GBP `EcomCurrencies` rows shipped `CurrencyRate: 0` —
  any price-context path converting through GBP (the index price sweep computes
  prices per currency) threw `DivideByZeroException`, emptying PDP price/add-to-cart
  paragraphs. Rows now ship `CurrencyRate: 86`. Gate lint: no `EcomCurrencies` row
  may ship `CurrencyRate <= 0`.
- **LRN-hosted-publish-03:** `config/swift-2.4.json` declared the retired predicate
  mode enum (`"Deploy"` ×16), which engine 0.8.1-beta — this layer's own declared
  floor — rejects with a 500 on every serializer call including the read-only
  settings query. All predicates now `"mode": "Replace"`. Gate probe: after staging
  the config, `GET /Admin/Api/SerializerSettings` must return 200 with a non-empty
  `predicatesSummary`.

## 3.0.0

**Framework-only (the Swift 2.4 base split).** Breaking restructure, executed at the
Swift 2.4 roll-forward (RUN-SWIFT-24; FOLLOWUP bump plan):

- **ALL content moved out** to the new `surface-swift` 1.0.0 layer: `replace/_content`
  (areas 3 "Swift 2" + 27 "Swift 2 Nederlands") and the ENTIRE `merge/` tree. The base
  is now `fragmentModes: ["replace"]` — no merge pass.
- **UrlPath moved to surface-swift** (its one row is a friendly-URL redirect bound to
  area 3 + a Swift page id; no route targets exist in a framework-only base).
- **Kept:** the 16 framework `replace/_sql` sets (shops + relations, languages,
  currencies, countries + relations, VAT, order flow/states/rules, payments, shippings,
  AccessUser permission-group trio) + `base.contract.json` (2.0.0, framework anchors
  only) + the SQL-predicate config (`config/swift-2.4.json`).
- **Engine floor: Truvio.Commerce.Serializer 0.8.1-beta** (DW packages retargeted to
  10.28.1-PreRelease for Swift 2.4 / DW 10.28).
- **Why at the bump:** the base had to be re-proven against 2.4 anyway; the restructure
  rides that sweep, and future Swift content churn lands in surface-swift instead of
  forcing base re-proves. Framework SQL is never duplicated across frontends
  (swift-demo and headless-demo now share the identical framework root).

**Proven on DW 10.28.1-PreRelease** (operator-approved override; stable re-prove
mandatory when DW 10.28 reaches NuGet stable). Editions re-pin to `base@3.0.0`.

## 2.4.1

Brand-neutral starter content. The scaffolding base no longer reads as a bike shop:
the bike-era editorial copy is rewritten to industry-neutral commerce copy so every
demo starts from a clean, brand-agnostic slate.

- **Bike-era copy neutralized (both languages).** About, Home, the Home-preset,
  Employees, About-us/Delivery SEO descriptions and the store Terms heading no longer
  reference bikes/bicycles/cycling. Examples: "Your Trusted Partner in Bicycle Solutions"
  → "…in Commerce"; "High Quality Bikes & Parts" → "High Quality Products & Parts";
  "Electric bikes are here to stay" → "Innovative products are here to stay"; "Swift
  Bikes" team copy → generic. No posts deleted (the Posts index and its category pages
  were already brand-neutral). Page titles are untouched, so the title-integrity gate leg
  stays green (122 pages, DB Title == YAML).
- **Legit survivors, left intentionally.** The stock Swift sample rich-text under
  `Navigation` (mountain-trail review filler — no bike brand or model names) and the
  `Product Info` `FieldDisplayGroups` config (a product field-group data identifier list,
  not editorial copy) are not brand strings and remain.
- **Line endings normalized.** All base YAML is uniformly CRLF + UTF-8 BOM (the
  serializer-native convention); the 2.4.0-touched Customer Center subtree (40 files that
  were LF/mixed in the working tree) is normalized, so a serializer round-trip is
  byte-stable.

No behavior, permissions, or engine-floor change from 2.4.0 — content-only patch. Editions
re-pin to `base@2.4.1`.

Gate: base-only PASS (`runs/20260710-155148`) + swift-demo PASS (theme leg on); permissions
parity 133 and title integrity 122 both green.

## 2.4.0

Per-role Customer Center, fully derived from the layer YAML. What a consumer sees change
from 2.3.2:

- **Per-role tile dashboard on ONE shared Overview.** The buyer tiles (My orders, Quotes,
  Carts, Favorites, Addresses, Profile, Returns) and the CSR tiles (Accounts, Orders,
  Carts, Users) now live on the same `Overview` page. Each tile — and its grid row —
  carries a serialized `permissions:` block, so a signed-in **buyer** sees only the buyer
  tiles and a signed-in **CSR** sees only the CSR tiles, on the same URL, with zero custom
  code. English + Dutch. (Buyer tiles: Customers=all / CSR=none; CSR tiles: CSR=all /
  Customers=none; Anonymous=none everywhere.)
- **CSR split-landing retired.** The separate `CSR` tile dashboard (duplicated grid +
  HelloUser) is removed; the CSR function pages (Accounts / Orders / Carts / Users) stay,
  and a CSR now lands on the shared Overview. Nav stays permission-filtered.
- **Dutch Customer Center is now gated for anonymous.** The NL `/customer-center/*` subtree
  carries the same page-level `permissions:` blocks as the English side (Anonymous → sign-in),
  closing the 2.3.2 "both languages" gap. (NL rows/paragraphs are independent content —
  they do not inherit the EN master's permissions — so NL carries its own serialized blocks.)
- **Historical title smears corrected.** Three bike-era `fields.Title` values from an old
  engine link-resolution defect are fixed: NL "My profile", EN "Search result page", EN
  "Favorites list service". (EN "Home preset" = "Contact" and NL "Home preset" = "Home" are
  legitimate stock Swift preset labels — verified against the pristine control DB — and are
  left untouched.)
- **Engine floor.** This base carries render-time permissions on grid rows and paragraphs,
  which require **Truvio.Commerce.Serializer >= 0.8.0-beta**. Older engines silently drop
  those blocks → ungated tiles. The floor is machine-readable in
  `base.contract.json` (`minSerializerVersion`). **Upgrade the serializer before consuming
  this base.**

Editions that build on the base (`swift-demo`, `headless-demo`, `base-only`, `dap-portal`)
re-pin to `base@2.4.0`.

Gate: base-only + swift-demo green on the current latest Swift (2.3), theme leg on, with two
new gate legs — permissions-parity (every serialized page/row/paragraph block ⇔ matching
`UnifiedPermission` rows) and title-integrity (item Title == YAML). Real buyer + CSR role UAT
confirms the per-role tiles behaviorally.

## 2.3.2

B2B-default pass: the base layer now presents a business-buyer storefront out of
the box, gate-proven on Swift 2.3. What a consumer sees change from 2.3.1:

- **Anonymous pricing hidden.** Prices are hidden for anonymous visitors on the
  product list and detail pages; a sign-in nudge replaces them. Signed-in buyers
  see prices. (B1)
- **Single, neutrally-named shop.** The nine demo shops collapse to one —
  "B2B Commerce Store" (formerly "Bikes"). The eight extra shops
  (Product category, Partner, Brands, Additionals, Digital Assets Portal,
  Channel-Amazon, Printing catalogs, EU Packaging) and their shop/group and
  shop/language relation rows are removed. Bind the site root + shop after
  deserialize, then restart (see the base contract). (B5)
- **List-mode product listing.** The product list page defaults to list view with
  B2B-fit columns; the grid toggle stays available. Standard Swift building
  blocks only — no custom templates or code. (B4)
- **"Home Machines" page removed.** The demo Home Machines page is gone from both
  the English and Dutch content areas, with its navigation and merge-manifest
  entries pruned. (B2)
- **Digital Assets Portal header decoupled.** The Swift storefront header no
  longer carries a link to the Digital Assets Portal (desktop, English + Dutch);
  the reciprocal storefront back-link is removed from the `dap-portal` layer. (B3)
- **Customer Center Overview is a tile dashboard.** Signing in lands the buyer on
  a function-tile dashboard (Orders, Quotes, Carts, Favorites, Addresses,
  Profile, Returns) instead of an order list — each tile routes to its function
  page. English + Dutch. (B6)
- **CSR dashboard + page-level gating.** A separate CSR dashboard ships, with
  Customer Center pages gated by role (CSR vs. buyer) at the page level. (B7)
- **Returns (RMA) in the Customer Center.** A "My returns" / "Mijn retouren" page
  wired to the stock Swift returns components is added to the customer tree and
  the tile dashboard, English + Dutch. (B9)
- **Per-environment exclusions documented.** `base.contract.json` now enumerates
  the deliberately non-serialized per-environment Area columns (domain,
  frontpage, shop, country, language, currency, stock location) and the consumer
  obligation to bind site root + shop after deserialize and restart. (B10)

Editions that build on the base (`swift-demo`, `headless-demo`, `base-only`,
`dap-portal`) re-pin to `base@2.3.2`.

Known issues deliberately shipped (deferred, tracked): a few historical item
Titles carry bike-era text from an engine link-resolution defect fixed upstream
(no new occurrences), and the Dutch Customer Center subtree is not yet gated for
anonymous visitors (the English subtree is). Both are queued for a follow-up
pass.
