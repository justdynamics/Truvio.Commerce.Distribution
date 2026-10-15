<#
.SYNOPSIS
Pester (v5+) tests for gateProven as a projection of the editions record (tools/ci/GateProvenProjection.ps1,
check 14 of Validate-Distribution.ps1, the edition tags of print-release-tags.ps1; owner ruling
std-q31-gateproven-from-record). fixtures/editions-status.json is real `solution status truvio-editions --json`
output: swift-demo with a legacy-proof line on 5.4.0, a proven line on 5.4.1 and a built-only 5.5.0;
headless-demo with a legacy-proof line on 3.3.0; base-swift with no release.

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\GateProvenProjection.ps1')
    $script:statusPath = Join-Path $PSScriptRoot 'fixtures\editions-status.json'
    function Read-Status { Get-Content -LiteralPath $script:statusPath -Raw -Encoding utf8 | ConvertFrom-Json }
    function Read-Extract { (ConvertTo-EditionsRecordExtract -Status (Read-Status)) | ConvertTo-Json -Depth 10 | ConvertFrom-Json }
    $script:validator = (Resolve-Path (Join-Path $PSScriptRoot '..\Validate-Distribution.ps1')).Path
    function Write-Text([string]$Path, [string]$Text) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
        [IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
    }
    # A minimal Distribution tree for print-release-tags: one edition, its tools/ci, and an INDEX.json.
    function New-TagTree([string]$ReleaseTag, [string]$MapVersion) {
        $d = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $ci = (New-Item -ItemType Directory -Force -Path (Join-Path $d 'tools/ci')).FullName
        foreach ($f in 'print-release-tags.ps1', 'Bacpac.ps1', 'ProvenTree.ps1', 'Get-LayerTreeHash.ps1') { Copy-Item -LiteralPath (Join-Path $PSScriptRoot "..\$f") -Destination $ci }
        $src = Get-Content -Raw (Join-Path $ci 'Bacpac.ps1')
        Write-Text (Join-Path $ci 'Bacpac.ps1') ($src -replace "'swift-demo'(\s*)=\s*'[^']+'", "'swift-demo'`$1= '$MapVersion'")
        Write-Text (Join-Path $d 'editions/swift-demo.json') (@{ name = 'swift-demo'; from = 'base@1.0.0' } | ConvertTo-Json)
        Write-Text (Join-Path $d 'layers/base/layer.json') (@{ name = 'base'; version = '1.0.0' } | ConvertTo-Json)
        $gp = [ordered]@{ date = '2026-10-16'; dw = @{ version = '10.29.7' }; swift = @{ tag = 'v2.4.0' }; swiftVersion = '2.4.0'
                          editions = [ordered]@{ 'swift-demo' = '20261016-073012' }
                          releases = [ordered]@{ 'swift-demo' = [ordered]@{ tag = $ReleaseTag; runId = '20261016-073012'; host = 'foundry'; ts = '2026-10-16T05:40:00Z'; resultsDigest = $null; legacy = $false } } }
        Write-Text (Join-Path $d 'layers/INDEX.json') ([ordered]@{ gateProven = $gp; layers = @() } | ConvertTo-Json -Depth 10)
        return $d
    }
}

Describe 'ConvertTo-GateProvenProjection on real console output' {
    It 'takes the newest proven release per edition; legacy only where the proven run is the legacy-proof run' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        @($p.editions.Keys) | Should -Be @('headless-demo', 'swift-demo')
        $p.editions['swift-demo'] | Should -Be '20261016-073012'
        $p.releases['swift-demo'].tag | Should -Be 'editions/swift-demo/5.4.1'
        $p.releases['swift-demo'].legacy | Should -BeFalse
        $p.releases['swift-demo'].resultsDigest | Should -Match '^sha256:[0-9a-f]{64}$'
        $p.editions['headless-demo'] | Should -Be '20261011-212054'
        $p.releases['headless-demo'].legacy | Should -BeTrue
        $p.releases['headless-demo'].host | Should -Be 'foundry-blank-dw10'
        $p.date | Should -Be '2026-10-15'
    }
    It 'leaves out an edition with no proven line (base-swift) and a release that is only built (5.5.0)' {
        $p = ConvertTo-GateProvenProjection -Status (Read-Status)
        $p.editions.Contains('base-swift') | Should -BeFalse
        @($p.releases.Values | ForEach-Object { $_.tag }) | Should -Not -Contain 'editions/swift-demo/5.5.0'
    }
    It 'the extract projects exactly like the full status' {
        (ConvertTo-GateProvenCanonical (ConvertTo-GateProvenProjection -Status (Read-Extract))) |
            Should -Be (ConvertTo-GateProvenCanonical (ConvertTo-GateProvenProjection -Status (Read-Status)))
    }
    It 'the extract is deterministic: no state, dwell or counters, the same bytes twice' {
        $x = ConvertTo-EditionsRecordExtract -Status (Read-Status) | ConvertTo-Json -Depth 10
        $x | Should -Not -Match 'dwellDays|readyToShow|"lines"|"state"|blocking'
        (ConvertTo-EditionsRecordExtract -Status (Read-Status) | ConvertTo-Json -Depth 10) | Should -Be $x
    }
}

