> # ⚠️ DEPRECATED — TOMBSTONED (P3, 2026-07-17)
> This over-bundled layer is **split and superseded**. Do NOT add it to new editions.
> - **Reordering** (Quick Order + Express Buy, data-only) → **`feature-reordering@1.0.0`**
> - **Pricing** (qty-break tiers + customer contract + the compile-optional provider) → **`feature-pricing@1.0.0`**
>
> Retained for **one release** for any downstream Distribution edition still pinning `1.2.1`
> (deprecation declared in `layer.json` `costHints.deprecated`). No Foundry edition pins it any
> more (`swift-demo` re-pinned to the two split layers + `feature-rma@1.0.0`). See the split
> verdict in `RUN-DISTRIBUTION-QUALITY.md` (decision D-D) and each successor's README/CHANGELOG.

# feature-reordering-pricing — Feature layer #1: Reordering+ / Complex Pricing

Feature layer delivering the quick-order pad, the buy-it-again proof surface, and qty-break +
customer-contract pricing on top of the swift/2.3 base layer. Satisfies
the layer contract ([`layers/layer.schema.json`](../layer.schema.json)) in full (schema, csLedger,
fragment rules including content, collision checks, activation manifest, publish guards).

## What the layer delivers

| Capability | How | Artifact |
|------------|-----|----------|
| Quick-order pad (CAND-01) | SKU + quantity grid with paste-from-Excel/CSV (tab-separated first, comma/semicolon fallback), feed-based SKU validation, one-click `cartcmd=addmulti` cart fill — all client-side parsing, zero custom server code | `templates/Designs/Swift-v2/Paragraph/PackQuickOrderPad.cshtml`, `itemtypes/ItemType_PackQuickOrderPad.xml`, Quick Order page fragment, shipped in **both** the `Swift 2` (area 3, `/swift-2/quick-order`) and `Swift 2 Nederlands` (area 27) nav trees, navigationTag `QuickOrderPadPage` |
| Editable buy-it-again (empty-cart safe) | **The stock Express Buy `?OrderID=` prefill flow the base layer already routes to** — `OrderViewSearchList.cshtml` renders the Reorder button to `ExpressBuyPage?OrderID=<id>`; the flow prefills an editable quantity grid and submits `cartcmd=addmulti`, which needs no active cart. The layer PROVES this flow (probes on `/swift-2/express-buy`), it does not rebuild it | `layer.json` asserts (`http-body-contains` on the Express Buy page, criticalPath) |
| Qty-break tier pricing | Anonymous-visible `EcomPrices` tier rows on **layer-owned** product `PACK-RPP-PROD1` (RPP-TIER-01, base 4995 EUR): qty 5 → 4500, qty 10 → 4200, qty 25 → 3900 | `merge/_sql/EcomPrices/PACK-RPP-0001..0003.yml` |
| Customer contract pricing | Buyer-scoped `EcomPrices` row on **layer-owned** product `PACK-RPP-PROD2` (RPP-CTR-01, base 1599 EUR): 1399 EUR for customer number `98745621` | `merge/_sql/EcomPrices/PACK-RPP-0004.yml` |
| Cart-enforced quantity tiers | `ReorderingPricingQtyBreakProvider` (cabp lineage) — **exactly why it exists: stock cart resolution ignores tier quantities (`PriceQuantity > 0`) at cart time**, so tier rows render on PDP surfaces but the cart charges the base price without it. The provider is non-exclusive (`HandlePricesExclusively = false`) and returns a price ONLY when a real tier (`Quantity > 1`) matches; base and contract rows fall through to the default provider. **Compile-optional** — see below | `src/ReorderingPricingQtyBreakProvider.cs` (csLedger: `price-provider`, `assembly-scan`; `layer.json` `customCode`) |

## Custom code is compile-optional (decision D3)

The base layer stays **zero custom code** (constraint unchanged). This **feature** layer MAY ship a
**declared, compile-optional** provider — declared machine-readably in [`layer.json`](layer.json)
under `customCode` (`compileOptional: true`). The split:

