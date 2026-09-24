-- ===========================================================================
-- sample-data layer - the demo clock (anchor table + whole-day uniform shift)
-- ===========================================================================
-- Every seeded demo decays. Orders, carts, email send/click history and
-- campaign windows all carry absolute dates, so a demo that is a few days or
-- weeks old shows stale orders, expired campaign windows and empty-looking
-- marketing dashboards without anyone touching the build.
--
-- The mechanic is an ANCHOR TABLE plus a WHOLE-DAY UNIFORM SHIFT:
--
--   dbo._demoClock(Id, AnchoredTo, Label)  one row per shifter, recording the
--     date this shifter last anchored its fixtures to.
--   dbo.usp_DemoClockShift                 shifts every operational date column
--     by DATEDIFF(day, AnchoredTo, today), then re-anchors its own row.
--   ScheduledTask 'Truvio demo clock'      runs the procedure every 1440
--     minutes through the stock RunSqlScheduledTaskAddIn.
--
-- Whole-day and uniform is the whole trick: shifting every column by the same
-- integer number of days preserves intra-day ordering and every relative gap,
-- so order -> ship -> click sequences stay coherent. The shift is idempotent
-- (a +1 then -1 test nets zero) and catch-up safe, so it runs unattended after
-- idle days.
--
-- Applies AFTER the merge deserialize that lands this layer's rows. Those rows
-- are serialized YAML carrying ABSOLUTE dates frozen at the harvest day
-- 2026-09-13: the brand orders, quotes and carts (TCO-0001..TCO-0026,
-- TCO-Q001..TCO-Q007, TCO-C001..TCO-C002) and the favourite lists ladder back
-- from 2026-09-12 as far as 2026-04-02, and every product carries ProductCreated and
-- ProductExpectedDelivery from the same harvest. The anchor is therefore seeded
-- to that harvest day and NOT to GETDATE(): a GETDATE() anchor reads delta 0 on
-- a fresh install, so the orders would stay frozen in 2026-09 forever while the
-- task reported Success. With the harvest-day anchor the first run carries a
-- real delta and moves the whole dataset onto the current calendar in one pass.
--
-- Idempotent: the tables, the seed rows, the procedure and the task row are all
-- created only when absent (the procedure uses CREATE OR ALTER). Transactional
-- per batch. Takes no sqlcmd variables.
--
-- Reserved names owned by this layer: dbo._demoClock, dbo._demoClockExclusion,
-- dbo._demoClockGuard, dbo.usp_DemoClockShift, ScheduledTask 'Truvio demo clock'.
--
-- A SQL-inserted ScheduledTask row is invisible to a RUNNING app until a
-- recycle: the scheduled-task service caches its task collection at application
-- start. sample-data already requires a host restart after its deserialize, so the
-- task is registered before that restart and is live from it. Prove the
-- registration from GET /Admin/Api/Tasks (mind the 10-row default page size),
-- never from the INSERT.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ---------------------------------------------------------------------------
-- 1. The anchor table. One row per shifter. A SECOND date-shifting task must
--    own its OWN anchor row (Id=2, ...) and re-anchor only that row: the
--    shifter re-anchors to today, so a second task reading the same row at a
--    later slot sees delta 0 and shifts nothing, forever, while reporting
--    Success.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo._demoClock', N'U') IS NULL
BEGIN
    CREATE TABLE dbo._demoClock (
        Id         INT           NOT NULL CONSTRAINT PK_demoClock PRIMARY KEY,
        AnchoredTo DATE          NOT NULL,
        Label      NVARCHAR(128) NOT NULL
    );
END
GO

-- The harvest day the shipped rows carry, as a literal and never GETDATE() -
-- see the header. Re-harvesting this layer's YAML moves this date with it.
IF NOT EXISTS (SELECT 1 FROM dbo._demoClock WHERE Id = 1)
    INSERT INTO dbo._demoClock (Id, AnchoredTo, Label)
    VALUES (1, CAST('2026-09-13' AS date), N'sample-data demo clock');
GO

