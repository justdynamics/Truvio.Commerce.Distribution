<#
.SYNOPSIS
WRITES: local CPQ candidate JSON files and an optional drift-checked plan. Never applies.
.DESCRIPTION
PowerShell 7. See contracts/cpq/compiler.md. No network, SQL, deployment or target switches.
.PARAMETER SpecFile
Portable spec JSON; duplicate properties and unsupported constructs are errors.
.PARAMETER OutDirectory
Explicit local artifact directory. Files are deterministic UTF-8 JSON without a BOM.
.PARAMETER IdentityMapFile
Optional previously reviewed identity map; model identities must match.
.PARAMETER ObservedFile
Optional independent complete owned-row and occupied-ID read, for planning only.
.PARAMETER ExpectedObservedDigest
Trusted digest of ObservedFile's parsed content, from the measurement record.
.PARAMETER PreviousFile
Previous ownership record from a completed delivery, not a proposed plan taken as applied.
.PARAMETER PreviousDigest
Trusted digest of PreviousFile from that delivery record.
.EXAMPLE
./tools/ci/Compile-CpqSpec.ps1 -SpecFile ./contracts/cpq/examples/neutral-workbench.json -OutDirectory $artifacts
#>
#Requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SpecFile,[Parameter(Mandatory)][string]$OutDirectory,
    [string]$IdentityMapFile,[string]$ObservedFile,[string]$ExpectedObservedDigest,[string]$PreviousFile,[string]$PreviousDigest)
$ErrorActionPreference='Stop'
try {
    . (Join-Path $PSScriptRoot 'Cpq.Contracts.ps1')
    . (Join-Path $PSScriptRoot 'Cpq.Compiler.ps1')
    . (Join-Path $PSScriptRoot 'Cpq.Plan.ps1')
    $contracts=Join-Path $PSScriptRoot '../../contracts/cpq'
    $spec=Read-CpqJson $SpecFile
    $map=if($IdentityMapFile){Read-CpqJson $IdentityMapFile}else{$null}
    $candidate=ConvertTo-CpqCandidate $spec $contracts $map
    $artifacts=@{'candidate.json'=$candidate;'table-rows.json'=$candidate.rows;'identity-map.json'=$candidate.identityMap;'delivery-requirements.json'=$candidate.deliveryRequirements}
    $native=@(foreach($row in $candidate.rows){foreach($key in @($row.values.Keys | Sort-Object -CaseSensitive)){
        if($key -match 'Conditions$|Actions(?:Else)?$|BomItems$|^InputOptions$|^InputSettings$'){
            $text=$row.values[$key];$value=if($text){ConvertFrom-Json -InputObject $text -AsHashtable -NoEnumerate}else{@()}
            @{table=$row.table;id=$row.id;column=$key;json=$value}
        }
    }})
    $artifacts['vendor-json.json']=$native
    if($ObservedFile){
        $observed=Read-CpqJson $ObservedFile;$previous=if($PreviousFile){Read-CpqJson $PreviousFile}else{$null}
        $artifacts['apply-plan.json']=New-CpqApplyPlan $candidate $observed $ExpectedObservedDigest $previous $PreviousDigest
    } elseif($PreviousFile -or $ExpectedObservedDigest -or $PreviousDigest){throw 'Planning arguments require an observed read.'}
    # Validate and plan everything before writing any output, including refusal paths.
    $null=New-Item -ItemType Directory -Path $OutDirectory -Force
    foreach($name in $artifacts.Keys){[IO.File]::WriteAllText((Join-Path $OutDirectory $name),(ConvertTo-CpqCanonicalJson $artifacts[$name])+"`n",[Text.UTF8Encoding]::new($false))}
    Write-Host "CPQ candidate: $($candidate.rows.Count) rows; applyAllowed=false. Review delivery-requirements.json."
} catch {Write-Error $_;exit 1}
