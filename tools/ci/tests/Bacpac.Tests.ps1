<#
Bacpac.Tests.ps1: the bacpac register rules (tools/ci/Bacpac.ps1, layers/bacpacs.schema.json, Foundry #1422).
The central rule is observed red: an edition that changes version or proving run while its bacpac entry does
not FAILs, and so does a blank entry left behind by a DW pin move. No network; gh is never called.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Bacpac.ps1')
    $script:schema = Join-Path $PSScriptRoot '..\..\..\layers\bacpacs.schema.json'
    $script:versions = @{ 'swift-demo' = '5.3.0'; 'dap-portal' = '2.3.0' }
    $script:editions = @('swift-demo', 'dap-portal', 'base-only')

    function New-Fixture {
        $sha = 'ab' * 32
        $doc = [ordered]@{
            gateProven = [ordered]@{ dw = [ordered]@{ version = '10.28.12' }; editions = [ordered]@{ 'swift-demo' = '20260928-233540'; 'dap-portal' = '20260928-234223' } }
            bacpacs = [ordered]@{
                blank = [ordered]@{ dwVersion = '10.28.12'; tag = 'databases/blank/10.28.12'; asset = 'blank-dw-10.28.12.bacpac'; sha256 = $sha; sizeBytes = 117191
                                    gateRunId = '20260929-110000'; scrubCheck = [ordered]@{ verdict = 'CLEAN'; tool = 'Foundry tools/bacpac/Test-BacpacScrub.ps1' } }
                editions = [ordered]@{
                    'swift-demo' = [ordered]@{ editionVersion = '5.3.0'; tag = 'editions/swift-demo/5.3.0'; asset = 'swift-demo-5.3.0.bacpac'; sha256 = $sha; sizeBytes = 1000
                                               gateRunId = '20260929-120000'; deliveryRunId = '20260929-110000'; provenRunId = '20260928-233540'
                                               distributionCommit = ('9a' * 20); dwVersion = '10.28.12'
                                               scrubCheck = [ordered]@{ verdict = 'CLEAN'; tool = 'Foundry tools/bacpac/Test-BacpacScrub.ps1' } }
                }
            }
        }
        return ($doc | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
    }
    function Get-Red($Index) { @(Test-BacpacRegister -Index $Index -EditionNames $script:editions -EditionVersion $script:versions | Where-Object { -not $_.ok }) }
}

Describe 'Test-BacpacRegister' -Tag 'Unit' {
    It 'passes an entry bound to the current edition version, gateProven run and DW pin' {
        Get-Red (New-Fixture) | Should -BeNullOrEmpty
    }
    It 'is silent when INDEX.json registers no bacpac' {
        $i = New-Fixture; $i.PSObject.Properties.Remove('bacpacs')
        @(Test-BacpacRegister -Index $i -EditionNames $script:editions -EditionVersion $script:versions).Count | Should -Be 0
    }
    It 'FAILs when the edition changes version and the bacpac entry does not' {
        $v = $script:versions.Clone(); $v['swift-demo'] = '5.4.0'
        $red = @(Test-BacpacRegister -Index (New-Fixture) -EditionNames $script:editions -EditionVersion $v | Where-Object { -not $_.ok })
        ($red.message -join ' ') | Should -Match 'the edition changed version'
    }
    It 'FAILs when gateProven moves to a new run and the bacpac run ids do not follow' {
        $i = New-Fixture; $i.gateProven.editions.'swift-demo' = '20261001-070000'
        ((Get-Red $i).message -join ' ') | Should -Match 'gateProven moved'
    }
    It 'FAILs a blank entry left behind by a DW pin move' {
        $i = New-Fixture; $i.gateProven.dw.version = '10.29.0'
        ((Get-Red $i).message -join ' ') | Should -Match 'the DW pin moved'
    }
    It 'FAILs a tag or asset name that does not follow from the entry' {
        $i = New-Fixture; $i.bacpacs.editions.'swift-demo'.asset = 'swift-demo.bacpac'; $i.bacpacs.blank.tag = 'blank/10.28.12'
        (Get-Red $i).Count | Should -Be 2
    }
    It 'FAILs an entry for an edition that has no edition file' {
        $i = New-Fixture
        $i.bacpacs.editions | Add-Member -NotePropertyName 'ghost' -NotePropertyValue $i.bacpacs.editions.'swift-demo'
        ((Get-Red $i).message -join ' ') | Should -Match 'names no edition file'
    }
}

Describe 'layers/bacpacs.schema.json' -Tag 'Unit' {
    It 'accepts the fixture' {
        Test-Json -Json ((New-Fixture).bacpacs | ConvertTo-Json -Depth 10) -SchemaFile $script:schema | Should -BeTrue
    }
    It 'rejects a scrub check that is not CLEAN and an entry without a sha256' {
        $i = New-Fixture; $i.bacpacs.blank.scrubCheck.verdict = 'FAIL'
        Test-Json -Json ($i.bacpacs | ConvertTo-Json -Depth 10) -SchemaFile $script:schema -ErrorAction SilentlyContinue | Should -BeFalse
        $i = New-Fixture; $i.bacpacs.editions.'swift-demo'.PSObject.Properties.Remove('sha256')
        Test-Json -Json ($i.bacpacs | ConvertTo-Json -Depth 10) -SchemaFile $script:schema -ErrorAction SilentlyContinue | Should -BeFalse
    }
}

Describe 'Get-BacpacReleasePlan' -Tag 'Unit' {
    It 'plans one release per registered bacpac, carrying tag, asset and sha256' {
        $plan = @(Get-BacpacReleasePlan -Index (New-Fixture))
        $plan.Tag | Should -Be @('databases/blank/10.28.12', 'editions/swift-demo/5.3.0')
        $plan.Asset | Should -Be @('blank-dw-10.28.12.bacpac', 'swift-demo-5.3.0.bacpac')
        $plan[1].Notes | Should -Match 'gate on it \(run 20260929-120000'
    }
}
