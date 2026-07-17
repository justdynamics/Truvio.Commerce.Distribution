# feature-pricing — Complex pricing (qty-break tiers + customer contract)

Feature layer delivering **B2B pricing** on top of the framework base + surface-swift: quantity-break
tier pricing and buyer-scoped customer-contract pricing, with a **compile-optional** price provider.
Split out of the retired `feature-reordering-pricing` bundle (P3, RUN-DISTRIBUTION-QUALITY, decision
D-D); the reordering half (Quick Order + Express Buy) moved to `feature-reordering`.

## What the layer delivers

| Capability | How | Artifact |
|------------|-----|----------|
| Qty-break tier pricing | Anonymous-visible `EcomPrices` tier rows on **layer-owned** product `PACK-RPP-PROD1` (RPP-TIER-01, base 4995 EUR): qty 5 → 4500, qty 10 → 4200, qty 25 → 3900 | `merge/_sql/EcomPrices/PACK-RPP-0001..0003.yml` |
| Customer contract pricing | Buyer-scoped `EcomPrices` row on **layer-owned** product `PACK-RPP-PROD2` (RPP-CTR-01, base 1599 EUR): 1399 EUR for customer number `98745621` | `merge/_sql/EcomPrices/PACK-RPP-0004.yml` |
| Self-sufficiency | Ships its own group `PACK-RPP-GRP1` (bound to `SHOP1`) + the two products + group/shop relations so tier/contract prices resolve against layer-owned catalog, not the demo catalog | `merge/_sql/EcomGroups`, `EcomProducts`, `EcomGroupProductRelation`, `EcomShopGroupRelation` |
| Cart-enforced quantity tiers | `ReorderingPricingQtyBreakProvider` (**compile-optional**) — stock cart resolution ignores tier quantities at cart time, so tier rows render on PDP surfaces but the cart charges the base price without it | `src/ReorderingPricingQtyBreakProvider.cs` |

## Custom code is compile-optional (decision D3)

Declared machine-readably in [`layer.json`](layer.json) under `customCode` (`compileOptional: true`):

| | Without compiling (data-only) | With the opt-in compile |
|---|---|---|
| **Customer-contract pricing** — the **zero-code headline** | ✅ Enforced end-to-end by the stock `DefaultPriceProvider`. `PACK-RPP-0004` (`PriceUserCustomerNumber 98745621`) prices `PACK-RPP-PROD2` at **1399** for customer `98745621`. No custom code. | ✅ Identical — the provider returns `null` for base/contract rows, always falling through. |
| **Quantity-tier pricing** | ⚠️ Tier rows ship as data and render on tier-aware surfaces, but the stock cart resolver ignores tier quantities — the cart charges the **base** price. | ✅ `ReorderingPricingQtyBreakProvider` (assembly-scan, non-exclusive) enforces tiers at cart time: `PACK-RPP-PROD1` prices **4500 / 4200 / 3900** at qty 5 / 10 / 25. |

**Opt-in compile step:** add `src/*.cs` to the Swift solution's custom-code project and build; the
provider self-registers via assembly scan (no config row). Compiling is **additive** — it never removes
or alters the contract-price guarantee. The Foundry gate compiles + proves both `cart-price` probes.

## Probe expectations (test coupling broken — P3)

Both `cart-price` probes now use **`/swift-2/express-buy`** as the add-to-cart vehicle (was
`/swift-2/quick-order`). The combined layer routed these probes through the Quick Order page, which was
only a test-authoring convenience — contract/tier pricing resolves on **any** add-to-cart surface. The
re-point removes the last coupling to the reordering half: `/swift-2/express-buy` is the OOTB buy-it-again
multi-add page shipped by **surface-swift** (present in every edition that composes surface-swift, and
independent of `feature-reordering`), and it processes the `cartcmd=addmulti` numbered-field POST directly.

> **Authoring note (P3 gate finding).** The `cart-price` `path` (the addmulti POST target) must NOT carry
> a trailing slash: POSTing to `/swift-2/cart/` 301-redirects and the follow drops the POST body, so the
> add silently no-ops ("product not found in the cart body"). Any non-slash ecommerce page with cart
> context works (`/swift-2/express-buy`, `/swift-2/shop`, `/swift-2/cart`); `express-buy` is the chosen
> decoupled surface. The `cartPath` GET keeps the canonical trailing slash (`/swift-2/cart/`).

| Probe | Expectation |
|-------|-------------|
| `cart-price` PACK-RPP-PROD2 × 1 via `/swift-2/express-buy` → `/swift-2/cart/` | unit price **1399** as the signed-in buyer 98745621 (contract row applied at cart time — data-only) |
| `cart-price` PACK-RPP-PROD1 × 5 via `/swift-2/express-buy` → `/swift-2/cart/` | unit price **4500** (tier applied end-to-end — requires the compiled provider) |

Displayed cart prices are VAT/locale-dependent per shop configuration; the probe matches locale-tolerantly
and reports observed price tokens on FAIL.

## Canonical buyer contract

Customer number **`98745621`**, username **`IMCUser`** — seeded per edition by the gate
(`Invoke-SeedGating`, pre-host-start; requires `sampleData: true`). Contract rows scope by
**`PriceUserCustomerNumber` only** (`PriceCustomerGroupId` scoping silently fails frontend resolution).

## CRITICAL: deactivate before re-serializing the base layer (Pitfall 6)

The base owns `EcomPrices` as a whole-table predicate; any `Invoke-Serialize` run against a host with this
layer ACTIVE captures the `PACK-RPP-*` rows into the base. **Always run `Invoke-LayerDeactivation` for
this layer before any `Invoke-Serialize` run.**

## Provenance

Split from `feature-reordering-pricing@1.2.1` (P3, 2026-07-17). Fresh `1.0.0`. The `configRows`, the
`customCode` block, and `src/ReorderingPricingQtyBreakProvider.cs` moved **verbatim**. The combined layer
is tombstoned (deprecated, kept one release).
