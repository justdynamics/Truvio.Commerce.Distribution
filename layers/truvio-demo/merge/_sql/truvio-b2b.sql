-- ===========================================================================
-- truvio-demo layer - the row-level B2B data
-- ===========================================================================
-- What a marine PLP row shows and a truvio row did not: a short description, a
-- stock count with a status, and - signed in - a price that is visibly the
-- buyer's rather than the list one. The parity report measured marine's own
-- answer to the last of those and found it FAKED: 22 EcomPrices rows, zero with
-- a user group, zero dealer discount rows, the anonymous GA4 payload already
-- carrying the exact figure the signed-in dealer sees. This layer is richer on
-- purpose - the discount is real data, not a template branch.
--
-- WHAT IT WRITES
--   60 short descriptions, one sentence each, every one distinct from the long
--     description above it. The PLP card reads this column; two identical
--     sentences on five cards is a worse row than no sentence at all.
--   60 stock positions on a five-step profile - healthy, low, zero-but-orderable,
--     mid, deep - so the stock component has a count to draw, a colour to change
--     and an expected-delivery date to fall back on.
--   60 stock-unit rows on the default stock location, the per-location breakdown
--     a multi-warehouse demo switches on. SHOP1 carries ShopStockLocationID = 0,
--     so the storefront reads the PRODUCT-level number today and these rows are
--     the location split beside it, summing to exactly the same figure. They are
--     seeded for the demo that turns locations on, and they can never disagree
--     with the count the page shows.
--   96 customer-group prices (60 masters + 36 variant combinations) scoped to
--     AccessUser group 1325, the base-contract group the buyer persona belongs
--     to. The combinations carry their own because a tier change that jumped the
--     buyer back to list price reads as a bug, not as a demo.
--   30 quantity-break rows: a three-step ladder on each of the ten masters that
--     carry one - six variant masters and five Price Structures masters that
--     overlap on one - and not the single ladder 1.1.x shipped.
--   6 contract prices on customer number TC-100200 - the one the layer already
--     had, plus the Contract Pricing band, which is named for the mechanism and
--     until now demonstrated none of it.
--
-- PRICE RESOLUTION, and why both group columns are not used. EcomPrices carries
-- PriceUserGroupId and PriceCustomerGroupId. The row that scopes a price to a
-- USER GROUP is PriceUserGroupId; PriceCustomerGroupId is the legacy customer
-- group and is left empty here, as the layer's contract row already leaves it.
-- Column names read off sys.columns on the DW 10.28.10 host, not inferred.
--
-- Idempotent: every row is guarded on its own key and every UPDATE on a
-- difference, so a re-run converges and a host edited by hand keeps the edit
-- only where the edit is not the thing being converged.
-- ===========================================================================
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRAN;

IF COL_LENGTH('EcomPrices', 'PriceUserGroupId') IS NULL
    RAISERROR(N'truvio-b2b.sql: EcomPrices has no PriceUserGroupId column on this platform build. A customer-group price cannot be scoped; read the live column names off sys.columns before seeding.', 16, 1);
IF COL_LENGTH('EcomProducts', 'ProductExpectedDelivery') IS NULL
    RAISERROR(N'truvio-b2b.sql: EcomProducts has no ProductExpectedDelivery column. The zero-stock rows would be orderable with no date behind them.', 16, 1);
IF NOT EXISTS (SELECT 1 FROM AccessUser WHERE AccessUserId = 1325)
    RAISERROR(N'truvio-b2b.sql: the buyer user group 1325 is missing. Every group price seeded here would resolve for nobody - a signed-in buyer would read list price and the demo would silently show nothing.', 16, 1);

