-- ===========================================================================
-- sample-data layer - email-marketing statistics backfill
-- ===========================================================================
-- A campaign email that shows 0 sent / 0 clicked reads exactly like an
-- unfinished build. The stats grids are fed by the send engine and the tracking
-- pixel, and NO MCP or Admin API surface creates send history, so this is a
-- fixture backfill into the telemetry tables. It stays strictly inside the
-- statistics and tracking tables: the emails, flows and pages themselves are
-- never touched here.
--
-- The join keys the grids actually use (each one was a dead end until proven):
--
--   RecipientStatisticsByEmail?EmailId=<n> resolves its recipients through
--     EmailMarketingEmail.EmailOriginalMessageId = EmailRecipient.RecipientMessageId.
--     NOT EmailMessageId. Setting EmailMessageId and inserting EmailRecipient
--     rows returns 0 rows forever; setting EmailOriginalMessageId makes the same
--     grid return the recipients live, without a recycle. This script sets both,
--     because the admin editor reads EmailMessageId, but the stats grid only
--     resolves through EmailOriginalMessageId.
--   Per-recipient CLICKED is a COUNT over OMCLinkClick joined to OMCLink where
--     OMCLink.LinkReferenceKey = CAST(<MessageId> AS varchar) AND
--     OMCLinkClick.LinkClickClickerKey = CAST(<RecipientId> AS varchar).
--     Both halves must match; either key alone yields 0. LinkClicksByEmail
--     (per-link performance) reads the same pair, so one correct click row feeds
--     both grids. OMCLink.LinkReferenceType is 'EmailMessaging'.
--   OPENED is PIXEL-ONLY. The per-recipient opened column and the EmailById
--     opened/clicked aggregates are materialized by the live open-tracking pixel
--     handler and are NOT reproducible from raw SQL - proven negative across
--     every OMCLink link type and 12 EmailAction ActionTypes. This script does
--     not attempt it. Script the demo around sends, bounces, clicks and link
--     performance, or generate real opens by loading the tracking pixel.
--
-- SCOPE: the backfill is DISCOVERY-DRIVEN. It seeds statistics for every
-- EmailMarketingEmail row that has no send history yet, and it is a clean no-op
-- on a database with no campaign emails. sample-data does not author campaign
-- emails itself and must not bind to another layer's rows (additions bind to the
-- base contract only), so a composition whose layers ship no EmailMarketingEmail
-- row gets nothing from this script and no error.
--
-- Idempotent: every row this script writes is marked
-- MessageDomainUrl = 'https://sample-data.example.invalid', and the script
-- deletes its own marked rows before re-seeding. Real send history is never
-- touched: an email whose EmailOriginalMessageId points at an unmarked message
-- is skipped.
--
-- Apply AFTER the base and any layer that ships campaign emails, and BEFORE
-- demo-clock.sql, so the clock anchors the seeded send dates with everything
-- else. Takes no sqlcmd variables.
--
-- Verify by calling RecipientStatisticsByEmail?EmailId=<n> and LinkClicksByEmail
-- for each seeded email and checking the numbers match the seed. A green insert
-- proves nothing; the grid query is the test.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.EmailMarketingEmail', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EmailMessage', N'U') IS NULL
   OR OBJECT_ID(N'dbo.EmailRecipient', N'U') IS NULL
   OR OBJECT_ID(N'dbo.OMCLink', N'U') IS NULL
   OR OBJECT_ID(N'dbo.OMCLinkClick', N'U') IS NULL
BEGIN
    RAISERROR(N'email-stats.sql: an email-marketing table is missing. This platform build does not carry the statistics schema; skip this script for it.', 16, 1);
END
GO

DECLARE @marker      NVARCHAR(510) = N'https://sample-data.example.invalid';
DECLARE @provider    NVARCHAR(510) = N'Dynamicweb.EmailMarketing.RecipientProviders.AccessUserRecipientProvider';
DECLARE @recipients  INT = 24;   -- sends per campaign email
DECLARE @bounces     INT = 2;    -- of those, delivery failures
DECLARE @links       INT = 3;    -- tracked links per campaign email

BEGIN TRAN;

-- ---------------------------------------------------------------------------
-- 1. Clear this script's own previous output. Delete children first: the click
--    rows key off the link ids, the link rows off the message ids.
-- ---------------------------------------------------------------------------
DECLARE @mine TABLE (MessageId INT PRIMARY KEY);
INSERT INTO @mine (MessageId)
SELECT MessageId FROM EmailMessage WHERE MessageDomainUrl = @marker;

