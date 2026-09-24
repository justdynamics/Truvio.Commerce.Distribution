# Truvio Commerce Distribution

Everything needed to make **Dynamicweb 10** run as **Truvio Commerce** — as one git
clone. Structured as versioned **layers** composed into gate-proven **editions**, proven
on the current latest Swift release (**Swift 2.4**; rolling latest-only) — this cycle proven on **Dynamicweb release ring R1**, which carried milestone **10.28.11** at the 2026-09-19 gate run. The ring is the claim and the milestone is the stamp: R0 is the current milestone under a 30-day soak, R1 the current milestone, R2 current+1, R3 current+2, R4 current+3, and milestones move first-in first-out one ring step per month ([release policy](https://doc.dynamicweb.dev/documentation/fundamentals/dw10release/releasepolicy.html)). The exact proven milestone stays stamped in `layers/INDEX.json` `gateProven`.

> Themes and features ship as `theme` and `feature` layers under `layers/`. Truvio Commerce
> is the platform formerly known as Dynamicweb; host binaries still carry the `Dynamicweb`
> name. We use **DW** as shorthand throughout.

## What's here

```
layers/            one versioned unit each (base, features, surfaces, themes, sample-data)
  layer.schema.json         the layer contract
  base/base.contract.json   guarantees the base makes to additions
editions/          named compositions of layers (base-swift, base-only, swift-demo, headless-demo, dap-portal)
  edition.schema.json       the edition contract
tools/ci/          the self-contained PR validator
```

- **[LAYERS.md](LAYERS.md)** — the full catalog (every layer + edition, proven vs Beta).
- **[GLOSSARY.md](GLOSSARY.md)** — authoritative vocabulary.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — the merge gate.

## Model

A **layer** is one versioned unit: a `layer.json` manifest + serialized content (mode
trees `replace/` source-wins, `merge/` field-level) and/or a `files/` disk overlay. Its
`kind` (`base` / `feature` / `surface` / `sample-data` / `theme`)
says how it composes — the dir-name prefix equals the kind (`feature-*`,
`surface-*`, `theme-*`; `base` is a singleton). Exactly one layer carries kind `sample-data`:
`sample-data`, the whole demo dataset — the browsable catalogue, the personas, the orders and the
storefront copy — which rides the `sampleData` toggle and is never an `add[]` ref. See
[LAYERS.md](LAYERS.md) for the prefix→lane table.

An **edition** is a composition — `from` a privileged base + an ordered `add` of layers,
plus optional `surfaces`, `sampleData`, and `themes`. Additions bind ONLY to the
[base contract](layers/base/base.contract.json), never to each other — including to the sample
data, whose subjects the contract's `sampleData` block names. Five editions are specified
(`base-only`, `base-swift`, `swift-demo`, `headless-demo`, `dap-portal`). **Which of them is
gate-proven is recorded in [`layers/INDEX.json`](layers/INDEX.json) `gateProven` and nowhere
else**: the Foundry publish flow stamps an edition there from a gate run, and an edition absent
from `gateProven.editions` is unproven, whatever a description says.

## Consuming

Git-clone distribution — no release archives. **Pin `origin/main` — main IS the version.**
Clone, `git pull --ff-only` to stay current, pick an edition, activate its layers against a
DW10 host. The upstream **Foundry** harness (`Truvio.Commerce.Serializer.BaselineUpdater`)
does this end-to-end and is where layers are produced and proven, and `main` only advances
through the gate-proven, PR-approved merge.

Under rolling-latest-only there is no supported old state to re-materialize, so **there is no
re-consumable tag pin**. Annotated tags (`layers/<name>/<semver>` / `editions/<name>/<semver>`,
carrying the gate run id + Swift version each artifact was proven against) are **provenance-only
audit history**, cut **automatically by CI on merge to main** — never a frozen consumption pin.
Need to reproduce a past state for forensics? Record the resolved commit SHA, not a tag.

## Policy

**Rolling latest-only Swift support.** This distribution targets the current latest Swift
release and validates on that one version. When the next Swift ships, maintenance rolls
forward and the prior version is dropped — no back-support, no multi-version matrix.

## License

MIT — see [LICENSE](LICENSE).
