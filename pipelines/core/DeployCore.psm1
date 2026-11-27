#Requires -Version 7.0
<#
Truvio Commerce Distribution: the deploy core (pipelines/core).

Functions that deliver a Distribution edition onto a Dynamicweb 10 host that is reached by its URL and
an Admin API key, and by nothing else: no SQL, no file share, no remote shell. The same functions run
on an Azure Pipelines agent, a GitHub Actions runner and an operator's own machine; the engine only
decides where the key comes from and where the report goes.

Rules every function here keeps:
  * The key is read from the environment (DW_API_KEY) or a file, held in memory, sent as a bearer
    header and never written to a log, a report or a URL.
  * A status code is never the evidence. An upload counts when the host lists every file of the
    batch; a command counts when its status reads ok; a setting counts when it reads back; an index
    counts when a build stamped after the request reports success.
  * Nothing is deleted on the host. A delivery adds and overwrites; it never removes a file, a row
    or a page (the Serializer never deletes, and no step here calls a delete command).
#>
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Layer disk trees and the directory under the host's Files folder each one mirrors.
$script:LayerTreeMap = [ordered]@{
    files        = ''
    templates    = 'Templates'
    itemtypes    = 'System/Items'
    repositories = 'System/Repositories'
}
# Serializer package limits (PackageUnzip refuses anything above them); checked before the upload.
$script:PackageLimits = @{ MaxZipBytes = 256MB; MaxUnzippedBytes = 1GB; MaxEntries = 100000 }

# ---------------------------------------------------------------------------------------------
# Report: one ordered list of rows {step, result, detail}; the run fails when a row reads FAIL.
# ---------------------------------------------------------------------------------------------
function New-DeployReport {
    param([Parameter(Mandatory)][string]$WorkDir, [string]$RunName = 'all')
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $logDir = Join-Path (Join-Path $WorkDir 'logs') $RunName
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    return [pscustomobject]@{
        workDir = $WorkDir; logDir = $logDir; seq = 0
        rows = [System.Collections.Generic.List[object]]::new()
        facts = [ordered]@{}
    }
}

function Add-DeployRow {
    param([Parameter(Mandatory)]$Report, [Parameter(Mandatory)][string]$Step,
          [Parameter(Mandatory)][ValidateSet('PASS', 'FAIL', 'SKIP', 'WARN', 'OWED')][string]$Result, [string]$Detail = '')
    $Report.rows.Add([ordered]@{ step = $Step; result = $Result; detail = $Detail; at = [datetime]::UtcNow.ToString('o') })
    $colour = switch ($Result) { 'PASS' { 'Green' } 'FAIL' { 'Red' } 'OWED' { 'Red' } 'WARN' { 'Yellow' } default { 'DarkGray' } }
    Write-Host ("[{0}] {1}: {2}" -f $Result, $Step, $Detail) -ForegroundColor $colour
}

function Save-DeployReport {
    param([Parameter(Mandatory)]$Report, [string]$Name = 'deploy-report.json')
    $failed = @($Report.rows | Where-Object { $_.result -in 'FAIL', 'OWED' })
    $out = [ordered]@{
        schema = 'truvio-deploy-report/v1'
        ok     = ($failed.Count -eq 0)
        facts  = $Report.facts
        rows   = @($Report.rows.ToArray())
    }
    $path = Join-Path $Report.workDir $Name
    $out | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $path -Encoding utf8NoBOM
    return $path
}

function Test-DeployFailed { param([Parameter(Mandatory)]$Report) return (@($Report.rows | Where-Object { $_.result -in 'FAIL', 'OWED' }).Count -gt 0) }

function Get-NextLog {
    param([Parameter(Mandatory)]$Report, [Parameter(Mandatory)][string]$Label)
    $Report.seq++
    return (Join-Path $Report.logDir ('{0:D3}-{1}.log' -f $Report.seq, ($Label -replace '[^A-Za-z0-9.-]', '_')))
}

# ---------------------------------------------------------------------------------------------
# Key and transport.
# ---------------------------------------------------------------------------------------------
function Resolve-DwApiKey {
    param([string]$ApiKeyFile, [string]$EnvName = 'DW_API_KEY')
    $raw = ''
    if ($ApiKeyFile) {
        if (-not (Test-Path -LiteralPath $ApiKeyFile -PathType Leaf)) { throw "The API key file '$ApiKeyFile' does not exist." }
        $raw = (Get-Content -LiteralPath $ApiKeyFile -Raw).Trim()
    } else {
        $raw = "$([Environment]::GetEnvironmentVariable($EnvName))".Trim()
    }
    # An Azure Pipelines secret that is not mapped arrives as the literal macro text.
    if (-not $raw -or $raw -match '^\$\(.+\)$') {
        throw "No Admin API key: set the $EnvName environment variable (a secret variable mapped into the step) or pass -ApiKeyFile. The key is created in the admin under Settings > System > Developer > Api Keys."
    }
    return (ConvertTo-SecureString -String $raw -AsPlainText -Force)
}

