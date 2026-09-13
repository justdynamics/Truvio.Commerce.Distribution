-- ===========================================================================
-- truvio-demo layer - the Truvio Commerce brand catalogue (V5-PLAN 2.4, D-B/D-D)
-- ===========================================================================
-- WHAT THIS IS
-- The brand-data catalogue for the fictional TRUVIO COMMERCE demo. It is a
-- SECOND sample-data layer alongside `sample-data`: that layer keeps the gate's
-- marker-string fixtures (FIXT* / PACK-*) and this one carries the catalogue a
-- prospect actually sees. The two never touch the same row - every key here is
-- TC*-prefixed and disjoint from FIXT* / FIXTGRP* / FIXT-PRICE-* / PACK-*.
--
-- THE NAMING RULE (owner decision D-B, binding)
-- No real-world product domain appears anywhere. Every group, product, field,
-- axis and option is named from PIM / Commerce / CMS vocabulary, so the
-- catalogue doubles as a platform-terminology tour and can never be mistaken
-- for a real business. `Size` and `Finish` are worldly and are deliberately NOT
-- the variant axes; `Tier` and `Mode` are.
--
-- THE FRONTEND FILTER (owner mandate, round two, 2026-09-13, binding)
-- An example ships only if SWIFT SHOWS IT. A quantity price renders on the page,
-- so it belongs; a PIM workflow is backend-only, so it does not. The twelve
-- subgroups below each name a thing the storefront draws - see section 0, which
-- also converges a host seeded under the retired taxonomy.
--
-- CONTENTS (deterministic)
--   4 top groups x 3 subgroups = 16 EcomGroups rows; the 4 top groups bind to
--     SHOP1, the 12 subgroups hang off them via EcomGroupRelations (the menu
--     needs depth two, and a subgroup reached only through the menu still needs
--     a parent relation - see Ensure-NavDepth in the harness).
--   60 masters TCPROD0001..TCPROD0060, 5 per subgroup, SKU TC-<CONCEPT>-<nnnn>
--     where <nnnn> is the same running number as the name suffix.
--   2 variant axes (Tier: Standard/Advanced/Enterprise; Mode: Draft/Published)
--     on 6 masters => 36 variant rows, each with its OWN EcomPrices row (a
--     variant with no price row inherits the master's and the tier reads as free).
--   1 BOM kit (TCPROD0021) with 2 slots, 2 services (ProductType 1),
--     a 3-step quantity-tier ladder on TCPROD0006, and one contract price on
--     TCPROD0002 scoped to customer number TC-100200 (truvio-identities.sql).
--   4 product categories (one per top group) x 7 category fields = 28 fields,
--     with 3 populated values per master here and the remaining 4 added by
--     truvio-pdp.sql, which takes the spec table to seven of seven. Every field
--     is now something a BUYER reads - a dimension in the platform's own unit
--     vocabulary, a material class, a rating, a compatibility note, a commercial
--     term. The Completeness Score that rendered as a shopper-facing spec row,
--     and every other backend concept beside it, is gone.
--
-- TRAPS THIS FILE OBEYS (each one cost a gate run once)
--   LANGUAGE ROW: every catalogue row is ENU, never LANG1. LANG1 is the latent
--     second en-US row retained only for reference_category and one legacy
--     sample order; catalogue rows written under it are invisible on the
--     storefront (RUN-SWIFT-MULTILANGUAGE).
--   PRIMARY PAGE = 0: no group here sets a primary page id. Swift's
--     ProductDetailRenderGrid prefers a group's PrimaryPageId over the detail
--     page, and a value aimed at the shop/PLP page makes the catalogue app
--     re-render that page inside itself - the recursion guard then EMPTIES every
--     PDP in the shop, with no error anywhere (Foundry #186). The base ships
--     ShopProductPrimaryPageId = 0 on SHOP1 for the same reason; leave both at 0.
--   EMPTY GROUPS (#177): navigation visibility and URL reachability are separate
--     surfaces, so an empty group still serves a live 200 PLP saying 0 products.
--     Every group here - top groups included - therefore carries products: a
--     master's PRIMARY relation is its subgroup and it carries a second,
--     non-primary relation to its top group (15 products per top group).
--   GROUP-RELATION CACHE (#29): the group-product relation cache is held
--     in-process, so these raw inserts are invisible until the host restarts.
--     layer.json declares requiresHostRestart: true for exactly this reason.
--
-- Apply AFTER the base replace-deserialize (this FKs EcomShops SHOP1 and
-- EcomCurrencies EUR) and after sample-data's own scripts, then restart the host.
-- Idempotent: every insert is IF NOT EXISTS-guarded on its own key, so a re-run
-- converges instead of duplicating or deleting.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

-- ---------------------------------------------------------------------------
-- 0. THE RE-SCREEN (round two, 2026-09-13). Converging, and it runs FIRST.
--    The owner's filter is binding: an example ships only if Swift SHOWS it.
--    Eight subgroups named a backend concept with no storefront surface -
--    Workflows, Completeness, Permissions, Impersonation, Item Types, Pages,
--    Paragraphs and Groups - and every one is replaced by vocabulary a Swift
--    page actually renders. The naming rule (D-B) is unchanged: each new name
--    is still PIM / Commerce / CMS terminology, never a real product domain.
--
--    THE TWELVE, and what shows them:
--      Data Models  Variants (variant selector) | Units & Measures (unit
--                   selector on add-to-cart) | Bundles & BOM (package contents)
--      Commerce     Price Structures (price table) | Discounts (price before
--                   discount) | Stock & Delivery (stock count and status)
--      Content      Documents (documents table) | Media & Galleries (gallery
--                   and thumbnails) | Relations (related-products strip)
--      Users        Assortments (which rows a persona sees) | Contract Pricing
--                   (your price versus list) | Currencies & VAT (the figure)
--
--    A host seeded by 1.1.x carries the old ids, so this block RENAMES rather
--    than inserting a second taxonomy beside the first. It runs before section
--    1, so the IF NOT EXISTS inserts below see converged rows and skip. On a
--    fresh database every statement here matches nothing and the inserts do the
--    work - which is what keeps this one script rather than two.
--
--    GroupId is the key every relation carries, so a rename is five tables:
--    EcomGroups, EcomShopGroupRelation, EcomGroupRelations (both columns),
--    EcomGroupProductRelation, and EcomProductItems, whose BOM slot binds a
--    group. Guarded on the old id existing AND the new one not, so a half-run
--    never merges two taxonomies into one group.
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-COMPLETENESS') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-STOCK-DELIVERY')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-STOCK-DELIVERY', GroupNumber = 'TCGRP-STOCK-DELIVERY' WHERE GroupId = 'TCGRP-COMPLETENESS';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-STOCK-DELIVERY' WHERE ShopGroupGroupId = 'TCGRP-COMPLETENESS';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-STOCK-DELIVERY' WHERE GroupRelationsGroupId = 'TCGRP-COMPLETENESS';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-STOCK-DELIVERY' WHERE GroupRelationsParentId = 'TCGRP-COMPLETENESS';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-STOCK-DELIVERY' WHERE GroupProductRelationGroupId = 'TCGRP-COMPLETENESS';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-STOCK-DELIVERY' WHERE ProductItemBomGroupId = 'TCGRP-COMPLETENESS';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-GROUPS') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CONTRACT-PRICING')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-CONTRACT-PRICING', GroupNumber = 'TCGRP-CONTRACT-PRICING' WHERE GroupId = 'TCGRP-GROUPS';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-CONTRACT-PRICING' WHERE ShopGroupGroupId = 'TCGRP-GROUPS';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-CONTRACT-PRICING' WHERE GroupRelationsGroupId = 'TCGRP-GROUPS';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-CONTRACT-PRICING' WHERE GroupRelationsParentId = 'TCGRP-GROUPS';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTRACT-PRICING' WHERE GroupProductRelationGroupId = 'TCGRP-GROUPS';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-CONTRACT-PRICING' WHERE ProductItemBomGroupId = 'TCGRP-GROUPS';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-IMPERSONATION') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-RELATIONS')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-RELATIONS', GroupNumber = 'TCGRP-RELATIONS' WHERE GroupId = 'TCGRP-IMPERSONATION';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-RELATIONS' WHERE ShopGroupGroupId = 'TCGRP-IMPERSONATION';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-RELATIONS' WHERE GroupRelationsGroupId = 'TCGRP-IMPERSONATION';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-RELATIONS' WHERE GroupRelationsParentId = 'TCGRP-IMPERSONATION';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-RELATIONS' WHERE GroupProductRelationGroupId = 'TCGRP-IMPERSONATION';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-RELATIONS' WHERE ProductItemBomGroupId = 'TCGRP-IMPERSONATION';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-ITEM-TYPES') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-BUNDLES')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-BUNDLES', GroupNumber = 'TCGRP-BUNDLES' WHERE GroupId = 'TCGRP-ITEM-TYPES';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-BUNDLES' WHERE ShopGroupGroupId = 'TCGRP-ITEM-TYPES';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-BUNDLES' WHERE GroupRelationsGroupId = 'TCGRP-ITEM-TYPES';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-BUNDLES' WHERE GroupRelationsParentId = 'TCGRP-ITEM-TYPES';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-BUNDLES' WHERE GroupProductRelationGroupId = 'TCGRP-ITEM-TYPES';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-BUNDLES' WHERE ProductItemBomGroupId = 'TCGRP-ITEM-TYPES';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PAGES') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-MEDIA')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-MEDIA', GroupNumber = 'TCGRP-MEDIA' WHERE GroupId = 'TCGRP-PAGES';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-MEDIA' WHERE ShopGroupGroupId = 'TCGRP-PAGES';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-MEDIA' WHERE GroupRelationsGroupId = 'TCGRP-PAGES';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-MEDIA' WHERE GroupRelationsParentId = 'TCGRP-PAGES';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-MEDIA' WHERE GroupProductRelationGroupId = 'TCGRP-PAGES';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-MEDIA' WHERE ProductItemBomGroupId = 'TCGRP-PAGES';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PARAGRAPHS') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CURRENCIES')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-CURRENCIES', GroupNumber = 'TCGRP-CURRENCIES' WHERE GroupId = 'TCGRP-PARAGRAPHS';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-CURRENCIES' WHERE ShopGroupGroupId = 'TCGRP-PARAGRAPHS';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-CURRENCIES' WHERE GroupRelationsGroupId = 'TCGRP-PARAGRAPHS';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-CURRENCIES' WHERE GroupRelationsParentId = 'TCGRP-PARAGRAPHS';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CURRENCIES' WHERE GroupProductRelationGroupId = 'TCGRP-PARAGRAPHS';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-CURRENCIES' WHERE ProductItemBomGroupId = 'TCGRP-PARAGRAPHS';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PERMISSIONS') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DOCUMENTS')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-DOCUMENTS', GroupNumber = 'TCGRP-DOCUMENTS' WHERE GroupId = 'TCGRP-PERMISSIONS';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-DOCUMENTS' WHERE ShopGroupGroupId = 'TCGRP-PERMISSIONS';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-DOCUMENTS' WHERE GroupRelationsGroupId = 'TCGRP-PERMISSIONS';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-DOCUMENTS' WHERE GroupRelationsParentId = 'TCGRP-PERMISSIONS';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-DOCUMENTS' WHERE GroupProductRelationGroupId = 'TCGRP-PERMISSIONS';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-DOCUMENTS' WHERE ProductItemBomGroupId = 'TCGRP-PERMISSIONS';
END;
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-WORKFLOWS') AND NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-UNITS')
BEGIN
    UPDATE EcomGroups SET GroupId = 'TCGRP-UNITS', GroupNumber = 'TCGRP-UNITS' WHERE GroupId = 'TCGRP-WORKFLOWS';
    UPDATE EcomShopGroupRelation SET ShopGroupGroupId = 'TCGRP-UNITS' WHERE ShopGroupGroupId = 'TCGRP-WORKFLOWS';
    UPDATE EcomGroupRelations SET GroupRelationsGroupId = 'TCGRP-UNITS' WHERE GroupRelationsGroupId = 'TCGRP-WORKFLOWS';
    UPDATE EcomGroupRelations SET GroupRelationsParentId = 'TCGRP-UNITS' WHERE GroupRelationsParentId = 'TCGRP-WORKFLOWS';
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-UNITS' WHERE GroupProductRelationGroupId = 'TCGRP-WORKFLOWS';
    IF COL_LENGTH('EcomProductItems', 'ProductItemBomGroupId') IS NOT NULL
        UPDATE EcomProductItems SET ProductItemBomGroupId = 'TCGRP-UNITS' WHERE ProductItemBomGroupId = 'TCGRP-WORKFLOWS';
END;

-- The display names, always: a host already carrying the new id still takes the
-- current label, so a wording change converges without a second rename.
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-ASSORTMENTS' AND GroupName <> N'Assortments')
    UPDATE EcomGroups SET GroupName = N'Assortments' WHERE GroupId = 'TCGRP-ASSORTMENTS';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-STOCK-DELIVERY' AND GroupName <> N'Stock & Delivery')
    UPDATE EcomGroups SET GroupName = N'Stock & Delivery' WHERE GroupId = 'TCGRP-STOCK-DELIVERY';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DISCOUNTS' AND GroupName <> N'Discounts')
    UPDATE EcomGroups SET GroupName = N'Discounts' WHERE GroupId = 'TCGRP-DISCOUNTS';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CONTRACT-PRICING' AND GroupName <> N'Contract Pricing')
    UPDATE EcomGroups SET GroupName = N'Contract Pricing' WHERE GroupId = 'TCGRP-CONTRACT-PRICING';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-RELATIONS' AND GroupName <> N'Relations')
    UPDATE EcomGroups SET GroupName = N'Relations' WHERE GroupId = 'TCGRP-RELATIONS';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-BUNDLES' AND GroupName <> N'Bundles & BOM')
    UPDATE EcomGroups SET GroupName = N'Bundles & BOM' WHERE GroupId = 'TCGRP-BUNDLES';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-MEDIA' AND GroupName <> N'Media & Galleries')
    UPDATE EcomGroups SET GroupName = N'Media & Galleries' WHERE GroupId = 'TCGRP-MEDIA';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CURRENCIES' AND GroupName <> N'Currencies & VAT')
    UPDATE EcomGroups SET GroupName = N'Currencies & VAT' WHERE GroupId = 'TCGRP-CURRENCIES';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DOCUMENTS' AND GroupName <> N'Documents')
    UPDATE EcomGroups SET GroupName = N'Documents' WHERE GroupId = 'TCGRP-DOCUMENTS';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupName <> N'Price Structures')
    UPDATE EcomGroups SET GroupName = N'Price Structures' WHERE GroupId = 'TCGRP-PRICE-STRUCTURES';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-VARIANTS' AND GroupName <> N'Variants')
    UPDATE EcomGroups SET GroupName = N'Variants' WHERE GroupId = 'TCGRP-VARIANTS';
IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-UNITS' AND GroupName <> N'Units & Measures')
    UPDATE EcomGroups SET GroupName = N'Units & Measures' WHERE GroupId = 'TCGRP-UNITS';

-- Re-homing. Six bands change top group so each of the four tops keeps 15
-- products and every child reads sensibly under its parent. Two rows say where a
-- band lives and BOTH have to move or the menu and the counts disagree: the
-- subgroup's own parent relation, and each product's secondary top-group
-- relation. The PRIMARY product relation is the subgroup and never moves, so the
-- EMPTY GROUPS rule holds throughout.
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-ASSORTMENTS' AND GroupRelationsParentId <> 'TCGRP-USERS')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-ASSORTMENTS';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-ASSORTMENTS', 'TCGRP-USERS', 1, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-ASSORTMENTS' AND GroupRelationsParentId = 'TCGRP-USERS' AND GroupRelationsSorting <> 1)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 1 WHERE GroupRelationsGroupId = 'TCGRP-ASSORTMENTS' AND GroupRelationsParentId = 'TCGRP-USERS';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupRelationsParentId <> 'TCGRP-COMMERCE')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-STOCK-DELIVERY';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-STOCK-DELIVERY', 'TCGRP-COMMERCE', 3, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupRelationsParentId = 'TCGRP-COMMERCE' AND GroupRelationsSorting <> 3)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 3 WHERE GroupRelationsGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupRelationsParentId = 'TCGRP-COMMERCE';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DISCOUNTS' AND GroupRelationsParentId <> 'TCGRP-COMMERCE')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DISCOUNTS';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-DISCOUNTS', 'TCGRP-COMMERCE', 2, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DISCOUNTS' AND GroupRelationsParentId = 'TCGRP-COMMERCE' AND GroupRelationsSorting <> 2)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 2 WHERE GroupRelationsGroupId = 'TCGRP-DISCOUNTS' AND GroupRelationsParentId = 'TCGRP-COMMERCE';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupRelationsParentId <> 'TCGRP-USERS')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CONTRACT-PRICING';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-CONTRACT-PRICING', 'TCGRP-USERS', 3, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupRelationsParentId = 'TCGRP-USERS' AND GroupRelationsSorting <> 3)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 3 WHERE GroupRelationsGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupRelationsParentId = 'TCGRP-USERS';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-RELATIONS' AND GroupRelationsParentId <> 'TCGRP-CONTENT')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-RELATIONS';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-RELATIONS', 'TCGRP-CONTENT', 3, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-RELATIONS' AND GroupRelationsParentId = 'TCGRP-CONTENT' AND GroupRelationsSorting <> 3)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 3 WHERE GroupRelationsGroupId = 'TCGRP-RELATIONS' AND GroupRelationsParentId = 'TCGRP-CONTENT';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-BUNDLES' AND GroupRelationsParentId <> 'TCGRP-DATA-MODELS')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-BUNDLES';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-BUNDLES', 'TCGRP-DATA-MODELS', 3, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-BUNDLES' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS' AND GroupRelationsSorting <> 3)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 3 WHERE GroupRelationsGroupId = 'TCGRP-BUNDLES' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-MEDIA' AND GroupRelationsParentId <> 'TCGRP-CONTENT')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-MEDIA';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-MEDIA', 'TCGRP-CONTENT', 2, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-MEDIA' AND GroupRelationsParentId = 'TCGRP-CONTENT' AND GroupRelationsSorting <> 2)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 2 WHERE GroupRelationsGroupId = 'TCGRP-MEDIA' AND GroupRelationsParentId = 'TCGRP-CONTENT';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CURRENCIES' AND GroupRelationsParentId <> 'TCGRP-USERS')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CURRENCIES';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-CURRENCIES', 'TCGRP-USERS', 2, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CURRENCIES' AND GroupRelationsParentId = 'TCGRP-USERS' AND GroupRelationsSorting <> 2)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 2 WHERE GroupRelationsGroupId = 'TCGRP-CURRENCIES' AND GroupRelationsParentId = 'TCGRP-USERS';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DOCUMENTS' AND GroupRelationsParentId <> 'TCGRP-CONTENT')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DOCUMENTS';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-DOCUMENTS', 'TCGRP-CONTENT', 1, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DOCUMENTS' AND GroupRelationsParentId = 'TCGRP-CONTENT' AND GroupRelationsSorting <> 1)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 1 WHERE GroupRelationsGroupId = 'TCGRP-DOCUMENTS' AND GroupRelationsParentId = 'TCGRP-CONTENT';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupRelationsParentId <> 'TCGRP-COMMERCE')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PRICE-STRUCTURES';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCGRP-COMMERCE', 1, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupRelationsParentId = 'TCGRP-COMMERCE' AND GroupRelationsSorting <> 1)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 1 WHERE GroupRelationsGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupRelationsParentId = 'TCGRP-COMMERCE';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-VARIANTS' AND GroupRelationsParentId <> 'TCGRP-DATA-MODELS')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-VARIANTS';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-VARIANTS', 'TCGRP-DATA-MODELS', 1, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-VARIANTS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS' AND GroupRelationsSorting <> 1)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 1 WHERE GroupRelationsGroupId = 'TCGRP-VARIANTS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS';
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-UNITS' AND GroupRelationsParentId <> 'TCGRP-DATA-MODELS')
BEGIN
    DELETE FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-UNITS';
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-UNITS', 'TCGRP-DATA-MODELS', 2, 1, 0);
END;
IF EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-UNITS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS' AND GroupRelationsSorting <> 2)
    UPDATE EcomGroupRelations SET GroupRelationsSorting = 2 WHERE GroupRelationsGroupId = 'TCGRP-UNITS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS';

IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0006') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0006')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-COMMERCE' WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0006';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0007') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0007')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-COMMERCE' WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0007';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0008') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0008')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-COMMERCE' WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0008';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0009') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0009')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-COMMERCE' WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0009';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0010') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0010')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-COMMERCE' WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0010';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0021') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0021')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0021';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0022') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0022')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0022';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0023') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0023')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0023';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0024') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0024')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0024';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0025') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0025')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0025';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0036') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0036')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0036';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0037') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0037')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0037';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0038') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0038')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0038';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0039') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0039')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0039';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0040') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0040')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-USERS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0040';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0041') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0041')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0041';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0042') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0042')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0042';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0043') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0043')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0043';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0044') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0044')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0044';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0045') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0045')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0045';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0051') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0051')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0051';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0052') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0052')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0052';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0053') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0053')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0053';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0054') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0054')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0054';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0055') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0055')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0055';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0056') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0056')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0056';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0057') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0057')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0057';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0058') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0058')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0058';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0059') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0059')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0059';
IF EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0060') AND NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0060')
    UPDATE EcomGroupProductRelation SET GroupProductRelationGroupId = 'TCGRP-CONTENT' WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0060';

-- Numbers and names follow the concept. A SKU still reading TC-IMP- names a
-- thing the storefront cannot show, so the token moves with the group.
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND (ProductNumber <> 'TC-VAR-0001' OR ProductName <> N'Truvio Variant Master 01'))
    UPDATE EcomProducts SET ProductNumber = 'TC-VAR-0001', ProductName = N'Truvio Variant Master 01' WHERE ProductId = 'TCPROD0001';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0002' AND (ProductNumber <> 'TC-VAR-0002' OR ProductName <> N'Truvio Variant Master 02'))
    UPDATE EcomProducts SET ProductNumber = 'TC-VAR-0002', ProductName = N'Truvio Variant Master 02' WHERE ProductId = 'TCPROD0002';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0003' AND (ProductNumber <> 'TC-VAR-0003' OR ProductName <> N'Truvio Variant Master 03'))
    UPDATE EcomProducts SET ProductNumber = 'TC-VAR-0003', ProductName = N'Truvio Variant Master 03' WHERE ProductId = 'TCPROD0003';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0004' AND (ProductNumber <> 'TC-VAR-0004' OR ProductName <> N'Truvio Variant Master 04'))
    UPDATE EcomProducts SET ProductNumber = 'TC-VAR-0004', ProductName = N'Truvio Variant Master 04' WHERE ProductId = 'TCPROD0004';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0005' AND (ProductNumber <> 'TC-VAR-0005' OR ProductName <> N'Truvio Variant Master 05'))
    UPDATE EcomProducts SET ProductNumber = 'TC-VAR-0005', ProductName = N'Truvio Variant Master 05' WHERE ProductId = 'TCPROD0005';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0006' AND (ProductNumber <> 'TC-STK-0006' OR ProductName <> N'Truvio Stock Item 06'))
    UPDATE EcomProducts SET ProductNumber = 'TC-STK-0006', ProductName = N'Truvio Stock Item 06' WHERE ProductId = 'TCPROD0006';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0007' AND (ProductNumber <> 'TC-STK-0007' OR ProductName <> N'Truvio Stock Item 07'))
    UPDATE EcomProducts SET ProductNumber = 'TC-STK-0007', ProductName = N'Truvio Stock Item 07' WHERE ProductId = 'TCPROD0007';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0008' AND (ProductNumber <> 'TC-STK-0008' OR ProductName <> N'Truvio Stock Item 08'))
    UPDATE EcomProducts SET ProductNumber = 'TC-STK-0008', ProductName = N'Truvio Stock Item 08' WHERE ProductId = 'TCPROD0008';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0009' AND (ProductNumber <> 'TC-STK-0009' OR ProductName <> N'Truvio Stock Item 09'))
    UPDATE EcomProducts SET ProductNumber = 'TC-STK-0009', ProductName = N'Truvio Stock Item 09' WHERE ProductId = 'TCPROD0009';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0010' AND (ProductNumber <> 'TC-STK-0010' OR ProductName <> N'Truvio Stock Item 10'))
    UPDATE EcomProducts SET ProductNumber = 'TC-STK-0010', ProductName = N'Truvio Stock Item 10' WHERE ProductId = 'TCPROD0010';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND (ProductNumber <> 'TC-UOM-0011' OR ProductName <> N'Truvio Unit Measure 11'))
    UPDATE EcomProducts SET ProductNumber = 'TC-UOM-0011', ProductName = N'Truvio Unit Measure 11' WHERE ProductId = 'TCPROD0011';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0012' AND (ProductNumber <> 'TC-UOM-0012' OR ProductName <> N'Truvio Unit Measure 12'))
    UPDATE EcomProducts SET ProductNumber = 'TC-UOM-0012', ProductName = N'Truvio Unit Measure 12' WHERE ProductId = 'TCPROD0012';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0013' AND (ProductNumber <> 'TC-UOM-0013' OR ProductName <> N'Truvio Unit Conversion Service 13'))
    UPDATE EcomProducts SET ProductNumber = 'TC-UOM-0013', ProductName = N'Truvio Unit Conversion Service 13' WHERE ProductId = 'TCPROD0013';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0014' AND (ProductNumber <> 'TC-UOM-0014' OR ProductName <> N'Truvio Unit Measure 14'))
    UPDATE EcomProducts SET ProductNumber = 'TC-UOM-0014', ProductName = N'Truvio Unit Measure 14' WHERE ProductId = 'TCPROD0014';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0015' AND (ProductNumber <> 'TC-UOM-0015' OR ProductName <> N'Truvio Unit Measure 15'))
    UPDATE EcomProducts SET ProductNumber = 'TC-UOM-0015', ProductName = N'Truvio Unit Measure 15' WHERE ProductId = 'TCPROD0015';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND (ProductNumber <> 'TC-PRC-0016' OR ProductName <> N'Truvio Price Matrix 16'))
    UPDATE EcomProducts SET ProductNumber = 'TC-PRC-0016', ProductName = N'Truvio Price Matrix 16' WHERE ProductId = 'TCPROD0016';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND (ProductNumber <> 'TC-PRC-0017' OR ProductName <> N'Truvio Price Matrix 17'))
    UPDATE EcomProducts SET ProductNumber = 'TC-PRC-0017', ProductName = N'Truvio Price Matrix 17' WHERE ProductId = 'TCPROD0017';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND (ProductNumber <> 'TC-PRC-0018' OR ProductName <> N'Truvio Price Matrix 18'))
    UPDATE EcomProducts SET ProductNumber = 'TC-PRC-0018', ProductName = N'Truvio Price Matrix 18' WHERE ProductId = 'TCPROD0018';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND (ProductNumber <> 'TC-PRC-0019' OR ProductName <> N'Truvio Price Matrix 19'))
    UPDATE EcomProducts SET ProductNumber = 'TC-PRC-0019', ProductName = N'Truvio Price Matrix 19' WHERE ProductId = 'TCPROD0019';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND (ProductNumber <> 'TC-PRC-0020' OR ProductName <> N'Truvio Price Matrix 20'))
    UPDATE EcomProducts SET ProductNumber = 'TC-PRC-0020', ProductName = N'Truvio Price Matrix 20' WHERE ProductId = 'TCPROD0020';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0021' AND (ProductNumber <> 'TC-ASM-0021' OR ProductName <> N'Truvio Assortment Kit 21'))
    UPDATE EcomProducts SET ProductNumber = 'TC-ASM-0021', ProductName = N'Truvio Assortment Kit 21' WHERE ProductId = 'TCPROD0021';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0022' AND (ProductNumber <> 'TC-ASM-0022' OR ProductName <> N'Truvio Assortment Scope 22'))
    UPDATE EcomProducts SET ProductNumber = 'TC-ASM-0022', ProductName = N'Truvio Assortment Scope 22' WHERE ProductId = 'TCPROD0022';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0023' AND (ProductNumber <> 'TC-ASM-0023' OR ProductName <> N'Truvio Assortment Scope 23'))
    UPDATE EcomProducts SET ProductNumber = 'TC-ASM-0023', ProductName = N'Truvio Assortment Scope 23' WHERE ProductId = 'TCPROD0023';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0024' AND (ProductNumber <> 'TC-ASM-0024' OR ProductName <> N'Truvio Assortment Scope 24'))
    UPDATE EcomProducts SET ProductNumber = 'TC-ASM-0024', ProductName = N'Truvio Assortment Scope 24' WHERE ProductId = 'TCPROD0024';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0025' AND (ProductNumber <> 'TC-ASM-0025' OR ProductName <> N'Truvio Assortment Scope 25'))
    UPDATE EcomProducts SET ProductNumber = 'TC-ASM-0025', ProductName = N'Truvio Assortment Scope 25' WHERE ProductId = 'TCPROD0025';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0026' AND (ProductNumber <> 'TC-DSC-0026' OR ProductName <> N'Truvio Discount Ladder 26'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DSC-0026', ProductName = N'Truvio Discount Ladder 26' WHERE ProductId = 'TCPROD0026';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0027' AND (ProductNumber <> 'TC-DSC-0027' OR ProductName <> N'Truvio Discount Ladder 27'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DSC-0027', ProductName = N'Truvio Discount Ladder 27' WHERE ProductId = 'TCPROD0027';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0028' AND (ProductNumber <> 'TC-DSC-0028' OR ProductName <> N'Truvio Discount Ladder 28'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DSC-0028', ProductName = N'Truvio Discount Ladder 28' WHERE ProductId = 'TCPROD0028';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0029' AND (ProductNumber <> 'TC-DSC-0029' OR ProductName <> N'Truvio Discount Ladder 29'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DSC-0029', ProductName = N'Truvio Discount Ladder 29' WHERE ProductId = 'TCPROD0029';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0030' AND (ProductNumber <> 'TC-DSC-0030' OR ProductName <> N'Truvio Discount Ladder 30'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DSC-0030', ProductName = N'Truvio Discount Ladder 30' WHERE ProductId = 'TCPROD0030';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND (ProductNumber <> 'TC-MED-0031' OR ProductName <> N'Truvio Media Set 31'))
    UPDATE EcomProducts SET ProductNumber = 'TC-MED-0031', ProductName = N'Truvio Media Set 31' WHERE ProductId = 'TCPROD0031';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0032' AND (ProductNumber <> 'TC-MED-0032' OR ProductName <> N'Truvio Media Set 32'))
    UPDATE EcomProducts SET ProductNumber = 'TC-MED-0032', ProductName = N'Truvio Media Set 32' WHERE ProductId = 'TCPROD0032';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0033' AND (ProductNumber <> 'TC-MED-0033' OR ProductName <> N'Truvio Media Set 33'))
    UPDATE EcomProducts SET ProductNumber = 'TC-MED-0033', ProductName = N'Truvio Media Set 33' WHERE ProductId = 'TCPROD0033';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0034' AND (ProductNumber <> 'TC-MED-0034' OR ProductName <> N'Truvio Media Set 34'))
    UPDATE EcomProducts SET ProductNumber = 'TC-MED-0034', ProductName = N'Truvio Media Set 34' WHERE ProductId = 'TCPROD0034';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0035' AND (ProductNumber <> 'TC-MED-0035' OR ProductName <> N'Truvio Media Set 35'))
    UPDATE EcomProducts SET ProductNumber = 'TC-MED-0035', ProductName = N'Truvio Media Set 35' WHERE ProductId = 'TCPROD0035';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0036' AND (ProductNumber <> 'TC-CUR-0036' OR ProductName <> N'Truvio Currency Matrix 36'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CUR-0036', ProductName = N'Truvio Currency Matrix 36' WHERE ProductId = 'TCPROD0036';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0037' AND (ProductNumber <> 'TC-CUR-0037' OR ProductName <> N'Truvio Currency Matrix 37'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CUR-0037', ProductName = N'Truvio Currency Matrix 37' WHERE ProductId = 'TCPROD0037';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0038' AND (ProductNumber <> 'TC-CUR-0038' OR ProductName <> N'Truvio Currency Matrix 38'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CUR-0038', ProductName = N'Truvio Currency Matrix 38' WHERE ProductId = 'TCPROD0038';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0039' AND (ProductNumber <> 'TC-CUR-0039' OR ProductName <> N'Truvio Currency Matrix 39'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CUR-0039', ProductName = N'Truvio Currency Matrix 39' WHERE ProductId = 'TCPROD0039';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0040' AND (ProductNumber <> 'TC-CUR-0040' OR ProductName <> N'Truvio Currency Matrix 40'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CUR-0040', ProductName = N'Truvio Currency Matrix 40' WHERE ProductId = 'TCPROD0040';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND (ProductNumber <> 'TC-BDL-0041' OR ProductName <> N'Truvio Bundle Kit 41'))
    UPDATE EcomProducts SET ProductNumber = 'TC-BDL-0041', ProductName = N'Truvio Bundle Kit 41' WHERE ProductId = 'TCPROD0041';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND (ProductNumber <> 'TC-BDL-0042' OR ProductName <> N'Truvio Bundle Kit 42'))
    UPDATE EcomProducts SET ProductNumber = 'TC-BDL-0042', ProductName = N'Truvio Bundle Kit 42' WHERE ProductId = 'TCPROD0042';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND (ProductNumber <> 'TC-BDL-0043' OR ProductName <> N'Truvio Bundle Kit 43'))
    UPDATE EcomProducts SET ProductNumber = 'TC-BDL-0043', ProductName = N'Truvio Bundle Kit 43' WHERE ProductId = 'TCPROD0043';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND (ProductNumber <> 'TC-BDL-0044' OR ProductName <> N'Truvio Bundle Kit 44'))
    UPDATE EcomProducts SET ProductNumber = 'TC-BDL-0044', ProductName = N'Truvio Bundle Kit 44' WHERE ProductId = 'TCPROD0044';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND (ProductNumber <> 'TC-BDL-0045' OR ProductName <> N'Truvio Bundle Kit 45'))
    UPDATE EcomProducts SET ProductNumber = 'TC-BDL-0045', ProductName = N'Truvio Bundle Kit 45' WHERE ProductId = 'TCPROD0045';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND (ProductNumber <> 'TC-CTR-0046' OR ProductName <> N'Truvio Contract Price 46'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CTR-0046', ProductName = N'Truvio Contract Price 46' WHERE ProductId = 'TCPROD0046';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND (ProductNumber <> 'TC-CTR-0047' OR ProductName <> N'Truvio Contract Price 47'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CTR-0047', ProductName = N'Truvio Contract Price 47' WHERE ProductId = 'TCPROD0047';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND (ProductNumber <> 'TC-CTR-0048' OR ProductName <> N'Truvio Contract Price 48'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CTR-0048', ProductName = N'Truvio Contract Price 48' WHERE ProductId = 'TCPROD0048';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND (ProductNumber <> 'TC-CTR-0049' OR ProductName <> N'Truvio Contract Price 49'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CTR-0049', ProductName = N'Truvio Contract Price 49' WHERE ProductId = 'TCPROD0049';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND (ProductNumber <> 'TC-CTR-0050' OR ProductName <> N'Truvio Contract Price 50'))
    UPDATE EcomProducts SET ProductNumber = 'TC-CTR-0050', ProductName = N'Truvio Contract Price 50' WHERE ProductId = 'TCPROD0050';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND (ProductNumber <> 'TC-DOC-0051' OR ProductName <> N'Truvio Document Set 51'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DOC-0051', ProductName = N'Truvio Document Set 51' WHERE ProductId = 'TCPROD0051';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0052' AND (ProductNumber <> 'TC-DOC-0052' OR ProductName <> N'Truvio Document Set 52'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DOC-0052', ProductName = N'Truvio Document Set 52' WHERE ProductId = 'TCPROD0052';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0053' AND (ProductNumber <> 'TC-DOC-0053' OR ProductName <> N'Truvio Document Service 53'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DOC-0053', ProductName = N'Truvio Document Service 53' WHERE ProductId = 'TCPROD0053';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0054' AND (ProductNumber <> 'TC-DOC-0054' OR ProductName <> N'Truvio Document Set 54'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DOC-0054', ProductName = N'Truvio Document Set 54' WHERE ProductId = 'TCPROD0054';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0055' AND (ProductNumber <> 'TC-DOC-0055' OR ProductName <> N'Truvio Document Set 55'))
    UPDATE EcomProducts SET ProductNumber = 'TC-DOC-0055', ProductName = N'Truvio Document Set 55' WHERE ProductId = 'TCPROD0055';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0056' AND (ProductNumber <> 'TC-REL-0056' OR ProductName <> N'Truvio Relation Set 56'))
    UPDATE EcomProducts SET ProductNumber = 'TC-REL-0056', ProductName = N'Truvio Relation Set 56' WHERE ProductId = 'TCPROD0056';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0057' AND (ProductNumber <> 'TC-REL-0057' OR ProductName <> N'Truvio Relation Set 57'))
    UPDATE EcomProducts SET ProductNumber = 'TC-REL-0057', ProductName = N'Truvio Relation Set 57' WHERE ProductId = 'TCPROD0057';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0058' AND (ProductNumber <> 'TC-REL-0058' OR ProductName <> N'Truvio Relation Set 58'))
    UPDATE EcomProducts SET ProductNumber = 'TC-REL-0058', ProductName = N'Truvio Relation Set 58' WHERE ProductId = 'TCPROD0058';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0059' AND (ProductNumber <> 'TC-REL-0059' OR ProductName <> N'Truvio Relation Set 59'))
    UPDATE EcomProducts SET ProductNumber = 'TC-REL-0059', ProductName = N'Truvio Relation Set 59' WHERE ProductId = 'TCPROD0059';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0060' AND (ProductNumber <> 'TC-REL-0060' OR ProductName <> N'Truvio Relation Set 60'))
    UPDATE EcomProducts SET ProductNumber = 'TC-REL-0060', ProductName = N'Truvio Relation Set 60' WHERE ProductId = 'TCPROD0060';

-- Order lines keep a snapshot of the number and the name they were placed
-- against. A demo order history reading TC-CMP-0007 against a catalogue that no
-- longer has that number is a broken page, so the snapshot follows the rename.
UPDATE l
   SET l.OrderLineProductNumber = p.ProductNumber,
       l.OrderLineProductName   = p.ProductName
  FROM EcomOrderLines l
  JOIN EcomProducts p
    ON p.ProductId = l.OrderLineProductId AND p.ProductVariantId = '' AND p.ProductLanguageId = 'ENU'
 WHERE l.OrderLineOrderId LIKE 'TCO-%'
   AND (l.OrderLineProductNumber <> p.ProductNumber OR l.OrderLineProductName <> p.ProductName);

-- A long description written for the old concept is WRONG on the new one, and
-- section 7b fills an EMPTY column only, so the stale bodies are cleared here and
-- rewritten below. Matched on the retired concept words, so a body someone has
-- edited by hand on a live host is left alone.
UPDATE EcomProducts SET ProductLongDescription = NULL
 WHERE ProductVariantId = '' AND ProductLanguageId = 'ENU'
   AND ProductId IN ('TCPROD0006', 'TCPROD0007', 'TCPROD0008', 'TCPROD0009', 'TCPROD0010', 'TCPROD0011', 'TCPROD0012', 'TCPROD0013',
                     'TCPROD0014', 'TCPROD0015', 'TCPROD0031', 'TCPROD0032', 'TCPROD0033', 'TCPROD0034', 'TCPROD0035', 'TCPROD0036',
                     'TCPROD0037', 'TCPROD0038', 'TCPROD0039', 'TCPROD0040', 'TCPROD0041', 'TCPROD0042', 'TCPROD0043', 'TCPROD0044',
                     'TCPROD0045', 'TCPROD0046', 'TCPROD0047', 'TCPROD0048', 'TCPROD0049', 'TCPROD0050', 'TCPROD0051', 'TCPROD0052',
                     'TCPROD0053', 'TCPROD0054', 'TCPROD0055', 'TCPROD0056', 'TCPROD0057', 'TCPROD0058', 'TCPROD0059', 'TCPROD0060')
   AND (ProductLongDescription LIKE N'%workflow%'
     OR ProductLongDescription LIKE N'%completeness%'
     OR ProductLongDescription LIKE N'%impersonat%'
     OR ProductLongDescription LIKE N'%permission%'
     OR ProductLongDescription LIKE N'%paragraph%'
     OR ProductLongDescription LIKE N'%item type%'
     OR ProductLongDescription LIKE N'%page tree%'
     OR ProductLongDescription LIKE N'%user group%');

-- Stale category fields. Section 7 below is the whole set the re-screen keeps;
-- anything else under a tc_* category is a field it dropped - the Completeness
-- Score that rendered as a shopper-facing spec row above all - and its values go
-- with it. Written as an anti-join against a VALUES list so the kept set is
-- stated once and read literally.
-- THE VALUES ARE REBUILT, NOT PATCHED. This layer owns every tc_* value on
-- every TCPROD row, and after the re-screen a value can be stale in three ways
-- at once: its field was dropped, its field moved category, or its product was
-- re-homed into a different top group and so reads a different category
-- altogether. Reconciling those cases one at a time leaves survivors - it left
-- four on the first measured pass - so the set is cleared here and section 7
-- writes it back in full, which makes the row count a statement rather than a
-- residue. truvio-pdp.sql runs later in the same phase and re-adds its four.
DELETE FROM EcomProductCategoryFieldValue
 WHERE FieldValueFieldCategoryId LIKE 'tc[_]%'
   AND FieldValueProductId LIKE 'TCPROD%';

DELETE t FROM EcomProductCategoryFieldTranslation t
 WHERE t.FieldTranslationFieldCategoryId LIKE 'tc[_]%'
   AND NOT EXISTS (SELECT 1 FROM (VALUES
    ('tc_data_models','tcUnitOfMeasure'), ('tc_data_models','tcPackQuantity'), ('tc_data_models','tcNetWeight'), ('tc_data_models','tcDimensions'),
    ('tc_data_models','tcMaterialClass'), ('tc_data_models','tcRating'), ('tc_data_models','tcCompatibility'), ('tc_commerce','tcPriceUnit'),
    ('tc_commerce','tcMinimumOrderQuantity'), ('tc_commerce','tcQuantityBreak'), ('tc_commerce','tcVatGroup'), ('tc_commerce','tcDeliveryLeadTime'),
    ('tc_commerce','tcWarrantyTerm'), ('tc_commerce','tcReturnWindow'), ('tc_content','tcDocumentSet'), ('tc_content','tcMediaSet'),
    ('tc_content','tcRevision'), ('tc_content','tcDatasheetCode'), ('tc_content','tcCertification'), ('tc_content','tcLanguageCoverage'),
    ('tc_content','tcCatalogueSection'), ('tc_users','tcAssortmentScope'), ('tc_users','tcCustomerNumber'), ('tc_users','tcAccountTerms'),
    ('tc_users','tcCurrencyScope'), ('tc_users','tcContractScope'), ('tc_users','tcStockStatus'), ('tc_users','tcOrderChannel')
       ) AS k(cat, fld) WHERE k.cat = t.FieldTranslationFieldCategoryId AND k.fld = t.FieldTranslationFieldId);
DELETE f FROM EcomProductCategoryField f
 WHERE f.FieldCategoryId LIKE 'tc[_]%'
   AND NOT EXISTS (SELECT 1 FROM (VALUES
    ('tc_data_models','tcUnitOfMeasure'), ('tc_data_models','tcPackQuantity'), ('tc_data_models','tcNetWeight'), ('tc_data_models','tcDimensions'),
    ('tc_data_models','tcMaterialClass'), ('tc_data_models','tcRating'), ('tc_data_models','tcCompatibility'), ('tc_commerce','tcPriceUnit'),
    ('tc_commerce','tcMinimumOrderQuantity'), ('tc_commerce','tcQuantityBreak'), ('tc_commerce','tcVatGroup'), ('tc_commerce','tcDeliveryLeadTime'),
    ('tc_commerce','tcWarrantyTerm'), ('tc_commerce','tcReturnWindow'), ('tc_content','tcDocumentSet'), ('tc_content','tcMediaSet'),
    ('tc_content','tcRevision'), ('tc_content','tcDatasheetCode'), ('tc_content','tcCertification'), ('tc_content','tcLanguageCoverage'),
    ('tc_content','tcCatalogueSection'), ('tc_users','tcAssortmentScope'), ('tc_users','tcCustomerNumber'), ('tc_users','tcAccountTerms'),
    ('tc_users','tcCurrencyScope'), ('tc_users','tcContractScope'), ('tc_users','tcStockStatus'), ('tc_users','tcOrderChannel')
       ) AS k(cat, fld) WHERE k.cat = f.FieldCategoryId AND k.fld = f.FieldId);

-- A tc_specs member naming a field that no longer exists resolves to nothing and
-- leaves a blank row in the spec table, so the members are pruned to the fields
-- section 7 actually ships. Section 7c rebuilds the set from the fields below.
DELETE r FROM EcomFieldDisplayGroupFields r
  JOIN EcomFieldDisplayGroups g ON g.FieldDisplayGroupId = r.FieldDisplayGroupFieldGroupId
 WHERE g.FieldDisplayGroupSystemName = 'tc_specs'
   AND r.FieldDisplayGroupFieldSystemName LIKE 'ProductCategory|tc[_]%'
   AND NOT EXISTS (SELECT 1 FROM EcomProductCategoryField f
                    WHERE r.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId);
-- ---------------------------------------------------------------------------
-- 1. Groups: 4 top groups (shop-bound) + 12 subgroups (parented).
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-DATA-MODELS', 'ENU', N'Data Models', 'TCGRP-DATA-MODELS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomShopGroupRelation WHERE ShopGroupShopId = 'SHOP1' AND ShopGroupGroupId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'TCGRP-DATA-MODELS', 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-COMMERCE', 'ENU', N'Commerce', 'TCGRP-COMMERCE', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomShopGroupRelation WHERE ShopGroupShopId = 'SHOP1' AND ShopGroupGroupId = 'TCGRP-COMMERCE')
    INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'TCGRP-COMMERCE', 2);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-CONTENT', 'ENU', N'Content', 'TCGRP-CONTENT', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomShopGroupRelation WHERE ShopGroupShopId = 'SHOP1' AND ShopGroupGroupId = 'TCGRP-CONTENT')
    INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'TCGRP-CONTENT', 3);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-USERS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-USERS', 'ENU', N'Users', 'TCGRP-USERS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomShopGroupRelation WHERE ShopGroupShopId = 'SHOP1' AND ShopGroupGroupId = 'TCGRP-USERS')
    INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'TCGRP-USERS', 4);

IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-VARIANTS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-VARIANTS', 'ENU', N'Variants', 'TCGRP-VARIANTS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-VARIANTS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-VARIANTS', 'TCGRP-DATA-MODELS', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-STOCK-DELIVERY')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-STOCK-DELIVERY', 'ENU', N'Stock & Delivery', 'TCGRP-STOCK-DELIVERY', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupRelationsParentId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-STOCK-DELIVERY', 'TCGRP-COMMERCE', 3, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-UNITS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-UNITS', 'ENU', N'Units & Measures', 'TCGRP-UNITS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-UNITS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-UNITS', 'TCGRP-DATA-MODELS', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PRICE-STRUCTURES')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-PRICE-STRUCTURES', 'ENU', N'Price Structures', 'TCGRP-PRICE-STRUCTURES', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupRelationsParentId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCGRP-COMMERCE', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-ASSORTMENTS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-ASSORTMENTS', 'ENU', N'Assortments', 'TCGRP-ASSORTMENTS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-ASSORTMENTS' AND GroupRelationsParentId = 'TCGRP-USERS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-ASSORTMENTS', 'TCGRP-USERS', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DISCOUNTS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-DISCOUNTS', 'ENU', N'Discounts', 'TCGRP-DISCOUNTS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DISCOUNTS' AND GroupRelationsParentId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-DISCOUNTS', 'TCGRP-COMMERCE', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-MEDIA')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-MEDIA', 'ENU', N'Media & Galleries', 'TCGRP-MEDIA', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-MEDIA' AND GroupRelationsParentId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-MEDIA', 'TCGRP-CONTENT', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CURRENCIES')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-CURRENCIES', 'ENU', N'Currencies & VAT', 'TCGRP-CURRENCIES', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CURRENCIES' AND GroupRelationsParentId = 'TCGRP-USERS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-CURRENCIES', 'TCGRP-USERS', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-BUNDLES')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-BUNDLES', 'ENU', N'Bundles & BOM', 'TCGRP-BUNDLES', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-BUNDLES' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-BUNDLES', 'TCGRP-DATA-MODELS', 3, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-CONTRACT-PRICING')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-CONTRACT-PRICING', 'ENU', N'Contract Pricing', 'TCGRP-CONTRACT-PRICING', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupRelationsParentId = 'TCGRP-USERS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-CONTRACT-PRICING', 'TCGRP-USERS', 3, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DOCUMENTS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-DOCUMENTS', 'ENU', N'Documents', 'TCGRP-DOCUMENTS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DOCUMENTS' AND GroupRelationsParentId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-DOCUMENTS', 'TCGRP-CONTENT', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-RELATIONS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-RELATIONS', 'ENU', N'Relations', 'TCGRP-RELATIONS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-RELATIONS' AND GroupRelationsParentId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-RELATIONS', 'TCGRP-CONTENT', 3, 1, 0);

-- THE TAXONOMY GUARD. The names above are the re-screened ones, seeded as
-- literals, because the converge UPDATE in section 0 renames only rows that
-- already exist: on a clean install there is nothing to converge, the predicate
-- is false, and the retired backend words would reach the shop navigation and
-- the PLP facet rail. Every row count was green while that happened, so this
-- asserts the NAMES and names the offender.
DECLARE @TcRetiredNames TABLE (GroupId NVARCHAR(255), GroupName NVARCHAR(255));
INSERT INTO @TcRetiredNames (GroupId, GroupName)
SELECT g.GroupId, g.GroupName
  FROM EcomGroups g
  JOIN (VALUES
        ('TCGRP-VARIANTS',         N'Variants'),
        ('TCGRP-UNITS',            N'Units & Measures'),
        ('TCGRP-BUNDLES',          N'Bundles & BOM'),
        ('TCGRP-PRICE-STRUCTURES', N'Price Structures'),
        ('TCGRP-DISCOUNTS',        N'Discounts'),
        ('TCGRP-STOCK-DELIVERY',   N'Stock & Delivery'),
        ('TCGRP-DOCUMENTS',        N'Documents'),
        ('TCGRP-MEDIA',            N'Media & Galleries'),
        ('TCGRP-RELATIONS',        N'Relations'),
        ('TCGRP-ASSORTMENTS',      N'Assortments'),
        ('TCGRP-CURRENCIES',       N'Currencies & VAT'),
        ('TCGRP-CONTRACT-PRICING', N'Contract Pricing')) AS x(GroupId, GroupName)
    ON x.GroupId = g.GroupId
 WHERE g.GroupName <> x.GroupName;