-- ---------------------------------------------------------------------------
-- 1. Short descriptions. One sentence, buyer-facing, distinct per row.
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Two axes and six combinations, each with its own number, its own stock and its own price.')
    UPDATE EcomProducts SET ProductShortDescription = N'Two axes and six combinations, each with its own number, its own stock and its own price.' WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'The row a signed-in account sees at an agreed price rather than the list one.')
    UPDATE EcomProducts SET ProductShortDescription = N'The row a signed-in account sees at an agreed price rather than the list one.' WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Price steps with the tier and holds across the mode, the usual shape of an option matrix.')
    UPDATE EcomProducts SET ProductShortDescription = N'Price steps with the tier and holds across the mode, the usual shape of an option matrix.' WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A tier grid where only the top tier changes the delivery position.')
    UPDATE EcomProducts SET ProductShortDescription = N'A tier grid where only the top tier changes the delivery position.' WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'The widest grid in the band: every combination priced, none of them inherited.')
    UPDATE EcomProducts SET ProductShortDescription = N'The widest grid in the band: every combination priced, none of them inherited.' WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Healthy stock on the default location and out of the door the same day.')
    UPDATE EcomProducts SET ProductShortDescription = N'Healthy stock on the default location and out of the door the same day.' WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Deliberately low, so the card shows a count rather than a reassuring word.')
    UPDATE EcomProducts SET ProductShortDescription = N'Deliberately low, so the card shows a count rather than a reassuring word.' WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'At zero and still orderable, against a delivery date the row carries itself.')
    UPDATE EcomProducts SET ProductShortDescription = N'At zero and still orderable, against a delivery date the row carries itself.' WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Stock split across three locations, which is what a multi-warehouse read looks like.')
    UPDATE EcomProducts SET ProductShortDescription = N'Stock split across three locations, which is what a multi-warehouse read looks like.' WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A long lead time, so the delivery line rather than the count is the thing to read.')
    UPDATE EcomProducts SET ProductShortDescription = N'A long lead time, so the delivery line rather than the count is the thing to read.' WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Priced per piece and ordered in single units, the plain case.')
    UPDATE EcomProducts SET ProductShortDescription = N'Priced per piece and ordered in single units, the plain case.' WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Priced per metre, so the quantity box and the line total both read in length.')
    UPDATE EcomProducts SET ProductShortDescription = N'Priced per metre, so the quantity box and the line total both read in length.' WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A conversion service: one price, two ways of buying it.')
    UPDATE EcomProducts SET ProductShortDescription = N'A conversion service: one price, two ways of buying it.' WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Sold in a pack, so pack quantity and unit price are different numbers on one card.')
    UPDATE EcomProducts SET ProductShortDescription = N'Sold in a pack, so pack quantity and unit price are different numbers on one card.' WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Priced per kilogram against the net weight in the specification table.')
    UPDATE EcomProducts SET ProductShortDescription = N'Priced per kilogram against the net weight in the specification table.' WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A three-step quantity ladder: the price falls at five, at ten and at twenty-five.')
    UPDATE EcomProducts SET ProductShortDescription = N'A three-step quantity ladder: the price falls at five, at ten and at twenty-five.' WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'The same ladder with a steeper last step, for a buyer who orders by the pallet.')
    UPDATE EcomProducts SET ProductShortDescription = N'The same ladder with a steeper last step, for a buyer who orders by the pallet.' WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A ladder that starts at ten, so small orders all pay the same.')
    UPDATE EcomProducts SET ProductShortDescription = N'A ladder that starts at ten, so small orders all pay the same.' WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A flat price with no break at all, the control the other four are read against.')
    UPDATE EcomProducts SET ProductShortDescription = N'A flat price with no break at all, the control the other four are read against.' WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A ladder and an account price at once, so the narrower of the two wins.')
    UPDATE EcomProducts SET ProductShortDescription = N'A ladder and an account price at once, so the narrower of the two wins.' WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A configurable kit: pick one component from each slot and the price follows.')
    UPDATE EcomProducts SET ProductShortDescription = N'A configurable kit: pick one component from each slot and the price follows.' WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Inside the account assortment, so a signed-in buyer sees it and an anonymous one does not.')
    UPDATE EcomProducts SET ProductShortDescription = N'Inside the account assortment, so a signed-in buyer sees it and an anonymous one does not.' WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'In the open catalogue, visible to everyone, the comparison row for the band.')
    UPDATE EcomProducts SET ProductShortDescription = N'In the open catalogue, visible to everyone, the comparison row for the band.' WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Scoped to one named account, the narrowest assortment the platform allows.')
    UPDATE EcomProducts SET ProductShortDescription = N'Scoped to one named account, the narrowest assortment the platform allows.' WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'In two assortments at once, which is how overlapping scopes resolve.')
    UPDATE EcomProducts SET ProductShortDescription = N'In two assortments at once, which is how overlapping scopes resolve.' WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Carries an account discount off list, so the page shows both numbers.')
    UPDATE EcomProducts SET ProductShortDescription = N'Carries an account discount off list, so the page shows both numbers.' WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Discounted to a round figure rather than by a percentage.')
    UPDATE EcomProducts SET ProductShortDescription = N'Discounted to a round figure rather than by a percentage.' WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'The deepest discount in the band, and the widest gap between list and yours.')
    UPDATE EcomProducts SET ProductShortDescription = N'The deepest discount in the band, and the widest gap between list and yours.' WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'No discount at all: list price signed in and signed out alike.')
    UPDATE EcomProducts SET ProductShortDescription = N'No discount at all: list price signed in and signed out alike.' WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Discount and quantity ladder together, so the ladder starts from the agreed price.')
    UPDATE EcomProducts SET ProductShortDescription = N'Discount and quantity ladder together, so the ladder starts from the agreed price.' WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'The full gallery: concept tile, photographic frame and a detail shot.')
    UPDATE EcomProducts SET ProductShortDescription = N'The full gallery: concept tile, photographic frame and a detail shot.' WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Leads with the photographic frame, so the card and the page do not open alike.')
    UPDATE EcomProducts SET ProductShortDescription = N'Leads with the photographic frame, so the card and the page do not open alike.' WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Two images only, the shortest gallery the thumbnail strip still draws.')
    UPDATE EcomProducts SET ProductShortDescription = N'Two images only, the shortest gallery the thumbnail strip still draws.' WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Shares its photographic frame with the band, which is how a range reads as a range.')
    UPDATE EcomProducts SET ProductShortDescription = N'Shares its photographic frame with the band, which is how a range reads as a range.' WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A flat tile and a lit frame together, the two registers a catalogue mixes.')
    UPDATE EcomProducts SET ProductShortDescription = N'A flat tile and a lit frame together, the two registers a catalogue mixes.' WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Standard VAT group, so the storefront figure is the one with tax in it.')
    UPDATE EcomProducts SET ProductShortDescription = N'Standard VAT group, so the storefront figure is the one with tax in it.' WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Reduced VAT group, where a catalogue with mixed rates starts to matter.')
    UPDATE EcomProducts SET ProductShortDescription = N'Reduced VAT group, where a catalogue with mixed rates starts to matter.' WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Priced in the default currency and read in the served one.')
    UPDATE EcomProducts SET ProductShortDescription = N'Priced in the default currency and read in the served one.' WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Carries an explicit price per currency rather than a converted one.')
    UPDATE EcomProducts SET ProductShortDescription = N'Carries an explicit price per currency rather than a converted one.' WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Zero-rated, so the figures with and without tax are the same.')
    UPDATE EcomProducts SET ProductShortDescription = N'Zero-rated, so the figures with and without tax are the same.' WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A fixed kit: the same members for every buyer, priced as one line.')
    UPDATE EcomProducts SET ProductShortDescription = N'A fixed kit: the same members for every buyer, priced as one line.' WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Binds a group rather than a product, so the buyer picks the member.')
    UPDATE EcomProducts SET ProductShortDescription = N'Binds a group rather than a product, so the buyer picks the member.' WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Names a default member and allows the swap, the middle ground between the two.')
    UPDATE EcomProducts SET ProductShortDescription = N'Names a default member and allows the swap, the middle ground between the two.' WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'One required slot and one optional, so the page shows what can be dropped.')
    UPDATE EcomProducts SET ProductShortDescription = N'One required slot and one optional, so the page shows what can be dropped.' WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Related to its members both ways, so a member page points back at the kit.')
    UPDATE EcomProducts SET ProductShortDescription = N'Related to its members both ways, so a member page points back at the kit.' WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'An agreed price against the demo account, below list on every quantity.')
    UPDATE EcomProducts SET ProductShortDescription = N'An agreed price against the demo account, below list on every quantity.' WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Priced by customer group, which is how a whole dealer tier gets one rate.')
    UPDATE EcomProducts SET ProductShortDescription = N'Priced by customer group, which is how a whole dealer tier gets one rate.' WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Carries both, so the narrower customer-number price wins.')
    UPDATE EcomProducts SET ProductShortDescription = N'Carries both, so the narrower customer-number price wins.' WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'An agreement with a validity window, the shape of a seasonal rate.')
    UPDATE EcomProducts SET ProductShortDescription = N'An agreement with a validity window, the shape of a seasonal rate.' WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'No agreement: list price signed in and signed out, the control row.')
    UPDATE EcomProducts SET ProductShortDescription = N'No agreement: list price signed in and signed out, the control row.' WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Datasheet and install guide, both downloadable from the page.')
    UPDATE EcomProducts SET ProductShortDescription = N'Datasheet and install guide, both downloadable from the page.' WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Datasheet held at a named revision, which is what the revision column is for.')
    UPDATE EcomProducts SET ProductShortDescription = N'Datasheet held at a named revision, which is what the revision column is for.' WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A documented procedure rather than an object, rendered in the same table.')
    UPDATE EcomProducts SET ProductShortDescription = N'A documented procedure rather than an object, rendered in the same table.' WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Shares its install guide with the band, the way a range documents a common fitting.')
    UPDATE EcomProducts SET ProductShortDescription = N'Shares its install guide with the band, the way a range documents a common fitting.' WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A certificate beside the datasheet, so compliance is answered on the page.')
    UPDATE EcomProducts SET ProductShortDescription = N'A certificate beside the datasheet, so compliance is answered on the page.' WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Related to three accessories, which is what the you-will-also-need strip is built from.')
    UPDATE EcomProducts SET ProductShortDescription = N'Related to three accessories, which is what the you-will-also-need strip is built from.' WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Related to its spares, so an owner can reorder a part without searching.')
    UPDATE EcomProducts SET ProductShortDescription = N'Related to its spares, so an owner can reorder a part without searching.' WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Related to an alternative in the same band, the substitute a catalogue offers.')
    UPDATE EcomProducts SET ProductShortDescription = N'Related to an alternative in the same band, the substitute a catalogue offers.' WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'A kit member that points back at its kit, so the relation reads from both ends.')
    UPDATE EcomProducts SET ProductShortDescription = N'A kit member that points back at its kit, so the relation reads from both ends.' WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '' AND ProductLanguageId = 'ENU' AND ISNULL(ProductShortDescription, N'') <> N'Relations in two groups at once, so the page draws two strips rather than one.')
    UPDATE EcomProducts SET ProductShortDescription = N'Relations in two groups at once, so the page draws two strips rather than one.' WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';

