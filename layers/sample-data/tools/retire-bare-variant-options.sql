-- ===========================================================================
-- retire-bare-variant-options.sql - OPTIONAL, and deliberately NOT declared in
-- sample-data/layer.json sql[].
--
-- WHO RUNS IT. An operator holding a host that was delivered from sample-data
-- 5.0.0 or earlier. A clean-room host needs nothing.
--
-- WHY IT EXISTS. Up to 5.0.0 the layer shipped 30 BARE option rows in
-- EcomVariantOptionsProductRelation (TCPROD0001$$TCVO-TIER-STD, ...) for six
-- masters that carry TWO variant groups. Dynamicweb keys a two-group master's
-- combinations by the dotted id (TCVO-TIER-STD.TCVO-MODE-PUB), so the cart
-- refused every variant line and VariantCombinationsByProductId answered 500
-- (Foundry #1255, #1269). 5.0.1 ships the 36 dotted combination rows instead.
-- A MERGE DESERIALIZE NEVER DELETES, so a 5.0.0 host keeps the 30 bare rows
-- next to the new ones. Stock Dynamicweb never holds a bare row for a master
-- with two or more variant groups.
--
-- ORDER. Before or after the 5.0.1 delivery; the fence below matches only bare
-- rows on TCPROD masters that carry two or more variant groups, never a dotted
-- combination and never a host's own product.
--
-- IDEMPOTENT. A second run deletes nothing.
--
-- RUN IT AS: sqlcmd -S <server> -d <db> -i retire-bare-variant-options.sql
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DELETE r
FROM EcomVariantOptionsProductRelation r
WHERE r.VariantOptionsProductRelationProductId LIKE 'TCPROD%'
  AND CHARINDEX('.', r.VariantOptionsProductRelationVariantId) = 0
  AND (SELECT COUNT(*) FROM EcomVariantGroupProductRelation g
        WHERE g.VariantGroupProductRelationProductId = r.VariantOptionsProductRelationProductId) >= 2;

SELECT @@ROWCOUNT AS BareOptionRowsRemoved;

COMMIT TRANSACTION;
