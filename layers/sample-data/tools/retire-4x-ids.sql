-- ===========================================================================
-- retire-4x-ids.sql - OPTIONAL, and deliberately NOT declared in
-- sample-data/layer.json sql[].
--
-- WHO RUNS IT. An operator holding a host that was delivered from sample-data
-- 4.x, BEFORE delivering 5.0.0 onto it. A clean-room host needs nothing.
--
-- WHY IT EXISTS. 5.0.0 renames the catalogue band, id AND name:
--     group    TCGRP-DATA-MODELS -> TCGRP-PRODUCT-STRUCTURE
--     category tc_data_models    -> tc_product_structure
--     files    tc-{datasheet,install-guide}-data-models.pdf
--                                -> tc-{datasheet,install-guide}-product-structure.pdf
-- A MERGE DESERIALIZE NEVER DELETES. Delivering 5.0.0 onto a 4.x host therefore
-- INSERTS the new ids and LEAVES the old ones, and the host ends with two of
-- everything: two top groups in the menu, two categories in the field picker,
-- fifteen duplicate spec values per master, and two datasheet rows on thirty
-- product pages. Nothing errors; the demo just reads as broken. The same
-- precedent is in the 4.1.2 changelog for the twelve retired price rows.
--
-- ORDER. Run this BEFORE the 5.0.0 deserialize, never after: run after, and the
-- LIKE 'tc[_]data[_]models%' fences below still match only the OLD rows (the new
-- ones are tc_product_structure), so it is safe either way - but running first
-- keeps the host from ever holding the doubled state.
--
-- IDEMPOTENT. Every statement is a keyed DELETE against the retired ids only. A
-- second run deletes nothing.
--
-- TWO ORPHAN SWEEPS IT ALSO DOES, both unrelated to the rename and both
-- idempotent: the DynamicStructureLevels rows left behind when the heap-table
-- write of DynamicStructures wiped a structure, and the EcomShopGroupRelation
-- rows whose group exists in no EcomGroups row (base 3.5.3 replayed 31 of them
-- and Replace cannot take them back - it upserts and never deletes an absent
-- row). Both are safe on a host that has neither.
--
-- WHAT IT DOES NOT TOUCH. The three subgroups TCGRP-VARIANTS, TCGRP-UNITS and
-- TCGRP-BUNDLES keep their ids across the rename - only their PARENT changes, and
-- the 5.0.0 deserialize rewrites their EcomGroupRelations rows in place. The
-- fifteen masters keep their ids too. Their old PARENT relations are what goes.
--
-- RUN IT AS: sqlcmd -S <server> -d <db> -i retire-4x-ids.sql
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

-- --- the retired group ----------------------------------------------------
DELETE FROM EcomShopGroupRelation      WHERE ShopGroupGroupId = N'TCGRP-DATA-MODELS';
DELETE FROM EcomGroupProductRelation   WHERE GroupProductRelationGroupId = N'TCGRP-DATA-MODELS';
DELETE FROM EcomGroupRelations         WHERE GroupRelationsParentId = N'TCGRP-DATA-MODELS'
                                          OR GroupRelationsGroupId  = N'TCGRP-DATA-MODELS';
DELETE FROM EcomGroups                 WHERE GroupId = N'TCGRP-DATA-MODELS';

-- --- the retired category, its fields, labels, values and display members --
-- The display-group member key embeds the category: ProductCategory|<cat>|<field>.
DELETE FROM EcomFieldDisplayGroupFields
 WHERE FieldDisplayGroupFieldSystemName LIKE 'ProductCategory|tc[_]data[_]models|%';
DELETE FROM EcomProductCategoryFieldValue       WHERE FieldValueFieldCategoryId        = N'tc_data_models';
DELETE FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldCategoryId  = N'tc_data_models';
DELETE FROM EcomProductCategoryField            WHERE FieldCategoryId                  = N'tc_data_models';
DELETE FROM EcomProductCategoryTranslation      WHERE CategoryTranslationCategoryId    = N'tc_data_models';
DELETE FROM EcomProductCategory                 WHERE CategoryId                       = N'tc_data_models';

-- The denormalised member list on the display group is rewritten from the
-- relation, never edited by hand: 5.0.0's own EcomFieldDisplayGroups row carries
-- the new names, so this only clears a host the deserialize has not reached yet.
UPDATE EcomFieldDisplayGroups
   SET FieldDisplayGroupFieldIds = REPLACE(FieldDisplayGroupFieldIds,
                                           N'ProductCategory|tc_data_models|',
                                           N'ProductCategory|tc_product_structure|')
 WHERE FieldDisplayGroupId = 100120
   AND FieldDisplayGroupFieldIds LIKE '%tc[_]data[_]models%';

-- --- the two retired documents --------------------------------------------
-- The 30 EcomDetails rows point at file paths that no longer exist on disk.
DELETE FROM EcomDetails
 WHERE DetailValue IN (N'/Files/Documents/TruvioCommerce/tc-datasheet-data-models.pdf',
                       N'/Files/Documents/TruvioCommerce/tc-install-guide-data-models.pdf');

