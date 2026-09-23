<#
.SYNOPSIS
Pester (v5+) golden tests for tools/ci/Get-LayerTreeHash.ps1, the layer-tree/v1 hash the Foundry
records in gateProven.proofs.<edition>.provenTree and this repository recomputes.

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

The fixture is written byte by byte, so no checkout setting (core.autocrlf, .gitattributes) can
change it. The golden hash was computed twice, by this script and by an independent Python
implementation of the same definition, and both gave the value pinned below. A change to the
pinned values is a change to the algorithm: it needs a new id (layer-tree/v2), never an edit here.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Get-LayerTreeHash.ps1')
    $script:hashScript = (Resolve-Path (Join-Path $PSScriptRoot '..\Get-LayerTreeHash.ps1')).Path

    $script:golden = 'sha256:9f78ecea129110e95409e56123c5eaaf9a3d34a885fad23202ddecdc3cda966c'
    $script:goldenManifest = @(
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  files/.gitkeep'
        '1b7bc7eb4a7b7149b5cc8b0f7ad226fec3d2a53e07fb02afd88b907549c47ebe  files/docs/guide.md'
        '9bbd2e0d0232e587c007690a6704fd8baff6b524b26800a9c550a67aa8fd4850  files/img.bin'
        'fb41f7ca3dca5a038e296f4f4d73a45a13f60f8840ca4d136fbb5dcaf99a0321  layer.json'
        '367d1c77eadc1495a7db4200f46a8b90ea1fa926282722d308c05a65098a4112  merge/lone-cr.txt'
        'd09edadd173a8bbc233d47dcafc30cc876af2fb569812f2bbe0e92a1905bbce8  replace/A.yml'
        'd02b8bb58aa82e872f709035f39b734b9f28dde0c3d305698a95d04aec594cfa  replace/b.yml'
    ) -join "`n"

    $script:utf8 = [System.Text.UTF8Encoding]::new($false)
    function Get-FixtureFiles {
        [ordered]@{
            'layer.json'          = $script:utf8.GetBytes("{`"name`":`"fx`",`"version`":`"1.0.0`"}`n")
            'README.md'           = $script:utf8.GetBytes("readme`r`n")
            'CHANGELOG.md'        = $script:utf8.GetBytes("# 1.0.0`n")
            'replace/b.yml'       = $script:utf8.GetBytes("a: 1`r`nb: 2`r`n")
            'replace/A.yml'       = $script:utf8.GetBytes("x: 1`n")
            'files/img.bin'       = [byte[]](0x89, 0x50, 0x00, 0x0D, 0x0A, 0xFF)
            'files/docs/guide.md' = $script:utf8.GetBytes("# guide`n")
            'files/.gitkeep'      = [byte[]]@()
            'merge/lone-cr.txt'   = $script:utf8.GetBytes("a`rb`r`n")
        }
    }
    # Write a fixture layer; -Override replaces or adds files, a $null value removes one.
    function New-FixtureLayer {
        param([hashtable]$Override = @{})
        $dir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $files = Get-FixtureFiles
        foreach ($k in $Override.Keys) { $files[$k] = $Override[$k] }
        foreach ($k in $files.Keys) {
            if ($null -eq $files[$k]) { continue }
            $p = Join-Path $dir $k
            [void][IO.Directory]::CreateDirectory((Split-Path -Parent $p))
            [IO.File]::WriteAllBytes($p, [byte[]]$files[$k])
        }
        return $dir
    }
}

Describe 'Get-LayerTreeHash - layer-tree/v1 golden' {
    It 'hashes the fixture to the pinned golden value' {
        Get-LayerTreeHash -LayerPath (New-FixtureLayer) | Should -BeExactly $script:golden
    }
    It 'writes the pinned canonical manifest: ordinal path order, sha256sum lines, / separators, root Markdown excluded' {
        (Get-LayerTreeManifest -LayerPath (New-FixtureLayer)).TrimEnd("`n") | Should -BeExactly $script:goldenManifest
    }
    It 'names the algorithm layer-tree/v1' {
        $script:LayerTreeHashAlgorithm | Should -BeExactly 'layer-tree/v1'
    }
    It 'prints the same hash when executed as a script (the CLI the Foundry and CI can call)' {
        $dir = New-FixtureLayer
        (& pwsh -NoProfile -File $script:hashScript -LayerPath $dir | Select-Object -Last 1) | Should -BeExactly $script:golden
    }
}

