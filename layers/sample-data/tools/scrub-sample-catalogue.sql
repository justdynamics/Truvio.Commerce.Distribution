-- ===========================================================================
-- scrub-sample-catalogue.sql - OPTIONAL, and deliberately NOT declared in
-- sample-data/layer.json sql[].
--
-- WHAT IT DOES. Removes the WHOLE Truvio Commerce sample catalogue and its PIM
-- structure from a host that was delivered with this layer, and keeps everything
-- about the host that is not catalogue: the three personas and their account, the
-- twelve orders, the storefront copy on Home / About / Contact / header / footer /
-- mega-menu, the demo clock and its tables, the email statistics, and every base
-- row (countries, currencies, languages, payments, shippings, order states, stock
-- locations, SHOP1).
--
-- WHY IT EXISTS. A branded demo starts from a composed swift-demo host and then
-- loads the customer's own catalogue. The sample catalogue is then not a neutral
-- placeholder, it is wrong data in the customer's channel: a prospect sees
-- "Truvio Variant Master 01" next to their own SKUs, and a PIM tree named after
-- platform vocabulary next to their own data models. Deleting it by hand is thirty
-- statements in an order that matters, so it ships here.
--
-- WHY IT IS NOT DECLARED IN sql[]. A declared script is one the composer RUNS,
-- and the composer's job is to deliver the catalogue, not to delete it. Whether a
-- host keeps the sample catalogue is a per-delivery editorial decision, exactly
-- like tools/truvio-gallery-photos.sql beside it.
--
-- IDEMPOTENT, and re-run after EVERY delivery: a merge deserialize re-inserts
-- every row this removes. Every statement is a keyed DELETE, so a second run
-- deletes nothing and the summary SELECT at the foot reads the same.
--
-- WHAT IT DELIBERATELY DOES NOT TOUCH, and why:
--   EcomStockLocation        base 3.6.0 owns the three neutral locations
--                            (Central warehouse / Regional warehouse / Default
--                            stock location) and SHOP1.ShopStockLocationID
--                            references them. Renaming them is a BRAND step, not
--                            a scrub step.
--   the baseline's own       the bike and clothing Dynamic Workspaces come from
--   Dynamic Workspaces       the dw10-demo-empty BASELINE DB, not from any layer.
--                            A delivery does not re-insert them, so removing them
--                            is a one-time act that belongs to whoever prepared
--                            the baseline. This script removes only workspace
--                            100170, the one THIS layer ships.
--   reference_category       the PARENT category row is base-owned (base 3.6.0).
--                            Only the 28 mirror FIELD rows this layer put there
--                            are removed, fenced on FieldId LIKE 'tc%'.
--   AccessUser / EcomOrders  the personas and their history are what makes the
--                            host still demonstrable after the scrub.
--   EcomDetailsGroup         the Images (100110) and Manuals (100111) asset
--                            categories are catalogue INFRASTRUCTURE, not sample
--                            data: the Swift PDP documents table binds Manuals by
--                            system name, and a branded catalogue's own assets
--                            want both. Their tc rows go; the categories stay.
--   EcomProductField         the six TCFIELD-* rows are SETTINGS rows for six
--                            STANDARD product fields (variant editing on
--                            ProductNumber, ProductPrice, ProductStock and three
--                            more). They carry no catalogue data, and a branded
--                            catalogue with variants needs them ON.
--
-- RUN IT AS: sqlcmd -S <server> -d <db> -i scrub-sample-catalogue.sql
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- --- the PIM structure (5.0.0) -------------------------------------------
-- Levels before the structure they hang off. Levels join their structure by its
-- UniqueId GUID held as nvarchar, never by its int id, so the delete states both
-- the reserved id range and that GUID.
DELETE FROM DynamicStructureLevels
 WHERE DynamicStructureLevelId BETWEEN 100171 AND 100172
    OR DynamicStructureLevelStructureId = N'7C0A1D2E-5B4F-4E8A-9C3D-2026091900A1';
DELETE FROM DynamicStructures WHERE DynamicStructureId = 100170;

DELETE FROM EcomCompletionRules WHERE EcomCompletionRuleId BETWEEN 100160 AND 100163;

DELETE FROM EcomShopGroupRelation WHERE ShopGroupShopId = N'TCSHOP-PIM' OR ShopGroupGroupId LIKE 'TCDM-%';
DELETE FROM EcomShopLanguageRelation WHERE ShopId = N'TCSHOP-PIM';
DELETE FROM EcomShops WHERE ShopId = N'TCSHOP-PIM';

-- The 28 reference_category MIRROR rows only. The parent category row and its
-- translation are base-owned and stay: another solution's fields need them.
DELETE FROM EcomProductCategoryFieldTranslation
 WHERE FieldTranslationFieldCategoryId = N'reference_category' AND FieldTranslationFieldId LIKE 'tc%';
DELETE FROM EcomProductCategoryField
 WHERE FieldCategoryId = N'reference_category' AND FieldId LIKE 'tc%';

-- --- the catalogue --------------------------------------------------------
DELETE FROM EcomStockUnit WHERE StockUnitProductId LIKE 'TCPROD%';
DELETE FROM EcomShopGroupRelation WHERE ShopGroupGroupId LIKE 'TCGRP%';
DELETE FROM EcomGroupProductRelation
 WHERE GroupProductRelationGroupId LIKE 'TCGRP%' OR GroupProductRelationGroupId LIKE 'TCDM-%'
    OR GroupProductRelationProductId LIKE 'TCPROD%';
