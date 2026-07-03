# Contributing

This is a **curated** catalog. Baselines are authored and maintained by
JustDynamics. Pull requests are welcome — bug fixes to existing baselines, new
solutions, documentation — but every package change passes the same gate before
it merges.

## The merge gate

A change to a package under `packages/` is mergeable only when:

1. **Structure is valid.** The package has `config/<name>.json`, a `deploy/`
   tree, and a `seed/` tree. The config parses, and every predicate declares a
   valid `mode` (`Deploy` or `Seed`) and `providerType` (`Content` or
   `SqlTable`). This is checked by `.github/workflows/validate-pr.yml`.

2. **The clean-room round-trip is green.** The package deploys into a freshly
   purged CleanDB target and reaches disposition **CLOSED**: serialize and
   deserialize all return HTTP 200, zero escalations, row-count parity between
   source and target, and no orphan YAML. This is
   `tools/e2e/full-clean-roundtrip.ps1`, run against the package. It needs a
   live DW host + SQL Server, so it runs on a self-hosted runner or is attested
   by a maintainer in the PR (`.github/workflows/e2e-gate.yml`).

3. **The package is documented.** `BASELINE.md` explains the deploy/seed/
   not-serialized split and any known source-data issues; `CHANGELOG.md` records
   the change; `CATALOG.md` and `COMPATIBILITY.md` are updated if the status or
   tested platform version changed.

## Authoring a new baseline

Follow [docs/authoring-a-baseline.md](docs/authoring-a-baseline.md) end to end.
In short: clean source host → write the predicate config → capture with
`tools/capture/new-baseline.ps1` → verify with the round-trip → document → PR.

## Documentation style

Docs describe **current** behavior in the present tense. They do not narrate fix
history, previous approaches, or internal phase numbers. A reader should be able
to follow a doc without knowing how the project got here.

## Conventions

- One package per `packages/<product>/<version>/` directory.
- Distribution is `git clone` of `main`; consumers pin by commit SHA. There are
  no release zips or tags to resolve.
- Swift support is rolling latest-only: one maintained version at a time.
- Large binary inputs (bacpacs) are **not** committed — they are provided
  out-of-band and gitignored. See [docs/host-setup.md](docs/host-setup.md).