DELETE c
FROM OMCLinkClick c
JOIN OMCLink l ON l.LinkId = c.LinkClickLinkId
WHERE l.LinkReferenceType = N'EmailMessaging'
  AND EXISTS (SELECT 1 FROM @mine m WHERE CAST(m.MessageId AS NVARCHAR(510)) = l.LinkReferenceKey);

DELETE l
FROM OMCLink l
WHERE l.LinkReferenceType = N'EmailMessaging'
  AND EXISTS (SELECT 1 FROM @mine m WHERE CAST(m.MessageId AS NVARCHAR(510)) = l.LinkReferenceKey);

DELETE r
FROM EmailRecipient r
WHERE EXISTS (SELECT 1 FROM @mine m WHERE m.MessageId = r.RecipientMessageId);

UPDATE e
   SET EmailOriginalMessageId = NULL,
       EmailMessageId         = NULL
FROM EmailMarketingEmail e
WHERE EXISTS (SELECT 1 FROM @mine m WHERE m.MessageId IN (e.EmailOriginalMessageId, e.EmailMessageId));

DELETE FROM EmailMessage WHERE MessageDomainUrl = @marker;

-- ---------------------------------------------------------------------------
-- 2. Backfill, one campaign email at a time. Only emails with NO send history
--    are touched, so a real send is never overwritten.
-- ---------------------------------------------------------------------------
DECLARE @emailId INT, @subject NVARCHAR(510), @senderName NVARCHAR(510), @senderEmail NVARCHAR(510);
DECLARE @seq INT = 0;
DECLARE @sentBase DATETIME;
DECLARE @messageId INT;

DECLARE campaigns CURSOR LOCAL FAST_FORWARD FOR
    SELECT e.EmailId,
           ISNULL(NULLIF(e.EmailSubject, N''), N'Sample campaign'),
           ISNULL(NULLIF(e.EmailSenderName, N''), N'Sample Data'),
           ISNULL(NULLIF(e.EmailSenderEmail, N''), N'sample-data@example.invalid')
    FROM EmailMarketingEmail e
    WHERE NOT EXISTS (SELECT 1 FROM EmailRecipient r WHERE r.RecipientMessageId = e.EmailOriginalMessageId)
      AND ISNULL(e.EmailIsTemplate, 0) = 0
    ORDER BY e.EmailId;