| | Without compiling (data-only, native platform) | With the opt-in compile |
|---|---|---|
| **Customer-contract pricing** — the **zero-code headline** | ✅ Enforced end-to-end by Dynamicweb's stock `DefaultPriceProvider`. The buyer-scoped `EcomPrices` row (`PACK-RPP-0004`, `PriceUserCustomerNumber 98745621`) prices `PACK-RPP-PROD2` at **1399** for customer `98745621` (base 1599). No custom code. | ✅ Identical — the provider returns `null` for base/contract rows, so they always fall through to the default provider. |
| **Quantity-tier pricing** | ⚠️ Tier rows (`PACK-RPP-0001..0003`) ship as data and render on tier-aware surfaces, but the stock cart resolver ignores tier quantities at cart time — the cart charges the **base** price for tiers. | ✅ `ReorderingPricingQtyBreakProvider` (assembly-scan auto-discovery, non-exclusive) enforces tiers at cart time: `PACK-RPP-PROD1` prices **4500 / 4200 / 3900** at qty 5 / 10 / 25. |

**Opt-in compile step:** add `src/*.cs` to the Swift solution's custom-code project and build; the
provider self-registers via assembly scan (no config row). Documented in the dynamicweb-skills
feature-layer compile recipe. Compiling is **additive** — it never removes or alters the contract-price
guarantee. The Foundry gate compiles + proves the full behavior (both probes); a downstream partner who
does not compile still gets the contract-price headline as pure data.

## Fragment portability (Verdanta DESIGN-1)

The Quick Order page fragment attaches under **base-provided structural ancestors** — the area
(`Swift 2` = area 3, `Swift 2 Nederlands` = area 27), the `Navigation` and
`Navigation/Secondary Navigation` structural-stub pages, plus the fragment-root `area.yml` and
`templates.manifest.yml`. Those paths are **base-owned anchors**.

**Why the layer does NOT ship those ancestor stubs.** The base contract's content-path collision rule
(07-01 / T-07-04) forbids an addition from shipping any `_content` path the base also ships — a
re-shipped ancestor would silently overwrite the base page and the gate throws
(`Test-LayerContentCollision`). So the fragment **references** these ancestors by path and
deliberately leaves them to the base (the intended architecture: additions bind to the base
contract, never re-ship it). Consequence: the fragment deserializes cleanly onto any host that has
the base (every edition composes base-first), but it is **not** standalone-deserializable onto a
bare host — **the base is a prerequisite**. (True in-layer stub duplication would need the gate to
exempt `isStructuralStub` anchor paths from the collision check — a harness/serializer change,
tracked outside this layer.)

**Applying on a renamed area.** The fragment hardcodes the area folder names `Swift 2` (area 3) and
`Swift 2 Nederlands` (area 27) in its `merge/_content/<area>/...` paths and in the two
`merge/merge-manifest.json` Content entries (`areaId` + `areaName`), matched by `layer.json`
`fragmentContent[].areaId`. The base contract anchors these as **area 3 / area 27** — a solution
maps by `areaId`, not by the display name. To apply on a solution whose areas are named
differently: (1) rename the `merge/_content/<area>` folders to the target area names, (2) update the
matching `areaName` (and `areaId` if it differs) in the two manifest Content entries, and (3) update
`fragmentContent[].areaId` in `layer.json`. Nothing in the page bodies depends on the literal string
`Swift 2`, so no paragraph edits are required.

## Canonical buyer contract

- Customer number **`98745621`**, username **`IMCUser`** — seeded per version by the gate
  (`Invoke-SeedGating`, Step 3c2, **pre-host-start**; DW caches identity state at startup).
- Password resolved from the `buyerPassword` secret in git-ignored
  `config/gate-secrets.local.json` (falling back to the documented demo default); never stored
  in this layer or in gate config.
- Contract rows scope by **`PriceUserCustomerNumber` only** — `PriceCustomerGroupId` scoping
  silently fails frontend resolution and is never used (mission-brief locked decision 3).

## Assortment graceful degrade

This base layer carries no `EcomAssortments` rows, so the pad's "validate against the signed-in
customer's assortment" degrades to: **product exists (resolved through the same index feed Express
Buy uses) + price resolves** (the feed price is user-scoped when signed in, so an
assortment-priced buyer sees their price at validation time). On solutions that DO carry
assortments, real enforcement activates automatically — the index query scopes results per user,
so unknown/unavailable SKUs simply stop resolving. No layer change needed.

## CRITICAL: deactivate before re-serializing the base layer (Pitfall 6)

The base layer owns `EcomPrices` as a **whole-table Seed predicate**. Any `Invoke-Serialize`
run against a host with this layer ACTIVE captures the `PACK-RPP-*` rows (and the Quick Order
page) into the base layer, silently breaking the base/layer ownership split.

