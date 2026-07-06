# fixture-catalog (kind: catalog)

The gate's small deterministic shop catalog — the base ships **zero catalog** (scaffolding-only),
so this `catalog` layer supplies the products/groups/variants/prices the smoke, verify, and layer
asserts exercise. Reserved key prefixes `FIXT*` / `FIXTGRP*` / `FIXT-PRICE-*` (base contract).

**Activation is SQL-seed, not serializer YAML.** The content is the hardcoded builder
`Get-SeedFixtureCatalogSql` in `tools/harness/Invoke-SeedFixtureCatalog.ps1`; the gate activates this
layer at Step 10a0 (after the base deserialize, before the row-count assert). Seeds SHOP1/ENU/EUR:
`EcomGroups` (3, FIXTGRP1..3), `EcomProducts` (14 masters FIXT0001..0014 + 6 variant rows = 20),
`EcomVariant*` (Size), `EcomPrices` (qty-ladder on FIXT0002 + buyer contract on FIXT0001).
Counts match `config/gate-config.json` `baseline.expectedCounts` (EcomProducts 20, EcomGroups 3).
