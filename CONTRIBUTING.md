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
   - every `replace-manifest.json` / `merge-manifest.json` names in `files[]` exactly the
     documents its tree ships, both directions: each SqlTable entry the `*.yml` files of its
     `_sql/<Table>/` directory, and the Content entries of a mode every `_content/*.yml` of that
     mode. Two exceptions pass and are counted: a subtree entry may list its frame (`area.yml`,
     the ancestor `page.yml` stubs, `templates.manifest.yml`) that the owning layer ships, and a
     `sample-data` document at a path a `surface` manifest of the same mode declares is a
     declared override, deserialized through the surface's entry;
   - the version spine holds (see [Version floors](#version-floors));
   - the protected-string guard passes (the layer/mode vocabulary never leaked into a
     DW/Swift identifier or path); theme layers carry no serialized content (SPEC-06).
     A mode word between slashes (`/replace/`, `\merge\`) fails the guard, except inside
     a token that starts with `layers/`: a guide page may cite `layers/base/replace/_sql`
     as prose, while a template, layout, image or file value carrying `/replace/` still
     fails;

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

## Version floors

[`versions/spine.json`](versions/spine.json) is the one record of every outward component's
proven `current`, its per-consumer `floors` and its package `ids`: the package, its aliases, and
its retired `predecessors`. `Dynamicweb.MCP` is the retired predecessor of `Truvio.Commerce.MCP`, so a
host that carries only `Dynamicweb.MCP` is below the floor. The `compat` block in
`layers/base/base.contract.json` is a copy of the floors of consumer `layers`: change the spine
first, then copy. CI ([`tools/ci/Test-VersionSpine.ps1`](tools/ci/Test-VersionSpine.ps1)) fails when:

- a floor has no `reason.ref` (`<owner>/<repo>#<n>`, or `<owner>/<repo>@<sha>` when history has
  no issue or PR) and `why`;
- a floor exceeds its component's `current`, or a gateProven-sourced `current` runs ahead of
  `layers/INDEX.json` `gateProven`;
- the contract disagrees with the spine;
- **a floor is raised without a consumer reason.** A floor rises only when a consumer depends on
  the fix, never to the latest release (owner ruling `redesign-floors`, 2026-09-23). A PR that
  raises a floor above the merge base must give it a new `reason.ref` naming the issue or PR the
  consumer depends on.

Versions order as SemVer 2.0 with the NuGet reading of prerelease labels: a prerelease ranks
below its release and labels compare case-insensitively, so a floor names the version as the
package ships it (`0.6.0-beta`, not `0.6.0`).

## Proof key (provenTree)

A provenance tag names a gate run, and it may only name a run that delivered exactly the tagged
tree (owner ruling 2026-09-23, "proof rides with delivery"). The Foundry's gateProven writer records,
per proven edition, `gateProven.proofs.<edition>` = `{ runId, deliveryRunId, distributionCommit,
checkSet, harnessCommit, algorithm, provenTree: { <layer>: { version, hash } } }`, hashing every
layer the run composed from the Distribution tree it delivered with
[`tools/ci/Get-LayerTreeHash.ps1`](tools/ci/Get-LayerTreeHash.ps1) (`layer-tree/v1`: every file of
the layer directory except the layer-root `*.md` documentation, CR LF read as LF in text files).
`gateProven.editions` is unchanged. CI (check 14 of the validator) recomputes each proven layer's hash
on the PR tree:

- same version, different tree: **FAIL**, "layer X changed since proving run Y without a version bump";
- bumped version: passes with a notice that the layer is unproven; release-tags does not tag it until a
  gate run delivers the new tree and restamps `gateProven`;
- `gateProven` without `proofs` (stamped before the key): a notice, and the pre-key tag rule, until the
  next restamp.

Release tags ([`tools/ci/print-release-tags.ps1`](tools/ci/print-release-tags.ps1)) cut a layer tag only
when the layer's tree hash equals its `provenTree` hash; otherwise it is listed under "Not tagged here"
with "tree differs from proving run". Dry-run the script on the merge result before merging.

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
