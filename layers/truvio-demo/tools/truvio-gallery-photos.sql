-- ===========================================================================
-- truvio-gallery-photos.sql - OPTIONAL, and deliberately NOT declared in
-- truvio-demo/layer.json sql[].
--
-- WHY IT IS NOT DECLARED. A declared script is one the composer runs, and this
-- one must not run by default: it repoints every gallery row at the five
-- PHOTOGRAPHIC assets under /Files/Images/TruvioCommerce/scenic/, and this
-- layer ships none of them. They are brand assets - Truvio's own, named with a
-- sha256 in the Distribution's brand/brand-assets.manifest.json - and a data
-- layer never commits photography. Running this before the brand step has put
-- those five files on disk gives the exact defect Foundry #1137 filed: 84
-- gallery rows whose every member 404s, with every row count green. SQL cannot
-- test for a file on disk, so the gate is a human step, not a predicate.
--
-- WHEN TO RUN IT. After the brand step has downloaded brand-assets.manifest.json
-- into the host Files tree (it already writes exactly these five targets), and
-- after truvio-pdp.sql. Verify the five files are present first:
--
--   Files/Images/TruvioCommerce/scenic/product-shot-1.webp
--   Files/Images/TruvioCommerce/scenic/product-shot-2.webp
--   Files/Images/TruvioCommerce/scenic/product-shot-3.webp
--   Files/Images/TruvioCommerce/scenic/product-visual.png
--   Files/Images/TruvioCommerce/scenic/ui-composite.webp
--
-- WHAT THE DEFAULT IS WITHOUT IT. truvio-pdp.sql seeds every gallery row with a
-- concept tile this layer DOES ship under files/Images/TruvioCommerce/products/,
-- so the default render is self-contained and every thumbnail resolves. This
-- script is an upgrade of that render, never a prerequisite for it.
--
-- TO REVERSE IT, re-run truvio-pdp.sql: its gallery section is an IF NOT EXISTS
-- upsert on DetailId, so it will not overwrite these values - delete the
-- TC-GAL-% rows first, then re-run it.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

-- The photographic set, assigned by a ring over (master ordinal + sort order)
-- so no master repeats a picture inside its own strip.
;WITH TcPhotos(n, path) AS (
    SELECT * FROM (VALUES
        (0, '/Files/Images/TruvioCommerce/scenic/product-shot-1.webp'),
        (1, '/Files/Images/TruvioCommerce/scenic/product-shot-2.webp'),
        (2, '/Files/Images/TruvioCommerce/scenic/product-shot-3.webp'),
        (3, '/Files/Images/TruvioCommerce/scenic/product-visual.png'),
        (4, '/Files/Images/TruvioCommerce/scenic/ui-composite.webp')) AS v(n, path))
UPDATE g
   SET g.DetailValue = p.path
  FROM EcomDetails g
  JOIN TcPhotos p
    ON p.n = (ISNULL(TRY_CAST(SUBSTRING(g.DetailProductId, 7, 4) AS INT), 0) + g.DetailSortOrder) % 5
 WHERE g.DetailId LIKE 'TC-GAL-%'
   AND g.DetailVariantId = '';

DECLARE @TcPhotoRows INT = (SELECT COUNT(*) FROM EcomDetails WHERE DetailId LIKE 'TC-GAL-%' AND DetailValue LIKE '/Files/Images/TruvioCommerce/scenic/%');
IF @TcPhotoRows = 0
    RAISERROR(N'truvio-gallery-photos.sql: no gallery row was swapped. Either truvio-pdp.sql has not run on this host, or the TC-GAL-%% rows were seeded under different ids.', 16, 1);

DECLARE @TcRepeatedPhoto INT = (
    SELECT COUNT(*) FROM (
        SELECT d.DetailProductId FROM EcomDetails d
         WHERE d.DetailId LIKE 'TC-GAL-%' AND d.DetailVariantId = ''
         GROUP BY d.DetailProductId
        HAVING COUNT(*) <> COUNT(DISTINCT d.DetailValue)) x);
IF @TcRepeatedPhoto > 0
    RAISERROR(N'truvio-gallery-photos.sql: a master carries the same photograph twice. The thumbnail strip renders and steps from an image to itself.', 16, 1);

COMMIT TRAN;
PRINT 'Done - truvio-demo gallery swapped onto the five brand-manifest scenic photographs. Confirm the files are on disk under Files/Images/TruvioCommerce/scenic/; this script cannot.';
