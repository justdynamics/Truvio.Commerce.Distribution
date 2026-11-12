BeforeAll {
    . (Join-Path $PSScriptRoot '../Cpq.Contracts.ps1')
    . (Join-Path $PSScriptRoot '../Cpq.Receipts.ps1')
    $script:contractRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../contracts/cpq')).Path
    . (Join-Path $PSScriptRoot 'fixtures/Cpq.Fixture.ps1')
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
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*MCP.Host assembly carrier*'
        $f=New-TestFixture;$f.packages.packages[3].version='0.6.5-alpha'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*floor*'
        $f=New-TestFixture;$f.packages.packages[2].dependsOn=@('CPQ_Admin')
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*incomplete*'
        $f=New-TestFixture;$f.packages.packages[5].assemblies[0].name='DocumentFormat.OpenXml.Other'
        { Assert-CpqPackages $f.packages $script:contractRoot } | Should -Throw '*DOCX*'
    }
    It 'accepts MCP <version> at or above the beta floor' -ForEach @(
        @{version='0.6.5-beta'},@{version='0.6.5-BETA'},@{version='0.6.5-beta.1'},
        @{version='0.6.5-rc.1'},@{version='0.6.5'},@{version='0.6.6-alpha'}
    ) {
        $f.packages.packages[3].version=$version
        Assert-CpqPackages $f.packages $script:contractRoot
    }
    It 'rejects MCP <version> below the beta floor' -ForEach @(
        @{version='0.6.4'},@{version='0.6.5-alpha.99'},@{version='0.6.5-123'}
    ) {
        $f.packages.packages[3].version=$version
        {Assert-CpqPackages $f.packages $script:contractRoot}|Should -Throw '*floor*'
    }
    It 'accepts a bundled Host and empty NuGet dependencies while preserving site prerequisites' {
        Set-TestBundledMcp $f.packages
        Assert-CpqPackages $f.packages $script:contractRoot
        $f.packages.packages[2].dependsOn=@('CPQ_Admin','Truvio.Commerce.MCP')
        {Assert-CpqPackages $f.packages $script:contractRoot}|Should -Throw '*incomplete*'
    }
    It 'rejects an older separate Host and an unlocked declared NuGet dependency' {
        $f.packages.packages[4].version='0.6.4-beta'
        {Assert-CpqPackages $f.packages $script:contractRoot}|Should -Throw '*floor*'
        $f=New-TestFixture;$f.packages.packages[2].nugetDependencies=@('Missing')
        {Assert-CpqPackages $f.packages $script:contractRoot}|Should -Throw '*installation graph*'
    }
    It 'rejects a mismatched bundled entry path and duplicate Host carriers' {
        Set-TestBundledMcp $f.packages
        $mcp=$f.packages.packages[3];$a=$mcp.assemblies[1];$entry=$a.entry
        $a.entry=$entry.Replace('/net10.0/','/net8.0/')
        {Assert-CpqPackages $f.packages $script:contractRoot}|Should -Throw '*assembly entry*'
        $a.entry=$entry;$f.packages.packages[2].assemblies+=,(Copy-TestData $a)
        {Assert-CpqPackages $f.packages $script:contractRoot}|Should -Throw '*MCP.Host assembly carrier*'
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
        $f.receipt.observations[0].observed.steps.recalculate.observed.sell='0.00'
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

Describe 'CPQ row payload contract (observation.schema.json)' {
    BeforeEach { $f=New-TestFixture;$row=$f.receipt.observations[0];$case=$f.spec.cases[0] }
    It 'accepts the producer step journal for every operation a check can be judged on' {
        foreach($function in @('cpq.page','cpq.pricing','cpq.bom','cpq.persistence','cpq.revisions','cpq.cart','cpq.quotes','cpq.documents')){
            $operation=Get-CpqCheckOperation $function
            foreach($case in $f.spec.cases){
                $r=@{caseId=$case.id;result='PASS';observed=(New-TestObservation $f.spec $case $f.context $operation)}
                { Assert-CpqObservationPayload -Row $r -Check @{functionId=$function} -Case $case -Context $f.context -Spec $f.spec -ContractRoot $script:contractRoot } | Should -Not -Throw
                Get-CpqObservationVerdict $r $case $f.spec | Should -BeExactly PASS
            }
        }
    }
    It 'RED CONTROL: refuses the free-form payloads the envelope alone used to accept' {
        foreach($payload in @(@{fixtureOnly=$true;sell='100.00'},@{lines=@(@{sku='WB-S';quantity=1})},@{operation='recalculate';steps=@{};reason='x'},@{operation='recalculate';steps=$row.observed.steps})){
            $row.observed=$payload
            { Assert-TestReceipt $f -Rehash } | Should -Throw '*observation.schema.json*'
        }
    }
    It 'refuses unknown fields, an unknown step, a null price and ERP calls' {
        $row.observed.extra=1
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*observation.schema.json*'
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.cleanup=$f.receipt.observations[0].observed.steps.render
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*observation.schema.json*'
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.recalculate.observed.vendorNote='x'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*observation.schema.json*'
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.recalculate.observed.beforeDiscount=$null
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*observation.schema.json*'
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.cart.observed.erpCalls=1
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*observation.schema.json*'
    }
    It 'refuses a payload judged on another operation than its check' {
        $row.observed.operation='cart'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*another operation*'
    }
    It 'refuses a broken journal and a journal that continues after a failed step' {
        $row.observed.steps.Remove('save')
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*unbroken prefix*'
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.render.result='UNVERIFIED'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*continues after*'
    }
    It 'refuses a step from another host, case or model version, and a partial step read' {
        foreach($change in @(@{hostId='another-host'},@{caseId='large-discount'},@{modelVersionId=7})){
            $f=New-TestFixture;$seen=$f.receipt.observations[0].observed.steps.save.observed
            foreach($key in $change.Keys){$seen[$key]=$change[$key]}
            { Assert-TestReceipt $f -Rehash } | Should -Throw '*escaped its host, case or model version*'
        }
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.quote.read.expectedSubjects=2
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*step read is incomplete*'
    }
    It 'RED CONTROL: a PASS label over a wrong price, discount basis or BOM is refused' {
        foreach($change in @(@{sell='99.00'},@{bom=@{'WB-S'=2}},@{valid=$false})){
            $f=New-TestFixture;$seen=$f.receipt.observations[0].observed.steps.recalculate.observed
            foreach($key in $change.Keys){$seen[$key]=$change[$key]}
            Get-CpqObservationVerdict $f.receipt.observations[0] $f.spec.cases[0] $f.spec | Should -BeExactly FAIL
            { Assert-TestReceipt $f -Rehash } | Should -Throw '*contradicts its own observation*'
        }
        $f=New-TestFixture;$f.receipt.observations[1].observed.steps.recalculate.observed.beforeDiscount='180.00'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*contradicts its own observation*'
    }
    It 'RED CONTROL: a failed or errored step cannot hide under UNVERIFIED' {
        foreach($result in @('FAIL','ERROR')){
            $f=New-TestFixture;$row=$f.receipt.observations[0]
            $row.observed.steps=@{render=$row.observed.steps.render;recalculate=$row.observed.steps.recalculate}
            $row.observed.steps.recalculate.result=$result;$row.result='UNVERIFIED'
            { Assert-TestReceipt $f -Rehash } | Should -Throw '*contradicts its own observation*'
            $row.result=$result
            { Assert-TestReceipt $f -Rehash } | Should -Not -Throw
        }
    }
    It 'reads a journal that stopped before the judged step, and a missing readback, as UNVERIFIED' {
        $row.observed=New-TestObservation $f.spec $case $f.context 'recalculate' -Through 'render'
        Get-CpqObservationVerdict $row $case $f.spec | Should -BeExactly UNVERIFIED
        $row.result='PASS'
        { Assert-TestReceipt $f -Rehash } | Should -Throw '*contradicts its own observation*'
        $row.result='UNVERIFIED'
        { Assert-TestReceipt $f -Rehash } | Should -Not -Throw
        $cart=@{caseId=$case.id;result='UNVERIFIED';observed=(New-TestObservation $f.spec $case $f.context 'cart')}
        $cart.observed.steps.cart.observed.ownerVerified=$false
        Get-CpqObservationVerdict $cart $case $f.spec | Should -BeExactly UNVERIFIED
    }
    It 'fails an invalid configuration that left a destination behind' {
        $invalid=@($f.spec.cases | Where-Object id -EQ 'invalid-mobile')[0]
        $r=@{caseId=$invalid.id;result='FAIL';observed=(New-TestObservation $f.spec $invalid $f.context 'cart')}
        Get-CpqObservationVerdict $r $invalid $f.spec | Should -BeExactly PASS
        $r.observed.steps.cart.observed.destinationId='cart-1'
        Get-CpqObservationVerdict $r $invalid $f.spec | Should -BeExactly FAIL
    }
}

Describe 'A PASS needs an implemented receipt binding in the locked snapshot' {
    BeforeAll {
        function New-TestSnapshot([string]$Status,[string]$Handler='cpq-behavior-receipt',[string]$Surface='file') {
            $binding=@{id='file-cpq-receipt';surface=$Surface;status=$Status;handler=$Handler}
            if($Status -eq 'planned'){$binding.reason='No complete domain producer/assertion exists for this intent.'}
            @{checks=@{'cpq.pricing.results'=@{id='cpq.pricing.results';functionId='cpq.pricing';bindings=@($binding)}}}
        }
        $script:passed=@{result='PASS';complete=$true}
    }
    It 'RED CONTROL: a complete reader PASS on a planned binding is UNVERIFIED' {
        $verdict=Resolve-CpqReaderVerdict cpq.pricing.results $script:passed (New-TestSnapshot planned)
        $verdict.result | Should -BeExactly UNVERIFIED;$verdict.complete | Should -BeFalse;$verdict.binding | Should -BeExactly planned
    }
    It 'RED CONTROL: a complete reader PASS without a receipt binding is UNVERIFIED' {
        foreach($snapshot in @($null,@{checks=@{}},(New-TestSnapshot implemented 'cpq-structured-read'),(New-TestSnapshot implemented 'cpq-behavior-receipt' 'sql'),(New-TestSnapshot retired))){
            $verdict=Resolve-CpqReaderVerdict cpq.pricing.results $script:passed $snapshot
            $verdict.result | Should -BeExactly UNVERIFIED;$verdict.complete | Should -BeFalse;$verdict.binding | Should -BeExactly unbound
        }
        $twice=New-TestSnapshot implemented;$twice.checks['cpq.pricing.results'].bindings+=$twice.checks['cpq.pricing.results'].bindings[0]
        (Resolve-CpqReaderVerdict cpq.pricing.results $script:passed $twice).binding | Should -BeExactly unbound
        (Resolve-CpqReaderVerdict cpq.bom.results $script:passed (New-TestSnapshot implemented)).result | Should -BeExactly UNVERIFIED
    }
    It 'lets a complete reader PASS stand once the snapshot promotes the binding' {
        $verdict=Resolve-CpqReaderVerdict cpq.pricing.results $script:passed (New-TestSnapshot implemented)
        $verdict.result | Should -BeExactly PASS;$verdict.complete | Should -BeTrue;$verdict.binding | Should -BeExactly implemented
    }
    It 'does not let an implemented binding complete an incomplete reader result' {
        $verdict=Resolve-CpqReaderVerdict cpq.pricing.results @{result='PASS';complete=$false} (New-TestSnapshot implemented)
        $verdict.result | Should -BeExactly UNVERIFIED;$verdict.complete | Should -BeFalse
    }
    It 'keeps FAIL and ERROR under any binding and reads an unknown result as ERROR' {
        foreach($status in @('planned','implemented')){foreach($result in @('FAIL','ERROR')){
            (Resolve-CpqReaderVerdict cpq.pricing.results @{result=$result;complete=$false} (New-TestSnapshot $status)).result | Should -BeExactly $result
        }}
        (Resolve-CpqReaderVerdict cpq.pricing.results @{result='OK';complete=$true} (New-TestSnapshot implemented)).result | Should -BeExactly ERROR
        (Resolve-CpqReaderVerdict cpq.pricing.results $null (New-TestSnapshot implemented)).result | Should -BeExactly ERROR
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
