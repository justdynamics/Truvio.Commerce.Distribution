BeforeAll {
    . (Join-Path $PSScriptRoot '../Ledger.ps1')
    $script:distribution = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:skills = Resolve-LedgerSkillsRoot -DistributionRoot $script:distribution
    $script:edition = Get-Content (Join-Path $script:distribution 'editions/swift-demo.json') -Raw | ConvertFrom-Json -AsHashtable
    $script:snapshot = Read-DistributionLedgerSnapshot $script:edition.ledger $script:skills
}

Describe 'Pinned edition ledger' {
    It 'validates every shipped edition against the canonical skills checkout' {
        foreach ($file in Get-ChildItem (Join-Path $script:distribution 'editions') -Filter '*.json') {
            if ($file.Name -eq 'edition.schema.json') { continue }
            $e = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
            $p = Get-EditionLedgerPlan $script:distribution $e $script:skills
            $p.checkIds.Count | Should -BeGreaterThan 0
        }
    }
    It 'RED CONTROL: rejects a changed snapshot digest' {
        $lock = $script:edition.ledger.Clone(); $lock.digest = 'sha256:' + ('0' * 64)
        { Read-DistributionLedgerSnapshot $lock $script:skills } | Should -Throw '*digest mismatch*'
    }
    It 'RED CONTROL: rejects a different producer commit' {
        $lock = $script:edition.ledger.Clone(); $lock.commit = '0' * 40
        { Read-DistributionLedgerSnapshot $lock $script:skills } | Should -Throw '*commit differs*'
    }
}

Describe 'Carriage and exact check selection' {
    BeforeEach {
        Mock Read-DistributionLedgerSnapshot { $script:snapshot }
        $script:testLayer = @{ name = 'test'; ledger = @{ provides = @('commerce.currencies'); requires = @('serializer.engine') } }
        Mock Get-EditionLedgerLayer { $script:testLayer }
        $script:testEdition = @{ ledger = @{ checkIds = @('commerce.currencies.one-default', 'commerce.currencies.several') } }
    }
    It 'requires do not add producer checks to the locked set' {
        $p = Get-EditionLedgerPlan $script:distribution $script:testEdition $script:skills
        $p.checkIds.Count | Should -Be 2
        $p.functions | Should -Be @('commerce.currencies')
    }
    It 'RED CONTROL: unknown provides fails' {
        $script:testLayer.ledger.provides += 'commerce.unknown'
        { Get-EditionLedgerPlan $script:distribution $script:testEdition $script:skills } | Should -Throw '*unknown ledger function*'
    }
    It 'RED CONTROL: unknown requires fails' {
        $script:testLayer.ledger.requires += 'serializer.unknown'
        { Get-EditionLedgerPlan $script:distribution $script:testEdition $script:skills } | Should -Throw '*unknown ledger function*'
    }
    It 'RED CONTROL: empty check set fails' {
        $script:testEdition.ledger.checkIds = @()
        { Get-EditionLedgerPlan $script:distribution $script:testEdition $script:skills } | Should -Throw '*must not be empty*'
    }
    It 'RED CONTROL: missing, extra and duplicate checks fail' {
        foreach ($ids in @(@('commerce.currencies.several'), @('commerce.currencies.one-default','commerce.currencies.several','distribution.base-layer.countries'), @('commerce.currencies.several','commerce.currencies.several'))) {
            $script:testEdition.ledger.checkIds = $ids
            { Get-EditionLedgerPlan $script:distribution $script:testEdition $script:skills } | Should -Throw
        }
    }
    It 'RED CONTROL: missing carriage fails' {
        $script:testLayer.Remove('ledger')
        { Get-EditionLedgerPlan $script:distribution $script:testEdition $script:skills } | Should -Throw '*no ledger carriage*'
    }
}