function ConvertTo-FilesDirectory {
    param([AllowEmptyString()][string]$Path)
    $p = "$Path".Trim().Replace('\', '/')
    if ($p -match '^[A-Za-z]:' -or $p.StartsWith('//')) { throw "'$Path' is a rooted disk path; a directory relative to the host's Files folder is expected." }
    $p = $p.TrimStart('/')
    if ($p -match '^(?i)files(/|$)') { $p = $p.Substring(5).TrimStart('/') }
    $p = $p.TrimEnd('/')
    if (@($p -split '/' | Where-Object { $_ -eq '..' }).Count -gt 0) { throw "'$Path' contains a '..' segment." }
    return $p
}

function Invoke-DwApi {
    <# One request to the host. Returns @{ Code; Body; Json }. Never throws on an HTTP error. #>
    param(
        [Parameter(Mandatory)][string]$HostUrl,
        [Parameter(Mandatory)][string]$Path,              # '/Admin/Api/<verb>?query'
        [ValidateSet('GET', 'POST')][string]$Method = 'GET',
        [securestring]$ApiKey,
        $Body,                                            # object -> JSON
        [hashtable]$Form,                                 # multipart
        [string]$LogPath,
        [int]$TimeoutSec = 600
    )
    $call = @{ Uri = "$($HostUrl.TrimEnd('/'))$Path"; Method = $Method; TimeoutSec = $TimeoutSec; ErrorAction = 'Stop'; SkipHttpErrorCheck = $true; MaximumRedirection = 0 }
    if ($ApiKey) { $call['Headers'] = @{ Authorization = "Bearer $([System.Net.NetworkCredential]::new('', $ApiKey).Password)" } }
    if ($Form) { $call['Form'] = $Form }
    elseif ($null -ne $Body) { $call['Body'] = ($Body | ConvertTo-Json -Depth 64 -Compress); $call['ContentType'] = 'application/json' }
    $code = 0; $text = ''
    try {
        $resp = Invoke-WebRequest @call
        $code = [int]$resp.StatusCode
        # A problem+json answer arrives as bytes, not as text.
        $text = if ($resp.Content -is [byte[]]) { [System.Text.Encoding]::UTF8.GetString($resp.Content) } else { "$($resp.Content)" }
    } catch {
        try { $code = [int]$_.Exception.Response.StatusCode } catch { $code = 0 }
        $text = "transport error: $($_.Exception.Message)"
    }
    if ($LogPath) { "$Method $Path`nHTTP $code`n$text" | Out-File -Encoding utf8 -FilePath $LogPath }
    $json = $null
    if ($text -and ($text.TrimStart().StartsWith('{') -or $text.TrimStart().StartsWith('['))) { try { $json = $text | ConvertFrom-Json } catch { $json = $null } }
    return @{ Code = $code; Body = $text; Json = $json }
}

function Get-Short { param([string]$Text, [int]$Max = 300) $s = ("$Text" -replace '\s+', ' ').Trim(); if ($s.Length -gt $Max) { $s = $s.Substring(0, $Max) }; return $s }

function Test-CommandResponse {
    <# A command counts when HTTP is 2xx, status reads ok and the body names no strict-mode escalation. #>
    param([Parameter(Mandatory)]$Response, [Parameter(Mandatory)][string]$Verb)
    $code = [int]$Response.Code
    $status = if ($Response.Json -and $Response.Json.PSObject.Properties['status']) { "$($Response.Json.status)" } else { '' }
    $message = if ($Response.Json -and $Response.Json.PSObject.Properties['message']) { "$($Response.Json.message)" } else { "$($Response.Body)" }
    $short = Get-Short $message 600
    if ($code -lt 200 -or $code -ge 300) { return @{ ok = $false; message = $message; detail = "$Verb answered HTTP $code (status '$status'): $short" } }
    if ($status -notmatch '^(?i)ok$') { return @{ ok = $false; message = $message; detail = "$Verb answered status '$status', not ok: $short" } }
    if ("$($Response.Body)" -match 'escalated|CumulativeStrictModeException') { return @{ ok = $false; message = $message; detail = "$Verb reported strict-mode escalations: $short" } }
    return @{ ok = $true; message = $message; detail = "$Verb ok: $short" }
}

# ---------------------------------------------------------------------------------------------
# Uploads: one request per destination directory, in batches; the host must list every file.
# ---------------------------------------------------------------------------------------------
function Send-DwFiles {
    param(
        [Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Directory,   # relative to Files
        [Parameter(Mandatory)][string[]]$FilePath,
        [Parameter(Mandatory)]$Report, [string]$Label = 'upload',
        [int]$MaxFiles = 50, [long]$MaxBytes = 20MB
    )
    $dir = ConvertTo-FilesDirectory $Directory
    $batches = [System.Collections.Generic.List[object]]::new()
    $current = [System.Collections.Generic.List[string]]::new(); $bytes = 0L
    foreach ($f in $FilePath) {
        $size = (Get-Item -LiteralPath $f).Length
        if ($current.Count -gt 0 -and ($current.Count -ge $MaxFiles -or ($bytes + $size) -gt $MaxBytes)) { $batches.Add($current.ToArray()); $current = [System.Collections.Generic.List[string]]::new(); $bytes = 0L }
        $current.Add($f); $bytes += $size
    }
    if ($current.Count -gt 0) { $batches.Add($current.ToArray()) }
    foreach ($batch in $batches) {
        $batch = @($batch)
        # The Files root itself is addressed as '/': an empty path is refused as missing.
        $form = @{ path = $(if ($dir) { $dir } else { '/' }); allowOverwrite = 'true'; skipExistingFiles = 'false'; files = @($batch | ForEach-Object { Get-Item -LiteralPath $_ }) }
        $resp = $null
        foreach ($attempt in 1..3) {
            $resp = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/Upload?createMissingDirectories=true' -Method POST -ApiKey $ApiKey -Form $form -LogPath (Get-NextLog $Report $Label)
            # 502/503/504 and a dropped connection are the host recycling or a gateway hiccup: wait and resend.
            if ($resp.Code -in 0, 502, 503, 504) { Start-Sleep -Seconds (10 * $attempt); continue }
            break
        }
        if ($resp.Code -lt 200 -or $resp.Code -ge 300) { return @{ ok = $false; detail = "Upload into /Files/$dir answered HTTP $($resp.Code): $(Get-Short $resp.Body)" } }
        $model = if ($resp.Json -and $resp.Json.PSObject.Properties['model']) { $resp.Json.model } else { $null }
        if ($null -ne $model -and $model -isnot [array] -and $model.PSObject.Properties['duplicates']) {
            return @{ ok = $false; detail = "the host refused to overwrite and wrote nothing in this batch into /Files/$dir (duplicates: $(@($model.duplicates) -join ', '))" }
        }
        $written = @($model | Where-Object { $_ -is [string] })
        if ($written.Count -ne $batch.Count) {
            return @{ ok = $false; detail = "Upload into /Files/$dir answered HTTP $($resp.Code) but lists $($written.Count) written file(s) for a batch of $($batch.Count): $(Get-Short $resp.Body)" }
        }
    }
    return @{ ok = $true; detail = "$($FilePath.Count) file(s) into /Files/$dir" }
}

function Send-DwTree {
    <# Mirror a local folder under a Files-relative root. Returns @{ ok; files; directories; detail }. #>
    param(
        [Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey,
        [Parameter(Mandatory)][string]$LocalRoot, [Parameter(Mandatory)][AllowEmptyString()][string]$RemoteRoot,
        [Parameter(Mandatory)]$Report, [string]$Label = 'upload-tree', [scriptblock]$Exclude
    )
    $root = (Resolve-Path -LiteralPath $LocalRoot).Path
    $files = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Length -gt 0 })
    if ($Exclude) { $files = @($files | Where-Object { -not (& $Exclude $_) }) }
    $groups = $files | Group-Object { $_.DirectoryName } | Sort-Object Name
    $count = 0
    foreach ($g in $groups) {
        $rel = $g.Name.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
        $remote = (@($RemoteRoot.Trim('/'), $rel) | Where-Object { $_ }) -join '/'
        $r = Send-DwFiles -HostUrl $HostUrl -ApiKey $ApiKey -Directory $remote -FilePath @($g.Group.FullName) -Report $Report -Label $Label
        if (-not $r.ok) { return @{ ok = $false; files = $count; directories = @($groups).Count; detail = $r.detail } }
        $count += $g.Count
    }
    return @{ ok = $true; files = $count; directories = @($groups).Count; detail = "$count file(s) across $(@($groups).Count) directorie(s) under /Files/$($RemoteRoot.Trim('/'))" }
}

# ---------------------------------------------------------------------------------------------
# Host probe and restart.
# ---------------------------------------------------------------------------------------------
function Compare-DwVersion {
    param([string]$A, [string]$B)
    $pa = @(("$A" -split '[-+]')[0] -split '\.' | ForEach-Object { [int]($_ -replace '\D', '0') })
    $pb = @(("$B" -split '[-+]')[0] -split '\.' | ForEach-Object { [int]($_ -replace '\D', '0') })
    for ($i = 0; $i -lt [Math]::Max($pa.Count, $pb.Count); $i++) {
        $x = if ($i -lt $pa.Count) { $pa[$i] } else { 0 }; $y = if ($i -lt $pb.Count) { $pb[$i] } else { 0 }
        if ($x -ne $y) { return [Math]::Sign($x - $y) }
    }
    return 0
}

function Test-DwHost {
    <# Version from the API descriptor, then proof that the key is accepted and that no key is refused. #>
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report, [string]$MinVersion)
    $desc = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/api.json' -LogPath (Get-NextLog $Report 'probe-descriptor') -TimeoutSec 120
    $version = if ($desc.Json -and $desc.Json.PSObject.Properties['info']) { "$($desc.Json.info.version)" } else { '' }
    if ($desc.Code -ne 200 -or -not $version) { Add-DeployRow $Report 'probe:version' 'FAIL' "GET /Admin/Api/api.json answered HTTP $($desc.Code) without info.version; is this a Dynamicweb 10 host?"; return $null }
    $Report.facts['dwVersion'] = $version
    if ($MinVersion -and (Compare-DwVersion $version $MinVersion) -lt 0) { Add-DeployRow $Report 'probe:version' 'FAIL' "the host runs Dynamicweb $version; the base contract's floor is $MinVersion"; return $null }
    Add-DeployRow $Report 'probe:version' 'PASS' "Dynamicweb $version$(if ($MinVersion) { " (floor $MinVersion)" })"
    $with = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/GetAreaById?Id=1' -ApiKey $ApiKey -LogPath (Get-NextLog $Report 'probe-key') -TimeoutSec 120
    $without = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/GetAreaById?Id=1' -TimeoutSec 120
    if ($with.Code -ne 200) { Add-DeployRow $Report 'probe:key' 'FAIL' "the Admin API key was answered HTTP $($with.Code) on GetAreaById; create a key under Settings > System > Developer > Api Keys"; return $null }
    if ($without.Code -eq 200) { Add-DeployRow $Report 'probe:key' 'WARN' 'the Admin API answers without a key on this host' }
    else { Add-DeployRow $Report 'probe:key' 'PASS' "the key is accepted (HTTP 200) and a request without it is refused (HTTP $($without.Code))" }
    return $version
}