IF EXISTS (SELECT 1 FROM @TcRetiredNames)
BEGIN
    DECLARE @TcBadTaxonomy NVARCHAR(2000) = STUFF((SELECT N', ' + GroupId + N'=' + GroupName FROM @TcRetiredNames FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');
    RAISERROR(N'truvio-catalog.sql: a subgroup carries a name the re-screen retired: %s. The final GroupName belongs in the INSERT literal; the section-0 UPDATE converges an already-seeded host and does nothing on a clean one, so a rename that lives only there ships the retired word to the shop navigation and the PLP facet rail while every row count stays green.', 16, 1, @TcBadTaxonomy);
END

-- ---------------------------------------------------------------------------
-- 2. The 60 masters. ProductType 0 = stock item, 1 = service, 2 = BOM parent.
--    Each carries its subgroup as the PRIMARY relation and its top group as a
--    second, non-primary relation (see the EMPTY GROUPS note above).
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0001', 'ENU', '', 'TC-VAR-0001', N'Truvio Variant Master 01', N'Truvio demo data. Master in the Variant band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-VARIANTS' AND GroupProductRelationProductId = 'TCPROD0001')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-VARIANTS', 'TCPROD0001', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0001')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0001', 1, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0002', 'ENU', '', 'TC-VAR-0002', N'Truvio Variant Master 02', N'Truvio demo data. Master in the Variant band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-VARIANTS' AND GroupProductRelationProductId = 'TCPROD0002')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-VARIANTS', 'TCPROD0002', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0002')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0002', 2, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0003', 'ENU', '', 'TC-VAR-0003', N'Truvio Variant Master 03', N'Truvio demo data. Master in the Variant band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-VARIANTS' AND GroupProductRelationProductId = 'TCPROD0003')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-VARIANTS', 'TCPROD0003', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0003')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0003', 3, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0004', 'ENU', '', 'TC-VAR-0004', N'Truvio Variant Master 04', N'Truvio demo data. Master in the Variant band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-VARIANTS' AND GroupProductRelationProductId = 'TCPROD0004')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-VARIANTS', 'TCPROD0004', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0004')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0004', 4, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0005', 'ENU', '', 'TC-VAR-0005', N'Truvio Variant Master 05', N'Truvio demo data. Master in the Variant band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-VARIANTS' AND GroupProductRelationProductId = 'TCPROD0005')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-VARIANTS', 'TCPROD0005', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0005')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0005', 5, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0006', 'ENU', '', 'TC-STK-0006', N'Truvio Stock Item 06', N'Truvio demo data. Stock row in the Stock & Delivery band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupProductRelationProductId = 'TCPROD0006')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-STOCK-DELIVERY', 'TCPROD0006', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0006')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0006', 6, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0007', 'ENU', '', 'TC-STK-0007', N'Truvio Stock Item 07', N'Truvio demo data. Stock row in the Stock & Delivery band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupProductRelationProductId = 'TCPROD0007')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-STOCK-DELIVERY', 'TCPROD0007', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0007')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0007', 7, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0008', 'ENU', '', 'TC-STK-0008', N'Truvio Stock Item 08', N'Truvio demo data. Stock row in the Stock & Delivery band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupProductRelationProductId = 'TCPROD0008')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-STOCK-DELIVERY', 'TCPROD0008', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0008')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0008', 8, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0009', 'ENU', '', 'TC-STK-0009', N'Truvio Stock Item 09', N'Truvio demo data. Stock row in the Stock & Delivery band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupProductRelationProductId = 'TCPROD0009')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-STOCK-DELIVERY', 'TCPROD0009', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0009')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0009', 9, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0010', 'ENU', '', 'TC-STK-0010', N'Truvio Stock Item 10', N'Truvio demo data. Stock row in the Stock & Delivery band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-STOCK-DELIVERY' AND GroupProductRelationProductId = 'TCPROD0010')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-STOCK-DELIVERY', 'TCPROD0010', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0010')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0010', 10, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0011', 'ENU', '', 'TC-UOM-0011', N'Truvio Unit Measure 11', N'Truvio demo data. Unit row in the Units & Measures band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-UNITS' AND GroupProductRelationProductId = 'TCPROD0011')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-UNITS', 'TCPROD0011', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0011')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0011', 11, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0012', 'ENU', '', 'TC-UOM-0012', N'Truvio Unit Measure 12', N'Truvio demo data. Unit row in the Units & Measures band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-UNITS' AND GroupProductRelationProductId = 'TCPROD0012')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-UNITS', 'TCPROD0012', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0012')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0012', 12, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0013', 'ENU', '', 'TC-UOM-0013', N'Truvio Unit Conversion Service 13', N'Truvio demo data. Service line (ProductType 1): no stock, no shipment - it proves a non-stock line renders and prices like any other.', 75.00, 1, 1, 100, 1, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-UNITS' AND GroupProductRelationProductId = 'TCPROD0013')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-UNITS', 'TCPROD0013', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0013')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0013', 13, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0014', 'ENU', '', 'TC-UOM-0014', N'Truvio Unit Measure 14', N'Truvio demo data. Unit row in the Units & Measures band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-UNITS' AND GroupProductRelationProductId = 'TCPROD0014')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-UNITS', 'TCPROD0014', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0014')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0014', 14, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0015', 'ENU', '', 'TC-UOM-0015', N'Truvio Unit Measure 15', N'Truvio demo data. Unit row in the Units & Measures band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-UNITS' AND GroupProductRelationProductId = 'TCPROD0015')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-UNITS', 'TCPROD0015', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0015')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0015', 15, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0016', 'ENU', '', 'TC-PRC-0016', N'Truvio Price Matrix 16', N'Truvio demo data. Matrix in the Price band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupProductRelationProductId = 'TCPROD0016')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCPROD0016', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0016')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0016', 16, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0017', 'ENU', '', 'TC-PRC-0017', N'Truvio Price Matrix 17', N'Truvio demo data. Matrix in the Price band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupProductRelationProductId = 'TCPROD0017')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCPROD0017', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0017')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0017', 17, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0018', 'ENU', '', 'TC-PRC-0018', N'Truvio Price Matrix 18', N'Truvio demo data. Matrix in the Price band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupProductRelationProductId = 'TCPROD0018')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCPROD0018', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0018')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0018', 18, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0019', 'ENU', '', 'TC-PRC-0019', N'Truvio Price Matrix 19', N'Truvio demo data. Matrix in the Price band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupProductRelationProductId = 'TCPROD0019')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCPROD0019', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0019')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0019', 19, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0020', 'ENU', '', 'TC-PRC-0020', N'Truvio Price Matrix 20', N'Truvio demo data. Matrix in the Price band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupProductRelationProductId = 'TCPROD0020')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCPROD0020', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0020')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0020', 20, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0021', 'ENU', '', 'TC-ASM-0021', N'Truvio Assortment Kit 21', N'Truvio demo data. Bill-of-materials parent: pick one Variants component and one Bundles & BOM component, then add the configured kit to the cart.', 0.00, 1, 1, 100, 2, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0021')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0021', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0021')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0021', 21, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0022', 'ENU', '', 'TC-ASM-0022', N'Truvio Assortment Scope 22', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0022')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0022', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0022')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0022', 22, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0023', 'ENU', '', 'TC-ASM-0023', N'Truvio Assortment Scope 23', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0023')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0023', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0023')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0023', 23, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0024', 'ENU', '', 'TC-ASM-0024', N'Truvio Assortment Scope 24', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0024')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0024', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0024')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0024', 24, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0025', 'ENU', '', 'TC-ASM-0025', N'Truvio Assortment Scope 25', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0025')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0025', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0025')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0025', 25, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0026', 'ENU', '', 'TC-DSC-0026', N'Truvio Discount Ladder 26', N'Truvio demo data. Ladder in the Discount band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DISCOUNTS' AND GroupProductRelationProductId = 'TCPROD0026')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DISCOUNTS', 'TCPROD0026', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0026')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0026', 26, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0027', 'ENU', '', 'TC-DSC-0027', N'Truvio Discount Ladder 27', N'Truvio demo data. Ladder in the Discount band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DISCOUNTS' AND GroupProductRelationProductId = 'TCPROD0027')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DISCOUNTS', 'TCPROD0027', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0027')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0027', 27, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0028', 'ENU', '', 'TC-DSC-0028', N'Truvio Discount Ladder 28', N'Truvio demo data. Ladder in the Discount band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DISCOUNTS' AND GroupProductRelationProductId = 'TCPROD0028')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DISCOUNTS', 'TCPROD0028', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0028')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0028', 28, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0029', 'ENU', '', 'TC-DSC-0029', N'Truvio Discount Ladder 29', N'Truvio demo data. Ladder in the Discount band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DISCOUNTS' AND GroupProductRelationProductId = 'TCPROD0029')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DISCOUNTS', 'TCPROD0029', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0029')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0029', 29, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0030', 'ENU', '', 'TC-DSC-0030', N'Truvio Discount Ladder 30', N'Truvio demo data. Ladder in the Discount band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DISCOUNTS' AND GroupProductRelationProductId = 'TCPROD0030')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DISCOUNTS', 'TCPROD0030', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0030')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0030', 30, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0031', 'ENU', '', 'TC-MED-0031', N'Truvio Media Set 31', N'Truvio demo data. Media set in the Media & Galleries band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-MEDIA' AND GroupProductRelationProductId = 'TCPROD0031')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-MEDIA', 'TCPROD0031', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0031')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0031', 31, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0032', 'ENU', '', 'TC-MED-0032', N'Truvio Media Set 32', N'Truvio demo data. Media set in the Media & Galleries band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-MEDIA' AND GroupProductRelationProductId = 'TCPROD0032')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-MEDIA', 'TCPROD0032', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0032')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0032', 32, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0033', 'ENU', '', 'TC-MED-0033', N'Truvio Media Set 33', N'Truvio demo data. Media set in the Media & Galleries band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-MEDIA' AND GroupProductRelationProductId = 'TCPROD0033')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-MEDIA', 'TCPROD0033', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0033')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0033', 33, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0034', 'ENU', '', 'TC-MED-0034', N'Truvio Media Set 34', N'Truvio demo data. Media set in the Media & Galleries band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-MEDIA' AND GroupProductRelationProductId = 'TCPROD0034')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-MEDIA', 'TCPROD0034', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0034')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0034', 34, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0035', 'ENU', '', 'TC-MED-0035', N'Truvio Media Set 35', N'Truvio demo data. Media set in the Media & Galleries band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-MEDIA' AND GroupProductRelationProductId = 'TCPROD0035')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-MEDIA', 'TCPROD0035', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0035')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0035', 35, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0036', 'ENU', '', 'TC-CUR-0036', N'Truvio Currency Matrix 36', N'Truvio demo data. Currency row in the Currencies & VAT band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CURRENCIES' AND GroupProductRelationProductId = 'TCPROD0036')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CURRENCIES', 'TCPROD0036', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0036')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0036', 36, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0037', 'ENU', '', 'TC-CUR-0037', N'Truvio Currency Matrix 37', N'Truvio demo data. Currency row in the Currencies & VAT band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CURRENCIES' AND GroupProductRelationProductId = 'TCPROD0037')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CURRENCIES', 'TCPROD0037', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0037')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0037', 37, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0038', 'ENU', '', 'TC-CUR-0038', N'Truvio Currency Matrix 38', N'Truvio demo data. Currency row in the Currencies & VAT band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CURRENCIES' AND GroupProductRelationProductId = 'TCPROD0038')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CURRENCIES', 'TCPROD0038', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0038')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0038', 38, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0039', 'ENU', '', 'TC-CUR-0039', N'Truvio Currency Matrix 39', N'Truvio demo data. Currency row in the Currencies & VAT band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CURRENCIES' AND GroupProductRelationProductId = 'TCPROD0039')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CURRENCIES', 'TCPROD0039', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0039')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0039', 39, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0040', 'ENU', '', 'TC-CUR-0040', N'Truvio Currency Matrix 40', N'Truvio demo data. Currency row in the Currencies & VAT band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CURRENCIES' AND GroupProductRelationProductId = 'TCPROD0040')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CURRENCIES', 'TCPROD0040', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0040')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0040', 40, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0041', 'ENU', '', 'TC-BDL-0041', N'Truvio Bundle Kit 41', N'Truvio demo data. Kit in the Bundles & BOM band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-BUNDLES' AND GroupProductRelationProductId = 'TCPROD0041')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-BUNDLES', 'TCPROD0041', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0041')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0041', 41, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0042', 'ENU', '', 'TC-BDL-0042', N'Truvio Bundle Kit 42', N'Truvio demo data. Kit in the Bundles & BOM band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-BUNDLES' AND GroupProductRelationProductId = 'TCPROD0042')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-BUNDLES', 'TCPROD0042', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0042')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0042', 42, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0043', 'ENU', '', 'TC-BDL-0043', N'Truvio Bundle Kit 43', N'Truvio demo data. Kit in the Bundles & BOM band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-BUNDLES' AND GroupProductRelationProductId = 'TCPROD0043')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-BUNDLES', 'TCPROD0043', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0043')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0043', 43, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0044', 'ENU', '', 'TC-BDL-0044', N'Truvio Bundle Kit 44', N'Truvio demo data. Kit in the Bundles & BOM band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-BUNDLES' AND GroupProductRelationProductId = 'TCPROD0044')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-BUNDLES', 'TCPROD0044', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0044')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0044', 44, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0045', 'ENU', '', 'TC-BDL-0045', N'Truvio Bundle Kit 45', N'Truvio demo data. Kit in the Bundles & BOM band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-BUNDLES' AND GroupProductRelationProductId = 'TCPROD0045')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-BUNDLES', 'TCPROD0045', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0045')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0045', 45, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0046', 'ENU', '', 'TC-CTR-0046', N'Truvio Contract Price 46', N'Truvio demo data. Contract row in the Contract Pricing band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupProductRelationProductId = 'TCPROD0046')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTRACT-PRICING', 'TCPROD0046', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0046')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0046', 46, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0047', 'ENU', '', 'TC-CTR-0047', N'Truvio Contract Price 47', N'Truvio demo data. Contract row in the Contract Pricing band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupProductRelationProductId = 'TCPROD0047')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTRACT-PRICING', 'TCPROD0047', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0047')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0047', 47, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0048', 'ENU', '', 'TC-CTR-0048', N'Truvio Contract Price 48', N'Truvio demo data. Contract row in the Contract Pricing band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupProductRelationProductId = 'TCPROD0048')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTRACT-PRICING', 'TCPROD0048', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0048')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0048', 48, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0049', 'ENU', '', 'TC-CTR-0049', N'Truvio Contract Price 49', N'Truvio demo data. Contract row in the Contract Pricing band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupProductRelationProductId = 'TCPROD0049')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTRACT-PRICING', 'TCPROD0049', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0049')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0049', 49, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0050', 'ENU', '', 'TC-CTR-0050', N'Truvio Contract Price 50', N'Truvio demo data. Contract row in the Contract Pricing band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTRACT-PRICING' AND GroupProductRelationProductId = 'TCPROD0050')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTRACT-PRICING', 'TCPROD0050', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0050')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0050', 50, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0051', 'ENU', '', 'TC-DOC-0051', N'Truvio Document Set 51', N'Truvio demo data. Document set in the Documents band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DOCUMENTS' AND GroupProductRelationProductId = 'TCPROD0051')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DOCUMENTS', 'TCPROD0051', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0051')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0051', 51, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0052', 'ENU', '', 'TC-DOC-0052', N'Truvio Document Set 52', N'Truvio demo data. Document set in the Documents band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DOCUMENTS' AND GroupProductRelationProductId = 'TCPROD0052')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DOCUMENTS', 'TCPROD0052', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0052')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0052', 52, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0053', 'ENU', '', 'TC-DOC-0053', N'Truvio Document Service 53', N'Truvio demo data. Service line (ProductType 1): no stock, no shipment - it proves a non-stock line renders and prices like any other.', 75.00, 1, 1, 100, 1, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DOCUMENTS' AND GroupProductRelationProductId = 'TCPROD0053')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DOCUMENTS', 'TCPROD0053', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0053')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0053', 53, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0054', 'ENU', '', 'TC-DOC-0054', N'Truvio Document Set 54', N'Truvio demo data. Document set in the Documents band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DOCUMENTS' AND GroupProductRelationProductId = 'TCPROD0054')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DOCUMENTS', 'TCPROD0054', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0054')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0054', 54, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0055', 'ENU', '', 'TC-DOC-0055', N'Truvio Document Set 55', N'Truvio demo data. Document set in the Documents band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DOCUMENTS' AND GroupProductRelationProductId = 'TCPROD0055')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DOCUMENTS', 'TCPROD0055', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0055')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0055', 55, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0056', 'ENU', '', 'TC-REL-0056', N'Truvio Relation Set 56', N'Truvio demo data. Relation set in the Relations band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-RELATIONS' AND GroupProductRelationProductId = 'TCPROD0056')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-RELATIONS', 'TCPROD0056', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0056')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0056', 56, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0057', 'ENU', '', 'TC-REL-0057', N'Truvio Relation Set 57', N'Truvio demo data. Relation set in the Relations band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-RELATIONS' AND GroupProductRelationProductId = 'TCPROD0057')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-RELATIONS', 'TCPROD0057', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0057')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0057', 57, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0058', 'ENU', '', 'TC-REL-0058', N'Truvio Relation Set 58', N'Truvio demo data. Relation set in the Relations band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-RELATIONS' AND GroupProductRelationProductId = 'TCPROD0058')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-RELATIONS', 'TCPROD0058', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0058')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0058', 58, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0059', 'ENU', '', 'TC-REL-0059', N'Truvio Relation Set 59', N'Truvio demo data. Relation set in the Relations band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-RELATIONS' AND GroupProductRelationProductId = 'TCPROD0059')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-RELATIONS', 'TCPROD0059', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0059')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0059', 59, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0060', 'ENU', '', 'TC-REL-0060', N'Truvio Relation Set 60', N'Truvio demo data. Relation set in the Relations band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-RELATIONS' AND GroupProductRelationProductId = 'TCPROD0060')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-RELATIONS', 'TCPROD0060', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0060')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0060', 60, 0, GETDATE());

