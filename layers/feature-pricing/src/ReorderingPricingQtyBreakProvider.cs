// feature-reordering-pricing pack — cart-enforced quantity-tier PriceProvider (cabp lineage:
// CabpQtyBreakPriceProvider, ported per PK1-03 with the three declared deltas below).
//
// Registration: assembly-scan auto-discovery (the engine's add-in scan finds
// PriceProvider-derived types; no config row required — csLedger classification
// "price-provider", registration "assembly-scan").
//
// Why this exists: the stock cart resolver picks the base EcomPrices row and ignores
// tier rows (Quantity > 0) at cart time — quantity-tier enforcement is the one
// matrix-inexpressible piece of Pack #1's pricing.
//
// Deltas from the cabp analog (orchestrator decision Q5 / mission-brief locked decision 4):
// 1. HandlePricesExclusively = false (cabp shipped true, owning pricing shop-wide —
//    Pitfall 5). FindPrice/FindInformativePrice return a PriceRaw ONLY when the best
//    match is an actual quantity tier (row Quantity > 1); base rows and contract rows
//    (Quantity 0/1) fall through as null so DefaultPriceProvider owns them. A bug here
//    can never null out shop-wide pricing.
// 2. FindQuantityPrices(PriceContext, Product) is also overridden (surface verified by
//    reflection on DW 10.26.9) — returns the matched tier schedule for tier display.
// 3. This header documents the contract constraints:
//    - Data reads exclusively via the Ecommerce Services prices lookup by product id —
//      zero raw SQL strings, zero direct database API calls (Verify Check 7 scans
//      packs/**/*.cs fail-closed; the upstream lineage's cost-price mechanism is NOT ported).
//    - Inputs are limited to the supplied price context and product selection members
//      (customer + customer number, currency, country, shop, time,
//      product/variant/unit/language/quantity). ScopeMatches honors EVERY EcomPrices
//      scope column this baseline uses — including PriceUserCustomerNumber and
//      PriceProductLanguageId (WR-01, Phase 7 review): a customer- or
//      language-scoped tier row must never price out-of-scope shoppers. The
//      provider must NEVER resolve the ambient ecommerce cart state anywhere in its
//      call graph: price providers run INSIDE cart calculation, and reaching back into
//      the active cart re-enters that calculation — a stack-overflow crash of the
//      checkout request (Pitfall 1; the always-on sweep-reentrancy check in
//      Invoke-PackAssert enforces this statically).
//    - Never throws: product id is null-guarded, group resolution degrades to an empty
//      set, and any unexpected state returns null (fall through to the default provider).
//
// Tier pick semantics (kept from the analog): highest Quantity at-or-below the line
// quantity wins; ties break by scope-specificity score, then lowest amount. An empty
// scope column is a wildcard; ValidFrom/ValidTo windows are respected.

using Dynamicweb.Ecommerce.Prices;
using Dynamicweb.Ecommerce.Products;
using Dynamicweb.Extensibility.AddIns;
using Dynamicweb.Security.UserManagement;
using EcomServices = Dynamicweb.Ecommerce.Services;

namespace Packs.ReorderingPricing;

[AddInName("Reordering Pricing Qty Break Price Provider")]
[AddInDescription("Applies EcomPrices quantity-tier rows (Quantity > 1) for line quantities at cart time. Returns null for base/contract lookups so the default provider owns those (non-exclusive composition).")]
[AddInActive(true)]
[AddInUseParameterSectioning(true)]
public sealed class ReorderingPricingQtyBreakProvider : PriceProvider
{
    // Q5: never own pricing shop-wide. Non-null returns are tier-only; everything else
    // falls through to DefaultPriceProvider.
    public override bool HandlePricesExclusively => false;

    public override PriceRaw? FindPrice(PriceContext context, PriceProductSelection selection)
    {
        return FindBestTierPrice(context, selection, isInformative: false);
    }

    public override PriceRaw? FindInformativePrice(PriceContext context, PriceProductSelection selection)
    {
        return FindBestTierPrice(context, selection, isInformative: true);
    }

