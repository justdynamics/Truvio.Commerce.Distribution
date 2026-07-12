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

$swift = '2.3.0'
# Proven gate runs (Foundry harness) — the run ids that proved each edition on the
# theme-default 1.0.0 state (presentation lane consolidated into ONE theme, 2026-07-12).
# RUNIDS-TBD: filled by the theme-default release sweep before the PR opens.
$runs = @{
    'base-only'     = 'RUNID-BASE-ONLY'
    'swift-demo'    = 'RUNID-SWIFT-DEMO'   # full run — base + 3 features + sample data + theme-default (affordance folded in)
    'headless-demo' = 'RUNID-HEADLESS'     # A1–A9 PASS (gate-headless runner)
    'dap-portal'    = 'RUNID-DAP-PORTAL'
}
# Per-edition RELEASE version. Bumped where the edition file changed (themes -> ["default"],
# overlays retired). headless-demo / dap-portal are byte-unchanged — existing tags stand.
$editionVersion = @{
    'swift-demo'    = '2.5.0'
    'base-only'     = '2.5.0'
    # headless-demo / dap-portal: files unchanged — existing tags stand, no new tag.
}
# Which proven run each LAYER rides (the edition that exercised it). All layers are proven.
$layerProof = @{
    base                            = $runs['swift-demo']
    'sample-data'                   = $runs['swift-demo']
    'feature-reordering-pricing'    = $runs['swift-demo']
    'feature-subscription-orders'   = $runs['swift-demo']
    'feature-bom-configurator'      = $runs['swift-demo']
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
    Write-Host "git tag -a '$tag' -m 'layer $($d.Name) $($m.version) — proven on Swift $swift, gate run $run'"
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
    Write-Host "git tag -a '$tag' -m 'edition $name $ver — proven on Swift $swift, gate run $run'"
}

Write-Host ""
Write-Host "git push origin --tags"
Write-Host ""
if ($skipped.Count -gt 0) {
    Write-Host "# Not tagged here:" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "#   - $_" }
}
