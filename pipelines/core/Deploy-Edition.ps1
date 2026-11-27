#Requires -Version 7.0
<#
.SYNOPSIS
Deliver a Truvio Commerce Distribution edition onto a Dynamicweb 10 host that is reached by its URL
and an Admin API key. The one entry point of the deploy core (pipelines/core): an Azure Pipelines
template, a GitHub Actions workflow and an operator at a prompt all run this script.

.DESCRIPTION
What a run does, in this order. Each stage can also be run on its own with -Stage, which is how a
pipeline shows them as separate steps.

  plan        Resolve the edition into its layers (base, add, surfaces, themes, sample data, extra
              layers), the apps and host files the base contract names. Writes nothing to the host.
  probe       Read the host's Dynamicweb version (floor: base.contract.json compat.dw.min), prove the
              key is accepted and that a request without it is refused.
  apps        Install the apps the base contract requires (the Serializer) from nuget.org, at the
              version layers/INDEX.json gateProven names, when the host does not answer for them yet.
  hostfiles   Push the Swift release asset the base contract pins (sha256 checked).
                full          the whole Files tree: an edition with a surface or a theme
                repositories  only System/Repositories/ProductsBackend: a PIM-only composition
                none          the host already carries its Files
              auto picks full or repositories from the edition.
  layerfiles  Push each layer's files/, templates/, itemtypes/ and repositories/ trees and the
              solution's files/, in composition order. Scheduled index task files wait until the
              content is in.
  settings    Apply the GlobalSettings the base contract requires, the leaves of the settings
              fragments the layers ship and the solution's settings.json, each read back.
  content     Compose everything that ships replace/ and merge/ trees into one tree per mode, upload
              the Serializer config and both zips, unzip both, then per mode a dry run (reported)
              and the real deserialize (strict), replace before merge. On a test environment the
              sample personas then get a password when DW_PERSONA_PASSWORD is set.
  index       Build every repository index the delivery brought, and wait for a fresh success.
  verify      Request the edition's critical paths.

A restart is done when a stage needs one (new apps, item types or repositories, changed settings):
see -Restart. Nothing on the host is deleted by any stage, and every stage can be run again.

The run writes deploy-report.json and a logs folder into -WorkDir and exits 1 when a row failed.
The key is never written to either.

.PARAMETER HostUrl      The host's address, https://shop-test.example.com. No trailing path.
.PARAMETER Edition      An edition name under editions/. base-only is the PIM-only composition.
.PARAMETER Environment  test (default), acceptance or production. Demo data (an edition with
                        sampleData true, an extra layer of kind sample-data) is refused outside test.
.PARAMETER ExtraLayer   Layer folders from outside the Distribution, delivered after the edition's
                        own layers: a customer's data layer. Semicolon separated or repeated.
.PARAMETER SolutionRoot A solution repository in the layout pipelines/README.md describes: layers/,
                        serializer/<mode>.<name>/, files/, settings.json and testdata/. Delivered after
                        the edition; testdata/ only to a test environment.
.PARAMETER ApiKeyFile   A file holding the Admin API key. Without it the key is read from the
                        DW_API_KEY environment variable. There is no parameter that takes the key.
.PARAMETER Stage        One or more stage names, or all (default).
.PARAMETER HostFiles    auto (default), full, repositories or none. See hostfiles above.
.PARAMETER Restart      control-file (default: recycle.txt into System/CloudHosting, Dynamicweb
                        Cloud), command (run -RestartCommand on the agent) or none (report the
                        restart as owed and stop).
.PARAMETER RestartCommand  A PowerShell command line that recycles the application, for -Restart command.
.PARAMETER AreaId       The website the edition's content area lands on. Default 1, the website the
                        stock setup wizard creates. Not used by a composition without a surface.
.PARAMETER DistributionRoot  The Distribution checkout. Default: the one this script is in.
.PARAMETER WorkDir      Where downloads, the composition, the logs and the report go. Default
                        .deploy under the current directory.
.PARAMETER RunName      Names this invocation's report (deploy-report.<RunName>.json) and log folder, so
                        a pipeline that runs the stages as separate steps keeps one report per step.
