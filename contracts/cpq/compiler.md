# CPQ candidate compiler

The offline compiler accepts the typed portable spec, validates it, and emits canonical vendor
JSON, table rows and a stable identity map. It has no target connection or apply operation.
The neutral workbench produces fifteen rows: one model, one inactive version, three groups,
four inputs, one input rule, four BOM rules and one price rule.

## Run and outputs

```powershell
./tools/ci/Compile-CpqSpec.ps1 -SpecFile ./contracts/cpq/examples/neutral-workbench.json -OutDirectory $artifacts
```

Outputs are `candidate.json`, `vendor-json.json`, `table-rows.json`, `identity-map.json` and
`delivery-requirements.json`. Objects use cpq-json/v1 ordinal key sorting, arrays retain their
semantic order, and files use UTF-8 without a BOM. There are no timestamps or generated GUIDs.
A second compile, including one using the emitted identity map, is byte-identical.

Model identity is stable across versions. Child identities include the spec version. Numeric
IDs are deterministically assigned in the reserved high range; collisions are refused, not
resolved by silently renumbering. An explicit reviewed identity map can resolve a collision.
The future import consumer must reserve and verify those exact IDs before any write.
Compiler ownership metadata stays outside ModelVersionSetting. New versions are inactive and
the compiler does not change the active version, pages or previously owned versions.

## Native mapping and refusal

Supported initial inputs are radiobox, select, number and text. Input array order becomes
InputSeq; absent labels fall back to the symbolic key. String options retain order, labels and
images. Numeric min/max/step and option-column presentation become native input settings.
Conditions become reviewed tuple groups with uppercase operators; they are not evaluated here.
Input rules use CPQOptions under an input_rule group. allowOptions emits explicit enable and
disable operations, including the else restoration. Set/property actions use setvalue maps.
BOM rows use literal catalogue SKUs and literal or declared numeric-input quantities.
Price rows carry the declared percentage and native condition; no expected price is computed.

Unknown fields, operators, references, malformed specs, reserved group collisions, native name
overflow, unsupported controls, typed lookups, variables and nonzero markup are refused before
any output is written. No arbitrary SQL, vendor JSON escape hatch or external command is accepted.
This adapter is narrower than the portable schema; preserving an unsupported spec is intentional.

The candidate retains five unresolved delivery requirements: server validation (including
constraints, bounds, maxLength and display-only semantics), price context/engine characterization,
page/theme assets, persistence/output, and independent engine golden cases. These are not native
rows with invented enforcement. Output handoffs, DOCX and presentation remain in that manifest.
Every candidate and plan has `applyAllowed:false`. A later consumer must implement the missing
semantics and prove them; it must refuse this candidate as an executable delivery input today.
The independently authored golden file verifies emitted structure and preserves 190.00/171.00
as expected business outcomes. Tests do not claim the vendor engine produced those amounts.

## Diff and proposed apply plan

Add `ObservedFile` and `ExpectedObservedDigest` to the CLI for a plan. The digest must come from
the trusted read record. `ObservedFile` contains `modelKey`, `complete:true`, all compiler-owned
`rows` and `occupied` table/ID pairs for the proposed identities. No incomplete read is allowed.
Initial ownership requires no existing owned rows and no foreign identity collision.

For an existing delivery, also supply its trusted `PreviousFile`/`PreviousDigest` and its
`IdentityMapFile`. The previous ownership record must come from an actual completed delivery,
never from a proposed plan accepted as if applied. Any changed, missing or extra observed owned
row refuses the plan. Changing a spec requires a new version; old rows and identities remain.
An unchanged compile against the independently observed delivery produces zero operations.

The output includes ordered proposed inserts, digests, unresolved requirements and
`nextOwnership`. It never applies them or stamps a successful delivery. Existing owned rows
cannot be overwritten by a changed compiler result. There is no deletion or active-version switch.

## Candidate package evidence

[`packages.candidate.lock.json`](packages.candidate.lock.json) records real byte hashes, vendor
nuspec provenance and unresolved dependencies. It is deliberately a different kind from an
installable `cpq-packages` lock and is rejected by that validator. It records original runtime
package bytes separately from the differing installed runtime DLL. The local replacement and
Truvio.CpqHotfix are excluded from delivery. No proprietary binaries are committed.

The Studio entry now pins the published v0.7.0 nupkg and DLL from source commit
`577c2be7ffd4117c88d9bc83cfbbbaa1f4375ed4`, with its producer's build manifest.
Its empty NuGet dependency list is separate from the admin/runtime/MCP site prerequisites.
MCP 0.6.5-beta meets the corrected floor; its archive carries both MCP and MCP.Host DLLs.
Original vendor runtime source resolution and OpenXml 3.1.0 plus the full dependency closure
remain unresolved. No loaded-assembly or exact-baseline claim follows from archive inspection.

Run `Invoke-Pester -Path tools/ci/tests/Cpq.Compiler.Tests.ps1 -CI` and the repository validator.
Receipt integration tests accept `CPQ_SKILLS_ROOT` to explicitly select the skills checkout.