-- ---------------------------------------------------------------------------
-- 2. Stock. A five-step profile, so the component has every state to draw.
--    A service row (ProductType 1) and the BOM parent (ProductType 2) keep
--    never-out-of-stock: Swift gates the stock component on ProductType = stock,
--    and a service showing a shelf count is wrong on the page, not merely odd.
-- ---------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0002' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0003' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0004' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0005' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0006' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0007' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0008' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0009' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0010' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0012' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0013' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0014' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0015' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0021' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0022' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0023' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0024' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0025' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0026' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0027' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0028' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0029' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0030' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0032' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0033' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0034' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0035' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0036' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0037' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0038' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0039' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0040' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0042' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0043' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0044' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0045' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0052' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0053' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0054' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0055' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '' AND (ProductStock <> 148 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 148, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0056' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '' AND (ProductStock <> 12 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 12, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0057' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '' AND (ProductStock <> 0 OR ProductNeverOutOfStock <> 1))
    UPDATE EcomProducts SET ProductStock = 0, ProductNeverOutOfStock = 1, ProductExpectedDelivery = DATEADD(day, 14, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0058' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '' AND (ProductStock <> 64 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 64, ProductNeverOutOfStock = 0, ProductExpectedDelivery = NULL WHERE ProductId = 'TCPROD0059' AND ProductVariantId = '';
IF EXISTS (SELECT 1 FROM EcomProducts WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '' AND (ProductStock <> 320 OR ProductNeverOutOfStock <> 0))
    UPDATE EcomProducts SET ProductStock = 320, ProductNeverOutOfStock = 0, ProductExpectedDelivery = DATEADD(day, 21, CAST(GETDATE() AS date)) WHERE ProductId = 'TCPROD0060' AND ProductVariantId = '';

-- The per-location breakdown, on the default stock location. See the header: the
-- storefront reads the product-level number while ShopStockLocationID = 0, and
-- these rows carry the same figure so the two can never disagree.
DECLARE @TcDefaultStockLocation BIGINT = (SELECT TOP 1 StockLocationId FROM EcomStockLocation ORDER BY CASE WHEN StockLocationName LIKE N'Default%' THEN 0 ELSE 1 END, StockLocationId);
IF @TcDefaultStockLocation IS NULL
    RAISERROR(N'truvio-b2b.sql: EcomStockLocation is empty. There is no location to break the demo stock down against.', 16, 1);
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0001' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0001', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-VAR-0001');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0002' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0002', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-VAR-0002');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0003' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0003', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-VAR-0003');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0004' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0004', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-VAR-0004');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0005' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0005', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-VAR-0005');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0006' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0006', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-STK-0006');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0007' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0007', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-STK-0007');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0008' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0008', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-STK-0008');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0009' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0009', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-STK-0009');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0010' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0010', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-STK-0010');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0011' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0011', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-UOM-0011');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0012' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0012', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-UOM-0012');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0013' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0013', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-UOM-0013');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0014' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0014', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-UOM-0014');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0015' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0015', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-UOM-0015');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0016' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0016', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-PRC-0016');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0017' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0017', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-PRC-0017');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0018' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0018', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-PRC-0018');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0019' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0019', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-PRC-0019');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0020' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0020', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-PRC-0020');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0021' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0021', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-ASM-0021');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0022' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0022', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-ASM-0022');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0023' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0023', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-ASM-0023');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0024' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0024', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-ASM-0024');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0025' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0025', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-ASM-0025');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0026' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0026', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DSC-0026');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0027' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0027', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DSC-0027');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0028' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0028', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-DSC-0028');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0029' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0029', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DSC-0029');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0030' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0030', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DSC-0030');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0031' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0031', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-MED-0031');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0032' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0032', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-MED-0032');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0033' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0033', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-MED-0033');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0034' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0034', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-MED-0034');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0035' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0035', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-MED-0035');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0036' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0036', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CUR-0036');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0037' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0037', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CUR-0037');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0038' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0038', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-CUR-0038');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0039' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0039', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CUR-0039');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0040' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0040', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CUR-0040');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0041' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0041', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-BDL-0041');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0042' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0042', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-BDL-0042');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0043' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0043', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-BDL-0043');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0044' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0044', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-BDL-0044');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0045' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0045', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-BDL-0045');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0046' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0046', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CTR-0046');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0047' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0047', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CTR-0047');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0048' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0048', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-CTR-0048');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0049' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0049', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CTR-0049');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0050' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0050', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-CTR-0050');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0051' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0051', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DOC-0051');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0052' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0052', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DOC-0052');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0053' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0053', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-DOC-0053');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0054' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0054', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DOC-0054');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0055' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0055', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-DOC-0055');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0056' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0056', '', '', 148, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-REL-0056');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0057' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0057', '', '', 12, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-REL-0057');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0058' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0058', '', '', 0, @TcDefaultStockLocation, 1, 0, 0, 0, 'TC-REL-0058');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0059' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0059', '', '', 64, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-REL-0059');
IF NOT EXISTS (SELECT 1 FROM EcomStockUnit WHERE StockUnitProductId = 'TCPROD0060' AND StockUnitVariantId = '' AND StockUnitStockLocationId = @TcDefaultStockLocation)
    INSERT INTO EcomStockUnit (StockUnitProductId, StockUnitVariantId, StockUnitId, StockUnitQuantity, StockUnitStockLocationId, StockUnitNeverOutOfStock, StockUnitWidth, StockUnitHeight, StockUnitDepth, StockUnitProductNumber) VALUES ('TCPROD0060', '', '', 320, @TcDefaultStockLocation, 0, 0, 0, 0, 'TC-REL-0060');