-- ---------------------------------------------------------------------------
-- 3. The two variant axes and their options.
--    Tier and Mode are platform vocabulary on purpose: `Size` and `Finish` are
--    worldly and would break the naming rule (D-B).
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroups WHERE VariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroups (VariantGroupId, VariantGroupLanguageId, VariantGroupName, VariantGroupLabel) VALUES ('TCVG-TIER', 'ENU', 'Tier', 'Tier');
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroups WHERE VariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroups (VariantGroupId, VariantGroupLanguageId, VariantGroupName, VariantGroupLabel) VALUES ('TCVG-MODE', 'ENU', 'Mode', 'Mode');
IF NOT EXISTS (SELECT 1 FROM EcomVariantsOptions WHERE VariantOptionId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('TCVO-TIER-STD', 'ENU', 'TCVG-TIER', 'Standard', 1);
IF NOT EXISTS (SELECT 1 FROM EcomVariantsOptions WHERE VariantOptionId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('TCVO-TIER-ADV', 'ENU', 'TCVG-TIER', 'Advanced', 2);
IF NOT EXISTS (SELECT 1 FROM EcomVariantsOptions WHERE VariantOptionId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('TCVO-TIER-ENT', 'ENU', 'TCVG-TIER', 'Enterprise', 3);
IF NOT EXISTS (SELECT 1 FROM EcomVariantsOptions WHERE VariantOptionId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('TCVO-MODE-DRAFT', 'ENU', 'TCVG-MODE', 'Draft', 1);
IF NOT EXISTS (SELECT 1 FROM EcomVariantsOptions WHERE VariantOptionId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('TCVO-MODE-PUB', 'ENU', 'TCVG-MODE', 'Published', 2);

-- ---------------------------------------------------------------------------
-- 4. The 6 variant masters: the AXIS BINDING, option relations, the 36
--    combination rows, and the explicit per-variant price. A combination row's
--    ProductVariantId is the
--    dot-joined option ids - that string IS the variant key the storefront
--    resolves, so it is written literally and never derived at read time.
--
--    EcomPrices.PriceProductVariantId is what scopes a price row to ONE combination.
--    Without it the 36 rows would all price the master and the tier ladder would
--    read as a single price - so the column is asserted before it is used.
--
--    The column is PriceProductVariantId, measured off sys.columns on DW 10.28.10.
--    This section once spelled it PriceVariantId in both the inserts AND the
--    guard, which taught the lesson the guard exists to teach: a COL_LENGTH guard
--    is a RUNTIME check and the batch dies at COMPILE time with Msg 207, so a
--    guard spelled from the same wrong guess as the insert never gets to fire.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('EcomPrices', 'PriceProductVariantId') IS NULL
    RAISERROR(N'truvio-catalog.sql: EcomPrices has no PriceProductVariantId column on this platform build. Per-variant prices cannot be scoped; read the live column names off sys.columns before seeding.', 16, 1);

-- THE SELECTOR RENDERS OFF THE AXIS BINDING, NOT OFF THE COMBINATIONS.
-- 1.1.x seeded the axes (EcomVariantGroups), the options (EcomVariantsOptions),
-- the per-master option relations (EcomVariantOptionsProductRelation) and all 36
-- combination rows with their own prices - and the PDP variant selector still
-- rendered EMPTY, signed in and signed out, on the very product whose own
-- Overview copy tells the reader to open it. Every count was right and nothing
-- showed.
--
-- Diagnosed on the live DW 10.28.10 host: EcomVariantGroupProductRelation held
-- ZERO rows, for this layer and for the whole database. That table is the one
-- that says WHICH AXES A PRODUCT USES. The option relations say which values on
-- an axis a product offers, and the combination rows say what each intersection
-- costs, but neither answers the selector's first question - and with no answer
-- it has nothing to draw a control for, so it draws nothing at all and reports
-- no error. The master carried ProductVariantGroupCounter = 0 beside it, which
-- is the same fact stated a second way.
--
-- Proven in a rolled-back transaction before it was written here: with the 12
-- rows below present, TCPROD0001 resolves two axes - Tier with 3 options and
-- Mode with 2 - and all 6 of its dot-joined combination keys carry exactly one
-- separator, so every key names a point on the grid the two axes describe.
--
-- VariantGroupProductRelationId is NOT an identity: it is a NOT NULL nvarchar
-- key, so each row is named deterministically rather than left to the platform.
-- Measured off sys.columns, in this file's own idiom.
IF COL_LENGTH('EcomVariantGroupProductRelation', 'VariantGroupProductRelationId') IS NULL
    RAISERROR(N'truvio-catalog.sql: EcomVariantGroupProductRelation is missing its id column on this platform build. The variant selector reads this table to learn which axes a product uses; without it every variant master renders an empty selector, silently.', 16, 1);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0001' AND VariantGroupProductRelationVariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0001-TIER', 'TCPROD0001', 'TCVG-TIER', 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0001' AND VariantGroupProductRelationVariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0001-MODE', 'TCPROD0001', 'TCVG-MODE', 2, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0011' AND VariantGroupProductRelationVariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0011-TIER', 'TCPROD0011', 'TCVG-TIER', 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0011' AND VariantGroupProductRelationVariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0011-MODE', 'TCPROD0011', 'TCVG-MODE', 2, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0016' AND VariantGroupProductRelationVariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0016-TIER', 'TCPROD0016', 'TCVG-TIER', 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0016' AND VariantGroupProductRelationVariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0016-MODE', 'TCPROD0016', 'TCVG-MODE', 2, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0031' AND VariantGroupProductRelationVariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0031-TIER', 'TCPROD0031', 'TCVG-TIER', 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0031' AND VariantGroupProductRelationVariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0031-MODE', 'TCPROD0031', 'TCVG-MODE', 2, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0041' AND VariantGroupProductRelationVariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0041-TIER', 'TCPROD0041', 'TCVG-TIER', 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0041' AND VariantGroupProductRelationVariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0041-MODE', 'TCPROD0041', 'TCVG-MODE', 2, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0051' AND VariantGroupProductRelationVariantGroupId = 'TCVG-TIER')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0051-TIER', 'TCPROD0051', 'TCVG-TIER', 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId = 'TCPROD0051' AND VariantGroupProductRelationVariantGroupId = 'TCVG-MODE')
    INSERT INTO EcomVariantGroupProductRelation (VariantGroupProductRelationId, VariantGroupProductRelationProductId, VariantGroupProductRelationVariantGroupId, VariantGroupProductRelationSorting, VariantGroupProductRelationPriceDif) VALUES ('TCVGR-TCPROD0051-MODE', 'TCPROD0051', 'TCVG-MODE', 2, 0);

-- The counters the backend keeps beside the relations, derived from the rows
-- rather than typed, so they cannot drift from what was actually seeded.
UPDATE p
   SET p.ProductVariantGroupCounter = x.axes,
       p.ProductVariantCounter      = x.combos,
       p.ProductVariantProdCounter  = x.combos
  FROM EcomProducts p
  CROSS APPLY (SELECT
        (SELECT COUNT(*) FROM EcomVariantGroupProductRelation r WHERE r.VariantGroupProductRelationProductId = p.ProductId) AS axes,
        (SELECT COUNT(*) FROM EcomProducts v WHERE v.ProductId = p.ProductId AND v.ProductVariantId <> '' AND v.ProductLanguageId = p.ProductLanguageId) AS combos) x
 WHERE p.ProductId LIKE 'TCPROD%' AND p.ProductVariantId = ''
   AND (p.ProductVariantGroupCounter <> x.axes OR p.ProductVariantCounter <> x.combos OR p.ProductVariantProdCounter <> x.combos);

IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0001' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0001', 'TCVO-TIER-STD');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0001' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0001', 'TCVO-TIER-ADV');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0001' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0001', 'TCVO-TIER-ENT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0001' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0001', 'TCVO-MODE-DRAFT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0001' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0001', 'TCVO-MODE-PUB');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-DRAFT', ProductNumber + '-STD-DRAFT', ProductName, ProductShortDescription, 45.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0001')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0001', 'TCPROD0001', 'TCVO-TIER-STD.TCVO-MODE-DRAFT', 'EUR', 1, 45.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-PUB', ProductNumber + '-STD-PUB', ProductName, ProductShortDescription, 49.50, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0002')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0002', 'TCPROD0001', 'TCVO-TIER-STD.TCVO-MODE-PUB', 'EUR', 1, 49.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', ProductNumber + '-ADV-DRAFT', ProductName, ProductShortDescription, 56.25, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0003')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0003', 'TCPROD0001', 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', 'EUR', 1, 56.25, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-PUB', ProductNumber + '-ADV-PUB', ProductName, ProductShortDescription, 61.88, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0004')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0004', 'TCPROD0001', 'TCVO-TIER-ADV.TCVO-MODE-PUB', 'EUR', 1, 61.88, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', ProductNumber + '-ENT-DRAFT', ProductName, ProductShortDescription, 72.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0005')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0005', 'TCPROD0001', 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', 'EUR', 1, 72.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-PUB', ProductNumber + '-ENT-PUB', ProductName, ProductShortDescription, 79.20, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0006')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0006', 'TCPROD0001', 'TCVO-TIER-ENT.TCVO-MODE-PUB', 'EUR', 1, 79.20, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0011' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0011', 'TCVO-TIER-STD');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0011' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0011', 'TCVO-TIER-ADV');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0011' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0011', 'TCVO-TIER-ENT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0011' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0011', 'TCVO-MODE-DRAFT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0011' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0011', 'TCVO-MODE-PUB');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-DRAFT', ProductNumber + '-STD-DRAFT', ProductName, ProductShortDescription, 45.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0007')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0007', 'TCPROD0011', 'TCVO-TIER-STD.TCVO-MODE-DRAFT', 'EUR', 1, 45.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-PUB', ProductNumber + '-STD-PUB', ProductName, ProductShortDescription, 49.50, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0008')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0008', 'TCPROD0011', 'TCVO-TIER-STD.TCVO-MODE-PUB', 'EUR', 1, 49.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', ProductNumber + '-ADV-DRAFT', ProductName, ProductShortDescription, 56.25, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0009')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0009', 'TCPROD0011', 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', 'EUR', 1, 56.25, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-PUB', ProductNumber + '-ADV-PUB', ProductName, ProductShortDescription, 61.88, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0010')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0010', 'TCPROD0011', 'TCVO-TIER-ADV.TCVO-MODE-PUB', 'EUR', 1, 61.88, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', ProductNumber + '-ENT-DRAFT', ProductName, ProductShortDescription, 72.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0011')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0011', 'TCPROD0011', 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', 'EUR', 1, 72.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-PUB', ProductNumber + '-ENT-PUB', ProductName, ProductShortDescription, 79.20, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0012')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0012', 'TCPROD0011', 'TCVO-TIER-ENT.TCVO-MODE-PUB', 'EUR', 1, 79.20, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0016' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0016', 'TCVO-TIER-STD');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0016' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0016', 'TCVO-TIER-ADV');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0016' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0016', 'TCVO-TIER-ENT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0016' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0016', 'TCVO-MODE-DRAFT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0016' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0016', 'TCVO-MODE-PUB');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-DRAFT', ProductNumber + '-STD-DRAFT', ProductName, ProductShortDescription, 45.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0013')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0013', 'TCPROD0016', 'TCVO-TIER-STD.TCVO-MODE-DRAFT', 'EUR', 1, 45.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-PUB', ProductNumber + '-STD-PUB', ProductName, ProductShortDescription, 49.50, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0014')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0014', 'TCPROD0016', 'TCVO-TIER-STD.TCVO-MODE-PUB', 'EUR', 1, 49.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', ProductNumber + '-ADV-DRAFT', ProductName, ProductShortDescription, 56.25, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0015')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0015', 'TCPROD0016', 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', 'EUR', 1, 56.25, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-PUB', ProductNumber + '-ADV-PUB', ProductName, ProductShortDescription, 61.88, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0016')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0016', 'TCPROD0016', 'TCVO-TIER-ADV.TCVO-MODE-PUB', 'EUR', 1, 61.88, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', ProductNumber + '-ENT-DRAFT', ProductName, ProductShortDescription, 72.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0017')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0017', 'TCPROD0016', 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', 'EUR', 1, 72.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-PUB', ProductNumber + '-ENT-PUB', ProductName, ProductShortDescription, 79.20, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0018')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0018', 'TCPROD0016', 'TCVO-TIER-ENT.TCVO-MODE-PUB', 'EUR', 1, 79.20, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0031' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0031', 'TCVO-TIER-STD');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0031' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0031', 'TCVO-TIER-ADV');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0031' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0031', 'TCVO-TIER-ENT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0031' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0031', 'TCVO-MODE-DRAFT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0031' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0031', 'TCVO-MODE-PUB');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-DRAFT', ProductNumber + '-STD-DRAFT', ProductName, ProductShortDescription, 45.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0019')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0019', 'TCPROD0031', 'TCVO-TIER-STD.TCVO-MODE-DRAFT', 'EUR', 1, 45.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-PUB', ProductNumber + '-STD-PUB', ProductName, ProductShortDescription, 49.50, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0020')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0020', 'TCPROD0031', 'TCVO-TIER-STD.TCVO-MODE-PUB', 'EUR', 1, 49.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', ProductNumber + '-ADV-DRAFT', ProductName, ProductShortDescription, 56.25, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0021')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0021', 'TCPROD0031', 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', 'EUR', 1, 56.25, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-PUB', ProductNumber + '-ADV-PUB', ProductName, ProductShortDescription, 61.88, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0022')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0022', 'TCPROD0031', 'TCVO-TIER-ADV.TCVO-MODE-PUB', 'EUR', 1, 61.88, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', ProductNumber + '-ENT-DRAFT', ProductName, ProductShortDescription, 72.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0023')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0023', 'TCPROD0031', 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', 'EUR', 1, 72.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-PUB', ProductNumber + '-ENT-PUB', ProductName, ProductShortDescription, 79.20, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0024')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0024', 'TCPROD0031', 'TCVO-TIER-ENT.TCVO-MODE-PUB', 'EUR', 1, 79.20, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0041' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0041', 'TCVO-TIER-STD');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0041' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0041', 'TCVO-TIER-ADV');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0041' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0041', 'TCVO-TIER-ENT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0041' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0041', 'TCVO-MODE-DRAFT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0041' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0041', 'TCVO-MODE-PUB');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-DRAFT', ProductNumber + '-STD-DRAFT', ProductName, ProductShortDescription, 45.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0025')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0025', 'TCPROD0041', 'TCVO-TIER-STD.TCVO-MODE-DRAFT', 'EUR', 1, 45.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-PUB', ProductNumber + '-STD-PUB', ProductName, ProductShortDescription, 49.50, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0026')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0026', 'TCPROD0041', 'TCVO-TIER-STD.TCVO-MODE-PUB', 'EUR', 1, 49.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', ProductNumber + '-ADV-DRAFT', ProductName, ProductShortDescription, 56.25, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0027')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0027', 'TCPROD0041', 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', 'EUR', 1, 56.25, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-PUB', ProductNumber + '-ADV-PUB', ProductName, ProductShortDescription, 61.88, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0028')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0028', 'TCPROD0041', 'TCVO-TIER-ADV.TCVO-MODE-PUB', 'EUR', 1, 61.88, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', ProductNumber + '-ENT-DRAFT', ProductName, ProductShortDescription, 72.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0029')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0029', 'TCPROD0041', 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', 'EUR', 1, 72.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-PUB', ProductNumber + '-ENT-PUB', ProductName, ProductShortDescription, 79.20, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0030')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0030', 'TCPROD0041', 'TCVO-TIER-ENT.TCVO-MODE-PUB', 'EUR', 1, 79.20, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0051' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-STD')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0051', 'TCVO-TIER-STD');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0051' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ADV')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0051', 'TCVO-TIER-ADV');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0051' AND VariantOptionsProductRelationVariantId = 'TCVO-TIER-ENT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0051', 'TCVO-TIER-ENT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0051' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-DRAFT')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0051', 'TCVO-MODE-DRAFT');
IF NOT EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId = 'TCPROD0051' AND VariantOptionsProductRelationVariantId = 'TCVO-MODE-PUB')
    INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('TCPROD0051', 'TCVO-MODE-PUB');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-DRAFT', ProductNumber + '-STD-DRAFT', ProductName, ProductShortDescription, 45.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0031')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0031', 'TCPROD0051', 'TCVO-TIER-STD.TCVO-MODE-DRAFT', 'EUR', 1, 45.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = 'TCVO-TIER-STD.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-STD.TCVO-MODE-PUB', ProductNumber + '-STD-PUB', ProductName, ProductShortDescription, 49.50, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0032')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0032', 'TCPROD0051', 'TCVO-TIER-STD.TCVO-MODE-PUB', 'EUR', 1, 49.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', ProductNumber + '-ADV-DRAFT', ProductName, ProductShortDescription, 56.25, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0033')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0033', 'TCPROD0051', 'TCVO-TIER-ADV.TCVO-MODE-DRAFT', 'EUR', 1, 56.25, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = 'TCVO-TIER-ADV.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ADV.TCVO-MODE-PUB', ProductNumber + '-ADV-PUB', ProductName, ProductShortDescription, 61.88, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0034')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0034', 'TCPROD0051', 'TCVO-TIER-ADV.TCVO-MODE-PUB', 'EUR', 1, 61.88, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-DRAFT')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', ProductNumber + '-ENT-DRAFT', ProductName, ProductShortDescription, 72.00, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0035')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0035', 'TCPROD0051', 'TCVO-TIER-ENT.TCVO-MODE-DRAFT', 'EUR', 1, 72.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = 'TCVO-TIER-ENT.TCVO-MODE-PUB')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    SELECT ProductId, ProductLanguageId, 'TCVO-TIER-ENT.TCVO-MODE-PUB', ProductNumber + '-ENT-PUB', ProductName, ProductShortDescription, 79.20, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-VAR-0036')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-VAR-0036', 'TCPROD0051', 'TCVO-TIER-ENT.TCVO-MODE-PUB', 'EUR', 1, 79.20, '', '');

-- THE SELECTOR GUARD, and it sits HERE - after the last option relation and
-- the last combination row - because it asserts exactly those. Upstream of
-- them it measured an empty table on any host seeding for the first time, and
-- a severity-16 RAISERROR does not abort the batch, so the script went on to
-- print its own success line on the run that had just reported the failure.
-- A row count would have been green on every run that
-- shipped an empty selector, so this asserts the thing the control needs: a
-- master bound to at least two axes, each of which offers at least two options
-- THAT MASTER actually carries. Anything less is a selector with nothing to
-- choose between, which renders as an empty div and says nothing about why.
DECLARE @TcRenderableSelectors INT = (
    SELECT COUNT(*) FROM (
        SELECT r.VariantGroupProductRelationProductId AS prod
          FROM EcomVariantGroupProductRelation r
         WHERE r.VariantGroupProductRelationProductId LIKE 'TCPROD%'
           AND (SELECT COUNT(*) FROM EcomVariantsOptions o
                 WHERE o.VariantOptionGroupId = r.VariantGroupProductRelationVariantGroupId
                   AND o.VariantOptionLanguageId = 'ENU'
                   AND EXISTS (SELECT 1 FROM EcomVariantOptionsProductRelation vp
                                WHERE vp.VariantOptionsProductRelationProductId = r.VariantGroupProductRelationProductId
                                  AND vp.VariantOptionsProductRelationVariantId = o.VariantOptionId)) >= 2
         GROUP BY r.VariantGroupProductRelationProductId
        HAVING COUNT(*) >= 2) s);
-- THE THRESHOLD IS SIX AND THE SUBJECT IS SIX, so the margin is zero: any master
-- losing an axis puts this back into failure (Foundry #1133, verified at 4a4cd05b -
-- TCPROD0001, 0011, 0016, 0031, 0041 and 0051, each bound to both TCVG-MODE and
-- TCVG-TIER). A guard with no margin has to SAY what it measured, or the next run
-- to trip it reports a threshold and leaves the reader to go and count.
DECLARE @TcSelectorMsg NVARCHAR(800);
IF @TcRenderableSelectors < 6
BEGIN
    SET @TcSelectorMsg = CONCAT(N'truvio-catalog.sql: ', @TcRenderableSelectors,
        N' of 6 required variant masters can actually render a selector. A master needs a row in EcomVariantGroupProductRelation per axis AND at least two of that axis options on itself; without both the PDP draws an empty div and the product copy telling the reader to open the selector is a lie on the page. The catalogue ships exactly 6, so this is a count of what survived, not a shortfall against a generous target.');
    RAISERROR(@TcSelectorMsg, 16, 1);
END

-- ---------------------------------------------------------------------------
-- 5. The BOM kit. Each slot binds a GROUP and names a default child, which is
--    what makes the configurator a picker and not a fixed kit.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0001')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0001', 'TCPROD0021', '', 'TCGRP-VARIANTS', 1, N'Variant component', 1, 'TCPROD0002', '', 1, '', '', '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0002')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0002', 'TCPROD0021', '', 'TCGRP-BUNDLES', 1, N'Item type component', 1, 'TCPROD0042', '', 2, '', '', '', '');

-- ---------------------------------------------------------------------------
-- 5b. The Bundles & BOM band owns kits that actually have contents.
--     The ProductBom component is on the PDP and renders zero rows on every
--     product the demo visits, under a visible Package contents heading - so the
--     #1136 fix turned an absent section into an empty one (Foundry #1161).
--
--     The reason is arithmetic: EcomProductItems held FOUR rows in the whole
--     database, two owned by TCPROD0021 and two by sample-data's PACK-BOM-0001.
--     TCPROD0021 is not in the bundling band, and every product in TCGRP-BUNDLES -
--     the group the #1134 re-screening renamed `Bundles & BOM` precisely to
--     demonstrate this capability - owned zero. The section whose purpose is to
--     show bundling was empty on the five products in the bundling group.
--
--     Four of the five Bundle Kit masters become real BOM parents (ProductType 2)
--     with two slots each. TCPROD0041 is deliberately left alone: it is one of the
--     six VARIANT masters, and a product that is both a variant master and a BOM
--     parent is a shape this catalogue does not claim to demonstrate and the gate
--     has never proven.
--
--     Each slot binds a GROUP and names a default child, which is what makes the
--     configurator a picker rather than a fixed kit - the same shape TC-BOM-0001
--     and TC-BOM-0002 already prove on TCPROD0021, column for column. The two
--     slots are chosen so the kit reaches the products the demo path actually
--     visits: a Variants component defaulting into TCGRP-VARIANTS, and a
--     Documentation component defaulting into TCGRP-DOCUMENTS, which is where
--     TCPROD0051 lives.
--
--     WHAT THIS DOES NOT DO, stated so the next census does not read it as a
--     regression: the Package contents band stays EMPTY on TCPROD0001 and
--     TCPROD0051. Neither is a kit, and giving a variant master bill-of-materials
--     rows to make a section non-empty would be seeding for the assert rather than
--     for the demo. The band is proven on the products whose band it is, and the
--     PDP pointer moves to a bundle master when that section is what is being
--     measured.
--
--     Idempotent: the ProductType move is existence-guarded and each slot is
--     guarded on its own ProductItemId.
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ProductType <> 2)
    UPDATE EcomProducts SET ProductType = 2 WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0042-1')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0042-1', 'TCPROD0042', '', 'TCGRP-VARIANTS', 1, N'Variant component', 1, 'TCPROD0002', '', 1, '', '', '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0042-2')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0042-2', 'TCPROD0042', '', 'TCGRP-DOCUMENTS', 1, N'Documentation component', 1, 'TCPROD0051', '', 2, '', '', '', '');
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ProductType <> 2)
    UPDATE EcomProducts SET ProductType = 2 WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0043-1')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0043-1', 'TCPROD0043', '', 'TCGRP-VARIANTS', 1, N'Variant component', 1, 'TCPROD0003', '', 1, '', '', '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0043-2')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0043-2', 'TCPROD0043', '', 'TCGRP-DOCUMENTS', 1, N'Documentation component', 1, 'TCPROD0052', '', 2, '', '', '', '');
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ProductType <> 2)
    UPDATE EcomProducts SET ProductType = 2 WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0044-1')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0044-1', 'TCPROD0044', '', 'TCGRP-VARIANTS', 1, N'Variant component', 1, 'TCPROD0004', '', 1, '', '', '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0044-2')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0044-2', 'TCPROD0044', '', 'TCGRP-DOCUMENTS', 1, N'Documentation component', 1, 'TCPROD0053', '', 2, '', '', '', '');
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ProductType <> 2)
    UPDATE EcomProducts SET ProductType = 2 WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0045-1')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0045-1', 'TCPROD0045', '', 'TCGRP-VARIANTS', 1, N'Variant component', 1, 'TCPROD0005', '', 1, '', '', '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0045-2')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0045-2', 'TCPROD0045', '', 'TCGRP-DOCUMENTS', 1, N'Documentation component', 1, 'TCPROD0054', '', 2, '', '', '', '');

