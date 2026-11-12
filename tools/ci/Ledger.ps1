<#
.SYNOPSIS
READ-ONLY. Validate layer carriage and an edition's exact skills-ledger lock.
.DESCRIPTION
PowerShell 7. Uses the pinned skills checkout's digest helper, never a copied runner.
No fetch, checkout, host connection, gate stamp or index write. An unreadable lock fails.
.EXAMPLE
Get-EditionLedgerPlan -DistributionRoot $root -Edition $edition -SkillsRoot $skills
#>
#Requires -Version 7.0
function Resolve-LedgerSkillsRoot {
    param([string]$SkillsRoot,[string]$DistributionRoot)
    if(-not $SkillsRoot){$SkillsRoot=$env:TRUVIO_SKILLS_PATH}
    if(-not $SkillsRoot){
        foreach($candidate in @((Join-Path $DistributionRoot '.ledger-skills'),(Join-Path (Split-Path $DistributionRoot -Parent) 'dynamicweb-skills'))){
            if(Test-Path -LiteralPath (Join-Path $candidate 'skills/dw-demo-ledger')){$SkillsRoot=$candidate;break}
        }
    }
    if(-not $SkillsRoot -or -not(Test-Path -LiteralPath $SkillsRoot -PathType Container)){throw 'No skills checkout: pass -SkillsRoot or set TRUVIO_SKILLS_PATH.'}
    return (Resolve-Path -LiteralPath $SkillsRoot).Path
}
function Read-DistributionLedgerSnapshot {
    param($Lock,[string]$SkillsRoot)
    if(-not $Lock -or $Lock.repo -ne 'dynamicweb/skills' -or $Lock.commit -notmatch '^[a-f0-9]{40}$' -or $Lock.digest -notmatch '^sha256:[a-f0-9]{64}$') {throw 'Missing or invalid ledger lock.'}
    $head=& git -C $SkillsRoot rev-parse --verify HEAD 2>$null
    if($LASTEXITCODE -ne 0 -or $head -cne $Lock.commit){throw 'Skills checkout commit differs from the edition ledger lock.'}
    $dirty=@(& git -C $SkillsRoot status --porcelain -- skills/dw-demo-ledger skills/dw-data-access)
    if($LASTEXITCODE -ne 0 -or $dirty.Count){throw 'Pinned skills checkout is dirty or unreadable.'}
    $core=Join-Path $SkillsRoot 'skills/dw-demo-ledger/scripts/Ledger.Core.ps1'
    if(-not(Test-Path -LiteralPath $core -PathType Leaf)){throw 'Pinned skills ledger helper is missing.'}
    . $core
    if($Lock.manifest -notmatch '^skills/dw-demo-ledger/assets/releases/[^/]+/manifest\.json$'){throw 'Invalid ledger manifest path.'}
    $manifest=Resolve-LedgerPath $SkillsRoot $Lock.manifest
    $root=Split-Path $manifest -Parent
    $digest=Get-LedgerDigest $root
    if($digest -cne $Lock.digest){throw 'Ledger snapshot digest mismatch; use the pinned canonical LF checkout.'}
    $meta=Read-LedgerJson $manifest
    $functions=@{};$checks=@{}
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $root 'functions') -Filter '*.json' -File){
        foreach($f in (Read-LedgerJson $file.FullName).functions){
            if($functions.ContainsKey($f.id)){throw 'Duplicate ledger function id.'};$functions[$f.id]=$f
            foreach($ref in $f.checks){
                $check=Read-LedgerJson (Resolve-LedgerPath $root $ref)
                if($check.functionId -ne $f.id -or $checks.ContainsKey($check.id)){throw 'Invalid check ownership or duplicate check id.'}
                $checks[$check.id]=$check
            }
        }
    }
    return @{root=$root;manifest=$manifest;digest=$digest;functions=$functions;checks=$checks;dwVersion=$meta.dwVersion}
}
# ConvertFrom-Json keeps the LAST of two same-named properties, the CPQ contract reader refuses them. Composition
# refuses them too, so one layer.json cannot read differently in the two places (Distribution #133).
function Assert-LedgerUniqueJsonKey {
    param([string]$Raw,[string]$Label)
    $document=[System.Text.Json.JsonDocument]::Parse($Raw)
    try{
        $pending=[Collections.Generic.Stack[System.Text.Json.JsonElement]]::new();$pending.Push($document.RootElement)
        while($pending.Count){
            $node=$pending.Pop()
            if($node.ValueKind -eq 'Object'){
                $names=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
                foreach($property in $node.EnumerateObject()){
                    if(-not $names.Add($property.Name)){throw "Duplicate JSON property '$($property.Name)' in $Label."}
                    $pending.Push($property.Value)
                }
            }elseif($node.ValueKind -eq 'Array'){foreach($item in $node.EnumerateArray()){$pending.Push($item)}}
        }
    }finally{$document.Dispose()}
}
function Get-EditionLedgerLayer {
    param([string]$DistributionRoot,$Edition)
    $names=@(foreach($ref in @($Edition.from)+@($Edition.add)+@($Edition.surfaces)){
        if(-not $ref){continue}
        if($ref -notmatch '^([a-z0-9-]+)@[0-9]+\.[0-9]+\.[0-9]+(?:-candidate)?$'){throw 'Invalid layer reference.'};$Matches[1]
    })
    if($Edition.sampleData){$names+='sample-data'}
    foreach($theme in $Edition.themes){if($theme -notmatch '^[a-z0-9-]+$'){throw 'Invalid theme reference.'};$names+='theme-'+$theme}
    foreach($name in @($names|Select-Object -Unique)){
        $raw=Get-Content -LiteralPath (Join-Path $DistributionRoot "layers/$name/layer.json") -Raw -ErrorAction Stop
        Assert-LedgerUniqueJsonKey $raw "layers/$name/layer.json"
        $raw|ConvertFrom-Json -AsHashtable
    }
}
function Get-EditionLedgerPlan {
    param([string]$DistributionRoot,$Edition,[string]$SkillsRoot,[hashtable]$SkillsRootsByCommit = @{})
    if($SkillsRootsByCommit.ContainsKey([string]$Edition.ledger.commit)){$SkillsRoot=$SkillsRootsByCommit[[string]$Edition.ledger.commit]}
    $SkillsRoot=Resolve-LedgerSkillsRoot $SkillsRoot $DistributionRoot
    $head=& git -C $SkillsRoot rev-parse HEAD 2>$null
    if($Edition.ledger.commit -and $head -cne $Edition.ledger.commit){
        $alternate=if($env:TRUVIO_CPQ_SKILLS_PATH){$env:TRUVIO_CPQ_SKILLS_PATH}else{Join-Path $DistributionRoot '.ledger-skills-cpq'}
        if(Test-Path -LiteralPath $alternate -PathType Container){
            $other=& git -C $alternate rev-parse HEAD 2>$null
            if($LASTEXITCODE -eq 0 -and $other -ceq $Edition.ledger.commit){$SkillsRoot=$alternate}
        }
    }
    $snapshot=Read-DistributionLedgerSnapshot $Edition.ledger $SkillsRoot
    $provided=@();$required=@();$cpqRequired=@()
    $candidateLayers=@()
    foreach($layer in @(Get-EditionLedgerLayer $DistributionRoot $Edition)){
        if(-not $layer.ledger){throw "Layer '$($layer.name)' has no ledger carriage declaration."}
        foreach($id in @($layer.ledger.provides)+@($layer.ledger.requires)){
            if(-not $snapshot.functions.ContainsKey($id)){throw "Layer '$($layer.name)' names unknown ledger function '$id'."}
        }
        if(@($layer.ledger.provides|Where-Object {$_ -in $layer.ledger.requires}).Count){throw "Layer '$($layer.name)' both provides and requires the same function."}
        if($layer.cpq){$cpqRequired+=@($layer.ledger.requires)}
        if($layer.cpq.status -ceq 'candidate'){$candidateLayers+=,$layer}
        $provided+=@($layer.ledger.provides);$required+=@($layer.ledger.requires)
    }
    $provided=@($provided|Sort-Object -Unique)
    if($candidateLayers.Count){
        if($Edition.delivery.status -cne 'candidate'){throw 'Candidate layer requires an explicitly non-deliverable candidate edition.'}
        foreach($layer in $candidateLayers){foreach($block in $layer.cpq.blockers){
            if(-not @($Edition.delivery.blockers | Where-Object {$_.id -ceq $block.id -and $_.reason -ceq $block.reason}).Count){throw 'Candidate edition omits a layer delivery blocker.'}
        }}
        if($Edition.provenOn){throw 'Candidate edition cannot claim proof.'}
    } elseif($Edition.delivery){throw 'Candidate edition has no candidate layer.'}
    $measured=@($provided)+@($cpqRequired)
    $expected=@($snapshot.checks.Values|Where-Object {$_.functionId -in $measured}|ForEach-Object id|Sort-Object)
    $locked=@($Edition.ledger.checkIds)
    if(-not $expected.Count -or -not $locked.Count){throw 'Edition ledger check set must not be empty.'}
    if(@($locked|Sort-Object -Unique).Count -ne $locked.Count){throw 'Duplicate locked ledger check id.'}
    foreach($id in $locked){if(-not $snapshot.checks.ContainsKey($id)){throw "Unknown locked check '$id'."}}
    if(@(Compare-Object $expected @($locked|Sort-Object)).Count){throw 'Edition checkIds must equal the provided functions plus CPQ prerequisites check union at the locked snapshot.'}
    return @{functions=@($measured|Sort-Object -Unique);provides=$provided;requires=@($required|Sort-Object -Unique);checkIds=$locked;snapshot=$snapshot;skillsRoot=$SkillsRoot}
}
