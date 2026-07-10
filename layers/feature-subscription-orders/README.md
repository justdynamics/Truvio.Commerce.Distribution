# feature-subscription-orders — Feature layer #2: Subscription Orders

Feature layer delivering invoice-based recurring (subscription) checkout and a customer-center
subscriptions surface on top of the swift/2.3 base layer. Satisfies
the layer contract ([`layers/layer.schema.json`](../layer.schema.json)) in full (schema, fragment
rules including content, collision checks, activation manifest, publish guards). **Zero custom `.cs`** — the
native DW 10.26.9 engine does all the work; the layer is pure exposure wiring.

## What the layer delivers

| Capability | How | Artifact |
|------------|-----|----------|
| Invoice recurring checkout (PK2-01) | Layer-owned Subscribe page with a minimized 3-step `eCom_CartV2` paragraph; the layer step template renders the native recurring panel (`EcomRecurringOrderCreate` + interval fields — decompile-verified names). The engine's `DefaultCheckoutHandler` (auto-resolved for the gateway-less PAY2 Invoice method) implements `IRecurring`, so checkout completion places the base order AND the `EcomRecurringOrder` template row | Subscribe page fragment (`/swift-2/subscribe`), `templates/Designs/Swift-v2/eCom7/CartV2/Step/PackSubscribeCheckout.cshtml` |
| Customer-center subscriptions list + manage (PK2-02) | Layer-owned Subscriptions page using the stock `eCom_CustomerExperienceCenter` app with `<OrderType>Recurringorder</OrderType>` (mandatory — the standard Orders list SQL excludes recurring templates) and a layer list template with interval/next-delivery detail and an ownership-guarded end-subscription action. The page sits under the base **Customer center → Account** nav tree (beside Orders/Favorites/etc., navigationTag `PackSubscriptionsPage`); because `Account` is base **replace**-owned content, this page ships as a **replace** fragment (`fragmentModes: ["merge","replace"]`) so the base Account parent is staged at deserialize | Subscriptions page fragment under `/Customer center/Account/Subscriptions`, `templates/Designs/Swift-v2/eCom/CustomerExperienceCenter/Orders/List/PackSubscriptions_List.cshtml` |
| Declared config dependencies (PK2-03) | SQL EXISTS probes on the base layer rows the layer rides on: `EcomPayments` PAY2 (Invoice, ENU), `EcomShippings` SHIP9 (Home delivery, ENU), and the native `ScheduledTask` row "Place recurring orders" | `layer.json` configRows |

## Zero-.cs architecture

`csLedger: []` — this layer ships **zero custom `.cs`**: templates + content fragments +
configRows, plus (since 1.1.0) its own layer-owned catalog rows. `DefaultCheckoutHandler` covers
the invoice path (any payment method with `PaymentAddInType != Checkout` resolves to it, and its
`RecurringSupported` returns true), the CartV2 frontend parses the recurring POST fields natively,
and the platform's own scheduled task generates follow-up orders. PAY2/SHIP9/ScheduledTask are
**declared configRow dependencies, not fragment rows** — the layer inserts nothing into those
tables. **1.1.0 self-sufficiency:** the base layer is scaffolding-only, so the layer now ships its
own recurring product `PACK-SUB-PROD1` + group `PACK-SUB-GRP1` + group/shop relations
(`fragmentTables`: EcomGroups, EcomProducts, EcomGroupProductRelation, EcomShopGroupRelation) —
the checkout-recurring probe rides the layer product, never a base catalog row.

## Morning admin step: enable scheduled generation

The gate proves the `ScheduledTask` row "Place recurring orders" **exists** — not that it runs.
The platform auto-creates it at host startup **disabled** (`TaskEnabled=0`, every 5 min). To
demonstrate follow-up order generation:

1. Admin → **Settings → Scheduled tasks → "Place recurring orders"** → enable.
2. Place a subscription (StartDate today). Placement nulls `LastDelivery`, so the **first
   follow-up order is due on the task's very next run** (~5 min).
3. The follow-up order appears in Orders (`OrderRecurringOrderId` set).

Do NOT flip `TaskEnabled` via SQL — DW caches scheduled-task state at startup, and layer
activation has no arbitrary-SQL hook by design.

## `EcomRecurringOrderCreate` toggle-off semantics (Pitfall 4)

The engine treats the field in three distinct ways:

| POST state | Engine behavior |
|------------|-----------------|
| Absent | Recurring state untouched |
| Present, value `True` | Create/update the cart's recurring template |
| Present, **empty value** | **Actively DELETES the cart's recurring template** |

The checkout template therefore ships **exactly one static element** carrying the field name —
the `value="True"` checkbox — and **never a static hidden empty-value companion** (the classic
hidden-field pattern would make every non-subscribing checkout tear down any recurring draft).
Keep this invariant in any template edit; it is machine-checked
(`tests/Layer.Tests.ps1`, Pitfall 4 single-input lock).