.PARAMETER DryRun       Run plan, probe and the composition only. Nothing is sent to the host that
                        changes it; the composition under -WorkDir is what a run would deliver. The
                        Serializer's own dry run is part of every real run, before each deserialize.
.PARAMETER NonStrict    Deserialize with strict mode off. An exception, to be named in the run's
                        record; the default is strict.

.EXAMPLE
# PIM only, onto a blank Dynamicweb Cloud solution.
$env:DW_API_KEY = (Get-Content C:\keys\acme-test.dw-apikey -Raw).Trim()
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://acme-test.dynamicweb.cloud -Edition base-only

.EXAMPLE
# The plan only: what would be delivered, nothing sent.
pwsh pipelines/core/Deploy-Edition.ps1 -HostUrl https://acme-test.dynamicweb.cloud -Edition base-only -Stage plan
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$HostUrl,
    [string]$Edition = 'base-only',
    [ValidateSet('test', 'acceptance', 'production')][string]$Environment = 'test',
    [string[]]$ExtraLayer = @(),
    [string]$SolutionRoot,
    [string]$ApiKeyFile,
    [string[]]$Stage = @('all'),
    [ValidateSet('auto', 'full', 'repositories', 'none')][string]$HostFiles = 'auto',
    [ValidateSet('control-file', 'command', 'none')][string]$Restart = 'control-file',
    [string]$RestartCommand,
    [int]$AreaId = 1,
    [string]$DistributionRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,
    [string]$WorkDir = (Join-Path (Get-Location) '.deploy'),
    [string]$RunName = 'all',
    [switch]$DryRun,
    [switch]$NonStrict
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'DeployCore.psm1') -Force