function Wait-DwHost {
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [int]$TimeoutSec = 600, [int]$StableReads = 2)
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSec); $good = 0
    while ([datetime]::UtcNow -lt $deadline) {
        $r = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/GetAreaById?Id=1' -ApiKey $ApiKey -TimeoutSec 120
        if ($r.Code -eq 200) { $good++; if ($good -ge $StableReads) { return $true } } else { $good = 0 }
        Start-Sleep -Seconds 5
    }
    return $false
}

function Invoke-HostRestart {
    <#
    Restart the application and prove the host answers again.
      control-file  upload recycle.txt into System/CloudHosting (Dynamicweb Cloud consumes it). The
                    restart counts only when the marker is gone afterwards; a marker that stays means
                    this host has no watcher, and the restart is reported as owed.
      command       run -RestartCommand on the agent (a self-hosted agent on the web server:
                    appcmd recycle apppool, Restart-WebAppPool, az webapp restart, ...).
      none          never restart; a step that needs one reports it as owed and the run stops.
    #>
    param(
        [Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)][ValidateSet('control-file', 'command', 'none')][string]$Mode,
        [string]$RestartCommand, [Parameter(Mandatory)][string]$Reason, [int]$TimeoutSec = 600
    )
    $step = "restart:$Reason"
    if ($Mode -eq 'none') { Add-DeployRow $Report $step 'OWED' "a restart is needed ($Reason) and -Restart none was given. Recycle the application and run again; the run picks up where it stopped."; return $false }
    if ($Mode -eq 'command') {
        if (-not $RestartCommand) { Add-DeployRow $Report $step 'FAIL' '-Restart command needs -RestartCommand'; return $false }
        $out = & pwsh -NoProfile -NonInteractive -Command $RestartCommand 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { Add-DeployRow $Report $step 'FAIL' "the restart command exited $LASTEXITCODE`: $(Get-Short $out)"; return $false }
        Start-Sleep -Seconds 5
    } else {
        $marker = Join-Path $Report.workDir 'recycle.txt'
        "recycle $([datetime]::UtcNow.ToString('o'))" | Set-Content -LiteralPath $marker -Encoding utf8NoBOM
        $up = Send-DwFiles -HostUrl $HostUrl -ApiKey $ApiKey -Directory 'System/CloudHosting' -FilePath @($marker) -Report $Report -Label 'restart-marker'
        if (-not $up.ok) { Add-DeployRow $Report $step 'FAIL' "the restart marker could not be uploaded: $($up.detail)"; return $false }
        # The platform consumes the marker when it acts on it. Poll for that, at most three minutes.
        $consumed = $false; $deadline = [datetime]::UtcNow.AddSeconds(180)
        while ([datetime]::UtcNow -lt $deadline) {
            Start-Sleep -Seconds 10
            $present = Test-DwFilePresent -HostUrl $HostUrl -ApiKey $ApiKey -Directory 'System/CloudHosting' -Name 'recycle.txt'
            if ($present -eq $false) { $consumed = $true; break }
        }
        if (-not $consumed) {
            Add-DeployRow $Report $step 'OWED' ("recycle.txt was uploaded into /Files/System/CloudHosting and is still there after three minutes: this host does not consume the control file " +
                "(it is a Dynamicweb Cloud affordance), so nothing restarted. Use -Restart command with a command that recycles the application, or recycle it by hand and run again.")
            return $false
        }
    }
    if (-not (Wait-DwHost -HostUrl $HostUrl -ApiKey $ApiKey -TimeoutSec $TimeoutSec)) { Add-DeployRow $Report $step 'FAIL' "the host did not answer HTTP 200 on the Admin API within $TimeoutSec s after the restart"; return $false }
    Add-DeployRow $Report $step 'PASS' "restarted by $Mode; the Admin API answers again"
    return $true
}

function Test-DwFilePresent {
    <# $true / $false when the directory listing is readable, $null when it is not. #>
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)][string]$Directory, [Parameter(Mandatory)][string]$Name)
    $dir = ConvertTo-FilesDirectory $Directory
    $q = "DirectoryPath=$([uri]::EscapeDataString("/Files/$dir"))&IncludeFiles=true&Recursive=false"
    $r = Invoke-DwApi -HostUrl $HostUrl -Path "/Admin/Api/DirectoryAll?$q" -ApiKey $ApiKey -TimeoutSec 120
    if ($r.Code -ne 200 -or -not $r.Json -or -not $r.Json.PSObject.Properties['model'] -or $null -eq $r.Json.model) { return $null }
    $names = @()
    try { $names = @($r.Json.model.files.data | ForEach-Object { "$($_.name)" }) } catch { return $null }
    return ($names -contains $Name)
}

# ---------------------------------------------------------------------------------------------
# The plan: edition -> ordered layers, their trees, the apps, the host files.
# ---------------------------------------------------------------------------------------------
function Read-JsonFile { param([Parameter(Mandatory)][string]$Path) return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json) }