**Deliberate cancel on uncheck (CR-01, Phase 8 review).** Field-absent leaves an *existing*
draft untouched, so uncheck-then-complete after an intermediate auto-post (shipping/payment
`onchange` → `submitForm()` already created the draft) would otherwise still complete as a
subscription against the user's opt-out. The checkbox therefore carries
`data-was-checked` (bound to `Ecom:Order.Recurring.Enabled` at render time) and an `onchange`
handler (`packSyncRecurringCancel`) that appends **one JS-created hidden empty-value
`EcomRecurringOrderCreate` field ONLY when a draft exists AND the user explicitly unchecks** —
the engine's designed delete signal, emitted deliberately and never statically. Re-checking the
box removes the hidden field again. Accidental present-but-empty stays structurally impossible:
the static markup never contains an empty-value element, and the only code path that creates one
requires `was-checked && unchecked`.

## CSRF residual risk (end-subscription action)

The cancel action in `PackSubscriptions_List.cshtml` accepts no antiforgery token — the DW
platform ships none for frontend forms, so this is the same exposure level as every stock Swift
form. Mitigations in place: the handler is **POST-only** (reads `Request.Form`, never the query
string), requires a **signed-in user**, and enforces the **ownership guard**
(`recurring.UserId == Pageview.User.ID`) before `EndRecurring`. Residual risk: a signed-in user
could be CSRF'd into ending *their own* subscription (never someone else's). `EndRecurring` sets
`RecurringOrderEndDate` — history is retained, nothing is deleted.

## Canonical buyer contract

- Customer number **`98745621`**, username **`IMCUser`** — seeded per version by the gate
  (`Invoke-SeedGating`, pre-host-start).
- Password resolved from the `buyerPassword` secret in git-ignored
  `config/gate-secrets.local.json` (falling back to the documented demo default); never stored
  in this layer or in gate config.
- The Subscriptions paragraph lists by customer number (`RetrieveListBasedOn=UseCustomerNumber`),
  so the checkout probe's placed order (same user) resolves in the list.

## CRITICAL: deactivate before re-serializing the base layer (Pitfall 6)

Any `Invoke-Serialize` run against a host with this layer ACTIVE captures the Subscribe and
Subscriptions pages into the base layer content tree, silently breaking the base/layer
ownership split.

> **Always run `Invoke-LayerDeactivation` for this layer before any `Invoke-Serialize` run.**
> Deactivation is manifest-tracked and exact (GUID-keyed page teardown, overlay path deletion).

## Probe expectations (gate proof)

| Probe | Expectation |
|-------|-------------|
| `checkout-recurring` on `/swift-2/subscribe` (product PACK-SUB-PROD1 × 1, PAY2/SHIP9, GotoStep1 — `CartV2.GotoStep{i}` is 0-BASED, so index 1 targets the second step, the `IsCheckout=true` Checkout step) | Authenticated multi-step checkout completes; IMCUser's count of `EcomRecurringOrder` rows with a non-empty `RecurringOrderBaseOrderID` **increases across the checkout POST** (before/after delta, Phase 8 WR-01 — pre-existing rows never satisfy the proof) |
| criticalPath `/swift-2/account/subscriptions` | 2xx via the account-gated sign-in redirect (302→sign-in 200, like base Orders — the page lives under Customer center/Account). The Subscribe page is deliberately NOT a criticalPath: anonymous + empty cart hits `EmptyCartRadioRedirect` with unverified target semantics (RESEARCH A4) |

## Authenticated list-render — real-host UAT (LRN-HARNESS-03)

The subscriptions **list render** (the signed-in page showing `data-pack-subscription-id=`
rows) is a **real-host UAT item, not a gate probe.** The harness clean-room does not
materialize customer-group → page-permission grants for the seeded buyer, so **no**
`Customer center/Account` page renders for IMCUser in-gate — base `Orders`/`Addresses`/
`Favorites` return "You do not have permission" exactly as this page does (verified: the
buyer is correctly in the `Customers` group `1325` and Account grants `1325`, but the grant
is not honored by frontend access resolution after a clean-room deserialize). This is the
permission-tier analog of the storefront-index gap (LRN-HARNESS-01).

**Gate-proven here:** the subscription is *created* (`checkout-recurring` SQL delta) and the
Account-nested URL resolves + auth-gates (`criticalPath` 302→sign-in). **Verify on a real
Swift 2.3 host:** sign in as the buyer, open `/swift-2/account/subscriptions` under the
Account nav, and confirm the placed subscription renders with its `End subscription` action.
Because the page lives in the Account nav tree (its correct home, beside Orders) rather than
as a public Secondary-Nav page, its in-gate proof is the auth-gate above rather than a public
render, and full render is a real-host UAT — as with the BOM configurator render.
