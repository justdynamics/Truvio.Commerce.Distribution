<#
.SYNOPSIS
Bacpac register and release assets (Foundry #1422, owner ruling vnext-bacpac-artifacts 2026-09-28).

.DESCRIPTION
layers/INDEX.json `bacpacs` records the published databases:
  bacpacs.blank                 the database the STOCK DW10 setup wizard creates at the DW pin
                                (gateProven.dw.version), exported; tag databases/blank/<dw version>.
  bacpacs.editions.<edition>    the blank database with that edition delivered, exported before any
                                measurement; tag editions/<edition>/<edition release version>.
No entry means the deserialize is the path. layers/bacpacs.schema.json is the shape; the rules here
are the ones a schema cannot state:
  * an edition entry names the edition release version it was built from, and the gateProven run
    that proved that version (provenRunId). When the edition moves (a new release version or a new
    gateProven run) and the entry does not, CI FAILs: rebuild the bacpac from the new run or remove
    the entry. The same holds for the DW version (gateProven.dw.version) of every entry.
  * tag and asset name follow from the entry (databases/blank/<dw>, blank-dw-<dw>.bacpac;
    editions/<e>/<v>, <e>-<v>.bacpac), so a consumer can derive the download from INDEX.json.

The asset bytes never pass through this repository. The Foundry uploads the proven file to a DRAFT
release on the tag (tools/bacpac/Publish-BacpacDraft.ps1); release-tags.yml
(print-release-tags.ps1 -Execute) downloads that draft's asset, compares its sha256 with the entry,
and only then publishes the release. Functions only.
#>

# Per-edition RELEASE version: the edition artifact's own semver, bumped when the edition FILE
# changes. Nothing in INDEX.json records it, so it is declared here, once, for the release tags and
# the bacpac register alike.
function Get-EditionReleaseVersion {
    return @{
        'swift-demo'    = '5.3.0'
        'headless-demo' = '3.2.0'
        'dap-portal'    = '2.3.0'
    }
}

function Get-BacpacTag {
    param([Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind, [string]$Edition, [Parameter(Mandatory)][string]$Version)
    if ($Kind -eq 'blank') { return "databases/blank/$Version" }
    return "editions/$Edition/$Version"
}

function Get-BacpacAssetName {
    param([Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind, [string]$Edition, [Parameter(Mandatory)][string]$Version)
    if ($Kind -eq 'blank') { return "blank-dw-$Version.bacpac" }
    return "$Edition-$Version.bacpac"
}

# ---------------------------------------------------------------------------
# Test-BacpacRegister: every rule, as { ok; message } rows. Pure over the parsed INDEX, the edition
# names on disk and the release-version map.
# ---------------------------------------------------------------------------
function Test-BacpacRegister {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Index,
        [Parameter(Mandatory)][string[]]$EditionNames,
        [Parameter(Mandatory)][hashtable]$EditionVersion
    )
    $rows = [System.Collections.Generic.List[object]]::new()
    $add = { param([bool]$ok, [string]$m) $rows.Add([pscustomobject]@{ ok = $ok; message = $m }) }
    $bp = $Index.bacpacs
    if (-not $bp) { return @() }
    $gp = $Index.gateProven
    $gpDw = "$($gp.dw.version)"
    $sha = '^[0-9a-f]{64}$'; $run = '^[0-9]{8}-[0-9]{6}$'; $commit = '^[0-9a-f]{40}$'

    if ($bp.blank) {
        $b = $bp.blank
        $v = "$($b.dwVersion)"
        & $add ($v -eq $gpDw) "bacpacs.blank dwVersion '$v' equals gateProven.dw.version '$gpDw'$(if ($v -ne $gpDw) { ': the DW pin moved; export a blank bacpac at the new pin or remove the entry' })"
        & $add ("$($b.tag)" -eq (Get-BacpacTag -Kind blank -Version $v)) "bacpacs.blank tag '$($b.tag)' is '$(Get-BacpacTag -Kind blank -Version $v)'"
        & $add ("$($b.asset)" -eq (Get-BacpacAssetName -Kind blank -Version $v)) "bacpacs.blank asset '$($b.asset)' is '$(Get-BacpacAssetName -Kind blank -Version $v)'"
        & $add ("$($b.sha256)" -match $sha) "bacpacs.blank sha256 is 64 lowercase hex"
        & $add ("$($b.gateRunId)" -match $run) "bacpacs.blank gateRunId '$($b.gateRunId)' is a gate run id"
    }
    foreach ($p in @($bp.editions.PSObject.Properties)) {
        if (-not $p) { continue }
        $en = $p.Name; $e = $p.Value; $pre = "bacpacs.editions.$en"
        if ($EditionNames -notcontains $en) { & $add $false "$pre names no edition file editions/$en.json"; continue }
        $relV = "$($EditionVersion[$en])"
        $ev = "$($e.editionVersion)"
        & $add ($relV -and $ev -eq $relV) "$pre editionVersion '$ev' equals the edition release version '$relV'$(if ($ev -ne $relV) { ': the edition changed version; rebuild the bacpac from the run that proves the new version or remove the entry' })"
        $gpRun = "$($gp.editions.$en)"
        & $add ("$($e.provenRunId)" -eq $gpRun -and $gpRun) "$pre provenRunId '$($e.provenRunId)' equals gateProven.editions.$en '$gpRun'$(if ("$($e.provenRunId)" -ne $gpRun) { ': gateProven moved; rebuild the bacpac from the new run (new sha256, gate run id) or remove the entry' })"
        & $add ("$($e.dwVersion)" -eq $gpDw) "$pre dwVersion '$($e.dwVersion)' equals gateProven.dw.version '$gpDw'"
        & $add ("$($e.tag)" -eq (Get-BacpacTag -Kind edition -Edition $en -Version $ev)) "$pre tag '$($e.tag)' is '$(Get-BacpacTag -Kind edition -Edition $en -Version $ev)'"
        & $add ("$($e.asset)" -eq (Get-BacpacAssetName -Kind edition -Edition $en -Version $ev)) "$pre asset '$($e.asset)' is '$(Get-BacpacAssetName -Kind edition -Edition $en -Version $ev)'"
        & $add ("$($e.sha256)" -match $sha) "$pre sha256 is 64 lowercase hex"
        & $add ("$($e.gateRunId)" -match $run -and "$($e.deliveryRunId)" -match $run) "$pre gateRunId '$($e.gateRunId)' and deliveryRunId '$($e.deliveryRunId)' are gate run ids"
        & $add ("$($e.distributionCommit)" -match $commit) "$pre distributionCommit is a full commit sha"
    }
    return @($rows)
}

# ---------------------------------------------------------------------------
# Get-BacpacReleasePlan: one row per registered bacpac that release-tags may publish now.
# ---------------------------------------------------------------------------
function Get-BacpacReleasePlan {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Index)
    $bp = $Index.bacpacs
    if (-not $bp) { return @() }
    $plan = @()
    if ($bp.blank) {
        $b = $bp.blank
        $plan += [pscustomobject]@{
            Tag = "$($b.tag)"; Asset = "$($b.asset)"; Sha256 = "$($b.sha256)"; SizeBytes = $b.sizeBytes
            Title = "Blank DW10 database, DW $($b.dwVersion)"
            Notes = ("The database the stock Dynamicweb 10 setup wizard creates at DW $($b.dwVersion), as a bacpac. Every Truvio Commerce " +
                     "edition delivers onto it (layers/base/base.contract.json, blankTarget). sha256 $($b.sha256). Proven by restoring it onto a " +
                     "fresh database, delivering an edition onto it and running the Foundry gate (run $($b.gateRunId)). Scrubbed: no password on " +
                     "any user, no API key; set the Administrator password before the first sign-in (CONTRIBUTING.md, 'Bacpac release assets').")
        }
    }
    foreach ($p in @($bp.editions.PSObject.Properties)) {
        if (-not $p) { continue }
        $e = $p.Value
        $plan += [pscustomobject]@{
            Tag = "$($e.tag)"; Asset = "$($e.asset)"; Sha256 = "$($e.sha256)"; SizeBytes = $e.sizeBytes
            Title = "$($p.Name) $($e.editionVersion) database"
            Notes = ("The $($p.Name) $($e.editionVersion) edition delivered onto the blank DW $($e.dwVersion) database (Distribution " +
                     "$($e.distributionCommit), delivery run $($e.deliveryRunId)) and exported before any measurement, as a bacpac. sha256 " +
                     "$($e.sha256). Proven by restoring it onto a fresh database and running the Foundry gate on it (run $($e.gateRunId), " +
                     "gateProven run $($e.provenRunId)). The database only: the host still carries the Swift release Files and the layer files " +
                     "the edition delivers. Scrubbed: no password on any user, no API key; set the Administrator and persona passwords before " +
                     "the first sign-in (CONTRIBUTING.md, 'Bacpac release assets').")
        }
    }
    return $plan
}

# ---------------------------------------------------------------------------
# Publish-BacpacRelease (release-tags actuator, needs gh and GH_TOKEN). Idempotent per tag:
#   published release carrying the asset with the recorded sha256 -> nothing to do;
#   draft release on the tag -> download its asset, verify the sha256, publish;
#   anything else (no draft, wrong asset, sha256 mismatch, published without the asset) -> an error
#   row, and the release stays as it was.
# -VerifyOnly (the dry run's -CheckReleases) downloads and compares but publishes nothing.
# Returns rows { tag; result = present|verified|published|error; detail }.
# ---------------------------------------------------------------------------
function Publish-BacpacRelease {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Plan, [Parameter(Mandatory)][string]$Repo, [switch]$VerifyOnly)
    $out = @()
    $token = if ($env:GH_TOKEN) { $env:GH_TOKEN } else { "$(gh auth token)".Trim() }
    $releases = @((gh api "repos/$Repo/releases?per_page=100" --paginate --slurp | ConvertFrom-Json) | ForEach-Object { $_ } | ForEach-Object { $_ })
    foreach ($row in $Plan) {
        $hits = @($releases | Where-Object { $_.tag_name -eq $row.Tag })
        $published = @($hits | Where-Object { -not $_.draft })
        $drafts = @($hits | Where-Object { $_.draft })
        $rel = if ($published.Count -gt 0) { $published[0] } elseif ($drafts.Count -eq 1) { $drafts[0] } else { $null }
        if (-not $rel) {
            $why = if ($drafts.Count -gt 1) { "$($drafts.Count) draft releases carry the tag; delete the extras" } else { 'no draft release carries the tag: upload the asset with the Foundry tools/bacpac/Publish-BacpacDraft.ps1, then re-run release-tags (workflow_dispatch)' }
            $out += [pscustomobject]@{ tag = $row.Tag; result = 'error'; detail = $why }; continue
        }
        $asset = @($rel.assets | Where-Object { $_.name -eq $row.Asset }) | Select-Object -First 1
        if (-not $asset) { $out += [pscustomobject]@{ tag = $row.Tag; result = 'error'; detail = "the $(if ($rel.draft) { 'draft' } else { 'published' }) release carries no asset '$($row.Asset)'" }; continue }
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("bacpac-" + [guid]::NewGuid().ToString('N') + '.bacpac')
        try {
            # The asset API answers a draft's asset too (the tag lookup does not), with the repo token.
            try {
                Invoke-WebRequest -Uri "https://api.github.com/repos/$Repo/releases/assets/$($asset.id)" -OutFile $tmp -Headers @{
                    Authorization = "Bearer $token"; Accept = 'application/octet-stream'; 'X-GitHub-Api-Version' = '2022-11-28' }
            } catch { $out += [pscustomobject]@{ tag = $row.Tag; result = 'error'; detail = "could not download asset $($row.Asset): $($_.Exception.Message)" }; continue }
            $sha = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
        } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
        if ($sha -ne $row.Sha256) {
            $out += [pscustomobject]@{ tag = $row.Tag; result = 'error'; detail = "asset $($row.Asset) sha256 $sha does not match layers/INDEX.json $($row.Sha256); left $(if ($rel.draft) { 'unpublished' } else { 'as it is' })" }; continue
        }
        if (-not $rel.draft) { $out += [pscustomobject]@{ tag = $row.Tag; result = 'present'; detail = "published, $($row.Asset) sha256 verified" }; continue }
        if ($VerifyOnly) { $out += [pscustomobject]@{ tag = $row.Tag; result = 'verified'; detail = "draft carries $($row.Asset) with the recorded sha256; -Execute publishes it" }; continue }
        $body = @{ draft = $false; tag_name = $row.Tag; name = $row.Title; body = $row.Notes; make_latest = 'false' } | ConvertTo-Json -Compress
        $body | gh api -X PATCH "repos/$Repo/releases/$($rel.id)" --input - > $null
        if ($LASTEXITCODE -ne 0) { $out += [pscustomobject]@{ tag = $row.Tag; result = 'error'; detail = 'publishing the draft failed' }; continue }
        $out += [pscustomobject]@{ tag = $row.Tag; result = 'published'; detail = "$($row.Asset) sha256 verified, draft published" }
    }
    return $out
}