Describe 'Test-GateProvenProjection' {
    BeforeAll {
        function New-Gp([scriptblock]$Edit) {
            $p = ConvertTo-GateProvenProjection -Status (Read-Status)
            if ($Edit) { & $Edit $p }
            ([ordered]@{ date = $p.date; dw = @{ version = '10.29.7' }; editions = $p.editions; releases = $p.releases } | ConvertTo-Json -Depth 8) | ConvertFrom-Json
        }
    }
    It 'passes a gateProven written from the projection of the extract' {
        @(Test-GateProvenProjection -GateProven (New-Gp) -Status (Read-Extract)) | Should -BeNullOrEmpty
    }
    It 'fails a hand-edited run id' {
        (@(Test-GateProvenProjection -GateProven (New-Gp { param($p) $p.editions['swift-demo'] = '20261001-000000' }) -Status (Read-Extract)) -join ' ') | Should -Match 'editions is not the projection'
    }
    It 'fails an edition added by hand that the record does not prove' {
        (@(Test-GateProvenProjection -GateProven (New-Gp { param($p) $p.editions['base-swift'] = '20261016-080000' }) -Status (Read-Extract)) -join ' ') | Should -Match 'editions is not the projection'
    }
    It 'fails a full status committed in place of the extract' {
        (@(Test-GateProvenProjection -GateProven (New-Gp) -Status (Read-Status)) -join ' ') | Should -Match 'not an extract'
    }
    It 'fails a null record and a record with no increments' {
        (@(Test-GateProvenProjection -GateProven (New-Gp) -Status $null) -join ' ') | Should -Match 'missing'
        (@(Test-GateProvenProjection -GateProven (New-Gp) -Status ([pscustomobject]@{ slug = 'truvio-editions' })) -join ' ') | Should -Match 'missing'
    }
    It 'fails a record with nothing proven' {
        $x = Read-Extract
        foreach ($i in $x.increments) { foreach ($r in @($i.releases)) { $r.proven = $null; $r.legacy = $null } }
        (@(Test-GateProvenProjection -GateProven ([pscustomobject]@{ date = $null; editions = @{}; releases = @{} }) -Status $x) -join ' ') | Should -Match 'nothing is proven'
    }
}

Describe 'Validate-Distribution check 14: the record is required' {
    BeforeAll {
        function Invoke-Check14([string]$Root) { (& pwsh -NoProfile -File $script:validator -RepoRoot $Root 2>&1 | ForEach-Object { "$_" }) -join "`n" }
        function New-Tree {
            $d = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $p = ConvertTo-GateProvenProjection -Status (Read-Status)
            Write-Text (Join-Path $d 'layers/INDEX.json') ([ordered]@{ gateProven = [ordered]@{ date = $p.date; editions = $p.editions; releases = $p.releases }; layers = @() } | ConvertTo-Json -Depth 10)
            return $d
        }
    }
    It 'FAILs when gateProven names editions and layers/editions-record.json is missing' {
        Invoke-Check14 (New-Tree) | Should -Match 'FAIL[^\r\n]*editions-record\.json is missing'
    }
    It 'FAILs a null extract' {
        $d = New-Tree; Write-Text (Join-Path $d 'layers/editions-record.json') 'null'
        Invoke-Check14 $d | Should -Match 'FAIL[^\r\n]*gateProven is the projection of the editions record[^\r\n]*missing'
    }
    It 'PASSes the projection of a committed extract' {
        $d = New-Tree; Write-Text (Join-Path $d 'layers/editions-record.json') (ConvertTo-EditionsRecordExtract -Status (Read-Status) | ConvertTo-Json -Depth 10)
        Invoke-Check14 $d | Should -Match 'PASS[^\r\n]*gateProven is the projection of the editions record'
    }
}

Describe 'print-release-tags: edition tags come from gateProven.releases' {
    It 'tags the release the record proved' {
        $d = New-TagTree -ReleaseTag 'editions/swift-demo/5.4.1' -MapVersion '5.4.1'
        $out = (& pwsh -NoProfile -File (Join-Path $d 'tools/ci/print-release-tags.ps1') -RepoRoot $d 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should -Match "git tag -a 'editions/swift-demo/5\.4\.1'"
    }
    It 'refuses when the release version map disagrees with the proven release' {
        $d = New-TagTree -ReleaseTag 'editions/swift-demo/5.4.1' -MapVersion '5.5.0'
        $out = (& pwsh -NoProfile -File (Join-Path $d 'tools/ci/print-release-tags.ps1') -RepoRoot $d 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should -Match 'no tag is cut on a mismatch'
        $out | Should -Not -Match "git tag -a 'editions/swift-demo"
    }
}
