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
            foreach($row in $f.receipt.observations){$row.checkId=$id}
        }
        function Get-Trust($f){
            @{Context=$f.context;Behavior=$f.behavior;Spec=$f.spec;Packages=$f.packages;ExpectedReceiptDigest=(Get-CpqDigest $f.receipt);NotBefore=[datetimeoffset]'2026-01-01T12:00:00Z';Now=[datetimeoffset]'2026-01-01T12:02:00Z';ContractRoot=$script:contractRoot}
        }
    }
    It 'reads all 21 behavioral envelopes without inventing a domain PASS' {
        $ids=@('installation.restart','model-versions.isolation','inputs.types','lookups.results','conditions.truth-table','input-rules.effects','constraints.transitions','bom.results','routing.results','pricing.results','persistence.roundtrip','revisions.isolated-copy','cart.handoff','quotes.handoff','documents.output','page.render','studio-models.roundtrip','diagrams.dependencies','visualization.selection','erp.boundary','spec-build.reproducible')
        foreach($id in $ids){$f=New-TestFixture;Set-Check $f ('cpq.'+$id)
            (Read-CpqBehaviorObservation ('cpq.'+$id) $f.receipt (Get-Trust $f)).result | Should -BeExactly UNVERIFIED
        }
    }
    It 'fails an incorrect price even when the producer labels it PASS and binds its digest' {
        $f=New-TestFixture;$f.receipt.observations[0].observed.sell='99.00'
        (Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)).result | Should -BeExactly FAIL
        $f.receipt.observations[0].result='ERROR'
        (Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)).result | Should -BeExactly ERROR
    }
    It 'compares independent BOM quantities and preserves missing producer proof' {
        $f=New-TestFixture;Set-Check $f cpq.bom.results
        foreach($row in $f.receipt.observations){
            $case=@($f.spec.cases | Where-Object {$_.id -eq $row.caseId})[0]
            $row.observed=@{lines=@(foreach($sku in $case.expect.bom.Keys){@{sku=$sku;quantity=$case.expect.bom[$sku]}})}
        }
        (Read-CpqBehaviorObservation cpq.bom.results $f.receipt (Get-Trust $f)).result | Should -BeExactly UNVERIFIED
        $f.receipt.observations[0].observed.lines[0].quantity=99
        (Read-CpqBehaviorObservation cpq.bom.results $f.receipt (Get-Trust $f)).result | Should -BeExactly FAIL
    }
    It 'does not reinterpret producer failures as an empty success' {
        $f=New-TestFixture;$f.receipt.observations[0].result='FAIL'
        (Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)).result | Should -BeExactly FAIL
    }
    It 'rejects altered bytes, wrong trusted context, partial scope and stale evidence' {
        $f=New-TestFixture;$trust=Get-Trust $f;$f.receipt.observations[0].observed.sell='99.00'
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt $trust} | Should -Throw '*digest*'
        $f=New-TestFixture;$trust=Get-Trust $f;$trust.Context=Copy-TestData $f.context;$trust.Context.modelId=99
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt $trust} | Should -Throw '*identity differs*'
        $f=New-TestFixture;$f.receipt.observations[0].read.expectedSubjects=2
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt (Get-Trust $f)} | Should -Throw '*incomplete*'
        $f=New-TestFixture;$trust=Get-Trust $f;$trust.Now=[datetimeoffset]'2026-01-02T12:02:00Z'
        {Read-CpqBehaviorObservation cpq.pricing.results $f.receipt $trust} | Should -Throw '*stale*'
    }
}