function Get-EditionPlan {
    <#
    Resolve an edition into the layers it composes, in delivery order, with the trees each one ships.
    -ExtraLayer adds layer folders from outside the Distribution (a customer's own data layer). A layer
    of kind sample-data among them takes the place of the Distribution's sample-data.
    -Environment acceptance|production refuses demo data: an edition with sampleData true, and any
    extra layer of kind sample-data, are for a test environment only.
    #>
    param(
        [Parameter(Mandatory)][string]$DistributionRoot, [Parameter(Mandatory)][string]$Edition,
        [string[]]$ExtraLayer = @(), [string]$SolutionRoot, [ValidateSet('test', 'acceptance', 'production')][string]$Environment = 'test'
    )
    $editionPath = Join-Path $DistributionRoot "editions/$Edition.json"
    if (-not (Test-Path -LiteralPath $editionPath -PathType Leaf)) { throw "No edition '$Edition' under $DistributionRoot/editions." }
    $spec = Read-JsonFile $editionPath
    $index = Read-JsonFile (Join-Path $DistributionRoot 'layers/INDEX.json')
    $contract = Read-JsonFile (Join-Path $DistributionRoot 'layers/base/base.contract.json')
    $problems = [System.Collections.Generic.List[string]]::new()
    $layers = [System.Collections.Generic.List[object]]::new()
    $addLayer = {
        param([string]$Dir, [string]$Role, [string]$PinnedVersion)
        $manifestPath = Join-Path $Dir 'layer.json'
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { $problems.Add("no layer.json in '$Dir'"); return }
        $m = Read-JsonFile $manifestPath
        if ($PinnedVersion -and "$($m.version)" -ne $PinnedVersion) { $problems.Add("edition $Edition pins $($m.name)@$PinnedVersion but the checkout carries $($m.version)") }
        $trees = [ordered]@{}
        foreach ($t in @('replace', 'merge') + @($script:LayerTreeMap.Keys)) { if (Test-Path -LiteralPath (Join-Path $Dir $t) -PathType Container) { $trees[$t] = (Join-Path $Dir $t) } }
        $layers.Add([pscustomobject]@{ name = "$($m.name)"; version = "$($m.version)"; kind = "$($m.kind)"; role = $Role; dir = (Resolve-Path -LiteralPath $Dir).Path; trees = $trees; sql = @($m.PSObject.Properties['sql'] ? $m.sql : @()) })
    }
    $ref = { param([string]$r) if ($r -match '^(?<n>[a-z0-9-]+)@(?<v>.+)$') { return @{ n = $Matches['n']; v = $Matches['v'] } } else { return @{ n = $r; v = '' } } }
    $base = & $ref "$($spec.from)"; & $addLayer (Join-Path $DistributionRoot "layers/$($base.n)") 'base' $base.v
    foreach ($r in @($spec.PSObject.Properties['add'] ? $spec.add : @())) { $x = & $ref "$r"; & $addLayer (Join-Path $DistributionRoot "layers/$($x.n)") 'add' $x.v }
    $surfaces = @($spec.PSObject.Properties['surfaces'] ? $spec.surfaces : @())
    foreach ($r in $surfaces) { $x = & $ref "$r"; & $addLayer (Join-Path $DistributionRoot "layers/$($x.n)") 'surface' $x.v }
    $themes = @($spec.PSObject.Properties['themes'] ? $spec.themes : @())
    foreach ($t in $themes) { & $addLayer (Join-Path $DistributionRoot "layers/theme-$t") 'theme' '' }

    $extra = [System.Collections.Generic.List[object]]::new()
    foreach ($p in @($ExtraLayer | ForEach-Object { $_ -split ';' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
        if (-not (Test-Path -LiteralPath $p -PathType Container)) { $problems.Add("extra layer folder '$p' does not exist"); continue }
        $before = $layers.Count; & $addLayer $p 'extra' ''
        if ($layers.Count -gt $before) { $extra.Add($layers[$layers.Count - 1]); $layers.RemoveAt($layers.Count - 1) }
    }
    $extraSample = @($extra | Where-Object { $_.kind -eq 'sample-data' })
    $wantsSample = [bool]($spec.PSObject.Properties['sampleData'] -and $spec.sampleData)
    if ($Environment -ne 'test') {
        if ($wantsSample) { $problems.Add("edition $Edition composes the sample data (sampleData true), which is demo data: it is delivered to a test environment only, never to $Environment. Pick an edition without it.") }
        foreach ($e in $extraSample) { $problems.Add("extra layer '$($e.name)' is of kind sample-data (demo data): it is delivered to a test environment only, never to $Environment.") }
    }
    if ($wantsSample -and $extraSample.Count -eq 0) { & $addLayer (Join-Path $DistributionRoot 'layers/sample-data') 'sample-data' '' }
    foreach ($e in $extra) { $layers.Add($e) }

    # The solution repository: what one customer's solution adds to the edition, in a fixed layout.
    #   layers/<name>/               layers in the Distribution's own shape
    #   serializer/<mode>.<name>/    database configuration, one folder per class, <mode> replace or merge,
    #                                each with its <mode>-manifest.json; serializer/config/*.json beside them
    #   files/                       whole files for the host's Files folder
    #   settings.json                { "settings": { "/Globalsettings/...": "value" } }, the approved list
    #   testdata/                    the same three folders again, holding sample data: a test environment only
    $solutionSettings = [System.Collections.Generic.List[object]]::new()
    $withheld = [System.Collections.Generic.List[string]]::new()
    if ($SolutionRoot) {
        if (-not (Test-Path -LiteralPath $SolutionRoot -PathType Container)) { $problems.Add("solution folder '$SolutionRoot' does not exist") }
        else {
            $solution = (Resolve-Path -LiteralPath $SolutionRoot).Path
            $addUnits = {
                param([string]$Root, [string]$Role)
                $kind = if ($Role -eq 'testdata') { 'sample-data' } else { 'solution' }
                $layersDir = Join-Path $Root 'layers'
                if (Test-Path -LiteralPath $layersDir -PathType Container) {
                    foreach ($d in (Get-ChildItem -LiteralPath $layersDir -Directory | Sort-Object Name)) {
                        $before = $layers.Count; & $addLayer $d.FullName $Role ''
                        if ($layers.Count -gt $before -and $Role -ne 'testdata' -and $layers[$layers.Count - 1].kind -eq 'sample-data') {
                            $problems.Add("solution layer '$($d.Name)' is of kind sample-data: sample data belongs under testdata/, which reaches a test environment only")
                        }
                    }
                }
                $serializerDir = Join-Path $Root 'serializer'
                if (Test-Path -LiteralPath $serializerDir -PathType Container) {
                    foreach ($d in (Get-ChildItem -LiteralPath $serializerDir -Directory | Where-Object { $_.Name -ne 'config' } | Sort-Object Name)) {
                        if ($d.Name -notmatch '^(?<mode>replace|merge)\.(?<name>[a-z0-9-]+)$') { $problems.Add("'$($d.FullName)' is not named <replace|merge>.<name>"); continue }
                        $unitMode = $Matches['mode']
                        if (-not (Test-Path -LiteralPath (Join-Path $d.FullName "$unitMode-manifest.json") -PathType Leaf)) { $problems.Add("'$($d.FullName)' carries no $unitMode-manifest.json"); continue }
                        $unitTrees = [ordered]@{}; $unitTrees[$unitMode] = $d.FullName
                        $layers.Add([pscustomobject]@{ name = $d.Name; version = ''; kind = $kind; role = $Role; dir = $serializerDir; trees = $unitTrees; sql = @() })
                    }
                }
                $filesDir = Join-Path $Root 'files'
                if (Test-Path -LiteralPath $filesDir -PathType Container) {
                    $fileTrees = [ordered]@{}; $fileTrees['files'] = $filesDir
                    $layers.Add([pscustomobject]@{ name = "$Role-files"; version = ''; kind = $kind; role = $Role; dir = $Root; trees = $fileTrees; sql = @() })
                }
            }
            & $addUnits $solution 'solution'
            $testdata = Join-Path $solution 'testdata'
            if (Test-Path -LiteralPath $testdata -PathType Container) {
                if ($Environment -eq 'test') { & $addUnits $testdata 'testdata' }
                else { $withheld.Add("the solution's testdata/ folder is sample data and is not delivered to $Environment") }
            }
            $settingsPath = Join-Path $solution 'settings.json'
            if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {
                $doc = Read-JsonFile $settingsPath
                if (-not $doc.PSObject.Properties['settings']) { $problems.Add("$settingsPath carries no 'settings' object") }
                else {
                    foreach ($prop in $doc.settings.PSObject.Properties) {
                        if ($prop.Name -notlike '/Globalsettings/*') { $problems.Add("settings.json key '$($prop.Name)' does not start with /Globalsettings/"); continue }
                        # Database, mail, licence and every secret belong to one environment and never travel with a release.
                        if ($prop.Name -match '(?i)password|database|licen[cs]e|smtp|apikey|secret|token|connectionstring') { $problems.Add("settings.json key '$($prop.Name)' names an environment's own configuration or a secret; it never travels with a release"); continue }
                        $solutionSettings.Add([pscustomobject]@{ path = $prop.Name; value = "$($prop.Value)" })
                    }
                }
            }
        }
    }

    # Every content area of the composition lands on ONE website (-AreaId), so a composition serialized from
    # more than one area is refused rather than folded together.
    $areaIds = [System.Collections.Generic.List[int]]::new()
    foreach ($l in $layers) {
        foreach ($t in 'replace', 'merge') {
            if (-not $l.trees.Contains($t)) { continue }
            $manifestPath = Join-Path $l.trees[$t] "$t-manifest.json"
            if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { continue }
            foreach ($e in @((Read-JsonFile $manifestPath).entries)) {
                if ($e -and $e.PSObject.Properties['areaId'] -and $null -ne $e.areaId -and -not $areaIds.Contains([int]$e.areaId)) { $areaIds.Add([int]$e.areaId) }
            }
        }
    }
    if ($areaIds.Count -gt 1) { $problems.Add("the composition carries content of $($areaIds.Count) areas (source ids $(($areaIds | Sort-Object) -join ', ')); this version delivers at most one content area, onto one website") }

    $apps = @()
    foreach ($a in @($contract.compat.apps)) {
        $proven = @($index.gateProven.apps | Where-Object { "$($_.id)" -eq "$($a.id)" }) | Select-Object -First 1
        $apps += [pscustomobject]@{ id = "$($a.id)"; min = "$($a.min)"; required = [bool]$a.required; version = $(if ($proven) { "$($proven.version)" } else { "$($a.min)" }) }
    }
    return [pscustomobject]@{
        edition       = "$($spec.name)"
        environment   = $Environment
        spec          = $spec
        layers        = @($layers.ToArray())
        hasSurface    = ($areaIds.Count -gt 0)
        hasTheme      = ($themes.Count -gt 0)
        apps          = $apps
        dwMin         = "$($contract.compat.dw.min)"
        swiftRelease  = $contract.deliveryTarget.hostFiles.swiftRelease
        requiredSettings = @($contract.deliveryTarget.hostFiles.globalSettings.required)
        solutionSettings = @($solutionSettings.ToArray())
        withheld      = @($withheld.ToArray())
        criticalPaths = @($spec.PSObject.Properties['criticalPaths'] ? $spec.criticalPaths : @())
        personas      = @($contract.sampleData.guaranteedRows.PSObject.Properties | Where-Object { $_.Value.PSObject.Properties['table'] -and "$($_.Value.table)" -eq 'AccessUser' -and $_.Value.PSObject.Properties['id'] -and $_.Value.id } |
                          ForEach-Object { [pscustomobject]@{ role = $_.Name; id = [int]$_.Value.id; userName = "$($_.Value.userName)" } })
        hasDemoData   = (@($layers | Where-Object { $_.kind -eq 'sample-data' }).Count -gt 0)
        gateProven    = $(if ($index.gateProven.editions.PSObject.Properties[$spec.name]) { "$($index.gateProven.editions.($spec.name))" } else { '' })
        problems      = @($problems.ToArray())
    }
}

# ---------------------------------------------------------------------------------------------
# Apps: the Serializer (and any other app the base contract requires) from nuget.org.
# ---------------------------------------------------------------------------------------------
function Get-SerializerState {
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, $Report)
    $r = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/SerializerSettings' -ApiKey $ApiKey -TimeoutSec 120 -LogPath $(if ($Report) { Get-NextLog $Report 'serializer-settings' })
    return @{ present = ($r.Code -eq 200 -and $null -ne $r.Json); code = $r.Code; json = $r.Json; body = $r.Body }
}

function Install-DwApp {
    param(
        [Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Version, [string]$PackageSource = 'https://api.nuget.org/v3-flatcontainer'
    )
    $lower = $Id.ToLowerInvariant(); $v = $Version.ToLowerInvariant()
    $pkgDir = Join-Path $Report.workDir 'packages'; New-Item -ItemType Directory -Force -Path $pkgDir | Out-Null
    $file = Join-Path $pkgDir "$Id.$Version.nupkg"
    if (-not (Test-Path -LiteralPath $file)) {
        try { Invoke-WebRequest -Uri "$PackageSource/$lower/$v/$lower.$v.nupkg" -OutFile $file -TimeoutSec 300 }
        catch { Add-DeployRow $Report "app:$Id" 'FAIL' "could not download $Id $Version from $PackageSource`: $($_.Exception.Message)"; return $false }
    }
    $up = Send-DwFiles -HostUrl $HostUrl -ApiKey $ApiKey -Directory 'System/AddIns/Local' -FilePath @($file) -Report $Report -Label "app-upload-$Id"
    if (-not $up.ok) { Add-DeployRow $Report "app:$Id" 'FAIL' $up.detail; return $false }
    $resp = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/AddinInstall' -Method POST -ApiKey $ApiKey -Body @{ Queue = $false; Ids = @("$Id.$Version|.nupkg") } -LogPath (Get-NextLog $Report "app-install-$Id")
    $judge = Test-CommandResponse -Response $resp -Verb 'AddinInstall'
    if (-not $judge.ok) { Add-DeployRow $Report "app:$Id" 'FAIL' $judge.detail; return $false }
    Add-DeployRow $Report "app:$Id" 'PASS' "$Id $Version uploaded into /Files/System/AddIns/Local and installed ($(Get-Short $judge.message 120))"
    return $true
}

# ---------------------------------------------------------------------------------------------
# Host files: the Swift release asset the base contract pins, whole or only its repositories.
# ---------------------------------------------------------------------------------------------
function Get-SwiftReleaseFiles {
    param([Parameter(Mandatory)]$SwiftRelease, [Parameter(Mandatory)]$Report)
    $dir = Join-Path $Report.workDir 'swift'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $zip = Join-Path $dir "$($SwiftRelease.asset)"
    if (-not (Test-Path -LiteralPath $zip)) { Invoke-WebRequest -Uri "$($SwiftRelease.url)" -OutFile $zip -TimeoutSec 900 }
    $hash = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne "$($SwiftRelease.sha256)".ToLowerInvariant()) { Remove-Item -LiteralPath $zip -Force; throw "The Swift release asset $($SwiftRelease.asset) hashes $hash; the base contract pins $($SwiftRelease.sha256)." }
    $out = Join-Path $dir 'extracted'
    if (-not (Test-Path -LiteralPath (Join-Path $out 'Files'))) { Expand-Archive -LiteralPath $zip -DestinationPath $out -Force }
    $files = Join-Path $out 'Files'
    if (-not (Test-Path -LiteralPath $files -PathType Container)) { throw "The Swift release asset has no Files/ folder at its root." }
    return $files
}

# ---------------------------------------------------------------------------------------------
# Compose: the replace/ and merge/ trees of the composed layers become ONE tree per mode with ONE
# manifest. The Serializer deserializes what the manifest names, so a per-layer copy that lets the
# last layer's manifest win would deliver that one layer and still report success.
#
#   * Entries are merged in composition order. In replace mode an entryId a later layer ships again
#     replaces the earlier entry (source wins) and is counted as an override; in merge mode entries
#     are additive, and an entryId more than one layer contributes is counted as a duplicate.
#   * Files are copied in composition order, so a path two layers ship is last-wins and counted.
#   * A layer may name a file it does not ship itself, as long as another composed layer does: a
#     feature that adds a page under the surface's website lists the area and ancestor page
#     documents the surface ships. That is checked on the STAGED tree, never per layer.
#   * -AreaId moves every content area id the layers were serialized from onto the target website:
#     manifest entries, the content/area-<n> token of their entryId, and Content predicates.
#   * The layers' config/*.json files are united into one Serializer.config.json: predicates in
#     order (same mode and name: the later layer wins), exclusion maps united, other keys first seen.
# JSON is handled as System.Text.Json nodes, so no value is reinterpreted on the way through.
# ---------------------------------------------------------------------------------------------
# PowerShell resolves node['name'] to the integer indexer, so properties are read and written through these.
function Get-JsonProperty {
    param($Node, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Node) { return $null }
    $value = $null
    # The comma keeps PowerShell from unrolling a JSON object or array into its members on return.
    if ($Node.AsObject().TryGetPropertyValue($Name, [ref]$value)) { return , $value }
    return $null
}
function Set-JsonProperty {
    # Typed variables and plain assignments throughout: an if-expression, a hashtable literal or a
    # subexpression would send a JSON object through the pipeline and unroll it into its members.
    param([Parameter(Mandatory)]$Node, [Parameter(Mandatory)][string]$Name, $Value)
    [System.Text.Json.Nodes.JsonObject]$object = $Node.AsObject()
    [System.Text.Json.Nodes.JsonNode]$jsonValue = $null
    if ($Value -is [System.Text.Json.Nodes.JsonNode]) { $jsonValue = $Value }
    elseif ($Value -is [bool]) { $jsonValue = [System.Text.Json.Nodes.JsonValue]::Create([bool]$Value) }
    elseif ($Value -is [int]) { $jsonValue = [System.Text.Json.Nodes.JsonValue]::Create([int]$Value) }
    elseif ($null -ne $Value) { $jsonValue = [System.Text.Json.Nodes.JsonValue]::Create([string]$Value) }
    if (-not $object.ContainsKey($Name)) { $object.Add($Name, $jsonValue); return }
    # Keep the property where it was: rebuild the object in its original order.
    $keys = [System.Collections.Generic.List[string]]::new()
    $values = [System.Collections.Generic.List[System.Text.Json.Nodes.JsonNode]]::new()
    foreach ($pair in $object) { $keys.Add($pair.Key); $values.Add($pair.Value) }
    $object.Clear()
    for ($n = 0; $n -lt $keys.Count; $n++) {
        if ($keys[$n] -eq $Name) { $object.Add($Name, $jsonValue) } else { $object.Add($keys[$n], $values[$n]) }
    }
}

function New-Composition {
    param([Parameter(Mandatory)]$Plan, [Parameter(Mandatory)]$Report, [int]$AreaId = 0)
    $root = Join-Path $Report.workDir 'SerializeRoot'
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    $layers = @($Plan.layers | Where-Object { $_.trees.Contains('replace') -or $_.trees.Contains('merge') })
    if ($layers.Count -eq 0) { return $null }
    $readNode = { param([string]$Path) , [System.Text.Json.Nodes.JsonNode]::Parse((Get-Content -LiteralPath $Path -Raw -Encoding utf8)) }
    $writeOptions = [System.Text.Json.JsonSerializerOptions]::new(); $writeOptions.WriteIndented = $true
    $writeOptions.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    $unionMap = {
        param($acc, $incoming)     # ordered map name -> List[string]; $incoming is a JsonObject of arrays
        if ($null -eq $incoming) { return }
        foreach ($kv in @($incoming.AsObject())) {
            if (-not $acc.Contains($kv.Key)) { $acc[$kv.Key] = [System.Collections.Generic.List[string]]::new() }
            foreach ($v in @($kv.Value.AsArray())) { $t = "$v"; if (-not $acc[$kv.Key].Contains($t)) { $acc[$kv.Key].Add($t) } }
        }
    }
    $mapNode = {
        param($acc)
        $o = [System.Text.Json.Nodes.JsonObject]::new()
        foreach ($k in $acc.Keys) { $a = [System.Text.Json.Nodes.JsonArray]::new(); foreach ($v in $acc[$k]) { $a.Add([System.Text.Json.Nodes.JsonValue]::Create([string]$v)) }; $o.Add([string]$k, $a) }
        return , $o
    }
    $summary = [ordered]@{}; $failures = [System.Collections.Generic.List[string]]::new(); $filesStaged = 0; $fileOverrides = 0
    foreach ($mode in 'replace', 'merge') {
        $modeRoot = Join-Path $root $mode
        $entries = [System.Collections.Generic.List[object]]::new(); $index = @{}; $owners = @{}
        $exclFields = [ordered]@{}; $exclXml = [ordered]@{}; $fileOwner = @{}; $overrides = 0; $duplicates = 0; $perLayer = [ordered]@{}; $any = $false
        foreach ($l in $layers) {
            if (-not $l.trees.Contains($mode)) { continue }
            $src = (Resolve-Path -LiteralPath $l.trees[$mode]).Path
            $any = $true
            $manifestPath = Join-Path $src "$mode-manifest.json"
            $count = 0
            if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
                $man = & $readNode $manifestPath
                if ("$((Get-JsonProperty $man 'schemaVersion'))" -ne '2') { throw "$manifestPath has schemaVersion '$((Get-JsonProperty $man 'schemaVersion'))'; only schemaVersion 2 manifests are composed." }
                & $unionMap $exclFields (Get-JsonProperty $man 'excludeFieldsByItemType')
                & $unionMap $exclXml (Get-JsonProperty $man 'excludeXmlElementsByType')
                foreach ($e in @((Get-JsonProperty $man 'entries').AsArray())) {
                    if ($null -eq $e) { continue }
                    $entry = $e.DeepClone()
                    if ($AreaId -gt 0 -and $null -ne (Get-JsonProperty $entry 'areaId')) {
                        $from = [int]"$((Get-JsonProperty $entry 'areaId'))"
                        Set-JsonProperty $entry 'areaId' ($AreaId)
                        if ($null -ne (Get-JsonProperty $entry 'entryId')) { Set-JsonProperty $entry 'entryId' ("$((Get-JsonProperty $entry 'entryId'))" -replace "area-$from(?=$|/)", "area-$AreaId") }
                    }
                    $id = if ($null -ne (Get-JsonProperty $entry 'entryId')) { "$((Get-JsonProperty $entry 'entryId'))" } else { '' }
                    if ($mode -eq 'replace' -and $id -and $index.ContainsKey($id)) { $entries[$index[$id]] = $entry; $owners[$id] = $l.name; $overrides++ }
                    else {
                        if ($id -and $owners.ContainsKey($id)) { $duplicates++ }
                        if ($id) { $index[$id] = $entries.Count; $owners[$id] = $l.name }
                        $entries.Add($entry)
                    }
                    $count++
                }
            }
            $perLayer[$l.name] = $count
            foreach ($file in Get-ChildItem -LiteralPath $src -Recurse -File) {
                if ($file.FullName -eq $manifestPath) { continue }
                $rel = $file.FullName.Substring($src.Length).TrimStart('\', '/')
                if ($fileOwner.ContainsKey($rel)) { $fileOverrides++ }
                $fileOwner[$rel] = $l.name
                $to = Join-Path $modeRoot $rel
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $to) | Out-Null
                Copy-Item -LiteralPath $file.FullName -Destination $to -Force
            }
        }
        if (-not $any) { continue }
        $filesStaged += $fileOwner.Count
        $manifest = [System.Text.Json.Nodes.JsonObject]::new()
        Set-JsonProperty $manifest 'schemaVersion' (2); Set-JsonProperty $manifest 'mode' ($mode)
        Set-JsonProperty $manifest 'writtenAtUtc' ([datetime]::UtcNow.ToString('o')); Set-JsonProperty $manifest 'complete' ($true)
        Set-JsonProperty $manifest 'excludeFieldsByItemType' (& $mapNode $exclFields)
        Set-JsonProperty $manifest 'excludeXmlElementsByType' (& $mapNode $exclXml)
        $arr = [System.Text.Json.Nodes.JsonArray]::new(); foreach ($e in $entries) { $arr.Add($e) }
        Set-JsonProperty $manifest 'entries' ($arr)
        New-Item -ItemType Directory -Force -Path $modeRoot | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $modeRoot "$mode-manifest.json"), $manifest.ToJsonString($writeOptions), [System.Text.UTF8Encoding]::new($false))
        # Every file the merged manifest names is on the staged tree, whichever layer shipped it.
        foreach ($e in $entries) {
            if ($null -eq (Get-JsonProperty $e 'files')) { continue }
            foreach ($f in @((Get-JsonProperty $e 'files').AsArray())) {
                $name = "$f"
                if ($name -and -not (Test-Path -LiteralPath (Join-Path $modeRoot $name) -PathType Leaf)) { $failures.Add("$mode entry '$((Get-JsonProperty $e 'entryId'))' names a file no composed layer ships: $name") }
            }
        }
        $summary[$mode] = [ordered]@{ perLayer = $perLayer; entries = $entries.Count; overrides = $overrides; duplicates = $duplicates; files = $fileOwner.Count }
    }
    # The united Serializer configuration.
    $config = [System.Text.Json.Nodes.JsonObject]::new(); $predicates = [System.Collections.Generic.List[object]]::new(); $predicateIndex = @{}
    $cfgExclFields = [ordered]@{}; $cfgExclXml = [ordered]@{}; $configFiles = 0
    foreach ($l in $layers) {
        $dir = Join-Path $l.dir 'config'
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
        foreach ($cf in Get-ChildItem -LiteralPath $dir -File -Filter '*.json' | Sort-Object Name) {
            $configFiles++
            $c = & $readNode $cf.FullName
            foreach ($kv in @($c.AsObject())) {
                if ($kv.Key.StartsWith('_') -or $kv.Key -in 'predicates', 'excludeFieldsByItemType', 'excludeXmlElementsByType') { continue }
                if ($config.ContainsKey($kv.Key)) { continue }
                [System.Text.Json.Nodes.JsonNode]$copy = $null
                if ($null -ne $kv.Value) { $copy = $kv.Value.DeepClone() }
                $config.Add([string]$kv.Key, $copy)
            }
            & $unionMap $cfgExclFields (Get-JsonProperty $c 'excludeFieldsByItemType')
            & $unionMap $cfgExclXml (Get-JsonProperty $c 'excludeXmlElementsByType')
            if ($null -eq (Get-JsonProperty $c 'predicates')) { continue }
            foreach ($pn in @((Get-JsonProperty $c 'predicates').AsArray())) {
                if ($null -eq $pn) { continue }
                $p = $pn.DeepClone()
                if ($AreaId -gt 0 -and "$((Get-JsonProperty $p 'providerType'))" -eq 'Content' -and $null -ne (Get-JsonProperty $p 'areaId')) { Set-JsonProperty $p 'areaId' $AreaId }
                $name = "$((Get-JsonProperty $p 'name'))"; $keyOf = "$("$((Get-JsonProperty $p 'mode'))".ToLowerInvariant())|$name"
                if ($name -and $predicateIndex.ContainsKey($keyOf)) { $predicates[$predicateIndex[$keyOf]] = $p }
                else { if ($name) { $predicateIndex[$keyOf] = $predicates.Count }; $predicates.Add($p) }
            }
        }
    }
    $configPath = Join-Path $root 'Serializer.config.json'
    if ($configFiles -gt 0) {
        Set-JsonProperty $config 'excludeFieldsByItemType' (& $mapNode $cfgExclFields)
        Set-JsonProperty $config 'excludeXmlElementsByType' (& $mapNode $cfgExclXml)
        $arr = [System.Text.Json.Nodes.JsonArray]::new(); foreach ($p in $predicates) { $arr.Add($p) }
        Set-JsonProperty $config 'predicates' ($arr)
        [System.IO.File]::WriteAllText($configPath, $config.ToJsonString($writeOptions), [System.Text.UTF8Encoding]::new($false))
    }
    return [pscustomobject]@{
        root = $root; config = $configPath; layers = @($layers | ForEach-Object name); modes = $summary
        predicates = $predicates.Count; files = $filesStaged; fileOverrides = $fileOverrides; failures = @($failures.ToArray())
    }
}

