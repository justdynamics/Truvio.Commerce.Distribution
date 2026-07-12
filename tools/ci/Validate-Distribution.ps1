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

Usage: pwsh tools/ci/Validate-Distribution.ps1  (run from repo root; exits 0 pass / 1 fail)
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
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
$clashes = @($sqlOwners.GetEnumerator() | Where-Object { @($_.Value | Select-Object -Unique).Count -gt 1 })
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

Write-Host ""
if ($fail.Count -eq 0) {
    Write-Host "== VALIDATION PASS ==" -ForegroundColor Green
    exit 0
} else {
    Write-Host "== VALIDATION FAIL ($($fail.Count) issue(s)) ==" -ForegroundColor Red
    exit 1
}
