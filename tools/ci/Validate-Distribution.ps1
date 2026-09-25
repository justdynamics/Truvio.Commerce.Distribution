<#
.SYNOPSIS
Self-contained PR validator for the Truvio Commerce Distribution repo (v3.0). The
machine-enforced merge gate (CONTRIBUTING.md): every PR must pass all checks below.
The deep clean-room deserialize roundtrip stays a documented operator step (run in the
harness / Foundry) — this validator is the fast structural gate.

Checks (all fail-closed; any failure -> exit 1):
  1. Layer schema      — every layers/<name>/layer.json validates vs layers/layer.schema.json.
  2. Dir/name agree    — layer.json "name" equals its directory name.
  3. Edition schema    — every editions/<name>.json validates vs editions/edition.schema.json.
  4. Edition refs      — from/add/surfaces '<name>@<semver>' resolve to layers/<name> whose
                         layer.json version == the pinned semver; themes[] resolve to
                         layers/theme-<name> (kind theme).
  5. Base contract     — layers/base/base.contract.json parses; compat.apps carries exactly one
                         Truvio.Commerce.Serializer floor, and the deprecated minSerializerVersion
                         alias (when present) equals it (Foundry #1084). ReleaseRing: compat.dw.ring
                         is present and is a release ring R0..R4, and compat.dw.min (the derived
                         alias, kept one release) is at or below INDEX.json gateProven.dw.version -
                         a floor above what the gate proved is a claim nobody measured.
  6. Cross-layer clash — no two non-base layers ship the same _sql/<Table>/<key>.yml ROW path
                         (a silent last-writer-wins collision at deserialize). A table SCHEMA
                         file (_sql/<Table>/_meta.yml) describes the table, not a row, so two
                         layers writing rows into the same table each carry one: shared is
                         allowed ONLY when every active copy is byte-identical, because the
                         engine deserializes the table against whichever schema file it read
                         last. Any divergence FAILs, naming the table and the layers.
  7. Protected strings — plan §3.1 guard (Test-ProtectedStrings.ps1).
  8. SPEC-06 disk-only — no serialized content (*.yml/*.yaml/*.sql/*.bacpac/*.bak) under a
                         kind:theme layer (disk-overlay-only).
  9. INDEX.json        — (RUN-VERSION-CURRENCY P3) layers/INDEX.json parses; carries a
                         well-formed `gateProven` marker; its `layers` array regenerates
                         from the live tree and diffs clean (drift BOTH directions FAILs:
                         a dir with no entry, an entry with no dir, a version/kind/status
                         mismatch); every `retired` tombstone is well-formed (name +
                         retired:true + supersededBy). Every edition ref name must be a LIVE
                         INDEX layer (a retired name FAILs "retired -> use <supersededBy>").
                         Living root docs (README/CONTRIBUTING/GLOSSARY/LAYERS) must not
                         mention a retired layer name (tombstones live in INDEX.json, not
                         prose; CHANGELOG history + names that are substrings of a live
                         identifier are out of scope).

 10. Staging arrays   — (Foundry #1167) files[] / repositories[] / itemtypes[] are the
                        layer's declared staging surface; each is diffed against the tree
                        it describes, BOTH directions (declared-not-on-disk and
                        disk-not-declared both FAIL). A non-empty tree with no declaration
                        FAILs; [] is how a layer states it ships none. .gitkeep excluded.
                        Every placeholders[].path must appear in one of the three arrays,
                        so the placeholder assert has a declared universe.
 12. Theme baseline   - (Foundry #1285) every kind:theme layer ships a theme.json whose
                        baselineTarget names the SAME Swift release its own layer.json
                        swiftVersion declares, as 'swift/<major>.<minor>'. baselineTarget is
                        the machine-readable answer to "which Swift release was this theme
                        proven against"; Swift support here is rolling latest-only, so a
                        stale value points a consumer at a release the distribution no
                        longer ships. Drift in either direction FAILs.
 13. Version spine   - (redesign plan 4D, owner ruling redesign-floors 2026-09-23) versions/spine.json
                        is the source of every floor (Test-VersionSpine.ps1): each floor names its
                        consumer and a reason ref; no floor exceeds its component's current; a
                        gateProven-sourced current never runs ahead of gateProven; base.contract.json
                        compat equals the spine floors of consumer 'layers'; and a floor RAISED
                        against the merge base (-SpineBaseRef, default origin/main) must carry a new
                        reason.ref, else "floor raised without a consumer reason".
 14. provenTree       - (owner ruling 2026-09-23, proof rides with delivery) gateProven.proofs is
                        well-formed (tools/ci/ProvenTree.ps1), and every layer in a proof's
                        provenTree is re-hashed on this tree (tools/ci/Get-LayerTreeHash.ps1,
                        layer-tree/v1). Same version with a different tree FAILs: "layer X changed
                        since proving run Y without a version bump". A bumped version is unproven:
                        a NOTE, and release-tags does not tag it. An edition with no proof (legacy)
                        is a NOTE and keeps the pre-key tag rule until the next restamp.
 15. Manifest files[] - (Distribution #89, part 1) every SqlTable entry of a layer's
                        replace/replace-manifest.json and merge/merge-manifest.json names in
                        files[] exactly the *.yml files in its _sql/<table>/ directory
                        (Test-ManifestFiles.ps1), BOTH directions, ordinal names, _meta.yml
                        included when present. Serializer strict mode refuses a delivery whose
                        directory holds a document files[] does not name. (#89 part 2) Every
                        mode directory's _content/*.yml is named by one of its Content entries,
                        and every file an entry names is on disk inside that entry's subtree,
                        BOTH directions. Two exceptions, both counted in the PASS line: a
                        subtree entry's frame (area.yml, the ancestor page.yml stubs,
                        templates.manifest.yml) may be listed and shipped by the layer that owns
                        those pages; and a kind:sample-data document at a path a kind:surface
                        manifest of the same mode declares is a declared override (ruling
                        dla-q4), deserialized through the surface's entry.
 11. Color schemes    - (Foundry #1003) every non-empty "colorSchemeId" in a layer's serialized
                        content names a scheme Id defined by a kind:theme layer's
                        files/System/Styles/ColorSchemes/*.json, compared case-sensitively
                        (the theme CSS matches [data-dw-colorscheme] by exact value).

Usage: pwsh tools/ci/Validate-Distribution.ps1  (run from repo root; exits 0 pass / 1 fail)
       pwsh tools/ci/Validate-Distribution.ps1 -SpineBaseRef origin/main  (the floor-rule base; CI
       fetches the PR base branch first. '' skips the floor-rule comparison, local runs only)
       pwsh tools/ci/Validate-Distribution.ps1 -RegenerateIndex  (rewrite the layers/INDEX.json
       `layers` array from the live tree, preserving `retired` + `gateProven` + operator-authored
       entry fields such as `note`; then validate)
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$RegenerateIndex,
    [string]$SpineBaseRef = 'origin/main'
)
$ErrorActionPreference = 'Stop'

# Ordered version comparison for the compat floor checks: SemVer 2.0 with the NuGet reading of
# prerelease labels (Compare-SpineVersion in Test-VersionSpine.ps1). A prerelease ranks BELOW its
# release, so 10.28.1-PreRelease does not satisfy 10.28.1; labels compare case-insensitively and
# numeric identifiers numerically. Returns -1 / 0 / 1. Same rule as the Foundry's
# Compare-CompatVersion, so the validator and the gate can never disagree about which floor is higher.
. (Join-Path $PSScriptRoot 'Test-VersionSpine.ps1')
function Compare-DistVersion {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$A,
          [Parameter(Mandatory)][AllowEmptyString()][string]$B)
    return Compare-SpineVersion -A $A -B $B
}

. (Join-Path $PSScriptRoot 'Test-ProtectedStrings.ps1')
. (Join-Path $PSScriptRoot 'ProvenTree.ps1')
. (Join-Path $PSScriptRoot 'Test-ManifestFiles.ps1')

$layersRoot   = Join-Path $RepoRoot 'layers'
$editionsRoot = Join-Path $RepoRoot 'editions'
$layerSchema  = Join-Path $layersRoot 'layer.schema.json'
$editionSchema= Join-Path $editionsRoot 'edition.schema.json'
$fail = @()
$log  = { param($ok, $msg) Write-Host ("  [{0}] {1}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $msg) -ForegroundColor $(if ($ok) { 'Green' } else { 'Red' }); if (-not $ok) { $script:fail += $msg } }

Write-Host "== Truvio Commerce Distribution — PR validation ==" -ForegroundColor Cyan
foreach ($p in @($layerSchema, $editionSchema)) {
    if (-not (Test-Path $p)) { & $log $false "schema missing: $p"; }
}

# Resolve every layer dir -> its validated manifest (kind/version), reused by later checks.
$layerDirs = @(Get-ChildItem -LiteralPath $layersRoot -Directory -ErrorAction SilentlyContinue)
$manifests = @{}
foreach ($d in $layerDirs) {
    $lj = Join-Path $d.FullName 'layer.json'
    if (-not (Test-Path $lj)) { & $log $false "layer '$($d.Name)': layer.json missing"; continue }
    $raw = Get-Content -LiteralPath $lj -Raw -Encoding utf8
    $ok = $false
    try { $ok = $raw | Test-Json -SchemaFile $layerSchema -ErrorAction Stop } catch { $ok = $false }
    & $log $ok "layer '$($d.Name)': layer.json schema"
    if (-not $ok) { continue }
    $m = $raw | ConvertFrom-Json
    & $log ($m.name -eq $d.Name) "layer '$($d.Name)': dir name == manifest name ('$($m.name)')"
    $manifests[$d.Name] = $m
}

# Password value shape (Foundry #1104): AccessUserPassword stores the platform hash, and a plaintext
# value signs in nobody with no error anywhere. Every declared sqlcmd variable named like a password
# must declare valueShape 'dw-password-hash', so an applier knows to hash the plaintext it is given.
foreach ($ln in @($manifests.Keys | Sort-Object)) {
    foreach ($s in @($manifests[$ln].sql)) {
        if (-not $s) { continue }
        foreach ($v in @($s.sqlcmdVariables)) {
            if (-not $v -or "$($v.name)" -notmatch '(?i)password') { continue }
            & $log ("$($v.valueShape)" -eq 'dw-password-hash') "layer '$ln': $($s.file) sqlcmd variable '$($v.name)' declares valueShape 'dw-password-hash' (found '$($v.valueShape)')"
        }
    }
}

# Edition schema + reference resolution.
$editionFiles = @(Get-ChildItem -LiteralPath $editionsRoot -File -Filter '*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'edition.schema.json' })
$refRx = '^(?<n>[a-z0-9-]+)@(?<v>[0-9]+\.[0-9]+\.[0-9]+)$'
foreach ($ef in $editionFiles) {
    $raw = Get-Content -LiteralPath $ef.FullName -Raw -Encoding utf8
    $ok = $false
    try { $ok = $raw | Test-Json -SchemaFile $editionSchema -ErrorAction Stop } catch { $ok = $false }
    & $log $ok "edition '$($ef.BaseName)': schema"
    if (-not $ok) { continue }
    $spec = $raw | ConvertFrom-Json
    $refs = @()
    if ($spec.from)     { $refs += "$($spec.from)" }
    foreach ($r in @($spec.add))      { if ($r) { $refs += "$r" } }
    foreach ($r in @($spec.surfaces)) { if ($r) { $refs += "$r" } }
    foreach ($ref in $refs) {
        if ($ref -notmatch $refRx) { & $log $false "edition '$($ef.BaseName)': malformed ref '$ref'"; continue }
        $n = $Matches['n']; $v = $Matches['v']
        if (-not $manifests.ContainsKey($n)) { & $log $false "edition '$($ef.BaseName)': ref '$ref' -> layers/$n missing"; continue }
        & $log ("$($manifests[$n].version)" -eq $v) "edition '$($ef.BaseName)': ref '$ref' version matches layers/$n ('$($manifests[$n].version)')"
    }
    foreach ($tn in @($spec.themes)) {
        if (-not $tn) { continue }
        & $log ($manifests.ContainsKey("theme-$tn")) "edition '$($ef.BaseName)': theme '$tn' -> layers/theme-$tn exists"
    }
}

# Base contract: parses + carries reserved prefixes.
$contractPath = Join-Path $layersRoot 'base\base.contract.json'
if (-not (Test-Path $contractPath)) {
    & $log $false "base contract missing: layers/base/base.contract.json"
} else {
    try {
        $contract = Get-Content -LiteralPath $contractPath -Raw -Encoding utf8 | ConvertFrom-Json
        $hasContract = $null -ne $contract
        & $log $hasContract "base contract parses"
    } catch { & $log $false "base contract invalid JSON: $_" }
    if ($hasContract) {
        # One serializer floor (Foundry #1084): compat.apps[id=Truvio.Commerce.Serializer].min is the
        # key every machine reader reads. The deprecated minSerializerVersion alias may stay for prose
        # readers, but only as the same value; a disagreement is two floors and FAILs.
        $serApps  = @(@($contract.compat.apps) | Where-Object { $_ -and $_.id -eq 'Truvio.Commerce.Serializer' })
        $serFloor = if ($serApps.Count -eq 1) { "$($serApps[0].min)" } else { '' }
        & $log ($serApps.Count -eq 1 -and $serFloor -ne '') "base contract states exactly one serializer floor under compat.apps (found $($serApps.Count) entr$(if($serApps.Count -eq 1){'y'}else{'ies'}), min '$serFloor')"
        if ($contract.PSObject.Properties.Name -contains 'minSerializerVersion') {
            & $log ("$($contract.minSerializerVersion)" -eq $serFloor) "base contract deprecated alias minSerializerVersion ('$($contract.minSerializerVersion)') equals compat.apps serializer floor ('$serFloor')"
        }

        # ReleaseRing. The outward compat claim is the Dynamicweb HOSTING ring the layers
        # were proven on, not a hand-typed version. Two things are enforced here:
        #
        #   compat.dw.ring    present and one of R0..R4 (optionally with the runtime suffix
        #                     the demo VM writes, e.g. R1-NET10). The Foundry compat leg
        #                     compares it as an ORDER, so a value that is not a ring cannot
        #                     be compared at all and must never ship.
        #   compat.dw.min     kept one release as the derived ALIAS of the proven milestone,
        #                     so it may never claim MORE than the gate proved. A `min` above
        #                     INDEX.json gateProven.dw.version is a floor nobody measured.
        #
        # Release policy: R0 is the current milestone under a 30-day soak, R1 the current
        # milestone, R2 current+1, R3 current+2, R4 current+3; milestones move first-in
        # first-out, one ring step per month.
        # https://doc.dynamicweb.dev/documentation/fundamentals/dw10release/releasepolicy.html
        $dwNode  = $contract.compat.dw
        $dwRing  = if ($dwNode -and $dwNode.PSObject.Properties.Name -contains 'ring') { "$($dwNode.ring)".Trim() } else { '' }
        & $log ($dwRing -match '^R[0-4](-[A-Za-z0-9]+)?$') ("base contract states compat.dw.ring as a Dynamicweb release ring R0..R4 " +
            "(found '$dwRing'). The ring is the outward compatibility claim and the Foundry compat leg compares it as an " +
            "order, so a missing or non-ring value cannot be compared. Remediation: set compat.dw.ring to the ring the " +
            "layers were proven on, e.g. R1.")

        $dwMin = if ($dwNode -and $dwNode.PSObject.Properties.Name -contains 'min') { "$($dwNode.min)".Trim() } else { '' }
        if ($dwMin -ne '') {
            $provenDw = ''
            $idxForCompat = $null
            $idxPathForCompat = Join-Path $layersRoot 'INDEX.json'
            if (Test-Path -LiteralPath $idxPathForCompat) {
                try { $idxForCompat = Get-Content -LiteralPath $idxPathForCompat -Raw -Encoding utf8 | ConvertFrom-Json } catch { $idxForCompat = $null }
            }
            if ($idxForCompat -and $idxForCompat.gateProven -and $idxForCompat.gateProven.dw) {
                $provenDw = "$($idxForCompat.gateProven.dw.version)".Trim()
            }
            if ($provenDw -eq '') {
                & $log $false ("base contract states compat.dw.min '$dwMin' but layers/INDEX.json carries no " +
                    "gateProven.dw.version to check it against, so the floor is unmeasured. Remediation: let the Foundry " +
                    "publish flow stamp gateProven before shipping a dw floor.")
            } else {
                & $log ((Compare-DistVersion -A $dwMin -B $provenDw) -le 0) ("base contract compat.dw.min '$dwMin' is at or " +
                    "below the proven milestone INDEX.json gateProven.dw.version '$provenDw'. `min` is the derived alias of " +
                    "what the gate proved and may never claim more than that. Remediation: lower compat.dw.min, or re-prove " +
                    "on the milestone you want to claim.")
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 13. Version spine (redesign plan 4D; owner ruling redesign-floors, 2026-09-23).
#     versions/spine.json is the source; base.contract.json compat is the copy. A floor rises
#     only when a consumer depends on the fix, never to the latest release, so a raise against
#     the merge base must cite a NEW reason.ref.
# ---------------------------------------------------------------------------
$spinePath = Join-Path $RepoRoot 'versions\spine.json'
$spineDoc = $null
if (Test-Path -LiteralPath $spinePath) {
    try { $spineDoc = Get-Content -LiteralPath $spinePath -Raw -Encoding utf8 | ConvertFrom-Json }
    catch { & $log $false "versions/spine.json invalid JSON: $_" }
}
$spineContract = $null
if (Test-Path -LiteralPath $contractPath) { try { $spineContract = Get-Content -LiteralPath $contractPath -Raw -Encoding utf8 | ConvertFrom-Json } catch { $spineContract = $null } }
$spineGp = $null
$spineIdxPath = Join-Path $layersRoot 'INDEX.json'
if (Test-Path -LiteralPath $spineIdxPath) { try { $spineGp = (Get-Content -LiteralPath $spineIdxPath -Raw -Encoding utf8 | ConvertFrom-Json).gateProven } catch { $spineGp = $null } }
if ([string]::IsNullOrWhiteSpace($SpineBaseRef)) {
    $spineBase = @{ state = 'skipped'; spine = $null; label = '(none)' }
} else {
    $spineBase = Get-BaseSpine -RepoRoot $RepoRoot -BaseRef $SpineBaseRef
}
foreach ($r in (Test-VersionSpine -Spine $spineDoc -Contract $spineContract -GateProven $spineGp `
        -BaseSpine $spineBase.spine -BaseState $spineBase.state -BaseLabel $spineBase.label)) {
    & $log $r.ok $r.msg
}

# Cross-layer collision: same _sql/<Table>/<key>.yml shipped by two non-base layers.
# A DEPRECATED layer (layer.json costHints.deprecated — the tombstone grace release) is
# composed by no active edition, so it cannot cause the runtime last-writer-wins collision
# this check guards against; it legitimately shadows the successor rows it was split into
# (its supersededBy targets) for the one-release back-compat window. Therefore only
# ACTIVE-vs-ACTIVE collisions FAIL — a clash whose only duplication is a deprecated tombstone
# shadowing an active successor is expected and passes.
$deprecatedLayers = @{}
foreach ($n in $manifests.Keys) {
    if ($manifests[$n].costHints -and $manifests[$n].costHints.deprecated) { $deprecatedLayers[$n] = $true }
}
$sqlOwners = @{}
$sqlPaths  = @{}
foreach ($d in $layerDirs) {
    if ($d.Name -eq 'base') { continue }
    $files = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Filter '*.yml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]_sql[\\/]' })
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($d.FullName.Length + 1) -replace '\\', '/'
        $rel = ($rel -replace '^(replace|merge)/', '')  # normalize mode-dir prefix
        if (-not $sqlOwners.ContainsKey($rel)) { $sqlOwners[$rel] = @(); $sqlPaths[$rel] = @() }
        $sqlOwners[$rel] += $d.Name
        $sqlPaths[$rel]  += [pscustomobject]@{ Layer = $d.Name; Path = $f.FullName }
    }
}
# Count only ACTIVE (non-deprecated) owners per row: a deprecated tombstone shadowing its
# supersededBy successor during the grace window is not a real collision.
$multiOwned = @($sqlOwners.GetEnumerator() | Where-Object {
    @($_.Value | Select-Object -Unique | Where-Object { -not $deprecatedLayers.ContainsKey($_) }).Count -gt 1
})
# A row file (_sql/<Table>/<key>.yml) shipped by two active layers is always a clash.
# A table schema file (_sql/<Table>/_meta.yml) describes the table, not a row: two layers
# writing rows into the same table each carry one. It is allowed in more than one active
# layer ONLY when every active copy is byte-identical; any divergence FAILs, naming the
# table and the layers, because the engine would deserialize the table against whichever
# schema file it read last.
$clashes     = @($multiOwned | Where-Object { $_.Key -notmatch '/_meta\.yml$' })
$metaShared  = @($multiOwned | Where-Object { $_.Key -match '/_meta\.yml$' })
$metaDiverge = @()
foreach ($m in $metaShared) {
    $copies = @($sqlPaths[$m.Key] | Where-Object { -not $deprecatedLayers.ContainsKey($_.Layer) })
    $hashes = @($copies | ForEach-Object { (Get-FileHash -LiteralPath $_.Path -Algorithm SHA256).Hash } | Select-Object -Unique)
    if ($hashes.Count -gt 1) { $metaDiverge += [pscustomobject]@{ Key = $m.Key; Layers = (($copies | ForEach-Object { $_.Layer } | Select-Object -Unique) -join ',') } }
}
& $log ($clashes.Count -eq 0) "cross-layer _sql collision: $($clashes.Count) clash(es)$(if($clashes.Count){' — ' + (($clashes | Select-Object -First 3 | ForEach-Object { $_.Key + ' <- ' + (($_.Value | Select-Object -Unique) -join ',') }) -join ' ; ')})"
& $log ($metaDiverge.Count -eq 0) "cross-layer _sql schema files: $($metaShared.Count) _meta.yml shared by more than one layer, $($metaShared.Count - $metaDiverge.Count) byte-identical, $($metaDiverge.Count) divergent$(if($metaDiverge.Count){' — ' + (($metaDiverge | ForEach-Object { ($_.Key -replace '^_sql/', '' -replace '/_meta\.yml$', '') + ' differs between ' + $_.Layers }) -join ' ; ')})"

# Protected strings (plan §3.1).
$psRow = Test-ProtectedStrings -LayersRoot $layersRoot
& $log ($psRow.result -eq 'PASS') "protected strings: $($psRow.detail)"

# SPEC-06: theme layers ship no serialized content (disk-overlay-only).
foreach ($d in $layerDirs) {
    if (-not $manifests.ContainsKey($d.Name)) { continue }
    $k = "$($manifests[$d.Name].kind)"
    if ($k -ne 'theme') { continue }
    $bad = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.yml', '.yaml', '.sql', '.bacpac', '.bak', '.mdf', '.ldf' })
    & $log ($bad.Count -eq 0) "$k '$($d.Name)': SPEC-06 disk-overlay-only ($($bad.Count) forbidden file(s))"
}

# ---------------------------------------------------------------------------
# 12. Theme baselineTarget agrees with the layer's own swiftVersion (Foundry #1285).
#     theme.json baselineTarget is the machine-readable statement of WHICH Swift
#     release a theme was proven against. Swift support in this distribution is
#     rolling latest-only, so a value that was never rolled forward points a
#     consumer at a release nothing here ships any more — and the drift is
#     invisible: theme-default carried swift/2.3 against a 2.4.0 layer for a whole
#     release, observed only in a Foundry file header. Compared as
#     'swift/<major>.<minor>' against layer.json swiftVersion; the patch segment is
#     deliberately out of scope, because the design-package baseline moves per minor.
# ---------------------------------------------------------------------------
foreach ($d in $layerDirs) {
    if (-not $manifests.ContainsKey($d.Name)) { continue }
    if ("$($manifests[$d.Name].kind)" -ne 'theme') { continue }
    $themePath = Join-Path $d.FullName 'theme.json'
    if (-not (Test-Path -LiteralPath $themePath)) {
        & $log $false "theme '$($d.Name)': theme.json missing — a theme layer must state the Swift release it was proven against in baselineTarget"
        continue
    }
    $themeDoc = $null
    try { $themeDoc = Get-Content -LiteralPath $themePath -Raw -Encoding utf8 | ConvertFrom-Json }
    catch { & $log $false "theme '$($d.Name)': theme.json invalid JSON: $_"; continue }

    $declaredSwift = "$($manifests[$d.Name].swiftVersion)".Trim()
    $expectedTarget = ''
    if ($declaredSwift -match '^(\d+)\.(\d+)') { $expectedTarget = "swift/$($Matches[1]).$($Matches[2])" }
    $actualTarget = "$($themeDoc.baselineTarget)".Trim()

    if ($expectedTarget -eq '') {
        & $log $false "theme '$($d.Name)': layer.json swiftVersion '$declaredSwift' is not a <major>.<minor>... version, so baselineTarget cannot be checked against it"
        continue
    }
    & $log ($actualTarget -eq $expectedTarget) ("theme '$($d.Name)': theme.json baselineTarget '$actualTarget' matches layer.json " +
        "swiftVersion '$declaredSwift' (expected '$expectedTarget'). Remediation: roll baselineTarget forward with the Swift bump — " +
        "it is what a consumer reads to learn which Swift release this theme was proven against.")
}

# ---------------------------------------------------------------------------
# 10. Declared staging arrays vs disk (Foundry #1167).
#     files[] / repositories[] / itemtypes[] are the layer's DECLARED staging surface.
#     Each is compared with the tree it describes, BOTH directions:
#       declared-not-on-disk -> a stale, renamed or retired path still promised;
#       disk-not-declared    -> a path that stages onto a host and that no manifest
#                               check can see (41% of this distribution's host writes
#                               before this check existed).
#     The arrays are Files-relative on the COMPOSED SITE, not layer-relative, which is
#     the same vocabulary placeholders[].path uses - so declaring them also gives the
#     placeholder assert a declared universe to resolve against.
#     A tree that exists and is non-empty MUST be declared; declaring [] is how a layer
#     states positively that it ships none. .gitkeep is never listed.
# ---------------------------------------------------------------------------
$stagingTrees = @(
    @{ key = 'files';        dir = 'files';        prefix = '' }
    @{ key = 'repositories'; dir = 'repositories'; prefix = 'System/Repositories/' }
    @{ key = 'itemtypes';    dir = 'itemtypes';    prefix = 'System/Items/' }
)
foreach ($d in $layerDirs) {
    if (-not $manifests.ContainsKey($d.Name)) { continue }
    $m = $manifests[$d.Name]
    foreach ($t in $stagingTrees) {
        $treePath = Join-Path $d.FullName $t.dir
        $hasTree  = Test-Path -LiteralPath $treePath
        $declared = $null
        if ($m.PSObject.Properties.Name -contains $t.key) { $declared = @($m.($t.key) | ForEach-Object { "$_" }) }

        $onDisk = @()
        if ($hasTree) {
            $onDisk = @(Get-ChildItem -LiteralPath $treePath -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne '.gitkeep' } |
                ForEach-Object { $t.prefix + ($_.FullName.Substring($treePath.Length + 1) -replace '\\', '/') })
        }

        if ($null -eq $declared) {
            # Absent key is only acceptable when there is nothing to declare.
            & $log ($onDisk.Count -eq 0) "layer '$($d.Name)': $($t.key)[] not declared; $($t.dir)/ ships $($onDisk.Count) path(s)$(if($onDisk.Count){' - DECLARED NOWHERE'})"
            continue
        }

        $declSet = @{}; foreach ($x in $declared) { $declSet[$x] = $true }
        $diskSet = @{}; foreach ($x in $onDisk)   { $diskSet[$x] = $true }
        $notOnDisk   = @($declared | Where-Object { -not $diskSet.ContainsKey($_) })
        $notDeclared = @($onDisk   | Where-Object { -not $declSet.ContainsKey($_) })
        $ok = ($notOnDisk.Count -eq 0 -and $notDeclared.Count -eq 0)
        $detail = "$($declared.Count) declared / $($onDisk.Count) on disk"
        if (-not $ok) {
            $detail += " — declared-not-on-disk $($notOnDisk.Count)$(if($notOnDisk.Count){' (' + (($notOnDisk | Select-Object -First 3) -join ', ') + ')'})"
            $detail += ", disk-not-declared $($notDeclared.Count)$(if($notDeclared.Count){' (' + (($notDeclared | Select-Object -First 3) -join ', ') + ')'})"
        }
        & $log $ok "layer '$($d.Name)': $($t.key)[] vs $($t.dir)/ — $detail"
    }

    # Every placeholder must resolve to a path the layer actually declares somewhere.
    foreach ($ph in @($m.placeholders)) {
        if (-not $ph) { continue }
        $path = "$($ph.path)"
        $universe = @()
        foreach ($t in $stagingTrees) {
            if ($m.PSObject.Properties.Name -contains $t.key) { $universe += @($m.($t.key) | ForEach-Object { "$_" }) }
        }
        & $log ($universe -contains $path) "layer '$($d.Name)': placeholder '$path' is declared in files[]/repositories[]/itemtypes[]"
    }
}

# ---------------------------------------------------------------------------
# 15. Manifest files[] vs disk, SqlTable entries (Distribution #89, part 1).
#     PR #88 renamed base row files (the name comes from the name column) and kept the old
#     names in replace-manifest.json; this validator passed and the first remote delivery
#     failed Serializer strict mode. Every SqlTable entry's files[] must equal the *.yml files
#     in its _sql/<table>/ directory, both directions.
#     Content entries (#89 part 2): the surface-swift manifests kept paragraph names that
#     PR #62 and #65 moved on disk. Every _content/*.yml of a mode is named by one of its
#     Content entries and every named file is on disk in the entry's subtree; the frame of a
#     subtree entry and sample-data's declared overrides of surface paths are the two
#     allowed, counted exceptions (Test-ManifestFiles.ps1 documents both).
# ---------------------------------------------------------------------------
foreach ($d in $layerDirs) {
    foreach ($mode in @('replace', 'merge')) {
        $mp = Join-Path (Join-Path $d.FullName $mode) "$mode-manifest.json"
        if (-not (Test-Path -LiteralPath $mp -PathType Leaf)) { continue }
        $mfResults = @(Test-SqlTableManifestFiles -ManifestPath $mp)
        if ($mfResults.Count -eq 0) { continue }   # no SqlTable entry in this manifest
        $mf = Get-SqlTableManifestFilesFinding -Label "layer '$($d.Name)': $mode/$mode-manifest.json" -Results $mfResults
        & $log $mf.ok $mf.msg
    }
}

# Content: the paths each surface layer's manifests declare, per mode, are the universe a
# sample-data document may override (ruling dla-q4).
$surfaceDeclared = @{ replace = @(); merge = @() }
foreach ($d in $layerDirs) {
    if ("$($manifests[$d.Name].kind)" -ne 'surface') { continue }
    foreach ($mode in @('replace', 'merge')) {
        $mp = Join-Path (Join-Path $d.FullName $mode) "$mode-manifest.json"
        if (-not (Test-Path -LiteralPath $mp -PathType Leaf)) { continue }
        try { $sd = Get-Content -LiteralPath $mp -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        $surfaceDeclared[$mode] += @(@($sd.entries) | Where-Object { $_ -and "$($_.providerType)" -eq 'Content' } |
            ForEach-Object { @($_.files) } | Where-Object { $null -ne $_ } | ForEach-Object { "$_" -replace '\\', '/' })
    }
}
foreach ($d in $layerDirs) {
    $isSampleData = "$($manifests[$d.Name].kind)" -eq 'sample-data'
    foreach ($mode in @('replace', 'merge')) {
        $modeDir = Join-Path $d.FullName $mode
        if (-not (Test-Path -LiteralPath $modeDir -PathType Container)) { continue }
        $override = if ($isSampleData) { $surfaceDeclared[$mode] } else { @() }
        $cr = Test-ContentManifestFiles -ModeDir $modeDir -OverrideDeclared $override
        if (-not $cr) { continue }   # no Content entry and no _content tree in this mode
        $cf = Get-ContentManifestFilesFinding -Label "layer '$($d.Name)': $mode/" -Result $cr
        & $log $cf.ok $cf.msg
    }
}

# ---------------------------------------------------------------------------
# 11. colorSchemeId values resolve to a theme-defined scheme (Foundry #1003).
#     An unknown id is written, read back and deserialized without complaint; the row
#     renders with no scheme. Compared case-sensitively.
# ---------------------------------------------------------------------------
$schemeIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($d in $layerDirs) {
    if (-not $manifests.ContainsKey($d.Name)) { continue }
    if ("$($manifests[$d.Name].kind)" -ne 'theme') { continue }
    $csDir = Join-Path $d.FullName 'files/System/Styles/ColorSchemes'
    if (-not (Test-Path -LiteralPath $csDir)) { continue }
    foreach ($f in @(Get-ChildItem -LiteralPath $csDir -Filter '*.json' -File)) {
        $cs = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8 | ConvertFrom-Json
        foreach ($s in @($cs.Schemes)) { if ($s.Id) { [void]$schemeIds.Add("$($s.Id)") } }
    }
}
if ($schemeIds.Count -eq 0) {
    & $log $false "color schemes: no kind:theme layer defines a ColorSchemes/*.json scheme"
} else {
    $badSchemes = @()
    foreach ($d in $layerDirs) {
        if (-not $manifests.ContainsKey($d.Name)) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Filter '*.yml' -ErrorAction SilentlyContinue)) {
            $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
            if (-not $raw -or $raw.IndexOf('colorSchemeId') -lt 0) { continue }
            foreach ($mt in [regex]::Matches($raw, '"colorSchemeId":\s*"([^"]+)"')) {
                $v = $mt.Groups[1].Value
                if (-not $schemeIds.Contains($v)) {
                    $badSchemes += "$($d.Name): $($f.FullName.Substring($d.FullName.Length + 1) -replace '\\', '/') '$v'"
                }
            }
        }
    }
    & $log ($badSchemes.Count -eq 0) "color schemes: every colorSchemeId names one of $($schemeIds.Count) theme-defined scheme id(s)$(if($badSchemes.Count){' - unknown: ' + (($badSchemes | Select-Object -First 5) -join '; ')})"
}

# ---------------------------------------------------------------------------
# 9. INDEX.json — machine-readable layer index (RUN-VERSION-CURRENCY P3).
# ---------------------------------------------------------------------------
$indexPath = Join-Path $layersRoot 'INDEX.json'

# Build the EXPECTED live-layer array from the validated tree manifests: the
# deterministic projection {name, kind, version, status, supersededBy?} that the
# committed INDEX.layers must equal. status = deprecated when costHints.deprecated,
# else active; supersededBy carried only for deprecated (from costHints).
function Get-ExpectedLiveEntries {
    param($Manifests)
    $out = @()
    foreach ($n in ($Manifests.Keys | Sort-Object)) {
        $m = $Manifests[$n]
        $dep = ($m.costHints -and $m.costHints.deprecated)
        $e = [ordered]@{ name = "$($m.name)"; kind = "$($m.kind)"; version = "$($m.version)"; status = $(if ($dep) { 'deprecated' } else { 'active' }) }
        if ($dep -and $m.costHints.supersededBy) { $e.supersededBy = @($m.costHints.supersededBy | ForEach-Object { "$_" }) }
        $out += [pscustomobject]$e
    }
    return $out
}
# Canonical one-line signature of a live entry for order-independent set compare.
function Get-EntrySig {
    param($E)
    $sb = @($E.supersededBy | ForEach-Object { "$_" } | Sort-Object) -join ','
    return "$($E.name)|$($E.kind)|$($E.version)|$($E.status)|$sb"
}

$expected = @(Get-ExpectedLiveEntries -Manifests $manifests)

# -RegenerateIndex: rewrite INDEX.layers from the live tree, PRESERVING retired + gateProven
# (retired tombstones are authored on retirement; gateProven is stamped by the Foundry publish
# flow — neither is derivable from the tree, so regeneration never clobbers them) AND any
# operator-authored fields on a layers[] entry (e.g. a tombstone `note` on a deprecated entry) —
# only the deterministic projection {name, kind, version, status, supersededBy} is regenerated;
# every other property on an existing entry of the same name is carried through (#28).
if ($RegenerateIndex) {
    $existing = $null
    if (Test-Path $indexPath) { try { $existing = Get-Content -LiteralPath $indexPath -Raw -Encoding utf8 | ConvertFrom-Json } catch { $existing = $null } }
    $doc = [ordered]@{}
    if ($existing -and $existing.PSObject.Properties.Name -contains '_comment') { $doc._comment = $existing._comment }
    if ($existing -and $existing.PSObject.Properties.Name -contains 'gateProven') { $doc.gateProven = $existing.gateProven }
    $regenerated = @('name', 'kind', 'version', 'status', 'supersededBy')
    $existingByName = @{}
    foreach ($e in @($existing.layers)) { if ($e -and $e.name) { $existingByName["$($e.name)"] = $e } }
    $carried = @()
    foreach ($entry in $expected) {
        $prev = $existingByName["$($entry.name)"]
        if ($prev) {
            foreach ($p in $prev.PSObject.Properties) {
                if ($p.Name -notin $regenerated) {
                    $entry | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
                    $carried += "$($entry.name).$($p.Name)"
                }
            }
        }
    }
    $doc.layers = $expected
    if ($existing -and $existing.PSObject.Properties.Name -contains 'retired') { $doc.retired = $existing.retired }
    $doc | ConvertTo-Json -Depth 12 | Out-File -Encoding utf8 -LiteralPath $indexPath
    Write-Host "  [regen] INDEX.json layers[] rewritten from live tree ($($expected.Count) entries; retired + gateProven preserved$(if ($carried.Count) { '; carried operator-authored: ' + ($carried -join ', ') }))" -ForegroundColor Yellow
}

$index = $null
if (-not (Test-Path $indexPath)) {
    & $log $false "INDEX.json missing: layers/INDEX.json (RUN-VERSION-CURRENCY P3 requires it)"
} else {
    try { $index = Get-Content -LiteralPath $indexPath -Raw -Encoding utf8 | ConvertFrom-Json; & $log $true "INDEX.json parses" }
    catch { & $log $false "INDEX.json invalid JSON: $_" }
}

if ($index) {
    # 9a. gateProven marker present + well-formed (consumers 'pin origin/main + assert
    #     INDEX.gateProven present'). Requires a date + a non-empty editions map whose
    #     values are gate run ids (^[0-9]{8}-[0-9]{6}$).
    $gp = $index.gateProven
    if (-not $gp) {
        & $log $false "INDEX.gateProven missing — the latest gate-proven state (runId(s) + date + edition set) is required (written by the Foundry publish flow)"
    } else {
        $gpDate = "$($gp.date)"
        $gpEds  = @()
        if ($gp.editions) { $gpEds = @($gp.editions.PSObject.Properties) }
        $gpOk = ($gpDate -match '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') -and ($gpEds.Count -gt 0)
        $badRun = @($gpEds | Where-Object { "$($_.Value)" -notmatch '^[0-9]{8}-[0-9]{6}$' } | ForEach-Object { "$($_.Name)=$($_.Value)" })
        if ($badRun.Count -gt 0) { $gpOk = $false }
        & $log $gpOk "INDEX.gateProven well-formed (date '$gpDate', $($gpEds.Count) edition(s))$(if($badRun.Count){' — bad runId(s): ' + ($badRun -join ', ')})"
    }

    # 9b. layers[] regenerates from the live tree and diffs clean — drift BOTH directions.
    $idxEntries = @($index.layers)
    $expSig = @($expected | ForEach-Object { Get-EntrySig $_ })
    $idxSig = @($idxEntries | ForEach-Object { Get-EntrySig $_ })
    $onlyTree  = @($expSig | Where-Object { $idxSig -notcontains $_ })   # dir/manifest with no matching INDEX entry
    $onlyIndex = @($idxSig | Where-Object { $expSig -notcontains $_ })   # INDEX entry with no matching dir/manifest
    $diffClean = ($onlyTree.Count -eq 0 -and $onlyIndex.Count -eq 0)
    $diffMsg = ''
    if (-not $diffClean) {
        $parts = @()
        if ($onlyTree.Count)  { $parts += "tree-not-in-INDEX: $($onlyTree -join ' ; ')" }
        if ($onlyIndex.Count) { $parts += "INDEX-not-in-tree: $($onlyIndex -join ' ; ')" }
        $diffMsg = " — " + ($parts -join ' || ') + " (run -RegenerateIndex)"
    }
    & $log $diffClean "INDEX.layers regenerates from live tree + diffs clean ($($idxEntries.Count) live entr(ies))$diffMsg"

    # 9c. Every retired tombstone is well-formed: name + retired:true + a supersededBy successor.
    $retired = @($index.retired)
    $retiredMap = @{}   # name -> supersededBy successor string (for the ref/doc checks)
    $badTomb = @()
    foreach ($t in $retired) {
        $nm = "$($t.name)"
        $succ = @($t.supersededBy | ForEach-Object { "$_" }) -join ' + '
        if ([string]::IsNullOrWhiteSpace($nm) -or ($t.retired -ne $true) -or [string]::IsNullOrWhiteSpace($succ)) {
            $badTomb += "'$nm' (retired=$($t.retired), supersededBy='$succ')"
        } else {
            $retiredMap[$nm] = $succ
        }
    }
    & $log ($badTomb.Count -eq 0) "INDEX.retired tombstones well-formed ($($retired.Count) tombstone(s))$(if($badTomb.Count){' — malformed: ' + ($badTomb -join ', ')})"

    # Live INDEX layer-name set (active + deprecated) for the ref + doc checks.
    $liveNames = @{}
    foreach ($e in $idxEntries) { $liveNames["$($e.name)"] = $true }

    # 9d. Every edition ref name resolves to a LIVE INDEX layer; a retired name FAILs
    #     with its successor. (The version match itself stays check 4; this is the
    #     name-vs-INDEX drift gate — a dead-layer reference must be loud, not silent.)
    foreach ($ef in $editionFiles) {
        $spec = Get-Content -LiteralPath $ef.FullName -Raw -Encoding utf8 | ConvertFrom-Json
        $names = @()
        if ($spec.from) { if ("$($spec.from)" -match $refRx) { $names += $Matches['n'] } }
        foreach ($r in @($spec.add))      { if ($r -and "$r" -match $refRx) { $names += $Matches['n'] } }
        foreach ($r in @($spec.surfaces)) { if ($r -and "$r" -match $refRx) { $names += $Matches['n'] } }
        foreach ($tn in @($spec.themes))  { if ($tn) { $names += "theme-$tn" } }
        foreach ($nm in ($names | Select-Object -Unique)) {
            if ($liveNames.ContainsKey($nm)) {
                & $log $true "edition '$($ef.BaseName)': ref '$nm' is a live INDEX layer"
            } elseif ($retiredMap.ContainsKey($nm)) {
                & $log $false "edition '$($ef.BaseName)': ref '$nm' is RETIRED -> use $($retiredMap[$nm])"
            } else {
                & $log $false "edition '$($ef.BaseName)': ref '$nm' absent from INDEX.json (neither live nor a retired tombstone)"
            }
        }
    }

    # 9e. Living root docs must not latch onto a retired layer name. Scope: the four
    #     living docs at repo root (CHANGELOG history + git history are OUT of scope,
    #     L-04). A retired name that is a SUBSTRING of any live layer/edition identifier
    #     is skipped — its prose hits are the (correct) successor, not a stale reference
    #     (e.g. 'headless' inside 'surface-headless', 'dap-portal' the live edition).
    $liveIdents = @()
    $liveIdents += @($idxEntries | ForEach-Object { "$($_.name)" })
    $liveIdents += @($editionFiles | ForEach-Object { $_.BaseName })
    $docFiles = @('README.md', 'CONTRIBUTING.md', 'GLOSSARY.md', 'LAYERS.md') |
        ForEach-Object { Join-Path $RepoRoot $_ } | Where-Object { Test-Path $_ }
    foreach ($rn in ($retiredMap.Keys | Sort-Object)) {
        $isSubstr = @($liveIdents | Where-Object { $_ -ne $rn -and $_ -like "*$rn*" }).Count -gt 0
        if ($isSubstr) { continue }   # ambiguous with a live successor name — not doc-scanned
        $hits = @()
        $rx = "(?<![a-z0-9-])$([regex]::Escape($rn))(?![a-z0-9-])"
        foreach ($df in $docFiles) {
            $ln = 0
            foreach ($line in (Get-Content -LiteralPath $df -Encoding utf8)) {
                $ln++
                if ([regex]::IsMatch($line, $rx)) { $hits += "$(Split-Path $df -Leaf):$ln" }
            }
        }
        & $log ($hits.Count -eq 0) "living docs clean of retired name '$rn' (-> use $($retiredMap[$rn]))$(if($hits.Count){' — hit(s): ' + ($hits -join ', ')})"
    }

    # 14. provenTree proof key (owner ruling 2026-09-23, "proof rides with delivery"). Each proven
    #     layer's tree hash (tools/ci/Get-LayerTreeHash.ps1, layer-tree/v1) is recomputed on THIS tree
    #     and compared with gateProven.proofs.<edition>.provenTree. Same version + different tree FAILs;
    #     a bumped version is unproven (NOTE, release-tags skips it); a legacy gateProven with no proofs
    #     keeps the pre-key rule (NOTE) until the next restamp fills it.
    if ($gp) {
        foreach ($pr in @(Test-ProvenTreeShape -GateProven $gp)) { & $log $false "gateProven.proofs: $pr" }
        $ptFindings = @(Get-ProvenTreeFinding -Status (Get-ProvenTreeStatus -RepoRoot $RepoRoot -GateProven $gp))
        foreach ($f in $ptFindings) {
            if ($f.level -eq 'NOTE') {
                Write-Host "  [NOTE] $($f.message)" -ForegroundColor Yellow
                if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::notice title=provenTree::$($f.message)" }
            } else {
                & $log ($f.level -eq 'PASS') $f.message
            }
        }
    }
}

Write-Host ""
if ($fail.Count -eq 0) {
    Write-Host "== VALIDATION PASS ==" -ForegroundColor Green
    exit 0
} else {
    Write-Host "== VALIDATION FAIL ($($fail.Count) issue(s)) ==" -ForegroundColor Red
    exit 1
}
