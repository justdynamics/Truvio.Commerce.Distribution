-- ===========================================================================
-- sample-data layer - demo shop catalog (deterministic, small, boring)
-- ===========================================================================
-- The base ships ZERO catalog (scaffolding-only). This script supplies the
-- demo products/groups/variants/prices for SHOP1 / ENU / EUR - the literal
-- base-contract anchors (layers/base/base.contract.json: one shop SHOP1,
-- default currency EUR, product language ENU).
-- Reserved key prefixes (base contract idRules.reservedFixtureKeys):
--   FIXT* / FIXTGRP* / FIXT-PRICE-* - no other layer may use them.
--
-- Contents (deterministic counts: EcomProducts = 20, EcomGroups = 3):
--   - 3 groups (FIXTGRP1..3) bound to SHOP1.
--   - 14 master products (FIXT0001..FIXT0014), active, never-out-of-stock,
--     priced, each related to a group.
--   - 1 "Size" variant axis (FIXTVG1, options S/M/L) on FIXT0013 + FIXT0014
--     => 6 variant product rows.
--   - 4 EcomPrices rows: a qty-tier ladder on FIXT0002 (qty 5/10/25) and ONE
--     buyer-scoped contract row on FIXT0001 (PriceUserCustomerNumber =
--     98745621, the base-contract buyer; 160.00 = list 200.00 x 0.8). Group
--     price columns stay empty - contract pricing resolves by customer
--     number, never PriceCustomerGroupId.
--
-- Apply AFTER the base layer deserialize (the framework rows this script FKs
-- against - EcomShops SHOP1, EcomCurrencies EUR - must exist), then restart
-- the DW host: the startup product-catalog cache must include these rows
-- before any storefront request.
-- Idempotent: DELETE-then-INSERT on the reserved FIXT* key prefixes.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

-- 0. Idempotent reset: remove any prior demo-catalog rows (keys are FIXT*-prefixed).
DELETE FROM EcomPrices                      WHERE PriceId LIKE 'FIXT-PRICE-%';
DELETE FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId LIKE 'FIXT%';
DELETE FROM EcomVariantsOptions             WHERE VariantOptionId LIKE 'FIXTVO%';
DELETE FROM EcomVariantGroups               WHERE VariantGroupId LIKE 'FIXTVG%';
DELETE FROM EcomGroupProductRelation        WHERE GroupProductRelationProductId LIKE 'FIXT%';
DELETE FROM EcomShopGroupRelation           WHERE ShopGroupGroupId LIKE 'FIXTGRP%';
DELETE FROM EcomProducts                    WHERE ProductId LIKE 'FIXT%';
DELETE FROM EcomGroups                      WHERE GroupId LIKE 'FIXTGRP%';

-- 1. Groups (bound to the shop).
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNavigationShowInMenu, GroupNavigationClickable) VALUES ('FIXTGRP1', 'ENU', 'Fixture Beverages', 1, 1);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'FIXTGRP1', 1);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNavigationShowInMenu, GroupNavigationClickable) VALUES ('FIXTGRP2', 'ENU', 'Fixture Equipment', 1, 1);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'FIXTGRP2', 2);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNavigationShowInMenu, GroupNavigationClickable) VALUES ('FIXTGRP3', 'ENU', 'Fixture Accessories', 1, 1);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'FIXTGRP3', 3);

-- 2. Master products (active, never-out-of-stock, priced) + primary group relation.
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0001', 'ENU', '', 'FIXT-0001', 'Fixture House Blend', 200.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0001', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0002', 'ENU', '', 'FIXT-0002', 'Fixture Single Origin', 100.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0002', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0003', 'ENU', '', 'FIXT-0003', 'Fixture Decaf', 85.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0003', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0004', 'ENU', '', 'FIXT-0004', 'Fixture Cold Brew', 95.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0004', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0005', 'ENU', '', 'FIXT-0005', 'Fixture Espresso Roast', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0005', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0006', 'ENU', '', 'FIXT-0006', 'Fixture Drip Filter', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0006', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0007', 'ENU', '', 'FIXT-0007', 'Fixture Grinder', 180.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0007', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0008', 'ENU', '', 'FIXT-0008', 'Fixture Kettle', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0008', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0009', 'ENU', '', 'FIXT-0009', 'Fixture Scale', 40.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0009', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0010', 'ENU', '', 'FIXT-0010', 'Fixture Tamper', 25.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0010', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0011', 'ENU', '', 'FIXT-0011', 'Fixture Filters Pack', 12.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0011', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0012', 'ENU', '', 'FIXT-0012', 'Fixture Cleaning Tablets', 18.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0012', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0013', 'ENU', '', 'FIXT-0013', 'Fixture Travel Mug', 22.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0013', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0014', 'ENU', '', 'FIXT-0014', 'Fixture Gift Box', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0014', 1, 1, GETDATE());

-- 3. Size variant axis (FIXTVG1) with 3 options, applied to 2 masters.
INSERT INTO EcomVariantGroups (VariantGroupId, VariantGroupLanguageId, VariantGroupName, VariantGroupLabel) VALUES ('FIXTVG1', 'ENU', 'Size', 'Size');
INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('FIXTVO1', 'ENU', 'FIXTVG1', 'Small', 1);
INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('FIXTVO2', 'ENU', 'FIXTVG1', 'Medium', 2);
INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('FIXTVO3', 'ENU', 'FIXTVG1', 'Large', 3);
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0013', 'FIXTVO1');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO1', ProductNumber + '-FIXTVO1', ProductName, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0013' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0013', 'FIXTVO2');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO2', ProductNumber + '-FIXTVO2', ProductName, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0013' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0013', 'FIXTVO3');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO3', ProductNumber + '-FIXTVO3', ProductName, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0013' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0014', 'FIXTVO1');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO1', ProductNumber + '-FIXTVO1', ProductName, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0014' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0014', 'FIXTVO2');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO2', ProductNumber + '-FIXTVO2', ProductName, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0014' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0014', 'FIXTVO3');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO3', ProductNumber + '-FIXTVO3', ProductName, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0014' AND ProductVariantId = '';

-- 4. Prices: anonymous qty-tier ladder + one buyer-scoped contract row.
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-T05', 'FIXT0002', 'EUR', 5, 90.00, '', '');
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-T10', 'FIXT0002', 'EUR', 10, 80.00, '', '');
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-T25', 'FIXT0002', 'EUR', 25, 70.00, '', '');
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-CONTRACT', 'FIXT0001', 'EUR', 1, 160.00, '', '98745621');

COMMIT TRAN;
PRINT 'Done - sample-data catalog: 3 groups, 14 masters + 6 variants (EcomProducts=20), 4 prices in SHOP1.';