    // Tier schedule for display surfaces (delta 2): every scope-matched tier row
    // (Quantity > 1) for the product, ascending by quantity threshold.
    public override System.Collections.Generic.IEnumerable<System.Collections.Generic.KeyValuePair<PriceQuantityInfo, PriceRaw>> FindQuantityPrices(PriceContext context, Product product)
    {
        var result = new System.Collections.Generic.List<System.Collections.Generic.KeyValuePair<PriceQuantityInfo, PriceRaw>>();
        try
        {
            if (product == null || string.IsNullOrEmpty(product.Id)) return result;

            var prices = EcomServices.Prices.GetByProductId(product.Id);
            if (prices == null) return result;

            var userGroupIds = ResolveUserGroupIds(context.Customer);
            var userId = context.Customer?.ID.ToString() ?? string.Empty;
            var customerNumber = context.Customer?.CustomerNumber ?? string.Empty;
            var currencyCode = context.Currency?.Code ?? string.Empty;
            var countryCode = context.Country?.Code2 ?? string.Empty;
            var shopId = context.Shop?.Id ?? string.Empty;
            var variantId = product.VariantId ?? string.Empty;
            var languageId = product.LanguageId ?? string.Empty;
            var now = context.Time ?? System.DateTime.Now;

            var tiers = new System.Collections.Generic.List<Price>();
            foreach (var p in prices)
            {
                if (p == null) continue;
                if (p.Quantity <= 1) continue; // schedule = actual tiers only
                if (!ScopeMatches(p, currencyCode, countryCode, shopId, variantId, p.UnitId ?? string.Empty, userId, customerNumber, userGroupIds, languageId, now)) continue;
                tiers.Add(p);
            }
            tiers.Sort((a, b) => a.Quantity.CompareTo(b.Quantity));

            foreach (var tier in tiers)
            {
                var info = new PriceQuantityInfo
                {
                    Quantity = tier.Quantity,
                    UnitId = tier.UnitId ?? string.Empty
                };
                var raw = new PriceRaw(tier.Amount, context.Currency)
                {
                    DiscountPercentage = tier.DiscountPercentage,
                    AllowOrderDiscounts = tier.AllowOrderDiscounts,
                    AllowOrderLineDiscounts = tier.AllowOrderLineDiscounts
                };
                result.Add(new System.Collections.Generic.KeyValuePair<PriceQuantityInfo, PriceRaw>(info, raw));
            }
        }
        catch
        {
            // Never throw from a price provider — an empty schedule degrades display only.
        }
        return result;
    }

    private static PriceRaw? FindBestTierPrice(PriceContext context, PriceProductSelection selection, bool isInformative)
    {
        try
        {
            if (string.IsNullOrEmpty(selection.ProductId)) return null;

            var prices = EcomServices.Prices.GetByProductId(selection.ProductId);
            if (prices == null) return null;

            var userGroupIds = ResolveUserGroupIds(context.Customer);
            var userId = context.Customer?.ID.ToString() ?? string.Empty;
            var customerNumber = context.Customer?.CustomerNumber ?? string.Empty;
            var currencyCode = context.Currency?.Code ?? string.Empty;
            var countryCode = context.Country?.Code2 ?? string.Empty;
            var shopId = context.Shop?.Id ?? string.Empty;
            var variantId = selection.VariantId ?? string.Empty;
            var unitId = selection.UnitId ?? string.Empty;
            var languageId = selection.LanguageId ?? string.Empty;
            var now = context.Time ?? System.DateTime.Now;

            var quantity = selection.Quantity > 0 ? selection.Quantity : 1d;

            Price? best = null;
            int bestSpecificity = -1;

            foreach (var p in prices)
            {
                if (p == null) continue;
                if (!isInformative && p.IsInformative) continue;
                if (p.Quantity > quantity) continue;
                if (!ScopeMatches(p, currencyCode, countryCode, shopId, variantId, unitId, userId, customerNumber, userGroupIds, languageId, now)) continue;

                int specificity = ComputeSpecificity(p);

                if (best == null
                    || p.Quantity > best.Quantity
                    || (p.Quantity == best.Quantity && (specificity > bestSpecificity || (specificity == bestSpecificity && p.Amount < best.Amount))))
                {
                    best = p;
                    bestSpecificity = specificity;
                }
            }

            // Q5 delta 1: only an actual quantity tier is ours. When the best match is a
            // base or contract row (Quantity 0/1), return null — DefaultPriceProvider owns
            // stock resolution for those and contract scoping keeps working untouched.
            if (best == null || best.Quantity <= 1) return null;

            var raw = new PriceRaw(best.Amount, context.Currency)
            {
                DiscountPercentage = best.DiscountPercentage,
                AllowOrderDiscounts = best.AllowOrderDiscounts,
                AllowOrderLineDiscounts = best.AllowOrderLineDiscounts
            };
            return raw;
        }
        catch
        {
            // Never throw from a price provider — null falls through to the default provider.
            return null;
        }
    }

