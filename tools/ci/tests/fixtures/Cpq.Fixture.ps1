# Synthetic CPQ receipt identities only. Never use as a package or delivery lock.
function Copy-TestData($Data) { ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Data -Depth 100) -AsHashtable }
function Set-TestBundledMcp($Packages) {
    $mcp=@($Packages.packages|Where-Object role -EQ 'mcp')[0]
    $mcpHost=@($Packages.packages|Where-Object role -EQ 'mcp-host')[0]
    $assembly=$mcpHost.assemblies[0]
    $assembly.entry="Files/System/AddIns/Installed/$($assembly.name)/lib/$($assembly.tfm)/$($assembly.name).dll"
    $mcp.assemblies+=,$assembly;$mcp.version='0.6.5-beta';$mcp.dependsOn=@();$mcp.nugetDependencies=@()
    $Packages.packages=@($Packages.packages|Where-Object role -NE 'mcp-host')
    $studio=@($Packages.packages|Where-Object role -EQ 'studio')[0]
    $studio.dependsOn=@('CPQ_Admin','DW_CPQ_API','Truvio.Commerce.MCP')
}
# One row payload in the shape contracts/cpq/observation.schema.json fixes: the producer's step
# journal for a case, up to and including -Through, every step agreeing with the independent expectation.
function New-TestObservation($Spec,$Case,$Context,[string]$Operation,[string]$Through='document') {
    $steps=@{}
    foreach($op in @('render','recalculate','save','reopen','revision','cart','quote','document')){
        $seen=@{hostId=$Context.hostId;caseId=$Case.id;modelVersionId=$Context.modelVersionId;erpCalls=0}
        if($op -eq 'render'){$seen.rendered=$true;$seen.dwErrors=0;$seen.theme=$Spec.page.theme}
        else{
            $seen.valid=$Case.expect.valid
            if($Case.expect.valid){
                $seen.bom=Copy-TestData $Case.expect.bom;$seen.sell=$Case.expect.sell
                if($op -eq 'recalculate' -and $Case.expect.Contains('beforeDiscount')){$seen.beforeDiscount=$Case.expect.beforeDiscount}
                if($op -ne 'recalculate'){$seen.destinationId=$Case.id+'.'+$op;$seen.readBack=$true;$seen.ownerVerified=$true}
            }
        }
        $steps[$op]=@{result='PASS';read=@{complete=$true;nextCursor=$null;expectedSubjects=1;observedSubjects=1};observed=$seen}
        if($op -eq $Through){break}
    }
    return @{operation=$Operation;steps=$steps;reason='Synthetic fixture journal; not a measured configuration.'}
}
function New-TestFixture {
    $spec = Read-CpqJson (Join-Path $script:contractRoot 'examples/neutral-workbench.json')
    # Synthetic identities and hashes. These are never installable package or live proof fixtures.
    $packages = @{
        schemaVersion=1; kind='cpq-packages'; engineProfile=$spec.engineProfile; dwVersion='10.29.8'
        packages=@(
            @{id='CPQ_Admin'; version='10.24.2'; role='admin'},
            @{id='DW_CPQ_API'; version='10.24.2'; role='runtime'},
            @{id='Truvio.Commerce.CpqStudio'; version='0.7.0'; role='studio'},
            @{id='Truvio.Commerce.MCP'; version='0.6.5'; role='mcp'},
            @{id='Truvio.Commerce.MCP.Host'; version='0.6.5'; role='mcp-host'},
            @{id='DocumentFormat.OpenXml'; version='3.3.0'; role='dependency'}
        )
    }
    foreach ($package in $packages.packages) {
        $package.source=@{kind='vendor';uri='https://packages.example.invalid/'+$package.id}
        $package.sha256='sha256:'+('a'*64)
        $package.assemblies=@(@{name=$package.id;version=$package.version+'.0';tfm='net10.0';sha256='sha256:'+('b'*64)})
        $package.dependsOn=@()
    }
    $packages.packages[2].dependsOn=@('CPQ_Admin','DW_CPQ_API','Truvio.Commerce.MCP','Truvio.Commerce.MCP.Host')
    $packages.packages[2].nugetDependencies=@()
    $packages.packages[1].dependsOn=@('DocumentFormat.OpenXml')
    $packages.packages[3].dependsOn=@('Truvio.Commerce.MCP.Host')
    $packages.packages[5].assemblies[0].tfm='netstandard2.0'
    $behavior=@{
        schemaVersion=1;kind='cpq-contract-v1';engineProfile=$spec.engineProfile
        specDigest=(Get-CpqDigest $spec);packageLockDigest=(Get-CpqDigest $packages);maxAgeSeconds=300
        checks=@(@{id='cpq.pricing.results';functionId='cpq.pricing';caseIds=@('small-fixed','large-discount');observation='model';minimumSubjects=1})
    }
    $context=@{
        hostId='fixture-host';release='editions/cpq-demo/1.0.0';distributionCommit=('1'*40)
        runId='fixture-run';deliveryRunId='fixture-delivery';dwVersion='10.29.8'
        modelKey=$spec.id;modelId=100001;modelVersionId=100002;modelDigest='sha256:'+('c'*64)
        specDigest=(Get-CpqDigest $spec);catalogueDigest=(Get-CpqDigest $spec.catalogue)
        packageLockDigest=(Get-CpqDigest $packages);behaviorDigest=(Get-CpqDigest $behavior)
        ledger=@{repo='dynamicweb/skills';commit=('2'*40);manifest='skills/dw-demo-ledger/assets/releases/10.29.8/manifest.json';digest='sha256:'+('d'*64);checkIds=@('cpq.pricing.results')}
        loadedAssemblies=@(foreach($package in $packages.packages){ foreach($assembly in $package.assemblies){
            @{packageId=$package.id;packageVersion=$package.version;name=$assembly.name;version=$assembly.version;tfm=$assembly.tfm;sha256=$assembly.sha256}
        }})
    }
    $receipt=@{
        schemaVersion=1;kind='cpq-behavior-receipt';startedAt='2026-01-01T12:01:00Z';completedAt='2026-01-01T12:01:20Z'
        before=(Copy-TestData $context);after=(Copy-TestData $context)
        observations=@(foreach($id in $behavior.checks[0].caseIds){
            $case=@($spec.cases | Where-Object id -EQ $id)[0]
            @{checkId='cpq.pricing.results';caseId=$id;inputDigest=(Get-CpqDigest $case.answers)
              expectationDigest=(Get-CpqDigest $case.expect);result='PASS'
              read=@{surface='file';operation='bounded-experiment-journal';complete=$true;nextCursor=$null;expectedSubjects=1;observedSubjects=1}
              observed=(New-TestObservation $spec $case $context 'recalculate')}
        })
    }
    return @{spec=$spec;packages=$packages;behavior=$behavior;context=$context;receipt=$receipt;digest=(Get-CpqDigest $receipt)}
}
function Assert-TestReceipt($Fixture, [switch]$Rehash) {
    $digest=if($Rehash){Get-CpqDigest $Fixture.receipt}else{$Fixture.digest}
    Assert-CpqReceipt -Receipt $Fixture.receipt -Context $Fixture.context -Behavior $Fixture.behavior `
        -Spec $Fixture.spec -Packages $Fixture.packages -ExpectedReceiptDigest $digest `
        -NotBefore ([datetimeoffset]'2026-01-01T12:00:00Z') -Now ([datetimeoffset]'2026-01-01T12:02:00Z') -ContractRoot $script:contractRoot
}
