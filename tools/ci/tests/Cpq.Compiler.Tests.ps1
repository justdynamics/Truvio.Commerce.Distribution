#Requires -Version 7.0
BeforeAll {
    foreach($file in @('Cpq.Contracts.ps1','Cpq.Compiler.ps1','Cpq.Plan.ps1')){. (Join-Path $PSScriptRoot "../$file")}
    $script:contracts=Join-Path $PSScriptRoot '../../../contracts/cpq'
    function New-Spec {Read-CpqJson (Join-Path $contracts 'examples/neutral-workbench.json')}
    function New-Candidate {ConvertTo-CpqCandidate (New-Spec) $contracts}
    function New-EmptyRead {@{modelKey='neutral-workbench';complete=$true;rows=@();occupied=@()}}
    function New-Delivered($candidate){
        $read=New-EmptyRead;$plan=New-CpqApplyPlan $candidate $read (Get-CpqDigest $read)
        $record=$plan.nextOwnership
        $observed=@{modelKey=$candidate.modelKey;complete=$true;rows=$record.ownedRows;occupied=@($record.ownedRows | ForEach-Object {@{table=$_.table;id=$_.id}})}
        return @{record=$record;observed=$observed}
    }
}
Describe 'Offline CPQ compiler and refusal boundary' {
    It 'matches independently authored native golden structures' {
        $c=New-Candidate;$g=Read-CpqJson (Join-Path $contracts 'examples/neutral-workbench.golden.json')
        foreach($table in $g.rowsByTable.Keys){@($c.rows | Where-Object {$_.table -ceq $table}).Count | Should -Be $g.rowsByTable[$table]}
        $r=@($c.rows | Where-Object {$_.table -ceq 'CPQInputRule'})[0].values
        $r.InputRuleType | Should -BeExactly $g.inputRule.InputRuleType
        foreach($key in @('InputRuleConditions','InputRuleActions','InputRuleActionsElse')){
            $r[$key] | Should -BeExactly (ConvertTo-CpqCanonicalJson $g.inputRule[$key])
        }
        $bom=@($c.rows | Where-Object {$_.table -ceq 'CPQBOMRule' -and $_.values.BOMRuleDescription -ceq 'drawers'})[0]
        $bom.values.BOMRuleBomItems | Should -BeExactly (ConvertTo-CpqCanonicalJson $g.drawerBom)
        $price=@($c.rows | Where-Object {$_.table -ceq 'CPQPriceRule'})[0].values
        $price.Conditions | Should -BeExactly (ConvertTo-CpqCanonicalJson $g.discountCondition)
        $price.Discount | Should -BeExactly $g.discount
        $fields=@($c.rows | Where-Object {$_.table -ceq 'CPQInput'} | ForEach-Object {$_.values})
        ($fields.InputName -join ',') | Should -BeExactly 'Build_Size,Build_Base,Build_Drawers,Build_Label'
        ($fields.InputSeq -join ',') | Should -BeExactly '1,2,3,4'
        $fields[0].InputLabel | Should -BeExactly 'Build_Size'
        $case=@((New-Spec).cases | Where-Object {$_.id -ceq 'large-discount'})[0]
        $case.expect.sell | Should -BeExactly $g.sell
        $case.expect.beforeDiscount | Should -BeExactly $g.beforeDiscount
    }
    It 'compiles twice to identical bytes with or without its identity map' {
        $s=New-Spec;$first=ConvertTo-CpqCandidate $s $contracts
        (ConvertTo-CpqCanonicalJson (ConvertTo-CpqCandidate $s $contracts $first.identityMap)) | Should -BeExactly (ConvertTo-CpqCanonicalJson $first)
        (Get-CpqDigest (ConvertTo-CpqCandidate $s $contracts)) | Should -BeExactly (Get-CpqDigest $first)
    }
    It 'keeps unimplemented semantics explicit and cannot produce an apply-ready plan' {
        $c=New-Candidate;$read=New-EmptyRead;$p=New-CpqApplyPlan $c $read (Get-CpqDigest $read)
        $p.applyAllowed | Should -BeFalse;$p.operations.Count | Should -Be 15
        $p.blockedRequirements.Count | Should -Be 5
        (ConvertTo-CpqCanonicalJson $p.blockedRequirements) | Should -Match 'clear-dependent-and-invalidate|maxLength|half-up'
        @($c.rows | Where-Object {$_.table -eq 'CPQModelVersion'})[0].values.ModelVersionActive | Should -BeFalse
    }
    It 'produces a zero-operation second plan after an independently observed delivery' {
        $c=New-Candidate;$d=New-Delivered $c
        $p=New-CpqApplyPlan $c $d.observed (Get-CpqDigest $d.observed) $d.record (Get-CpqDigest $d.record)
        $p.operations.Count | Should -Be 0
    }
    It 'refuses authoring drift even with a freshly trusted read digest' {
        $c=New-Candidate;$d=New-Delivered $c
        $obs=ConvertFrom-Json (ConvertTo-CpqCanonicalJson $d.observed) -AsHashtable
        $obs.rows[0].values.unexpected='author edit'
        {New-CpqApplyPlan $c $obs (Get-CpqDigest $obs) $d.record (Get-CpqDigest $d.record)} | Should -Throw '*drift*'
    }
    It 'refuses partial reads, false digests and unowned identity collisions' {
        $c=New-Candidate;$read=New-EmptyRead;$read.complete=$false
        {New-CpqApplyPlan $c $read (Get-CpqDigest $read)} | Should -Throw '*Incomplete*'
        $read=New-EmptyRead
        {New-CpqApplyPlan $c $read ('sha256:'+('1'*64))} | Should -Throw '*trusted*'
        $read.occupied=@(@{table=$c.rows[0].table;id=$c.rows[0].id})
        {New-CpqApplyPlan $c $read (Get-CpqDigest $read)} | Should -Throw '*occupied*'
    }
    It 'refuses semantic overwrite but preserves old version rows on a new version' {
        $c=New-Candidate;$d=New-Delivered $c;$s=New-Spec;$s.inputs[0].label='Changed'
        $next=ConvertTo-CpqCandidate $s $contracts $c.identityMap
        {New-CpqApplyPlan $next $d.observed (Get-CpqDigest $d.observed) $d.record (Get-CpqDigest $d.record)} | Should -Throw '*new model version*'
        $s.version=2;$next=ConvertTo-CpqCandidate $s $contracts $c.identityMap
        $p=New-CpqApplyPlan $next $d.observed (Get-CpqDigest $d.observed) $d.record (Get-CpqDigest $d.record)
        $next.modelId | Should -Be $c.modelId;$next.modelVersionId | Should -Not -Be $c.modelVersionId
        $p.nextOwnership.ownedRows.Count | Should -Be 29
        @($p.operations | Where-Object {$_.operation -ne 'insert'}).Count | Should -Be 0
    }
    It 'refuses duplicated and foreign identity maps' {
        $c=New-Candidate;$map=$c.identityMap;$map.modelKey='another'
        {ConvertTo-CpqCandidate (New-Spec) $contracts $map} | Should -Throw '*another model*'
        $map=(New-Candidate).identityMap;$keys=@($map.entries.Keys);$map.entries[$keys[1]]=$map.entries[$keys[0]]
        {ConvertTo-CpqCandidate (New-Spec) $contracts $map} | Should -Throw '*colliding*'
    }
    It 'refuses unknown fields, operators, unresolved references and unsupported native constructs' {
        $s=New-Spec;$s.extra='bad';{ConvertTo-CpqCandidate $s $contracts} | Should -Throw
        $s=New-Spec;$s.bom[0].when=@{'=='=@('$input.Build_Size','small')};{ConvertTo-CpqCandidate $s $contracts} | Should -Throw
        $s=New-Spec;$s.bom[0].quantity='$input.Missing';{ConvertTo-CpqCandidate $s $contracts} | Should -Throw
        $s=New-Spec;$s.pricing.additionalMarkupPercent='5';{ConvertTo-CpqCandidate $s $contracts} | Should -Throw '*margin grammar*'
        $s=New-Spec;$s.inputs[0].type='checkbox';{ConvertTo-CpqCandidate $s $contracts} | Should -Throw '*Input type*'
    }
    It 'does not activate a version or hide engine requirements in vendor settings' {
        $c=New-Candidate;$v=@($c.rows | Where-Object {$_.table -ceq 'CPQModelVersion'})[0]
        $v.values.ModelVersionSetting | Should -BeExactly ''
        $c.deliveryRequirements[0].constraints[0].id | Should -BeExactly 'mobile-needs-small'
    }
    It 'refuses the real candidate evidence as an installable package lock' {
        $p=Read-CpqJson (Join-Path $contracts 'packages.candidate.lock.json')
        $p.deployable | Should -BeFalse
        @($p.packages | Where-Object id -EQ DW_CPQ_API)[0].assemblies[0].installedMatchesPackage | Should -BeFalse
        {Assert-CpqPackages $p $contracts} | Should -Throw '*schema*'
    }
}
