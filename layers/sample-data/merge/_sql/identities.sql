-- ===========================================================================
-- sample-data layer - demo identities (permission groups + buyer + CSR)
-- ===========================================================================
-- Base-contract anchors (layers/base/base.contract.json, guaranteedRows):
--   AccessUser groups (AccessUserType=2, exact ids): 1325 Customers,
--   1270 Account Admin, 1292 CSR. Users (AccessUserType=5, exact ids):
--   1328 buyer (customer number 98745621), 1326 CSR (customer number 7789765).
--   Membership: 1328->1325, 1326->1292.
-- DW 10.26.x has no separate group table - groups ARE AccessUser rows of
-- type 2. The inline page.yml permission bindings (keyed by group name +
-- ownerId) resolve against these rows and write the frontend gate into the
-- UnifiedPermission table.
-- Apply BEFORE the host starts: DW caches identity state at startup.
-- Idempotent: every insert is guarded by IF NOT EXISTS.
--
-- sqlcmd variables (pass with `sqlcmd -v NAME="value"`; the Foundry harness
-- substitutes them itself). Values are demo credentials, never production:
--   BuyerUserName   frontend buyer login name (canonical: IMCUser)
--   BuyerPassword   PLATFORM HASH of the buyer demo password
--   CsrPassword     PLATFORM HASH of the CSR demo password
--
-- CREDENTIALS
--   BuyerPassword and CsrPassword carry the platform password HASH, not the
--   password (layer.json valueShape: dw-password-hash). AccessUserPassword stores
--   what the host compares a sign-in against, which with password encryption on
--   is the 128-character hex SHA512 string (lowercase hex of
--   SHA512(UTF8(password + "DwSecret"))). A plaintext value is written verbatim
--   and yields a user that cannot sign in, with no error in SQL, in any log or on
--   the sign-in page (Foundry #1104). The applier takes the plaintext and hashes
--   it once. The shape guard below refuses any value that is not 128 hex
--   characters, naming the variable, before a single row is written.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ---------------------------------------------------------------------------
-- 0. The password shape guard, the same shape as truvio-identities.sql. Runs
--    before BEGIN TRAN and ends the batch with RETURN, so a refused value writes
--    nothing whether or not the runner passes sqlcmd -b; with -b the non-zero
--    exit stops the apply as well. DATALENGTH rather than LEN, which ignores
--    trailing spaces; a binary collation so the hex class means exactly 0-9, A-F
--    and a-f.
-- ---------------------------------------------------------------------------
DECLARE @SdPasswordShape NVARCHAR(200) = N'';
IF DATALENGTH(N'$(BuyerPassword)') <> 256 OR N'$(BuyerPassword)' COLLATE Latin1_General_BIN LIKE N'%[^0-9A-Fa-f]%'
    SET @SdPasswordShape = @SdPasswordShape + N' BuyerPassword';
IF DATALENGTH(N'$(CsrPassword)') <> 256 OR N'$(CsrPassword)' COLLATE Latin1_General_BIN LIKE N'%[^0-9A-Fa-f]%'
    SET @SdPasswordShape = @SdPasswordShape + N' CsrPassword';
IF @SdPasswordShape <> N''
BEGIN
    RAISERROR(N'identities.sql: sqlcmd variable(s)%s must carry the platform password hash, a 128-character hex string, and do not. AccessUserPassword stores the value verbatim; a plaintext value creates a user that can never sign in. Hash the password first and pass the hash. Nothing was written.', 16, 1, @SdPasswordShape);
    RETURN;
END

BEGIN TRAN;

-- 1 + 2. Groups (AccessUserType=2) and users (AccessUserType=5) with EXACT source ids.
SET IDENTITY_INSERT AccessUser ON;

-- Group 1325 Customers
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 1325)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName, AccessUserActive)
    VALUES (1325, 2, 'Customers', 'Customers', 1);

-- Group 1270 Account Admin
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 1270)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName, AccessUserActive)
    VALUES (1270, 2, 'Account Admin', 'Account Admin', 1);

-- Group 1292 CSR
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 1292)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName, AccessUserActive)
    VALUES (1292, 2, 'CSR', 'CSR', 1);

-- Buyer user 1328 (complete profile so the row is a valid frontend customer)
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 1328)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName,
                            AccessUserEmail, AccessUserPassword, AccessUserCustomerNumber,
                            AccessUserAddress, AccessUserZip, AccessUserCity, AccessUserActive)
    VALUES (1328, 5, '$(BuyerUserName)', '$(BuyerUserName)', 'IMCUser@testcompany.com', '$(BuyerPassword)', '98745621',
            '742 Evergreen Terrace', '62704', 'Springfield', 1);

-- CSR salesrep user 1326
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 1326)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName,
                            AccessUserPassword, AccessUserCustomerNumber, AccessUserActive)
    VALUES (1326, 5, 'IMC Sales rep', 'IMCSalesrep', '$(CsrPassword)', '7789765', 1);

SET IDENTITY_INSERT AccessUser OFF;

-- 3. Membership (AccessUserGroupRelationSort is NOT NULL - set 0).
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation
               WHERE AccessUserGroupRelationUserId = 1328 AND AccessUserGroupRelationGroupId = 1325)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort)
    VALUES (1328, 1325, 0);

IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation
               WHERE AccessUserGroupRelationUserId = 1326 AND AccessUserGroupRelationGroupId = 1292)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort)
    VALUES (1326, 1292, 0);

-- The buyer-scoped contract price lives in catalog.sql (FIXT-PRICE-CONTRACT on
-- FIXT0001) - it needs the catalog rows, which land after the base deserialize.

COMMIT TRAN;
PRINT 'Done - sample-data identities: groups 1325/1270/1292, users 1328/1326, membership.';
