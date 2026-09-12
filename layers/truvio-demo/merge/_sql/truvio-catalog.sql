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
--     with 3 populated values per master product.
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
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-COMPLETENESS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-COMPLETENESS', 'ENU', N'Completeness', 'TCGRP-COMPLETENESS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-COMPLETENESS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-COMPLETENESS', 'TCGRP-DATA-MODELS', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-WORKFLOWS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-WORKFLOWS', 'ENU', N'Workflows', 'TCGRP-WORKFLOWS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-WORKFLOWS' AND GroupRelationsParentId = 'TCGRP-DATA-MODELS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-WORKFLOWS', 'TCGRP-DATA-MODELS', 3, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PRICE-STRUCTURES')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-PRICE-STRUCTURES', 'ENU', N'Price Structures', 'TCGRP-PRICE-STRUCTURES', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PRICE-STRUCTURES' AND GroupRelationsParentId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-PRICE-STRUCTURES', 'TCGRP-COMMERCE', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-ASSORTMENTS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-ASSORTMENTS', 'ENU', N'Assortments', 'TCGRP-ASSORTMENTS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-ASSORTMENTS' AND GroupRelationsParentId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-ASSORTMENTS', 'TCGRP-COMMERCE', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-DISCOUNTS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-DISCOUNTS', 'ENU', N'Discounts', 'TCGRP-DISCOUNTS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-DISCOUNTS' AND GroupRelationsParentId = 'TCGRP-COMMERCE')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-DISCOUNTS', 'TCGRP-COMMERCE', 3, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PAGES')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-PAGES', 'ENU', N'Pages', 'TCGRP-PAGES', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PAGES' AND GroupRelationsParentId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-PAGES', 'TCGRP-CONTENT', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PARAGRAPHS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-PARAGRAPHS', 'ENU', N'Paragraphs', 'TCGRP-PARAGRAPHS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PARAGRAPHS' AND GroupRelationsParentId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-PARAGRAPHS', 'TCGRP-CONTENT', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-ITEM-TYPES')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-ITEM-TYPES', 'ENU', N'Item Types', 'TCGRP-ITEM-TYPES', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-ITEM-TYPES' AND GroupRelationsParentId = 'TCGRP-CONTENT')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-ITEM-TYPES', 'TCGRP-CONTENT', 3, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-GROUPS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-GROUPS', 'ENU', N'Groups', 'TCGRP-GROUPS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-GROUPS' AND GroupRelationsParentId = 'TCGRP-USERS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-GROUPS', 'TCGRP-USERS', 1, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-PERMISSIONS')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-PERMISSIONS', 'ENU', N'Permissions', 'TCGRP-PERMISSIONS', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-PERMISSIONS' AND GroupRelationsParentId = 'TCGRP-USERS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-PERMISSIONS', 'TCGRP-USERS', 2, 1, 0);
IF NOT EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId = 'TCGRP-IMPERSONATION')
    INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('TCGRP-IMPERSONATION', 'ENU', N'Impersonation', 'TCGRP-IMPERSONATION', 1, 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomGroupRelations WHERE GroupRelationsGroupId = 'TCGRP-IMPERSONATION' AND GroupRelationsParentId = 'TCGRP-USERS')
    INSERT INTO EcomGroupRelations (GroupRelationsGroupId, GroupRelationsParentId, GroupRelationsSorting, GroupRelationsIsPrimary, GroupRelationsInheritCategories) VALUES ('TCGRP-IMPERSONATION', 'TCGRP-USERS', 3, 1, 0);

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
    VALUES ('TCPROD0006', 'ENU', '', 'TC-CMP-0006', N'Truvio Completeness Score 06', N'Truvio demo data. Score in the Completeness band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMPLETENESS' AND GroupProductRelationProductId = 'TCPROD0006')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMPLETENESS', 'TCPROD0006', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0006')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0006', 6, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0007', 'ENU', '', 'TC-CMP-0007', N'Truvio Completeness Score 07', N'Truvio demo data. Score in the Completeness band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMPLETENESS' AND GroupProductRelationProductId = 'TCPROD0007')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMPLETENESS', 'TCPROD0007', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0007')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0007', 7, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0008', 'ENU', '', 'TC-CMP-0008', N'Truvio Completeness Score 08', N'Truvio demo data. Score in the Completeness band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMPLETENESS' AND GroupProductRelationProductId = 'TCPROD0008')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMPLETENESS', 'TCPROD0008', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0008')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0008', 8, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0009', 'ENU', '', 'TC-CMP-0009', N'Truvio Completeness Score 09', N'Truvio demo data. Score in the Completeness band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMPLETENESS' AND GroupProductRelationProductId = 'TCPROD0009')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMPLETENESS', 'TCPROD0009', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0009')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0009', 9, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0010', 'ENU', '', 'TC-CMP-0010', N'Truvio Completeness Score 10', N'Truvio demo data. Score in the Completeness band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMPLETENESS' AND GroupProductRelationProductId = 'TCPROD0010')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMPLETENESS', 'TCPROD0010', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0010')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0010', 10, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0011', 'ENU', '', 'TC-WFL-0011', N'Truvio Workflow State 11', N'Truvio demo data. State in the Workflow band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-WORKFLOWS' AND GroupProductRelationProductId = 'TCPROD0011')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-WORKFLOWS', 'TCPROD0011', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0011')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0011', 11, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0012', 'ENU', '', 'TC-WFL-0012', N'Truvio Workflow State 12', N'Truvio demo data. State in the Workflow band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-WORKFLOWS' AND GroupProductRelationProductId = 'TCPROD0012')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-WORKFLOWS', 'TCPROD0012', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0012')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0012', 12, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0013', 'ENU', '', 'TC-WFL-0013', N'Truvio Workflow Service 13', N'Truvio demo data. Service line (ProductType 1): no stock, no shipment - it proves a non-stock line renders and prices like any other.', 75.00, 1, 1, 100, 1, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-WORKFLOWS' AND GroupProductRelationProductId = 'TCPROD0013')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-WORKFLOWS', 'TCPROD0013', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0013')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0013', 13, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0014', 'ENU', '', 'TC-WFL-0014', N'Truvio Workflow State 14', N'Truvio demo data. State in the Workflow band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-WORKFLOWS' AND GroupProductRelationProductId = 'TCPROD0014')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-WORKFLOWS', 'TCPROD0014', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-DATA-MODELS' AND GroupProductRelationProductId = 'TCPROD0014')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-DATA-MODELS', 'TCPROD0014', 14, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0015', 'ENU', '', 'TC-WFL-0015', N'Truvio Workflow State 15', N'Truvio demo data. State in the Workflow band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-WORKFLOWS' AND GroupProductRelationProductId = 'TCPROD0015')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-WORKFLOWS', 'TCPROD0015', 5, 1, GETDATE());
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
    VALUES ('TCPROD0021', 'ENU', '', 'TC-ASM-0021', N'Truvio Assortment Kit 21', N'Truvio demo data. Bill-of-materials parent: pick one Variants component and one Item Types component, then add the configured kit to the cart.', 0.00, 1, 1, 100, 2, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0021')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0021', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0021')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0021', 21, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0022', 'ENU', '', 'TC-ASM-0022', N'Truvio Assortment Scope 22', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0022')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0022', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0022')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0022', 22, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0023', 'ENU', '', 'TC-ASM-0023', N'Truvio Assortment Scope 23', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0023')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0023', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0023')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0023', 23, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0024', 'ENU', '', 'TC-ASM-0024', N'Truvio Assortment Scope 24', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0024')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0024', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0024')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0024', 24, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0025', 'ENU', '', 'TC-ASM-0025', N'Truvio Assortment Scope 25', N'Truvio demo data. Scope in the Assortment band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ASSORTMENTS' AND GroupProductRelationProductId = 'TCPROD0025')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ASSORTMENTS', 'TCPROD0025', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-COMMERCE' AND GroupProductRelationProductId = 'TCPROD0025')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-COMMERCE', 'TCPROD0025', 25, 0, GETDATE());
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
    VALUES ('TCPROD0031', 'ENU', '', 'TC-PAG-0031', N'Truvio Page Node 31', N'Truvio demo data. Node in the Page band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PAGES' AND GroupProductRelationProductId = 'TCPROD0031')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PAGES', 'TCPROD0031', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0031')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0031', 31, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0032', 'ENU', '', 'TC-PAG-0032', N'Truvio Page Node 32', N'Truvio demo data. Node in the Page band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PAGES' AND GroupProductRelationProductId = 'TCPROD0032')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PAGES', 'TCPROD0032', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0032')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0032', 32, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0033', 'ENU', '', 'TC-PAG-0033', N'Truvio Page Node 33', N'Truvio demo data. Node in the Page band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PAGES' AND GroupProductRelationProductId = 'TCPROD0033')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PAGES', 'TCPROD0033', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0033')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0033', 33, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0034', 'ENU', '', 'TC-PAG-0034', N'Truvio Page Node 34', N'Truvio demo data. Node in the Page band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PAGES' AND GroupProductRelationProductId = 'TCPROD0034')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PAGES', 'TCPROD0034', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0034')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0034', 34, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0035', 'ENU', '', 'TC-PAG-0035', N'Truvio Page Node 35', N'Truvio demo data. Node in the Page band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PAGES' AND GroupProductRelationProductId = 'TCPROD0035')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PAGES', 'TCPROD0035', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0035')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0035', 35, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0036', 'ENU', '', 'TC-PAR-0036', N'Truvio Paragraph Block 36', N'Truvio demo data. Block in the Paragraph band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PARAGRAPHS' AND GroupProductRelationProductId = 'TCPROD0036')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PARAGRAPHS', 'TCPROD0036', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0036')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0036', 36, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0037', 'ENU', '', 'TC-PAR-0037', N'Truvio Paragraph Block 37', N'Truvio demo data. Block in the Paragraph band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PARAGRAPHS' AND GroupProductRelationProductId = 'TCPROD0037')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PARAGRAPHS', 'TCPROD0037', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0037')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0037', 37, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0038', 'ENU', '', 'TC-PAR-0038', N'Truvio Paragraph Block 38', N'Truvio demo data. Block in the Paragraph band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PARAGRAPHS' AND GroupProductRelationProductId = 'TCPROD0038')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PARAGRAPHS', 'TCPROD0038', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0038')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0038', 38, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0039', 'ENU', '', 'TC-PAR-0039', N'Truvio Paragraph Block 39', N'Truvio demo data. Block in the Paragraph band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PARAGRAPHS' AND GroupProductRelationProductId = 'TCPROD0039')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PARAGRAPHS', 'TCPROD0039', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0039')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0039', 39, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0040', 'ENU', '', 'TC-PAR-0040', N'Truvio Paragraph Block 40', N'Truvio demo data. Block in the Paragraph band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PARAGRAPHS' AND GroupProductRelationProductId = 'TCPROD0040')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PARAGRAPHS', 'TCPROD0040', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0040')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0040', 40, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0041', 'ENU', '', 'TC-ITM-0041', N'Truvio Item Type Schema 41', N'Truvio demo data. Schema in the Item Type band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ITEM-TYPES' AND GroupProductRelationProductId = 'TCPROD0041')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ITEM-TYPES', 'TCPROD0041', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0041')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0041', 41, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0042', 'ENU', '', 'TC-ITM-0042', N'Truvio Item Type Schema 42', N'Truvio demo data. Schema in the Item Type band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ITEM-TYPES' AND GroupProductRelationProductId = 'TCPROD0042')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ITEM-TYPES', 'TCPROD0042', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0042')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0042', 42, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0043', 'ENU', '', 'TC-ITM-0043', N'Truvio Item Type Schema 43', N'Truvio demo data. Schema in the Item Type band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ITEM-TYPES' AND GroupProductRelationProductId = 'TCPROD0043')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ITEM-TYPES', 'TCPROD0043', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0043')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0043', 43, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0044', 'ENU', '', 'TC-ITM-0044', N'Truvio Item Type Schema 44', N'Truvio demo data. Schema in the Item Type band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ITEM-TYPES' AND GroupProductRelationProductId = 'TCPROD0044')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ITEM-TYPES', 'TCPROD0044', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0044')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0044', 44, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0045', 'ENU', '', 'TC-ITM-0045', N'Truvio Item Type Schema 45', N'Truvio demo data. Schema in the Item Type band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-ITEM-TYPES' AND GroupProductRelationProductId = 'TCPROD0045')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-ITEM-TYPES', 'TCPROD0045', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-CONTENT' AND GroupProductRelationProductId = 'TCPROD0045')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-CONTENT', 'TCPROD0045', 45, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0046', 'ENU', '', 'TC-GRP-0046', N'Truvio Group Segment 46', N'Truvio demo data. Segment in the Group band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-GROUPS' AND GroupProductRelationProductId = 'TCPROD0046')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-GROUPS', 'TCPROD0046', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0046')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0046', 46, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0047', 'ENU', '', 'TC-GRP-0047', N'Truvio Group Segment 47', N'Truvio demo data. Segment in the Group band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-GROUPS' AND GroupProductRelationProductId = 'TCPROD0047')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-GROUPS', 'TCPROD0047', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0047')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0047', 47, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0048', 'ENU', '', 'TC-GRP-0048', N'Truvio Group Segment 48', N'Truvio demo data. Segment in the Group band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-GROUPS' AND GroupProductRelationProductId = 'TCPROD0048')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-GROUPS', 'TCPROD0048', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0048')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0048', 48, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0049', 'ENU', '', 'TC-GRP-0049', N'Truvio Group Segment 49', N'Truvio demo data. Segment in the Group band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-GROUPS' AND GroupProductRelationProductId = 'TCPROD0049')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-GROUPS', 'TCPROD0049', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0049')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0049', 49, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0050', 'ENU', '', 'TC-GRP-0050', N'Truvio Group Segment 50', N'Truvio demo data. Segment in the Group band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-GROUPS' AND GroupProductRelationProductId = 'TCPROD0050')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-GROUPS', 'TCPROD0050', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0050')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0050', 50, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0051', 'ENU', '', 'TC-PRM-0051', N'Truvio Permission Grant 51', N'Truvio demo data. Grant in the Permission band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PERMISSIONS' AND GroupProductRelationProductId = 'TCPROD0051')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PERMISSIONS', 'TCPROD0051', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0051')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0051', 51, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0052', 'ENU', '', 'TC-PRM-0052', N'Truvio Permission Grant 52', N'Truvio demo data. Grant in the Permission band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PERMISSIONS' AND GroupProductRelationProductId = 'TCPROD0052')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PERMISSIONS', 'TCPROD0052', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0052')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0052', 52, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0053', 'ENU', '', 'TC-PRM-0053', N'Truvio Permission Service 53', N'Truvio demo data. Service line (ProductType 1): no stock, no shipment - it proves a non-stock line renders and prices like any other.', 75.00, 1, 1, 100, 1, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PERMISSIONS' AND GroupProductRelationProductId = 'TCPROD0053')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PERMISSIONS', 'TCPROD0053', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0053')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0053', 53, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0054', 'ENU', '', 'TC-PRM-0054', N'Truvio Permission Grant 54', N'Truvio demo data. Grant in the Permission band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PERMISSIONS' AND GroupProductRelationProductId = 'TCPROD0054')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PERMISSIONS', 'TCPROD0054', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0054')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0054', 54, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0055', 'ENU', '', 'TC-PRM-0055', N'Truvio Permission Grant 55', N'Truvio demo data. Grant in the Permission band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-PERMISSIONS' AND GroupProductRelationProductId = 'TCPROD0055')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-PERMISSIONS', 'TCPROD0055', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0055')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0055', 55, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0056', 'ENU', '', 'TC-IMP-0056', N'Truvio Impersonation Token 56', N'Truvio demo data. Token in the Impersonation band of the Truvio Commerce platform-vocabulary catalogue.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-IMPERSONATION' AND GroupProductRelationProductId = 'TCPROD0056')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-IMPERSONATION', 'TCPROD0056', 1, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0056')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0056', 56, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0057', 'ENU', '', 'TC-IMP-0057', N'Truvio Impersonation Token 57', N'Truvio demo data. Token in the Impersonation band of the Truvio Commerce platform-vocabulary catalogue.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-IMPERSONATION' AND GroupProductRelationProductId = 'TCPROD0057')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-IMPERSONATION', 'TCPROD0057', 2, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0057')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0057', 57, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0058', 'ENU', '', 'TC-IMP-0058', N'Truvio Impersonation Token 58', N'Truvio demo data. Token in the Impersonation band of the Truvio Commerce platform-vocabulary catalogue.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-IMPERSONATION' AND GroupProductRelationProductId = 'TCPROD0058')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-IMPERSONATION', 'TCPROD0058', 3, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0058')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0058', 58, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0059', 'ENU', '', 'TC-IMP-0059', N'Truvio Impersonation Token 59', N'Truvio demo data. Token in the Impersonation band of the Truvio Commerce platform-vocabulary catalogue.', 90.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-IMPERSONATION' AND GroupProductRelationProductId = 'TCPROD0059')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-IMPERSONATION', 'TCPROD0059', 4, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0059')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0059', 59, 0, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '')
    INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated)
    VALUES ('TCPROD0060', 'ENU', '', 'TC-IMP-0060', N'Truvio Impersonation Token 60', N'Truvio demo data. Token in the Impersonation band of the Truvio Commerce platform-vocabulary catalogue.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-IMPERSONATION' AND GroupProductRelationProductId = 'TCPROD0060')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-IMPERSONATION', 'TCPROD0060', 5, 1, GETDATE());
