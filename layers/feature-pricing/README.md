# feature-pricing — Complex pricing (qty-break tiers + customer contract)

Feature layer delivering **B2B pricing** on top of the framework base + surface-swift: quantity-break
tier pricing and buyer-scoped customer-contract pricing, with a **compile-optional** price provider.
Split out of the retired `feature-reordering-pricing` bundle (P3, RUN-DISTRIBUTION-QUALITY, decision
D-D); the reordering half (Quick Order + Express Buy) moved to `feature-reordering`.

## What the layer delivers

| Capability | How | Artifact |
|------------|-----|----------|
| Qty-break tier pricing | `EcomPrices` tier rows on the sample-data product `TCPROD0020` (`TC-PRC-0020`, list 120 EUR): qty 5 → 108, qty 10 → 96, qty 25 → 84 | `sample-data` `merge/_sql/EcomPrices/TC-PRICE-Q{05,10,25}-0020.yml` |
| Customer contract pricing | Account-scoped `EcomPrices` row on the sample-data product `TCPROD0046` (`TC-CTR-0046`, list 45 EUR): 36.90 EUR for customer number `TC-100200` | `sample-data` `merge/_sql/EcomPrices/TC-PRICE-CTR-0046.yml` |
| Catalogue the prices bind to | The sample-data brand catalogue: `TCGRP-PRICE-STRUCTURES` → `TCPROD0020` and `TCGRP-CONTRACT-PRICING` → `TCPROD0046`, both bound to `SHOP1`. This layer ships zero catalogue rows and binds only to `base.contract.json` `sampleData.guaranteedRows` | `sample-data` `merge/_sql/` |
| Cart-enforced quantity tiers | `ReorderingPricingQtyBreakProvider` (**compile-optional**) — stock cart resolution ignores tier quantities at cart time, so tier rows render on PDP surfaces but the cart charges the base price without it | `src/ReorderingPricingQtyBreakProvider.cs` |


> **Where the catalogue rows live (Foundry 960, this release).** This layer ships **zero**
> catalogue rows. The products, groups, relations and prices it demonstrates against are seeded by
> the `sample-data` layer (`merge/_sql/feature-fixtures.sql`), with every id unchanged, so they ride
> the single `sampleData` edition toggle like the rest of the catalogue. Composed with
> `sampleData: false` this layer now adds no products and no groups; its behaviour probes are
> meaningful only on an edition that also carries sample data.

## Custom code is compile-optional (decision D3)

Declared machine-readably in [`layer.json`](layer.json) under `customCode` (`compileOptional: true`):

| | Without compiling (data-only) | With the opt-in compile |
|---|---|---|
| **Customer-contract pricing** — the **zero-code headline** | ✅ Enforced end-to-end by the stock `DefaultPriceProvider`. `TC-PRICE-CTR-0046` (`PriceUserCustomerNumber TC-100200`) prices `TCPROD0046` at **36.90** for the demo account, against a 45.00 list and a 39.60 customer-group row. No custom code. | ✅ Identical — the provider returns `null` for base/contract rows, always falling through. |
| **Quantity-tier pricing** | ⚠️ Tier rows ship as data and render on tier-aware surfaces, but the stock cart resolver ignores tier quantities — the cart charges the **customer-group** price (108). | ✅ `ReorderingPricingQtyBreakProvider` (assembly-scan, non-exclusive) enforces tiers at cart time: `TCPROD0020` prices **108 / 96 / 84** at qty 5 / 10 / 25 against a 120 list. |

**Opt-in compile step:** add `src/*.cs` to the Swift solution's custom-code project and build; the
provider self-registers via assembly scan (no config row). Compiling is **additive** — it never removes
or alters the contract-price guarantee. The Foundry gate compiles + proves both `cart-price` probes.

## Probe expectations (test coupling broken — P3)

Both `cart-price` probes now use **`/en-us/express-buy`** as the add-to-cart vehicle (was
`/en-us/quick-order`). The combined layer routed these probes through the Quick Order page, which was
only a test-authoring convenience — contract/tier pricing resolves on **any** add-to-cart surface. The
re-point removes the last coupling to the reordering half: `/en-us/express-buy` is the OOTB buy-it-again
multi-add page shipped by **surface-swift** (present in every edition that composes surface-swift, and
independent of `feature-reordering`), and it processes the `cartcmd=addmulti` numbered-field POST directly.

> **Authoring note (P3 gate finding).** The `cart-price` `path` (the addmulti POST target) must NOT carry
> a trailing slash: POSTing to `/en-us/cart/` 301-redirects and the follow drops the POST body, so the
> add silently no-ops ("product not found in the cart body"). Any non-slash ecommerce page with cart
> context works (`/en-us/express-buy`, `/en-us/shop`, `/en-us/cart`); `express-buy` is the chosen
> decoupled surface. The `cartPath` GET keeps the canonical trailing slash (`/en-us/cart/`).

| Probe | Expectation |
|-------|-------------|
| `cart-price` TCPROD0046 × 1 via `/en-us/express-buy` → `/en-us/cart/` | unit price **36.90** as the signed-in buyer on account `TC-100200` (contract row applied at cart time — data-only; list 45.00, customer-group 39.60) |
| `cart-price` TCPROD0020 × 10 via `/en-us/express-buy` → `/en-us/cart/` | unit price **96** (tier applied end-to-end — requires the compiled provider) |

**Why quantity 10 and not 5.** `TCPROD0020` also carries a customer-group row `TC-PRICE-GRP-0020`
at 108 for group `1325` at quantity 1, and the probe signs in as the buyer, who is a member of
that group. At quantity 5 the expected amount would be 108 whether or not the tier ladder fired,
so the assert would be vacuous. 96 is reachable only through `TC-PRICE-Q10-0020`.

Displayed cart prices are VAT/locale-dependent per shop configuration; the probe matches locale-tolerantly
and reports observed price tokens on FAIL.

## Canonical buyer contract

Customer number **`TC-100200`**, buyer **`TruvioBuyer`** (`AccessUser` `100101`) — a
`base.contract.json` `sampleData.guaranteedRows` subject, present when an edition sets
`sampleData: true`. Contract rows scope by
**`PriceUserCustomerNumber` only** (`PriceCustomerGroupId` scoping silently fails frontend resolution).

## CRITICAL: deactivate before re-serializing the base layer (Pitfall 6)

The base owns `EcomPrices` as a whole-table predicate; any `Invoke-Serialize` run against a host carrying
sample data captures the `TC-PRICE-*` rows into the base. **Always run `Invoke-LayerDeactivation` for the
composed layers before any `Invoke-Serialize` run.**

## Provenance

Split from `feature-reordering-pricing@1.2.1` (P3, 2026-07-17). Fresh `1.0.0`. The `configRows`, the
`customCode` block, and `src/ReorderingPricingQtyBreakProvider.cs` moved **verbatim**. The combined layer
is tombstoned (deprecated, kept one release).
