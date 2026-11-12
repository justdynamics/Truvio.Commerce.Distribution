BeforeAll {
    . (Join-Path $PSScriptRoot '../Cpq.Contracts.ps1')
    . (Join-Path $PSScriptRoot '../Cpq.Receipts.ps1')
    $script:contractRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../contracts/cpq')).Path
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
}

Describe 'CPQ typed declaration and reference rules' {
    BeforeEach { $f=New-TestFixture }
    It 'accepts the neutral business spec without claiming to execute it' {
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Not -Throw
    }
    It 'rejects unknown root and nested fields' {
        $f.spec.silentSetting='ignored'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*schema*'
        $f.spec.Remove('silentSetting');$f.spec.inputs[0].silentSetting=$true
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*schema*'
    }
    It 'rejects unknown operators and the vendor object-test trap' {
        foreach($condition in @(@{'=='=@('$input.Build_Size','large')},@{left='x';operator='eq';right='x'},@{and=@(@{novalue='$input.Build_Size'})})) {
            $f.spec.inputRules[0].when=$condition
            { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*schema*'
        }
    }
    It 'rejects an uncharacterized engine profile' {
        $f.spec.engineProfile='carrot-latest'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*schema*'
    }
    It 'rejects duplicate and unresolved identities' {
        $f.spec.inputs[1].key=$f.spec.inputs[0].key.ToLowerInvariant()
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*duplicate*'
        $f=New-TestFixture;$f.spec.inputRules[0].when.eq[0]='$input.Missing'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*reference*'
    }
    It 'rejects unknown products, groups and action options' {
        $f.spec.bom[0].sku='MISSING'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*product*'
        $f=New-TestFixture;$f.spec.inputs[0].group='Missing'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*group*'
        $f=New-TestFixture;$f.spec.inputRules[0].then[0].allowOptions.values=@('hovering')
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*option*'
    }
    It 'rejects ambiguous rule order and invalid declared defaults' {
        $second=Copy-TestData $f.spec.inputRules[0];$second.id='second-rule';$f.spec.inputRules+=@($second)
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*order*'
        $f=New-TestFixture;$f.spec.inputs[2].default=3
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*bounds*'
    }
    It 'rejects a text input or literal variable used as a numeric quantity' {
        $f.spec.bom[0].quantity='$input.Build_Label'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*number input*'
        $f=New-TestFixture;$f.spec.variables=@(@{key='Count';value='forminput[Build_Drawers]'})
        $f.spec.bom[0].quantity='$variable.Count'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*positive number*'
    }
    It 'validates lookup references without accepting arbitrary SQL' {
        $f.spec.lookups=@(@{key='frames';source='catalogue';valueField='key';labelField='key';where=@{gt=@('$product.price',0)};limit=20})
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Not -Throw
        $f.spec.lookups[0].sql='SELECT * FROM CPQInput'
        { Assert-CpqSpec $f.spec $script:contractRoot } | Should -Throw '*schema*'
    }
    It 'rejects duplicate JSON keys before conversion can erase them' {
        $path=Join-Path $TestDrive 'duplicate.json'
        [IO.File]::WriteAllText($path,'{"x":{"a":1,"a":2}}')
        { Read-CpqJson $path } | Should -Throw '*Duplicate JSON*'
    }
    It 'canonicalizes object order while preserving arrays' {
        (Get-CpqDigest @{b=2;a=1}) | Should -BeExactly (Get-CpqDigest @{a=1;b=2})
        (Get-CpqDigest @(1,2)) | Should -Not -Be (Get-CpqDigest @(2,1))
    }
}

Describe 'CPQ package and behavior binding' {
    BeforeEach { $f=New-TestFixture }
    It 'accepts a structurally complete synthetic lock and behavior declaration' {
        { Assert-CpqPackages $f.packages $script:contractRoot; Assert-CpqBehavior $f.behavior $f.spec $f.packages $script:contractRoot } | Should -Not -Throw
    }
    It 'rejects package/entry assembly mismatch and duplicate loaded identities' {
        $f.packages.packages[0].assemblies[0].name='RenamedAdmin'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*entry assembly*'
        $f=New-TestFixture;$f.packages.packages[1].assemblies+=@((Copy-TestData $f.packages.packages[0].assemblies[0]))
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*Duplicate loaded*'
    }
    It 'rejects missing package identity or digest' {
        $f.packages.packages[0].Remove('id')
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*schema*'
        $f=New-TestFixture;$f.packages.packages[0].sha256='sha256:'+('0'*64)
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*digest*'
    }
    It 'rejects drift from the declared app profile' {
        $f.packages.packages[0].version='10.24.3'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*engine profile*'
    }
    It 'rejects unlocked dependencies and cycles' {
        $f.packages.packages[0].dependsOn=@('Missing')
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*not locked*'
        $f.packages.packages[0].dependsOn=@('DW_CPQ_API');$f.packages.packages[1].dependsOn=@('CPQ_Admin')
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*cycle*'
    }
    It 'rejects absent MCP and DOCX dependencies and an MCP release below the Studio floor' {
        $f.packages.packages=@($f.packages.packages | Where-Object role -NE 'mcp-host')
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*mcp-host package*'
        $f=New-TestFixture;$f.packages.packages[3].version='0.6.5-beta'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*floor*'
        $f=New-TestFixture;$f.packages.packages[2].dependsOn=@('CPQ_Admin')
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*incomplete*'
        $f=New-TestFixture;$f.packages.packages[5].assemblies[0].name='DocumentFormat.OpenXml.Other'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*DOCX*'
    }
    It 'rejects secret-shaped source locators and an unpinned source build' {
        $f.packages.packages[0].source.uri='https://packages.example.invalid/app?credential=fixture'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*source*'
        $f=New-TestFixture;$f.packages.packages[2].source.kind='build'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*schema*'
    }
    It 'rejects wrong content digests and unowned checks' {
        $f.spec.version=2
        { Assert-CpqBehavior $f.behavior $f.spec $f.packages $script:contractRoot } | Should -Throw '*digest*'
        $f=New-TestFixture;$f.behavior.checks[0].functionId='cpq.bom'
        { Assert-CpqBehavior $f.behavior $f.spec $f.packages $script:contractRoot } | Should -Throw '*ownership*'
    }
}

Describe 'CPQ receipts are bound evidence, not a readiness verdict' {
    BeforeEach { $f=New-TestFixture }
    It 'accepts the complete matching envelope and returns no PASS verdict' {
        $result=Assert-TestReceipt $f
        $result | Should -BeNullOrEmpty
    }
    It 'preserves a valid FAIL outcome without calling it ready' {
        $f.receipt.observations[0].result='FAIL'
        { Assert-TestReceipt $f -Rehash } | Should -Not -Throw
        $f.receipt.observations[0].result | Should -BeExactly 'FAIL'
    }
    It 'rejects an altered observation against the trusted receipt digest' {
        $f.receipt.observations[0].observed.sell='0.00'
        { Assert-TestReceipt $f } | Should -Throw '*trusted record*'
    }
    It 'rejects foreign hosts and runtime drift even with a rehashed envelope' {
        $f.receipt.before.hostId='another-host'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*identity differs*'
        $f=New-TestFixture;$f.receipt.after.loadedAssemblies[0].sha256='sha256:'+('e'*64)
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*identity differs*'
    }
    It 'rejects stale, future and pre-delivery timestamps' {
        foreach($time in @('2026-01-01T11:59:59Z','2026-01-01T12:03:00Z')) {
            $f.receipt.startedAt=$time;$f.receipt.completedAt=$time
            { Assert-TestReceipt $f -Rehash } | Should -Throw '*stale*'
        }
        $f=New-TestFixture;$f.behavior.maxAgeSeconds=20
        $f.context.behaviorDigest=Get-CpqDigest $f.behavior;$f.receipt.before=Copy-TestData $f.context;$f.receipt.after=Copy-TestData $f.context
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*stale*'
    }
    It 'rejects incomplete reads, continuations and dishonest counts' {
        $f.receipt.observations[0].read.complete=$false
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*schema*'
        $f=New-TestFixture;$f.receipt.observations[0].read.nextCursor='next-page'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*schema*'
        $f=New-TestFixture;$f.receipt.observations[0].read.expectedSubjects=2
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*incomplete*'
    }
    It 'rejects missing, duplicate and unknown check/case rows' {
        $f.receipt.observations=@($f.receipt.observations[0])
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*missing required*'
        $f=New-TestFixture;$f.receipt.observations+=@($f.receipt.observations[0])
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*duplicate*'
        $f=New-TestFixture;$f.receipt.observations[0].caseId='missing-case'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*unexpected*'
    }
    It 'rejects absent identities and a receipt outside the exact ledger lock' {
        $f.receipt.before.Remove('modelVersionId')
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*schema*'
        $f=New-TestFixture;$f.context.ledger.checkIds=@('cpq.bom.results')
        $f.receipt.before=Copy-TestData $f.context;$f.receipt.after=Copy-TestData $f.context
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*outside the ledger lock*'
    }
    It 'rejects a changed golden expectation and SQL without localOnly' {
        $f.receipt.observations[0].expectationDigest='sha256:'+('e'*64)
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*expectation*'
        $f=New-TestFixture;$f.receipt.observations[0].read.surface='sql'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*schema*'
    }
}

Describe 'CPQ layer declarations fail closed' {
    BeforeEach {
        $f=New-TestFixture
        $script:layerRoot=Join-Path $TestDrive 'feature-cpq'
        New-Item -ItemType Directory -Path (Join-Path $script:layerRoot 'cpq') -Force | Out-Null
        foreach($name in @('spec','packages','behavior')) {
            [IO.File]::WriteAllText((Join-Path $script:layerRoot "cpq/$name.json"),(ConvertTo-Json -InputObject $f[$name] -Depth 100))
        }
        $script:layer=@{name='feature-cpq';version='1.0.0';kind='feature';swiftVersion='2.5.0';cpq=@{schemaVersion=1;spec='cpq/spec.json';packages='cpq/packages.json';behavior='cpq/behavior.json'};ledger=@{provides=@('cpq.pricing');requires=@()};asserts=@{behaviorProbes=@(@{kind='cpq-contract-v1';path='/cpq';contract='cpq/behavior.json'})}}
    }
    It 'validates a declared fixture layer without installing it' {
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Not -Throw
        $schema=Join-Path $script:contractRoot '../../layers/layer.schema.json'
        { Assert-CpqSchema $script:layer $schema } | Should -Not -Throw
    }
    It 'rejects unregistered kinds, absent carriage and missing providers' {
        $script:layer.asserts.behaviorProbes[0].kind='cpq-contract-v2'
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw '*matching*'
        $script:layer.Remove('cpq')
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw '*declaration*'
    }
    It 'rejects a missing provider and disabled render proof' {
        $script:layer.ledger.provides=@()
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw '*provider*'
        $script:layer.ledger.provides=@('cpq.pricing');$script:layer.asserts.behaviorProbes[0].renderProof=$false
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw '*render proof*'
    }
    It 'rejects a path escape and an absent file' {
        $script:layer.cpq.spec='../outside.json'
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw
        $script:layer.cpq.spec='cpq/missing.json'
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw
    }
    It 'rejects fixture-skipping behavior and unknown declaration fields' {
        $script:layer.asserts.behaviorProbes[0].requiresFixtures=@('fixture')
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw '*skipped*'
        $script:layer.cpq.command='run-anything'
        { Test-CpqLayerContract $script:layerRoot $script:layer $script:contractRoot } | Should -Throw '*schema*'
    }
}