-- --- orphaned workspace levels -------------------------------------------
-- DynamicStructures is a HEAP on DW 10.28 (no primary key), so the serializer
-- writes it with DELETE FROM [table] plus insert-all under Merge as well as
-- Replace: delivering this layer removes every workspace the host already had.
-- DynamicStructureLevels HAS a primary key, so it is upserted and the wiped
-- structures' level rows survive as orphans - they render nowhere and nothing
-- else removes them. Idempotent: a host with no orphans loses nothing.
-- The join is the structure's UniqueId GUID held as nvarchar, never its int id.
DELETE FROM DynamicStructureLevels
 WHERE DynamicStructureLevelStructureId NOT IN
       (SELECT CAST(DynamicStructureUniqueId AS nvarchar(50)) FROM DynamicStructures);

-- --- orphaned shop-group relations ----------------------------------------
-- base 3.5.3 shipped 32 GROUP<n>$$SHOP1 rows for groups no layer ships. base
-- 3.6.0 drops them from its replace tree, but REPLACE UPSERTS AND NEVER DELETES
-- a row absent from the tree (docs/swift-replace-merge-analysis.md D-5), so 31
-- of them replay on every delivery and survive the upgrade. They point at no
-- EcomGroups row, so they resolve nothing and only pad the table. Idempotent.
DELETE FROM EcomShopGroupRelation
 WHERE NOT EXISTS (SELECT 1 FROM EcomGroups g WHERE g.GroupId = EcomShopGroupRelation.ShopGroupGroupId);

COMMIT TRANSACTION;

SELECT 'TCGRP-DATA-MODELS group'   AS what, CAST((SELECT COUNT(*) FROM EcomGroups WHERE GroupId = N'TCGRP-DATA-MODELS') AS nvarchar(20)) AS remaining
UNION ALL SELECT 'its shop relation',       CAST((SELECT COUNT(*) FROM EcomShopGroupRelation WHERE ShopGroupGroupId = N'TCGRP-DATA-MODELS') AS nvarchar(20))
UNION ALL SELECT 'its group relations',     CAST((SELECT COUNT(*) FROM EcomGroupRelations WHERE GroupRelationsParentId = N'TCGRP-DATA-MODELS' OR GroupRelationsGroupId = N'TCGRP-DATA-MODELS') AS nvarchar(20))
UNION ALL SELECT 'its product relations',   CAST((SELECT COUNT(*) FROM EcomGroupProductRelation WHERE GroupProductRelationGroupId = N'TCGRP-DATA-MODELS') AS nvarchar(20))
UNION ALL SELECT 'tc_data_models category', CAST((SELECT COUNT(*) FROM EcomProductCategory WHERE CategoryId = N'tc_data_models') AS nvarchar(20))
UNION ALL SELECT 'its fields',              CAST((SELECT COUNT(*) FROM EcomProductCategoryField WHERE FieldCategoryId = N'tc_data_models') AS nvarchar(20))
UNION ALL SELECT 'its field labels',        CAST((SELECT COUNT(*) FROM EcomProductCategoryFieldTranslation WHERE FieldTranslationFieldCategoryId = N'tc_data_models') AS nvarchar(20))
UNION ALL SELECT 'its field values',        CAST((SELECT COUNT(*) FROM EcomProductCategoryFieldValue WHERE FieldValueFieldCategoryId = N'tc_data_models') AS nvarchar(20))
UNION ALL SELECT 'its display members',     CAST((SELECT COUNT(*) FROM EcomFieldDisplayGroupFields WHERE FieldDisplayGroupFieldSystemName LIKE 'ProductCategory|tc[_]data[_]models|%') AS nvarchar(20))
UNION ALL SELECT 'old PDF asset rows',      CAST((SELECT COUNT(*) FROM EcomDetails WHERE DetailValue LIKE '%-data-models.pdf') AS nvarchar(20))
UNION ALL SELECT 'orphan workspace levels',  CAST((SELECT COUNT(*) FROM DynamicStructureLevels WHERE DynamicStructureLevelStructureId NOT IN (SELECT CAST(DynamicStructureUniqueId AS nvarchar(50)) FROM DynamicStructures)) AS nvarchar(20))
UNION ALL SELECT 'orphan shop-group rels',   CAST((SELECT COUNT(*) FROM EcomShopGroupRelation r WHERE NOT EXISTS (SELECT 1 FROM EcomGroups g WHERE g.GroupId = r.ShopGroupGroupId)) AS nvarchar(20))
UNION ALL SELECT 'KEPT: 3 subgroups',       CAST((SELECT COUNT(*) FROM EcomGroups WHERE GroupId IN (N'TCGRP-VARIANTS', N'TCGRP-UNITS', N'TCGRP-BUNDLES')) AS nvarchar(20))
UNION ALL SELECT 'KEPT: products on host',  CAST((SELECT COUNT(*) FROM EcomProducts WHERE ProductId LIKE 'TCPROD%') AS nvarchar(20));
-- Every retired row above must read 0; KEPT: 3 subgroups must read 3 (one ENU row
-- each) and KEPT: products must be unchanged. Then deliver 5.0.0, restart the host
-- and rebuild the product index.
