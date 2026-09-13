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
--   NEUTRALIZATION CONVENTION: reserved KEYS stay FIXT*-prefixed, but every
--   DISPLAY value is function-descriptive placeholder data - it names what the row
--   exists to demonstrate, never a real-world product domain. Products are
--   'Sample Product NN - <role>'; groups are 'Sample Group N - <function>'; every
--   ShortDescription opens with the literal word 'Placeholder', which is the
--   machine-detectable marker a design gate scans for (/placeholder/i). On any
--   edition with sampleData: true this is the catalogue a prospect sees, and the
--   build replaces it per customer.
--
--   THESE ROWS ARE GATE FIXTURES, NEVER BROWSABLE DEMO CONTENT - the sentence above
--   describes what sampleData: true USED to mean and is kept only so the convention
--   reads whole. Owner decision, Foundry #1074 (2026-09-13): the FIXT*/PACK-* rows
--   exist so the gate's layer-declared probes have stable, id-addressable subjects,
--   not so a prospect can browse them. Composed into a storefront a prospect opens
--   they are a measured defect, twice filed - 12 bare 'Placeholder product.' strings
--   on the unfiltered /en-us/shop (#1174) and 6 'Sample Group N' values in the PLP
--   facet rail, which is the permanent STOCKCOPY-01 design FAIL (#1127, rail
--   re-screened in #1134). The fix is COMPOSITIONAL and lives in editions/, not in
--   this file: exactly ONE edition sets sampleData: true on the Swift surface -
--   editions/gate-fixtures.json - and swift-demo, the edition a prospect sees, sets
--   it false and takes its catalogue from the truvio-demo layer. Nothing here moved
--   and no id changed. Do not neutralize these strings any further: the marker word
--   is what the placeholder asserts key on, and it is correct for a fixture to
--   carry it.
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
--   EM DASH, AND WHY IT IS NOT A LITERAL (Foundry #1095). The convention above
--   spells the separator as an em dash (U+2014), and a UTF-8 em dash in this file
--   is three bytes - E2 80 94. An applier that runs sqlcmd WITHOUT `-f 65001`
--   reads the file in the machine's ANSI code page (1252) and those three bytes
--   arrive as three characters: U+00E2 U+20AC U+201D. That is the corruption the
--   v5 e2e measured in the branded PLP facet sidebar - the FIXTGRP group names and
--   20 FIXT* product names rendered the mojibake, not the dash. So NO name literal
--   in this file carries a non-ASCII byte any more: the dash is written as its code
--   point, `N'...' + NCHAR(8212) + N'...'`, which every code page reads the same
--   way. The displayed value is unchanged. Section 6 then repairs a host seeded
--   before this change.
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
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNavigationShowInMenu, GroupNavigationClickable) VALUES ('FIXTGRP1', 'ENU', N'Sample Group 1 ' + NCHAR(8212) + N' Pricing Demos', 1, 1);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'FIXTGRP1', 1);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNavigationShowInMenu, GroupNavigationClickable) VALUES ('FIXTGRP2', 'ENU', N'Sample Group 2 ' + NCHAR(8212) + N' Plain Masters', 1, 1);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'FIXTGRP2', 2);
INSERT INTO EcomGroups (GroupId, GroupLanguageId, GroupName, GroupNavigationShowInMenu, GroupNavigationClickable) VALUES ('FIXTGRP3', 'ENU', N'Sample Group 3 ' + NCHAR(8212) + N' Variant Demos', 1, 1);
INSERT INTO EcomShopGroupRelation (ShopGroupShopId, ShopGroupGroupId, ShopGroupRelationsSorting) VALUES ('SHOP1', 'FIXTGRP3', 3);

