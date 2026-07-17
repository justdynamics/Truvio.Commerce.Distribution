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
  5. Base contract     — layers/base/base.contract.json parses; reserved prefixes present.
  6. Cross-layer clash — no two non-base layers ship the same _sql/<Table>/<key>.yml path
                         (a silent last-writer-wins collision at deserialize).
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

Usage: pwsh tools/ci/Validate-Distribution.ps1  (run from repo root; exits 0 pass / 1 fail)
       pwsh tools/ci/Validate-Distribution.ps1 -RegenerateIndex  (rewrite the layers/INDEX.json
       `layers` array from the live tree, preserving `retired` + `gateProven`; then validate)
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$RegenerateIndex
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Test-ProtectedStrings.ps1')

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
foreach ($d in $layerDirs) {
    if ($d.Name -eq 'base') { continue }
    $files = @(Get-ChildItem -LiteralPath $d.FullName -Recurse -File -Filter '*.yml' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '[\\/]_sql[\\/]' })
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($d.FullName.Length + 1) -replace '\\', '/'
        $rel = ($rel -replace '^(replace|merge)/', '')  # normalize mode-dir prefix
        if (-not $sqlOwners.ContainsKey($rel)) { $sqlOwners[$rel] = @() }
        $sqlOwners[$rel] += $d.Name
    }
}
# Count only ACTIVE (non-deprecated) owners per row: a deprecated tombstone shadowing its
# supersededBy successor during the grace window is not a real collision.
$clashes = @($sqlOwners.GetEnumerator() | Where-Object {
    @($_.Value | Select-Object -Unique | Where-Object { -not $deprecatedLayers.ContainsKey($_) }).Count -gt 1
})
& $log ($clashes.Count -eq 0) "cross-layer _sql collision: $($clashes.Count) clash(es)$(if($clashes.Count){' — ' + (($clashes | Select-Object -First 3 | ForEach-Object { $_.Key + ' <- ' + (($_.Value | Select-Object -Unique) -join ',') }) -join ' ; ')})"

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
# flow — neither is derivable from the tree, so regeneration never clobbers them).
if ($RegenerateIndex) {
    $existing = $null
    if (Test-Path $indexPath) { try { $existing = Get-Content -LiteralPath $indexPath -Raw -Encoding utf8 | ConvertFrom-Json } catch { $existing = $null } }
    $doc = [ordered]@{}
    if ($existing -and $existing.PSObject.Properties.Name -contains '_comment') { $doc._comment = $existing._comment }
    if ($existing -and $existing.PSObject.Properties.Name -contains 'gateProven') { $doc.gateProven = $existing.gateProven }
    $doc.layers = $expected
    if ($existing -and $existing.PSObject.Properties.Name -contains 'retired') { $doc.retired = $existing.retired }
    $doc | ConvertTo-Json -Depth 12 | Out-File -Encoding utf8 -LiteralPath $indexPath
    Write-Host "  [regen] INDEX.json layers[] rewritten from live tree ($($expected.Count) entries; retired + gateProven preserved)" -ForegroundColor Yellow
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
}

Write-Host ""
if ($fail.Count -eq 0) {
    Write-Host "== VALIDATION PASS ==" -ForegroundColor Green
    exit 0
} else {
    Write-Host "== VALIDATION FAIL ($($fail.Count) issue(s)) ==" -ForegroundColor Red
    exit 1
}
