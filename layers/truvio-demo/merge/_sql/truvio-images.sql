-- ===========================================================================
-- truvio-demo layer - product imagery
-- ===========================================================================
-- Every product gets its OWN image, and a second one to hover onto. A PLP card
-- and a PDP with no image are an empty grey box on the two pages the design gate
-- measures; five cards carrying the same picture are the same failure one step
-- later, because the row a buyer scans in order to choose between products is
-- showing one product five times.
--
-- WHAT CHANGED AT 1.5.0 (#1157). Until 1.4.0 this file mapped a tile per
-- SUBGROUP - twelve pictures over ninety-six product rows, five or six products
-- per picture - and nominated no second image at all, so the PLP card's
-- ShowAlternativeImageOnHover had nothing to swap to. It now maps a tile per
-- PRODUCT and attaches a second, differently-composed image beside it. The
-- twelve concept tiles stay on disk and stay in files[]: the PDP gallery strip
-- in truvio-pdp.sql still draws them, and a picture a product does not own is
-- exactly what a strip is for.
--
-- WHAT CHANGED AT 1.7.0 (Foundry #1171). The rows point at PNG. Dynamicweb's
-- GetImage.ashx decodes with SixLabors.ImageSharp, and ImageSharp ships no SVG
-- decoder: the 500 body names its set - Webp, TIFF, GIF, TGA, JPEG, PNG, PBM,
-- BMP - and nothing in it parses XML vector markup. Measured read-only on the
-- composed host: the raw /Files/... path 200 at 1209 bytes, the same file through
-- the handler 500 with width and format, 500 with width alone, 500 with no
-- parameters at all, and a PNG through the identical handler 200. Swift's card
-- and gallery components only ever ask through that handler, because they need
-- its width and crop arguments, so every tc-* image this file mapped had been a
-- broken picture behind a correctly-counted img node since 1.2.0. tools/
-- make-tiles.py now writes a PNG beside each SVG; the SVGs stay as the authoring
-- sources and stay in files[].
--
-- THE TILES ARE DATA, not theme: the file is what a product row points at, never
-- a style. They are generated, deterministically and self-contained, by
-- tools/make-tiles.py - 120 files, two per master, each carrying the product's
-- own index at a size that survives a 120px card. The photographic brand assets
-- stay in the Distribution's brand/brand-assets.manifest.json and are fetched at
-- brand time; they are deliberately NOT committed here.
--
-- THE HOVER ROW IS THE SECOND-LOWEST-SORTED IMAGE, and that is load-bearing.
-- Swift-v2_ProductDefaultImage.cshtml builds its alternative from
-- product.AssetCategories filtered to the ONE category the paragraph's
-- GetAlternativeImageFrom radio names (Images), removes the default image from
-- what that yields, and takes the FIRST of what is left. So the second image has
-- to be (a) in the Images asset category - truvio-pdp.sql's path-scoped UPDATE
-- puts it there, which is why this file does not name the category itself - and
-- (b) sorted ahead of the PDP gallery rows, which sit at 2 and 3. Default 0,
-- hover 1, gallery 2 and 3.
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
-- BULK-ATTACH TAIL (#125): each tile now lands on at most 7 product rows (one
--   master plus, on the six masters that have them, its 6 variant rows) and is
--   DEFAULT on every one of them, so it can never become the un-audited
--   additional gallery slot that check looks for. The hover row is default on
--   none of them, and is the only non-default row this file writes.
--
-- Idempotent, and CONVERGING: a host seeded at 1.4.0 carries TC-DETAIL-* rows
-- pointing at the old subgroup tiles. The ids are derived from the product key
-- and are therefore stable, so the same ids are updated in place rather than a
-- second set being inserted beside them.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

IF OBJECT_ID(N'dbo.EcomDetails', N'U') IS NULL
    RAISERROR(N'truvio-images.sql: EcomDetails is missing. Product imagery cannot be attached on this platform build; resolve before composing an edition whose PLP/PDP probes require an image.', 16, 1);

-- The tile and the hover image each MASTER carries. Variant rows join on
-- ProductId and therefore inherit their master's pair, which is what a variant
-- combination should show: the same product in another configuration.
IF OBJECT_ID('tempdb..#TcTile') IS NOT NULL DROP TABLE #TcTile;
CREATE TABLE #TcTile (ProductId nvarchar(255) NOT NULL PRIMARY KEY, TilePath nvarchar(510) NOT NULL, DetailPath nvarchar(510) NOT NULL);
INSERT INTO #TcTile (ProductId, TilePath, DetailPath) VALUES
    ('TCPROD0001', '/Files/Images/TruvioCommerce/products/tc-tile-variants-0001.png', '/Files/Images/TruvioCommerce/products/tc-detail-variants-0001.png'),
    ('TCPROD0002', '/Files/Images/TruvioCommerce/products/tc-tile-variants-0002.png', '/Files/Images/TruvioCommerce/products/tc-detail-variants-0002.png'),
    ('TCPROD0003', '/Files/Images/TruvioCommerce/products/tc-tile-variants-0003.png', '/Files/Images/TruvioCommerce/products/tc-detail-variants-0003.png'),
    ('TCPROD0004', '/Files/Images/TruvioCommerce/products/tc-tile-variants-0004.png', '/Files/Images/TruvioCommerce/products/tc-detail-variants-0004.png'),
    ('TCPROD0005', '/Files/Images/TruvioCommerce/products/tc-tile-variants-0005.png', '/Files/Images/TruvioCommerce/products/tc-detail-variants-0005.png'),
    ('TCPROD0006', '/Files/Images/TruvioCommerce/products/tc-tile-stock-delivery-0006.png', '/Files/Images/TruvioCommerce/products/tc-detail-stock-delivery-0006.png'),
    ('TCPROD0007', '/Files/Images/TruvioCommerce/products/tc-tile-stock-delivery-0007.png', '/Files/Images/TruvioCommerce/products/tc-detail-stock-delivery-0007.png'),
    ('TCPROD0008', '/Files/Images/TruvioCommerce/products/tc-tile-stock-delivery-0008.png', '/Files/Images/TruvioCommerce/products/tc-detail-stock-delivery-0008.png'),
    ('TCPROD0009', '/Files/Images/TruvioCommerce/products/tc-tile-stock-delivery-0009.png', '/Files/Images/TruvioCommerce/products/tc-detail-stock-delivery-0009.png'),
    ('TCPROD0010', '/Files/Images/TruvioCommerce/products/tc-tile-stock-delivery-0010.png', '/Files/Images/TruvioCommerce/products/tc-detail-stock-delivery-0010.png'),
    ('TCPROD0011', '/Files/Images/TruvioCommerce/products/tc-tile-units-0011.png', '/Files/Images/TruvioCommerce/products/tc-detail-units-0011.png'),
    ('TCPROD0012', '/Files/Images/TruvioCommerce/products/tc-tile-units-0012.png', '/Files/Images/TruvioCommerce/products/tc-detail-units-0012.png'),
    ('TCPROD0013', '/Files/Images/TruvioCommerce/products/tc-tile-units-0013.png', '/Files/Images/TruvioCommerce/products/tc-detail-units-0013.png'),
    ('TCPROD0014', '/Files/Images/TruvioCommerce/products/tc-tile-units-0014.png', '/Files/Images/TruvioCommerce/products/tc-detail-units-0014.png'),
    ('TCPROD0015', '/Files/Images/TruvioCommerce/products/tc-tile-units-0015.png', '/Files/Images/TruvioCommerce/products/tc-detail-units-0015.png'),
    ('TCPROD0016', '/Files/Images/TruvioCommerce/products/tc-tile-price-structures-0016.png', '/Files/Images/TruvioCommerce/products/tc-detail-price-structures-0016.png'),
    ('TCPROD0017', '/Files/Images/TruvioCommerce/products/tc-tile-price-structures-0017.png', '/Files/Images/TruvioCommerce/products/tc-detail-price-structures-0017.png'),
    ('TCPROD0018', '/Files/Images/TruvioCommerce/products/tc-tile-price-structures-0018.png', '/Files/Images/TruvioCommerce/products/tc-detail-price-structures-0018.png'),
    ('TCPROD0019', '/Files/Images/TruvioCommerce/products/tc-tile-price-structures-0019.png', '/Files/Images/TruvioCommerce/products/tc-detail-price-structures-0019.png'),
    ('TCPROD0020', '/Files/Images/TruvioCommerce/products/tc-tile-price-structures-0020.png', '/Files/Images/TruvioCommerce/products/tc-detail-price-structures-0020.png'),
    ('TCPROD0021', '/Files/Images/TruvioCommerce/products/tc-tile-assortments-0021.png', '/Files/Images/TruvioCommerce/products/tc-detail-assortments-0021.png'),
    ('TCPROD0022', '/Files/Images/TruvioCommerce/products/tc-tile-assortments-0022.png', '/Files/Images/TruvioCommerce/products/tc-detail-assortments-0022.png'),
    ('TCPROD0023', '/Files/Images/TruvioCommerce/products/tc-tile-assortments-0023.png', '/Files/Images/TruvioCommerce/products/tc-detail-assortments-0023.png'),
    ('TCPROD0024', '/Files/Images/TruvioCommerce/products/tc-tile-assortments-0024.png', '/Files/Images/TruvioCommerce/products/tc-detail-assortments-0024.png'),
    ('TCPROD0025', '/Files/Images/TruvioCommerce/products/tc-tile-assortments-0025.png', '/Files/Images/TruvioCommerce/products/tc-detail-assortments-0025.png'),
    ('TCPROD0026', '/Files/Images/TruvioCommerce/products/tc-tile-discounts-0026.png', '/Files/Images/TruvioCommerce/products/tc-detail-discounts-0026.png'),
    ('TCPROD0027', '/Files/Images/TruvioCommerce/products/tc-tile-discounts-0027.png', '/Files/Images/TruvioCommerce/products/tc-detail-discounts-0027.png'),
    ('TCPROD0028', '/Files/Images/TruvioCommerce/products/tc-tile-discounts-0028.png', '/Files/Images/TruvioCommerce/products/tc-detail-discounts-0028.png'),
    ('TCPROD0029', '/Files/Images/TruvioCommerce/products/tc-tile-discounts-0029.png', '/Files/Images/TruvioCommerce/products/tc-detail-discounts-0029.png'),
    ('TCPROD0030', '/Files/Images/TruvioCommerce/products/tc-tile-discounts-0030.png', '/Files/Images/TruvioCommerce/products/tc-detail-discounts-0030.png'),
    ('TCPROD0031', '/Files/Images/TruvioCommerce/products/tc-tile-media-0031.png', '/Files/Images/TruvioCommerce/products/tc-detail-media-0031.png'),
    ('TCPROD0032', '/Files/Images/TruvioCommerce/products/tc-tile-media-0032.png', '/Files/Images/TruvioCommerce/products/tc-detail-media-0032.png'),
    ('TCPROD0033', '/Files/Images/TruvioCommerce/products/tc-tile-media-0033.png', '/Files/Images/TruvioCommerce/products/tc-detail-media-0033.png'),
    ('TCPROD0034', '/Files/Images/TruvioCommerce/products/tc-tile-media-0034.png', '/Files/Images/TruvioCommerce/products/tc-detail-media-0034.png'),
    ('TCPROD0035', '/Files/Images/TruvioCommerce/products/tc-tile-media-0035.png', '/Files/Images/TruvioCommerce/products/tc-detail-media-0035.png'),
    ('TCPROD0036', '/Files/Images/TruvioCommerce/products/tc-tile-currencies-0036.png', '/Files/Images/TruvioCommerce/products/tc-detail-currencies-0036.png'),
    ('TCPROD0037', '/Files/Images/TruvioCommerce/products/tc-tile-currencies-0037.png', '/Files/Images/TruvioCommerce/products/tc-detail-currencies-0037.png'),
    ('TCPROD0038', '/Files/Images/TruvioCommerce/products/tc-tile-currencies-0038.png', '/Files/Images/TruvioCommerce/products/tc-detail-currencies-0038.png'),
    ('TCPROD0039', '/Files/Images/TruvioCommerce/products/tc-tile-currencies-0039.png', '/Files/Images/TruvioCommerce/products/tc-detail-currencies-0039.png'),
    ('TCPROD0040', '/Files/Images/TruvioCommerce/products/tc-tile-currencies-0040.png', '/Files/Images/TruvioCommerce/products/tc-detail-currencies-0040.png'),
    ('TCPROD0041', '/Files/Images/TruvioCommerce/products/tc-tile-bundles-0041.png', '/Files/Images/TruvioCommerce/products/tc-detail-bundles-0041.png'),
    ('TCPROD0042', '/Files/Images/TruvioCommerce/products/tc-tile-bundles-0042.png', '/Files/Images/TruvioCommerce/products/tc-detail-bundles-0042.png'),
    ('TCPROD0043', '/Files/Images/TruvioCommerce/products/tc-tile-bundles-0043.png', '/Files/Images/TruvioCommerce/products/tc-detail-bundles-0043.png'),
    ('TCPROD0044', '/Files/Images/TruvioCommerce/products/tc-tile-bundles-0044.png', '/Files/Images/TruvioCommerce/products/tc-detail-bundles-0044.png'),
    ('TCPROD0045', '/Files/Images/TruvioCommerce/products/tc-tile-bundles-0045.png', '/Files/Images/TruvioCommerce/products/tc-detail-bundles-0045.png'),
    ('TCPROD0046', '/Files/Images/TruvioCommerce/products/tc-tile-contract-pricing-0046.png', '/Files/Images/TruvioCommerce/products/tc-detail-contract-pricing-0046.png'),
    ('TCPROD0047', '/Files/Images/TruvioCommerce/products/tc-tile-contract-pricing-0047.png', '/Files/Images/TruvioCommerce/products/tc-detail-contract-pricing-0047.png'),
    ('TCPROD0048', '/Files/Images/TruvioCommerce/products/tc-tile-contract-pricing-0048.png', '/Files/Images/TruvioCommerce/products/tc-detail-contract-pricing-0048.png'),
    ('TCPROD0049', '/Files/Images/TruvioCommerce/products/tc-tile-contract-pricing-0049.png', '/Files/Images/TruvioCommerce/products/tc-detail-contract-pricing-0049.png'),
    ('TCPROD0050', '/Files/Images/TruvioCommerce/products/tc-tile-contract-pricing-0050.png', '/Files/Images/TruvioCommerce/products/tc-detail-contract-pricing-0050.png'),
    ('TCPROD0051', '/Files/Images/TruvioCommerce/products/tc-tile-documents-0051.png', '/Files/Images/TruvioCommerce/products/tc-detail-documents-0051.png'),
    ('TCPROD0052', '/Files/Images/TruvioCommerce/products/tc-tile-documents-0052.png', '/Files/Images/TruvioCommerce/products/tc-detail-documents-0052.png'),
    ('TCPROD0053', '/Files/Images/TruvioCommerce/products/tc-tile-documents-0053.png', '/Files/Images/TruvioCommerce/products/tc-detail-documents-0053.png'),
    ('TCPROD0054', '/Files/Images/TruvioCommerce/products/tc-tile-documents-0054.png', '/Files/Images/TruvioCommerce/products/tc-detail-documents-0054.png'),
    ('TCPROD0055', '/Files/Images/TruvioCommerce/products/tc-tile-documents-0055.png', '/Files/Images/TruvioCommerce/products/tc-detail-documents-0055.png'),
    ('TCPROD0056', '/Files/Images/TruvioCommerce/products/tc-tile-relations-0056.png', '/Files/Images/TruvioCommerce/products/tc-detail-relations-0056.png'),
    ('TCPROD0057', '/Files/Images/TruvioCommerce/products/tc-tile-relations-0057.png', '/Files/Images/TruvioCommerce/products/tc-detail-relations-0057.png'),
    ('TCPROD0058', '/Files/Images/TruvioCommerce/products/tc-tile-relations-0058.png', '/Files/Images/TruvioCommerce/products/tc-detail-relations-0058.png'),
    ('TCPROD0059', '/Files/Images/TruvioCommerce/products/tc-tile-relations-0059.png', '/Files/Images/TruvioCommerce/products/tc-detail-relations-0059.png'),
    ('TCPROD0060', '/Files/Images/TruvioCommerce/products/tc-tile-relations-0060.png', '/Files/Images/TruvioCommerce/products/tc-detail-relations-0060.png');

-- ---------------------------------------------------------------------------
-- 1. EcomDetails: the attachment the storefront reads.
--    The column list is resolved against sys.columns because the optional
--    columns (language, sorting, type) differ across platform builds, and an
--    INSERT naming a column the build does not have fails the whole script.
-- ---------------------------------------------------------------------------
-- EcomDetails names the variant column DetailVariantId, NOT DetailProductVariantId
-- (sys.columns, DW 10.28.10). The wrong spelling is a compile-time Msg 207 inside
-- sp_executesql, so it survives every COL_LENGTH guard above it.
DECLARE @inserted int = 0, @hovered int = 0, @converged int = 0, @hoverConverged int = 0, @updated int = 0, @attached int = 0, @hoverRows int = 0;
DECLARE @cols nvarchar(max) = N'DetailId, DetailProductId, DetailVariantId, DetailValue, DetailIsDefault';
-- The detail id is DERIVED from the product key, never from a ROW_NUMBER: a
-- re-run that attaches only the missing rows would restart the counter at 1 and
-- collide with the ids the first run wrote. It is also what lets the 1.4.0
-- convergence below be a targeted UPDATE rather than a delete and a reseed.
DECLARE @key nvarchar(max) = N'p.ProductId + CASE WHEN p.ProductVariantId = '''' THEN '''' ELSE ''-'' + p.ProductVariantId END';
DECLARE @tailDefault nvarchar(max) = N'', @tailHover nvarchar(max) = N'';

IF COL_LENGTH('EcomDetails', 'DetailLanguageId') IS NOT NULL
    SELECT @cols = @cols + N', DetailLanguageId', @tailDefault = @tailDefault + N', p.ProductLanguageId', @tailHover = @tailHover + N', p.ProductLanguageId';
IF COL_LENGTH('EcomDetails', 'DetailProductLanguageId') IS NOT NULL
    SELECT @cols = @cols + N', DetailProductLanguageId', @tailDefault = @tailDefault + N', p.ProductLanguageId', @tailHover = @tailHover + N', p.ProductLanguageId';
IF COL_LENGTH('EcomDetails', 'DetailSorting') IS NOT NULL
    SELECT @cols = @cols + N', DetailSorting', @tailDefault = @tailDefault + N', 0', @tailHover = @tailHover + N', 1';
IF COL_LENGTH('EcomDetails', 'DetailSortOrder') IS NOT NULL
    SELECT @cols = @cols + N', DetailSortOrder', @tailDefault = @tailDefault + N', 0', @tailHover = @tailHover + N', 1';
IF COL_LENGTH('EcomDetails', 'DetailType') IS NOT NULL
    SELECT @cols = @cols + N', DetailType', @tailDefault = @tailDefault + N', 0', @tailHover = @tailHover + N', 0';

-- 1a. The default image - what the card shows and what the PDP opens on.
DECLARE @sql nvarchar(max) = N'
INSERT INTO EcomDetails (' + @cols + N')
SELECT ''TC-DETAIL-'' + ' + @key + N', p.ProductId, p.ProductVariantId, t.TilePath, 1' + @tailDefault + N'
FROM EcomProducts p
JOIN #TcTile t ON t.ProductId = p.ProductId
WHERE p.ProductId LIKE ''TCPROD%''
  AND NOT EXISTS (SELECT 1 FROM EcomDetails d WHERE d.DetailId = ''TC-DETAIL-'' + ' + @key + N');';
EXEC sp_executesql @sql;
SET @inserted = @@ROWCOUNT;

-- 1b. The hover image - the second, non-default row the card swaps to.
DECLARE @sqlHover nvarchar(max) = N'
INSERT INTO EcomDetails (' + @cols + N')
SELECT ''TC-HOVER-'' + ' + @key + N', p.ProductId, p.ProductVariantId, t.DetailPath, 0' + @tailHover + N'
FROM EcomProducts p
JOIN #TcTile t ON t.ProductId = p.ProductId
WHERE p.ProductId LIKE ''TCPROD%''
  AND NOT EXISTS (SELECT 1 FROM EcomDetails d WHERE d.DetailId = ''TC-HOVER-'' + ' + @key + N');';
EXEC sp_executesql @sqlHover;
SET @hovered = @@ROWCOUNT;

-- 1c. Convergence. A host seeded at 1.4.0 or earlier carries TC-DETAIL-* rows
--     pointing at the twelve subgroup tiles. Same ids, new value.
UPDATE d
   SET d.DetailValue = t.TilePath
  FROM EcomDetails d
  JOIN EcomProducts p ON p.ProductId = d.DetailProductId AND p.ProductVariantId = d.DetailVariantId
  JOIN #TcTile t ON t.ProductId = p.ProductId
 WHERE d.DetailId = 'TC-DETAIL-' + p.ProductId + CASE WHEN p.ProductVariantId = '' THEN '' ELSE '-' + p.ProductVariantId END
   AND d.DetailValue <> t.TilePath
   AND ISNULL(d.DetailsName, N'') <> N'brand-photograph';
SET @converged = @@ROWCOUNT;

-- 1d. The same convergence for the HOVER row, and for the same reason one step
--     later: a host seeded at 1.5.0 or 1.6.0 carries TC-HOVER-* rows pointing at
--     the .svg detail image. The id is derived from the product key here too, so
--     the row is updated in place and no second hover row is ever created.
UPDATE d
   SET d.DetailValue = t.DetailPath
  FROM EcomDetails d
  JOIN EcomProducts p ON p.ProductId = d.DetailProductId AND p.ProductVariantId = d.DetailVariantId
  JOIN #TcTile t ON t.ProductId = p.ProductId
 WHERE d.DetailId = 'TC-HOVER-' + p.ProductId + CASE WHEN p.ProductVariantId = '' THEN '' ELSE '-' + p.ProductVariantId END
   AND d.DetailValue <> t.DetailPath
   AND ISNULL(d.DetailsName, N'') <> N'brand-photograph';
SET @hoverConverged = @@ROWCOUNT;

-- ---------------------------------------------------------------------------
-- 2. The legacy EcomProducts image columns, where the build still has them.
--    Same value as the default row, so the two surfaces can never disagree
--    about which file a product shows.
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
JOIN #TcTile t ON t.ProductId = p.ProductId
WHERE p.ProductId LIKE ''TCPROD%'';';
    EXEC sp_executesql @upd;
    SET @updated = @@ROWCOUNT;
END

-- ---------------------------------------------------------------------------
-- 3. Report what was MEASURED, and fail when the page would not show what this
--    file claims. The tail used to PRINT a fixed success line naming 12 tiles
--    and 96 rows whether or not a single row moved - which is precisely the
--    "seeds no image and reports success" failure the header says this file
--    exists to prevent. @inserted is legitimately 0 on a re-run (the attach is
--    idempotent), so every assertion below is a MEASUREMENT of the end state.
-- ---------------------------------------------------------------------------
SELECT @attached = COUNT(*)
FROM EcomDetails d
JOIN #TcTile t ON t.TilePath = d.DetailValue
WHERE d.DetailProductId LIKE 'TCPROD%' AND d.DetailIsDefault = 1;

SELECT @hoverRows = COUNT(*)
FROM EcomDetails d
JOIN #TcTile t ON t.DetailPath = d.DetailValue
WHERE d.DetailProductId LIKE 'TCPROD%' AND d.DetailIsDefault = 0;

-- 3a. THE SHARING GUARD, and it is the one that would have caught 1.4.0. Two
--     products in the same group showing the same default picture is the defect
--     #1157 names, and a row count cannot see it: 96 rows over 12 pictures
--     counts exactly as well as 96 rows over 96.
DECLARE @TcSharedDefaults INT = (
    SELECT COUNT(*) FROM (
        SELECT r.GroupProductRelationGroupId, d.DetailValue
          FROM EcomDetails d
          JOIN EcomGroupProductRelation r ON r.GroupProductRelationProductId = d.DetailProductId AND r.GroupProductRelationIsPrimary = 1
         WHERE d.DetailProductId LIKE 'TCPROD%' AND d.DetailIsDefault = 1 AND d.DetailVariantId = ''
         GROUP BY r.GroupProductRelationGroupId, d.DetailValue
        HAVING COUNT(DISTINCT d.DetailProductId) > 1) shared);

-- 3b. THE SECOND-IMAGE GUARD. A master with one image has nothing to hover to,
--     and the card component fails that silently: no error, no empty element,
--     just a swap that never happens.
-- 3c. THE RASTER GUARD (Foundry #1171). A TCPROD image row carrying an .svg path
--     is a picture that answers 200 on its raw path and 500 through the only
--     route Swift's card takes. Every guard above this one counts it as present.
DECLARE @TcVectorImages INT = (
    SELECT COUNT(*) FROM EcomDetails
     WHERE DetailProductId LIKE 'TCPROD%'
       AND (DetailId LIKE 'TC-DETAIL-%' OR DetailId LIKE 'TC-HOVER-%')
       AND DetailValue LIKE '%.svg');

DECLARE @TcMastersWithoutSecond INT = (
    SELECT COUNT(*) FROM EcomProducts p
     WHERE p.ProductId LIKE 'TCPROD%' AND p.ProductVariantId = ''
       AND (SELECT COUNT(DISTINCT d.DetailValue) FROM EcomDetails d
             WHERE d.DetailProductId = p.ProductId AND d.DetailVariantId = ''
               AND d.DetailValue LIKE '/Files/Images/%') < 2);

DROP TABLE #TcTile;

IF @attached = 0
BEGIN
    ROLLBACK TRAN;
    RAISERROR(N'truvio-images.sql: 0 TCPROD rows carry a per-product tile after the attach. The PLP and PDP probes will measure empty grey boxes. Check that the catalogue seeded (truvio-catalog.sql ran) and that the TCPROD ids this file maps exist.', 16, 1);
END
ELSE IF @hoverRows = 0
BEGIN
    ROLLBACK TRAN;
    RAISERROR(N'truvio-images.sql: no product carries a second image. The PLP card sets ShowAlternativeImageOnHover, and with one image per product the hover is a swap to nothing - no error, no change, which is the failure mode this guard exists for.', 16, 1);
END
ELSE IF @TcSharedDefaults > 0
BEGIN
    ROLLBACK TRAN;
    RAISERROR(N'truvio-images.sql: two or more products in one group share a default image. That is the 1.4.0 state this release replaces: every row count correct, and a PLP band showing one product five times.', 16, 1);
END
ELSE IF @TcMastersWithoutSecond > 0
BEGIN
    ROLLBACK TRAN;
    RAISERROR(N'truvio-images.sql: a master carries fewer than two distinct images. The hover swap has no subject on that card.', 16, 1);
END
ELSE IF @TcVectorImages > 0
BEGIN
    ROLLBACK TRAN;
    RAISERROR(N'truvio-images.sql: a product image row still points at an .svg. GetImage.ashx decodes with SixLabors.ImageSharp, which ships no SVG decoder and answers HTTP 500 for every one of them - so the card and the PDP paint a broken image while the attach count, the sharing guard and the second-image guard are all green. That is the state every release from 1.2.0 to 1.6.0 shipped.', 16, 1);
END
ELSE
BEGIN
    COMMIT TRAN;
    PRINT CONCAT(N'truvio-demo imagery: ', @inserted, N' default row(s) inserted, ',
                 @hovered, N' hover row(s) inserted, ', @converged, N' default row(s) converged onto the raster tile, ',
                 @hoverConverged, N' hover row(s) converged onto the raster detail, ',
                 @updated, N' EcomProducts row(s) given the legacy image columns, ',
                 @attached, N' TCPROD row(s) carry their own tile and ', @hoverRows, N' carry a second image.');
END
