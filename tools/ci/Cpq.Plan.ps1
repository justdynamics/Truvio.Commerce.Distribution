<#
.SYNOPSIS
READ-ONLY. Produce an idempotent, drift-checked CPQ row plan; never apply it.
.DESCRIPTION
PowerShell 7; requires Cpq.Contracts.ps1 and Cpq.Compiler.ps1. See contracts/cpq/compiler.md.
Observed contains complete compiler-owned rows plus occupied identities for all proposed IDs.
ExpectedObservedDigest and PreviousDigest come from trusted read/delivery records independently.
.EXAMPLE
New-CpqApplyPlan -Candidate $candidate -Observed $snapshot -ExpectedObservedDigest $readDigest
#>
#Requires -Version 7.0
function New-CpqApplyPlan {
    param($Candidate,$Observed,[string]$ExpectedObservedDigest,$Previous,[string]$PreviousDigest)
    if($Candidate.kind -cne 'cpq-compiler-candidate' -or $Candidate.compiler -cne 'cpq-native/v1' -or $Candidate.applyAllowed -ne $false){throw 'Unknown compiler candidate.'}
    if($Observed.complete -ne $true -or $Observed.rows -isnot [array] -or $Observed.occupied -isnot [array] -or $Observed.modelKey -cne $Candidate.modelKey){throw 'Incomplete owned-row and identity observation.'}
    if((Get-CpqDigest $Observed) -cne $ExpectedObservedDigest){throw 'Observation differs from trusted read record.'}
    if($Previous){
        if((Get-CpqDigest $Previous) -cne $PreviousDigest -or $Previous.modelKey -cne $Candidate.modelKey){throw 'Prior ownership record is not trusted or belongs to another model.'}
        if($Previous.specDigest -cne $Candidate.specDigest -and $Candidate.specVersion -le $Previous.specVersion){throw 'Semantic changes require a new model version.'}
        if($Candidate.specVersion -lt $Previous.specVersion){throw 'Version rollback requires a separate reviewed operation.'}
        foreach($key in $Previous.identityMap.entries.Keys){if($Candidate.identityMap.entries[$key] -ne $Previous.identityMap.entries[$key]){throw 'Compiler identity drift.'}}
    }
    $before=@{};$after=@{}
    foreach($row in $Observed.rows){
        $key=$row.table+'/'+$row.id
        if($before.ContainsKey($key)){throw 'Duplicate observed row.'};$before[$key]=$row
    }
    $previousRows=if($Previous){@($Previous.ownedRows)}else{@()}
    if($Previous -and $Previous.ownedRows -isnot [array]){throw 'Prior delivery lacks its complete owned-row record.'}
    $expected=@{};foreach($row in $previousRows){$key=$row.table+'/'+$row.id;if($expected.ContainsKey($key)){throw 'Duplicate prior ownership.'};$expected[$key]=$row}
    if((ConvertTo-CpqCanonicalJson $before) -cne (ConvertTo-CpqCanonicalJson $expected)){throw 'Target drift: export and reconcile authoring changes before planning.'}
    # Old versions remain owned and unchanged. A new version does not erase history.
    foreach($key in $expected.Keys){$after[$key]=$expected[$key]}
    $incoming=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($row in $Candidate.rows){
        $key=$row.table+'/'+$row.id
        if(-not $incoming.Add($key)){throw 'Duplicate compiled row.'}
        $occupied=@($Observed.occupied | Where-Object {$_.table -ceq $row.table -and $_.id -eq $row.id})
        if($occupied.Count -gt 1 -or ($occupied.Count -eq 1 -and -not $before.ContainsKey($key))){throw 'Proposed identity is occupied outside the owned row set.'}
        if($before.ContainsKey($key) -and $occupied.Count -ne 1){throw 'Occupied identity observation is incomplete.'}
        if($before.ContainsKey($key) -and (ConvertTo-CpqCanonicalJson $before[$key]) -cne (ConvertTo-CpqCanonicalJson $row)){throw 'Compiled row would overwrite an owned version; reconcile identities and create a new version.'}
        $after[$key]=$row
    }
    $operations=@(foreach($key in @($after.Keys | Sort-Object -CaseSensitive)){
        if(-not $before.ContainsKey($key)){@{operation='insert';row=$after[$key]}}
        elseif((ConvertTo-CpqCanonicalJson $before[$key]) -cne (ConvertTo-CpqCanonicalJson $after[$key])){@{operation='update';beforeDigest=(Get-CpqDigest $before[$key]);row=$after[$key]}}
    })
    $record=@{modelKey=$Candidate.modelKey;specVersion=$Candidate.specVersion;specDigest=$Candidate.specDigest;identityMap=$Candidate.identityMap;ownedRows=@($after.Keys | Sort-Object -CaseSensitive | ForEach-Object {$after[$_]})}
    return @{schemaVersion=1;kind='cpq-apply-plan';applyAllowed=$false;candidateDigest=(Get-CpqDigest $Candidate);observedDigest=$ExpectedObservedDigest;operations=$operations;nextOwnership=$record;blockedRequirements=$Candidate.deliveryRequirements}
}