Describe 'Get-LayerTreeHash - OS independence' {
    It 'hashes a CRLF checkout of the text files to the same value as an LF one' {
        $crlf = New-FixtureLayer -Override @{
            'layer.json'          = $script:utf8.GetBytes("{`"name`":`"fx`",`"version`":`"1.0.0`"}`r`n")
            'replace/A.yml'       = $script:utf8.GetBytes("x: 1`r`n")
            'replace/b.yml'       = $script:utf8.GetBytes("a: 1`nb: 2`n")
            'files/docs/guide.md' = $script:utf8.GetBytes("# guide`r`n")
        }
        Get-LayerTreeHash -LayerPath $crlf | Should -BeExactly $script:golden
    }
    It 'keeps a lone CR (only CR LF pairs are line endings)' {
        $dir = New-FixtureLayer -Override @{ 'merge/lone-cr.txt' = $script:utf8.GetBytes("a`nb`n") }
        Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden
    }
    It 'hashes a binary file (a NUL in its first 8000 bytes) as it is: CR LF inside it is content' {
        $dir = New-FixtureLayer -Override @{ 'files/img.bin' = [byte[]](0x89, 0x50, 0x00, 0x0A, 0xFF) }
        Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden
    }
    It 'ignores an empty directory (git carries none)' {
        $dir = New-FixtureLayer
        [void][IO.Directory]::CreateDirectory((Join-Path $dir 'templates/empty'))
        Get-LayerTreeHash -LayerPath $dir | Should -BeExactly $script:golden
    }
}

Describe 'Get-LayerTreeHash - what the tree covers' {
    It 'ignores the layer-root documentation (README.md, CHANGELOG.md, any <layer>/*.md)' {
        $dir = New-FixtureLayer -Override @{ 'README.md' = $script:utf8.GetBytes('changed'); 'BASE.md' = $script:utf8.GetBytes('new doc') }
        Get-LayerTreeHash -LayerPath $dir | Should -BeExactly $script:golden
    }
    It 'covers Markdown below the root (files/ ships whatever it holds)' {
        $dir = New-FixtureLayer -Override @{ 'files/docs/guide.md' = $script:utf8.GetBytes("# guide v2`n") }
        Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden
    }
    It 'covers a version bump in layer.json' {
        $dir = New-FixtureLayer -Override @{ 'layer.json' = $script:utf8.GetBytes("{`"name`":`"fx`",`"version`":`"1.0.1`"}`n") }
        Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden
    }
    It 'covers every delivered tree, not only replace/merge/files (config/, repositories/, templates/, itemtypes/, src/)' {
        foreach ($tree in 'config', 'repositories', 'templates', 'itemtypes', 'src') {
            $dir = New-FixtureLayer -Override @{ "$tree/x.txt" = $script:utf8.GetBytes('x') }
            Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden -Because "$tree/ is part of the tagged tree"
        }
    }
    It 'covers a rename (the path is part of the hash)' {
        $dir = New-FixtureLayer -Override @{ 'replace/A.yml' = $null; 'replace/a2.yml' = $script:utf8.GetBytes("x: 1`n") }
        Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden
    }
    It 'covers a one-byte content change' {
        $dir = New-FixtureLayer -Override @{ 'replace/A.yml' = $script:utf8.GetBytes("x: 2`n") }
        Get-LayerTreeHash -LayerPath $dir | Should -Not -Be $script:golden
    }
    It 'throws on a missing directory' {
        { Get-LayerTreeHash -LayerPath (Join-Path $TestDrive 'nope') } | Should -Throw '*layer directory not found*'
    }
}
