<#
.SYNOPSIS
The pipeline items under pipelines/ (pipelines/pipeline.schema.json): the structural checks the
validator runs on them and the release tags the tag actuator cuts for them.

A pipeline item is deploy tooling, not content: it is never part of layers/INDEX.json gateProven and
its tag attests no gate run. Its tag pipelines/<name>/<version> names one tree of the item's
directory, so a file change without a version change is refused once the tag exists.

Functions only: dot-sourcing this file declares nothing in the caller's scope.
#>

function Get-PipelineItem {
    <# Every pipelines/<name>/ directory that carries a pipeline.json, as @{ name; dir; manifestPath; manifest; raw }. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $root = Join-Path $RepoRoot 'pipelines'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return @() }
    $items = @()
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name)) {
        $path = Join-Path $d.FullName 'pipeline.json'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $raw = Get-Content -LiteralPath $path -Raw -Encoding utf8
        $manifest = $null
        try { $manifest = $raw | ConvertFrom-Json } catch { $manifest = $null }
        $items += [pscustomobject]@{ name = $d.Name; dir = $d.FullName; manifestPath = $path; manifest = $manifest; raw = $raw }
    }
    return $items
}

function Test-PipelineItem {
    <#
    The structural gate for pipelines/. Returns rows @{ ok; msg }.
      * every directory under pipelines/ is an item with a pipeline.json that validates against the schema;
      * name equals the directory name; the entry file exists; README.md and CHANGELOG.md exist and the
        changelog carries a heading for the manifest's version;
      * requires.core equals the version of pipelines/core: both ship from one commit;
      * no YAML or script of an item carries a tab or a CRLF line ending (the Azure Pipelines parser and
        a Linux agent read them as they are);
      * when the tag pipelines/<name>/<version> is present in this clone, the item's directory is the
        tree that tag names. A difference means a file changed without a version change.
    #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $rows = [System.Collections.Generic.List[object]]::new()
    $add = { param($ok, $msg) $rows.Add([pscustomobject]@{ ok = [bool]$ok; msg = "$msg" }) }
    $root = Join-Path $RepoRoot 'pipelines'
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return $rows.ToArray() }
    $schema = Join-Path $root 'pipeline.schema.json'
    if (-not (Test-Path -LiteralPath $schema -PathType Leaf)) { & $add $false 'pipelines/pipeline.schema.json is missing'; return $rows.ToArray() }
    foreach ($d in (Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name)) {
        if (-not (Test-Path -LiteralPath (Join-Path $d.FullName 'pipeline.json') -PathType Leaf)) { & $add $false "pipelines/$($d.Name) carries no pipeline.json: every directory under pipelines/ is an item" }
    }
    $items = @(Get-PipelineItem -RepoRoot $RepoRoot)
    $core = @($items | Where-Object { $_.name -eq 'core' }) | Select-Object -First 1
    foreach ($item in $items) {
        $label = "pipelines/$($item.name)"
        try { [void](Test-Json -Json $item.raw -SchemaFile $schema -ErrorAction Stop); & $add $true "$label/pipeline.json validates against the schema" }
        catch { & $add $false "$label/pipeline.json fails the schema: $($_.Exception.Message)"; continue }
        $m = $item.manifest
        & $add ("$($m.name)" -eq $item.name) "$label name '$($m.name)' equals its directory"
        & $add (Test-Path -LiteralPath (Join-Path $item.dir "$($m.entry)") -PathType Leaf) "$label entry '$($m.entry)' exists"
        & $add (Test-Path -LiteralPath (Join-Path $item.dir 'README.md') -PathType Leaf) "$label ships a README.md"
        $changelog = Join-Path $item.dir 'CHANGELOG.md'
        $hasEntry = (Test-Path -LiteralPath $changelog -PathType Leaf) -and ((Get-Content -LiteralPath $changelog -Raw -Encoding utf8) -match "(?m)^##\s+$([regex]::Escape("$($m.version)"))(\s|$)")
        & $add $hasEntry "$label CHANGELOG.md carries a heading for $($m.version)"
        if ($m.PSObject.Properties['requires'] -and $m.requires -and $m.requires.PSObject.Properties['core']) {
            $coreVersion = if ($core -and $core.manifest) { "$($core.manifest.version)" } else { '(no pipelines/core)' }
            & $add ("$($m.requires.core)" -eq $coreVersion) "$label requires core $($m.requires.core), and pipelines/core is $coreVersion"
        }
        $bad = @()
        foreach ($f in (Get-ChildItem -LiteralPath $item.dir -Recurse -File | Where-Object { $_.Extension -in '.yml', '.yaml', '.ps1', '.psm1', '.json' })) {
            $text = [System.IO.File]::ReadAllText($f.FullName)
            if ($text.Contains("`r`n")) { $bad += "$($f.Name) (CRLF)" }
            if ($f.Extension -in '.yml', '.yaml' -and $text.Contains("`t")) { $bad += "$($f.Name) (tab)" }
        }
        & $add ($bad.Count -eq 0) "$label files are LF and its YAML carries no tab$(if ($bad.Count) { ": $($bad -join ', ')" })"
        $tag = "pipelines/$($item.name)/$($m.version)"
        $tagCommit = "$(& git -C $RepoRoot rev-parse -q --verify "refs/tags/$tag^{commit}" 2>$null)".Trim()
        if ($tagCommit) {
            & git -C $RepoRoot diff --quiet $tagCommit -- "pipelines/$($item.name)" 2>$null
            & $add ($LASTEXITCODE -eq 0) "$label equals the tree of its released tag $tag (a changed file needs a new version)"
        }
    }
    return $rows.ToArray()
}

function Get-PipelineReleaseTag {
    <# One @{ Tag; Message } per item, for tools/ci/print-release-tags.ps1. #>
    param([Parameter(Mandatory)][string]$RepoRoot)
    $out = @()
    foreach ($item in @(Get-PipelineItem -RepoRoot $RepoRoot)) {
        $m = $item.manifest
        if (-not $m -or "$($m.version)" -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { continue }
        $out += [pscustomobject]@{
            Tag     = "pipelines/$($item.name)/$($m.version)"
            Message = "pipeline item $($item.name) $($m.version) ($($m.kind), $($m.engine)): deploy tooling released from main; proof state $($m.proof.state) as the item states it in pipelines/$($item.name)/pipeline.json. Not a gate attestation: no edition is proven by this tag."
        }
    }
    return $out
}
