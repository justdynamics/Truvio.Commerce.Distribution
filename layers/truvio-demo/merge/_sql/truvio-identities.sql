-- ===========================================================================
-- truvio-demo layer - the brand identities, the B2B account and the orders
-- ===========================================================================
-- Three personas on the fictional truvio-demo domain, one B2B account they all
-- belong to, and twelve orders across states - the rows behind the customer
-- centre, the order list, reorder and impersonation on the swift-demo edition.
--
-- SEED GATING (base.contract.json)
--   The contract's guaranteedRows are UNTOUCHED: permission groups 1325
--   Customers / 1270 Account Admin / 1292 CSR and users 1328 / 1326 are
--   sample-data's, and this script only reads them - every persona here is a NEW
--   row above the contract's int-identity floor of 100000 (idRules
--   .intIdentityFloor), and each joins one of the three contract groups rather
--   than inventing a fourth. A composition without sample-data therefore has no
--   group to join, which is why swift-demo composes both layers.
--
-- CREDENTIALS
--   TruvioBuyerPassword, TruvioCsrPassword and TruvioAdminPassword arrive as sqlcmd
--   variables: never repo content, never logged. Each one carries the PLATFORM
--   HASH of the persona's password, not the password: AccessUserPassword stores
--   what the host compares against, which on a host with password encryption on
--   is a 128-character hex SHA512 string. A plaintext value is written verbatim
--   and yields a persona that cannot sign in, with no error in SQL, in any log or
--   on the sign-in page. Hash first, then pass the hash. The shape guard below
--   refuses any value that is not 128 hex characters, naming the variable, before
--   a single row is written. An applier that cannot supply a declared variable
--   must fail before executing this script, never substitute a blank.
--
-- CUSTOMER NUMBER
--   The account and all three contacts carry ONE customer number, TC-100200.
--   Contract prices, account-wide favourites and the CSR account listing compare
--   that string exactly, so a per-contact suffix silently limits all three to the
--   one contact whose number matches. A per-contact identifier, if a story needs
--   one, belongs in AccessUserExternalId, never in the customer number.
--
-- TIMING
--   Unlike sample-data's identities.sql this script runs
--   after-replace-deserialize, not before-host-start: its orders FK the shop,
--   currency and catalogue rows, which do not exist before the deserialize. DW
--   caches identity state at startup, so the personas become first-class on the
--   host restart the catalogue already requires (layer.json
--   requiresHostRestart: true) - one restart covers both scripts.
--
-- ORDER STATES
--   Only OrderFlowId 1 states are used (OS1 New, OS2 Completed, OS3 Rejected).
--   OS12/OS13/OS14 belong to flow 4 and an order carrying a state from another
--   flow reads as a broken record in the Commerce grids.
--
-- Idempotent: every insert is IF NOT EXISTS-guarded on its own key.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- ---------------------------------------------------------------------------
-- 0. The password shape guard. Runs before BEGIN TRAN and ends the batch with
--    RETURN, so a refused value writes nothing whether or not the runner passes
--    sqlcmd -b; with -b the non-zero exit stops the apply as well. DATALENGTH
--    rather than LEN, which ignores trailing spaces; a binary collation so the
--    hex class means exactly 0-9, A-F and a-f.
-- ---------------------------------------------------------------------------
DECLARE @TcPasswordShape NVARCHAR(200) = N'';
IF DATALENGTH(N'$(TruvioBuyerPassword)') <> 256 OR N'$(TruvioBuyerPassword)' COLLATE Latin1_General_BIN LIKE N'%[^0-9A-Fa-f]%'
    SET @TcPasswordShape = @TcPasswordShape + N' TruvioBuyerPassword';
IF DATALENGTH(N'$(TruvioCsrPassword)') <> 256 OR N'$(TruvioCsrPassword)' COLLATE Latin1_General_BIN LIKE N'%[^0-9A-Fa-f]%'
    SET @TcPasswordShape = @TcPasswordShape + N' TruvioCsrPassword';
IF DATALENGTH(N'$(TruvioAdminPassword)') <> 256 OR N'$(TruvioAdminPassword)' COLLATE Latin1_General_BIN LIKE N'%[^0-9A-Fa-f]%'
    SET @TcPasswordShape = @TcPasswordShape + N' TruvioAdminPassword';
IF @TcPasswordShape <> N''
BEGIN
    RAISERROR(N'truvio-identities.sql: sqlcmd variable(s)%s must carry the platform password hash, a 128-character hex string, and do not. AccessUserPassword stores the value verbatim; a plaintext value creates a persona that can never sign in. Hash the password first and pass the hash. Nothing was written.', 16, 1, @TcPasswordShape);
    RETURN;
END

BEGIN TRAN;

