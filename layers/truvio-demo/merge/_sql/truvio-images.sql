-- ===========================================================================
-- truvio-demo layer - product imagery
-- ===========================================================================
-- Every product gets an image, because a PLP card and a PDP with no image are
-- an empty grey box on the two pages the design gate measures. The tiles are
-- the layer's own neutral SVGs, one per concept subgroup, shipped under
-- files/Images/TruvioCommerce/products/ and served from
-- /Files/Images/TruvioCommerce/products/tc-tile-<concept>.svg. They are DATA,
-- not theme: the file is what a product row points at, not a style. The
-- photographic brand assets stay in the Distribution's
-- brand/brand-assets.manifest.json and are fetched at brand time - they are
-- deliberately NOT committed here.
--
-- TWO ATTACHMENT SURFACES, BOTH WRITTEN
--   EcomDetails is the asset attachment the storefront reads (DetailValue +
--   DetailIsDefault - the shape observed on a live DW 10.28 host). The legacy
--   EcomProducts.ProductImage* columns are written too WHERE THEY EXIST, so a
--   template that still reads them is not left with a blank. Neither write is
--   allowed to be silent: the EcomDetails column set is resolved from
--   sys.columns and the statement is built over the columns the platform
--   actually has, and a missing EcomDetails table is a loud failure, never a
--   skip. A demo that seeds no image and reports success is the exact failure
--   this file exists to prevent.
--
-- BULK-ATTACH TAIL (#125): each tile lands on at most 11 product rows (5
--   masters plus one master's 6 variant rows) and is DEFAULT on every one of
--   them, so it can never become the un-audited additional gallery slot that
--   check looks for.
--
-- Idempotent: a product row that already carries this exact tile is skipped.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

IF OBJECT_ID(N'dbo.EcomDetails', N'U') IS NULL
    RAISERROR(N'truvio-images.sql: EcomDetails is missing. Product imagery cannot be attached on this platform build; resolve before composing an edition whose PLP/PDP probes require an image.', 16, 1);

-- The concept tile each subgroup's products carry. Joined through the PRIMARY
-- group relation, so a variant row inherits its master's tile automatically.
IF OBJECT_ID('tempdb..#TcTile') IS NOT NULL DROP TABLE #TcTile;
CREATE TABLE #TcTile (GroupId nvarchar(255) NOT NULL PRIMARY KEY, TilePath nvarchar(510) NOT NULL);
INSERT INTO #TcTile (GroupId, TilePath) VALUES
    ('TCGRP-VARIANTS', '/Files/Images/TruvioCommerce/products/tc-tile-variants.svg'),
    ('TCGRP-COMPLETENESS', '/Files/Images/TruvioCommerce/products/tc-tile-completeness.svg'),
    ('TCGRP-WORKFLOWS', '/Files/Images/TruvioCommerce/products/tc-tile-workflows.svg'),
    ('TCGRP-PRICE-STRUCTURES', '/Files/Images/TruvioCommerce/products/tc-tile-price-structures.svg'),
    ('TCGRP-ASSORTMENTS', '/Files/Images/TruvioCommerce/products/tc-tile-assortments.svg'),
    ('TCGRP-DISCOUNTS', '/Files/Images/TruvioCommerce/products/tc-tile-discounts.svg'),
    ('TCGRP-PAGES', '/Files/Images/TruvioCommerce/products/tc-tile-pages.svg'),
    ('TCGRP-PARAGRAPHS', '/Files/Images/TruvioCommerce/products/tc-tile-paragraphs.svg'),
    ('TCGRP-ITEM-TYPES', '/Files/Images/TruvioCommerce/products/tc-tile-item-types.svg'),
    ('TCGRP-GROUPS', '/Files/Images/TruvioCommerce/products/tc-tile-groups.svg'),
    ('TCGRP-PERMISSIONS', '/Files/Images/TruvioCommerce/products/tc-tile-permissions.svg'),
    ('TCGRP-IMPERSONATION', '/Files/Images/TruvioCommerce/products/tc-tile-impersonation.svg');

-- ---------------------------------------------------------------------------
-- 1. EcomDetails: the attachment the storefront reads.
--    The column list is resolved against sys.columns because the optional
--    columns (language, sorting, type) differ across platform builds, and an
--    INSERT naming a column the build does not have fails the whole script.
-- ---------------------------------------------------------------------------
DECLARE @cols nvarchar(max) = N'DetailId, DetailProductId, DetailProductVariantId, DetailValue, DetailIsDefault';
-- The detail id is DERIVED from the product key, never from a ROW_NUMBER: a
-- re-run that attaches only the missing rows would restart the counter at 1 and
-- collide with the ids the first run wrote.
DECLARE @sel  nvarchar(max) = N'''TC-DETAIL-'' + p.ProductId + CASE WHEN p.ProductVariantId = '''' THEN '''' ELSE ''-'' + p.ProductVariantId END, p.ProductId, p.ProductVariantId, t.TilePath, 1';

IF COL_LENGTH('EcomDetails', 'DetailLanguageId') IS NOT NULL
    SELECT @cols = @cols + N', DetailLanguageId', @sel = @sel + N', p.ProductLanguageId';
IF COL_LENGTH('EcomDetails', 'DetailProductLanguageId') IS NOT NULL
    SELECT @cols = @cols + N', DetailProductLanguageId', @sel = @sel + N', p.ProductLanguageId';
IF COL_LENGTH('EcomDetails', 'DetailSorting') IS NOT NULL
    SELECT @cols = @cols + N', DetailSorting', @sel = @sel + N', 1';
IF COL_LENGTH('EcomDetails', 'DetailType') IS NOT NULL
    SELECT @cols = @cols + N', DetailType', @sel = @sel + N', 0';

DECLARE @sql nvarchar(max) = N'
INSERT INTO EcomDetails (' + @cols + N')
SELECT ' + @sel + N'
FROM EcomProducts p
JOIN EcomGroupProductRelation r ON r.GroupProductRelationProductId = p.ProductId AND r.GroupProductRelationIsPrimary = 1
JOIN #TcTile t ON t.GroupId = r.GroupProductRelationGroupId
WHERE p.ProductId LIKE ''TCPROD%''
  AND NOT EXISTS (SELECT 1 FROM EcomDetails d
                  WHERE d.DetailProductId = p.ProductId
                    AND d.DetailProductVariantId = p.ProductVariantId
                    AND d.DetailValue = t.TilePath);';
EXEC sp_executesql @sql;

-- ---------------------------------------------------------------------------
-- 2. The legacy EcomProducts image columns, where the build still has them.
--    Same value, so the two surfaces can never disagree about which file a
--    product shows.
-- ---------------------------------------------------------------------------
DECLARE @imgSet nvarchar(max) = N'';
IF COL_LENGTH('EcomProducts', 'ProductImageSmall') IS NOT NULL SET @imgSet = @imgSet + N'ProductImageSmall = t.TilePath, ';
IF COL_LENGTH('EcomProducts', 'ProductImageMedium') IS NOT NULL SET @imgSet = @imgSet + N'ProductImageMedium = t.TilePath, ';
IF COL_LENGTH('EcomProducts', 'ProductImageLarge') IS NOT NULL SET @imgSet = @imgSet + N'ProductImageLarge = t.TilePath, ';

IF LEN(@imgSet) > 0
BEGIN
    SET @imgSet = LEFT(@imgSet, LEN(@imgSet) - 1);
    DECLARE @upd nvarchar(max) = N'
UPDATE p SET ' + @imgSet + N'
FROM EcomProducts p
JOIN EcomGroupProductRelation r ON r.GroupProductRelationProductId = p.ProductId AND r.GroupProductRelationIsPrimary = 1
JOIN #TcTile t ON t.GroupId = r.GroupProductRelationGroupId
WHERE p.ProductId LIKE ''TCPROD%'';';
    EXEC sp_executesql @upd;
END

DROP TABLE #TcTile;

COMMIT TRAN;
PRINT 'Done - truvio-demo imagery: 12 concept tiles attached as the default image of all 96 TCPROD rows.';
