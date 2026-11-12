# Candidate baseline

Baseline target: DW 10.29.8, Swift 2.5.0, Carrot CPQ 10.24.2, Studio 0.7.0. Only the target is declared; this combination has not been proven.

Owned model tables in the compiler profile: CPQModel, CPQModelVersion, CPQGroup, CPQInput, CPQInputRule, CPQBOMRule and CPQPriceRule. Exact identities and values are in `cpq/generated/candidate.json` and `identity-map.json`. No broad table replacement is allowed. Cards, revisions, quotes, carts and documents are experiment-created, run-owned subjects on the disposable host, not rows imported from another demo.

Owned content intent is in `cpq/content-plan.json`: four neutral component products/prices and dedicated configurator/card/output bindings. The manifest does not declare a merge tree because no verified native content import is available yet. No vendor item definitions, templates or engine binaries are copied into this layer. Vendor startup must create its own schema/items/design files before the Foundry consumer applies anything.

There is no baseline database, customer fixture, installed DLL, package archive or successful host measurement in this candidate.