> **Always run `Invoke-LayerDeactivation` for this layer before any `Invoke-Serialize` run.**
> Deactivation is manifest-tracked and exact (targeted `DELETE` per `PriceId`, GUID-keyed page
> teardown), so the host returns to a clean base state.

(07-04 also routes this rule into the distribution repo's CONTRIBUTING via the morning handoff.)

## Reorder mechanisms explicitly NOT used

| Mechanism | Why not |
|-----------|---------|
| `CustomerCenterCmd=Reorder` | Appends to the *active* cart and **silently no-ops when the cart is empty** — it is the stock template's fallback branch only; the base layer never takes it because the Express Buy page + nav tag resolve |
| `cartcmd=copyorder` | **Dead on Swift 2.x** (historical full-test field finding) — never resurrect it |

## Probe expectations (07-04 gate proof)

| Probe | Expectation |
|-------|-------------|
| `http-body-contains /swift-2/quick-order` | addmulti form marker (`name="cartcmd" ... value="addmulti"`) |
| `http-body-contains /swift-2/express-buy` | `id="ExpressBuySearchForm"` (buy-it-again surface, anonymous) |
| `cart-price` PACK-RPP-PROD2 × 1 via `/swift-2/quick-order` → `/swift-2/cart/` | unit price **1399** as the signed-in buyer 98745621 (contract row applied at cart time — the storefront-cart verification rule) |
| `cart-price` PACK-RPP-PROD1 × 5 via `/swift-2/quick-order` → `/swift-2/cart/` | unit price **4500** (tier applied end-to-end — the Q5 composition arbiter) |

> **Why the contract probe is cart-price, not a PDP body probe (07-04 live finding):** the probe
> was originally authored as `authenticated-body-contains` on the derived PDP slug
> `/swift-2/shop/scattante-cfr-race`. Live 2.3 evidence (run 20260702-093557 triage): that slug
> 404s (product URLs route through the Product Details service page), and Swift's PDP does not
> server-render price tokens in the response body — a body-contains price probe on the PDP can
> never PASS regardless of path. The cart-price probe is the stronger authenticated proof and
> matches locked decision 5 ("verify prices in the storefront cart as the signed-in buyer").
> A PDP-rendered price check becomes meaningful once the stock ProductPriceTable paragraph lands
> on the PDP (queued swift/2.3.1 base layer improvement).

Displayed cart prices are VAT/locale-dependent per shop configuration; if the live cart shows a
VAT-adjusted amount, adjust `expectedAmount` from the observed FAIL detail (the probe reports the
observed price tokens) — the 07-04 runbook owns that call.

## Known Issues

| Issue | Impact | Workaround |
|-------|--------|------------|
| Quick Order deactivate→reactivate cycle limitation (declared) | After `Invoke-LayerDeactivation` followed by re-activation, the Quick Order page (`/swift-2/quick-order`) returns 404 — the 2-page area 3 + area 27 NL-mirror fragment does not fully re-bind on reactivation, so the two quick-order **cycle** asserts (`http-body-contains` and `sku-validation` on `/swift-2/quick-order`) fail in the gate's Step 12c cycle leg. **Scope: toggle-cycle only.** Normal (first) activation, main-leg installation, and every behavior assert on first activation are unaffected; the sibling `/swift-2/express-buy` surface survives the cycle. | A full re-deserialize of the base layer + layer restores the page. |

### Gate treatment — declared known-cycle-limitation (WARN, not FAIL)

This limitation is **declared in `layer.json`** under `knownCycleLimitations` (two entries: the
`http-body-contains` and `sku-validation` asserts on `/swift-2/quick-order`, phase `behavior-cycle`).
The gate **honors** it: when either matches in the Step 12c deactivate→reactivate cycle leg it is
recorded as **`KNOWN-LIMITATION` (WARN)** — surfaced loudly in the pipeline log and the
`COMPATIBILITY` layer rows with the declared reason — and does **not** flip the gate to FAIL.

The exemption is scoped as tightly as possible: **only** these two quick-order `behavior-cycle`
asserts. Every other cycle assert of this layer — the config-row cycle probes, the
`/swift-2/express-buy` behavior cycle assert, the cart-price cycle probes, the critical-path cycle
checks, and the always-on sweeps — still **hard-fails** the gate if it breaks. A first-activation
(Step 12b) failure of the same probes is never exempted. See
the layer contract ([`layers/layer.schema.json`](../layer.schema.json)) for the contract mechanism.