IF NOT EXISTS (SELECT 1 FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = 'TCGRP-USERS' AND GroupProductRelationProductId = 'TCPROD0060')
    INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('TCGRP-USERS', 'TCPROD0060', 60, 0, GETDATE());

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
-- 4. The 6 variant masters: option relations, the 36 combination rows, and the
--    explicit per-variant price. A combination row's ProductVariantId is the
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

-- ---------------------------------------------------------------------------
-- 5. The BOM kit. Each slot binds a GROUP and names a default child, which is
--    what makes the configurator a picker and not a fixed kit.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0001')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0001', 'TCPROD0021', '', 'TCGRP-VARIANTS', 1, N'Variant component', 1, 'TCPROD0002', '', 1, '', '', '', '');
IF NOT EXISTS (SELECT 1 FROM EcomProductItems WHERE ProductItemId = 'TC-BOM-0002')
    INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
    VALUES ('TC-BOM-0002', 'TCPROD0021', '', 'TCGRP-ITEM-TYPES', 1, N'Item type component', 1, 'TCPROD0042', '', 2, '', '', '', '');

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
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcFacet' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcFacet', 'tc_data_models', 'tcFacet', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcFacet' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcFacet', 'tc_data_models', 'ENU', N'Facet');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcVariantAxis' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcVariantAxis', 'tc_data_models', 'tcVariantAxis', 1, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcVariantAxis' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcVariantAxis', 'tc_data_models', 'ENU', N'Variant Axis');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCompletenessScore' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCompletenessScore', 'tc_data_models', 'tcCompletenessScore', 6, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCompletenessScore' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCompletenessScore', 'tc_data_models', 'ENU', N'Completeness Score');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcWorkflowState' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcWorkflowState', 'tc_data_models', 'tcWorkflowState', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcWorkflowState' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcWorkflowState', 'tc_data_models', 'ENU', N'Workflow State');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcDataModel' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcDataModel', 'tc_data_models', 'tcDataModel', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcDataModel' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcDataModel', 'tc_data_models', 'ENU', N'Data Model');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcFieldGroup' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcFieldGroup', 'tc_data_models', 'tcFieldGroup', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcFieldGroup' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcFieldGroup', 'tc_data_models', 'ENU', N'Field Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcInheritance' AND FieldCategoryId = 'tc_data_models')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcInheritance', 'tc_data_models', 'tcInheritance', 3, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcInheritance' AND FieldTranslationFieldCategoryId = 'tc_data_models' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcInheritance', 'tc_data_models', 'ENU', N'Inheritance');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_commerce', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_commerce' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_commerce', 'ENU', N'Commerce');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcPriceMatrix' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcPriceMatrix', 'tc_commerce', 'tcPriceMatrix', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcPriceMatrix' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcPriceMatrix', 'tc_commerce', 'ENU', N'Price Matrix');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcQuantityTier' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcQuantityTier', 'tc_commerce', 'tcQuantityTier', 6, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcQuantityTier' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcQuantityTier', 'tc_commerce', 'ENU', N'Quantity Tier');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcAssortmentScope' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcAssortmentScope', 'tc_commerce', 'tcAssortmentScope', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcAssortmentScope' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcAssortmentScope', 'tc_commerce', 'ENU', N'Assortment Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcDiscountLadder' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcDiscountLadder', 'tc_commerce', 'tcDiscountLadder', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcDiscountLadder' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcDiscountLadder', 'tc_commerce', 'ENU', N'Discount Ladder');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCurrencyScope' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCurrencyScope', 'tc_commerce', 'tcCurrencyScope', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCurrencyScope' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCurrencyScope', 'tc_commerce', 'ENU', N'Currency Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcVatGroup' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcVatGroup', 'tc_commerce', 'tcVatGroup', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcVatGroup' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcVatGroup', 'tc_commerce', 'ENU', N'VAT Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcContractScope' AND FieldCategoryId = 'tc_commerce')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcContractScope', 'tc_commerce', 'tcContractScope', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcContractScope' AND FieldTranslationFieldCategoryId = 'tc_commerce' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcContractScope', 'tc_commerce', 'ENU', N'Contract Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_content')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_content', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_content' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_content', 'ENU', N'Content');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcPageNode' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcPageNode', 'tc_content', 'tcPageNode', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcPageNode' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcPageNode', 'tc_content', 'ENU', N'Page Node');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcParagraphBlock' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcParagraphBlock', 'tc_content', 'tcParagraphBlock', 1, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcParagraphBlock' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcParagraphBlock', 'tc_content', 'ENU', N'Paragraph Block');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcItemType' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcItemType', 'tc_content', 'tcItemType', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcItemType' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcItemType', 'tc_content', 'ENU', N'Item Type');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcGridRow' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcGridRow', 'tc_content', 'tcGridRow', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcGridRow' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcGridRow', 'tc_content', 'ENU', N'Grid Row');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcColorScheme' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcColorScheme', 'tc_content', 'tcColorScheme', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcColorScheme' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcColorScheme', 'tc_content', 'ENU', N'Color Scheme');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcNavigationTag' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcNavigationTag', 'tc_content', 'tcNavigationTag', 1, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcNavigationTag' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcNavigationTag', 'tc_content', 'ENU', N'Navigation Tag');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcTemplateTag' AND FieldCategoryId = 'tc_content')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcTemplateTag', 'tc_content', 'tcTemplateTag', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcTemplateTag' AND FieldTranslationFieldCategoryId = 'tc_content' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcTemplateTag', 'tc_content', 'ENU', N'Template Tag');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategory WHERE CategoryId = 'tc_users')
    INSERT INTO EcomProductCategory (CategoryId, CategoryProductProperties, CategoryType) VALUES ('tc_users', 0, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId = 'tc_users' AND CategoryTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryTranslation (CategoryTranslationCategoryId, CategoryTranslationLanguageId, CategoryTranslationCategoryName) VALUES ('tc_users', 'ENU', N'Users');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcUserGroup' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcUserGroup', 'tc_users', 'tcUserGroup', 1, 1);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcUserGroup' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcUserGroup', 'tc_users', 'ENU', N'User Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcPermissionGrant' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcPermissionGrant', 'tc_users', 'tcPermissionGrant', 1, 2);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcPermissionGrant' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcPermissionGrant', 'tc_users', 'ENU', N'Permission Grant');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcImpersonationScope' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcImpersonationScope', 'tc_users', 'tcImpersonationScope', 1, 3);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcImpersonationScope' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcImpersonationScope', 'tc_users', 'ENU', N'Impersonation Scope');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcCustomerNumber' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcCustomerNumber', 'tc_users', 'tcCustomerNumber', 1, 4);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcCustomerNumber' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcCustomerNumber', 'tc_users', 'ENU', N'Customer Number');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcAccessLevel' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcAccessLevel', 'tc_users', 'tcAccessLevel', 1, 5);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcAccessLevel' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcAccessLevel', 'tc_users', 'ENU', N'Access Level');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcSecondaryUser' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcSecondaryUser', 'tc_users', 'tcSecondaryUser', 3, 6);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcSecondaryUser' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcSecondaryUser', 'tc_users', 'ENU', N'Secondary User');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryField WHERE FieldId = 'tcLoginProfile' AND FieldCategoryId = 'tc_users')
    INSERT INTO EcomProductCategoryField (FieldId, FieldCategoryId, FieldTemplateTag, FieldType, FieldSortOrder) VALUES ('tcLoginProfile', 'tc_users', 'tcLoginProfile', 1, 7);
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldId = 'tcLoginProfile' AND FieldTranslationFieldCategoryId = 'tc_users' AND FieldTranslationLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldTranslation (FieldTranslationFieldId, FieldTranslationFieldCategoryId, FieldTranslationLanguageId, FieldTranslationFieldLabel) VALUES ('tcLoginProfile', 'tc_users', 'ENU', N'Login Profile');