-- ---------------------------------------------------------------------------
-- 3. The customer-group price. THIS is where truvio goes past marine: a real
--    PriceUserGroupId row on every master, at a figure a buyer can see is below
--    the list price beside it. Four of every five rows discount; the fifth is
--    priced at list on purpose, so the demo has a control and the discount is
--    read as data rather than as a styling rule.
-- ---------------------------------------------------------------------------
DECLARE @TcList TABLE (prod NVARCHAR(60) PRIMARY KEY, factor DECIMAL(5,4));
INSERT INTO @TcList (prod, factor) VALUES ('TCPROD0001', 0.8800), ('TCPROD0002', 0.8500), ('TCPROD0003', 0.8000), ('TCPROD0004', 1.0000),
                                     ('TCPROD0005', 0.9000), ('TCPROD0006', 0.8800), ('TCPROD0007', 0.8500), ('TCPROD0008', 0.8000),
                                     ('TCPROD0009', 1.0000), ('TCPROD0010', 0.9000), ('TCPROD0011', 0.8800), ('TCPROD0012', 0.8500),
                                     ('TCPROD0013', 0.8000), ('TCPROD0014', 1.0000), ('TCPROD0015', 0.9000), ('TCPROD0016', 0.8800),
                                     ('TCPROD0017', 0.8500), ('TCPROD0018', 0.8000), ('TCPROD0019', 1.0000), ('TCPROD0020', 0.9000),
                                     ('TCPROD0021', 0.8800), ('TCPROD0022', 0.8500), ('TCPROD0023', 0.8000), ('TCPROD0024', 1.0000),
                                     ('TCPROD0025', 0.9000), ('TCPROD0026', 0.8800), ('TCPROD0027', 0.8500), ('TCPROD0028', 0.8000),
                                     ('TCPROD0029', 1.0000), ('TCPROD0030', 0.9000), ('TCPROD0031', 0.8800), ('TCPROD0032', 0.8500),
                                     ('TCPROD0033', 0.8000), ('TCPROD0034', 1.0000), ('TCPROD0035', 0.9000), ('TCPROD0036', 0.8800),
                                     ('TCPROD0037', 0.8500), ('TCPROD0038', 0.8000), ('TCPROD0039', 1.0000), ('TCPROD0040', 0.9000),
                                     ('TCPROD0041', 0.8800), ('TCPROD0042', 0.8500), ('TCPROD0043', 0.8000), ('TCPROD0044', 1.0000),
                                     ('TCPROD0045', 0.9000), ('TCPROD0046', 0.8800), ('TCPROD0047', 0.8500), ('TCPROD0048', 0.8000),
                                     ('TCPROD0049', 1.0000), ('TCPROD0050', 0.9000), ('TCPROD0051', 0.8800), ('TCPROD0052', 0.8500),
                                     ('TCPROD0053', 0.8000), ('TCPROD0054', 1.0000), ('TCPROD0055', 0.9000), ('TCPROD0056', 0.8800),
                                     ('TCPROD0057', 0.8500), ('TCPROD0058', 0.8000), ('TCPROD0059', 1.0000), ('TCPROD0060', 0.9000);