-- 2. Master products (active, never-out-of-stock, priced) + primary group relation.
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0001', 'ENU', '', 'FIXT-0001', N'Sample Product 01 ' + NCHAR(8212) + N' Contract Price', N'Placeholder product. Demonstrates a buyer-scoped contract price (FIXT-PRICE-CONTRACT) and is the line item on the seeded delivered order the RMA flow returns against.', 200.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0001', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0002', 'ENU', '', 'FIXT-0002', N'Sample Product 02 ' + NCHAR(8212) + N' Qty Tiers', N'Placeholder product. Demonstrates the quantity-break price ladder (tiers at 5, 10 and 25).', 100.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0002', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0003', 'ENU', '', 'FIXT-0003', N'Sample Product 03 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master with a list price and no special pricing.', 85.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0003', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0004', 'ENU', '', 'FIXT-0004', N'Sample Product 04 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master used to give list and grid layouts more than one card.', 95.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0004', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0005', 'ENU', '', 'FIXT-0005', N'Sample Product 05 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master used to fill the product list beyond a single row.', 120.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0005', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0006', 'ENU', '', 'FIXT-0006', N'Sample Product 06 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master in the second group, so group navigation has something to switch between.', 45.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0006', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0007', 'ENU', '', 'FIXT-0007', N'Sample Product 07 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master demonstrating a higher price point in the same group.', 180.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0007', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0008', 'ENU', '', 'FIXT-0008', N'Sample Product 08 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master used by the search and facet probes.', 60.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0008', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0009', 'ENU', '', 'FIXT-0009', N'Sample Product 09 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master used by the search and facet probes.', 40.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP2', 'FIXT0009', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0010', 'ENU', '', 'FIXT-0010', N'Sample Product 10 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master in the third group, the lowest price band.', 25.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0010', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0011', 'ENU', '', 'FIXT-0011', N'Sample Product 11 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master used to demonstrate a low-value repeat-order line.', 12.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0011', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0012', 'ENU', '', 'FIXT-0012', N'Sample Product 12 ' + NCHAR(8212) + N' Master', N'Placeholder product. Plain catalogue master used to demonstrate a low-value repeat-order line.', 18.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0012', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0013', 'ENU', '', 'FIXT-0013', N'Sample Product 13 ' + NCHAR(8212) + N' Size Variants', N'Placeholder product. Demonstrates the Size variant axis: this master expands into Small, Medium and Large variant rows.', 22.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP3', 'FIXT0013', 1, 1, GETDATE());
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) VALUES ('FIXT0014', 'ENU', '', 'FIXT-0014', N'Sample Product 14 ' + NCHAR(8212) + N' Size Variants', N'Placeholder product. Second master on the Size variant axis, so variant behaviour is visible on more than one product.', 75.00, 1, 1, 100, 0, 'SHOP1', GETDATE(), GETDATE());
INSERT INTO EcomGroupProductRelation (GroupProductRelationGroupId, GroupProductRelationProductId, GroupProductRelationSorting, GroupProductRelationIsPrimary, GroupProductRelationCreated) VALUES ('FIXTGRP1', 'FIXT0014', 1, 1, GETDATE());

-- 3. Size variant axis (FIXTVG1) with 3 options, applied to 2 masters.
INSERT INTO EcomVariantGroups (VariantGroupId, VariantGroupLanguageId, VariantGroupName, VariantGroupLabel) VALUES ('FIXTVG1', 'ENU', 'Size', 'Size');
INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('FIXTVO1', 'ENU', 'FIXTVG1', 'Small', 1);
INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('FIXTVO2', 'ENU', 'FIXTVG1', 'Medium', 2);
INSERT INTO EcomVariantsOptions (VariantOptionId, VariantOptionLanguageId, VariantOptionGroupId, VariantOptionName, VariantOptionSortOrder) VALUES ('FIXTVO3', 'ENU', 'FIXTVG1', 'Large', 3);
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0013', 'FIXTVO1');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO1', ProductNumber + '-FIXTVO1', ProductName, ProductShortDescription, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0013' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0013', 'FIXTVO2');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO2', ProductNumber + '-FIXTVO2', ProductName, ProductShortDescription, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0013' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0013', 'FIXTVO3');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO3', ProductNumber + '-FIXTVO3', ProductName, ProductShortDescription, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0013' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0014', 'FIXTVO1');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO1', ProductNumber + '-FIXTVO1', ProductName, ProductShortDescription, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0014' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0014', 'FIXTVO2');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO2', ProductNumber + '-FIXTVO2', ProductName, ProductShortDescription, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0014' AND ProductVariantId = '';
INSERT INTO EcomVariantOptionsProductRelation (VariantOptionsProductRelationProductId, VariantOptionsProductRelationVariantId) VALUES ('FIXT0014', 'FIXTVO3');
INSERT INTO EcomProducts (ProductId, ProductLanguageId, ProductVariantId, ProductNumber, ProductName, ProductShortDescription, ProductPrice, ProductActive, ProductNeverOutOfStock, ProductStock, ProductType, ProductDefaultShopId, ProductCreated, ProductUpdated) SELECT ProductId, ProductLanguageId, 'FIXTVO3', ProductNumber + '-FIXTVO3', ProductName, ProductShortDescription, ProductPrice, 1, 1, 100, 0, ProductDefaultShopId, GETDATE(), GETDATE() FROM EcomProducts WHERE ProductId = 'FIXT0014' AND ProductVariantId = '';

-- 4. Prices: anonymous qty-tier ladder + one buyer-scoped contract row.
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-T05', 'FIXT0002', 'EUR', 5, 90.00, '', '');
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-T10', 'FIXT0002', 'EUR', 10, 80.00, '', '');
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-T25', 'FIXT0002', 'EUR', 25, 70.00, '', '');
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber) VALUES ('FIXT-PRICE-CONTRACT', 'FIXT0001', 'EUR', 1, 160.00, '', '98745621');

