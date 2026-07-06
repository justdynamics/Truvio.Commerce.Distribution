# Contributing

This is a **curated** distribution, authored and maintained by JustDynamics. Pull
requests are welcome — layer fixes, new layers, new editions, documentation — but every
change passes the same gate before it merges. See [GLOSSARY.md](GLOSSARY.md) for the
vocabulary and [LAYERS.md](LAYERS.md) for the catalog.

## The merge gate

A change to `layers/` or `editions/` is mergeable only when both hold:

1. **The structural gate is green (machine-enforced).**
   [`.github/workflows/validate.yml`](.github/workflows/validate.yml) runs
   [`tools/ci/Validate-Distribution.ps1`](tools/ci/Validate-Distribution.ps1) on every PR:
   - every `layers/<name>/layer.json` validates against `layers/layer.schema.json`, and its
     `name` equals the directory name;
   - every `editions/<name>.json` validates against `editions/edition.schema.json`, and its
     `from` / `add` / `surfaces` refs resolve to a `layers/<name>` whose version matches the
     pinned semver; `themes[]` resolve to `layers/theme-<name>`;
   - `layers/base/base.contract.json` parses; no two non-base layers ship the same
     `_sql/<Table>/<key>.yml` (silent-collision guard);
   - the protected-string guard passes (the layer/mode vocabulary never leaked into a
     DW/Swift identifier or path); theme layers carry no serialized content (SPEC-06).

2. **The clean-room roundtrip is attested (operator step).** The deep proof — a layer or
   edition deserializes cleanly on the current latest Swift with row-count parity and zero
   strict-mode escalations — runs in the **Foundry** harness
   (`Truvio.Commerce.Serializer.BaselineUpdater`), not on a hosted runner (it needs a live
   DW host + SQL Server). The maintainer runs `gate.ps1 -Edition <name>` and records the
   run id in the PR. A layer that cannot pass ships **Beta**, flagged in its `BASELINE.md`
   with the promote-out path (see `layers/dap-portal`).

## Authoring

Layers are produced and proven in the Foundry harness, then published here. A new layer
carries a `layer.json` (correct `kind`), its `replace/`+`merge/` mode trees and/or a
`files/` overlay, and a `BASELINE.md`. A new edition is a `editions/<name>.json`
composition whose refs resolve. Run `tools/ci/Validate-Distribution.ps1` locally before
opening the PR.

## Conventions

- One layer per `layers/<name>/` directory; one edition per `editions/<name>.json`.
- **Git-clone distribution** of `main` — no release archives. Each proven artifact is
  pinned by an annotated tag `layers/<name>/<semver>` / `editions/<name>/<semver>` carrying
  the gate run id + Swift version; consumers pin by tag or commit SHA.
- Modes are `replace` / `merge` everywhere (never `deploy` / `seed`).
- Swift support is **rolling latest-only** — one maintained version at a time.
- Large binary inputs (bacpacs, DBs) are **not** committed.
- Docs describe **current** behavior in the present tense — no fix history or phase numbers.