-- Derived from the product's OWN list price rather than typed, so a price edited
-- above can never leave a group price stranded above the figure it discounts.
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
SELECT 'TC-PRICE-GRP-' + RIGHT(p.ProductId, 4), p.ProductId, '', 'EUR', 1,
       ROUND(p.ProductPrice * t.factor, 2), '', '', '1325'
  FROM EcomProducts p JOIN @TcList t ON t.prod = p.ProductId
 WHERE p.ProductVariantId = '' AND p.ProductLanguageId = 'ENU'
   AND NOT EXISTS (SELECT 1 FROM EcomPrices x WHERE x.PriceId = 'TC-PRICE-GRP-' + RIGHT(p.ProductId, 4));
UPDATE g SET g.PriceAmount = ROUND(p.ProductPrice * t.factor, 2)
  FROM EcomPrices g
  JOIN EcomProducts p ON p.ProductId = g.PriceProductId AND p.ProductVariantId = '' AND p.ProductLanguageId = 'ENU'
  JOIN @TcList t ON t.prod = p.ProductId
 WHERE g.PriceId LIKE 'TC-PRICE-GRP-%' AND g.PriceProductVariantId = ''
   AND g.PriceAmount <> ROUND(p.ProductPrice * t.factor, 2);

-- And the same discount on every variant combination, keyed off that
-- combination's own price row, so choosing a tier moves the buyer's figure
-- rather than throwing it back to list.
INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
SELECT 'TC-PRICE-GRPV-' + CAST(v.PriceAutoId AS NVARCHAR(20)), v.PriceProductId, v.PriceProductVariantId, v.PriceCurrency, 1,
       ROUND(v.PriceAmount * t.factor, 2), '', '', '1325'
  FROM EcomPrices v JOIN @TcList t ON t.prod = v.PriceProductId
 WHERE v.PriceId LIKE 'TC-PRICE-VAR-%' AND v.PriceProductVariantId <> ''
   AND NOT EXISTS (SELECT 1 FROM EcomPrices x WHERE x.PriceId = 'TC-PRICE-GRPV-' + CAST(v.PriceAutoId AS NVARCHAR(20)));

