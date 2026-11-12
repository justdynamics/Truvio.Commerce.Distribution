# Synthetic CPQ receipt identities only. Never use as a package or delivery lock.
function Copy-TestData($Data) { ConvertFrom-Json -InputObject (ConvertTo-Json -InputObject $Data -Depth 100) -AsHashtable }
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
    $packages.packages[2].dependsOn=@('CPQ_Admin','Truvio.Commerce.MCP.Host')
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
              read=@{surface='runtime';operation='/cpqapi/model';complete=$true;nextCursor=$null;expectedSubjects=1;observedSubjects=1}
              observed=@{fixtureOnly=$true;sell=$case.expect.sell}}
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
