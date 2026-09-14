# Changelog — feature-pricing

## 1.1.3

Both `cart-price` probes move onto the brand catalogue, and the tier probe gets a stronger
expected value. The subject moves from a row the sample-data layer used to ship as a marker-string fixture to a row of the browsable brand catalogue, and the probe now binds to a subject the base contract guarantees (`base.contract.json` `sampleData.guaranteedRows`, new in base 3.5.0) rather than to a layer. sample-data 4.0.0 is the merge of the two sample-data layers; the `gate-fixtures` edition is deleted and `swift-demo` sets `sampleData: true`, so this probe resolves in the demo edition itself.

**Tier probe: `PACK-RPP-PROD1` qty 5 / 4500 becomes `TCPROD0020` qty 10 / 96.** The arithmetic.
`TCPROD0020` ships a 120.00 list price (`TC-PRICE-LIST-0020`), a customer-group row
`TC-PRICE-GRP-0020` at **108.00 for group 1325 at quantity 1**, and the ladder
`TC-PRICE-Q05-0020` 108.00 at 5, `TC-PRICE-Q10-0020` 96.00 at 10, `TC-PRICE-Q25-0020` 84.00 at 25.
The `cart-price` kind signs in as the buyer, and the buyer is a member of 1325, so the
customer-group row is in scope for every rung. At quantity 5 the expected amount would be 108.00
whether the tier ladder fired or not, which is a vacuous assert. Quantity 10 is the first rung the
group row cannot produce: 96.00 is reachable only through `TC-PRICE-Q10-0020`, so the observed
amount proves the ladder and not price resolution in general. Quantity 25 / 84.00 would prove the
same thing; 10 is chosen because it is the middle rung and the cheapest cart to build.

**Contract probe: `PACK-RPP-PROD2` qty 1 / 1399 becomes `TCPROD0046` qty 1 / 36.90.**
`TC-PRICE-CTR-0046` carries 36.90 scoped by `PriceUserCustomerNumber` `TC-100200`, the demo
account every persona belongs to, against a 45.00 list and a 39.60 customer-group row. All three
amounts are distinct, so a cart charging the group or the list price fails loudly with the observed
figure. This is still the zero-code headline: Dynamicweb's stock `DefaultPriceProvider` resolves and
charges it with no compile.

`customCode.withoutCompile` and `customCode.withCompile` are rewritten onto the same rows: without
the provider a tiered cart charges the customer-group price, with it `TCPROD0020` charges
108 / 96 / 84 at 5 / 10 / 25. The provider source is unchanged.

## 1.1.2

Every probe and criticalPath moves from the `/swift-2/` area segment to the `/en-us/` culture root (Foundry #965). `AreaUrlName` `swift-2` is decorative on a single-area host: Dynamicweb prefixes the area segment only when more than one area competes for the host and otherwise serves the culture segment, so every `/swift-2/` path answered 404 on a healthy, fully deserialized site while the same pages answered under `/en-us/`. Page targets are unchanged; only the prefix moves. The cart target is `/en-us/cart/`: `Shopping cart` is a non-clickable folder with `urlIgnoreForChildren`, so its `Cart` page resolves without the folder segment. README probe tables follow.

## 1.1.1

**The discount engine is shipped switched on (Foundry 1048).**
`files/System/Truvio/globalsettings.commerce.fragment.config` carries the New Discount Experience
activation block verbatim, with its apply and proof steps in-file.

Two discount engines coexist. The legacy one reads `EcomDiscount`; the new one — the engine the
admin Discounts screen renders and every adjustment verb writes — reads `EcomDiscounts`, and only
once the feature is activated. The baseline shipped no activation block, so three group net tiers
were created, conditioned on the right user groups, rewarded with the right percentages, active in
the database and correct on read-back, and the signed-in cart charged full list price for every one
of them. A customer-number contract price in the same cart resolved correctly, which makes the
failure look like a discount configured wrong rather than an engine switched off.

It ships as a **fragment**, not as a settings file: a layer's `files/` overlay is overwrite-wins with
no merge step, so shipping a whole `GlobalSettings.config` would replace the host's database
connection, mail server and licence configuration. The file's only job is to be copied out of, into
the host's own `<Features>` element, followed by a restart.

The base was the first candidate and was rejected: it ships no GlobalSettings fragments at all, so
there is no shape to follow there, and inventing one on the privileged content-free singleton for a
single feature flag is the wrong trade. This is the layer whose subject is price and discount
resolution, so the precondition travels with it.

Recorded for anyone validating it: a read-back of the discount, its conditions and its rewards is
not evidence — it passes on a dormant engine. The only proof is the discounted amount in a rendered
cart.

## 1.1.0

**Zero catalogue rows (Foundry 960).** The two demo products (`PACK-RPP-PROD1/2`), their group
(`PACK-RPP-GRP1`), the group and shop relations and all four `EcomPrices` rows moved to the
`sample-data` layer (`merge/_sql/feature-fixtures.sql`), ids unchanged. This layer's whole merge
tree went with them, so `fragmentModes`, `fragmentTables` and the six catalogue `configRows` are
gone from `layer.json`: what remains is the compile-optional price provider and the two `cart-price`
probes, which address the same product ids as before.

Why the rows could not stay: `sampleData: false` is the distribution's statement that the shop is
empty, and a layer that ships catalogue rows outside that toggle makes the statement false without
the gate being able to say which layer did it. Self-sufficiency was a real argument — the base
ships no catalogue — but it bought a per-layer catalogue at the cost of the one invariant every
consumer reads.

## 1.0.0

Initial release. Split out of `feature-reordering-pricing@1.2.1` (P3 feature surgery,
RUN-DISTRIBUTION-QUALITY decision D-D) as the **pricing half**:

- **Moved verbatim from the combined layer:** the `customCode` block, `csLedger`, the
  six `configRows`, `src/ReorderingPricingQtyBreakProvider.cs`, and all
  `merge/_sql/PACK-RPP-*` rows (group `PACK-RPP-GRP1`, products `PACK-RPP-PROD1/PROD2`,
  their group/shop relations, and `EcomPrices` `PACK-RPP-0001..0004`). Keys unchanged so
  the provider, tier ladder, and contract row behave identically.
- **`cart-price` probes re-pointed:** both moved off `/swift-2/quick-order` (the reordering
  layer's Quick Order page) onto **`/swift-2/cart/`** — the last coupling between the two
  split layers, and only ever a test-authoring convenience. Contract/tier pricing resolves
  on any add-to-cart surface; `/swift-2/cart/` is provided by surface-swift in every edition.
- **Dropped (moved to `feature-reordering`):** the Quick Order pad item type + template + page
  fragment, the `http-body-contains` / `sku-validation` probes, and the `fragmentContent` +
  `knownCycleLimitations`. This layer ships **no content** — SQL rows + provider only.

`swiftVersion` claim 2.4.0; proven on the `swift-demo` edition (see the RUN-DISTRIBUTION-QUALITY
P3 gate stamp). Contract price 1399 charged uncompiled; tier 4500@qty5 charged when compiled.
