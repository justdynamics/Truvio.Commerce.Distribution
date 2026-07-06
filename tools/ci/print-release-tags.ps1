<#
.SYNOPSIS
PRINT (never run) the annotated git-tag commands that pin each proven layer/edition to the
gate run + Swift version it was proven against (plan §4 P3.3). Print-don't-run: irreversible
network/history mutations are shown for the operator to execute after the PR merges.

Tag scheme: layers/<name>/<semver> and editions/<name>/<semver>, annotated with the gate
run id + swiftVersion. BETA artifacts (not gate-proven) are listed but NOT tagged.

Usage: pwsh tools/ci/print-release-tags.ps1   # prints commands to stdout; executes nothing
#>
[CmdletBinding()]
param([string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'

$swift = '2.3.0'
# Proven gate runs (Foundry harness, 2026-07-06): the run id that proved each artifact.
$runs = @{
    'base-only'     = '20260706-112256'
    'swift-demo'    = '20260706-112646'   # full run — base + catalog + sample-data + 3 features + 3 themes
    'headless-demo' = '20260706-113923'
}
# Which proven run each LAYER rides (the edition that exercised it).
$layerProof = @{
    base                       = $runs['swift-demo']
    'fixture-catalog'          = $runs['swift-demo']
    'sample-data'              = $runs['swift-demo']
    'reordering-pricing'       = $runs['swift-demo']
    'subscription-orders'      = $runs['swift-demo']
    'bom-configurator'         = $runs['swift-demo']
    headless                   = $runs['headless-demo']
    'theme-tech-saas'          = $runs['swift-demo']
    'theme-fashion-lifestyle'  = $runs['swift-demo']
    'theme-industrial-b2b'     = $runs['swift-demo']
    # dap-portal is BETA — not proven, intentionally omitted below.
}

Write-Host "# === Print-don't-run: annotated release tags (run AFTER the PR merges) ===" -ForegroundColor Cyan
Write-Host "# Each tag pins a proven artifact to its gate run id + Swift $swift."
Write-Host ""

$beta = @()
Write-Host "# --- Layers ---"
foreach ($d in (Get-ChildItem (Join-Path $RepoRoot 'layers') -Directory | Sort-Object Name)) {
    $lj = Join-Path $d.FullName 'layer.json'
    if (-not (Test-Path $lj)) { continue }
    $m = Get-Content $lj -Raw | ConvertFrom-Json
    if (-not $layerProof.ContainsKey($d.Name)) { $beta += "layers/$($d.Name)/$($m.version) (layer '$($d.Name)')"; continue }
    $run = $layerProof[$d.Name]
    $tag = "layers/$($d.Name)/$($m.version)"
    Write-Host "git tag -a '$tag' -m 'layer $($d.Name) $($m.version) — proven on Swift $swift, gate run $run'"
}

Write-Host ""
Write-Host "# --- Editions ---"
foreach ($ef in (Get-ChildItem (Join-Path $RepoRoot 'editions') -File -Filter '*.json' | Where-Object { $_.Name -ne 'edition.schema.json' } | Sort-Object Name)) {
    $s = Get-Content $ef.FullName -Raw | ConvertFrom-Json
    if (-not $runs.ContainsKey("$($s.name)")) { $beta += "editions/$($s.name) (edition '$($s.name)')"; continue }
    $run = $runs["$($s.name)"]
    $tag = "editions/$($s.name)/$swift"
    Write-Host "git tag -a '$tag' -m 'edition $($s.name) — proven on Swift $swift, gate run $run'"
}

Write-Host ""
Write-Host "git push origin --tags"
Write-Host ""
if ($beta.Count -gt 0) {
    Write-Host "# BETA (NOT gate-proven — intentionally untagged until proven):" -ForegroundColor Yellow
    $beta | ForEach-Object { Write-Host "#   - $_" }
}