-- ---------------------------------------------------------------------------
-- 1. The B2B account (an AccessUser of type 2 - DW has no separate group table)
--    and the three personas (type 5), all above the 100000 identity floor.
-- ---------------------------------------------------------------------------
SET IDENTITY_INSERT AccessUser ON;

IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 100100)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName, AccessUserCustomerNumber, AccessUserActive)
    VALUES (100100, 2, 'Truvio Demo Account', 'Truvio Demo Account', 'TC-100200', 1);

-- buyer persona 100101 (buyer@truvio-demo.example)
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 100101)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName,
                            AccessUserEmail, AccessUserPassword, AccessUserCustomerNumber,
                            AccessUserCompany, AccessUserAddress, AccessUserZip, AccessUserCity, AccessUserActive)
    VALUES (100101, 5, 'Truvio Buyer', 'TruvioBuyer', 'buyer@truvio-demo.example', '$(TruvioBuyerPassword)', 'TC-100200', 'Truvio Demo Account', '1 Placeholder Way', '0000 TC', 'Truvio Demo', 1);
-- csr persona 100102 (csr@truvio-demo.example)
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 100102)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName,
                            AccessUserEmail, AccessUserPassword, AccessUserCustomerNumber,
                            AccessUserCompany, AccessUserAddress, AccessUserZip, AccessUserCity, AccessUserActive)
    VALUES (100102, 5, 'Truvio CSR', 'TruvioCsr', 'csr@truvio-demo.example', '$(TruvioCsrPassword)', 'TC-100200', 'Truvio Demo Account', '1 Placeholder Way', '0000 TC', 'Truvio Demo', 1);
-- admin persona 100103 (admin@truvio-demo.example)
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 100103)
    INSERT INTO AccessUser (AccessUserId, AccessUserType, AccessUserName, AccessUserUserName,
                            AccessUserEmail, AccessUserPassword, AccessUserCustomerNumber,
                            AccessUserCompany, AccessUserAddress, AccessUserZip, AccessUserCity, AccessUserActive)
    VALUES (100103, 5, 'Truvio Admin', 'TruvioAdmin', 'admin@truvio-demo.example', '$(TruvioAdminPassword)', 'TC-100200', 'Truvio Demo Account', '1 Placeholder Way', '0000 TC', 'Truvio Demo', 1);

SET IDENTITY_INSERT AccessUser OFF;

-- Converge a host seeded when the CSR and the admin carried TC-100201 / TC-100202.
-- The inserts above are IF NOT EXISTS, so they never touch an existing row; this
-- UPDATE is what moves both contacts onto the account's number. Guarded on the
-- difference, so a converged host is a no-op.
IF EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId IN (100102, 100103) AND ISNULL(AccessUserCustomerNumber, '') <> 'TC-100200')
    UPDATE AccessUser SET AccessUserCustomerNumber = 'TC-100200'
     WHERE AccessUserId IN (100102, 100103) AND ISNULL(AccessUserCustomerNumber, '') <> 'TC-100200';

-- ---------------------------------------------------------------------------
-- 2. Membership: each persona joins the B2B account AND the base-contract
--    permission group its role maps to. AccessUserGroupRelationSort is NOT NULL.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation WHERE AccessUserGroupRelationUserId = 100101 AND AccessUserGroupRelationGroupId = 100100)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort) VALUES (100101, 100100, 0);
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation WHERE AccessUserGroupRelationUserId = 100101 AND AccessUserGroupRelationGroupId = 1325)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort) VALUES (100101, 1325, 0);
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation WHERE AccessUserGroupRelationUserId = 100102 AND AccessUserGroupRelationGroupId = 100100)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort) VALUES (100102, 100100, 0);
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation WHERE AccessUserGroupRelationUserId = 100102 AND AccessUserGroupRelationGroupId = 1292)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort) VALUES (100102, 1292, 0);
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation WHERE AccessUserGroupRelationUserId = 100103 AND AccessUserGroupRelationGroupId = 100100)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort) VALUES (100103, 100100, 0);
IF NOT EXISTS (SELECT 1 FROM AccessUserGroupRelation WHERE AccessUserGroupRelationUserId = 100103 AND AccessUserGroupRelationGroupId = 1270)
    INSERT INTO AccessUserGroupRelation (AccessUserGroupRelationUserId, AccessUserGroupRelationGroupId, AccessUserGroupRelationSort) VALUES (100103, 1270, 0);

