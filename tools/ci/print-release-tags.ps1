<#
.SYNOPSIS
PRINT (never run) the annotated git-tag commands that pin each proven layer/edition to the
gate run + Swift version it was proven against (plan §4 P3.3). Print-don't-run: irreversible
network/history mutations are shown for the operator to execute after the PR merges.

Tag scheme: layers/<name>/<semver> and editions/<name>/<semver>, annotated with the gate
run id + swiftVersion. Layer tags use the layer.json version (carried over unchanged by the
taxonomy rename); edition tags use the per-edition release version (bumped when the edition
FILE changed in this rename).

Usage: pwsh tools/ci/print-release-tags.ps1   # prints commands to stdout; executes nothing
#>
[CmdletBinding()]
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'

$swift = '2.4.0'
# Proven gate runs (Foundry harness) — the FULL COLD MATRIX that proved this release
# (RUN-DISTRIBUTION-QUALITY P5, all four editions green, 2026-07-17).
$runs = @{
    'base-only'     = '20260717-032922'
    'swift-demo'    = '20260717-030351'   # full run — framework base + surface-swift + 5 features + sample data + theme-default
    'headless-demo' = '20260717-031817'   # A1–A9 PASS (gate-headless runner; ZERO Swift design files)
    'dap-portal'    = '20260717-034401'   # DAP style-id migration re-proven (Step 10d3 clean)
}
# Per-edition RELEASE version. Bumped where the edition FILE changed this release:
# swift-demo (re-pin to the split + rma), dap-portal (surface-dap-portal 1.0.3),
# headless-demo (surface-headless 2.3.3). base-only is byte-unchanged — existing tag stands.
$editionVersion = @{
    'swift-demo'    = '3.1.0'
    'headless-demo' = '2.5.1'
    'dap-portal'    = '1.1.1'
}
# Which proven run each LAYER rides (the edition that exercised it). All layers are proven.
$layerProof = @{
    base                            = $runs['swift-demo']
    'sample-data'                   = $runs['swift-demo']
    'feature-reordering'            = $runs['swift-demo']
    'feature-pricing'               = $runs['swift-demo']
    'feature-rma'                   = $runs['swift-demo']
    'feature-reordering-pricing'    = $runs['swift-demo']
    'feature-subscription-orders'   = $runs['swift-demo']
    'feature-bom-configurator'      = $runs['swift-demo']
    'surface-swift'                 = $runs['swift-demo']
    'surface-headless'              = $runs['headless-demo']
    'surface-dap-portal'            = $runs['dap-portal']
    'theme-default'                 = $runs['swift-demo']
}

Write-Host "# === Print-don't-run: annotated release tags (run AFTER the PR merges) ===" -ForegroundColor Cyan
Write-Host "# Layer tags carry over the (unchanged) layer.json version; edition tags are bumped where the file changed."
Write-Host ""

$skipped = @()
Write-Host "# --- Layers (new-name tags at carried-over versions) ---"
foreach ($d in (Get-ChildItem (Join-Path $RepoRoot 'layers') -Directory | Sort-Object Name)) {
    $lj = Join-Path $d.FullName 'layer.json'
    if (-not (Test-Path $lj)) { continue }
    $m = Get-Content $lj -Raw | ConvertFrom-Json
    if (-not $layerProof.ContainsKey($d.Name)) { $skipped += "layers/$($d.Name)/$($m.version) (no proof mapping)"; continue }
    $run = $layerProof[$d.Name]
    $tag = "layers/$($d.Name)/$($m.version)"
    Write-Host "git tag -a '$tag' -m 'layer $($d.Name) $($m.version) — proven on Swift $swift / DW 10.28.1-PreRelease, gate run $run (stable re-prove pending DW 10.28 stable)'"
}

Write-Host ""
Write-Host "# --- Editions (bumped where the file changed) ---"
foreach ($ef in (Get-ChildItem (Join-Path $RepoRoot 'editions') -File -Filter '*.json' | Where-Object { $_.Name -ne 'edition.schema.json' } | Sort-Object Name)) {
    $s = Get-Content $ef.FullName -Raw | ConvertFrom-Json
    $name = "$($s.name)"
    if (-not $editionVersion.ContainsKey($name)) { $skipped += "editions/$name (file unchanged — existing tag stands)"; continue }
    if (-not $runs.ContainsKey($name)) { $skipped += "editions/$name (no proven run)"; continue }
    $run = $runs[$name]
    $ver = $editionVersion[$name]
    $tag = "editions/$name/$ver"
    Write-Host "git tag -a '$tag' -m 'edition $name $ver — proven on Swift $swift / DW 10.28.1-PreRelease, gate run $run (stable re-prove pending DW 10.28 stable)'"
}

Write-Host ""
Write-Host "git push origin --tags"
Write-Host ""
if ($skipped.Count -gt 0) {
    Write-Host "# Not tagged here:" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "#   - $_" }
}
