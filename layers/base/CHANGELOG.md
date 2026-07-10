# Changelog — base

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