-- ---------------------------------------------------------------------------
-- 3. Twelve orders TCO-0001..TCO-0012 with their lines. Order lines snapshot the
--    product number and name, exactly as a live checkout does - a line that
--    joins back to EcomProducts for its label goes blank the moment the
--    catalogue is re-seeded.
--    OrderCompletedDate is set only on a Completed order: a New or Rejected
--    order carrying a completion date reads as completed in every date-scoped
--    grid and report, whatever its state says.
--
--    ALL TWELVE carry OrderCustomerAccessUserId = 100101, the BUYER. Measured on
--    DW 10.28.10: the customer-centre page grants group 1325 and the My-orders
--    scope, and nothing else, so an order stamped with the CSR (100102) or the
--    admin (100103) is invisible to every persona that can actually open the
--    page - four of the twelve were, and the order list rendered eight. CSR and
--    admin reach these orders by IMPERSONATING the buyer, which is the
--    platform's own path for it; widening the page grants to make them visible
--    would demo a permission model the platform does not use.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0001')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0001', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -62, GETDATE()), DATEADD(day, -60, GETDATE()), 195.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0001-1', 'TCO-0001', 'TCPROD0002', 'TC-VAR-0002', N'Truvio Variant Master 02', 2, 60.00, 120.00, '0', DATEADD(day, -62, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0001-2', 'TCO-0001', 'TCPROD0007', 'TC-STK-0007', N'Truvio Stock Item 07', 1, 75.00, 75.00, '0', DATEADD(day, -62, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0002')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0002', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -55, GETDATE()), DATEADD(day, -53, GETDATE()), 202.50);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0002-1', 'TCO-0002', 'TCPROD0006', 'TC-STK-0006', N'Truvio Stock Item 06', 5, 40.50, 202.50, '0', DATEADD(day, -55, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0003')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0003', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -48, GETDATE()), DATEADD(day, -46, GETDATE()), 225.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0003-1', 'TCO-0003', 'TCPROD0016', 'TC-PRC-0016', N'Truvio Price Matrix 16', 1, 45.00, 45.00, '0', DATEADD(day, -48, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0003-2', 'TCO-0003', 'TCPROD0021', 'TC-ASM-0021', N'Truvio Assortment Kit 21', 1, 0.00, 0.00, '0', DATEADD(day, -48, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0003-3', 'TCO-0003', 'TCPROD0042', 'TC-BDL-0042', N'Truvio Bundle Kit 42', 3, 60.00, 180.00, '0', DATEADD(day, -48, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0004')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0004', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -41, GETDATE()), DATEADD(day, -39, GETDATE()), 45.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0004-1', 'TCO-0004', 'TCPROD0031', 'TC-MED-0031', N'Truvio Media Set 31', 1, 45.00, 45.00, '0', DATEADD(day, -41, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0005')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0005', 1, 0, 'OS3', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -34, GETDATE()), NULL, 75.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0005-1', 'TCO-0005', 'TCPROD0013', 'TC-UOM-0013', N'Truvio Unit Conversion Service 13', 1, 75.00, 75.00, '0', DATEADD(day, -34, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0006')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0006', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -27, GETDATE()), DATEADD(day, -25, GETDATE()), 300.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0006-1', 'TCO-0006', 'TCPROD0046', 'TC-CTR-0046', N'Truvio Contract Price 46', 2, 90.00, 180.00, '0', DATEADD(day, -27, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0006-2', 'TCO-0006', 'TCPROD0047', 'TC-CTR-0047', N'Truvio Contract Price 47', 1, 120.00, 120.00, '0', DATEADD(day, -27, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0007')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0007', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -21, GETDATE()), DATEADD(day, -19, GETDATE()), 120.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0007-1', 'TCO-0007', 'TCPROD0051', 'TC-DOC-0051', N'Truvio Document Set 51', 1, 45.00, 45.00, '0', DATEADD(day, -21, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0007-2', 'TCO-0007', 'TCPROD0053', 'TC-DOC-0053', N'Truvio Document Service 53', 1, 75.00, 75.00, '0', DATEADD(day, -21, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0008')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0008', 1, 0, 'OS2', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -16, GETDATE()), DATEADD(day, -14, GETDATE()), 240.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0008-1', 'TCO-0008', 'TCPROD0036', 'TC-CUR-0036', N'Truvio Currency Matrix 36', 4, 60.00, 240.00, '0', DATEADD(day, -16, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0009')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0009', 1, 0, 'OS1', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -11, GETDATE()), NULL, 165.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0009-1', 'TCO-0009', 'TCPROD0056', 'TC-REL-0056', N'Truvio Relation Set 56', 1, 45.00, 45.00, '0', DATEADD(day, -11, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0009-2', 'TCO-0009', 'TCPROD0057', 'TC-REL-0057', N'Truvio Relation Set 57', 2, 60.00, 120.00, '0', DATEADD(day, -11, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0010')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0010', 1, 0, 'OS1', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -7, GETDATE()), NULL, 45.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0010-1', 'TCO-0010', 'TCPROD0026', 'TC-DSC-0026', N'Truvio Discount Ladder 26', 1, 45.00, 45.00, '0', DATEADD(day, -7, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0011')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0011', 1, 0, 'OS1', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -4, GETDATE()), NULL, 195.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0011-1', 'TCO-0011', 'TCPROD0011', 'TC-UOM-0011', N'Truvio Unit Measure 11', 3, 45.00, 135.00, '0', DATEADD(day, -4, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0011-2', 'TCO-0011', 'TCPROD0002', 'TC-VAR-0002', N'Truvio Variant Master 02', 1, 60.00, 60.00, '0', DATEADD(day, -4, GETDATE()));
END
IF NOT EXISTS (SELECT 1 FROM EcomOrders WHERE OrderId = 'TCO-0012')
BEGIN
    INSERT INTO EcomOrders (OrderId, OrderComplete, OrderCart, OrderStateId, OrderShopId, OrderLanguageId, OrderCurrencyCode, OrderCustomerNumber, OrderCustomerAccessUserId, OrderCustomerName, OrderCustomerEmail, OrderCustomerCompany, OrderCustomerCountryCode, OrderDate, OrderCompletedDate, OrderTotalPrice)
    VALUES ('TCO-0012', 1, 0, 'OS1', 'SHOP1', 'ENU', 'EUR', 'TC-100200', 100101, 'Truvio Buyer', 'buyer@truvio-demo.example', 'Truvio Demo Account', 'NL', DATEADD(day, -1, GETDATE()), NULL, 195.00);
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0012-1', 'TCO-0012', 'TCPROD0022', 'TC-ASM-0022', N'Truvio Assortment Scope 22', 2, 60.00, 120.00, '0', DATEADD(day, -1, GETDATE()));
    INSERT INTO EcomOrderLines (OrderLineId, OrderLineOrderId, OrderLineProductId, OrderLineProductNumber, OrderLineProductName, OrderLineQuantity, OrderLineUnitPrice, OrderLinePriceWithVAT, OrderLineType, OrderLineDate)
    VALUES ('TCO-0012-2', 'TCO-0012', 'TCPROD0018', 'TC-PRC-0018', N'Truvio Price Matrix 18', 1, 75.00, 75.00, '0', DATEADD(day, -1, GETDATE()));
