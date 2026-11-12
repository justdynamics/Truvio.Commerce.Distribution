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
    It 'RED CONTROL: layer and edition blocker sets must be equal in both directions (Distribution #132 item 4)' {
        $skills=if($env:TRUVIO_CPQ_SKILLS_PATH){$env:TRUVIO_CPQ_SKILLS_PATH}else{Join-Path $script:dist '.ledger-skills-cpq'}
        $e=Read-CpqJson (Join-Path $script:dist 'editions/cpq-demo.json')
        $e.delivery.blockers+=,@{id='made-up';reason='A blocker no candidate layer declares.'}
        {Get-EditionLedgerPlan $script:dist $e $skills}|Should -Throw '*blocker no candidate layer declares*'
        $e=Read-CpqJson (Join-Path $script:dist 'editions/cpq-demo.json')
        $e.delivery.blockers[0].reason=$e.delivery.blockers[0].reason+' Edited.'
        {Get-EditionLedgerPlan $script:dist $e $skills}|Should -Throw '*omits a layer delivery blocker*'
        # Dropping a blocker from the layer only: the edition then names one the layer no longer declares.
        Mock Get-EditionLedgerLayer {
            foreach($name in 'base','feature-cpq','surface-swift','theme-default'){
                $l=Read-CpqJson (Join-Path $script:dist "layers/$name/layer.json")
                if($name -ceq 'feature-cpq'){$l.cpq.blockers=@($l.cpq.blockers|Select-Object -Skip 1)}
                $l
            }
        }
        {Get-EditionLedgerPlan $script:dist (Read-CpqJson (Join-Path $script:dist 'editions/cpq-demo.json')) $skills}|Should -Throw '*blocker no candidate layer declares*'
    }
    It 'RED CONTROL: the layer copy of the candidate package lock may not differ from contracts/cpq (Distribution #132 item 4)' {
        $path=Join-Path $root $layer.cpq.packages;$behaviorPath=Join-Path $root $layer.cpq.behavior
        $p=Read-CpqJson $path;$p.gaps+='A further gap recorded in the layer copy only.'
        [IO.File]::WriteAllText($path,(ConvertTo-CpqCanonicalJson $p))
        # Recompute the behavior binding, as the issue describes: the divergence must still be refused.
        $b=Read-CpqJson $behaviorPath;$b.packageLockDigest=Get-CpqDigest $p;[IO.File]::WriteAllText($behaviorPath,(ConvertTo-CpqCanonicalJson $b))
        {Test-Candidate $root $layer}|Should -Throw '*differs from contracts/cpq/packages.candidate.lock.json*'
    }
    It 'RED CONTROL: candidate package evidence keeps its profile, floor, entry and digest rules (Distribution #132 item 4)' {
        $new={Read-CpqJson (Join-Path $script:contracts 'packages.candidate.lock.json')}
        {Assert-CpqCandidatePackages (& $new)}|Should -Not -Throw
        $pkg={param($p,$id) @($p.packages|Where-Object {$_.id -ceq $id})[0]}
        $p=& $new;(& $pkg $p 'DW_CPQ_API').version='10.24.3';{Assert-CpqCandidatePackages $p}|Should -Throw '*engine profile*'
        $p=& $new;(& $pkg $p 'Truvio.Commerce.MCP').version='0.6.4';{Assert-CpqCandidatePackages $p}|Should -Throw '*below*'
        $p=& $new;(& $pkg $p 'Truvio.Commerce.MCP').minimumVersion='0.6.0';{Assert-CpqCandidatePackages $p}|Should -Throw '*Studio floor*'
        $p=& $new;(& $pkg $p 'CPQ_Admin').assemblies[0].entry='lib/net8.0/Other.dll';{Assert-CpqCandidatePackages $p}|Should -Throw '*entry differs*'
        $p=& $new;(& $pkg $p 'CPQ_Admin').assemblies[0].entry='lib/CPQ_Admin.dll';{Assert-CpqCandidatePackages $p}|Should -Throw '*entry differs*'
        $p=& $new;(& $pkg $p 'CPQ_Admin').assemblies[0].name='Renamed';{Assert-CpqCandidatePackages $p}|Should -Throw '*identities do not match*'
        $p=& $new;(& $pkg $p 'Truvio.Commerce.MCP').assemblies[1].name='Truvio.Commerce.MCP';{Assert-CpqCandidatePackages $p}|Should -Throw '*duplicate candidate assembly*'
        $p=& $new;(& $pkg $p 'CPQ_Admin').packageSha256='sha256:'+('0'*64);{Assert-CpqCandidatePackages $p}|Should -Throw '*package digest*'
        $p=& $new;(& $pkg $p 'CPQ_Admin').assemblies[0].packageEntrySha256='sha256:abc';{Assert-CpqCandidatePackages $p}|Should -Throw '*assembly digest*'
        $p=& $new;(& $pkg $p 'DW_CPQ_API').assemblies[0].installedMatchesPackage=$true;{Assert-CpqCandidatePackages $p}|Should -Throw '*contradicts its digests*'
        $p=& $new;(& $pkg $p 'CPQ_Admin').assemblies[0].installedSha256='sha256:'+('1'*64);{Assert-CpqCandidatePackages $p}|Should -Throw '*contradicts its digests*'
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
