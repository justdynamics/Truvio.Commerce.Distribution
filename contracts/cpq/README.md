# CPQ contracts, version 1

These are the proposed inputs and evidence boundary for a CPQ feature layer. The offline [candidate compiler](compiler.md) emits rows and a blocked plan. These contracts do not ship a
layer, install an app or implement a runtime producer. Existing editions are
unchanged. The consumer must implement `cpq-contract-v1` before an edition can use it; an unknown
probe kind must fail. Schema validation is not a CPQ readiness verdict.

## Contents

- [Documents and ownership](#documents-and-ownership)
- [Portable model](#portable-model)
- [Package lock](#package-lock)
- [Layer and behavior declaration](#layer-and-behavior-declaration)
- [Trusted evidence boundary](#trusted-evidence-boundary)
- [Validation and consumers](#validation-and-consumers)

## Documents and ownership

| Schema | Owner and purpose |
|---|---|
| `spec.schema.json` | Model author: stable names, inputs/options, rules, BOM, pricing intent and independent cases. |
| `packages.schema.json` | Delivery author: exact package/source/assembly identities, hashes and dependency graph. |
| `layer-declaration.schema.json` | Distribution: layer-relative paths to the spec, package lock and behavior contract. |
| `behavior.schema.json` | Check author: exact check/function IDs, cases, observation kind, nonempty scope and freshness limit. |
| `context.schema.json` | Trusted measurement coordinator: actual delivery/host/model/app/ledger facts. Never copied from a receipt to make it match. |
| `receipt.schema.json` | Registered behavior producer: observed outcomes bound to those facts, with explicit read completeness. |

All are self-contained draft-7 schemas. Unknown contract fields are errors, including nested
rules and actions. `observed` is intentionally the sanitized domain payload of the named check;
its interpretation is the future handler's responsibility, not arbitrary instructions to execute.

## Portable model

[`examples/neutral-workbench.json`](examples/neutral-workbench.json) is a synthetic business spec,
not vendor rule JSON or a measured configuration. Its accepted profile is explicitly
`carrot-10.24.2-studio-0.7.0`; that identifies the behavior to characterize, not a compatibility
certificate. A different app combination needs a reviewed profile and new evidence.

Conditions use a typed AST: one comparison key (`eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `in`, `nin`,
`contains`, `startswith`, `endswith`), `hasvalue`, or recursive `and`/`or`. Unknown operators and
the vendor's unsafe `left/operator/right` test shape are rejected. `contains` follows the reviewed
profile's reversed semantics: the right value contains the left. The compiler must emit uppercase
group operators and supported tuples. It must not pass the AST straight to Carrot.

References are exact `$input.Name`, `$variable.Name` or, in a catalogue lookup only,
`$product.Field`. Inputs refer to declared groups; BOM and expected lines refer to declared
catalogue keys. `allowOptions`, `set` and `properties` are proposed compiler operations. They are
not promises that an unimplemented adapter enforces them. Version 1 has no arbitrary SQL,
executable code, vendor JSON escape hatch or silent extension object. Inputs/options/labels,
typed lookups, variables, thresholds, constraints and presentation choices remain data.

This first spec profile covers catalogue sell prices, local cards/cart/quotes and optional local
DOCX. Routing, ERP mutation, Graph/PDF and 3D are explicitly outside this profile. The ledger may
describe those functions separately; broad capability inventory does not expand this compiler
profile. A further profile needs its own typed fields, adapter and proof. Preserve unsupported
models for review rather than dropping their constructs during import.

The example's large frame and two drawers cost 190.00 before a declared ten percent discount,
171.00 after it. These are expected business outcomes, not results produced by these validators.
Input/price rule ordering, margin grammar and engine coercion still need actual characterization.

## Package lock

The lock requires the exact reviewed identities for admin/runtime/Studio, source locator,
version, package digest, loaded assembly name/version/TFM/digest and a closed dependency graph.
It also requires explicit `Truvio.Commerce.MCP` and `Truvio.Commerce.MCP.Host` identities and
the `DocumentFormat.OpenXml` assembly for the declared DOCX output. Studio must declare its
admin and MCP host dependencies. The reviewed Studio README requires MCP 0.6.5 or later;
this is a CPQ profile requirement and does not raise another edition's floor. The resolver
still has to choose compatible exact releases, inspect all transitive dependencies and bind
their actual bytes. No exact MCP, MCP host or OpenXml release is invented by this contract.
There are no floating versions. A build source also names its full commit. The entry assembly
must start with the package ID, and duplicate loaded identities, all-zero digests, unlocked
dependencies and dependency cycles fail validation. Source locators are HTTPS without credentials,
queries or fragments; authentication belongs to the resolver, not the declaration.

The resolver must verify the package bytes, declared dependencies and extracted assemblies
against the lock before installation. A lock author can lie about a hash; syntax validation cannot
establish that a package exists, is licensed or contains those assemblies. A separate `packages.candidate.lock.json` records actual observed byte identities and gaps;
it is not an installable package lock because the proving package set has not been resolved. Unit tests use synthetic
hashes and `.invalid` URLs and must never become deployment inputs.

Store downloaded DLL/NuGet bytes in a local artifact cache outside synced review folders; retain
hashes and source metadata in the evidence. Vendor code held locally is not a distributable fix.
App defects belong to the vendor or independently authored adapter. Before publishing, the
delivery consumer must install once, initialize the vendor schema at startup, then import the
generated model and content. Do not deserialize CPQ rows before that schema exists.

## Layer and behavior declaration

The optional new `layer.json` property is:

```json
{
  "cpq": {
    "schemaVersion": 1,
    "spec": "cpq/model.json",
    "packages": "cpq/packages.lock.json",
    "behavior": "cpq/behavior.json"
  },
  "asserts": {
    "behaviorProbes": [
      {"kind":"cpq-contract-v1", "path":"/configure", "contract":"cpq/behavior.json"}
    ]
  }
}
```

This is a fragment, not a complete layer. The three files must exist within a feature layer;
relative traversal and filesystem links are rejected. The behavior declaration binds the exact
spec and package-lock digests and enumerates check IDs, owning function IDs and case IDs. Each
function must be in `ledger.provides`; edition locks still follow `Ledger.ps1` and the canonical
skills snapshot. There must be one matching CPQ probe; rendering cannot be disabled and the
sampleData fixture skip cannot suppress it. `path` is a declarative storefront path, not a shell
command or permission to perform arbitrary HTTP calls.

No `feature-cpq` directory or `cpq-demo` edition is created by this contract change. No index,
gateProven projection, version spine, existing layer or existing edition proof is restamped.

## Trusted evidence boundary

`Assert-CpqReceipt` accepts the receipt, trusted context, spec, package lock, behavior contract,
trusted receipt digest, the delivery's earliest permitted time and the current clock. All are
explicit parameters. The consumer must get context and digest from the actual delivery and
measurement record. Reading `receipt.before` and passing it back as trusted context defeats the
contract and is not a valid consumer implementation.

Context binds host, release, Distribution commit, delivery/run IDs, DW version, actual model and
version IDs, model/spec/catalogue/package/behavior digests, the full ledger lock and the complete
declared CPQ assembly scope. The receipt's before/after context must match it exactly. The
assembly inventory must match the locked packages with no omissions or duplicates. The trusted
receipt digest detects altered observation bytes after recording.

The timestamp interval must be after delivery, not in the future, and within the behavior
contract's maximum age (at most one hour). Every declared check/case pair must appear once;
unknown, duplicate or missing pairs fail. Each row binds the declared answers and expectation
digests, reports complete enumeration with no continuation cursor and matching nonzero subject
counts, and satisfies the check's minimum scope. SQL observations require `localOnly:true`.

Digests use `cpq-json/v1`: recursively ordinal-sort object keys, preserve array order, compact
JSON serialize values with the PowerShell helper, UTF-8 without BOM, then SHA-256. Persist and
compare these digests with the same helper; this is not a claim of RFC 8785 interoperability.
The ledger digest keeps its own existing algorithm. Raw package/assembly hashes are byte hashes.

The validator returns no PASS verdict. A valid receipt may contain `FAIL`, `ERROR` or `UNVERIFIED`.
The registered check handler must still inspect the actual outcome and compare it with the
independent case assertion. In particular it must prove prices survive handoff, wrong-owner
quote calls create no records, SQL options survive rebuild, and missing loader types fail. A
syntactically valid or correctly hashed `PASS` is never sufficient.

## Validation and consumers

Run from the repository checkout:

```powershell
Invoke-Pester -Path tools/ci/tests/Cpq.Tests.ps1 -CI
./tools/ci/Validate-Distribution.ps1 -SkillsRoot <checkout-at-the-existing-edition-lock>
```

The structural CI validates the neutral spec and every layer that opts in, and CI watches this
contract directory. Tests cover unknown fields/operators, missing/duplicate identities, reference
scope, package loader names, dependency closure, wrong hashes/locks/hosts, partial pages, stale
or future receipts, mutation of observations, skipped fixtures and preserved failure outcomes.

The companion Foundry CPQ proving consumer supplies package installation, transactional owned-row staging and a bounded separate behavior producer. A characterized runtime/content adapter and complete skills handlers are still required for live proof. MCP comes first for equivalent complete reads; discover authenticated Admin
queries next and use local-only SQL where needed. Studio's reviewed read/analyze tool pack
enforces its `/admin/dynamo` context, so the external consumer cannot assume those tools are
exposed on `/admin/mcp`. None of these schemas weakens that access policy. No host is needed to
review this contract; the blank proving host is needed for engine experiments and delivery proof.


## Candidate carriage

A CPQ layer may use an explicit `status:candidate`, a `-candidate` version and named `blockers`.
Its `packages` path then points to `packages-candidate.schema.json` evidence, whose kind, status
and `deployable:false` prevent it being mistaken for `packages.schema.json`. The candidate also
names generated compiler output, identity map, case fixtures and content intent under
`candidateArtifacts`; validation regenerates and checks those artifacts against the spec.
A ready declaration cannot carry candidate blockers or artifacts.

`Test-CpqLayerContract -ForDelivery` refuses candidates with the named reasons. A candidate
edition must repeat every layer blocker and cannot claim gate proof. Nothing sets or changes
an existing edition's proof. CPQ editions lock the checks of their provided functions **and**
the CPQ prerequisites; non-CPQ editions retain their existing selection semantics.

The validator accepts `-SkillsRootsByCommit` for mixed exact revisions; CI checks out both the
older edition lock and the CPQ lock. `TRUVIO_CPQ_SKILLS_PATH` or `.ledger-skills-cpq` is an optional
additional checkout, selected only when its HEAD equals the requested full commit. Validation
never fetches or moves a skills checkout. All selected snapshot bytes remain digest-checked.