-- ---------------------------------------------------------------------------
-- 4. Quantity ladders. 1.1.x shipped ONE, on a single product, so the price
--    table had a subject on exactly one page in sixty. Every variant master and
--    every Price Structures master now carries a three-step ladder.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0001')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0001', 'TCPROD0001', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0001')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0001', 'TCPROD0001', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0001')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0001', 'TCPROD0001', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0001' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0011')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0011', 'TCPROD0011', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0011')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0011', 'TCPROD0011', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0011')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0011', 'TCPROD0011', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0011' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0016')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0016', 'TCPROD0016', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0016')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0016', 'TCPROD0016', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0016')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0016', 'TCPROD0016', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0016' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0017')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0017', 'TCPROD0017', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0017')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0017', 'TCPROD0017', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0017')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0017', 'TCPROD0017', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0017' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0018')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0018', 'TCPROD0018', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0018')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0018', 'TCPROD0018', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0018')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0018', 'TCPROD0018', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0018' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0019')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0019', 'TCPROD0019', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0019')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0019', 'TCPROD0019', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0019')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0019', 'TCPROD0019', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0019' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0020')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0020', 'TCPROD0020', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0020')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0020', 'TCPROD0020', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0020')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0020', 'TCPROD0020', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0020' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0031')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0031', 'TCPROD0031', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0031')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0031', 'TCPROD0031', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0031')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0031', 'TCPROD0031', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0031' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0041')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0041', 'TCPROD0041', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0041')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0041', 'TCPROD0041', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0041')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0041', 'TCPROD0041', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0041' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q05-0051')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q05-0051', 'TCPROD0051', '', 'EUR', 5, ROUND(ProductPrice * 0.90, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q10-0051')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q10-0051', 'TCPROD0051', '', 'EUR', 10, ROUND(ProductPrice * 0.80, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-Q25-0051')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-Q25-0051', 'TCPROD0051', '', 'EUR', 25, ROUND(ProductPrice * 0.70, 2), '', '', '' FROM EcomProducts WHERE ProductId = 'TCPROD0051' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';

