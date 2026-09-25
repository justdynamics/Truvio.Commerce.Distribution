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
+ swiftVersion. Both the gate run id and the Swift/DW versions are READ FROM
layers/INDEX.json `gateProven` (Distribution #77) - never re-typed here. An edition absent from
gateProven.editions is unproven and gets no tag; a layer no attested edition composes gets none
either. Layer tags use the layer.json version; edition tags use the per-edition release
version (bumped when the edition FILE changed this release).

Proof key (owner ruling 2026-09-23, "proof rides with delivery"): a layer is tagged ONLY when its
tree hash here (tools/ci/Get-LayerTreeHash.ps1, layer-tree/v1) equals the hash its proving run
recorded in gateProven.proofs.<edition>.provenTree. Otherwise it is listed under "Not tagged here"
with the reason "tree differs from proving run <run>". An edition whose proof carries a layer that
no longer matches is not tagged either. An edition with no proof yet (legacy, stamped before the
key) keeps the pre-key rule, with a notice, until the next restamp fills its provenTree.

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

# --- Provenance comes from layers/INDEX.json, never from a literal here (Distribution #77).
# A tag message is an ATTESTATION: the Swift release, the DW milestone and the gate run a
# layer or edition was proven on. Every one of those is already recorded, by the Foundry
# publish flow, in layers/INDEX.json `gateProven` — the file CONTRIBUTING.md names as the
# single source of truth and forbids hand-authoring. Re-typing them here produced exactly
# the drift this reads them to end: a hard-coded Swift 2.4.0 and a July run-id table still
# being stamped onto September artifacts.
$indexPath = Join-Path $RepoRoot 'layers\INDEX.json'
if (-not (Test-Path $indexPath)) { throw "layers/INDEX.json missing — release-tag provenance is read from it, never re-typed here (Distribution #77)." }
$index = Get-Content $indexPath -Raw -Encoding utf8 | ConvertFrom-Json
$gp = $index.gateProven
if (-not $gp) { throw "layers/INDEX.json carries no gateProven marker — nothing here is attested, so no provenance tag may be cut." }

$swift = "$($gp.swiftVersion)".Trim()
if ($swift -eq '') { $swift = ("$($gp.swift.tag)".Trim() -replace '^v', '') }
$dw = "$($gp.dw.version)".Trim()
if ($dw -eq '') { $dw = "$($gp.dwPlatformVersion)".Trim() }
$ring = "$($gp.dw.ring)".Trim()
if ($swift -eq '' -or $dw -eq '') { throw "layers/INDEX.json gateProven names no Swift and/or DW version — a tag cannot attest what the index does not record." }

# Proven gate runs: the gateProven.editions MAP, verbatim. An edition appears there only
# once it has PASSed, so an absent edition means unproven and gets no tag — the same rule
# INDEX.json states for itself. This is deliberately not a superset: a tag for an edition
# the current index does not attest would be a fabricated attestation.
$runs = @{}
foreach ($p in @($gp.editions.PSObject.Properties)) { $runs[$p.Name] = "$($p.Value)" }
if ($runs.Count -eq 0) { throw "layers/INDEX.json gateProven.editions is empty — no edition is attested, so no tag may be cut." }

# Per-edition RELEASE version. This one is NOT derivable: it is the edition artifact's own
# semver, bumped when the edition FILE changes, and nothing in INDEX.json records it. It
# stays declared here, and an edition absent from the map keeps its existing tag.
$editionVersion = @{
    'swift-demo'    = '4.0.2'
    'headless-demo' = '3.0.0'
    'dap-portal'    = '2.0.0'
}

# Which proven run each LAYER rides: DERIVED from the edition compositions on disk, so a
# layer added to (or dropped from) an edition never needs a second edit here. A layer is
# proven by any attested edition that composes it; when more than one does, the first by
# edition name wins, deterministically. A layer no attested edition composes is reported as
# skipped rather than tagged against someone else's run.
$layerEditions = @{}
foreach ($ef in (Get-ChildItem (Join-Path $RepoRoot 'editions') -File -Filter '*.json' |
                 Where-Object { $_.Name -ne 'edition.schema.json' } | Sort-Object Name)) {
    $spec = Get-Content $ef.FullName -Raw -Encoding utf8 | ConvertFrom-Json
    $en = "$($spec.name)"
    if (-not $runs.ContainsKey($en)) { continue }          # unproven edition proves no layer
    $names = @()
    foreach ($r in @($spec.from) + @($spec.add) + @($spec.surfaces)) {
        if ($r -and "$r" -match '^(?<n>[a-z0-9-]+)@') { $names += $Matches['n'] }
    }
    foreach ($tn in @($spec.themes)) { if ($tn) { $names += "theme-$tn" } }
    # sampleData is a toggle, not a ref: the one sample-data layer IS what it activates.
    if ($spec.sampleData) { $names += 'sample-data' }
    foreach ($n in ($names | Select-Object -Unique)) {
        if (-not $layerEditions.ContainsKey($n)) { $layerEditions[$n] = [System.Collections.Generic.List[string]]::new() }
        $layerEditions[$n].Add($en)
    }
}

# --- The proof key: which proving run delivered THIS tree (tools/ci/ProvenTree.ps1). ------------
. (Join-Path $PSScriptRoot 'ProvenTree.ps1')
$proofStatus = @(Get-ProvenTreeStatus -RepoRoot $RepoRoot -GateProven $gp)
$legacyEditions = @($proofStatus | Where-Object state -eq 'legacy' | ForEach-Object { $_.edition })
$notices = @()
if ($legacyEditions.Count -gt 0) {
    $notices += "gateProven carries no provenTree yet for $($legacyEditions -join ', ') (legacy): those tags keep the pre-key rule until the next restamp fills it."
}

# A layer rides the first composing attested edition (by edition file name) whose provenTree hash
# equals this tree. A proof that records the layer with another tree blocks it. Only when no proof
# records the layer at all does a legacy edition carry it, as before the key.
$layerProof = @{}      # layer -> @{ run; hash }  (hash $null for a legacy tag)
$layerBlocked = @{}    # layer -> reason
foreach ($n in $layerEditions.Keys) {
    $chosen = $null; $legacy = $null; $reasons = @(); $recorded = $false
    foreach ($en in $layerEditions[$n]) {
        if ($legacyEditions -contains $en) { if (-not $legacy) { $legacy = $en }; continue }
        $row = @($proofStatus | Where-Object { $_.edition -eq $en -and $_.layer -eq $n }) | Select-Object -First 1
        if (-not $row) { $reasons += "proving run $($runs[$en]) ($en) recorded no provenTree entry for it"; continue }
        $recorded = $true
        if ($row.state -eq 'match') { $chosen = $row; break }
        $reasons += "tree differs from proving run $($row.runId) ($en, $($row.state): proven $($row.provenVersion) $($row.provenHash), here $($row.currentVersion) $($row.currentHash))"
    }
    if ($chosen)                         { $layerProof[$n] = @{ run = $chosen.runId; hash = $chosen.currentHash } }
    elseif ($legacy -and -not $recorded) { $layerProof[$n] = @{ run = $runs[$legacy]; hash = $null } }
    else                                 { $layerBlocked[$n] = ($reasons -join '; ') }
}

# --- Build the manifest: an ordered list of @{ Tag; Message } entries. ------------------------
$manifest = [System.Collections.Generic.List[object]]::new()
$skipped  = @()

foreach ($d in (Get-ChildItem (Join-Path $RepoRoot 'layers') -Directory | Sort-Object Name)) {
    $lj = Join-Path $d.FullName 'layer.json'
    if (-not (Test-Path $lj)) { continue }
    $m = Get-Content $lj -Raw | ConvertFrom-Json
    if ($layerBlocked.ContainsKey($d.Name)) { $skipped += "layers/$($d.Name)/$($m.version) ($($layerBlocked[$d.Name]))"; continue }
    if (-not $layerProof.ContainsKey($d.Name)) { $skipped += "layers/$($d.Name)/$($m.version) (no gate-proven edition in INDEX.json composes it)"; continue }
    $run = $layerProof[$d.Name].run
    $tree = if ($layerProof[$d.Name].hash) { ", tree $($layerProof[$d.Name].hash)" } else { '' }
    $manifest.Add([pscustomobject]@{
        Tag     = "layers/$($d.Name)/$($m.version)"
        Message = "layer $($d.Name) $($m.version) — proven on Swift $swift / DW $dw$(if ($ring) { " ($ring)" }), gate run $run$tree (provenance read from layers/INDEX.json gateProven)"
    })
}

foreach ($ef in (Get-ChildItem (Join-Path $RepoRoot 'editions') -File -Filter '*.json' | Where-Object { $_.Name -ne 'edition.schema.json' } | Sort-Object Name)) {
    $s = Get-Content $ef.FullName -Raw | ConvertFrom-Json
    $name = "$($s.name)"
    if (-not $editionVersion.ContainsKey($name)) { $skipped += "editions/$name (file unchanged — existing tag stands)"; continue }
    if (-not $runs.ContainsKey($name))           { $skipped += "editions/$name (absent from INDEX.json gateProven.editions - unproven, so no tag)"; continue }
    $run = $runs[$name]
    $ver = $editionVersion[$name]
    # A proven edition is tagged only while every layer its run delivered is still that tree.
    $edRows = @($proofStatus | Where-Object { $_.edition -eq $name -and $_.state -ne 'legacy' })
    $edOff = @($edRows | Where-Object { $_.state -ne 'match' } | ForEach-Object { "$($_.layer) $($_.state)" })
    if ($edOff.Count -gt 0) { $skipped += "editions/$name/$ver (tree differs from proving run ${run}: $($edOff -join ', '))"; continue }
    $tree = if ($edRows.Count -gt 0) { ", provenTree verified ($($edRows.Count) layers)" } else { '' }
    $manifest.Add([pscustomobject]@{
        Tag     = "editions/$name/$ver"
        Message = "edition $name $ver — proven on Swift $swift / DW $dw$(if ($ring) { " ($ring)" }), gate run $run$tree (provenance read from layers/INDEX.json gateProven)"
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
    if ($notices.Count -gt 0) {
        Write-Host "# Notice:" -ForegroundColor Yellow
        $notices | ForEach-Object { Write-Host "#   - $_" }
    }
    return
}

# EXECUTE mode (CI actuator): idempotently cut + push any MISSING tag at HEAD.
Write-Host "== Distribution release-tag actuator (D-CONSUME a — provenance-only) ==" -ForegroundColor Cyan
foreach ($n in $notices) { Write-Host "::notice title=provenTree::$n" }
foreach ($s in @($skipped | Where-Object { $_ -match 'tree differs from proving run' })) { Write-Host "  [hold] $s" -ForegroundColor Yellow }
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