-- THE BOM GUARD. A row count over the whole table was green on the state this
-- section fixes - four rows existed, none of them in the band that advertises the
-- capability. So the assertion is per GROUP: the bundling band must own at least
-- four BOM parents, and no BOM parent anywhere may carry fewer than two slots.
DECLARE @TcBundleKits INT = (
    SELECT COUNT(DISTINCT p.ProductId)
      FROM EcomProducts p
      JOIN EcomGroupProductRelation g ON g.GroupProductRelationProductId = p.ProductId
     WHERE g.GroupProductRelationGroupId = 'TCGRP-BUNDLES'
       AND p.ProductVariantId = '' AND p.ProductLanguageId = 'ENU'
       AND (SELECT COUNT(*) FROM EcomProductItems i WHERE i.ProductItemProductId = p.ProductId) >= 2);
IF @TcBundleKits < 4
BEGIN
    DECLARE @TcBomMsg NVARCHAR(600) = CONCAT(N'truvio-catalog.sql: only ', @TcBundleKits,
        N' product(s) in TCGRP-BUNDLES carry two or more BOM slots, against 4 required. The Bundles & BOM band exists to demonstrate bundling, and the PDP Package contents section renders a heading over an empty table on every product in it - which is worse than the section being absent, and just as silent.');
    RAISERROR(@TcBomMsg, 16, 1);
END

DECLARE @TcThinKits INT = (
    SELECT COUNT(*) FROM (
        SELECT i.ProductItemProductId
          FROM EcomProductItems i
         WHERE i.ProductItemProductId LIKE 'TCPROD%'
         GROUP BY i.ProductItemProductId
        HAVING COUNT(*) < 2) x);
IF @TcThinKits > 0
    RAISERROR(N'truvio-demo: a BOM parent carries fewer than two slots. A one-slot kit is a product with an accessory, not a configurator, and the Package contents table reads as a mistake.', 16, 1);

-- ---------------------------------------------------------------------------
-- 6. Prices: the quantity-tier ladder and the one contract row.
--    Contract pricing resolves by PriceUserCustomerNumber, never by
--    PriceCustomerGroupId - the group columns stay empty.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-T05')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-T05', 'TCPROD0006', '', 'EUR', 5, 40.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-T10')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-T10', 'TCPROD0006', '', 'EUR', 10, 36.00, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-T25')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-T25', 'TCPROD0006', '', 'EUR', 25, 31.50, '', '');
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CONTRACT')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('TC-PRICE-CONTRACT', 'TCPROD0002', '', 'EUR', 1, 48.00, '', 'TC-100200');

-- ---------------------------------------------------------------------------
-- 7. Product categories and their fields - one category per TOP group, seven
--    fields each, every name from the same platform vocabulary. Category field
--    values are ROW-BACKED (EcomProductCategoryFieldValue): no DDL, no schema
--    change, which is why a demo catalogue can ship them as plain inserts.
--
--    The column names below are READ OFF sys.columns on a DW 10.28.10 host, not
--    inferred from the naming convention. Inferring them is exactly what went
--    wrong once: EcomProductCategoryField is FieldType (not FieldTypeId) and
--    FieldSortOrder (not FieldSort), it carries NO locked column at all, and
--    FieldTemplateTag is NOT NULL. The platform sets FieldTemplateTag to the
--    field's own system name verbatim (every row on every reference seed
--    measured: FieldTemplateTag = FieldId), so each insert supplies the FieldId
--    twice rather than deriving anything at read time.
--
--    A platform whose columns differ must FAIL HERE, loudly, rather than seed a
--    catalogue with no attributes on it - so the shape is asserted first, and the
--    guard asserts the REAL names: a guard spelled from the same wrong guess as
--    the insert passes and then the insert fails at compile time with Msg 207,
--    which is what happened before this fix.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.EcomProductCategory', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EcomProductCategoryTranslation', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EcomProductCategoryField', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EcomProductCategoryFieldTranslation', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EcomProductCategoryFieldValue', N'U') IS NULL
    RAISERROR(N'truvio-catalog.sql: a product-category table is missing. The brand catalogue ships category fields; this platform build does not carry the category schema.', 16, 1);
IF COL_LENGTH('EcomProductCategoryField', 'FieldId') IS NULL
   OR COL_LENGTH('EcomProductCategoryField', 'FieldCategoryId') IS NULL
   OR COL_LENGTH('EcomProductCategoryField', 'FieldTemplateTag') IS NULL
   OR COL_LENGTH('EcomProductCategoryField', 'FieldType') IS NULL
   OR COL_LENGTH('EcomProductCategoryField', 'FieldSortOrder') IS NULL
   OR COL_LENGTH('EcomProductCategoryFieldTranslation', 'FieldTranslationFieldId') IS NULL
   OR COL_LENGTH('EcomProductCategoryFieldValue', 'FieldValueFieldId') IS NULL
   OR COL_LENGTH('EcomProductCategoryFieldValue', 'FieldValueValue') IS NULL
    RAISERROR(N'truvio-catalog.sql: the product-category FIELD columns are not the expected shape (FieldId / FieldCategoryId / FieldTemplateTag / FieldType / FieldSortOrder / FieldTranslationFieldId / FieldValueFieldId / FieldValueValue). Read the live column names off sys.columns and update this section - do NOT let it seed a catalogue with no attributes.', 16, 1);

IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_data_models', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_data_models' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_data_models', 'ENU', N'Data Models');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcUnitOfMeasure' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'tcUnitOfMeasure', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcUnitOfMeasure' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'ENU', N'Unit of Measure');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcPackQuantity' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcPackQuantity', 'tc_data_models', 'tcPackQuantity', 6, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcPackQuantity' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcPackQuantity', 'tc_data_models', 'ENU', N'Pack Quantity');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcNetWeight' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcNetWeight', 'tc_data_models', 'tcNetWeight', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcNetWeight' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcNetWeight', 'tc_data_models', 'ENU', N'Net Weight');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcDimensions' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcDimensions', 'tc_data_models', 'tcDimensions', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcDimensions' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcDimensions', 'tc_data_models', 'ENU', N'Dimensions');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcMaterialClass' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcMaterialClass', 'tc_data_models', 'tcMaterialClass', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcMaterialClass' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcMaterialClass', 'tc_data_models', 'ENU', N'Material Class');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcRating' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcRating', 'tc_data_models', 'tcRating', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcRating' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcRating', 'tc_data_models', 'ENU', N'Rating');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCompatibility' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCompatibility', 'tc_data_models', 'tcCompatibility', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCompatibility' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCompatibility', 'tc_data_models', 'ENU', N'Compatibility');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_commerce', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_commerce' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_commerce', 'ENU', N'Commerce');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcPriceUnit' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcPriceUnit', 'tc_commerce', 'tcPriceUnit', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcPriceUnit' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcPriceUnit', 'tc_commerce', 'ENU', N'Price Unit');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcMinimumOrderQuantity' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'tcMinimumOrderQuantity', 6, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcMinimumOrderQuantity' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'ENU', N'Minimum Order Quantity');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcQuantityBreak' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcQuantityBreak', 'tc_commerce', 'tcQuantityBreak', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcQuantityBreak' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcQuantityBreak', 'tc_commerce', 'ENU', N'Quantity Break');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcVatGroup' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcVatGroup', 'tc_commerce', 'tcVatGroup', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcVatGroup' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcVatGroup', 'tc_commerce', 'ENU', N'VAT Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcDeliveryLeadTime' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcDeliveryLeadTime', 'tc_commerce', 'tcDeliveryLeadTime', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcDeliveryLeadTime' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcDeliveryLeadTime', 'tc_commerce', 'ENU', N'Delivery Lead Time');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcWarrantyTerm' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcWarrantyTerm', 'tc_commerce', 'tcWarrantyTerm', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcWarrantyTerm' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcWarrantyTerm', 'tc_commerce', 'ENU', N'Warranty Term');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcReturnWindow' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcReturnWindow', 'tc_commerce', 'tcReturnWindow', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcReturnWindow' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcReturnWindow', 'tc_commerce', 'ENU', N'Return Window');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_content')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_content', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_content' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_content', 'ENU', N'Content');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcDocumentSet' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcDocumentSet', 'tc_content', 'tcDocumentSet', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcDocumentSet' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcDocumentSet', 'tc_content', 'ENU', N'Document Set');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcMediaSet' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcMediaSet', 'tc_content', 'tcMediaSet', 1, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcMediaSet' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcMediaSet', 'tc_content', 'ENU', N'Media Set');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcRevision' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcRevision', 'tc_content', 'tcRevision', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcRevision' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcRevision', 'tc_content', 'ENU', N'Revision');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcDatasheetCode' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcDatasheetCode', 'tc_content', 'tcDatasheetCode', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcDatasheetCode' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcDatasheetCode', 'tc_content', 'ENU', N'Datasheet Code');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCertification' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCertification', 'tc_content', 'tcCertification', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCertification' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCertification', 'tc_content', 'ENU', N'Certification');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcLanguageCoverage' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcLanguageCoverage', 'tc_content', 'tcLanguageCoverage', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcLanguageCoverage' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcLanguageCoverage', 'tc_content', 'ENU', N'Language Coverage');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCatalogueSection' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCatalogueSection', 'tc_content', 'tcCatalogueSection', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCatalogueSection' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCatalogueSection', 'tc_content', 'ENU', N'Catalogue Section');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_users')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_users', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_users' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_users', 'ENU', N'Users');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcAssortmentScope' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcAssortmentScope', 'tc_users', 'tcAssortmentScope', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcAssortmentScope' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcAssortmentScope', 'tc_users', 'ENU', N'Assortment Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCustomerNumber' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCustomerNumber', 'tc_users', 'tcCustomerNumber', 1, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCustomerNumber' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCustomerNumber', 'tc_users', 'ENU', N'Customer Number');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcAccountTerms' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcAccountTerms', 'tc_users', 'tcAccountTerms', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcAccountTerms' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcAccountTerms', 'tc_users', 'ENU', N'Account Terms');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCurrencyScope' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCurrencyScope', 'tc_users', 'tcCurrencyScope', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCurrencyScope' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCurrencyScope', 'tc_users', 'ENU', N'Currency Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcContractScope' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcContractScope', 'tc_users', 'tcContractScope', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcContractScope' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcContractScope', 'tc_users', 'ENU', N'Contract Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcStockStatus' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcStockStatus', 'tc_users', 'tcStockStatus', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcStockStatus' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcStockStatus', 'tc_users', 'ENU', N'Stock Status');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcOrderChannel' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcOrderChannel', 'tc_users', 'tcOrderChannel', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcOrderChannel' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcOrderChannel', 'tc_users', 'ENU', N'Order Channel');

-- The first three fields of each category on every master (180 rows). The other
-- four per product are filled by truvio-pdp.sql, which takes the specification
-- table to seven values of seven on every page.
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0001' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0001', '', 'ENU', N'Each');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0001' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0001', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0001' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0001', '', 'ENU', N'0.55 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0002' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0002', '', 'ENU', N'Metre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0002' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0002', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0002' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0002', '', 'ENU', N'0.70 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0003' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0003', '', 'ENU', N'Pack of 10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0003' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0003', '', 'ENU', N'10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0003' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0003', '', 'ENU', N'0.85 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0004' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0004', '', 'ENU', N'Kilogram');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0004' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0004', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0004' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0004', '', 'ENU', N'1.00 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0005' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0005', '', 'ENU', N'Litre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0005' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0005', '', 'ENU', N'25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0005' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0005', '', 'ENU', N'1.15 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0006' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0006', '', 'ENU', N'Per each');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0006' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0006', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0006' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0006', '', 'ENU', N'5 / 10 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0007' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0007', '', 'ENU', N'Per metre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0007' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0007', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0007' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0007', '', 'ENU', N'5 / 10 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0008' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0008', '', 'ENU', N'Per pack of 10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0008' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0008', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0008' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0008', '', 'ENU', N'10 / 25 / 50');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0009' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0009', '', 'ENU', N'Per kilogram');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0009' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0009', '', 'ENU', N'2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0009' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0009', '', 'ENU', N'No break');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0010' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0010', '', 'ENU', N'Per litre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0010' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0010', '', 'ENU', N'10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0010' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0010', '', 'ENU', N'5 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0011' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0011', '', 'ENU', N'Each');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0011' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0011', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0011' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0011', '', 'ENU', N'0.70 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0012' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0012', '', 'ENU', N'Metre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0012' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0012', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0012' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0012', '', 'ENU', N'0.85 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0013' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0013', '', 'ENU', N'Pack of 10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0013' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0013', '', 'ENU', N'10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0013' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0013', '', 'ENU', N'1.00 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0014' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0014', '', 'ENU', N'Kilogram');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0014' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0014', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0014' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0014', '', 'ENU', N'1.15 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0015' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0015', '', 'ENU', N'Litre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0015' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0015', '', 'ENU', N'25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0015' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0015', '', 'ENU', N'1.30 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0016' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0016', '', 'ENU', N'Per each');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0016' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0016', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0016' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0016', '', 'ENU', N'5 / 10 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0017' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0017', '', 'ENU', N'Per metre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0017' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0017', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0017' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0017', '', 'ENU', N'5 / 10 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0018' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0018', '', 'ENU', N'Per pack of 10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0018' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0018', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0018' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0018', '', 'ENU', N'10 / 25 / 50');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0019' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0019', '', 'ENU', N'Per kilogram');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0019' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0019', '', 'ENU', N'2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0019' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0019', '', 'ENU', N'No break');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0020' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0020', '', 'ENU', N'Per litre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0020' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0020', '', 'ENU', N'10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0020' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0020', '', 'ENU', N'5 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0021' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0021', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0021' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0021', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0021' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0021', '', 'ENU', N'Net 30');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0022' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0022', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0022' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0022', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0022' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0022', '', 'ENU', N'Net 30');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0023' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0023', '', 'ENU', N'Open catalogue');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0023' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0023', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0023' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0023', '', 'ENU', N'Net 45');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0024' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0024', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0024' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0024', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0024' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0024', '', 'ENU', N'Net 14');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0025' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0025', '', 'ENU', N'Named account only');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0025' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0025', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0025' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0025', '', 'ENU', N'Prepaid');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0026' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0026', '', 'ENU', N'Per each');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0026' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0026', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0026' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0026', '', 'ENU', N'5 / 10 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0027' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0027', '', 'ENU', N'Per metre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0027' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0027', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0027' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0027', '', 'ENU', N'5 / 10 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0028' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0028', '', 'ENU', N'Per pack of 10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0028' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0028', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0028' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0028', '', 'ENU', N'10 / 25 / 50');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0029' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0029', '', 'ENU', N'Per kilogram');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0029' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0029', '', 'ENU', N'2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0029' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0029', '', 'ENU', N'No break');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceUnit' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0030' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceUnit', 'tc_commerce', 'TCPROD0030', '', 'ENU', N'Per litre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMinimumOrderQuantity' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0030' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMinimumOrderQuantity', 'tc_commerce', 'TCPROD0030', '', 'ENU', N'10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityBreak' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0030' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityBreak', 'tc_commerce', 'TCPROD0030', '', 'ENU', N'5 / 25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0031' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0031', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0031' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0031', '', 'ENU', N'Tile, product frame, detail shot');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0031' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0031', '', 'ENU', N'Rev A.1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0032' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0032', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0032' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0032', '', 'ENU', N'Product frame, tile');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0032' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0032', '', 'ENU', N'Rev B.1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0033' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0033', '', 'ENU', N'Datasheet only');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0033' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0033', '', 'ENU', N'Tile, product frame');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0033' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0033', '', 'ENU', N'Rev C.1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0034' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0034', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0034' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0034', '', 'ENU', N'Tile, product frame, detail shot');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0034' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0034', '', 'ENU', N'Rev D.1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0035' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0035', '', 'ENU', N'Datasheet, install guide, certificate');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0035' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0035', '', 'ENU', N'Tile, product frame');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0035' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0035', '', 'ENU', N'Rev E.1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0036' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0036', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0036' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0036', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0036' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0036', '', 'ENU', N'Net 30');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0037' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0037', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0037' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0037', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0037' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0037', '', 'ENU', N'Net 30');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0038' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0038', '', 'ENU', N'Open catalogue');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0038' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0038', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0038' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0038', '', 'ENU', N'Net 45');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0039' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0039', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0039' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0039', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0039' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0039', '', 'ENU', N'Net 14');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0040' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0040', '', 'ENU', N'Named account only');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0040' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0040', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0040' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0040', '', 'ENU', N'Prepaid');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0041' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0041', '', 'ENU', N'Each');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0041' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0041', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0041' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0041', '', 'ENU', N'1.15 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0042' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0042', '', 'ENU', N'Metre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0042' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0042', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0042' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0042', '', 'ENU', N'1.30 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0043' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0043', '', 'ENU', N'Pack of 10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0043' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0043', '', 'ENU', N'10');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0043' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0043', '', 'ENU', N'1.45 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0044' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0044', '', 'ENU', N'Kilogram');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0044' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0044', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0044' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0044', '', 'ENU', N'1.60 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUnitOfMeasure' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0045' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUnitOfMeasure', 'tc_data_models', 'TCPROD0045', '', 'ENU', N'Litre');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPackQuantity' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0045' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPackQuantity', 'tc_data_models', 'TCPROD0045', '', 'ENU', N'25');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNetWeight' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0045' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNetWeight', 'tc_data_models', 'TCPROD0045', '', 'ENU', N'0.40 kg');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0046' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0046', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0046' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0046', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0046' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0046', '', 'ENU', N'Net 30');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0047' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0047', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0047' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0047', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0047' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0047', '', 'ENU', N'Net 30');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0048' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0048', '', 'ENU', N'Open catalogue');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0048' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0048', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0048' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0048', '', 'ENU', N'Net 45');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0049' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0049', '', 'ENU', N'Account assortment');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0049' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0049', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0049' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0049', '', 'ENU', N'Net 14');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0050' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_users', 'TCPROD0050', '', 'ENU', N'Named account only');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0050' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0050', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccountTerms' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0050' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccountTerms', 'tc_users', 'TCPROD0050', '', 'ENU', N'Prepaid');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0051' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0051', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0051' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0051', '', 'ENU', N'Tile, product frame, detail shot');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0051' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0051', '', 'ENU', N'Rev A.2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0052' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0052', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0052' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0052', '', 'ENU', N'Product frame, tile');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0052' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0052', '', 'ENU', N'Rev B.2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0053' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0053', '', 'ENU', N'Datasheet only');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0053' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0053', '', 'ENU', N'Tile, product frame');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0053' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0053', '', 'ENU', N'Rev C.2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0054' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0054', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0054' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0054', '', 'ENU', N'Tile, product frame, detail shot');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0054' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0054', '', 'ENU', N'Rev D.2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0055' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0055', '', 'ENU', N'Datasheet, install guide, certificate');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0055' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0055', '', 'ENU', N'Tile, product frame');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0055' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0055', '', 'ENU', N'Rev E.2');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0056' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0056', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0056' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0056', '', 'ENU', N'Tile, product frame, detail shot');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0056' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0056', '', 'ENU', N'Rev A.3');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0057' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0057', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0057' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0057', '', 'ENU', N'Product frame, tile');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0057' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0057', '', 'ENU', N'Rev B.3');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0058' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0058', '', 'ENU', N'Datasheet only');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0058' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0058', '', 'ENU', N'Tile, product frame');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0058' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0058', '', 'ENU', N'Rev C.3');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0059' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0059', '', 'ENU', N'Datasheet and install guide');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0059' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0059', '', 'ENU', N'Tile, product frame, detail shot');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0059' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0059', '', 'ENU', N'Rev D.3');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDocumentSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0060' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDocumentSet', 'tc_content', 'TCPROD0060', '', 'ENU', N'Datasheet, install guide, certificate');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcMediaSet' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0060' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcMediaSet', 'tc_content', 'TCPROD0060', '', 'ENU', N'Tile, product frame');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcRevision' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0060' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcRevision', 'tc_content', 'TCPROD0060', '', 'ENU', N'Rev E.3');

