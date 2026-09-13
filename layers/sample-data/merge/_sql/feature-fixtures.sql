-- ===========================================================================
-- sample-data layer - feature demo fixtures (Foundry #960)
-- ===========================================================================
-- WHY THIS FILE EXISTS
-- Until sample-data 2.3.0 three feature layers shipped their own catalogue rows
-- in their merge/_sql/ mode trees (feature-pricing PACK-RPP-*, feature-bom-
-- configurator PACK-BOM-*, feature-subscription-orders PACK-SUB-*), each
-- justified in its README as "catalog self-sufficiency". The consequence,
-- measured on the e2e host and filed as Foundry issue 960: an edition composed
-- with sampleData false landed 8 products, 5 groups and 4 prices while the
-- composer result reported no sample data, because the sampleData toggle gates
-- only THIS layer. The invariant the distribution wants is the plain one - the
-- catalogue rides the single sampleData toggle and nothing else - so the rows
-- moved here verbatim and the feature layers now ship zero catalogue rows.
--
-- KEYS ARE UNCHANGED. Every id below is byte-identical to the row the feature
-- layer used to ship, because each layer's behaviorProbes, configRows and demo
-- pages address these products by id. Only the OWNER moved.
--
-- Contents (on top of catalog.sql's 20 products / 3 groups):
--   5 groups    PACK-RPP-GRP1, PACK-BOM-GRP1, PACK-BOM-FORKS, PACK-BOM-RACKS,
--               PACK-SUB-GRP1
--   8 products  PACK-RPP-PROD1/2, PACK-BOM-0001, PACK-BOM-FORK-1/2,
--               PACK-BOM-RACK-1/2, PACK-SUB-PROD1
--   4 prices    PACK-RPP-0001..0004 (the qty-tier ladder + the contract row for
--               base-contract buyer 98745621)
--   2 BOM slots PACK-BOM3-0002/0003 on PACK-BOM-0001
--
-- Runs AFTER catalog.sql (same phase, order 2): it FKs the same framework rows
-- (EcomShops SHOP1, EcomCurrencies EUR, product language ENU) and nothing that
-- catalog.sql inserts.
-- Idempotent: DELETE-then-INSERT on the PACK-* reserved key prefixes only, so it
-- never touches the FIXT* rows catalog.sql owns.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

-- 0. Idempotent reset, scoped to the three PACK-* families this file owns.
DELETE FROM EcomProductItems         WHERE ProductItemId LIKE 'PACK-BOM3-%';
DELETE FROM EcomPrices               WHERE PriceId LIKE 'PACK-RPP-%';
DELETE FROM EcomGroupProductRelation WHERE GroupProductRelationProductId LIKE 'PACK-RPP-%'
                                        OR GroupProductRelationProductId LIKE 'PACK-BOM-%'
                                        OR GroupProductRelationProductId LIKE 'PACK-SUB-%';
DELETE FROM EcomShopGroupRelation    WHERE ShopGroupGroupId IN ('PACK-RPP-GRP1', 'PACK-BOM-GRP1', 'PACK-BOM-FORKS', 'PACK-BOM-RACKS', 'PACK-SUB-GRP1');
DELETE FROM EcomProducts             WHERE ProductId LIKE 'PACK-RPP-%'
                                        OR ProductId LIKE 'PACK-BOM-%'
                                        OR ProductId LIKE 'PACK-SUB-%';
DELETE FROM EcomGroups               WHERE GroupId IN ('PACK-RPP-GRP1', 'PACK-BOM-GRP1', 'PACK-BOM-FORKS', 'PACK-BOM-RACKS', 'PACK-SUB-GRP1');

-- 1. Groups. None show in the menu: these are feature-demo catalogues reached
--    from the feature's own page, not from storefront navigation.
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('PACK-RPP-GRP1',  'ENU', N'Reordering Pack Catalog',   '', 0, 1, 1);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('PACK-BOM-GRP1',  'ENU', N'Kit Configurator Catalog',  '', 0, 1, 1);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('PACK-BOM-FORKS', 'ENU', N'Kit Forks',                 '', 0, 1, 1);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('PACK-BOM-RACKS', 'ENU', N'Kit Racks',                 '', 0, 1, 1);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNumber, GroupNavigationShowInMenu, GroupNavigationShowInSiteMap, GroupNavigationClickable) VALUES ('PACK-SUB-GRP1',  'ENU', N'Subscription Pack Catalog', '', 0, 1, 1);

INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'PACK-RPP-GRP1',  100);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'PACK-BOM-GRP1',  100);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'PACK-BOM-FORKS', 100);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'PACK-BOM-RACKS', 100);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'PACK-SUB-GRP1',  100);

