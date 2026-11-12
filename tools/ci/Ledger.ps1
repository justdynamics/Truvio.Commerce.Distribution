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
    # A digest taken from a CRLF checkout validates on that checkout and nowhere else; say so instead of a bare mismatch.
    $crlf=@(Get-LedgerCrlfFile $root)
    if($crlf.Count){throw "Pinned skills checkout has CRLF line endings in $($crlf.Count) snapshot file(s) (first: $($crlf[0])); recreate it with core.autocrlf=false (canonical LF)."}
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
    # What the pinned runner can execute, read from the same checkout: its handler allowlist, and the requirement
    # kinds it has a fact source for (only feature flags, and only when the runner discovers them at all).
    $handlers=@{};$registry=Join-Path $SkillsRoot 'skills/dw-demo-ledger/assets/handlers.json'
    if(Test-Path -LiteralPath $registry -PathType Leaf){$handlers=Read-LedgerJson $registry}
    $factKinds=@();$transport=Join-Path $SkillsRoot 'skills/dw-demo-ledger/scripts/Ledger.Transport.ps1'
    if((Test-Path -LiteralPath $transport -PathType Leaf) -and (Get-Content -LiteralPath $transport -Raw) -match 'function\s+Get-LedgerFeatureFacts\b'){$factKinds=@('flag')}
    return @{root=$root;manifest=$manifest;digest=$digest;functions=$functions;checks=$checks;dwVersion=$meta.dwVersion;handlers=$handlers;factKinds=$factKinds}
}
# Snapshot files that hold a CR LF pair, as paths relative to the release directory.
function Get-LedgerCrlfFile {
    param([string]$Root)
    foreach($file in Get-ChildItem -LiteralPath $Root -File -Recurse){
        if([Text.Encoding]::Latin1.GetString([IO.File]::ReadAllBytes($file.FullName)).Contains("`r`n")){[IO.Path]::GetRelativePath($Root,$file.FullName).Replace('\','/')}
    }
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
        # Both directions: the edition may not carry a blocker that no candidate layer declares either.
        foreach($block in $Edition.delivery.blockers){
            if(-not @($candidateLayers | ForEach-Object {$_.cpq.blockers} | Where-Object {$_.id -ceq $block.id -and $_.reason -ceq $block.reason}).Count){throw 'Candidate edition names a delivery blocker no candidate layer declares.'}
        }
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

# ---- Locked checks that can never pass (Distribution #132 item 1) ----
# Decided from the locked snapshot and the pinned runner alone, no host. One finding per check and rule:
#   no-implemented-binding         every binding of the check is status:planned, so the runner selects none (UNVERIFIED).
#   handler-not-allowlisted        the check has implemented bindings, but none names a handler that the runner's
#                                  assets/handlers.json allows on that binding's surface (ERROR).
#   requirement-not-establishable  the owning function requires a fact the pinned runner has no source for: any
#                                  app, licence or capability requirement; a flag requirement when the runner does
#                                  not discover feature flags, or whose id is a settings path (UNVERIFIED before any
#                                  ruling is read; dynamicweb/skills#222).
function Get-LedgerUnexecutableCheck {
    param($Snapshot,[string[]]$CheckIds)
    foreach($id in $CheckIds){
        $check=$Snapshot.checks[$id];$function=$Snapshot.functions[$check.functionId]
        $implemented=@($check.bindings|Where-Object {$_.status -ceq 'implemented'})
        if(-not $implemented.Count){
            @{check=$id;rule='no-implemented-binding';detail='every binding is planned'}
        }elseif(-not @($implemented|Where-Object {$Snapshot.handlers.ContainsKey([string]$_.handler) -and $_.surface -in $Snapshot.handlers[[string]$_.handler]}).Count){
            @{check=$id;rule='handler-not-allowlisted';detail='handler '+((@($implemented.handler)|Sort-Object -Unique) -join ', ')}
        }
        $blocked=@($function.requires|Where-Object {$_.kind -cnotin $Snapshot.factKinds -or "$($_.id)".StartsWith('/')})
        if($blocked.Count){@{check=$id;rule='requirement-not-establishable';detail='requires '+(($blocked|ForEach-Object {"$($_.kind):$($_.id)"}) -join ', ')}}
    }
}
# contracts/ledger/exceptions.json: the only place a finding above, or a removal below, may be accepted.
# Returns @{unexecutable;removals}; an absent file is an empty register, a malformed one throws.
function ConvertFrom-LedgerExceptions {
    param([string]$Raw)
    $register=@{unexecutable=@();removals=@()}
    if([string]::IsNullOrWhiteSpace($Raw)){return $register}
    Assert-LedgerUniqueJsonKey $Raw 'contracts/ledger/exceptions.json'
    $data=$Raw|ConvertFrom-Json -AsHashtable
    if($data.schemaVersion -ne 1 -or @($data.Keys|Where-Object {$_ -cnotin @('schemaVersion','comment','unexecutable','removals')}).Count){throw 'Invalid ledger exceptions register.'}
    foreach($entry in @($data.unexecutable)){
        if($entry -isnot [Collections.IDictionary]){if($data.ContainsKey('unexecutable') -and $null -ne $data.unexecutable){throw 'Invalid unexecutable entry in the ledger exceptions register.'};continue}
        if(@($entry.Keys|Where-Object {$_ -cnotin @('edition','check','rule','ref','reason')}).Count -or -not $entry.edition -or -not $entry.check -or
            $entry.rule -cnotin @('no-implemented-binding','handler-not-allowlisted','requirement-not-establishable') -or
            "$($entry.ref)" -cnotmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$' -or "$($entry.reason)".Length -lt 10){throw 'Invalid unexecutable entry in the ledger exceptions register.'}
        $register.unexecutable+=,$entry
    }
    foreach($entry in @($data.removals)){
        if($entry -isnot [Collections.IDictionary]){if($data.ContainsKey('removals') -and $null -ne $data.removals){throw 'Invalid removal entry in the ledger exceptions register.'};continue}
        if(@($entry.Keys|Where-Object {$_ -cnotin @('kind','subject','id','ruling','reason')}).Count -or -not $entry.subject -or
            $entry.kind -cnotin @('lock','check','carriage','provides') -or ($entry.kind -cin @('check','provides')) -ne [bool]$entry.id -or
            "$($entry.ruling)" -cnotmatch '^[a-z0-9][a-z0-9-]+$' -or "$($entry.reason)".Length -lt 10){throw 'Invalid removal entry in the ledger exceptions register.'}
        $register.removals+=,$entry
    }
    return $register
}
# Rows @{ok;note;msg} for one validated edition lock. A candidate edition is refused for delivery and cannot claim
# proof, so its unexecutable checks are reported, not failed; everywhere else each finding FAILs unless the
# register names exactly that edition, check and rule, and a register entry that matches no finding FAILs too.
function Test-EditionLedgerExecutable {
    param($Edition,$Plan,$Exceptions)
    $name=[string]$Edition.name;$at=([string]$Edition.ledger.commit).Substring(0,8)
    $findings=@(Get-LedgerUnexecutableCheck $Plan.snapshot $Plan.checkIds)
    $entries=@($Exceptions.unexecutable|Where-Object {$_.edition -ceq $name})
    if($Edition.delivery.status -ceq 'candidate'){
        if($entries.Count){@{ok=$false;msg="ledger ${name}: a candidate edition takes no unexecutable exception; remove its entries from contracts/ledger/exceptions.json"}}
        if($findings.Count){@{ok=$true;note=$true;msg="ledger ${name}: $(@($findings.check|Sort-Object -Unique).Count) of $($Plan.checkIds.Count) locked checks cannot pass at $at (candidate edition, not deliverable)"}}
        return
    }
    $accepted=@()
    foreach($finding in $findings){
        $entry=@($entries|Where-Object {$_.check -ceq $finding.check -and $_.rule -ceq $finding.rule})
        if($entry.Count -eq 1){$accepted+="$($finding.check) [$($finding.rule), $($entry[0].ref)]"}
        elseif($entry.Count){@{ok=$false;msg="ledger ${name}: duplicate exception for '$($finding.check)' ($($finding.rule))"}}
        else{@{ok=$false;msg="ledger ${name}: locked check '$($finding.check)' can never pass at ${at}: $($finding.rule) ($($finding.detail)). Lock a snapshot where it can run, or record it in contracts/ledger/exceptions.json with its reason."}}
    }
    foreach($entry in $entries){
        if(-not @($findings|Where-Object {$_.check -ceq $entry.check -and $_.rule -ceq $entry.rule}).Count){
            @{ok=$false;msg="ledger ${name}: exception for '$($entry.check)' ($($entry.rule)) matches no finding at ${at}; remove the stale entry"}
        }
    }
    if($accepted.Count){@{ok=$true;note=$true;msg="ledger ${name}: $($accepted.Count) locked check(s) cannot pass at ${at}, accepted by contracts/ledger/exceptions.json: $($accepted -join '; ')"}}
}

# ---- Removal of a lock, a locked check or layer carriage (Distribution #132 item 2) ----
# A ledger record is what one tree declares: per edition file whether it carries a lock and which checks, per layer
# whether it carries a ledger block and what it provides, and the removal entries of the exceptions register.
function ConvertTo-LedgerRecord {
    param([hashtable]$Editions,[hashtable]$Layers,[string]$ExceptionsRaw)
    $record=@{editions=@{};layers=@{};removals=@((ConvertFrom-LedgerExceptions $ExceptionsRaw).removals)}
    foreach($name in $Editions.Keys){
        $edition=$Editions[$name]|ConvertFrom-Json -AsHashtable
        $lock=$edition -is [Collections.IDictionary] -and $edition.ContainsKey('ledger') -and $null -ne $edition.ledger
        $record.editions[$name]=@{lock=$lock;checkIds=@(if($lock){$edition.ledger.checkIds})}
    }
    foreach($name in $Layers.Keys){
        $layer=$Layers[$name]|ConvertFrom-Json -AsHashtable
        $carriage=$layer -is [Collections.IDictionary] -and $layer.ContainsKey('ledger') -and $null -ne $layer.ledger
        $record.layers[$name]=@{carriage=$carriage;provides=@(if($carriage){$layer.ledger.provides})}
    }
    return $record
}
function Get-LedgerRecord {
    param([string]$RepoRoot)
    $editions=@{};$layers=@{}
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'editions') -Filter '*.json' -File -ErrorAction SilentlyContinue){
        if($file.Name -ne 'edition.schema.json'){$editions[$file.BaseName]=Get-Content -LiteralPath $file.FullName -Raw}
    }
    foreach($directory in Get-ChildItem -LiteralPath (Join-Path $RepoRoot 'layers') -Directory -ErrorAction SilentlyContinue){
        $manifest=Join-Path $directory.FullName 'layer.json'
        if(Test-Path -LiteralPath $manifest -PathType Leaf){$layers[$directory.Name]=Get-Content -LiteralPath $manifest -Raw}
    }
    $register=Join-Path $RepoRoot 'contracts/ledger/exceptions.json'
    $raw=if(Test-Path -LiteralPath $register -PathType Leaf){Get-Content -LiteralPath $register -Raw}else{''}
    return ConvertTo-LedgerRecord $editions $layers $raw
}
# The same record at a git ref: the merge base with HEAD when history allows it (a shallow CI clone may not), else
# the ref itself, exactly as Get-BaseSpine reads versions/spine.json. Returns @{state;label;record}; state is
# present or unresolved. Nothing is fetched.
function Get-BaseLedgerRecord {
    param([string]$RepoRoot,[string]$BaseRef)
    $null=& git -C $RepoRoot rev-parse --verify --quiet "$BaseRef^{commit}" 2>$null
    if($LASTEXITCODE -ne 0){return @{state='unresolved';label=$BaseRef;record=$null}}
    $mergeBase=(& git -C $RepoRoot merge-base HEAD $BaseRef 2>$null)
    $at=if($LASTEXITCODE -eq 0 -and "$mergeBase".Trim()){"$mergeBase".Trim()}else{$BaseRef}
    $label=if($at -eq $BaseRef){$BaseRef}else{"merge base $($at.Substring(0,8)) of $BaseRef"}
    try{
        $editions=@{};$layers=@{}
        foreach($path in @(& git -C $RepoRoot ls-tree --name-only $at 'editions/' 2>$null)){
            if($path -match '^editions/([^/]+)\.json$' -and $Matches[1] -ne 'edition.schema'){
                $name=$Matches[1];$editions[$name]=(& git -C $RepoRoot show "${at}:$path") -join "`n"
            }
        }
        foreach($path in @(& git -C $RepoRoot ls-tree -d --name-only $at 'layers/' 2>$null)){
            $null=& git -C $RepoRoot cat-file -e "${at}:$path/layer.json" 2>$null
            if($LASTEXITCODE -eq 0){$layers[(Split-Path $path -Leaf)]=(& git -C $RepoRoot show "${at}:$path/layer.json") -join "`n"}
        }
        $raw=''
        $null=& git -C $RepoRoot cat-file -e "${at}:contracts/ledger/exceptions.json" 2>$null
        if($LASTEXITCODE -eq 0){$raw=(& git -C $RepoRoot show "${at}:contracts/ledger/exceptions.json") -join "`n"}
        return @{state='present';label=$label;record=(ConvertTo-LedgerRecord $editions $layers $raw)}
    }catch{return @{state='unresolved';label="$label (ledger record did not parse)";record=$null}}
}
# Rows @{ok;msg}. Against the base record, each of these FAILs unless the head register carries a removal entry
# for it that the base register does not (a ruling is spent by the change that names it, never reused):
#   lock      an edition that carried a lock has none, or its edition file is gone        (subject = edition)
#   check     a check id the edition locked is no longer locked                           (subject = edition, id)
#   carriage  a layer that carried a ledger block has none                                (subject = layer)
#   provides  a function the layer provided is no longer provided                         (subject = layer, id)
# A removed layer directory is not a row of its own: the checks it carried surface as 'check' removals.
# Without a base, a gateProven edition that declares no lock still FAILs. A new removal entry that matches nothing
# removed FAILs, so the register cannot collect permissions ahead of use.
function Test-LedgerRemoval {
    param($Head,$Base,[ValidateSet('present','unresolved','skipped')][string]$BaseState='present',[string]$BaseLabel='base',[string[]]$GateProven=@())
    foreach($name in @($Head.editions.Keys|Sort-Object)){
        if(-not $Head.editions[$name].lock -and $name -in $GateProven){@{ok=$false;msg="ledger ${name}: a gateProven edition must declare a ledger lock"}}
    }
    if($BaseState -eq 'skipped'){@{ok=$true;msg="ledger removal not compared (-SpineBaseRef ''; local runs only)"};return}
    if($BaseState -eq 'unresolved' -or -not $Base){@{ok=$false;msg="ledger removal: cannot read the base ledger record at $BaseLabel, so a removed lock or carriage cannot be ruled out. Fetch the base branch, or pass -SpineBaseRef '' for a local run."};return}
    $key={param($e) "$($e.kind)|$($e.subject)|$($e.id)|$($e.ruling)|$($e.reason)"}
    $spent=@($Base.removals|ForEach-Object {& $key $_})
    $fresh=@($Head.removals|Where-Object {(& $key $_) -cnotin $spent})
    $used=[Collections.Generic.HashSet[string]]::new();$failed=0;$ruled=0
    $removed=@(
        foreach($name in @($Base.editions.Keys|Sort-Object)){
            $was=$Base.editions[$name];if(-not $was.lock){continue}
            $now=$Head.editions[$name]
            if(-not $now){@{kind='lock';subject=$name;id=$null;what="edition '$name' carried a ledger lock and is gone"}}
            elseif(-not $now.lock){@{kind='lock';subject=$name;id=$null;what="edition '$name' no longer declares its ledger lock"}}
            else{foreach($id in @($was.checkIds|Where-Object {$_ -cnotin $now.checkIds})){@{kind='check';subject=$name;id=$id;what="edition '$name' no longer locks check '$id'"}}}
        }
        foreach($name in @($Base.layers.Keys|Sort-Object)){
            $was=$Base.layers[$name];$now=$Head.layers[$name];if(-not $was.carriage -or -not $now){continue}
            if(-not $now.carriage){@{kind='carriage';subject=$name;id=$null;what="layer '$name' no longer declares ledger carriage"}}
            else{foreach($id in @($was.provides|Where-Object {$_ -cnotin $now.provides})){@{kind='provides';subject=$name;id=$id;what="layer '$name' no longer provides '$id'"}}}
        }
    )
    foreach($item in $removed){
        $ruling=@($fresh|Where-Object {$_.kind -ceq $item.kind -and $_.subject -ceq $item.subject -and "$($_.id)" -ceq "$($item.id)"})
        if($ruling.Count){$ruled++;$null=$used.Add((& $key $ruling[0]));@{ok=$true;msg="ledger removal: $($item.what) (ruling $($ruling[0].ruling))"}}
        else{$failed++;@{ok=$false;msg="ledger removal: $($item.what) against $BaseLabel. Restore it, or name the ruling in contracts/ledger/exceptions.json removals (kind '$($item.kind)', subject '$($item.subject)'$(if($item.id){", id '$($item.id)'"}))."}}
    }
    foreach($entry in $fresh){
        if(-not $used.Contains((& $key $entry))){$failed++;@{ok=$false;msg="ledger removal: new register entry ($($entry.kind) $($entry.subject)$(if($entry.id){" $($entry.id)"})) matches nothing removed against $BaseLabel"}}
    }
    if(-not $failed -and -not $ruled){@{ok=$true;msg="ledger removal: no lock, locked check or layer carriage removed against $BaseLabel"}}
}