-- ---------------------------------------------------------------------------
-- 7b. Long descriptions - one per master, so the PDP has a body.
--    The PDP carries a full-width Overview band (surface-swift's
--    Swift-v2_ProductLongDescription paragraph). 1.0.0 shipped short descriptions
--    and nothing else, so the band rendered at height 0 on every product and the
--    v5 e2e measured the detail page collapsing to 84 characters of main text.
--    Every master now carries two or three sentences in the same
--    platform-vocabulary voice the names use: what the concept is, what THIS row
--    demonstrates, and what a prospect can do with it on the page.
--
--    Stored in EcomProducts.ProductLongDescription, beside the short description
--    the masters already carry. The column is asserted first, in this file's own
--    idiom - a platform that spells it differently must fail loudly rather than
--    seed 60 empty detail pages.
--
--    Guarded on ABSENCE, not on difference: a host whose copy has been edited
--    keeps the edit, and a host seeded by 1.0.x - where the column is empty - is
--    filled on the next run. Variant rows inherit the master's body, so only the
--    60 masters are written.
-- ---------------------------------------------------------------------------
IF COL_LENGTH('EcomProducts', 'ProductLongDescription') IS NULL
    RAISERROR(N'truvio-catalog.sql: EcomProducts.ProductLongDescription is missing. The PDP Overview band reads this column; do NOT let this script seed 60 products with no detail-page body.', 16, 1);

IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A variant master carries the axes and the option rows that hang off them, and every combination is a product row of its own with its own price. This master demonstrates the plain two-axis case: a tier axis and a mode axis, expanded into the full grid of combinations. Open the tier and mode selectors on this page to watch the price, the number and the stock position change without leaving the record.' WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A variant master carries the axes and the option rows that hang off them, and every combination is a product row of its own with its own price. This master is the one carrying a customer-scoped contract price, so a signed-in B2B account sees a different number on the same row. Open the tier and mode selectors on this page to watch the price, the number and the stock position change without leaving the record.' WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A variant master carries the axes and the option rows that hang off them, and every combination is a product row of its own with its own price. This master shows the price stepping per tier while the mode axis leaves it untouched, which is how a real option matrix usually behaves. Open the tier and mode selectors on this page to watch the price, the number and the stock position change without leaving the record.' WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A variant master carries the axes and the option rows that hang off them, and every combination is a product row of its own with its own price. This master shows an option set that is deeper than it is wide, the shape a configurable product tends to take. Open the tier and mode selectors on this page to watch the price, the number and the stock position change without leaving the record.' WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A variant master carries the axes and the option rows that hang off them, and every combination is a product row of its own with its own price. This master is the control row: same band, same fields, no variants on it, so the difference in the detail page is easy to point at. Open the tier and mode selectors on this page to watch the price, the number and the stock position change without leaving the record.' WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Stock is a number a buyer acts on, so the row carries a real level, a delivery text and a policy for what happens at zero. This row holds a healthy level and ships from the default location the same day. The count, the status colour and the delivery line all come from the same product row you are looking at.' WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Stock is a number a buyer acts on, so the row carries a real level, a delivery text and a policy for what happens at zero. This row sits low on purpose, so the storefront shows the count rather than a reassuring word. The count, the status colour and the delivery line all come from the same product row you are looking at.' WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Stock is a number a buyer acts on, so the row carries a real level, a delivery text and a policy for what happens at zero. This row is at zero and is never-out-of-stock, so it stays orderable against an expected delivery date. The count, the status colour and the delivery line all come from the same product row you are looking at.' WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Stock is a number a buyer acts on, so the row carries a real level, a delivery text and a policy for what happens at zero. This row splits its level across three stock locations, which is what a multi-warehouse read looks like. The count, the status colour and the delivery line all come from the same product row you are looking at.' WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Stock is a number a buyer acts on, so the row carries a real level, a delivery text and a policy for what happens at zero. This row carries a long lead time, so the delivery line rather than the count is what a buyer reads. The count, the status colour and the delivery line all come from the same product row you are looking at.' WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A unit of measure decides what a price and a quantity actually mean, and the add-to-cart selector is where a buyer chooses one. This row prices per piece and steps in single units, the plain case every other row is measured against. Open the unit selector on this page and watch the quantity step, the price unit and the line total move together.' WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A unit of measure decides what a price and a quantity actually mean, and the add-to-cart selector is where a buyer chooses one. This row prices per metre, so the quantity field and the line total both read in length. Open the unit selector on this page and watch the quantity step, the price unit and the line total move together.' WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A unit of measure decides what a price and a quantity actually mean, and the add-to-cart selector is where a buyer chooses one. This service row converts between two units, which is how a catalogue keeps one price and two ways of buying it. Open the unit selector on this page and watch the quantity step, the price unit and the line total move together.' WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A unit of measure decides what a price and a quantity actually mean, and the add-to-cart selector is where a buyer chooses one. This row sells in a pack, so the pack quantity and the unit price are different numbers on the same card. Open the unit selector on this page and watch the quantity step, the price unit and the line total move together.' WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A unit of measure decides what a price and a quantity actually mean, and the add-to-cart selector is where a buyer chooses one. This row prices per kilogram against a net weight, so the spec table and the price agree. Open the unit selector on this page and watch the quantity step, the price unit and the line total move together.' WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price structure is the set of rows that answer one question - what does this product cost, for this customer, at this quantity, in this currency. This record carries the quantity ladder, so buying five, ten or twenty-five resolves to three different unit prices. Resolution is ordered and deterministic: the most specific row that matches the request wins, and nothing about it is hard-coded in a template.' WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price structure is the set of rows that answer one question - what does this product cost, for this customer, at this quantity, in this currency. This record shows the plain list price with nothing layered on it, which is the baseline the other rows are read against. Resolution is ordered and deterministic: the most specific row that matches the request wins, and nothing about it is hard-coded in a template.' WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price structure is the set of rows that answer one question - what does this product cost, for this customer, at this quantity, in this currency. This record shows a currency-scoped row, the shape a price takes when a solution sells in more than one currency. Resolution is ordered and deterministic: the most specific row that matches the request wins, and nothing about it is hard-coded in a template.' WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price structure is the set of rows that answer one question - what does this product cost, for this customer, at this quantity, in this currency. This record shows a customer-scoped row, resolved by customer number rather than by group. Resolution is ordered and deterministic: the most specific row that matches the request wins, and nothing about it is hard-coded in a template.' WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price structure is the set of rows that answer one question - what does this product cost, for this customer, at this quantity, in this currency. This record is the comparison row: same product shape, no special pricing, so the resolution order is easy to demonstrate. Resolution is ordered and deterministic: the most specific row that matches the request wins, and nothing about it is hard-coded in a template.' WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'An assortment is the scoped slice of the catalogue a given customer, shop or user group is allowed to see and buy. This record is a bill-of-materials parent: pick one component from the Variants band and one from the Item Types band, then add the configured kit to the cart. Scoping happens before rendering, so an unscoped product is absent from the list, the search index and the direct URL alike.' WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'An assortment is the scoped slice of the catalogue a given customer, shop or user group is allowed to see and buy. This record is scoped to the demo B2B account, so it is present for a signed-in buyer and absent for everyone else. Scoping happens before rendering, so an unscoped product is absent from the list, the search index and the direct URL alike.' WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'An assortment is the scoped slice of the catalogue a given customer, shop or user group is allowed to see and buy. This record is in the open scope, reachable by an anonymous visitor, which is the contrast the previous row needs. Scoping happens before rendering, so an unscoped product is absent from the list, the search index and the direct URL alike.' WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'An assortment is the scoped slice of the catalogue a given customer, shop or user group is allowed to see and buy. This record sits in two scopes at once, which is the case that decides whether an assortment is a filter or a union. Scoping happens before rendering, so an unscoped product is absent from the list, the search index and the direct URL alike.' WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'An assortment is the scoped slice of the catalogue a given customer, shop or user group is allowed to see and buy. This record is the comparison row: same band, no scoping applied, so the effect of scoping is visible by difference. Scoping happens before rendering, so an unscoped product is absent from the list, the search index and the direct URL alike.' WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A discount ladder is a set of conditions and rewards the order engine evaluates on every cart recalculation. This record carries a straight percentage reward, the simplest rung of the ladder. Conditions and rewards are configured rather than written, so a campaign is authored by a merchandiser and takes effect on the next request.' WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A discount ladder is a set of conditions and rewards the order engine evaluates on every cart recalculation. This record carries an amount-off reward, which behaves differently from a percentage once a cart has several lines. Conditions and rewards are configured rather than written, so a campaign is authored by a merchandiser and takes effect on the next request.' WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A discount ladder is a set of conditions and rewards the order engine evaluates on every cart recalculation. This record carries a quantity-triggered reward, evaluated per line rather than per order. Conditions and rewards are configured rather than written, so a campaign is authored by a merchandiser and takes effect on the next request.' WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A discount ladder is a set of conditions and rewards the order engine evaluates on every cart recalculation. This record carries an order-level reward, evaluated once the whole cart has been totalled. Conditions and rewards are configured rather than written, so a campaign is authored by a merchandiser and takes effect on the next request.' WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A discount ladder is a set of conditions and rewards the order engine evaluates on every cart recalculation. This record is the comparison row: no discount touches it, so the difference on the cart page is unambiguous. Conditions and rewards are configured rather than written, so a campaign is authored by a merchandiser and takes effect on the next request.' WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A product gallery is several images on one record, one of them default, the rest reachable from the thumbnails. This row carries the full gallery: the concept tile, a photographic frame and a detail shot. Step through the thumbnails on this page: the default image is the one the product list card shows.' WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A product gallery is several images on one record, one of them default, the rest reachable from the thumbnails. This row leads with the photographic frame, so the card and the detail page do not open on the same picture. Step through the thumbnails on this page: the default image is the one the product list card shows.' WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A product gallery is several images on one record, one of them default, the rest reachable from the thumbnails. This row keeps two images only, which is the shortest gallery the thumbnail strip still renders. Step through the thumbnails on this page: the default image is the one the product list card shows.' WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A product gallery is several images on one record, one of them default, the rest reachable from the thumbnails. This row shares its photographic frame with the rest of its band, which is how a range reads as a range. Step through the thumbnails on this page: the default image is the one the product list card shows.' WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A product gallery is several images on one record, one of them default, the rest reachable from the thumbnails. This row pairs a flat concept tile with a lit product frame, the two registers a catalogue mixes. Step through the thumbnails on this page: the default image is the one the product list card shows.' WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price is a number and a currency, and a VAT group decides whether the shopper reads it with tax or without. This row sits in the standard VAT group, so the storefront figure includes tax at the default rate. The currency, the rate and the VAT group that produced the figure on this page are all in the specification table below.' WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price is a number and a currency, and a VAT group decides whether the shopper reads it with tax or without. This row is in the reduced group, which is where a catalogue with mixed rates starts to matter. The currency, the rate and the VAT group that produced the figure on this page are all in the specification table below.' WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price is a number and a currency, and a VAT group decides whether the shopper reads it with tax or without. This row is priced in the default currency and read in the served one, the conversion the rate column drives. The currency, the rate and the VAT group that produced the figure on this page are all in the specification table below.' WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price is a number and a currency, and a VAT group decides whether the shopper reads it with tax or without. This row carries an explicit price per currency rather than a converted one, which is what a fixed price list is. The currency, the rate and the VAT group that produced the figure on this page are all in the specification table below.' WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A price is a number and a currency, and a VAT group decides whether the shopper reads it with tax or without. This row is zero-rated, so the with-tax and without-tax figures are the same and the difference is visible by its absence. The currency, the rate and the VAT group that produced the figure on this page are all in the specification table below.' WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A bundle is a product whose contents are other products, listed on the page and priced as a kit. This kit fixes its members, so the package-contents list is the same for every buyer. The package-contents section on this page lists every member as a full row, with its own number, stock and price.' WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A bundle is a product whose contents are other products, listed on the page and priced as a kit. This kit binds a group rather than a product, so a buyer picks the member and the kit configures itself. The package-contents section on this page lists every member as a full row, with its own number, stock and price.' WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A bundle is a product whose contents are other products, listed on the page and priced as a kit. This kit names a default member and allows a swap, which is the middle ground between fixed and configurable. The package-contents section on this page lists every member as a full row, with its own number, stock and price.' WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A bundle is a product whose contents are other products, listed on the page and priced as a kit. This kit carries a required slot and an optional one, so the page shows what can and cannot be dropped. The package-contents section on this page lists every member as a full row, with its own number, stock and price.' WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A bundle is a product whose contents are other products, listed on the page and priced as a kit. This kit relates to its members both ways, so a member page points back at the kit it belongs to. The package-contents section on this page lists every member as a full row, with its own number, stock and price.' WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A contract price is a number agreed with one account, resolved by customer number and shown only to that account. This row carries a contract price against the demo account, so the signed-in figure is below the list figure. Sign in as the demo buyer and compare the figure on this page with the list price beside it.' WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A contract price is a number agreed with one account, resolved by customer number and shown only to that account. This row is priced by customer group instead, which is how a whole dealer tier gets one rate. Sign in as the demo buyer and compare the figure on this page with the list price beside it.' WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A contract price is a number agreed with one account, resolved by customer number and shown only to that account. This row carries both, so the narrower customer-number price wins and the group price is what it beats. Sign in as the demo buyer and compare the figure on this page with the list price beside it.' WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A contract price is a number agreed with one account, resolved by customer number and shown only to that account. This row has a contract price with a validity window, which is what a seasonal agreement looks like. Sign in as the demo buyer and compare the figure on this page with the list price beside it.' WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'A contract price is a number agreed with one account, resolved by customer number and shown only to that account. This row has no agreement at all and is the control: list price signed in and signed out alike. Sign in as the demo buyer and compare the figure on this page with the list price beside it.' WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Documents hang off a product as an asset category, so a datasheet and an install guide are rows on the record, not links in the copy. This row carries the full document set: a datasheet and an install guide, both downloadable from the page. The documents table on this page lists each file with its name, its type and its size.' WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Documents hang off a product as an asset category, so a datasheet and an install guide are rows on the record, not links in the copy. This row keeps its datasheet current at a named revision, which is what a document table''s revision column is for. The documents table on this page lists each file with its name, its type and its size.' WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Documents hang off a product as an asset category, so a datasheet and an install guide are rows on the record, not links in the copy. This service row documents a procedure rather than an object, and the table renders it the same way. The documents table on this page lists each file with its name, its type and its size.' WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Documents hang off a product as an asset category, so a datasheet and an install guide are rows on the record, not links in the copy. This row shares its install guide with the rest of its band, which is how a range documents a common fitting. The documents table on this page lists each file with its name, its type and its size.' WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Documents hang off a product as an asset category, so a datasheet and an install guide are rows on the record, not links in the copy. This row carries a certification alongside the datasheet, so the compliance question is answered on the page. The documents table on this page lists each file with its name, its type and its size.' WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Related products are rows on the record: accessories, spares and alternatives, each in its own relation group. This row relates to three accessories, which is what the ''you will also need'' strip is built from. The related-products strip at the foot of this page is built from those rows and from nothing else.' WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Related products are rows on the record: accessories, spares and alternatives, each in its own relation group. This row relates to its spares, so a buyer who owns it can reorder a part without searching. The related-products strip at the foot of this page is built from those rows and from nothing else.' WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Related products are rows on the record: accessories, spares and alternatives, each in its own relation group. This row relates to an alternative in the same band, which is how a catalogue offers a substitute. The related-products strip at the foot of this page is built from those rows and from nothing else.' WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Related products are rows on the record: accessories, spares and alternatives, each in its own relation group. This row is a member of a kit and relates back to it, so the relationship reads from both ends. The related-products strip at the foot of this page is built from those rows and from nothing else.' WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '')
    UPDATE EcomProducts SET ProductLongDescription = N'Related products are rows on the record: accessories, spares and alternatives, each in its own relation group. This row carries relations in two groups at once, so the page renders two distinct strips rather than one mixed list. The related-products strip at the foot of this page is built from those rows and from nothing else.' WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductLongDescription, '') = '';
