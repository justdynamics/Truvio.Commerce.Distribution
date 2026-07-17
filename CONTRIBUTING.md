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
     pinned semver; `themes[]` resolve to `layers/theme-<name>` (kind theme);
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

## Composition policy — when an improvement becomes a NEW layer

Not every improvement earns its own layer; each new layer multiplies gate cost (editions ×
themes × asserts). A change becomes a **new layer only when ALL THREE** hold —
otherwise it **folds** into an existing layer (the base contract, an existing theme, or a
feature layer):

1. **Consumer optionality** — a consumer can meaningfully choose to take it or leave it.
2. **Independent lifecycle** — it versions and ships on its own cadence, not lock-stepped to another layer.
3. **Own files/data surface** — it owns a distinct `files/` and/or serialized-content surface, not a handful of edits to someone else's.

Fail any one → fold it in. The naming follows the kind (`feature-*`, `surface-*`,
`theme-*`); see [LAYERS.md](LAYERS.md) for the prefix→lane table. Presentation
improvements fold into `theme-default` — the distribution ships one theme, and a
customer re-skin starts from it.

Gate cost is tracked as a **KPI trend only** (gate cost per edition, in the Foundry's
`docs/KPI.md`) — there is no per-publish leg budget; the constraint ranking triggers action,
not a fixed threshold.

## Authoring

Layers are produced and proven in the Foundry harness, then published here. A new layer
carries a `layer.json` (correct `kind`), its `replace/`+`merge/` mode trees and/or a
`files/` overlay, and a `BASELINE.md`. A new edition is a `editions/<name>.json`
composition whose refs resolve. Run `tools/ci/Validate-Distribution.ps1` locally before
opening the PR.

## Conventions

- One layer per `layers/<name>/` directory; one edition per `editions/<name>.json`.
- **Git-clone distribution** of `main` — no release archives. **Consumers pin `origin/main`
  (`git pull --ff-only`) — main IS the version.** Annotated tags `layers/<name>/<semver>` /
  `editions/<name>/<semver>` (carrying the gate run id + Swift version) are **provenance-only**
  audit history, **cut automatically by CI** ([`.github/workflows/release-tags.yml`](.github/workflows/release-tags.yml))
  on merge to main — never a re-consumable frozen pin, never cut by hand. Rolling-latest-only
  means there is no supported old state to re-materialize; forensic reproducibility is the
  resolved commit SHA, not a tag.
- Modes are `replace` / `merge` everywhere (never `deploy` / `seed`).
- Swift support is **rolling latest-only** — one maintained version at a time.
- Large binary inputs (bacpacs, DBs) are **not** committed.
- Docs describe **current** behavior in the present tense — no fix history or phase numbers.