-- 5. RMA demo (P3 feature-rma interplay). One DELIVERED order for the base-contract
--    buyer (98745621) to return against, plus the RMA<->order-line link. The RMA
--    request HEADER (EcomRmas PACK-RMA-0001) is seeded by the feature-rma layer (its
--    nvarchar PK is serializer-friendly); the link (EcomRmaOrderLines) lives HERE
--    because RmaOrderLineId is an int IDENTITY PK the serializer cannot natural-key
--    insert (base contract wires that path for only 4 relation tables). No DB FK on the
--    RMA tables, so the header/link insert order across layers is free; both rows exist
--    by render time. In an edition WITHOUT feature-rma the link is a harmless orphan and
--    the order is just an extra completed order (no row-count / delivery-API impact).
--    Idempotent: DELETE-then-INSERT on the demo keys (lines before order = FK-safe).
DELETE FROM EcomRmaOrderLines WHERE RmaOrderLineRmaId = 'PACK-RMA-0001';
DELETE FROM EcomOrderLines    WHERE OrderLineOrderId  = 'FIXT-ORDER-RMA1';
DELETE FROM EcomOrders        WHERE OrderId           = 'FIXT-ORDER-RMA1';

INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
VALUES ('FIXT-ORDER-RMA1', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', '98745621', 1328, 'IMC User', 'imcuser@example.com', 'IMC Trading BV', 'NL', DATEADD(day, -30, GETDATE()), DATEADD(day, -28, GETDATE()), 200.00);
INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
VALUES ('FIXT-ORDER-RMA1-1', 'FIXT-ORDER-RMA1', 'FIXT0001', 'FIXT-0001', N'Sample Product 01 ' + NCHAR(8212) + N' Contract Price', 1, 200.00, 200.00, '0', DATEADD(day, -30, GETDATE()));
INSERT INTO EcomRmaOrderLines (RmaOrderLineRmaId, RmaOrderLineOrderLineId)
VALUES ('PACK-RMA-0001', 'FIXT-ORDER-RMA1-1');

-- 6. Mojibake repair (Foundry #1095): converge a host seeded by an earlier revision
--    of this script, or by an applier that read it in code page 1252. Section 0's
--    DELETE-then-INSERT already rewrites the rows this file owns; this pass is what
--    makes the convergence explicit and covers the snapshot columns a reset does not
--    reach. The signature is the CP1252 misdecode of the UTF-8 em dash -
--    U+00E2 U+20AC U+201D - rewritten to the single U+2014 the names are supposed to
--    carry. Existence-guarded: a clean host is never written to.
DECLARE @Mojibake NVARCHAR(8) = NCHAR(226) + NCHAR(8364) + NCHAR(8221);
DECLARE @EmDash   NVARCHAR(2) = NCHAR(8212);

IF EXISTS (SELECT 1 FROM EcomGroups WHERE GroupId LIKE 'FIXTGRP%' AND GroupName LIKE '%' + @Mojibake + '%')
    UPDATE EcomGroups
       SET GroupName = REPLACE(GroupName, @Mojibake, @EmDash)
     WHERE GroupId LIKE 'FIXTGRP%' AND GroupName LIKE '%' + @Mojibake + '%';

IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId LIKE 'FIXT%' AND (ProductName LIKE '%' + @Mojibake + '%' OR ProductShortDescription LIKE '%' + @Mojibake + '%'))
    UPDATE EcomProducts
       SET ProductName             = REPLACE(ProductName, @Mojibake, @EmDash),
           ProductShortDescription = REPLACE(ProductShortDescription, @Mojibake, @EmDash)
     WHERE ProductId LIKE 'FIXT%'
       AND (ProductName LIKE '%' + @Mojibake + '%' OR ProductShortDescription LIKE '%' + @Mojibake + '%');

IF EXISTS (SELECT 1 FROM EcomOrderLines WHERE OrderLineOrderId LIKE 'FIXT-ORDER-%' AND OrderLineProductName LIKE '%' + @Mojibake + '%')
    UPDATE EcomOrderLines
       SET OrderLineProductName = REPLACE(OrderLineProductName, @Mojibake, @EmDash)
     WHERE OrderLineOrderId LIKE 'FIXT-ORDER-%' AND OrderLineProductName LIKE '%' + @Mojibake + '%';

COMMIT TRAN;
PRINT 'Done - sample-data catalog: 3 groups, 14 masters + 6 variants (EcomProducts=20), 4 prices in SHOP1; + 1 delivered RMA demo order (FIXT-ORDER-RMA1) for buyer 98745621.';