OPEN campaigns;
FETCH NEXT FROM campaigns INTO @emailId, @subject, @senderName, @senderEmail;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @seq += 1;

    -- Campaign N was sent (7 + N) days ago, so the seeded campaigns read as a
    -- sequence rather than a single blast. demo-clock.sql keeps them current.
    SET @sentBase = DATEADD(hour, 9, CAST(CAST(DATEADD(day, -(6 + @seq), GETDATE()) AS date) AS datetime));

    INSERT INTO EmailMessage
        (MessageSubject, MessageSenderName, MessageSenderEmail, MessageDomainUrl,
         MessageRecipientsSource, MessageRequireUniqueRecipients)
    VALUES
        (@subject, @senderName, @senderEmail, @marker, @provider, 1);

    SET @messageId = CAST(SCOPE_IDENTITY() AS INT);

    -- The stats grid resolves recipients through EmailOriginalMessageId; the
    -- admin editor reads EmailMessageId. Set both to the same message.
    UPDATE EmailMarketingEmail
       SET EmailOriginalMessageId = @messageId,
           EmailMessageId         = @messageId
     WHERE EmailId = @emailId;

    -- Recipients: the SENT count. The last @bounces of them carry a delivery
    -- error, which is what the grid renders as failed.
    ;WITH n AS (
        SELECT TOP (@recipients) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
        FROM sys.all_objects
    )
    INSERT INTO EmailRecipient
        (RecipientKey, RecipientName, RecipientEmailAddress, RecipientMessageId,
         RecipientSentTime, RecipientErrorMessage, RecipientErrorTime, RecipientSecret)
    SELECT
        N'FIXT-RCPT-' + RIGHT(N'00' + CAST(n.i AS nvarchar(3)), 2),
        N'Sample Recipient ' + RIGHT(N'00' + CAST(n.i AS nvarchar(3)), 2),
        N'sample-recipient-' + RIGHT(N'00' + CAST(n.i AS nvarchar(3)), 2) + N'@example.invalid',
        @messageId,
        DATEADD(second, n.i * 37, @sentBase),
        CASE WHEN n.i > @recipients - @bounces
             THEN N'550 5.1.1 Recipient address rejected: user unknown (sample-data fixture bounce)'
             ELSE NULL END,
        CASE WHEN n.i > @recipients - @bounces
             THEN DATEADD(second, n.i * 37 + 4, @sentBase)
             ELSE NULL END,
        LOWER(CONVERT(nvarchar(36), NEWID()))
    FROM n;

    -- Tracked links. LinkReferenceKey is the MESSAGE id as a string, and
    -- LinkReferenceType is 'EmailMessaging' - both halves are what the
    -- per-link-performance grid filters on.
    ;WITH l AS (
        SELECT TOP (@links) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i
        FROM sys.all_objects
    )
    INSERT INTO OMCLink (LinkUrl, LinkReferenceType, LinkReferenceKey)
    SELECT CASE l.i WHEN 1 THEN N'/shop' WHEN 2 THEN N'/shop?ProductID=FIXT0002' ELSE N'/contact' END,
           N'EmailMessaging',
           CAST(@messageId AS nvarchar(510))
    FROM l;

    -- Clicks. LinkClickClickerKey is the RECIPIENT id as a string. Delivered
    -- recipients only (a bounced send cannot click), and every click lands after
    -- its own send time so the send -> click sequence stays coherent.
    --
    -- The selection keys off each row's ORDINAL within this message, never off
    -- the identity id: identity values move on every re-seed, so an id-based
    -- rule would make the click counts drift run to run. On the shipped
    -- 24-sent / 2-bounced shape this yields exactly 13 clicks split 5/4/4 across
    -- the three links, so the per-link performance grid is not flat.
    INSERT INTO OMCLinkClick (LinkClickLinkId, LinkClickClickerKey, LinkClickClickTime, LinkClickSessionId)
    SELECT lk.LinkId,
           CAST(r.RecipientId AS nvarchar(510)),
           DATEADD(minute, 40 + ((r.Ord + lk.Ord) % 7) * 25, r.RecipientSentTime),
           LEFT(REPLACE(LOWER(CONVERT(nvarchar(36), NEWID())), N'-', N''), 24)
    FROM (SELECT RecipientId, RecipientSentTime,
                 ROW_NUMBER() OVER (ORDER BY RecipientId) AS Ord
          FROM EmailRecipient
          WHERE RecipientMessageId = @messageId
            AND RecipientErrorMessage IS NULL) AS r
    CROSS JOIN (SELECT LinkId, ROW_NUMBER() OVER (ORDER BY LinkId) AS Ord
                FROM OMCLink
                WHERE LinkReferenceType = N'EmailMessaging'
                  AND LinkReferenceKey = CAST(@messageId AS nvarchar(510))) AS lk
    WHERE (r.Ord * 3 + lk.Ord) % 5 = 0;

    FETCH NEXT FROM campaigns INTO @emailId, @subject, @senderName, @senderEmail;
END

CLOSE campaigns;
DEALLOCATE campaigns;

COMMIT TRAN;
GO

-- ===========================================================================
-- Proving it works - read the GRID query, not the INSERT
-- ===========================================================================
--   SELECT e.EmailId, e.EmailSubject,
--          (SELECT COUNT(*) FROM EmailRecipient r
--            WHERE r.RecipientMessageId = e.EmailOriginalMessageId) AS Sent,
--          (SELECT COUNT(*) FROM EmailRecipient r
--            WHERE r.RecipientMessageId = e.EmailOriginalMessageId
--              AND r.RecipientErrorMessage IS NOT NULL) AS Bounced,
--          (SELECT COUNT(*) FROM OMCLinkClick c
--             JOIN OMCLink l ON l.LinkId = c.LinkClickLinkId
--            WHERE l.LinkReferenceKey = CAST(e.EmailOriginalMessageId AS nvarchar(510))
--              AND l.LinkReferenceType = 'EmailMessaging') AS Clicks
--   FROM EmailMarketingEmail e
--   WHERE e.EmailOriginalMessageId IS NOT NULL;
--
-- Then confirm through the admin surfaces themselves:
--   GET /Admin/Api/RecipientStatisticsByEmail?EmailId=<n>
--   GET /Admin/Api/LinkClicksByEmail?EmailId=<n>
-- ===========================================================================
