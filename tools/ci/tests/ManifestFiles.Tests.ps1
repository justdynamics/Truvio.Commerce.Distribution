<#
.SYNOPSIS
Pester (v5+) tests for tools/ci/Test-ManifestFiles.ps1: SqlTable entries of a layer manifest must
name in files[] exactly the *.yml files in their _sql/<table>/ directory (Distribution #89, part 1).

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

The fixture mirrors the committed manifests: files[] is relative to the mode directory,
'/'-separated, and lists _meta.yml like any row file. A Content entry rides along to prove it is
ignored (Content is #89 part 2).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Test-ManifestFiles.ps1')

    # Write a merge/ mode directory with one SqlTable entry (EcomShops) and one Content entry.
    # -Declared overrides the entry's files[]; -OnDisk overrides the row files written.
    function New-FixtureManifest {
        param(
            [string[]]$Declared = @('_sql/EcomShops/_meta.yml', '_sql/EcomShops/SHOP1.yml', '_sql/EcomShops/SHOP2.yml'),
            [string[]]$OnDisk   = @('_meta.yml', 'SHOP1.yml', 'SHOP2.yml')
        )
        $mode = Join-Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))) 'merge'
        $tableDir = Join-Path (Join-Path $mode '_sql') 'EcomShops'
        [void][IO.Directory]::CreateDirectory($tableDir)
        foreach ($f in $OnDisk) { [IO.File]::WriteAllText((Join-Path $tableDir $f), "k: v`n") }
        $manifest = [ordered]@{
            schemaVersion = 2; mode = 'merge'; complete = $true
            entries = @(
                [ordered]@{ providerType = 'SqlTable'; table = 'EcomShops'; entryId = 'sql/EcomShops'; files = @($Declared) }
                [ordered]@{ providerType = 'Content'; entryId = 'content/x'; files = @('Area/Not On Disk.yml') }
            )
        }
        $path = Join-Path $mode 'merge-manifest.json'
        $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding utf8
        return $path
    }
}

Describe 'Test-SqlTableManifestFiles - SqlTable files[] vs disk' {
    It 'passes a SqlTable entry whose files[] matches its directory, and ignores Content entries' {
        $r = @(Test-SqlTableManifestFiles -ManifestPath (New-FixtureManifest))
        $r.Count | Should -Be 1
        $r[0].table | Should -BeExactly 'EcomShops'
        $r[0].ok | Should -BeTrue
        $r[0].declared | Should -Be 3
        $r[0].onDisk | Should -Be 3
        (Get-SqlTableManifestFilesFinding -Label 'fx' -Results $r).ok | Should -BeTrue
    }

    It 'fails a declared row file that is missing on disk, and names it' {
        $r = @(Test-SqlTableManifestFiles -ManifestPath (New-FixtureManifest -OnDisk @('_meta.yml', 'SHOP1.yml')))
        $r[0].ok | Should -BeFalse
        $r[0].notOnDisk | Should -Be @('_sql/EcomShops/SHOP2.yml')
        $r[0].notDeclared.Count | Should -Be 0
        $f = Get-SqlTableManifestFilesFinding -Label 'fx' -Results $r
        $f.ok | Should -BeFalse
        $f.msg | Should -Match 'declared-not-on-disk 1: _sql/EcomShops/SHOP2\.yml'
    }

    It 'fails a row file on disk that files[] does not declare, and names it' {
        $r = @(Test-SqlTableManifestFiles -ManifestPath (New-FixtureManifest -OnDisk @('_meta.yml', 'SHOP1.yml', 'SHOP2.yml', 'SHOP3.yml')))
        $r[0].ok | Should -BeFalse
        $r[0].notDeclared | Should -Be @('_sql/EcomShops/SHOP3.yml')
        $r[0].notOnDisk.Count | Should -Be 0
        $f = Get-SqlTableManifestFilesFinding -Label 'fx' -Results $r
        $f.ok | Should -BeFalse
        $f.msg | Should -Match 'disk-not-declared 1: _sql/EcomShops/SHOP3\.yml'
    }

    It 'fails a renamed row file in both directions (the PR #88 case)' {
        $r = @(Test-SqlTableManifestFiles -ManifestPath (New-FixtureManifest -OnDisk @('_meta.yml', 'SHOP1.yml', 'Shop Two.yml')))
        $r[0].ok | Should -BeFalse
        $r[0].notOnDisk | Should -Be @('_sql/EcomShops/SHOP2.yml')
        $r[0].notDeclared | Should -Be @('_sql/EcomShops/Shop Two.yml')
    }

    It 'fails an undeclared _meta.yml like any other file' {
        $r = @(Test-SqlTableManifestFiles -ManifestPath (New-FixtureManifest -Declared @('_sql/EcomShops/SHOP1.yml', '_sql/EcomShops/SHOP2.yml')))
        $r[0].ok | Should -BeFalse
        $r[0].notDeclared | Should -Be @('_sql/EcomShops/_meta.yml')
    }

    It 'returns nothing for a manifest with no SqlTable entry' {
        $p = New-FixtureManifest
        $doc = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
        $doc.entries = @($doc.entries | Where-Object { $_.providerType -ne 'SqlTable' })
        $doc | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $p -Encoding utf8
        @(Test-SqlTableManifestFiles -ManifestPath $p).Count | Should -Be 0
    }
}