function New-ModeZip {
    param([Parameter(Mandatory)][string]$ModeRoot, [Parameter(Mandatory)][ValidateSet('replace', 'merge')][string]$Mode, [Parameter(Mandatory)][string]$ZipPath)
    if (-not (Test-Path -LiteralPath (Join-Path $ModeRoot "$Mode-manifest.json") -PathType Leaf)) { throw "$Mode-manifest.json is not at the root of '$ModeRoot'." }
    $files = @(Get-ChildItem -LiteralPath $ModeRoot -Recurse -File)
    $bytes = [long](($files | Measure-Object -Property Length -Sum).Sum)
    if ($files.Count -gt $script:PackageLimits.MaxEntries) { throw "The $Mode tree holds $($files.Count) files; the Serializer's limit is $($script:PackageLimits.MaxEntries)." }
    if ($bytes -gt $script:PackageLimits.MaxUnzippedBytes) { throw "The $Mode tree is $bytes bytes unzipped; the Serializer's limit is $($script:PackageLimits.MaxUnzippedBytes)." }
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($ModeRoot, $ZipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    $zipBytes = (Get-Item -LiteralPath $ZipPath).Length
    if ($zipBytes -gt $script:PackageLimits.MaxZipBytes) { throw "The $Mode zip is $zipBytes bytes; the Serializer's limit is $($script:PackageLimits.MaxZipBytes)." }
    return @{ files = $files.Count; bytes = $bytes; zipBytes = $zipBytes }
}

function Invoke-Deserialize {
    param(
        [Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)][ValidateSet('replace', 'merge')][string]$Mode, [switch]$DryRun, [bool]$Strict = $true
    )
    $label = "deserialize:$Mode$(if ($DryRun) { ':dry-run' })"
    $body = [ordered]@{ Mode = $Mode; QuarantineUnresolvableLinks = $true; StrictMode = $Strict }
    if ($DryRun) { $body['IsDryRun'] = $true }
    $q = "mode=$Mode&quarantineUnresolvableLinks=true&strictMode=$("$Strict".ToLowerInvariant())$(if ($DryRun) { '&isDryRun=true' })"
    $resp = Invoke-DwApi -HostUrl $HostUrl -Path "/Admin/Api/Deserialize?$q" -Method POST -ApiKey $ApiKey -Body $body -LogPath (Get-NextLog $Report $label) -TimeoutSec 3600
    $judge = Test-CommandResponse -Response $resp -Verb 'Deserialize'
    $failed = if ($judge.message -match '([0-9]+)\s+failed') { [int]$Matches[1] } else { 0 }
    if ($judge.ok -and $failed -gt 0) { $judge = @{ ok = $false; message = $judge.message; detail = "Deserialize answered ok with $failed failed: $(Get-Short $judge.message 600)" } }
    if ($DryRun -and -not $judge.ok -and $failed -eq 0) {
        # A dry run writes nothing, so a row an earlier entry of the same run creates is not there yet when a later
        # entry looks for it. Such a finding is reported and the real pass, which is strict, decides.
        Add-DeployRow $Report $label 'WARN' (Get-Short $judge.detail 700)
        return $true
    }
    Add-DeployRow $Report $label $(if ($judge.ok) { 'PASS' } else { 'FAIL' }) (Get-Short $judge.detail 700)
    return $judge.ok
}