-- 2. Products. ProductUniqueId is carried verbatim where the source row had one,
--    so the row stays stable across a re-seed.
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductUniqueId, ProductCreated, ProductUpdated)
VALUES ('PACK-RPP-PROD1', 'ENU', '', 'RPP-TIER-01', N'Reordering Tier Product', N'Placeholder product. Demonstrates quantity-break tier pricing for the feature-pricing layer.', 4995, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', 'b1a7e2c4-1111-4a1b-9c01-a1a1a1a1a101', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductUniqueId, ProductCreated, ProductUpdated)
VALUES ('PACK-RPP-PROD2', 'ENU', '', 'RPP-CTR-01', N'Reordering Contract Product', N'Placeholder product. Demonstrates buyer-scoped contract pricing for the feature-pricing layer.', 1599, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', 'b1a7e2c4-2222-4a1b-9c01-a2a2a2a2a202', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductUniqueId, ProductCreated, ProductUpdated)
VALUES ('PACK-BOM-0001', 'ENU', '', '10004kit', N'Truvio Kit Configurator (BOM)', N'Placeholder product. Multi-group bill-of-materials parent: pick a fork and a rack, add the configured kit to the cart.', 0, 0, 1, 2, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', '5e8f8b07-f01a-440b-bc24-ab8ad8eef14c', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductCreated, ProductUpdated)
VALUES ('PACK-BOM-FORK-1', 'ENU', '', 'BOM-FORK-1', N'BOM Fork (standard)', N'Placeholder product. Bill-of-materials child component, standard tier.', 120, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductCreated, ProductUpdated)
VALUES ('PACK-BOM-FORK-2', 'ENU', '', 'BOM-FORK-2', N'BOM Fork (premium)', N'Placeholder product. Bill-of-materials child component, premium tier.', 180, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductCreated, ProductUpdated)
VALUES ('PACK-BOM-RACK-1', 'ENU', '', 'BOM-RACK-1', N'BOM Rack (standard)', N'Placeholder product. Bill-of-materials child component, standard tier.', 60, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductCreated, ProductUpdated)
VALUES ('PACK-BOM-RACK-2', 'ENU', '', 'BOM-RACK-2', N'BOM Rack (premium)', N'Placeholder product. Bill-of-materials child component, premium tier.', 90, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductStock, ProductActive, ProductType, ProductPriceType, ProductNeverOutOfStock, ProductHidden, ProductExcludeFromIndex, ProductExcludeFromAllProducts, ProductApprovalState, ProductWorkflowStateId, ProductDefaultShopId, ProductUniqueId, ProductCreated, ProductUpdated)
VALUES ('PACK-SUB-PROD1', 'ENU', '', 'SUB-PLAN-01', N'Subscription Plan Product', N'Placeholder product. Recurring / subscription order demo product.', 49, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 'SHOP1', 'c3b7e2c4-3333-4a1b-9c01-a3a3a3a3a303', GETDATE(), GETDATE());

-- 3. Group relations.
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-RPP-GRP1',  'PACK-RPP-PROD1',  1, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-RPP-GRP1',  'PACK-RPP-PROD2',  2, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-BOM-GRP1',  'PACK-BOM-0001',   1, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-BOM-FORKS', 'PACK-BOM-FORK-1', 1, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-BOM-FORKS', 'PACK-BOM-FORK-2', 2, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-BOM-RACKS', 'PACK-BOM-RACK-1', 1, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-BOM-RACKS', 'PACK-BOM-RACK-2', 2, 1, GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('PACK-SUB-GRP1',  'PACK-SUB-PROD1',  1, 1, GETDATE());

-- 4. BOM slots on PACK-BOM-0001. Each slot binds a GROUP and names a default
--    child, which is what makes the configurator a picker and not a fixed kit.
INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
VALUES ('PACK-BOM3-0002', 'PACK-BOM-0001', '', 'PACK-BOM-FORKS', 1, N'Fork', 1, 'PACK-BOM-FORK-1', '', 1, '', '', '', '');
INSERT INTO EcomProductItems (ProductItemId, ProductItemProductId, ProductItemBomProductId, ProductItemBomGroupId, ProductItemQuantity, ProductItemName, ProductItemRequired, ProductItemDefaultProductId, ProductItemBomNoProductText, ProductItemSortOrder, ProductItemBomVariantId, ProductItemDefaultVariantId, ProductItemDefaultUnitId, ProductItemBomUnitId)
VALUES ('PACK-BOM3-0003', 'PACK-BOM-0001', '', 'PACK-BOM-RACKS', 1, N'Rack', 1, 'PACK-BOM-RACK-1', '', 2, '', '', '', '');

-- 5. Prices: the qty-tier ladder on PACK-RPP-PROD1 and the buyer-scoped contract
--    row on PACK-RPP-PROD2. Contract pricing resolves by PriceUserCustomerNumber
--    (base-contract buyer 98745621), never by PriceCustomerGroupId.
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PricePriority, PriceUserCustomerNumber, PriceDiscountPercentage, PriceAllowOrderLineDiscounts, PriceAllowOrderDiscounts) VALUES ('PACK-RPP-0001', 'PACK-RPP-PROD1', 'EUR',  5, 4500.0, '', 0, '',         0, 1, 1);
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PricePriority, PriceUserCustomerNumber, PriceDiscountPercentage, PriceAllowOrderLineDiscounts, PriceAllowOrderDiscounts) VALUES ('PACK-RPP-0002', 'PACK-RPP-PROD1', 'EUR', 10, 4200.0, '', 0, '',         0, 1, 1);
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PricePriority, PriceUserCustomerNumber, PriceDiscountPercentage, PriceAllowOrderLineDiscounts, PriceAllowOrderDiscounts) VALUES ('PACK-RPP-0003', 'PACK-RPP-PROD1', 'EUR', 25, 3900.0, '', 0, '',         0, 1, 1);
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PricePriority, PriceUserCustomerNumber, PriceDiscountPercentage, PriceAllowOrderLineDiscounts, PriceAllowOrderDiscounts) VALUES ('PACK-RPP-0004', 'PACK-RPP-PROD2', 'EUR',  1, 1399.0, '', 0, '98745621', 0, 1, 1);

COMMIT TRAN;