-- ---------------------------------------------------------------------------
-- 5. Contract prices. The layer already had one, on a Variants row; the band
--    NAMED for the mechanism had none. Resolved by customer number, never by a
--    group column - so these are strictly narrower than section 3 and win.
-- ---------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CTR-0046')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-CTR-0046', 'TCPROD0046', '', 'EUR', 1, ROUND(ProductPrice * 0.82, 2), '', 'TC-100200', '' FROM EcomProducts WHERE ProductId = 'TCPROD0046' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CTR-0047')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-CTR-0047', 'TCPROD0047', '', 'EUR', 1, ROUND(ProductPrice * 0.78, 2), '', 'TC-100200', '' FROM EcomProducts WHERE ProductId = 'TCPROD0047' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CTR-0048')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-CTR-0048', 'TCPROD0048', '', 'EUR', 1, ROUND(ProductPrice * 0.75, 2), '', 'TC-100200', '' FROM EcomProducts WHERE ProductId = 'TCPROD0048' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CTR-0049')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-CTR-0049', 'TCPROD0049', '', 'EUR', 1, ROUND(ProductPrice * 0.80, 2), '', 'TC-100200', '' FROM EcomProducts WHERE ProductId = 'TCPROD0049' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CTR-0050')
    INSERT INTO EcomPrices (PriceId, PriceProductId, PriceProductVariantId, PriceCurrency, PriceQuantity, PriceAmount, PriceCustomerGroupId, PriceUserCustomerNumber, PriceUserGroupId)
    SELECT 'TC-PRICE-CTR-0050', 'TCPROD0050', '', 'EUR', 1, ROUND(ProductPrice * 0.85, 2), '', 'TC-100200', '' FROM EcomProducts WHERE ProductId = 'TCPROD0050' AND ProductVariantId = '' AND ProductLanguageId = 'ENU';
