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
| `swift` | 2.2 | Swift storefront (B2C/B2B commerce) | Stable (round-trip verified) |
| `digital-asset-portal` | 1.0 | Digital Asset Portal | In progress |

## What is a package?

A package is one solution at one version, living under `packages/<product>/<version>/`:

```
packages/swift/2.2/
  config/swift-2.2.json     # predicate config: what gets serialized and how
  deploy/                   # Deploy-mode YAML — source-wins structural baseline
  seed/                     # Seed-mode YAML — bootstrap content, customer-editable
  templates.manifest.yml    # template references, used for upload pre-flight
  BASELINE.md               # what's in/out and why; per-environment carve-outs
  CHANGELOG.md
```

The split into **deploy** and **seed** mirrors the engine's two deployment
modes:

- **Deploy** — developer-owned structure (site framework, item types, payment
  and shipping definitions, VAT, currencies, countries, order states, URL
  routing). On every deserialize, YAML wins and overwrites the target.
- **Seed** — bootstrap content the customer is meant to edit (starter pages,
  catalog, newsletter templates). Deserialize fills only fields the target left
  empty, so customer edits survive re-runs.

Environment-specific data (domains, secrets, payment-gateway keys, analytics
IDs) is deliberately **not** in any package — see each package's `BASELINE.md`
and [docs/package-format.md](docs/package-format.md).

## Consuming a baseline

Two supported paths. **CI/CD against the YAML is the primary path**; the
in-admin upload is the quick-start.

### 1. CI/CD (recommended) — [docs/consuming-cicd.md](docs/consuming-cicd.md)

Check this repo out in your pipeline, copy a package's `deploy/` and `seed/`
trees plus its `config/` into the target host's Serializer folder, then call the
deserialize endpoints under strict mode. Diffs are reviewable in PRs and the
same baseline promotes cleanly across dev/test/QA/prod.

### 2. In-admin Upload Package (quick-start) — [docs/consuming-upload.md](docs/consuming-upload.md)

Download a package's release `.zip` from this repo's GitHub Releases and upload
it through **Settings → Developer → Serialize → Upload Package** in DW admin. A
pre-flight gate verifies every required template exists on the target before
anything is written.

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