END

-- ---------------------------------------------------------------------------
-- 4. Ownership convergence. Section 3 guards every order on IF NOT EXISTS, which
--    seeds correctly and repairs nothing: a host seeded before the reassignment
--    above still carries the SPLIT ownership 1.0.0 shipped - three orders on the
--    CSR (100102) and one on the admin (100103) - and the buyer's
--    /customer-center/my-orders renders 8 of 12. Measured exactly that way on
--    DW 10.28.10 after a clean re-run of this script.
--
--    So the reassignment is stated a second time as an UPDATE over the whole
--    TCO-% range, covering the customer identity block as a unit: the access-user
--    id the my-orders scope filters on, and the customer number / name / email the
--    order grids and the receipt render. Existence-guarded in this script's own
--    idiom - the guard reads the rows that DIFFER, so a host already converged is
--    not written to, and a re-run is a no-op rather than a no-change UPDATE.
-- ---------------------------------------------------------------------------
IF EXISTS (
    SELECT 1 FROM EcomOrders
     WHERE OrderId LIKE 'TCO-%'
       AND (   ISNULL(OrderCustomerAccessUserId, 0) <> 100101
            OR ISNULL(OrderCustomerNumber, '')      <> 'TC-100200'
            OR ISNULL(OrderCustomerName, '')        <> N'Truvio Buyer'
            OR ISNULL(OrderCustomerEmail, '')       <> 'buyer@truvio-demo.example')
)
    UPDATE EcomOrders
       SET OrderCustomerAccessUserId = 100101,
           OrderCustomerNumber       = 'TC-100200',
           OrderCustomerName         = N'Truvio Buyer',
           OrderCustomerEmail        = 'buyer@truvio-demo.example'
     WHERE OrderId LIKE 'TCO-%'
       AND (   ISNULL(OrderCustomerAccessUserId, 0) <> 100101
            OR ISNULL(OrderCustomerNumber, '')      <> 'TC-100200'
            OR ISNULL(OrderCustomerName, '')        <> N'Truvio Buyer'
            OR ISNULL(OrderCustomerEmail, '')       <> 'buyer@truvio-demo.example');

COMMIT TRAN;
PRINT 'Done - truvio-demo identities: account 100100, personas 100101/100102/100103, 6 memberships, 12 orders TCO-0001..TCO-0012 with 20 lines.';