# ---------------------------------------------------------------------------------------------
# Settings, indexes, verification.
# ---------------------------------------------------------------------------------------------
function Set-DwGlobalSetting {
    <# Read, save when different, read back. Returns @{ ok; changed }. The key resolves only as /Globalsettings/... #>
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report, [Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $read = {
        $r = Invoke-DwApi -HostUrl $HostUrl -Path "/Admin/Api/GlobalSettingByKey?Key=$([uri]::EscapeDataString($Key))" -ApiKey $ApiKey -TimeoutSec 120 -LogPath (Get-NextLog $Report 'setting-read')
        if ($r.Code -ne 200 -or -not $r.Json -or -not $r.Json.PSObject.Properties['model'] -or $null -eq $r.Json.model -or -not $r.Json.model.PSObject.Properties['value']) { return @{ ok = $false; value = ''; detail = "GlobalSettingByKey answered HTTP $($r.Code): $(Get-Short $r.Body)" } }
        return @{ ok = $true; value = "$($r.Json.model.value)" }
    }
    $before = & $read
    if (-not $before.ok) { Add-DeployRow $Report "setting:$Key" 'FAIL' $before.detail; return @{ ok = $false; changed = $false } }
    if ($before.value -eq $Value) { Add-DeployRow $Report "setting:$Key" 'PASS' "already $Value"; return @{ ok = $true; changed = $false } }
    $save = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/GlobalSettingSave' -Method POST -ApiKey $ApiKey -Body @{ Model = @{ Key = $Key; Value = $Value } } -LogPath (Get-NextLog $Report 'setting-save')
    $after = & $read
    if (-not $after.ok -or $after.value -ne $Value) { Add-DeployRow $Report "setting:$Key" 'FAIL' "saved (HTTP $($save.Code)) but it reads back '$($after.value)', not '$Value'"; return @{ ok = $false; changed = $false } }
    Add-DeployRow $Report "setting:$Key" 'PASS' "was '$($before.value)', now reads back '$Value' (takes effect at the next application start)"
    return @{ ok = $true; changed = $true }
}

function Get-SettingsFragmentLeaf {
    <#
    Every leaf of the globalsettings.*.fragment.config files a layer ships under files/, as
    @{ layer; key; value; rule; allowed }. A fragment is never uploaded as the host's settings file: a leaf
    under <Features> is applied one by one (rule replace), /Globalsettings/System/Url/Providers is a comma
    list that is united with the host's own, and any other leaf is refused and reported.
    #>
    param([Parameter(Mandatory)]$Plan)
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($l in $Plan.layers) {
        if (-not $l.trees.Contains('files')) { continue }
        foreach ($f in @(Get-ChildItem -LiteralPath $l.trees['files'] -Recurse -File -Filter 'globalsettings*.fragment.config' | Sort-Object FullName)) {
            $doc = [xml](Get-Content -LiteralPath $f.FullName -Raw)
            if (-not $doc.DocumentElement -or $doc.DocumentElement.LocalName -ne 'Globalsettings') { throw "The fragment $($f.FullName) has no <Globalsettings> root." }
            $walk = {
                param($el, [string]$parent)
                $path = "$parent/$($el.LocalName)"
                $kids = @($el.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })
                if ($kids.Count -gt 0) { foreach ($k in $kids) { & $walk $k $path }; return }
                $union = ($path -ieq '/Globalsettings/System/Url/Providers')
                $rows.Add([pscustomobject]@{ layer = $l.name; key = $path; value = "$($el.InnerText)".Trim()
                    rule = $(if ($union) { 'comma-union' } else { 'replace' }); allowed = ($union -or $path -like '/Globalsettings/Features/*') })
            }
            foreach ($c in @($doc.DocumentElement.ChildNodes | Where-Object { $_.NodeType -eq [System.Xml.XmlNodeType]::Element })) { & $walk $c '/Globalsettings' }
        }
    }
    return $rows.ToArray()
}

