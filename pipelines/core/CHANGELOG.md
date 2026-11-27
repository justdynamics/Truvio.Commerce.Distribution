# Changelog: pipelines/core

## 1.0.0 (2026-11-27)

The first release. `Deploy-Edition.ps1` delivers an edition, and a solution repository on top of it,
onto a Dynamicweb 10 host reached by address and Admin API key: plan, probe, apps, host files, layer
and solution files, settings, database configuration, indexes, verification.

Measured on blank Dynamicweb 10.30.8 hosts (stock setup wizard, Swift files removed, no Serializer),
restarted by command:

- `base-only`, the PIM-only composition: Serializer 1.0.8-beta installed, the back-office product
  repository pushed, 740 rows created across 23 replace entries and 6 updated in the merge entry,
  the product index built on both instances. The eleven row counts the edition declares read back
  from the database as declared. A second run created nothing and passed.
- `base-only` with `examples/pim-solution`: the solution's index file, its setting (read back) and
  its four completeness rules arrived, in that order.

- `swift-demo`, the storefront with sample data: 1,455 Swift release files and the layers' 494
  files pushed, 1,066 rows and documents created in the replace pass and 2,514 in the merge pass
  with none failed, the three sample personas given a password, three product indexes built. The
  database read back 97 products, 21 groups and 96 countries, as the edition declares; the five
  critical paths answered 200 and the shop page listed products.

Not measured in this release: a restart through the Dynamicweb Cloud control file, and a delivery
from a Linux agent (the plan and the composition are unit-tested on Linux).