$allStages = @('plan', 'probe', 'apps', 'hostfiles', 'layerfiles', 'settings', 'content', 'index', 'verify')
$Stage = @($Stage | ForEach-Object { $_ -split '[,;]' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
if ($Stage -contains 'all') { $Stage = $allStages }
foreach ($s in $Stage) { if ($allStages -notcontains $s) { throw "Unknown stage '$s'. Stages: $($allStages -join ', '), or all." } }
if ($DryRun) { $Stage = @($Stage | Where-Object { $_ -in 'plan', 'probe', 'content' }) }
if ($HostUrl -notmatch '^https?://[^/]+/?$') { throw "-HostUrl '$HostUrl' must be the host's address only, such as https://shop-test.example.com." }
$HostUrl = $HostUrl.TrimEnd('/')
$strict = -not $NonStrict

if ($RunName -notmatch '^[A-Za-z0-9._-]+$') { throw "-RunName '$RunName' may hold letters, digits, dot, underscore and hyphen only." }
$report = New-DeployReport -WorkDir $WorkDir -RunName $RunName
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pipeline.json') -Raw | ConvertFrom-Json
$report.facts['core'] = "$($manifest.name)@$($manifest.version)"
$report.facts['host'] = $HostUrl
$report.facts['edition'] = $Edition
$report.facts['environment'] = $Environment
$report.facts['stages'] = $Stage
$report.facts['dryRun'] = [bool]$DryRun
try { $report.facts['distributionCommit'] = "$(& git -C $DistributionRoot rev-parse HEAD 2>$null)".Trim() } catch { $report.facts['distributionCommit'] = '' }

function Complete-Run {
    $path = Save-DeployReport -Report $report -Name $(if ($RunName -eq 'all') { 'deploy-report.json' } else { "deploy-report.$RunName.json" })
    $failed = Test-DeployFailed $report
    $rows = @($report.rows)
    Write-Host ''
    Write-Host ("{0}: {1} passed, {2} failed, {3} owed, {4} skipped, {5} warnings. Report: {6}" -f $(if ($failed) { 'FAILED' } else { 'DONE' }),
        @($rows | Where-Object result -eq 'PASS').Count, @($rows | Where-Object result -eq 'FAIL').Count, @($rows | Where-Object result -eq 'OWED').Count,
        @($rows | Where-Object result -eq 'SKIP').Count, @($rows | Where-Object result -eq 'WARN').Count, $path)
    exit $(if ($failed) { 1 } else { 0 })
}

try {
    # ---- plan (always resolved; the stage only decides whether it is printed as a row) -------------
    $plan = Get-EditionPlan -DistributionRoot $DistributionRoot -Edition $Edition -ExtraLayer $ExtraLayer -SolutionRoot $SolutionRoot -Environment $Environment
    $mode = if ($HostFiles -ne 'auto') { $HostFiles } elseif ($plan.hasSurface -or $plan.hasTheme) { 'full' } else { 'repositories' }
    $report.facts['layers'] = @($plan.layers | ForEach-Object { "$($_.name)@$($_.version)" })
    $report.facts['hostFiles'] = $mode
    $report.facts['gateProvenRun'] = $plan.gateProven
    if ($plan.problems.Count -gt 0) { foreach ($p in $plan.problems) { Add-DeployRow $report 'plan' 'FAIL' $p }; Complete-Run }
    if ($Stage -contains 'plan') {
        Add-DeployRow $report 'plan' 'PASS' ("edition $($plan.edition) for $Environment`: " + (@($plan.layers | ForEach-Object { "$($_.name)@$($_.version) [$($_.role): $(@($_.trees.Keys) -join ', ')]" }) -join '; ') + "; host files: $mode")
        if (-not $plan.gateProven) { Add-DeployRow $report 'plan:proof' 'WARN' "edition $($plan.edition) is not in layers/INDEX.json gateProven.editions: no gate run has proven this composition" }
        foreach ($w in $plan.withheld) { Add-DeployRow $report 'plan:testdata' 'SKIP' $w }
        foreach ($l in @($plan.layers | Where-Object { @($_.sql).Count -gt 0 })) {
            Add-DeployRow $report "plan:sql:$($l.name)" 'SKIP' "layer $($l.name) declares $(@($l.sql).Count) SQL script(s); a host reached by URL and key has no SQL route, so they are not run"
        }
    }
    if (@($Stage | Where-Object { $_ -ne 'plan' }).Count -eq 0) { Complete-Run }

    $key = Resolve-DwApiKey -ApiKeyFile $ApiKeyFile
    $restartArgs = @{ HostUrl = $HostUrl; ApiKey = $key; Report = $report; Mode = $Restart; RestartCommand = $RestartCommand }

    # ---- probe -----------------------------------------------------------------------------------
    if ($Stage -contains 'probe') {
        if (-not (Test-DwHost -HostUrl $HostUrl -ApiKey $key -Report $report -MinVersion $plan.dwMin)) { Complete-Run }
    }

    # ---- apps ------------------------------------------------------------------------------------
    if ($Stage -contains 'apps') {
        foreach ($app in @($plan.apps | Where-Object required)) {
            if ($app.id -ne 'Truvio.Commerce.Serializer') { Add-DeployRow $report "app:$($app.id)" 'SKIP' 'no presence check is known for this app; install it by hand'; continue }
            $state = Get-SerializerState -HostUrl $HostUrl -ApiKey $key -Report $report
            if ($state.present) { Add-DeployRow $report "app:$($app.id)" 'PASS' 'already on the host (SerializerSettings answers); left as it is'; continue }
            if (-not (Install-DwApp -HostUrl $HostUrl -ApiKey $key -Report $report -Id $app.id -Version $app.version)) { Complete-Run }
            $state = Get-SerializerState -HostUrl $HostUrl -ApiKey $key -Report $report
            if (-not $state.present) {
                if (-not (Invoke-HostRestart @restartArgs -Reason "load $($app.id)")) { Complete-Run }
                $state = Get-SerializerState -HostUrl $HostUrl -ApiKey $key -Report $report
            }
            if (-not $state.present) { Add-DeployRow $report "app:$($app.id):loaded" 'FAIL' "installed, but SerializerSettings still answers HTTP $($state.code): the app did not load. Check that its version fits the host's Dynamicweb version."; Complete-Run }
            Add-DeployRow $report "app:$($app.id):loaded" 'PASS' 'SerializerSettings answers HTTP 200'
        }
    }

    # ---- hostfiles -------------------------------------------------------------------------------
    $swiftFiles = $null
    $needSwift = ($mode -ne 'none') -and (@($Stage | Where-Object { $_ -in 'hostfiles', 'index' }).Count -gt 0)
    if ($needSwift) { $swiftFiles = Get-SwiftReleaseFiles -SwiftRelease $plan.swiftRelease -Report $report }
    $restartForFiles = $false
    if ($Stage -contains 'hostfiles') {
        if ($mode -eq 'none') { Add-DeployRow $report 'hostfiles' 'SKIP' 'the host keeps its own Files (-HostFiles none)' }
        elseif ($mode -eq 'full') {
            # The host's GlobalSettings files stay the host's: they hold its own configuration, and an upload would
            # replace all of it. The settings the delivery needs are applied one by one in the settings stage.
            $r = Send-DwTree -HostUrl $HostUrl -ApiKey $key -LocalRoot $swiftFiles -RemoteRoot '' -Report $report -Label 'hostfiles' -Exclude { param($f) $f.Name -like 'GlobalSettings*.config' }
            Add-DeployRow $report 'hostfiles' $(if ($r.ok) { 'PASS' } else { 'FAIL' }) "Swift $($plan.swiftRelease.tag) Files, sha256 verified: $($r.detail)"
            if (-not $r.ok) { Complete-Run }
            $restartForFiles = $true
        } else {
            $src = Join-Path $swiftFiles 'System/Repositories/ProductsBackend'
            $r = Send-DwTree -HostUrl $HostUrl -ApiKey $key -LocalRoot $src -RemoteRoot 'System/Repositories/ProductsBackend' -Report $report -Label 'hostfiles'
            Add-DeployRow $report 'hostfiles' $(if ($r.ok) { 'PASS' } else { 'FAIL' }) "the ProductsBackend repository of Swift $($plan.swiftRelease.tag) (sha256 verified), which the PIM reads: $($r.detail)"
            if (-not $r.ok) { Complete-Run }
            $restartForFiles = $true
        }
    }

    # ---- layerfiles ------------------------------------------------------------------------------
    $treeMap = [ordered]@{ files = ''; templates = 'Templates'; itemtypes = 'System/Items'; repositories = 'System/Repositories' }
    $isTask = { param($f) $f.Extension -eq '.task' }
    $isFilesTask = { param($f) $f.Extension -eq '.task' -and $f.FullName -match '[\\/]System[\\/]Repositories[\\/]' }
    if ($Stage -contains 'layerfiles') {
        $total = 0
        foreach ($l in $plan.layers) {
            foreach ($t in $treeMap.Keys) {
                if (-not $l.trees.Contains($t)) { continue }
                $r = Send-DwTree -HostUrl $HostUrl -ApiKey $key -LocalRoot $l.trees[$t] -RemoteRoot $treeMap[$t] -Report $report -Label "layerfiles-$($l.name)-$t" -Exclude $(if ($t -eq 'repositories') { $isTask } elseif ($t -eq 'files') { $isFilesTask } else { $null })
                if (-not $r.ok) { Add-DeployRow $report "layerfiles:$($l.name)/$t" 'FAIL' $r.detail; Complete-Run }
                if ($r.files -gt 0) { Add-DeployRow $report "layerfiles:$($l.name)/$t" 'PASS' $r.detail; $total += $r.files }
                if ($r.files -gt 0 -and ($t -in 'itemtypes', 'repositories' -or ($t -eq 'files' -and (Test-Path -LiteralPath (Join-Path $l.trees[$t] 'System/Repositories'))))) { $restartForFiles = $true }
            }
        }
        if ($total -eq 0) { Add-DeployRow $report 'layerfiles' 'SKIP' 'no composed layer ships a files, templates, itemtypes or repositories tree (index task files wait for the content)' }
    }
    if ($restartForFiles -and -not $DryRun) {
        # Item types and repository definitions are read at application start; a Replace before it fails on a missing table.
        if (-not (Invoke-HostRestart @restartArgs -Reason 'read new item types and repositories')) { Complete-Run }
    }

    # ---- settings --------------------------------------------------------------------------------
    if ($Stage -contains 'settings') {
        $changed = $false
        $required = @($plan.requiredSettings)
        # The Swift release's own settings file is not uploaded over the host's (see hostfiles). The one Swift default
        # the base contract names as needed by the storefront is applied here instead.
        if ($mode -eq 'full') { $required += [pscustomobject]@{ path = '/Globalsettings/Settings/Designs/DoNotIncludeBaseHref'; value = 'True' } }
        $required += @($plan.solutionSettings)
        foreach ($s in $required) {
            $r = Set-DwGlobalSetting -HostUrl $HostUrl -ApiKey $key -Report $report -Key "$($s.path)" -Value "$($s.value)"
            if (-not $r.ok) { Complete-Run }
            if ($r.changed) { $changed = $true }
        }
        if ($required.Count -eq 0) { Add-DeployRow $report 'settings' 'SKIP' 'the base contract requires no GlobalSettings' }
        # The settings fragments the layers ship, leaf by leaf; a fragment file is never the host's settings file.
        foreach ($leaf in @(Get-SettingsFragmentLeaf -Plan $plan)) {
            if (-not $leaf.allowed) { Add-DeployRow $report "setting:$($leaf.key)" 'SKIP' "layer $($leaf.layer) ships this leaf outside <Features>; it is not applied"; continue }
            $value = $leaf.value
            if ($leaf.rule -eq 'comma-union') {
                $current = Get-DwGlobalSettingValue -HostUrl $HostUrl -ApiKey $key -Key $leaf.key
                if ($null -eq $current) { Add-DeployRow $report "setting:$($leaf.key)" 'FAIL' 'the current value could not be read, so the list cannot be united with the host''s own'; Complete-Run }
                $seen = [System.Collections.Generic.List[string]]::new()
                foreach ($t in @(("$current,$value" -split ',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })) { if ($seen -notcontains $t) { $seen.Add($t) } }
                $value = $seen -join ','
            }
            $r = Set-DwGlobalSetting -HostUrl $HostUrl -ApiKey $key -Report $report -Key $leaf.key -Value $value
            if (-not $r.ok) { Complete-Run }
            if ($r.changed) { $changed = $true }
        }
        if ($changed) { if (-not (Invoke-HostRestart @restartArgs -Reason 'apply changed settings')) { Complete-Run } }
    }

    # ---- content ---------------------------------------------------------------------------------
    if ($Stage -contains 'content') {
        $composition = New-Composition -Plan $plan -Report $report -AreaId $(if ($plan.hasSurface) { $AreaId } else { 0 })
        if ($null -eq $composition) { Add-DeployRow $report 'compose' 'SKIP' 'no composed layer ships serialized content' }
        else {
            $describe = @($composition.modes.Keys | ForEach-Object { $m = $composition.modes[$_]; "$_ $($m.entries) entries ($($m.overrides) overridden, $($m.duplicates) contributed twice), $($m.files) files" }) -join '; '
            if ($composition.failures.Count -gt 0) {
                foreach ($f in @($composition.failures | Select-Object -First 20)) { Add-DeployRow $report 'compose' 'FAIL' $f }
                Complete-Run
            }
            Add-DeployRow $report 'compose' 'PASS' "layers $($composition.layers -join ', '): $describe; $($composition.predicates) predicates; $($composition.fileOverrides) file path(s) a later layer overrides"
            $modes = @('replace', 'merge' | Where-Object { Test-Path -LiteralPath (Join-Path $composition.root "$_/$_-manifest.json") -PathType Leaf })
            $serializer = Get-SerializerState -HostUrl $HostUrl -ApiKey $key -Report $report
            if (-not $serializer.present) {
                if ($DryRun) { Add-DeployRow $report 'content' 'SKIP' 'dry run: the host has no Serializer yet, so no dry-run deserialize can be sent; the composition above is what a run would deliver'; Complete-Run }
                Add-DeployRow $report 'content' 'FAIL' "the host does not answer for the Serializer (SerializerSettings HTTP $($serializer.code)); run the apps stage first"; Complete-Run
            }
            if ($DryRun) {
                Add-DeployRow $report 'content' 'SKIP' 'dry run: the composition is not uploaded, because unzipping it would replace the trees the host holds; run without -DryRun to get the dry-run and the real deserialize'
                Complete-Run
            }
            if (Test-Path -LiteralPath $composition.config -PathType Leaf) {
                $up = Send-DwFiles -HostUrl $HostUrl -ApiKey $key -Directory 'System/Serializer' -FilePath @($composition.config) -Report $report -Label 'serializer-config'
                Add-DeployRow $report 'content:config' $(if ($up.ok) { 'PASS' } else { 'FAIL' }) "Serializer.config.json: $($up.detail)"
                if (-not $up.ok) { Complete-Run }
            }
            # Both trees are on the host before the first deserialize: a link into the other tree resolves only then.
            foreach ($m in $modes) {
                $zip = Join-Path $report.workDir "$m.zip"
                $z = New-ModeZip -ModeRoot (Join-Path $composition.root $m) -Mode $m -ZipPath $zip
                $up = Send-DwFiles -HostUrl $HostUrl -ApiKey $key -Directory 'System/Serializer/Upload' -FilePath @($zip) -Report $report -Label "zip-$m" -MaxBytes 512MB
                if (-not $up.ok) { Add-DeployRow $report "content:upload:$m" 'FAIL' $up.detail; Complete-Run }
                $unzip = Invoke-DwApi -HostUrl $HostUrl -Path '/Admin/Api/PackageUnzip' -Method POST -ApiKey $key -Body ([ordered]@{ FilePath = "/Files/System/Serializer/Upload/$m.zip"; Mode = $m }) -LogPath (Get-NextLog $report "unzip-$m")
                $judge = Test-CommandResponse -Response $unzip -Verb 'PackageUnzip'
                Add-DeployRow $report "content:stage:$m" $(if ($judge.ok) { 'PASS' } else { 'FAIL' }) "$($z.files) files, $($z.zipBytes) bytes zipped: $(Get-Short $judge.detail 300)"
                if (-not $judge.ok) { Complete-Run }
            }
            foreach ($m in $modes) {
                if (-not (Invoke-Deserialize -HostUrl $HostUrl -ApiKey $key -Report $report -Mode $m -DryRun -Strict $strict)) { Complete-Run }
                if (-not (Invoke-Deserialize -HostUrl $HostUrl -ApiKey $key -Report $report -Mode $m -Strict $strict)) { Complete-Run }
            }
            if (-not $strict) { Add-DeployRow $report 'content:strict' 'WARN' 'deserialized with strict mode off (-NonStrict); name this exception in the run record' }
        }
        # The scheduled index tasks go in after the content: a build that starts on an empty database leaves the index in error.
        foreach ($l in $plan.layers) {
            $filesRepositories = if ($l.trees.Contains('files')) { Join-Path $l.trees['files'] 'System/Repositories' } else { '' }
            if ($filesRepositories -and (Test-Path -LiteralPath $filesRepositories -PathType Container) -and @(Get-ChildItem -LiteralPath $filesRepositories -Recurse -File -Filter '*.task').Count -gt 0) {
                $r = Send-DwTree -HostUrl $HostUrl -ApiKey $key -LocalRoot $filesRepositories -RemoteRoot 'System/Repositories' -Report $report -Label "tasks-$($l.name)" -Exclude { param($f) $f.Extension -ne '.task' }
                Add-DeployRow $report "content:tasks:$($l.name)" $(if ($r.ok) { 'PASS' } else { 'FAIL' }) "scheduled index task file(s): $($r.detail)"
                if (-not $r.ok) { Complete-Run }
            }
            if (-not $l.trees.Contains('repositories')) { continue }
            $tasks = @(Get-ChildItem -LiteralPath $l.trees['repositories'] -Recurse -File -Filter '*.task')
            if ($tasks.Count -eq 0) { continue }
            $r = Send-DwTree -HostUrl $HostUrl -ApiKey $key -LocalRoot $l.trees['repositories'] -RemoteRoot 'System/Repositories' -Report $report -Label "tasks-$($l.name)" -Exclude { param($f) $f.Extension -ne '.task' }
            Add-DeployRow $report "content:tasks:$($l.name)" $(if ($r.ok) { 'PASS' } else { 'FAIL' }) "scheduled index task file(s): $($r.detail)"
            if (-not $r.ok) { Complete-Run }
        }
        # Sample personas ship without a password. On a test environment one is set from DW_PERSONA_PASSWORD when given.
        if ($plan.hasDemoData -and $Environment -eq 'test' -and @($plan.layers | Where-Object { $_.name -eq 'sample-data' -or $_.role -in 'extra', 'testdata' }).Count -gt 0) {
            $personaPassword = "$([Environment]::GetEnvironmentVariable('DW_PERSONA_PASSWORD'))".Trim()
            if (-not $personaPassword -or $personaPassword -match '^\$\(.+\)$') {
                Add-DeployRow $report 'personas' 'SKIP' "the sample personas ($(@($plan.personas | ForEach-Object userName) -join ', ')) have no password: set the DW_PERSONA_PASSWORD secret to give them one, or set it in the admin"
            } else {
                $secure = ConvertTo-SecureString -String $personaPassword -AsPlainText -Force
                foreach ($p in $plan.personas) { if (-not (Set-DwUserPassword -HostUrl $HostUrl -ApiKey $key -Report $report -UserId $p.id -Label $p.userName -Password $secure)) { Complete-Run } }
                # The user cache holds the old state until the application starts again.
                if (-not (Invoke-HostRestart @restartArgs -Reason 'load the persona passwords')) { Complete-Run }
            }
        }
    }

    # ---- index -----------------------------------------------------------------------------------
    if ($Stage -contains 'index') {
        $roots = @()
        if ($mode -eq 'full' -and $swiftFiles) { $roots += (Join-Path $swiftFiles 'System/Repositories/ProductsBackend'); $roots += (Join-Path $swiftFiles 'System/Repositories/ProductsFrontend') }
        elseif ($mode -eq 'repositories' -and $swiftFiles) { $roots += (Join-Path $swiftFiles 'System/Repositories/ProductsBackend') }
        foreach ($l in $plan.layers) {
            if ($l.trees.Contains('repositories')) { $roots += $l.trees['repositories'] }
            if ($l.trees.Contains('files')) { $roots += (Join-Path $l.trees['files'] 'System/Repositories') }
        }
        $builds = @(Get-IndexBuildPlan -RepositoryRoot $roots)
        if ($builds.Count -eq 0) { Add-DeployRow $report 'index' 'SKIP' 'the delivery brought no repository index' }
        $hasProducts = (@($plan.layers | Where-Object { $_.kind -eq 'sample-data' }).Count -gt 0)
        foreach ($b in $builds) {
            if (-not (Invoke-IndexBuild -HostUrl $HostUrl -ApiKey $key -Report $report -Repository $b.repository -IndexName $b.indexName -BuildName $b.buildName -DocumentsExpected $hasProducts)) { Complete-Run }
        }
    }

    # ---- verify ----------------------------------------------------------------------------------
    if ($Stage -contains 'verify') {
        $serializer = Get-SerializerState -HostUrl $HostUrl -ApiKey $key -Report $report
        $needsSetup = if ($serializer.present -and $serializer.json.PSObject.Properties['model'] -and $serializer.json.model -and $serializer.json.model.PSObject.Properties['needsSetup']) { [bool]$serializer.json.model.needsSetup }
                      elseif ($serializer.present -and $serializer.json.PSObject.Properties['needsSetup']) { [bool]$serializer.json.needsSetup } else { $null }
        if (-not $serializer.present) { Add-DeployRow $report 'verify:serializer' 'FAIL' "SerializerSettings answers HTTP $($serializer.code)" }
        elseif ($needsSetup -eq $true) { Add-DeployRow $report 'verify:serializer' 'FAIL' 'the Serializer reports needsSetup true: the composed configuration is not on the host' }
        else { Add-DeployRow $report 'verify:serializer' 'PASS' "the Serializer answers$(if ($needsSetup -eq $false) { ' with its configuration in place (needsSetup false)' })" }
        [void](Test-CriticalPath -HostUrl $HostUrl -Report $report -Path $plan.criticalPaths)
    }
} catch {
    Add-DeployRow $report 'run' 'FAIL' "$($_.Exception.Message)"
}
Complete-Run
