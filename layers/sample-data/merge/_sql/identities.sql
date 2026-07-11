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
--   BuyerPassword   buyer demo password
--   CsrPassword     CSR demo password
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

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