    private static bool ScopeMatches(Price p, string currencyCode, string countryCode, string shopId, string variantId, string unitId, string userId, string customerNumber, System.Collections.Generic.HashSet<string> userGroupIds, string languageId, System.DateTime now)
    {
        if (!string.IsNullOrEmpty(p.CurrencyCode) && !string.Equals(p.CurrencyCode, currencyCode, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.CountryCode) && !string.Equals(p.CountryCode, countryCode, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.ShopId) && !string.Equals(p.ShopId, shopId, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.VariantId) && !string.Equals(p.VariantId, variantId, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.UnitId) && !string.Equals(p.UnitId, unitId, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.UserId) && !string.Equals(p.UserId, userId, System.StringComparison.OrdinalIgnoreCase)) return false;
        // WR-01 (Phase 7 review): a tier row scoped by PriceUserCustomerNumber —
        // the exact scoping column this pack's contract row uses — must NEVER be
        // treated as unscoped: that would grant the (typically discounted) price
        // to EVERY shopper. Same for the product language scope
        // (PriceProductLanguageId -> Price.LanguageId).
        if (!string.IsNullOrEmpty(p.UserCustomerNumber) && !string.Equals(p.UserCustomerNumber, customerNumber, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.LanguageId) && !string.Equals(p.LanguageId, languageId, System.StringComparison.OrdinalIgnoreCase)) return false;
        if (!string.IsNullOrEmpty(p.UserGroupId) && !userGroupIds.Contains(p.UserGroupId)) return false;
        if (p.ValidFrom.HasValue && p.ValidFrom.Value > now) return false;
        if (p.ValidTo.HasValue && p.ValidTo.Value < now) return false;
        return true;
    }

    private static int ComputeSpecificity(Price p)
    {
        int score = 0;
        if (!string.IsNullOrEmpty(p.UserId)) score += 64;
        if (!string.IsNullOrEmpty(p.UserGroupId)) score += 32;
        if (!string.IsNullOrEmpty(p.VariantId)) score += 16;
        if (!string.IsNullOrEmpty(p.UnitId)) score += 8;
        if (!string.IsNullOrEmpty(p.ShopId)) score += 4;
        if (!string.IsNullOrEmpty(p.CountryCode)) score += 2;
        if (!string.IsNullOrEmpty(p.CurrencyCode)) score += 1;
        return score;
    }

    // Error-swallowing group resolution (cabp lines 104-118): never throw, degrade to
    // an empty set — an unmatched group scope then simply fails ScopeMatches.
    private static System.Collections.Generic.HashSet<string> ResolveUserGroupIds(User? customer)
    {
        var ids = new System.Collections.Generic.HashSet<string>(System.StringComparer.OrdinalIgnoreCase);
        if (customer == null) return ids;
        try
        {
            foreach (var g in customer.GetGroups())
            {
                if (g == null) continue;
                ids.Add(g.ID.ToString());
            }
        }
        catch { }
        return ids;
    }
}
