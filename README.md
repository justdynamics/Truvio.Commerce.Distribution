# Truvio.Commerce.Serializer.Baselines

**Versioned, deploy-ready Serialized baselines for Truvio Commerce (Dynamicweb 10) — Swift, Digital Asset Portal, and more.**

This repository is the home of the *content* baselines that pair with the
[Truvio.Commerce.Serializer](https://github.com/justdynamics/Truvio.Commerce.Serializer)
engine. The engine serializes and deserializes Truvio Commerce database state
to and from YAML. This repository holds the YAML — curated, version-controlled
snapshots of complete solutions that you can deploy into a clean install to
reconstruct a known-good starting point.

> Truvio Commerce is the platform formerly known as Dynamicweb. Host binaries
> and APIs still carry the `Dynamicweb` name (e.g. `Dynamicweb.Host.Suite`); we
> use **DW** as shorthand for the platform throughout.

## Catalog

See [CATALOG.md](CATALOG.md) for the full list with status and tested platform
versions. At a glance:

| Package | Version | Solution | Status |
| --- | --- | --- | --- |
| `swift` | 2.3 | Swift storefront (B2C/B2B commerce) — scaffolding-only | Stable (round-trip verified) |
| `digital-asset-portal` | 1.0 | Digital Asset Portal | Beta (add-on to Swift) |

The Swift baseline is **scaffolding-only**: framework plus starter content and pages,
**zero sample catalog**. The demo catalog is authored per-demo (dw-demo-pim recipes).

## What is a package?

A package is one solution at one version, living under `packages/<product>/<version>/`:

```
packages/swift/2.3/
  config/swift-2.3.json     # predicate config: what gets serialized and how
  deploy/                   # Deploy-mode YAML — source-wins structural baseline
  seed/                     # Seed-mode YAML — bootstrap content, customer-editable
  BASELINE.md               # what's in/out and why; per-environment carve-outs
  INSTALL.txt               # the Management-API deserialize flow
  CHANGELOG.md
```

The split into **deploy** and **seed** mirrors the engine's two deployment
modes:

- **Deploy** — developer-owned structure (site framework, item types, payment
  and shipping definitions, VAT, currencies, countries, order states, URL
  routing). On every deserialize, YAML wins and overwrites the target.
- **Seed** — bootstrap content the customer is meant to edit (starter pages,
  newsletter templates). Deserialize fills only fields the target left empty, so
  customer edits survive re-runs. The Swift baseline's Seed tree is content-only —
  no sample catalog.

Environment-specific data (domains, secrets, payment-gateway keys, analytics
IDs) is deliberately **not** in any package — see each package's `BASELINE.md`
and [docs/package-format.md](docs/package-format.md).

## Consuming a baseline

**Clone the repo** (or sparse-checkout `packages/swift/2.3`) at the commit you
want to reproduce — there are no release zips. Copy the package's `config/`,
`deploy/` and `seed/` into the target host's Serializer folder, then call the
Management-API deserialize endpoints under strict mode: the Deploy pass, then the
Seed pass (`?mode=Seed`). See the package's [`INSTALL.txt`](packages/swift/2.3/INSTALL.txt)
and [docs/consuming-cicd.md](docs/consuming-cicd.md).

Pin reproducibility by **commit SHA** — record it in the consuming demo's
CUSTOMISATIONS.md. Diffs are reviewable in PRs and the same baseline promotes
cleanly across dev/test/QA/prod.

## Authoring or updating a baseline (maintainers)

Baselines are curated. Every package is captured from a cleaned source host and
must pass the clean-room round-trip gate before it merges. The full loop —
standing up a local host, getting the database into a clean Serialized context,
capturing, and verifying — is in:

- [docs/host-setup.md](docs/host-setup.md) — local DW host + clean database
- [docs/authoring-a-baseline.md](docs/authoring-a-baseline.md) — capture → verify → PR
- [CONTRIBUTING.md](CONTRIBUTING.md) — the merge gate and conventions

## Compatibility

Each baseline is captured and verified against a specific DW platform version.
Schema drift between platform versions is the main cross-version failure mode —
check [COMPATIBILITY.md](COMPATIBILITY.md) before deploying.

## License

MIT — see [LICENSE](LICENSE).