function Get-DwGlobalSettingValue {
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)][string]$Key)
    $r = Invoke-DwApi -HostUrl $HostUrl -Path "/Admin/Api/GlobalSettingByKey?Key=$([uri]::EscapeDataString($Key))" -ApiKey $ApiKey -TimeoutSec 120
    if ($r.Code -ne 200 -or -not $r.Json -or -not $r.Json.PSObject.Properties['model'] -or $null -eq $r.Json.model -or -not $r.Json.model.PSObject.Properties['value']) { return $null }
    return "$($r.Json.model.value)"
}

function Set-DwUserPassword {
    <# One UserSetPassword. The value is carried in the request body only and never logged. #>
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report, [Parameter(Mandatory)][int]$UserId, [Parameter(Mandatory)][string]$Label, [Parameter(Mandatory)][securestring]$Password)
    $plain = [System.Net.NetworkCredential]::new('', $Password).Password
    $resp = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/UserSetPassword' -Method POST -ApiKey $ApiKey -Body @{ Model = [ordered]@{ UserId = $UserId; Password = $plain; ConfirmPassword = $plain } }
    $judge = Test-CommandResponse -Response $resp -Verb 'UserSetPassword'
    $detail = if ($judge.ok) { "password set for $Label (user $UserId)" } else { "the password of $Label (user $UserId) was not set: HTTP $($resp.Code)" }
    Add-DeployRow $Report "persona:$Label" $(if ($judge.ok) { 'PASS' } else { 'FAIL' }) $detail
    return $judge.ok
}

