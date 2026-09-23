-- ===========================================================================
-- sample-data layer - EcomNumbers counters raised past the rows the layers ship
-- ===========================================================================
-- Dynamicweb mints a new id for an ecommerce entity from its EcomNumbers row:
-- NumberPrefix + (NumberCounter + NumberAdd). A deserialize writes rows with
-- their ids verbatim and never advances the counter, so a composed host starts
-- with counters BEHIND the ids it already holds: the base ships OS1..OS14,
-- SHIP3..SHIP13 and PAY1..PAY3 into a clone whose counters were left wherever
-- the clone left them (measured on foundry.mydwsite4.com: SHIP counter 5 with
-- SHIP13 present). The next create without an explicit id then mints an id that
-- exists, and the create silently OVERWRITES the shipped row: MCP
-- create_order_state without an id replaced OS5 and OS6 (Foundry #1322). The
-- same holds for shipping, payment and price rows and for every other counter.
--
-- WHAT IT DOES. For every EcomNumbers row that names its table and id column
-- (NumberTableName, NumberColumnName) and carries a non-empty NumberPrefix, it
-- reads the highest numeric suffix in use in that column - ids of the exact
-- form <NumberPrefix><digits><NumberPostFix>, nothing else - and raises
-- NumberCounter to it when the counter is lower. The next minted id is then one
-- past the highest in use. It is table-agnostic on purpose: EcomOrderStates,
-- EcomShippings, EcomPayments and EcomPrices are the ones #1322 names, and the
-- same rule covers ORDER, CART, OL, GROUP, FIELD and the rest without a list to
-- keep in sync.
--
-- WHAT IT NEVER DOES. It never lowers a counter, never touches a row that is
-- not an EcomNumbers counter, and ignores ids outside the generator's shape:
-- the TC* keys this layer ships (TCPROD0001, TC-PRICE-CTR-0046, TCO-0001) do
-- not match any prefix+digits form, so they neither raise nor lower anything.
-- A counter whose table or column is missing on this host is skipped.
--
-- IDEMPOTENT. A second run finds every counter at or above its maximum and
-- updates nothing. TRANSACTIONAL: one transaction under XACT_ABORT, so a
-- failure part way leaves every counter as it was.
--
-- CHANNEL. Local installs only, like every sql[] script: an online host (URL +
-- Admin API key) has no SQL channel, and no MCP tool or Management API command
-- writes EcomNumbers. An online host applies this script through its own SQL
-- route (the hosting provider's SQL access), or passes an explicit unused id
-- on every create until it does.
--
-- VERIFY:
--   SELECT NumberType, NumberPrefix, NumberCounter FROM EcomNumbers
--   WHERE NumberType IN ('OS','SHIP','PAY','PRICE');
--   -- each counter >= the highest numeric suffix of its table, e.g.
--   SELECT MAX(TRY_CAST(SUBSTRING(OrderStateId, 3, 50) AS bigint))
--   FROM EcomOrderStates WHERE OrderStateId LIKE 'OS[0-9]%';
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

CREATE TABLE #counterMax (
    NumberId      nvarchar(255) NOT NULL,
    NumberType    nvarchar(255) NOT NULL,
    CounterBefore int           NOT NULL,
    MaxInUse      bigint        NULL
);

DECLARE @id nvarchar(255), @type nvarchar(255), @counter int,
        @prefix nvarchar(255), @postfix nvarchar(255),
        @tbl nvarchar(255), @col nvarchar(255), @sql nvarchar(max), @mx bigint;

DECLARE c CURSOR LOCAL FAST_FORWARD FOR
    SELECT NumberId, NumberType, NumberCounter, NumberPrefix, ISNULL(NumberPostFix, N''),
           NumberTableName, NumberColumnName
    FROM EcomNumbers
    WHERE ISNULL(NumberPrefix, N'') <> N''
      AND ISNULL(NumberTableName, N'') <> N''
      AND ISNULL(NumberColumnName, N'') <> N'';

OPEN c;
FETCH NEXT FROM c INTO @id, @type, @counter, @prefix, @postfix, @tbl, @col;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF OBJECT_ID(QUOTENAME(@tbl), N'U') IS NOT NULL AND COL_LENGTH(@tbl, @col) IS NOT NULL
    BEGIN
        -- v = the id as text. It counts only when it is exactly
        -- <prefix><digits><postfix>: the prefix and postfix are compared as plain
        -- text (no LIKE, so a prefix character is never a wildcard), and the part
        -- between them must be all digits.
        SET @sql = N'SELECT @mx = MAX(TRY_CAST(s AS bigint)) FROM (
                SELECT SUBSTRING(v, DATALENGTH(@p) / 2 + 1,
                                 DATALENGTH(v) / 2 - DATALENGTH(@p) / 2 - DATALENGTH(@f) / 2) AS s
                FROM (SELECT CAST(' + QUOTENAME(@col) + N' AS nvarchar(255)) COLLATE DATABASE_DEFAULT AS v
                      FROM ' + QUOTENAME(@tbl) + N') AS ids
                WHERE DATALENGTH(v) > DATALENGTH(@p) + DATALENGTH(@f)
                  AND LEFT(v, DATALENGTH(@p) / 2) = @p
                  AND RIGHT(v, DATALENGTH(@f) / 2) = @f
            ) AS suffixes
            WHERE s NOT LIKE N''%[^0-9]%'' AND LEN(s) <= 18;';
        SET @mx = NULL;
        EXEC sp_executesql @sql, N'@p nvarchar(255), @f nvarchar(255), @mx bigint OUTPUT',
             @p = @prefix, @f = @postfix, @mx = @mx OUTPUT;
        INSERT #counterMax (NumberId, NumberType, CounterBefore, MaxInUse)
        VALUES (@id, @type, @counter, @mx);
    END;
    FETCH NEXT FROM c INTO @id, @type, @counter, @prefix, @postfix, @tbl, @col;
END;
CLOSE c;
DEALLOCATE c;

-- Report what moves, then move it. Never lower; never past int.
SELECT m.NumberType, m.CounterBefore, m.MaxInUse AS CounterAfter
FROM #counterMax m
WHERE m.MaxInUse IS NOT NULL AND m.MaxInUse > m.CounterBefore AND m.MaxInUse <= 2147483647
ORDER BY m.NumberType;

UPDATE n
SET NumberCounter = CAST(m.MaxInUse AS int)
FROM EcomNumbers n
JOIN #counterMax m ON m.NumberId = n.NumberId
WHERE m.MaxInUse IS NOT NULL
  AND m.MaxInUse <= 2147483647
  AND m.MaxInUse > n.NumberCounter;

DROP TABLE #counterMax;

COMMIT TRANSACTION;
