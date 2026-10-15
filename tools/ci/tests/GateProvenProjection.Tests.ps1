<#
.SYNOPSIS
Pester (v5+) tests for gateProven as a projection of the editions record (tools/ci/GateProvenProjection.ps1,
check 14 of Validate-Distribution.ps1; owner ruling std-q31-gateproven-from-record). The record is a
fixture of `solution status truvio-editions --json` (fixtures/editions-status.json).

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\GateProvenProjection.ps1')
    $script:statusPath = Join-Path $PSScriptRoot 'fixtures\editions-status.json'
    function Read-Status { Get-Content -LiteralPath $script:statusPath -Raw -Encoding utf8 | ConvertFrom-Json }
    $script:validator = (Resolve-Path (Join-Path $PSScriptRoot '..\Validate-Distribution.ps1')).Path
    $script:repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
}

Describe 'ConvertTo-GateProvenProjection' {
    It 'takes the newest proven release per edition, a legacy-proof line only where no proven line exists' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        @($p.editions.Keys) | Should -Be @('headless-demo', 'swift-demo')
        $p.editions['swift-demo'] | Should -Be '20261016-073012'
        $p.releases['swift-demo'].tag | Should -Be 'editions/swift-demo/5.4.1'
        $p.releases['swift-demo'].legacy | Should -BeFalse
        $p.releases['swift-demo'].ts | Should -Be '2026-10-16T05:40:00Z'
        $p.editions['headless-demo'] | Should -Be '20261011-212054'
        $p.releases['headless-demo'].legacy | Should -BeTrue
        $p.date | Should -Be '2026-10-16'
    }
    It 'leaves out an edition with no proven or legacy line (unproven, never missing)' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        $p.editions.Contains('base-swift') | Should -BeFalse
    }
}

Describe 'Test-GateProvenProjection' {
    It 'passes a gateProven written from the projection, read back from JSON' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        $gp = ([ordered]@{ date = $p.date; dw = @{ version = '10.29.7' }; editions = $p.editions; releases = $p.releases } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
        @(Test-GateProvenProjection -GateProven $gp -Status (Read-Status)) | Should -BeNullOrEmpty
    }
    It 'fails a hand-edited run id' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        $p.editions['swift-demo'] = '20261001-000000'
        $gp = ([ordered]@{ date = $p.date; editions = $p.editions; releases = $p.releases } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
        (@(Test-GateProvenProjection -GateProven $gp -Status (Read-Status)) -join ' ') | Should -Match 'editions is not the projection'
    }
    It 'fails an edition added by hand that the record does not prove' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        $p.editions['base-swift'] = '20261016-080000'
        $gp = ([ordered]@{ date = $p.date; editions = $p.editions; releases = $p.releases } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
        (@(Test-GateProvenProjection -GateProven $gp -Status (Read-Status)) -join ' ') | Should -Match 'editions is not the projection'
    }
    It 'fails a record with nothing proven' {
        $s = Read-Status
        foreach ($i in $s.increments) { foreach ($r in $i.releases) { $r.proven = $null; $r.legacy = $false } }
        (@(Test-GateProvenProjection -GateProven ([pscustomobject]@{ date = $null; editions = @{}; releases = @{} }) -Status $s) -join ' ') | Should -Match 'nothing is proven'
    }
}

Describe 'Validate-Distribution check 14 on this tree' {
    It 'reports the edition proof check (projection, or the NOTE before the first projection run)' {
        $out = (& pwsh -NoProfile -File $script:validator -RepoRoot $script:repo 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should -Match 'projection of the editions record|predates the editions record'
    }
}
