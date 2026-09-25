<#
.SYNOPSIS
Pester (v5+) tests for tools/ci/Test-ManifestFiles.ps1: SqlTable entries of a layer manifest must
name in files[] exactly the *.yml files in their _sql/<table>/ directory (Distribution #89, part 1).

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

The fixture mirrors the committed manifests: files[] is relative to the mode directory,
'/'-separated, and lists _meta.yml like any row file. A Content entry rides along to prove the
SqlTable check ignores it; Test-ContentManifestFiles (#89 part 2) has its own Describe below.
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

Describe 'Test-ContentManifestFiles - Content files[] vs disk (#89 part 2)' {
    BeforeAll {
        # Write <mode>/_content/<files> and, unless -NoManifest, a manifest whose Content entries
        # are given as @{ path; files } (areaName 'Swift 2').
        function New-ContentFixture {
            param(
                [string]$Mode = 'merge',
                [string[]]$OnDisk,
                [object[]]$Entries = @(),
                [switch]$NoManifest
            )
            $modeDir = Join-Path (Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))) $Mode
            [void][IO.Directory]::CreateDirectory($modeDir)
            foreach ($f in $OnDisk) {
                $p = Join-Path $modeDir $f
                [void][IO.Directory]::CreateDirectory((Split-Path -Parent $p))
                [IO.File]::WriteAllText($p, "k: v`n")
            }
            if (-not $NoManifest) {
                $manifest = [ordered]@{
                    schemaVersion = 2; mode = $Mode; complete = $true
                    entries = @($Entries | ForEach-Object {
                        [ordered]@{ providerType = 'Content'; areaId = 3; areaName = 'Swift 2'; path = $_.path; pageId = 0
                            entryId = "content/area-3$($_.path)"; files = @($_.files) }
                    })
                }
                $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $modeDir "$Mode-manifest.json") -Encoding utf8
            }
            return $modeDir
        }

        $script:quickOrder = @(
            '_content/Swift 2/Navigation/Secondary Navigation/Quick Order/page.yml'
            '_content/Swift 2/Navigation/Secondary Navigation/Quick Order/grid-row-1/grid-row.yml'
            '_content/Swift 2/Navigation/Secondary Navigation/Quick Order/grid-row-1/paragraph-c1-1.yml'
        )
        $script:quickOrderFrame = @(
            '_content/Swift 2/area.yml'
            '_content/Swift 2/Navigation/page.yml'
            '_content/Swift 2/Navigation/Secondary Navigation/page.yml'
            '_content/templates.manifest.yml'
        )
    }

    It 'passes a subtree entry that lists its frame while the owning layer ships it (the feature-layer shape)' {
        $dir = New-ContentFixture -OnDisk $quickOrder -Entries @(@{ path = '/Navigation/Secondary Navigation/Quick Order'; files = $quickOrder + $quickOrderFrame })
        $r = Test-ContentManifestFiles -ModeDir $dir
        $r.ok | Should -BeTrue
        $r.entries[0].root | Should -BeExactly '_content/Swift 2/Navigation/Secondary Navigation/Quick Order'
        $r.entries[0].frameAbsent.Count | Should -Be 4
        $f = Get-ContentManifestFilesFinding -Label 'fx' -Result $r
        $f.ok | Should -BeTrue
        $f.msg | Should -Match '4 frame file\(s\) listed'
    }

    It 'fails a listed page.yml of a sibling that is not an ancestor of the subtree root' {
        $files = $quickOrder + @('_content/Swift 2/Navigation/Secondary Navigation/Find dealers/page.yml')
        $r = Test-ContentManifestFiles -ModeDir (New-ContentFixture -OnDisk $quickOrder -Entries @(@{ path = '/Navigation/Secondary Navigation/Quick Order'; files = $files }))
        $r.ok | Should -BeFalse
        $r.entries[0].notOnDisk | Should -Be @('_content/Swift 2/Navigation/Secondary Navigation/Find dealers/page.yml')
        $r.entries[0].outside | Should -Be @('_content/Swift 2/Navigation/Secondary Navigation/Find dealers/page.yml')
    }

    It 'fails a moved paragraph in both directions (the surface-swift Mobile Header case)' {
        $disk = @('_content/Swift 2/Header _ Footer/page.yml', '_content/Swift 2/Header _ Footer/Mobile Header/page.yml',
                  '_content/Swift 2/Header _ Footer/Mobile Header/grid-row-2/paragraph-c3-6.yml')
        $decl = @('_content/Swift 2/Header _ Footer/page.yml', '_content/Swift 2/Header _ Footer/Mobile Header/page.yml',
                  '_content/Swift 2/Header _ Footer/Mobile Header/grid-row-3/paragraph-c3-6.yml')
        $r = Test-ContentManifestFiles -ModeDir (New-ContentFixture -OnDisk $disk -Entries @(@{ path = '/Header / Footer'; files = $decl }))
        $r.ok | Should -BeFalse
        $r.entries[0].root | Should -BeExactly '_content/Swift 2/Header _ Footer'
        $r.entries[0].notOnDisk | Should -Be @('_content/Swift 2/Header _ Footer/Mobile Header/grid-row-3/paragraph-c3-6.yml')
        $r.notDeclared | Should -Be @('_content/Swift 2/Header _ Footer/Mobile Header/grid-row-2/paragraph-c3-6.yml')
        $msg = (Get-ContentManifestFilesFinding -Label 'fx' -Result $r).msg
        $msg | Should -Match 'declared-not-on-disk 1'
        $msg | Should -Match 'disk-not-declared by any Content entry 1'
    }

    It 'resolves a whole-area entry and a folder carrying the sibling de-dup suffix' {
        $disk = @('_content/Swift 2/area.yml', '_content/Swift 2/Home/page.yml', '_content/Swift 2/Home [a1b2c3]/page.yml')
        $r = Test-ContentManifestFiles -ModeDir (New-ContentFixture -Mode 'replace' -OnDisk $disk -Entries @(@{ path = '/'; files = $disk }))
        $r.ok | Should -BeTrue
        $r.entries[0].root | Should -BeExactly '_content/Swift 2'
        $r2 = Test-ContentManifestFiles -ModeDir (New-ContentFixture -OnDisk @('_content/Swift 2/Posts [0f0f0f]/page.yml') -Entries @(@{ path = '/Posts'; files = @('_content/Swift 2/Posts [0f0f0f]/page.yml') }))
        $r2.ok | Should -BeTrue
        $r2.entries[0].root | Should -BeExactly '_content/Swift 2/Posts [0f0f0f]'
    }

    It 'fails an entry whose path resolves to no folder' {
        $r = Test-ContentManifestFiles -ModeDir (New-ContentFixture -OnDisk @('_content/Swift 2/Home/page.yml') -Entries @(@{ path = '/Gone'; files = @('_content/Swift 2/Home/page.yml') }))
        $r.ok | Should -BeFalse
        $r.entries[0].reason | Should -Match "path '/Gone'"
    }

    It 'fails a _content tree with no manifest, and passes it when every file is a declared override' {
        $disk = @('_content/Swift 2/Home/grid-row-1/paragraph-c1-18.yml', '_content/Swift 2/Home/page.yml')
        $dir = New-ContentFixture -OnDisk $disk -NoManifest
        $r = Test-ContentManifestFiles -ModeDir $dir
        $r.ok | Should -BeFalse
        $r.notDeclared.Count | Should -Be 2
        $o = Test-ContentManifestFiles -ModeDir $dir -OverrideDeclared $disk
        $o.ok | Should -BeTrue
        $o.overrides.Count | Should -Be 2
        (Get-ContentManifestFilesFinding -Label 'fx' -Result $o).msg | Should -Match '2 declared override\(s\)'
        $p = Test-ContentManifestFiles -ModeDir $dir -OverrideDeclared @($disk[0])
        $p.ok | Should -BeFalse
        $p.notDeclared | Should -Be @('_content/Swift 2/Home/page.yml')
    }

    It 'returns nothing for a mode with no Content entry and no _content tree' {
        $dir = New-ContentFixture -OnDisk @() -Entries @()
        Test-ContentManifestFiles -ModeDir $dir | Should -BeNullOrEmpty
    }

    It 'maps page names onto the Serializer folder names' {
        ConvertTo-ContentFolderName -Name 'Header / Footer' | Should -BeExactly 'Header _ Footer'
        ConvertTo-ContentFolderName -Name ' What? ' | Should -BeExactly 'What_'
        ConvertTo-ContentFolderName -Name '  ' | Should -BeExactly '_unnamed'
    }
}
