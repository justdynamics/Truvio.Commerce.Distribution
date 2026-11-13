#Requires -Version 7.0
# Cross-repository integration: choose a reviewed skills checkout explicitly.
$hasReader=$env:CPQ_SKILLS_ROOT -and (Test-Path (Join-Path $env:CPQ_SKILLS_ROOT 'skills/dw-demo-ledger/scripts/Cpq.Receipts.ps1'))
Describe 'Skills reader against actual Distribution receipt contracts' -Skip:(-not $hasReader) {
    BeforeAll {
        . (Join-Path $PSScriptRoot '../Cpq.Contracts.ps1')
        . (Join-Path $PSScriptRoot '../Cpq.Receipts.ps1')
        $script:contractRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../contracts/cpq')).Path
        . (Join-Path $PSScriptRoot 'fixtures/Cpq.Fixture.ps1')
        . (Join-Path $env:CPQ_SKILLS_ROOT 'skills/dw-demo-ledger/scripts/Cpq.Json.ps1')
        . (Join-Path $env:CPQ_SKILLS_ROOT 'skills/dw-demo-ledger/scripts/Cpq.Receipts.ps1')
        function Set-Check($f,$id){
            $f.behavior.checks[0].id=$id;$f.behavior.checks[0].functionId=$id.Substring(0,$id.LastIndexOf('.'))
            $f.context.ledger.checkIds=@($id);$f.context.behaviorDigest=Get-CpqDigest $f.behavior
            $f.receipt.before=Copy-TestData $f.context;$f.receipt.after=Copy-TestData $f.context
            # The payload names the step its check is judged on; a row that keeps another one is refused.
            foreach($row in $f.receipt.observations){$row.checkId=$id;$row.observed.operation=Get-CpqCheckOperation $f.behavior.checks[0].functionId}
        }
        function Get-Trust($f){
            @{Context=$f.context;Behavior=$f.behavior;Spec=$f.spec;Packages=$f.packages;ExpectedReceiptDigest=(Get-CpqDigest $f.receipt);NotBefore=[datetimeoffset]'2026-01-01T12:00:00Z';Now=[datetimeoffset]'2026-01-01T12:02:00Z';ContractRoot=$script:contractRoot}
        }
        # What an honest producer writes for a failed recalculation: the journal stops there and the row says FAIL.
        function Set-FailedRecalculation($row){
            $row.observed.steps=@{render=$row.observed.steps.render;recalculate=$row.observed.steps.recalculate}
            $row.observed.steps.recalculate.result='FAIL';$row.result='FAIL'
        }
        # The 21 behavioural checks whose only binding is the receipt handler.
        $script:receiptCheckIds=@('installation.restart','model-versions.isolation','inputs.types','lookups.results','conditions.truth-table','input-rules.effects','constraints.transitions','bom.results','routing.results','pricing.results','persistence.roundtrip','revisions.isolated-copy','cart.handoff','quotes.handoff','documents.output','page.render','studio-models.roundtrip','diagrams.dependencies','visualization.selection','erp.boundary','spec-build.reproducible')
    }
    It 'reads all 21 behavioral envelopes in the producer payload shape; a proven row is PASS only until the binding status gates it' {
        # Skills #240 (reader contract): every row judged by Get-CpqObservationVerdict and proven reads PASS with
        # complete=$true. The binding status, not the reader, keeps it from a domain PASS (Resolve-CpqReaderVerdict).
        $snapshot=@{checks=@{}}
        foreach($id in $script:receiptCheckIds){$f=New-TestFixture;Set-Check $f ('cpq.'+$id)
            $read=Read-CpqBehaviorObservation ('cpq.'+$id) $f.receipt (Get-Trust $f)
            $read.result | Should -BeExactly PASS;$read.complete | Should -BeTrue;@($read.offenders).Count | Should -Be 0
            $snapshot.checks['cpq.'+$id]=@{id='cpq.'+$id;bindings=@(@{id='file-cpq-receipt';surface='file';status='planned';handler='cpq-behavior-receipt'})}
            (Resolve-CpqReaderVerdict ('cpq.'+$id) $read $snapshot).result | Should -BeExactly UNVERIFIED
            # Only promoting the binding lets the same proven row through.
            $snapshot.checks['cpq.'+$id].bindings[0].status='implemented'
            (Resolve-CpqReaderVerdict ('cpq.'+$id) $read $snapshot).result | Should -BeExactly PASS
        }
    }
    It 'RED CONTROL: a wrong price in the producer shape under a PASS label is refused, never read as UNVERIFIED' {
        # Foundry #1644: this exact row used to come back UNVERIFIED with no offender.
        $f=New-TestFixture;$f.receipt.observations[0].observed.steps.recalculate.observed.sell='99.00'
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)} | Should -Throw '*contradicts its own observation*'
        # The honest producer row for the same observation carries FAIL, and the reader keeps it.
        Set-FailedRecalculation $f.receipt.observations[0]
        $read=Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)
        $read.result | Should -BeExactly FAIL;$read.offenders.Count | Should -Be 1
        $f=New-TestFixture;$f.receipt.observations[0].result='ERROR'
        (Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)).result | Should -BeExactly ERROR
    }
    It 'RED CONTROL: refuses the payload shapes the producer never writes' {
        $f=New-TestFixture;$f.receipt.observations[0].observed=@{fixtureOnly=$true;sell='100.00'}
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)} | Should -Throw '*observation.schema.json*'
        $f=New-TestFixture;Set-Check $f cpq.bom.results
        $f.receipt.observations[0].observed=@{lines=@(@{sku='WB-S';quantity=1})}
        {Read-CpqBehaviorObservation cpq.bom.results $f.receipt (Get-Trust $f)} | Should -Throw '*observation.schema.json*'
    }
    It 'refuses a wrong BOM quantity under a PASS label and keeps the producer failure for it' {
        $f=New-TestFixture;Set-Check $f cpq.bom.results
        (Read-CpqBehaviorObservation cpq.bom.results $f.receipt (Get-Trust $f)).result | Should -BeExactly PASS
        $f.receipt.observations[0].observed.steps.recalculate.observed.bom['WB-S']=99
        {Read-CpqBehaviorObservation cpq.bom.results $f.receipt (Get-Trust $f)} | Should -Throw '*contradicts its own observation*'
        Set-FailedRecalculation $f.receipt.observations[0]
        (Read-CpqBehaviorObservation cpq.bom.results $f.receipt (Get-Trust $f)).result | Should -BeExactly FAIL
    }
    It 'does not reinterpret producer failures as an empty success' {
        $f=New-TestFixture;$f.receipt.observations[0].result='FAIL'
        (Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)).result | Should -BeExactly FAIL
    }
    It 'rejects altered bytes, wrong trusted context, partial scope and stale evidence' {
        $f=New-TestFixture;$trust=Get-Trust $f;$f.receipt.observations[0].observed.steps.recalculate.observed.sell='99.00'
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt $trust} | Should -Throw '*digest*'
        $f=New-TestFixture;$trust=Get-Trust $f;$trust.Context=Copy-TestData $f.context;$trust.Context.modelId=99
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt $trust} | Should -Throw '*identity differs*'
        $f=New-TestFixture;$f.receipt.observations[0].read.expectedSubjects=2
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)} | Should -Throw '*incomplete*'
        $f=New-TestFixture;$trust=Get-Trust $f;$trust.Now=[datetimeoffset]'2026-01-02T12:02:00Z'
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt $trust} | Should -Throw '*stale*'
    }
    It 'binds every receipt check of the pinned snapshot as planned, so none of them can yield PASS' {
        # The binding files of the pinned checkout, not a copy: when one is promoted this test names it.
        $probes=Join-Path $env:CPQ_SKILLS_ROOT 'skills/dw-demo-ledger/assets/releases/10.30.6/probes/cpq'
        $snapshot=@{checks=@{}}
        foreach($file in Get-ChildItem -LiteralPath $probes -Filter '*.json' -File){$check=Read-CpqJson $file.FullName;$snapshot.checks[$check.id]=$check}
        $bound=@($snapshot.checks.Keys | Where-Object {(Get-CpqReceiptBinding $_ $snapshot) -cne 'unbound'} | Sort-Object)
        $bound | Should -Be @($script:receiptCheckIds | ForEach-Object {'cpq.'+$_} | Sort-Object)
        foreach($id in $bound){
            Get-CpqReceiptBinding $id $snapshot | Should -BeExactly planned
            $verdict=Resolve-CpqReaderVerdict $id @{result='PASS';complete=$true} $snapshot
            $verdict.result | Should -BeExactly UNVERIFIED;$verdict.complete | Should -BeFalse
        }
    }
}
