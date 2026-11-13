# Edition ledger locks

Each layer declares `ledger.provides` for functions its payload demonstrates and
`ledger.requires` for capabilities it depends on or merely configures. The adjacent
comment explains exclusions. These are carriage declarations, not passing evidence.
For example, feature-pricing installs provider settings; sample-data carries the
price rows. The gallery add-on has no exact ledger function, so it claims none.

An edition locks the union of its provided functions' primary checks. Requirements
must exist in the same snapshot but do not add checks. The lock uses the skills
consumer contract's names: `repo`, `commit`, `manifest`, `digest`, `checkIds`.
`repo` is `dynamicweb/skills`; `manifest` is relative to that checkout. Foundry passes
the other four fields unchanged to the skills runner's build declaration.

The digest covers the complete release directory, using the pinned runner's
`Get-LedgerDigest`. Use canonical LF bytes: on Windows create the checkout with
`git -c core.autocrlf=false worktree add --detach <path> <commit>`. The validator
requires the exact commit and clean ledger and shared transport sources. It never
fetches or updates a producer on the caller's behalf.

Run `pwsh tools/ci/Validate-Distribution.ps1 -SkillsRoot <path>` and Pester on
`tools/ci/tests` with `TRUVIO_SKILLS_PATH` pointing to that checkout. CI explicitly
checks out the lock's revision. A future lock update also updates that CI ref;
validation rejects a checkout at the wrong revision. Unknown function/check ids,
digest differences, empty sets and extra or missing checks fail. A pinned checkout
whose snapshot files hold CRLF line endings is refused by name before the digest is
compared, so a digest taken from an `autocrlf=true` checkout cannot validate locally.

## Build inputs (`ledger.inputs`)

Some locked checks name a build field as a token in their probe: `{lang}` for the
language their rows are stored in and `{pimShop}` for the PIM shop whose folders they
count. The edition declares those values in its lock, because its own layers carry the
rows they name, so the value is the same on every host that receives the edition:

```json
"ledger": { "repo": "dynamicweb/skills", "commit": "...", "manifest": "...", "digest": "...", "checkIds": [ ... ],
            "inputs": { "defaultLanguage": "ENU", "pimShop": "TCSHOP-PIM" } }
```

| Field | Token | Names |
|---|---|---|
| `defaultLanguage` | `{lang}` | an `EcomLanguages` `LanguageId` |
| `pimShop` | `{pimShop}` | an `EcomShops` `ShopId` |

Each value is a plain id (letters, digits, `_` or `-`), the producer's SQL token rule;
no other field is accepted except `families` (below). The Foundry ledger leg passes them to the runner's build
declaration, refuses a host value that differs, and fails the gate with `Ledger input not
declared` when a locked check uses a token that nothing supplied (Foundry #1641).
`{areaId}` is not an edition input: it comes from the host profile.

The validator (`Test-EditionLedgerInput` in `tools/ci/Ledger.ps1`) FAILs, so a missing
declaration fails the pull request rather than the gate, when:

- a locked check uses `{lang}` or `{pimShop}` and the edition declares no value for it;
- the edition declares a value that no locked check uses;
- the value is not a plain id, or no layer the edition composes ships that row as
  `layers/<layer>/<replace|merge>/_sql/<EcomLanguages|EcomShops>/<id>.yml`.

`families` is not a token: the skills `pim-families` handler reads it from the build. A
locked check whose assertion kind is `families` (`pim.data-models.families-have-models`)
needs every declared family to have a data model on its category, with products, and at
least one family declared; without a declaration it FAILs on every host with "the build file
declares 0 family(ies)". The edition declares them as `ledger.inputs.families`, an array of
`{ "name": "<label>", "category": "<EcomProductCategory CategoryId>" }`. The validator FAILs
when a locked check reads families and none are declared, when they are declared and no
locked check reads them, on an entry that is not a non-blank name and a plain-id category,
on a category named twice, and on a category no composed layer ships as
`layers/<layer>/<replace|merge>/_sql/EcomProductCategory/<id>.yml`. swift-demo,
headless-demo and dap-portal declare the four data-model categories the sample-data layer
carries (`tc_commerce`, `tc_content`, `tc_product_structure`, `tc_users`).

swift-demo, headless-demo and dap-portal declare `ENU` (a base row, the default language
the sample-data catalogue is stored in) and `TCSHOP-PIM` (the sample-data PIM shop);
each has 10 locked checks using `{lang}` and 1 using `{pimShop}`. base-only, base-swift
and cpq-demo use neither token and declare no inputs. An edition file is not part of a
layer's proven tree hash, so declaring inputs bumps no layer version.

## Checks that can never pass

A lock may not contain a check that cannot end PASS at the locked commit. The
validator decides this from the locked snapshot and the pinned runner, without a host
(`Get-LedgerUnexecutableCheck` in `tools/ci/Ledger.ps1`):

| Rule | The check fails it when |
|---|---|
| `no-implemented-binding` | every binding is `status: planned` |
| `handler-not-allowlisted` | no implemented binding names a handler that the runner's `assets/handlers.json` allows on its surface |
| `requirement-not-establishable` | its function requires a fact the pinned runner has no source for: any `app`, `licence` or `capability` requirement, a `flag` when the runner does not discover feature flags, or a `flag` whose id is a settings path |

A candidate edition (`delivery.status: candidate`) is refused for delivery and cannot
claim proof, so the validator reports its count as a NOTE. Every other edition FAILs
per finding unless `contracts/ledger/exceptions.json` `unexecutable` names exactly that
edition, check and rule, with a `ref` (`owner/repo#issue`) and a reason. An entry that
matches no finding FAILs too, so the register shrinks when a lock moves to a snapshot
where the check runs. Whether a required fact holds on a given host, and whether a
short flag name matches the host's feature name, is not decidable here.

## Removing a lock, a check or carriage

Against the base branch (`-SpineBaseRef`, the merge base when history allows, as the
floor rule reads it) the validator FAILs when:

- an edition that carried a lock has none, or its file is gone (`lock`);
- a check id an edition locked is no longer locked (`check`);
- a layer that carried a `ledger` block has none (`carriage`);
- a function a layer provided is no longer in its `provides` (`provides`).

A removal passes only when the same change adds an entry to
`contracts/ledger/exceptions.json` `removals` with that `kind`, the `subject` (edition
or layer name), the `id` (check or function id, for `check` and `provides`), the
`ruling` id that allows it and a `reason`. An entry already present on the base is
spent, and a new entry that matches nothing removed FAILs. A removed layer directory
is not a row of its own; the checks it carried surface as `check` removals. An
unreadable base FAILs; `-SpineBaseRef ''` skips the comparison for local runs only.
Independently of any base, an edition named in `gateProven` must declare a lock.

The first locks cover all five compositions. Layer patch versions change because
layer.json is part of the proven tree hash; payloads are unchanged. Existing release
records and bacpacs remain historical proof. The regenerated INDEX layer list does
not advance gateProven. A new composition must acquire its own proving record before
a release or stamp is advanced. Foundry keeps ledger identities and the report
digest beside that proof; its consumer never copies the skills runner.
