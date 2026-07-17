<#
.SYNOPSIS
Release-tag manifest for the Distribution: the annotated provenance tags that pin each proven
layer/edition to the gate run + Swift version it was proven against.

Under the consumption contract D-CONSUME (a): consumers pin origin/main (main IS the version);
annotated tags are PROVENANCE-ONLY audit history, cut AUTOMATICALLY by CI on merge to main — not
a re-consumable frozen pin, never cut by hand.

Two modes:
  * default (PRINT)   — prints the `git tag -a` commands to stdout; executes nothing. Local
                        inspection / dry-run. Preserves the historical print-don't-run behaviour.
  * -Execute (CI)     — the actuator. Idempotently creates any MISSING annotated tag at the
                        current HEAD (main tip) and pushes it. Existing tags are left untouched
                        (safe to run on every push to main). This is what .github/workflows/
                        release-tags.yml runs post-merge.

Tag scheme: layers/<name>/<semver> and editions/<name>/<semver>, annotated with the gate run id
+ swiftVersion. Layer tags use the layer.json version; edition tags use the per-edition release
version (bumped when the edition FILE changed this release).

Usage:
  pwsh tools/ci/print-release-tags.ps1              # print the manifest (executes nothing)
  pwsh tools/ci/print-release-tags.ps1 -Execute     # CI actuator: cut + push missing tags
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [switch]$Execute
)
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

# --- Build the manifest: an ordered list of @{ Tag; Message } entries. ------------------------
$manifest = [System.Collections.Generic.List[object]]::new()
$skipped  = @()

foreach ($d in (Get-ChildItem (Join-Path $RepoRoot 'layers') -Directory | Sort-Object Name)) {
    $lj = Join-Path $d.FullName 'layer.json'
    if (-not (Test-Path $lj)) { continue }
    $m = Get-Content $lj -Raw | ConvertFrom-Json
    if (-not $layerProof.ContainsKey($d.Name)) { $skipped += "layers/$($d.Name)/$($m.version) (no proof mapping)"; continue }
    $run = $layerProof[$d.Name]
    $manifest.Add([pscustomobject]@{
        Tag     = "layers/$($d.Name)/$($m.version)"
        Message = "layer $($d.Name) $($m.version) — proven on Swift $swift / DW 10.28.1-PreRelease, gate run $run (stable re-prove pending DW 10.28 stable)"
    })
}

foreach ($ef in (Get-ChildItem (Join-Path $RepoRoot 'editions') -File -Filter '*.json' | Where-Object { $_.Name -ne 'edition.schema.json' } | Sort-Object Name)) {
    $s = Get-Content $ef.FullName -Raw | ConvertFrom-Json
    $name = "$($s.name)"
    if (-not $editionVersion.ContainsKey($name)) { $skipped += "editions/$name (file unchanged — existing tag stands)"; continue }
    if (-not $runs.ContainsKey($name))           { $skipped += "editions/$name (no proven run)"; continue }
    $run = $runs[$name]
    $ver = $editionVersion[$name]
    $manifest.Add([pscustomobject]@{
        Tag     = "editions/$name/$ver"
        Message = "edition $name $ver — proven on Swift $swift / DW 10.28.1-PreRelease, gate run $run (stable re-prove pending DW 10.28 stable)"
    })
}

# --- Emit. -----------------------------------------------------------------------------------
if (-not $Execute) {
    # PRINT mode (default): show the commands, run nothing.
    Write-Host "# === Print-don't-run: annotated provenance tags (D-CONSUME a — cut by CI on merge) ===" -ForegroundColor Cyan
    Write-Host "# Layer tags carry the layer.json version; edition tags are bumped where the file changed."
    Write-Host ""
    foreach ($e in $manifest) { Write-Host "git tag -a '$($e.Tag)' -m '$($e.Message)'" }
    Write-Host ""
    Write-Host "git push origin --tags"
    Write-Host ""
    if ($skipped.Count -gt 0) {
        Write-Host "# Not tagged here:" -ForegroundColor Yellow
        $skipped | ForEach-Object { Write-Host "#   - $_" }
    }
    return
}

# EXECUTE mode (CI actuator): idempotently cut + push any MISSING tag at HEAD.
Write-Host "== Distribution release-tag actuator (D-CONSUME a — provenance-only) ==" -ForegroundColor Cyan
$created = @()
$present = @()
foreach ($e in $manifest) {
    $exists = & git -C $RepoRoot tag --list $e.Tag
    if ($exists) { $present += $e.Tag; Write-Host "  [skip] $($e.Tag) (already cut)"; continue }
    & git -C $RepoRoot tag -a $e.Tag -m $e.Message
    if ($LASTEXITCODE -ne 0) { throw "git tag -a failed for $($e.Tag)" }
    $created += $e.Tag
    Write-Host "  [cut ] $($e.Tag)" -ForegroundColor Green
}

if ($created.Count -eq 0) {
    Write-Host "No new tags to cut — all provenance tags for the current main already present." -ForegroundColor Green
} else {
    foreach ($t in $created) {
        & git -C $RepoRoot push origin "refs/tags/$t"
        if ($LASTEXITCODE -ne 0) { throw "git push failed for tag $t" }
        Write-Host "  [push] $t" -ForegroundColor Green
    }
    Write-Host "Cut + pushed $($created.Count) provenance tag(s): $($created -join ', ')" -ForegroundColor Green
}