-- ---------------------------------------------------------------------------
-- 7c. The field display group the PDP spec table reads.
--    Swift's spec paragraph (Swift-v2_ProductFieldDisplayGroups) does NOT bind a
--    product category. Its DisplayGroups field takes FIELD DISPLAY GROUP system
--    names, resolved by the item type's own option query against
--    EcomFieldDisplayGroups / EcomFieldDisplayGroupTranslation. So the 28 tc_*
--    category fields and their 180 values were never enough on their own: with no
--    display group in the database the paragraph has nothing to name, which is why
--    surface-swift 1.5.0 removed the band as permanently empty and why the v5 e2e
--    measured no spec element on the PDP at all.
--
--    This section supplies the missing half. One group, `tc_specs`, holding every
--    tc_* category field; surface-swift's restored paragraph names it. A product
--    renders only the fields it actually carries a value for, so one group serves
--    all four categories without showing three empty ones on every page.
--
--    Column names read off sys.columns on the DW 10.28.10 e2e host, not inferred -
--    the same discipline section 7 states, and for the same reason. Note the shape:
--    FieldDisplayGroupId is an INT IDENTITY, so the group is addressed by its
--    SYSTEM NAME everywhere and the id is looked up, never asserted.
--    EcomFieldDisplayGroupFields is the normalised relation; the group's own
--    FieldDisplayGroupFieldIds column is the denormalised list the backend keeps
--    beside it, and it is written from the relation rather than typed, so the two
--    can never disagree.
--
--    A GROUP THAT EXISTS IS NOT A GROUP THAT RESOLVES. 1.1.0 seeded this group
--    correctly and the v5 e2e still measured an empty table: the members were
--    written as bare category FieldIds, and a bare member name resolves against
--    GLOBAL product fields (EcomProductField, which is empty on this host and on
--    any host this layer composes) rather than against category fields. A category
--    field is referenced in the qualified pipe form
--    ProductCategory|<FieldCategoryId>|<FieldId>, stated and evidenced at the
--    INSERT below. The band rendered a heading over nothing, silently, with zero
--    dw-errors and every row count correct - which is why this section now ends in
--    a RESOLUTION guard that counts values reached through the platform's own join
--    path, not only the column-shape guard that was green throughout.
--
--    Idempotent: the group, its translation and each field relation are
--    IF NOT EXISTS-guarded on their own key, and the frontend flag and the
--    denormalised list are existence-guarded UPDATEs so a host seeded before this
--    section converges instead of keeping a half-wired group. A host carrying the
--    1.1.0 bare names is rewritten to the qualified form in place, so it converges
--    rather than accumulating a second set of members that do not resolve.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo.EcomFieldDisplayGroups', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EcomFieldDisplayGroupTranslation', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EcomFieldDisplayGroupFields', N'U') IS NULL
    RAISERROR(N'truvio-catalog.sql: a field-display-group table is missing. The PDP spec table reads these; this platform build does not carry the display-group schema.', 16, 1);
IF COL_LENGTH('EcomFieldDisplayGroups', 'FieldDisplayGroupId') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroups', 'FieldDisplayGroupSystemName') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroups', 'FieldDisplayGroupName') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroups', 'FieldDisplayGroupSortIndex') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroups', 'FieldDisplayGroupAvailableInFrontend') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroups', 'FieldDisplayGroupFieldIds') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupTranslation', 'FieldDisplayGroupTranslationGroupId') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupTranslation', 'FieldDisplayGroupTranslationGroupSystemName') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupTranslation', 'FieldDisplayGroupTranslationLanguageId') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupTranslation', 'FieldDisplayGroupTranslationText') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupFields', 'FieldDisplayGroupFieldSystemName') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupFields', 'FieldDisplayGroupFieldGroupId') IS NULL
   OR COL_LENGTH('EcomFieldDisplayGroupFields', 'FieldDisplayGroupFieldSortOrder') IS NULL
    RAISERROR(N'truvio-catalog.sql: the field-display-group columns are not the expected shape (FieldDisplayGroupId / FieldDisplayGroupSystemName / FieldDisplayGroupName / FieldDisplayGroupSortIndex / FieldDisplayGroupAvailableInFrontend / FieldDisplayGroupFieldIds / the three translation columns / the three relation columns). Read the live column names off sys.columns and update this section - do NOT let it seed a group the PDP cannot resolve.', 16, 1);

IF NOT EXISTS (SELECT 1 FROM EcomFieldDisplayGroups WHERE FieldDisplayGroupSystemName = 'tc_specs')
    INSERT INTO EcomFieldDisplayGroups (FieldDisplayGroupSystemName, FieldDisplayGroupName, FieldDisplayGroupSortIndex, FieldDisplayGroupAvailableInFrontend, FieldDisplayGroupFieldIds)
    VALUES ('tc_specs', N'Specifications', 1, 1, N'');

DECLARE @TcSpecsGroupId INT = (SELECT TOP 1 FieldDisplayGroupId FROM EcomFieldDisplayGroups WHERE FieldDisplayGroupSystemName = 'tc_specs');
IF @TcSpecsGroupId IS NULL
    RAISERROR(N'truvio-catalog.sql: the tc_specs field display group was not created. The PDP spec table has nothing to bind to.', 16, 1);

-- The paragraph's own option query filters on AvailableInFrontend = 1; a group that
-- is not flagged is invisible to the storefront AND to the backend picker.
IF EXISTS (SELECT 1 FROM EcomFieldDisplayGroups WHERE FieldDisplayGroupSystemName = 'tc_specs' AND FieldDisplayGroupAvailableInFrontend <> 1)
    UPDATE EcomFieldDisplayGroups SET FieldDisplayGroupAvailableInFrontend = 1 WHERE FieldDisplayGroupSystemName = 'tc_specs';

IF NOT EXISTS (SELECT 1 FROM EcomFieldDisplayGroupTranslation WHERE FieldDisplayGroupTranslationGroupSystemName = 'tc_specs' AND FieldDisplayGroupTranslationLanguageId = 'ENU')
    INSERT INTO EcomFieldDisplayGroupTranslation (FieldDisplayGroupTranslationGroupId, FieldDisplayGroupTranslationGroupSystemName, FieldDisplayGroupTranslationLanguageId, FieldDisplayGroupTranslationText)
    VALUES (@TcSpecsGroupId, 'tc_specs', 'ENU', N'Specifications');

-- The relation is derived from the category fields themselves, so the two can only
-- ever list the same 28 names and a field added above joins the group on the next run.
--
-- THE MEMBER NAME IS QUALIFIED, NOT BARE. A display-group member is not a field id:
-- it is a REFERENCE to a field, and a category field's reference form is
--     ProductCategory|<FieldCategoryId>|<FieldId>
-- pipe-delimited, with the literal segment `ProductCategory` in front. 1.1.0 wrote
-- the bare `FieldId` and the band rendered an empty table on every product, because
-- nothing resolved. The form above was read off six unrelated DW 10 solutions on the
-- same SQL instance, every one of which uses it and no other: their display-group
-- member rows are 100 % `ProductCategory|...|...` wherever the member is a category
-- field (marine-demo 65/65, momar 1264, burco 121, gerflor 111, dw10-demo 91,
-- sapporo 91), and in dw10-demo 75 of the 91 qualified names resolve against a live
-- EcomProductCategoryField row while ZERO bare names do. A GLOBAL product field
-- (EcomProductField + its own column on EcomProducts) is named bare; a CATEGORY field
-- is named qualified. This layer ships category fields, so it names them qualified.
INSERT INTO EcomFieldDisplayGroupFields (FieldDisplayGroupFieldSystemName, FieldDisplayGroupFieldGroupId, FieldDisplayGroupFieldSortOrder)
SELECT 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId, @TcSpecsGroupId, f.FieldSortOrder
  FROM EcomProductCategoryField f
 WHERE f.FieldCategoryId LIKE 'tc[_]%'
   AND NOT EXISTS (SELECT 1 FROM EcomFieldDisplayGroupFields r
                    WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
                      AND r.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId);

-- A host seeded by 1.1.0 carries the 28 BARE names. Converge it in place rather than
-- leaving 56 rows of which half resolve: rewrite a bare row to its qualified form
-- where that row's name is exactly a tc_* category field id, then drop any bare row
-- left over (a duplicate, because the qualified row was inserted above).
UPDATE r
   SET r.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId
  FROM EcomFieldDisplayGroupFields r
  JOIN EcomProductCategoryField f
    ON f.FieldId = r.FieldDisplayGroupFieldSystemName
   AND f.FieldCategoryId LIKE 'tc[_]%'
 WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
   AND NOT EXISTS (SELECT 1 FROM EcomFieldDisplayGroupFields d
                    WHERE d.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
                      AND d.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId);

DELETE r
  FROM EcomFieldDisplayGroupFields r
 WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
   AND EXISTS (SELECT 1 FROM EcomProductCategoryField f
                WHERE f.FieldId = r.FieldDisplayGroupFieldSystemName
                  AND f.FieldCategoryId LIKE 'tc[_]%');

-- The denormalised list, written from the relation, never typed. STRING_AGG rather
-- than the FOR XML idiom on purpose: the XML value() method needs QUOTED_IDENTIFIER ON
-- and sqlcmd runs these scripts with it OFF, so the XML form fails with Msg 1934 on a
-- real apply. Measured on the DW 10.28.10 host. The list carries the same qualified
-- names as the relation - burco's seven groups write theirs exactly this way, a
-- comma-joined list of `ProductCategory|cat|field` - and most solutions leave the
-- column NULL entirely, so it is a convenience beside the relation and never the
-- thing the frontend resolves against.
DECLARE @TcSpecsFieldIds NVARCHAR(MAX);
SELECT @TcSpecsFieldIds = STRING_AGG(r.FieldDisplayGroupFieldSystemName, ',')
                            WITHIN GROUP (ORDER BY r.FieldDisplayGroupFieldSortOrder, r.FieldDisplayGroupFieldSystemName)
  FROM EcomFieldDisplayGroupFields r
 WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId;
IF EXISTS (SELECT 1 FROM EcomFieldDisplayGroups WHERE FieldDisplayGroupSystemName = 'tc_specs' AND ISNULL(FieldDisplayGroupFieldIds, N'') <> ISNULL(@TcSpecsFieldIds, N''))
    UPDATE EcomFieldDisplayGroups SET FieldDisplayGroupFieldIds = ISNULL(@TcSpecsFieldIds, N'') WHERE FieldDisplayGroupSystemName = 'tc_specs';

-- THE COMPLETENESS GUARDS, and they come before the resolution guard because a
-- group can resolve and still be short. The measured failure was exactly that:
-- EcomFieldDisplayGroupFields held 28 members for group 14 while the denormalised
-- FieldDisplayGroupFieldIds column listed SIX names, and the sixth of them,
-- ProductCategory|tc_content|tcMedia, is not a field on any host - the real system
-- name is tcMediaSet (Foundry #1147). The relation was right, the column was typed,
-- and nothing anywhere said so: no exception, no dw-error, and every row count
-- correct. Whichever of the two stores the runtime reads, a band built from six
-- names of which one cannot resolve shows one row on TCPROD0051 and none at all on
-- TCPROD0001.
--
-- Three assertions, in the order they can fail:
--   1. the relation holds EVERY tc_* category field, not a subset
--   2. it holds every one of them PER CATEGORY, so a whole category cannot go
--      missing while the total happens to come out right
--   3. every name in the denormalised column resolves to a live category field,
--      which is the assertion that would have caught tcMedia on the run that
--      introduced it
DECLARE @TcSpecsMembers INT = (SELECT COUNT(*) FROM EcomFieldDisplayGroupFields WHERE FieldDisplayGroupFieldGroupId = @TcSpecsGroupId);
DECLARE @TcSpecsFields INT = (SELECT COUNT(*) FROM EcomProductCategoryField WHERE FieldCategoryId LIKE 'tc[_]%');
DECLARE @TcSpecsMsg NVARCHAR(1000);
IF @TcSpecsMembers <> @TcSpecsFields
BEGIN
    SET @TcSpecsMsg = CONCAT(N'truvio-catalog.sql: the tc_specs display group holds ', @TcSpecsMembers,
                             N' member(s) against ', @TcSpecsFields,
                             N' tc_* category field(s) in the database. The spec band is built from the members, so a short group shows a short table on every product and says nothing about why.');
    RAISERROR(@TcSpecsMsg, 16, 1);
END

DECLARE @TcSpecsShortCategory NVARCHAR(400) = (
    SELECT TOP 1 CONCAT(f.FieldCategoryId, N' (', COUNT(*), N' field(s), ',
                        SUM(CASE WHEN EXISTS (SELECT 1 FROM EcomFieldDisplayGroupFields r
                                               WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
                                                 AND r.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId)
                                 THEN 1 ELSE 0 END), N' member(s))')
      FROM EcomProductCategoryField f
     WHERE f.FieldCategoryId LIKE 'tc[_]%'
     GROUP BY f.FieldCategoryId
    HAVING COUNT(*) <> SUM(CASE WHEN EXISTS (SELECT 1 FROM EcomFieldDisplayGroupFields r
                                              WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
                                                AND r.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId)
                                THEN 1 ELSE 0 END));
IF @TcSpecsShortCategory IS NOT NULL
BEGIN
    SET @TcSpecsMsg = CONCAT(N'truvio-catalog.sql: a whole field category is under-represented in tc_specs - ', @TcSpecsShortCategory,
                             N'. The group spans four categories and a product renders only the fields it carries a value for, so a missing category is invisible on three products in four.');
    RAISERROR(@TcSpecsMsg, 16, 1);
END

DECLARE @TcSpecsUnresolvedNames INT = (
    SELECT COUNT(*)
      FROM STRING_SPLIT(ISNULL(@TcSpecsFieldIds, N''), ',') x
     WHERE LTRIM(RTRIM(x.value)) <> N''
       AND NOT EXISTS (SELECT 1 FROM EcomProductCategoryField f
                        WHERE 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId = LTRIM(RTRIM(x.value))));
IF @TcSpecsUnresolvedNames > 0
BEGIN
    SET @TcSpecsMsg = CONCAT(N'truvio-catalog.sql: ', @TcSpecsUnresolvedNames,
                             N' name(s) in FieldDisplayGroupFieldIds do not resolve to a live EcomProductCategoryField row. A typed name that resolves to nothing is silent - the measured case was ProductCategory|tc_content|tcMedia, where the real system name is tcMediaSet. The column is written FROM the relation, so an unresolved name here means the relation itself names a field that does not exist.');
    RAISERROR(@TcSpecsMsg, 16, 1);
END

DECLARE @TcSpecsListedNames INT = (
    SELECT COUNT(*) FROM STRING_SPLIT(ISNULL(@TcSpecsFieldIds, N''), ',') x WHERE LTRIM(RTRIM(x.value)) <> N'');
IF @TcSpecsListedNames <> @TcSpecsMembers
BEGIN
    SET @TcSpecsMsg = CONCAT(N'truvio-catalog.sql: the denormalised FieldDisplayGroupFieldIds column lists ', @TcSpecsListedNames,
                             N' name(s) against ', @TcSpecsMembers,
                             N' relation member(s). The two stores disagreeing is the defect of #1147 - 6 against 28 on the measured host - and the column is meant to be WRITTEN FROM the relation rather than typed beside it.');
    RAISERROR(@TcSpecsMsg, 16, 1);
END

-- THE RESOLUTION GUARD. The shape guard above asserts COLUMNS; it passed on the run
-- that shipped a band with no rows, because column shape was never the thing that was
-- wrong. This one asserts the thing the page needs: that a member of tc_specs joins
-- through to a VALUE on a real product, along the same path the platform walks when
-- Swift calls GetProductDisplayGroupFieldsByGroupSystemNames(['tc_specs']) - member
-- name -> category field -> that field's value on a product. A group that resolves to
-- nothing renders a heading over an empty table, which is worse than no band at all,
-- and it is silent: no exception, no dw-error, correct row counts everywhere.
DECLARE @TcSpecsResolved INT = (
    SELECT COUNT(*)
      FROM EcomFieldDisplayGroupFields r
      JOIN EcomProductCategoryField f
        ON r.FieldDisplayGroupFieldSystemName = 'ProductCategory|' + f.FieldCategoryId + '|' + f.FieldId
      JOIN EcomProductCategoryFieldValue v
        ON v.FieldValueFieldCategoryId = f.FieldCategoryId
       AND v.FieldValueFieldId = f.FieldId
     WHERE r.FieldDisplayGroupFieldGroupId = @TcSpecsGroupId
       AND v.FieldValueProductId LIKE 'TCPROD%'
       AND ISNULL(v.FieldValueValue, N'') <> N'');
IF @TcSpecsResolved = 0
    RAISERROR(N'truvio-catalog.sql: the tc_specs display group resolves to ZERO field values on any TCPROD product. The PDP spec band will render a heading over an empty table. Members must be written in the category-field reference form ProductCategory|<FieldCategoryId>|<FieldId>; a bare FieldId resolves against GLOBAL product fields (EcomProductField) only, and this layer ships none.', 16, 1);

-- ---------------------------------------------------------------------------
-- 8. Currency rates: every currency row, not just the default.
--    EcomCurrencies.CurrencyRate is hundredths - the platform's own seed ships a
--    currency at 100, meaning 1.00. A currency left at 1 renders every price a
--    hundred times over.
--
--    1.0.1 moved only the DEFAULT currency (EUR) to 100 and the v5 e2e on
--    DW 10.28.10 measured the bug intact and merely relabelled: the storefront
--    serves USD, whose rate was still 1, so the stored 45.00 rendered as
--    $4,500.00. The rate has to be right on the currency the SITE serves, and a
--    demo edition does not get to assume which one that is. So: every currency row
--    still sitting at the placeholder 1 moves to 100. EcomCurrencies holds exactly
--    the currencies the solution offers - a currency that is not enabled has no row
--    - so "every row" and "every enabled currency" are the same set, and the
--    statement needs no column beyond the two it already reads.
--
--    Measured on the 10.28.10 host, EcomCurrencies grouped by code and rate (rows
--    are per language, 16-17 of each):
--        EUR 100 (default)   USD 1     HUF 2      DKK 15    CZK 29
--        GBP 86              HRK 99    RON 150    PLN 163   BGN 380
--    Only USD is at 1, and only USD moves. Every other currency already carries a
--    real rate relative to the default and this statement leaves it alone - which
--    is the point of guarding on `= 1` rather than on `<> 100`.
--
--    CROSS-CURRENCY PARITY FOR USD IS DELIBERATE. Moving USD to 100 makes it 1:1
--    with the default, so a 60.00 EUR line renders as 60.00 USD. That is demo
--    semantics on purpose - the catalogue carries one set of round numbers and they
--    stay readable on the currency the storefront actually serves, and inventing an
--    FX rate would put wrong money on a prospect's screen with nothing behind it. A
--    solution that needs real conversion sets real rates; this layer is not the
--    place for them.
--
--    Existence-guarded, so a host already at 100 is not written to. The DURABLE
--    home for this remains the BASE layer's currency seed (queued for the next
--    base release); this stays a stopgap scoped to the demo edition.
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM EcomCurrencies WHERE CurrencyRate = 1)
    UPDATE EcomCurrencies SET CurrencyRate = 100 WHERE CurrencyRate = 1;

COMMIT TRAN;
PRINT 'Done - truvio-demo catalogue: 16 groups (4 top + 12 re-screened sub), 60 masters + 36 variant rows bound to their 2 axes and proven renderable, 40 prices, 2 BOM slots, 4 categories / 28 buyer-readable fields / 180 values in SHOP1; 60 long descriptions and the tc_specs field display group the PDP spec table reads, its 28 members in the ProductCategory|<category>|<field> reference form and proven to resolve.';