-- Three populated values per master (180 rows): enough for a facet, a spec
-- table and a completeness score to have something to read.
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFacet' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0001' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFacet', 'tc_data_models', 'TCPROD0001', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVariantAxis' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0001' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVariantAxis', 'tc_data_models', 'TCPROD0001', '', 'ENU', N'Tier');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0001' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0001', '', 'ENU', N'40');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVariantAxis' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0002' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVariantAxis', 'tc_data_models', 'TCPROD0002', '', 'ENU', N'Mode');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0002' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0002', '', 'ENU', N'60');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0002' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0002', '', 'ENU', N'In review');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0003' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0003', '', 'ENU', N'75');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0003' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0003', '', 'ENU', N'Approved');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0003' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0003', '', 'ENU', N'Content');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0004' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0004', '', 'ENU', N'Published');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0004' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0004', '', 'ENU', N'Identity');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFieldGroup' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0004' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFieldGroup', 'tc_data_models', 'TCPROD0004', '', 'ENU', N'Pricing');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0005' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0005', '', 'ENU', N'Catalogue');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFieldGroup' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0005' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFieldGroup', 'tc_data_models', 'TCPROD0005', '', 'ENU', N'Access');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcInheritance' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0005' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcInheritance', 'tc_data_models', 'TCPROD0005', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFacet' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0006' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFacet', 'tc_data_models', 'TCPROD0006', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVariantAxis' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0006' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVariantAxis', 'tc_data_models', 'TCPROD0006', '', 'ENU', N'Tier');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0006' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0006', '', 'ENU', N'40');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVariantAxis' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0007' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVariantAxis', 'tc_data_models', 'TCPROD0007', '', 'ENU', N'Mode');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0007' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0007', '', 'ENU', N'60');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0007' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0007', '', 'ENU', N'In review');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0008' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0008', '', 'ENU', N'75');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0008' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0008', '', 'ENU', N'Approved');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0008' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0008', '', 'ENU', N'Content');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0009' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0009', '', 'ENU', N'Published');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0009' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0009', '', 'ENU', N'Identity');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFieldGroup' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0009' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFieldGroup', 'tc_data_models', 'TCPROD0009', '', 'ENU', N'Pricing');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0010' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0010', '', 'ENU', N'Catalogue');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFieldGroup' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0010' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFieldGroup', 'tc_data_models', 'TCPROD0010', '', 'ENU', N'Access');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcInheritance' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0010' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcInheritance', 'tc_data_models', 'TCPROD0010', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFacet' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0011' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFacet', 'tc_data_models', 'TCPROD0011', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVariantAxis' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0011' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVariantAxis', 'tc_data_models', 'TCPROD0011', '', 'ENU', N'Tier');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0011' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0011', '', 'ENU', N'40');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVariantAxis' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0012' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVariantAxis', 'tc_data_models', 'TCPROD0012', '', 'ENU', N'Mode');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0012' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0012', '', 'ENU', N'60');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0012' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0012', '', 'ENU', N'In review');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCompletenessScore' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0013' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCompletenessScore', 'tc_data_models', 'TCPROD0013', '', 'ENU', N'75');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0013' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0013', '', 'ENU', N'Approved');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0013' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0013', '', 'ENU', N'Content');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcWorkflowState' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0014' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcWorkflowState', 'tc_data_models', 'TCPROD0014', '', 'ENU', N'Published');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0014' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0014', '', 'ENU', N'Identity');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFieldGroup' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0014' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFieldGroup', 'tc_data_models', 'TCPROD0014', '', 'ENU', N'Pricing');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDataModel' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0015' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDataModel', 'tc_data_models', 'TCPROD0015', '', 'ENU', N'Catalogue');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcFieldGroup' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0015' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcFieldGroup', 'tc_data_models', 'TCPROD0015', '', 'ENU', N'Access');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcInheritance' AND FieldValueFieldCategoryId = 'tc_data_models' AND FieldValueProductId = 'TCPROD0015' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcInheritance', 'tc_data_models', 'TCPROD0015', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceMatrix' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0016' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceMatrix', 'tc_commerce', 'TCPROD0016', '', 'ENU', N'List');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityTier' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0016' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityTier', 'tc_commerce', 'TCPROD0016', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0016' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0016', '', 'ENU', N'Shop');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityTier' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0017' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityTier', 'tc_commerce', 'TCPROD0017', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0017' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0017', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0017' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0017', '', 'ENU', N'Order');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0018' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0018', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0018' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0018', '', 'ENU', N'Order line');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0018' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0018', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0019' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0019', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0019' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0019', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVatGroup' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0019' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVatGroup', 'tc_commerce', 'TCPROD0019', '', 'ENU', N'Standard');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0020' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0020', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVatGroup' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0020' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVatGroup', 'tc_commerce', 'TCPROD0020', '', 'ENU', N'Reduced');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcContractScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0020' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcContractScope', 'tc_commerce', 'TCPROD0020', '', 'ENU', N'Customer number');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceMatrix' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0021' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceMatrix', 'tc_commerce', 'TCPROD0021', '', 'ENU', N'List');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityTier' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0021' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityTier', 'tc_commerce', 'TCPROD0021', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0021' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0021', '', 'ENU', N'Shop');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityTier' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0022' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityTier', 'tc_commerce', 'TCPROD0022', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0022' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0022', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0022' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0022', '', 'ENU', N'Order');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0023' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0023', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0023' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0023', '', 'ENU', N'Order line');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0023' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0023', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0024' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0024', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0024' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0024', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVatGroup' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0024' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVatGroup', 'tc_commerce', 'TCPROD0024', '', 'ENU', N'Standard');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0025' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0025', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVatGroup' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0025' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVatGroup', 'tc_commerce', 'TCPROD0025', '', 'ENU', N'Reduced');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcContractScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0025' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcContractScope', 'tc_commerce', 'TCPROD0025', '', 'ENU', N'Customer number');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPriceMatrix' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0026' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPriceMatrix', 'tc_commerce', 'TCPROD0026', '', 'ENU', N'List');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityTier' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0026' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityTier', 'tc_commerce', 'TCPROD0026', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0026' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0026', '', 'ENU', N'Shop');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcQuantityTier' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0027' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcQuantityTier', 'tc_commerce', 'TCPROD0027', '', 'ENU', N'5');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0027' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0027', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0027' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0027', '', 'ENU', N'Order');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAssortmentScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0028' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAssortmentScope', 'tc_commerce', 'TCPROD0028', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0028' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0028', '', 'ENU', N'Order line');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0028' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0028', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcDiscountLadder' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0029' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcDiscountLadder', 'tc_commerce', 'TCPROD0029', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0029' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0029', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVatGroup' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0029' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVatGroup', 'tc_commerce', 'TCPROD0029', '', 'ENU', N'Standard');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCurrencyScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0030' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCurrencyScope', 'tc_commerce', 'TCPROD0030', '', 'ENU', N'EUR');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcVatGroup' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0030' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcVatGroup', 'tc_commerce', 'TCPROD0030', '', 'ENU', N'Reduced');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcContractScope' AND FieldValueFieldCategoryId = 'tc_commerce' AND FieldValueProductId = 'TCPROD0030' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcContractScope', 'tc_commerce', 'TCPROD0030', '', 'ENU', N'Customer number');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPageNode' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0031' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPageNode', 'tc_content', 'TCPROD0031', '', 'ENU', N'Root');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcParagraphBlock' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0031' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcParagraphBlock', 'tc_content', 'TCPROD0031', '', 'ENU', N'Text');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0031' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0031', '', 'ENU', N'Page');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcParagraphBlock' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0032' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcParagraphBlock', 'tc_content', 'TCPROD0032', '', 'ENU', N'Poster');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0032' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0032', '', 'ENU', N'Paragraph');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0032' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0032', '', 'ENU', N'2Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0033' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0033', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0033' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0033', '', 'ENU', N'3Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0033' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0033', '', 'ENU', N'Accent');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0034' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0034', '', 'ENU', N'4Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0034' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0034', '', 'ENU', N'Muted');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNavigationTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0034' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNavigationTag', 'tc_content', 'TCPROD0034', '', 'ENU', N'None');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0035' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0035', '', 'ENU', N'Default');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNavigationTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0035' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNavigationTag', 'tc_content', 'TCPROD0035', '', 'ENU', N'Main');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcTemplateTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0035' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcTemplateTag', 'tc_content', 'TCPROD0035', '', 'ENU', N'PageTitle');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPageNode' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0036' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPageNode', 'tc_content', 'TCPROD0036', '', 'ENU', N'Root');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcParagraphBlock' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0036' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcParagraphBlock', 'tc_content', 'TCPROD0036', '', 'ENU', N'Text');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0036' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0036', '', 'ENU', N'Page');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcParagraphBlock' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0037' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcParagraphBlock', 'tc_content', 'TCPROD0037', '', 'ENU', N'Poster');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0037' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0037', '', 'ENU', N'Paragraph');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0037' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0037', '', 'ENU', N'2Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0038' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0038', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0038' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0038', '', 'ENU', N'3Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0038' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0038', '', 'ENU', N'Accent');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0039' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0039', '', 'ENU', N'4Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0039' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0039', '', 'ENU', N'Muted');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNavigationTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0039' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNavigationTag', 'tc_content', 'TCPROD0039', '', 'ENU', N'None');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0040' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0040', '', 'ENU', N'Default');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNavigationTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0040' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNavigationTag', 'tc_content', 'TCPROD0040', '', 'ENU', N'Main');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcTemplateTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0040' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcTemplateTag', 'tc_content', 'TCPROD0040', '', 'ENU', N'PageTitle');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPageNode' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0041' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPageNode', 'tc_content', 'TCPROD0041', '', 'ENU', N'Root');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcParagraphBlock' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0041' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcParagraphBlock', 'tc_content', 'TCPROD0041', '', 'ENU', N'Text');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0041' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0041', '', 'ENU', N'Page');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcParagraphBlock' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0042' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcParagraphBlock', 'tc_content', 'TCPROD0042', '', 'ENU', N'Poster');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0042' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0042', '', 'ENU', N'Paragraph');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0042' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0042', '', 'ENU', N'2Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcItemType' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0043' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcItemType', 'tc_content', 'TCPROD0043', '', 'ENU', N'Product');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0043' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0043', '', 'ENU', N'3Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0043' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0043', '', 'ENU', N'Accent');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcGridRow' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0044' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcGridRow', 'tc_content', 'TCPROD0044', '', 'ENU', N'4Column');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0044' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0044', '', 'ENU', N'Muted');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNavigationTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0044' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNavigationTag', 'tc_content', 'TCPROD0044', '', 'ENU', N'None');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcColorScheme' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0045' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcColorScheme', 'tc_content', 'TCPROD0045', '', 'ENU', N'Default');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcNavigationTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0045' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcNavigationTag', 'tc_content', 'TCPROD0045', '', 'ENU', N'Main');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcTemplateTag' AND FieldValueFieldCategoryId = 'tc_content' AND FieldValueProductId = 'TCPROD0045' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcTemplateTag', 'tc_content', 'TCPROD0045', '', 'ENU', N'PageTitle');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUserGroup' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0046' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUserGroup', 'tc_users', 'TCPROD0046', '', 'ENU', N'Customers');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPermissionGrant' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0046' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPermissionGrant', 'tc_users', 'TCPROD0046', '', 'ENU', N'Read');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0046' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0046', '', 'ENU', N'None');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPermissionGrant' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0047' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPermissionGrant', 'tc_users', 'TCPROD0047', '', 'ENU', N'Write');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0047' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0047', '', 'ENU', N'Account');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0047' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0047', '', 'ENU', N'TC-100201');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0048' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0048', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0048' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0048', '', 'ENU', N'TC-100202');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0048' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0048', '', 'ENU', N'Frontend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0049' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0049', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0049' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0049', '', 'ENU', N'Backend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcSecondaryUser' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0049' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcSecondaryUser', 'tc_users', 'TCPROD0049', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0050' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0050', '', 'ENU', N'Frontend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcSecondaryUser' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0050' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcSecondaryUser', 'tc_users', 'TCPROD0050', '', 'ENU', N'0');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcLoginProfile' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0050' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcLoginProfile', 'tc_users', 'TCPROD0050', '', 'ENU', N'Elevated');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUserGroup' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0051' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUserGroup', 'tc_users', 'TCPROD0051', '', 'ENU', N'Customers');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPermissionGrant' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0051' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPermissionGrant', 'tc_users', 'TCPROD0051', '', 'ENU', N'Read');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0051' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0051', '', 'ENU', N'None');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPermissionGrant' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0052' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPermissionGrant', 'tc_users', 'TCPROD0052', '', 'ENU', N'Write');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0052' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0052', '', 'ENU', N'Account');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0052' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0052', '', 'ENU', N'TC-100201');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0053' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0053', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0053' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0053', '', 'ENU', N'TC-100202');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0053' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0053', '', 'ENU', N'Frontend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0054' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0054', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0054' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0054', '', 'ENU', N'Backend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcSecondaryUser' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0054' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcSecondaryUser', 'tc_users', 'TCPROD0054', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0055' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0055', '', 'ENU', N'Frontend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcSecondaryUser' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0055' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcSecondaryUser', 'tc_users', 'TCPROD0055', '', 'ENU', N'0');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcLoginProfile' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0055' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcLoginProfile', 'tc_users', 'TCPROD0055', '', 'ENU', N'Elevated');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcUserGroup' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0056' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcUserGroup', 'tc_users', 'TCPROD0056', '', 'ENU', N'Customers');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPermissionGrant' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0056' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPermissionGrant', 'tc_users', 'TCPROD0056', '', 'ENU', N'Read');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0056' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0056', '', 'ENU', N'None');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcPermissionGrant' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0057' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcPermissionGrant', 'tc_users', 'TCPROD0057', '', 'ENU', N'Write');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0057' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0057', '', 'ENU', N'Account');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0057' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0057', '', 'ENU', N'TC-100201');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcImpersonationScope' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0058' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcImpersonationScope', 'tc_users', 'TCPROD0058', '', 'ENU', N'Group');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0058' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0058', '', 'ENU', N'TC-100202');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0058' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0058', '', 'ENU', N'Frontend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcCustomerNumber' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0059' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcCustomerNumber', 'tc_users', 'TCPROD0059', '', 'ENU', N'TC-100200');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0059' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0059', '', 'ENU', N'Backend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcSecondaryUser' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0059' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcSecondaryUser', 'tc_users', 'TCPROD0059', '', 'ENU', N'1');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcAccessLevel' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0060' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcAccessLevel', 'tc_users', 'TCPROD0060', '', 'ENU', N'Frontend');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcSecondaryUser' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0060' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcSecondaryUser', 'tc_users', 'TCPROD0060', '', 'ENU', N'0');
IF NOT EXISTS (SELECT 1 FROM EcomProductCategoryFieldValue WHERE FieldValueFieldId = 'tcLoginProfile' AND FieldValueFieldCategoryId = 'tc_users' AND FieldValueProductId = 'TCPROD0060' AND FieldValueProductVariantId = '' AND FieldValueProductLanguageId = 'ENU')
    INSERT INTO EcomProductCategoryFieldValue (FieldValueFieldId, FieldValueFieldCategoryId, FieldValueProductId, FieldValueProductVariantId, FieldValueProductLanguageId, FieldValueValue) VALUES ('tcLoginProfile', 'tc_users', 'TCPROD0060', '', 'ENU', N'Elevated');

COMMIT TRAN;
PRINT 'Done - truvio-demo catalogue: 16 groups (4 top + 12 sub), 60 masters + 36 variant rows, 40 prices, 2 BOM slots, 4 categories / 28 fields / 180 values in SHOP1.';
