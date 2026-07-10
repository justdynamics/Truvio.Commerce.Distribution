# Commerce domain data (_sql) — populated at serialize/capture time

This headless baseline **reuses the commerce/PIM domain model** (D6): products, groups,
variants, prices, orders, users, facets. Those rows are NOT hand-authored here — they are
captured from the live harness host by the orchestrator's `Invoke-Serialize` pass, exactly
as the Swift baseline captures them, and written under `_sql/<Table>/<key>.yml` per the
SqlTable predicates in `config/headless-2.3.json`.

The frontend consumes this commerce data through the product/order **Delivery API**
endpoints, not through item types. Only the presentation-agnostic `Headless_*` content
(navigation, pages, customer-center) is authored as YAML in `_content/`.
