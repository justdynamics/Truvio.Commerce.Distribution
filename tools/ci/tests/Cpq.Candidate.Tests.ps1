BeforeAll {
    $script:dist=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    . (Join-Path $script:dist 'tools/ci/Cpq.Contracts.ps1')
    . (Join-Path $script:dist 'tools/ci/Cpq.Compiler.ps1')
    . (Join-Path $script:dist 'tools/ci/Ledger.ps1')
    $script:contracts=Join-Path $script:dist 'contracts/cpq'
    $script:source=Join-Path $script:dist 'layers/feature-cpq'
    function Test-Candidate($root,$layer,[switch]$Delivery){Test-CpqLayerContract $root $layer $script:contracts -ForDelivery:$Delivery}
}
Describe 'Non-deliverable CPQ candidate carriage' {
    BeforeEach {
        $root=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Copy-Item -LiteralPath $script:source -Destination $root -Recurse
        $layer=Read-CpqJson (Join-Path $root 'layer.json')
    }
    It 'validates the real evidence, compiler output, cases and content intent as a candidate' {
        Assert-CpqSchema $layer (Join-Path $script:dist 'layers/layer.schema.json')
        Test-Candidate $root $layer
        $layer.ledger.provides.Count|Should -Be 18;$layer.ledger.requires.Count|Should -Be 10
    }
    It 'preserves ISO strings and array shape across a canonical receipt read' {
        $path=Join-Path $TestDrive 'iso.json'
        $value=@{time='2026-11-12T12:00:00.1234000Z';items=@(@{n=1});empty=@();nulls=@($null)}
        [IO.File]::WriteAllText($path,(ConvertTo-CpqCanonicalJson $value))
        $read=Read-CpqJson $path
        $read.time|Should -BeOfType string
        ($read.items -is [array])|Should -BeTrue
        $read.empty.Count|Should -Be 0
        $read.nulls.Count|Should -Be 1
        (Get-CpqDigest $read)|Should -BeExactly (Get-CpqDigest $value)
    }
    It 'refuses delivery and names all five blockers' {
        $layer.cpq.blockers.id|Should -Not -Contain 'studio-package'
        $layer.cpq.blockers.id|Should -Not -Contain 'stable-mcp'
        $layer.cpq.blockers.Count|Should -Be 5
        {Test-Candidate $root $layer -Delivery}|Should -Throw '*openxml-closure*runtime-identity*runtime-verification*content-bindings*engine-adapter*'
    }
    It 'cannot promote partial evidence by changing only status or version' {
        $layer.cpq.status='ready';$layer.cpq.Remove('blockers');$layer.cpq.Remove('candidateArtifacts');$layer.version='1.0.0'
        {Test-Candidate $root $layer -Delivery}|Should -Throw '*schema*'
    }
    It 'rejects missing blockers and duplicate blocker identities' {
        $layer.cpq.blockers=@();{Test-Candidate $root $layer}|Should -Throw '*schema*'
        $layer=Read-CpqJson (Join-Path $root 'layer.json');$layer.cpq.blockers+=,$layer.cpq.blockers[0]
        {Test-Candidate $root $layer}|Should -Throw '*duplicate*'
    }
    It 'rejects changed generated row bytes and changed fixtures' {
        $path=Join-Path $root $layer.cpq.candidateArtifacts.compiled
        $data=Read-CpqJson $path;$data.rows[0].values.ModelName='unreviewed';$data|ConvertTo-Json -Depth 100|Set-Content $path
        {Test-Candidate $root $layer}|Should -Throw '*stale or altered*'
    }
    It 'requires render proof and never permits sampleData fixture skipping' {
        $layer.asserts.behaviorProbes[0].renderProof=$false;{Test-Candidate $root $layer}|Should -Throw '*render proof*'
        $layer.asserts.behaviorProbes[0].renderProof=$true;$layer.asserts.behaviorProbes[0].requiresFixtures=@('WB-S')
        {Test-Candidate $root $layer}|Should -Throw '*must not be skipped*'
    }
    It 'locks all core and prerequisite checks at the exact CPQ skills revision' {
        $e=Read-CpqJson (Join-Path $script:dist 'editions/cpq-demo.json')
        $skills=if($env:TRUVIO_CPQ_SKILLS_PATH){$env:TRUVIO_CPQ_SKILLS_PATH}else{Join-Path $script:dist '.ledger-skills-cpq'}
        $p=Get-EditionLedgerPlan $script:dist $e $skills
        $p.checkIds.Count|Should -Be 63
        @($p.checkIds|Where-Object {$_ -like 'cpq.*'}).Count|Should -Be 28
        $p.checkIds|Should -Contain 'serializer.engine.engine-floor'
    }
    It 'rejects a candidate edition that drops a blocker or prerequisite check' {
        $e=Read-CpqJson (Join-Path $script:dist 'editions/cpq-demo.json')
        $skills=if($env:TRUVIO_CPQ_SKILLS_PATH){$env:TRUVIO_CPQ_SKILLS_PATH}else{Join-Path $script:dist '.ledger-skills-cpq'}
        $e.delivery.blockers=@($e.delivery.blockers|Select-Object -Skip 1)
        {Get-EditionLedgerPlan $script:dist $e $skills}|Should -Throw '*omits*'
        $e=Read-CpqJson (Join-Path $script:dist 'editions/cpq-demo.json');$e.ledger.checkIds=@($e.ledger.checkIds|Select-Object -Skip 1)
        {Get-EditionLedgerPlan $script:dist $e $skills}|Should -Throw '*checkIds must equal*'
    }
    It 'RED CONTROL: composition refuses a layer.json with a duplicate key, as the contract reader does' {
        $d=Join-Path $TestDrive ([guid]::NewGuid().ToString('N'));$dir=New-Item -ItemType Directory -Force -Path (Join-Path $d 'layers/dup')
        $path=Join-Path $dir 'layer.json'
        [IO.File]::WriteAllText($path,'{"name":"dup","version":"1.0.0","cpq":{"status":"candidate"},"cpq":null}')
        {Read-CpqJson $path}|Should -Throw '*Duplicate JSON property*'
        {Get-EditionLedgerLayer $d @{from='dup@1.0.0';add=@();surfaces=@();themes=@()}}|Should -Throw "*Duplicate JSON property 'cpq'*"
        [IO.File]::WriteAllText($path,'{"name":"dup","version":"1.0.0","cpq":null}')
        @(Get-EditionLedgerLayer $d @{from='dup@1.0.0';add=@();surfaces=@();themes=@()})[0].name|Should -BeExactly 'dup'
    }
}