function Get-IndexBuildPlan {
    <# Every <Repository>/<Name>.index under the given local repository folders, with the build to run (Full when declared, else the first). #>
    param([string[]]$RepositoryRoot)
    $plan = [ordered]@{}
    foreach ($root in @($RepositoryRoot | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) })) {
        foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.index') {
            $repo = Split-Path -Leaf $f.DirectoryName
            $builds = @()
            try { $xml = [xml](Get-Content -LiteralPath $f.FullName -Raw); $builds = @($xml.SelectNodes('//*[local-name()="Build"]') | ForEach-Object { "$($_.GetAttribute('Name'))" } | Where-Object { $_ }) } catch { $builds = @() }
            $build = if ($builds -contains 'Full') { 'Full' } elseif ($builds.Count -gt 0) { $builds[0] } else { 'Full' }
            $plan["$repo/$($f.Name)"] = [pscustomobject]@{ repository = $repo; indexName = $f.Name; buildName = $build }
        }
    }
    return @($plan.Values)
}

function Invoke-IndexBuild {
    param(
        [Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)][securestring]$ApiKey, [Parameter(Mandatory)]$Report,
        [Parameter(Mandatory)][string]$Repository, [Parameter(Mandatory)][string]$IndexName, [Parameter(Mandatory)][string]$BuildName,
        [bool]$DocumentsExpected = $false, [int]$TimeoutSec = 900
    )
    $step = "index:$Repository/$IndexName"
    foreach ($v in $Repository, $IndexName) { if ($v -notmatch '^[A-Za-z0-9._-]+$') { Add-DeployRow $Report $step 'FAIL' "'$v' is not a valid repository or index file name"; return $false } }
    $posted = [datetime]::UtcNow
    $resp = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/BuildIndex' -Method POST -ApiKey $ApiKey -Body ([ordered]@{ Repository = $Repository; IndexName = $IndexName; BuildName = $BuildName }) -LogPath (Get-NextLog $Report 'index-build')
    $judge = Test-CommandResponse -Response $resp -Verb 'BuildIndex'
    if (-not $judge.ok) { Add-DeployRow $Report $step 'FAIL' $judge.detail; return $false }
    $deadline = $posted.AddSeconds($TimeoutSec); $last = ''; $followUps = 0
    $prop = { param($o, [string[]]$names) foreach ($n in $names) { foreach ($p in $o.PSObject.Properties) { if ($p.Name -ieq $n -and $null -ne $p.Value -and "$($p.Value)" -ne '') { return $p.Value } } }; return $null }
    $toUtc = {
        param($v)
        if ($null -eq $v) { return $null }
        if ($v -is [datetime]) { if ($v.Kind -eq [DateTimeKind]::Unspecified) { return [datetime]::SpecifyKind($v, [DateTimeKind]::Utc) } else { return $v.ToUniversalTime() } }
        $dto = [DateTimeOffset]::MinValue
        if ([DateTimeOffset]::TryParse("$v", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$dto)) { return $dto.UtcDateTime }
        return $null
    }
    while ([datetime]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 5
        $q = "Repository=$([uri]::EscapeDataString($Repository))&IndexName=$([uri]::EscapeDataString($IndexName))"
        $st = Invoke-DwApi -HostUrl $HostUrl -Path "/Admin/Api/IndexStatusByRepositoryAndIndexName?$q" -ApiKey $ApiKey -TimeoutSec 120 -LogPath (Join-Path $Report.logDir "index-status-$Repository.log")
        if ($st.Code -ne 200 -or -not $st.Json) { $last = "status HTTP $($st.Code)"; continue }
        $m = if ($st.Json.PSObject.Properties['model'] -and $null -ne $st.Json.model) { $st.Json.model } else { $st.Json }
        $state = "$(& $prop $m @('State'))"
        $description = "$(& $prop $m @('StateDescription'))"
        $last = "State '$state'$(if ($description) { " ($description)" })"
        $fresh = $false
        foreach ($n in 'LastRun', 'LastSuccessfulRun', 'LastSuccessfulBuild') {
            $utc = & $toUtc (& $prop $m @($n))
            if ($null -ne $utc -and $utc -ge $posted.AddSeconds(-60)) { $fresh = $true }
        }
        if (-not $fresh) { continue }     # nothing of this request has finished yet; a state from before it does not count
        if ($state -notmatch '^(?i)success$') {
            # An index with several instances builds one per request. After the first build the status reads
            # "instance '<other>' must be recovered before other instances can build" until that instance is
            # built too, so one follow-up request per remaining instance is posted, and no more.
            $repair = [bool](& $prop $m @('HasBlockingRepairCandidate'))
            $instances = [int]("$(& $prop $m @('InstanceCount'))" -replace '\D', '0' -replace '^$', '1')
            $next = "$(& $prop $m @('NextBuildTarget'))"; $online = "$(& $prop $m @('OnlineInstance'))"
            if ($repair -and $next -and $next -ne $online -and $followUps -lt ($instances - 1)) {
                $followUps++
                $again = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/BuildIndex' -Method POST -ApiKey $ApiKey -Body ([ordered]@{ Repository = $Repository; IndexName = $IndexName; BuildName = $BuildName }) -LogPath (Get-NextLog $Report 'index-build-followup')
                $last = "follow-up build $followUps for instance '$next' posted (HTTP $($again.Code))"
                Start-Sleep -Seconds 5
                continue
            }
            if ($state -match '^(?i)(error|failed)$' -and -not $repair) { Add-DeployRow $Report $step 'FAIL' "the build $BuildName ended in $last"; return $false }
            continue
        }
        $docs = & $prop $m @('CurrentCount', 'DocumentCount', 'Documents')
        if ($DocumentsExpected -and $null -ne $docs -and [long]$docs -le 0) { Add-DeployRow $Report $step 'FAIL' "the build $BuildName succeeded holding $docs documents although the composition carries products"; return $false }
        Add-DeployRow $Report $step 'PASS' "build $BuildName reached State Success, stamped after the request$(if ($followUps) { " ($followUps follow-up build(s) for the other instance)" })$(if ($null -ne $docs) { ", $docs documents" })"
        return $true
    }
    Add-DeployRow $Report $step 'FAIL' "the build $BuildName did not report a fresh success within $TimeoutSec s (last: $last)"
    return $false
}

function Test-CriticalPath {
    param([Parameter(Mandatory)][string]$HostUrl, [Parameter(Mandatory)]$Report, [string[]]$Path)
    $ok = $true
    foreach ($p in @($Path | Where-Object { $_ })) {
        $code = 0
        try { $r = Invoke-WebRequest -Uri "$($HostUrl.TrimEnd('/'))$p" -SkipHttpErrorCheck -TimeoutSec 120 -MaximumRedirection 5; $code = [int]$r.StatusCode } catch { $code = 0 }
        if ($code -eq 200) { Add-DeployRow $Report "path:$p" 'PASS' 'HTTP 200' } else { Add-DeployRow $Report "path:$p" 'FAIL' "HTTP $code"; $ok = $false }
    }
    return $ok
}

Export-ModuleMember -Function *
