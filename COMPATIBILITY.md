# Compatibility

A baseline is a snapshot of a database at a specific DW platform version. The
YAML carries column values for the tables and item types as they existed in that
version. Deploying into a host running a **different** platform version is the
main source of trouble, because the platform's schema can differ.

## Tested matrix

| Package | Baseline version | Captured & verified against | Engine version used |
| --- | --- | --- | --- |
| `swift` | 2.2.0 | DW 10.26.7 | Truvio.Commerce.Serializer 0.6.x |

Each package's `BASELINE.md` repeats its tested platform version in its header.
Treat that as the supported target.

## Why platform version matters: schema drift

When source and target run different platform versions, tables can gain or lose
columns. The engine tolerates a target that is *missing* columns the YAML
mentions, but the safest deployment keeps platform versions aligned. Known
drift-prone areas observed across versions:

- **Area** — legacy layout columns (`AreaHtmlType`, `AreaLayoutPhone`,
  `AreaLayoutTablet`) present in some versions, empty/absent in others.
- **EcomProducts** — legacy columns such as `ProductPeriodId`,
  `ProductVariantGroupCounter`, `ProductPriceMatrixPeriod`, `ProductOptimizedFor`.
- **EcomGroups** — `GroupPageIDRel`.

## Recommendations

1. **Match the platform version** in the tested matrix above for a deployment
   with zero schema warnings.
2. If you must deploy onto a newer platform, run the deserialize in **dry-run /
   report mode first** and review any schema-drift warnings before applying.
3. Keep the source and target on the **same** DW NuGet version when capturing a
   new baseline — see [docs/host-setup.md](docs/host-setup.md).