IF NOT EXISTS (SELECT 1 FROM EcomPrices WHERE PriceId = 'TC-PRICE-CONTRACT')
    RAISERROR(N'truvio-b2b.sql: the original contract price TC-PRICE-CONTRACT is gone. It is the row the signed-in proof has always cited; it is kept, never replaced.', 16, 1);

-- ---------------------------------------------------------------------------
-- THE RESOLUTION GUARD. Counting rows proves nothing: the question is whether a
-- signed-in buyer's price is BELOW the list price on the same row, which is the
-- only thing the page can show. Asserted along the path the platform walks -
-- product -> group price scoped to a group the buyer is actually a member of.
-- ---------------------------------------------------------------------------
DECLARE @TcVisibleDiscounts INT = (
    SELECT COUNT(*)
      FROM EcomPrices g
      JOIN EcomProducts p ON p.ProductId = g.PriceProductId AND p.ProductVariantId = '' AND p.ProductLanguageId = 'ENU'
     WHERE g.PriceUserGroupId = '1325' AND g.PriceProductVariantId = ''
       AND g.PriceAmount < p.ProductPrice
       AND EXISTS (SELECT 1 FROM AccessUserGroupRelation r
                    WHERE r.AccessUserGroupRelationGroupId = 1325
                      AND r.AccessUserGroupRelationUserId = 100101));
IF @TcVisibleDiscounts < 40
    RAISERROR(N'truvio-b2b.sql: fewer than 40 masters price BELOW list for the buyer persona. Either the group prices did not land, or the persona is not in the group they are scoped to - and in both cases a signed-in demo shows the same number an anonymous one does, silently.', 16, 1);

COMMIT TRAN;
PRINT 'Done - truvio-demo B2B rows: 60 short descriptions, 60 stock positions + 60 stock-unit rows, 96 customer-group prices (60 masters + 36 combinations), 30 quantity-break rows across 10 masters, 5 new contract prices beside the one the layer already had, and the buyer-below-list guard green.';