DELETE FROM EcomGroupRelations
 WHERE GroupRelationsGroupId LIKE 'TCGRP%' OR GroupRelationsParentId LIKE 'TCGRP%'
    OR GroupRelationsGroupId LIKE 'TCDM-%' OR GroupRelationsParentId LIKE 'TCDM-%';
DELETE FROM EcomGroups WHERE GroupId LIKE 'TCGRP%' OR GroupId LIKE 'TCDM-%';
DELETE FROM EcomProductsRelated
 WHERE ProductRelatedProductId LIKE 'TCPROD%' OR ProductRelatedProductRelId LIKE 'TCPROD%';
DELETE FROM EcomProductsRelatedGroups WHERE RelatedGroupId LIKE 'TCREL-%';
DELETE FROM EcomDetails WHERE DetailProductId LIKE 'TCPROD%';
DELETE FROM EcomPrices WHERE PriceId LIKE 'TC-PRICE-%' OR PriceProductId LIKE 'TCPROD%';
DELETE FROM EcomProductItems WHERE ProductItemId LIKE 'TC-BOM-%' OR ProductItemProductId LIKE 'TCPROD%';
DELETE FROM EcomVariantOptionsProductRelation WHERE VariantOptionsProductRelationProductId LIKE 'TCPROD%';
DELETE FROM EcomVariantGroupProductRelation WHERE VariantGroupProductRelationProductId LIKE 'TCPROD%';
DELETE FROM EcomVariantsOptions WHERE VariantOptionId LIKE 'TCVO-%';
DELETE FROM EcomVariantGroups WHERE VariantGroupId LIKE 'TCVG-%';
DELETE FROM EcomProductCategoryFieldValue
 WHERE FieldValueFieldCategoryId LIKE 'tc[_]%' OR FieldValueProductId LIKE 'TCPROD%';
DELETE FROM EcomFieldDisplayGroupFields WHERE FieldDisplayGroupFieldGroupId = 100120;
DELETE FROM EcomFieldDisplayGroupTranslation WHERE FieldDisplayGroupTranslationGroupId = 100120;
DELETE FROM EcomFieldDisplayGroups WHERE FieldDisplayGroupId = 100120;
DELETE FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldCategoryId LIKE 'tc[_]%';
DELETE FROM EcomProductCategoryField WHERE FieldCategoryId LIKE 'tc[_]%';
DELETE FROM EcomProductCategoryTranslation WHERE CategoryTranslationCategoryId LIKE 'tc[_]%';
DELETE FROM EcomProductCategory WHERE CategoryId LIKE 'tc[_]%';
DELETE FROM EcomProducts WHERE ProductId LIKE 'TCPROD%';

COMMIT TRANSACTION;

SELECT 'TC products'          AS what, CAST((SELECT COUNT(*) FROM EcomProducts WHERE ProductId LIKE 'TCPROD%') AS nvarchar(20)) AS remaining
UNION ALL SELECT 'TC catalogue groups', CAST((SELECT COUNT(*) FROM EcomGroups WHERE GroupId LIKE 'TCGRP%') AS nvarchar(20))
UNION ALL SELECT 'TCDM data models',    CAST((SELECT COUNT(*) FROM EcomGroups WHERE GroupId LIKE 'TCDM-%') AS nvarchar(20))
UNION ALL SELECT 'TCSHOP-PIM shop',     CAST((SELECT COUNT(*) FROM EcomShops WHERE ShopId = N'TCSHOP-PIM') AS nvarchar(20))
UNION ALL SELECT 'tc categories',       CAST((SELECT COUNT(*) FROM EcomProductCategory WHERE CategoryId LIKE 'tc[_]%') AS nvarchar(20))
UNION ALL SELECT 'tc mirror fields',    CAST((SELECT COUNT(*) FROM EcomProductCategoryField WHERE FieldCategoryId = N'reference_category' AND FieldId LIKE 'tc%') AS nvarchar(20))
UNION ALL SELECT 'TC completion rules', CAST((SELECT COUNT(*) FROM EcomCompletionRules WHERE EcomCompletionRuleId BETWEEN 100160 AND 100163) AS nvarchar(20))
UNION ALL SELECT 'TC workspaces',       CAST((SELECT COUNT(*) FROM DynamicStructures WHERE DynamicStructureId = 100170) AS nvarchar(20))
UNION ALL SELECT 'KEPT: personas',      CAST((SELECT COUNT(*) FROM AccessUser WHERE AccessUserId BETWEEN 100100 AND 100103) AS nvarchar(20))
UNION ALL SELECT 'KEPT: orders',        CAST((SELECT COUNT(*) FROM EcomOrders WHERE OrderId LIKE 'TCO-%') AS nvarchar(20))
UNION ALL SELECT 'KEPT: stock locations', ISNULL((SELECT STRING_AGG(StockLocationName, N', ') FROM EcomStockLocation), N'(none)')
UNION ALL SELECT 'KEPT: products on host', CAST((SELECT COUNT(*) FROM EcomProducts) AS nvarchar(20));
-- Every TC/tc row above must read 0 and every KEPT row must be non-empty. Then
-- rebuild the product index (Products / Products.index) and restart the host: the
-- group-product relation cache and CompletionRuleService are in-process.
