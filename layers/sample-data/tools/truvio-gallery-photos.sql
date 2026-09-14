-- ===========================================================================
-- truvio-gallery-photos.sql - OPTIONAL, and deliberately NOT declared in
-- sample-data/layer.json sql[].
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
-- AND THAT SENTENCE WAS FALSE ON A HOST SEEDED AT 1.2.0, which is worth stating
-- because it is how this script's own guards stayed green over a defect. 1.2.0
-- seeded the gallery SCENIC, 1.3.0's upsert was IF NOT EXISTS on DetailId, so such
-- a host arrived here already carrying 84 scenic rows and this script re-derived
-- the ring rather than performing the swap it exists to perform: 84 rows before and
-- after, 0 added, 0 removed, 60 of 84 values changed, `products/` count 0 in both
-- states (Foundry #1137, #1145). truvio-pdp.sql now CONVERGES each gallery row
-- instead of skipping it, so the sentence above is true again on every host.
--
-- THE STAMP, and why it exists. Every row this script writes is stamped
-- DetailsName = 'brand-photograph'. truvio-pdp.sql's convergence skips a stamped
-- row, so a later Replace cannot silently undo a swap a brand step chose to make.
-- The stamp is the ONLY thing that can distinguish the two states: 1.2.0's residue
-- and this script's result point at the same five files, so neither the path nor
-- any count can tell them apart.
--
-- TO REVERSE IT, clear the stamp and re-run truvio-pdp.sql:
--
--   UPDATE EcomDetails SET DetailsName = NULL WHERE DetailId LIKE 'TC-GAL-%';
--
-- the convergence then repoints every row back onto the shipped tiles. Deleting the
-- rows first is no longer necessary.
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
   SET g.DetailValue = p.path,
       g.DetailsName = N'brand-photograph'
  FROM EcomDetails g
  JOIN TcPhotos p
    ON p.n = (ISNULL(TRY_CAST(SUBSTRING(g.DetailProductId, 7, 4) AS INT), 0) + g.DetailSortOrder) % 5
 WHERE g.DetailId LIKE 'TC-GAL-%'
   AND g.DetailVariantId = '';

-- The swap is proven by the STAMP, not by the prefix. A host seeded at 1.2.0
-- already carried scenic paths before this script ran, so a prefix count was green
-- on a run that swapped nothing.
DECLARE @TcPhotoRows INT = (SELECT COUNT(*) FROM EcomDetails WHERE DetailId LIKE 'TC-GAL-%' AND DetailValue LIKE '/Files/Images/TruvioCommerce/scenic/%' AND ISNULL(DetailsName, N'') = N'brand-photograph');
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
PRINT 'Done - sample-data gallery swapped onto the five brand-manifest scenic photographs. Confirm the files are on disk under Files/Images/TruvioCommerce/scenic/; this script cannot.';