-- ---------------------------------------------------------------------------
-- 2. Table exclusions. Config and logging tables never move: audit and
--    scheduled-task logs must keep their real timestamps or the clock's own
--    run history becomes unreadable, and ScheduledTask.TaskNextRun is what the
--    scheduler reads to decide when to fire.
--
--    A build that wants a table left alone adds a row here; the procedure reads
--    the list, so no procedure edit is needed.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo._demoClockExclusion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo._demoClockExclusion (
        TableName SYSNAME        NOT NULL CONSTRAINT PK_demoClockExclusion PRIMARY KEY,
        Reason    NVARCHAR(200)  NOT NULL
    );
END
GO

INSERT INTO dbo._demoClockExclusion (TableName, Reason)
SELECT v.TableName, v.Reason
FROM (VALUES
    (N'_demoClock',              N'The clock own anchor row is re-anchored by the procedure, never shifted by it'),
    (N'ScheduledTask',           N'TaskNextRun/TaskLastRun drive the scheduler; shifting them moves or stalls every task including this one'),
    (N'ScheduledTaskExecution',  N'Task run history - the clock own log must stay readable'),
    (N'CommandLog',              N'Logging'),
    (N'GeneralLog',              N'Logging'),
    (N'SystemLog',               N'Logging'),
    (N'EcomOrderDebuggingInfo',  N'Logging'),
    (N'Updates',                 N'Platform update history - a real installation record, not demo data'),
    (N'VersionData',             N'Content version history - a real authoring record'),
    (N'AccessUserPassword',      N'Security state, not demo-visible dates'),
    (N'AccessUserToken',         N'Security state - shifting token expiry resurrects expired tokens'),
    (N'NonBrowserSession',       N'Runtime session state'),
    (N'TrackingSession',         N'Runtime telemetry'),
    (N'TrackingView',            N'Runtime telemetry'),
    (N'McpConfiguration',        N'Configuration'),
    (N'McpConfigurationCredential', N'Configuration and security state'),
    (N'McpAdminAssistantConversation', N'Tooling history'),
    (N'McpAdminAssistantMessage',      N'Tooling history')
) AS v(TableName, Reason)
WHERE NOT EXISTS (SELECT 1 FROM dbo._demoClockExclusion e WHERE e.TableName = v.TableName);
GO

-- ---------------------------------------------------------------------------
-- 3. Per-column guards. Auto-discovering date columns is right for demo data,
--    but any column a cancel / void / close operation overloads as a STATE
--    MARKER needs its own guard - a blanket DATEADD marches the cancelled thing
--    back to life.
--
--    The known instance: GiftCardCancel writes no reversing transaction and
--    sets no status flag. It cancels by rewriting GiftCardExpiryDate to now and
--    keeping the balance, so on a cancelled card that column is a cancellation
--    timestamp, not an expiry. Shifting only rows whose value is still in the
--    future leaves the cancelled card frozen and still reading inactive.
--
--    GuardPredicate is spliced into the CASE WHEN for that column only. It must
--    reference the column as [<ColumnName>] and nothing else.
-- ---------------------------------------------------------------------------
IF OBJECT_ID(N'dbo._demoClockGuard', N'U') IS NULL
BEGIN
    CREATE TABLE dbo._demoClockGuard (
        TableName      SYSNAME       NOT NULL,
        ColumnName     SYSNAME       NOT NULL,
        GuardPredicate NVARCHAR(400) NOT NULL,
        Reason         NVARCHAR(300) NOT NULL,
        CONSTRAINT PK_demoClockGuard PRIMARY KEY (TableName, ColumnName)
    );
END
GO

INSERT INTO dbo._demoClockGuard (TableName, ColumnName, GuardPredicate, Reason)
SELECT v.TableName, v.ColumnName, v.GuardPredicate, v.Reason
FROM (VALUES
    (N'EcomGiftCard', N'GiftCardExpiryDate', N'[GiftCardExpiryDate] > GETDATE()',
     N'GiftCardCancel cancels a card by rewriting GiftCardExpiryDate to now, so on a cancelled card the column is a cancellation timestamp. Shift only cards still in the future, or a nightly shift hands the viewer a live balance meant to be void.')
) AS v(TableName, ColumnName, GuardPredicate, Reason)
WHERE NOT EXISTS (SELECT 1 FROM dbo._demoClockGuard g
                  WHERE g.TableName = v.TableName AND g.ColumnName = v.ColumnName);
GO

-- ---------------------------------------------------------------------------
-- 4. The shifter.
--
--    Date columns are DISCOVERED from sys.columns on every run and never
--    hardcoded: every commerce feature spells its timestamps differently (one
--    hand-written pass hardcoded 18 column names and 12 of them were wrong),
--    and discovery is also what keeps the shifter correct across a platform
--    upgrade. A reference build shifted 142 date columns across 49 tables.
--
--    Sentinel values are left alone. DATEADD over '9999-12-31' overflows and
--    aborts the batch, and a 1900-01-01 placeholder is not a fixture date, so
--    only values inside [1900-01-02, 2900-01-01) move.
--
--    @WhatIf = 1 reports the delta and the plan and writes nothing. Use it to
--    inspect; use the rewind-and-run below to PROVE.
--
--    SET QUOTED_IDENTIFIER ON is MANDATORY and must be its own batch before the
--    CREATE. The setting is captured at procedure-creation time, and sqlcmd -i
--    (how the Foundry gate and every documented apply path run this file)
--    defaults QUOTED_IDENTIFIER to OFF. Without it the procedure creates
--    cleanly, sqlcmd exits 0, and the FIRST invocation fails at runtime with
--    Msg 1934 "SELECT failed because the following SET options have incorrect
--    settings: 'QUOTED_IDENTIFIER'" - because the plan builder calls the XML
--    data type method .value(). A green apply proves nothing here; run the
--    procedure once.
-- ---------------------------------------------------------------------------
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_DemoClockShift
    @AnchorId INT = 1,
    @WhatIf   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @today DATE = CAST(GETDATE() AS date);
    DECLARE @anchor DATE;

    SELECT @anchor = AnchoredTo FROM dbo._demoClock WHERE Id = @AnchorId;

    IF @anchor IS NULL
    BEGIN
        RAISERROR(N'usp_DemoClockShift: no _demoClock row with Id = %d. Every shifter owns its own anchor row.', 16, 1, @AnchorId);
        RETURN;
    END

    DECLARE @d INT = DATEDIFF(day, @anchor, @today);

    PRINT CONCAT(N'demo clock: anchor Id=', @AnchorId, N' anchored ', CONVERT(nvarchar(10), @anchor, 23),
                 N', today ', CONVERT(nvarchar(10), @today, 23), N', delta ', @d, N' day(s)');

    IF @d = 0
    BEGIN
        PRINT N'demo clock: delta 0, nothing to shift. A bare run right after install proves NOTHING - a new anchor row is legitimately 0 on its first pass. Prove with a rewind-and-run instead.';
        RETURN;
    END

    -- Build one UPDATE per table, all of that table's date columns in one SET.
    DECLARE @sql NVARCHAR(MAX) = N'';
    DECLARE @tables INT = 0, @cols INT = 0;

    ;WITH dateCols AS (
        SELECT  t.name AS TableName,
                c.name AS ColumnName
        FROM sys.columns c
        JOIN sys.tables  t ON t.object_id = c.object_id
        JOIN sys.schemas s ON s.schema_id = t.schema_id
        JOIN sys.types  ty ON ty.user_type_id = c.user_type_id
        WHERE s.name = N'dbo'
          AND t.is_ms_shipped = 0
          AND c.is_computed = 0
          AND ty.name IN (N'date', N'datetime', N'datetime2', N'smalldatetime')
          -- sys.tables/sys.columns name is sysname in the catalog collation
          -- (Latin1_General_100_CI_AS_KS_WS_SC); the layer's own sysname columns take
          -- the database default (Latin1_General_100_CI_AS). COLLATE DATABASE_DEFAULT
          -- on the compare, or the batch fails to compile with Msg 468 before the
          -- procedure's own shape guards ever run.
          AND NOT EXISTS (SELECT 1 FROM dbo._demoClockExclusion e
                          WHERE e.TableName = t.name COLLATE DATABASE_DEFAULT)
          AND t.name NOT LIKE N'%[_]BAK[_]%'      -- hand-taken backup snapshots
          AND t.name NOT LIKE N'%Log'             -- logging tables
          AND EXISTS (SELECT 1 FROM sys.partitions p
                      WHERE p.object_id = t.object_id AND p.index_id IN (0, 1) AND p.rows > 0)
    ),
    colExpr AS (
        SELECT  dc.TableName,
                dc.ColumnName,
                CAST(
                    QUOTENAME(dc.ColumnName) + N' = CASE WHEN ' + QUOTENAME(dc.ColumnName)
                    + N' > ''1900-01-01'' AND ' + QUOTENAME(dc.ColumnName) + N' < ''2900-01-01'''
                    + ISNULL(N' AND ' + g.GuardPredicate, N'')
                    + N' THEN DATEADD(day, @d, ' + QUOTENAME(dc.ColumnName) + N') ELSE '
                    + QUOTENAME(dc.ColumnName) + N' END'
                AS NVARCHAR(MAX)) AS SetExpr,
                CAST(QUOTENAME(dc.ColumnName) + N' IS NOT NULL' AS NVARCHAR(MAX)) AS WhereExpr
        FROM dateCols dc
        LEFT JOIN dbo._demoClockGuard g
               ON g.TableName  = dc.TableName  COLLATE DATABASE_DEFAULT
              AND g.ColumnName = dc.ColumnName COLLATE DATABASE_DEFAULT
    ),
    perTable AS (
        SELECT  ce.TableName,
                COUNT(*) AS ColCount,
                STUFF((SELECT N', ' + i.SetExpr FROM colExpr i
                        WHERE i.TableName = ce.TableName ORDER BY i.ColumnName
                        FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 2, N'') AS SetList,
                STUFF((SELECT N' OR ' + i.WhereExpr FROM colExpr i
                        WHERE i.TableName = ce.TableName ORDER BY i.ColumnName
                        FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), 1, 4, N'') AS WhereList
        FROM colExpr ce
        GROUP BY ce.TableName
    )
    -- FOR XML PATH escapes the generated markup characters and .value() unescapes
    -- them, so the '>' and '<' in the CASE guards round-trip intact. Reading the
    -- result as a set (never a variable-accumulating SELECT with ORDER BY, whose
    -- order SQL Server does not guarantee) keeps the plan deterministic.
    SELECT @sql    = ISNULL((SELECT N'UPDATE ' + QUOTENAME(p.TableName) + N' SET ' + p.SetList
                                  + N' WHERE ' + p.WhereList + N';' + CHAR(13) + CHAR(10)
                             FROM perTable p ORDER BY p.TableName
                             FOR XML PATH(N''), TYPE).value(N'.', N'nvarchar(max)'), N''),
           @tables = (SELECT COUNT(*) FROM perTable),
           @cols   = ISNULL((SELECT SUM(ColCount) FROM perTable), 0);

    PRINT CONCAT(N'demo clock: ', @cols, N' date column(s) across ', @tables, N' table(s) in scope');

    IF @tables = 0
    BEGIN
        PRINT N'demo clock: no date columns in scope - nothing to shift, anchor left untouched.';
        RETURN;
    END

    IF @WhatIf = 1
    BEGIN
        PRINT N'demo clock: @WhatIf = 1, nothing written. Plan follows.';
        -- SELECT, not PRINT: PRINT truncates an nvarchar(max) at 4000 characters
        -- and the plan is longer than that on any real database.
        SELECT @sql AS DemoClockPlan;
        RETURN;
    END

    BEGIN TRAN;

    EXEC sys.sp_executesql @sql, N'@d INT', @d = @d;

    -- Re-anchor ONLY this shifter's row.
    UPDATE dbo._demoClock SET AnchoredTo = @today WHERE Id = @AnchorId;

    COMMIT TRAN;

    PRINT CONCAT(N'demo clock: shifted by ', @d, N' day(s) and re-anchored Id=', @AnchorId, N' to ', CONVERT(nvarchar(10), @today, 23));
END
GO

-- ---------------------------------------------------------------------------
-- 5. Register the recurring task on the stock RunSql add-in.
--
--    TaskAddInSettings holds LITERAL XML: the surrounding document's own markup
--    stays intact and only a parameter VALUE would ever be escaped. XML-escaping
--    the whole document stores a string the add-in loader cannot parse, and the
--    task then exists, opens in admin, and does nothing. The value here is
--    'EXEC dbo.usp_DemoClockShift;' - it carries no XML metacharacter, which is
--    exactly why the task calls a procedure instead of inlining the shift SQL.
--
--    TaskType 0 + TaskMinute 1440 + TaskHour/Day/Wday -1 is the stock daily
--    recurrence (the platform's own 'Cleanup logs' task uses it).
--    TaskStartFromLastRun 1 makes it catch-up safe after idle days.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM ScheduledTask WHERE TaskName = N'Truvio demo clock')
BEGIN
    DECLARE @addin NVARCHAR(200) = N'Dynamicweb.Scheduling.ScheduledTaskAddIns.RunSqlScheduledTaskAddIn, Dynamicweb.Core';
    DECLARE @addinName NVARCHAR(200) = N'Dynamicweb.Scheduling.ScheduledTaskAddIns.RunSqlScheduledTaskAddIn';
    DECLARE @settings NVARCHAR(MAX) =
        N'<?xml version="1.0" encoding="utf-8"?>' + CHAR(13) + CHAR(10) +
        N'<Parameters addin="' + @addinName + N'">' + CHAR(13) + CHAR(10) +
        N'  <Parameter addin="' + @addinName + N'" name="SQL Query" value="EXEC dbo.usp_DemoClockShift;" />' + CHAR(13) + CHAR(10) +
        N'  <Parameter addin="' + @addinName + N'" name="Log debugging info" value="True" />' + CHAR(13) + CHAR(10) +
        N'</Parameters>';

    INSERT INTO ScheduledTask
        (TaskName, TaskBegin, TaskEnd, TaskLastRun, TaskNextRun, TaskEnabled, TaskType,
         TaskMinute, TaskHour, TaskDay, TaskWday,
         TaskAddInTypeName, TaskAddInSettings, TaskComment,
         TaskCheckPrevious, TaskSort, TaskStartFromLastRun, TaskLastResult)
    VALUES
        (N'Truvio demo clock',
         GETDATE(), '9999-12-31', '2000-01-01', DATEADD(minute, 1440, GETDATE()), 1, 0,
         1440, -1, -1, -1,
         @addin, @settings,
         -- TaskComment is NVARCHAR(255): a longer literal fails the INSERT with
         -- Msg 2628 (String or binary data would be truncated).
         N'Keeps the sample-data rows anchored to today: shifts every operational date column by DATEDIFF(day, _demoClock.AnchoredTo, today), then re-anchors. Whole-day and uniform, so ordering and gaps survive. Skips _demoClockExclusion; guards _demoClockGuard.',
         0, 0, 1, 1);
END
GO

-- ===========================================================================
-- Proving it works - REWIND AND RUN, never a bare run
-- ===========================================================================
-- A new task creates or reads its anchor row on the first execution, so the
-- delta is legitimately 0 on that pass. "The task ran" is not evidence that
-- "the task shifts", and a bare run reports Success while doing nothing.
--
--   -- capture a known timestamp (TCO-0001 is the delivered order the RMA
--   -- flow returns against)
--   SELECT TOP 1 OrderId, OrderDate FROM EcomOrders WHERE OrderId = 'TCO-0001';
--   -- rewind THIS shifter's anchor by one day, leaving any other anchor alone
--   UPDATE dbo._demoClock SET AnchoredTo = DATEADD(day, -1, AnchoredTo) WHERE Id = 1;
--   EXEC dbo.usp_DemoClockShift;
--   -- assert: OrderDate advanced by exactly one day, AnchoredTo is today again
--   SELECT OrderId, OrderDate FROM EcomOrders WHERE OrderId = 'TCO-0001';
--   SELECT Id, AnchoredTo FROM dbo._demoClock;
--
-- Idempotency check: rewind +1, run, rewind -1, run - the timestamps net zero.
-- Confirm end to end from the rendered screen as well (the same order list
-- captured a demo day apart shows every date moved by one day), not only from
-- the task's lastRunState. A cancelled gift card must still read inactive after
-- the run.
-- ===========================================================================
