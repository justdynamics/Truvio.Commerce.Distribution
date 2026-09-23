<#
.SYNOPSIS
Pester (v5+) tests for tools/ci/Test-VersionSpine.ps1: the version order, the spine shape and
reasons, floor <= current, current <= gateProven, the contract copy, and the floor rule
(owner ruling redesign-floors, 2026-09-23). No network, no host.

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

Every check is shown FAILING on a fixture that breaches it before its pass on the shipped files
is trusted.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Test-VersionSpine.ps1')
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

    function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json }
    # A deep copy, so one test's edit never leaks into the next.
    function Copy-Doc($Doc) { $Doc | ConvertTo-Json -Depth 20 | ConvertFrom-Json }
    function Get-Fails($Rows) { @($Rows | Where-Object { -not $_.ok }) }

    $script:spine    = Read-Json (Join-Path $script:repoRoot 'versions\spine.json')
    $script:contract = Read-Json (Join-Path $script:repoRoot 'layers\base\base.contract.json')
    $script:gp       = (Read-Json (Join-Path $script:repoRoot 'layers\INDEX.json')).gateProven

    function Invoke-Spine {
        param($Spine = $script:spine, $Contract = $script:contract, $GateProven = $script:gp,
              $BaseSpine = $null, [string]$BaseState = 'skipped')
        Test-VersionSpine -Spine $Spine -Contract $Contract -GateProven $GateProven `
            -BaseSpine $BaseSpine -BaseState $BaseState -BaseLabel 'origin/main'
    }
    function Get-Floor($Spine, [string]$Component, [string]$Consumer) {
        @($Spine.components.$Component.floors | Where-Object { $_.consumer -eq $Consumer })[0]
    }
}

Describe 'Compare-SpineVersion - SemVer 2.0 with NuGet prerelease labels' {
    It 'compares core segments numerically, never as strings (10.8.4 < 10.28.12)' {
        Compare-SpineVersion -A '10.8.4'   -B '10.28.12' | Should -Be -1
        Compare-SpineVersion -A '10.28.12' -B '10.28.9'  | Should -Be 1
        Compare-SpineVersion -A '10.9.0'   -B '10.28.1'  | Should -Be -1
        Compare-SpineVersion -A '10.28.1'  -B '10.28.1.0' | Should -Be 0
    }
    It 'ranks a prerelease BELOW its release' {
        Compare-SpineVersion -A '0.4.4-BETA' -B '0.4.4' | Should -Be -1
        Compare-SpineVersion -A '10.28.1-PreRelease' -B '10.28.1' | Should -Be -1
        Compare-SpineVersion -A '0.4.5-beta' -B '0.4.4' | Should -Be 1
    }
    It 'reads prerelease labels case-insensitively, as NuGet does (0.6.0-BETA == 0.6.0-beta)' {
        Compare-SpineVersion -A '0.6.0-BETA' -B '0.6.0-beta' | Should -Be 0
        Compare-SpineVersion -A '0.4.4-BETA' -B '0.4.4-beta' | Should -Be 0
    }
    It 'compares numeric identifiers numerically and ranks them below alphanumerics' {
        Compare-SpineVersion -A '1.0.0-beta.10' -B '1.0.0-beta.9' | Should -Be 1
        Compare-SpineVersion -A '1.0.0-1'       -B '1.0.0-alpha'  | Should -Be -1
        Compare-SpineVersion -A '1.0.0-alpha'   -B '1.0.0-beta'   | Should -Be -1
        Compare-SpineVersion -A '1.0.0-beta'    -B '1.0.0-beta.1' | Should -Be -1
    }
    It 'ignores build metadata and a leading v' {
        Compare-SpineVersion -A 'v2.4.0' -B '2.4.0' | Should -Be 0
        Compare-SpineVersion -A '1.0.6-beta+abc' -B '1.0.6-beta' | Should -Be 0
    }
}

Describe 'the shipped spine' {
    It 'passes every check against the shipped contract and gateProven' {
        $fails = Get-Fails (Invoke-Spine)
        ($fails | ForEach-Object { $_.msg }) -join "`n" | Should -BeNullOrEmpty
    }
    It 'names Dynamicweb.MCP as the retired PREDECESSOR of the MCP add-in, never as an alias' {
        Resolve-SpineComponent -Spine $script:spine -Id 'truvio.commerce.mcp' | Should -Be 'mcp'
        Resolve-SpineComponent -Spine $script:spine -Id 'Dynamicweb.MCP'      | Should -BeNullOrEmpty
        Resolve-SpineComponent -Spine $script:spine -Id 'Nope.Package'        | Should -BeNullOrEmpty
        @($script:spine.components.mcp.ids.predecessors) | Should -Be @('Dynamicweb.MCP')
        (Get-SpineIds -Component $script:spine.components.mcp -IncludePredecessors) | Should -Be @('Truvio.Commerce.MCP', 'Dynamicweb.MCP')
    }
    It 'states the MCP floor 0.6.0-beta for both consumers, with the owner reason' {
        foreach ($cons in 'layers', 'skills') {
            $f = Get-Floor $script:spine 'mcp' $cons
            $f.min | Should -Be '0.6.0-beta'
            $f.reason.ref | Should -Be 'dynamicweb/skills#137'
            $f.PSObject.Properties.Name | Should -Not -Contain 'flag'
        }
    }
    It 'gives every floor a reason ref' {
        foreach ($c in $script:spine.components.PSObject.Properties) {
            foreach ($f in @($c.Value.floors)) { "$($f.reason.ref)" | Should -Not -BeNullOrEmpty }
        }
    }
}

Describe 'S2 reasons and S1 ids' {
    It 'FAILs a floor with no reason ref' {
        $s = Copy-Doc $script:spine
        (Get-Floor $s 'serializer' 'layers').reason.ref = ''
        (Get-Fails (Invoke-Spine -Spine $s)).msg -join ' ' | Should -Match "serializer floor for consumer 'layers' carries reason\.ref"
    }
    It 'FAILs a reason ref that names neither an issue/PR nor a commit' {
        $s = Copy-Doc $script:spine
        (Get-Floor $s 'serializer' 'layers').reason.ref = 'see the chat'
        (Get-Fails (Invoke-Spine -Spine $s)).Count | Should -BeGreaterThan 0
    }
    It 'FAILs an alias claimed by two components, a predecessor included' {
        $s = Copy-Doc $script:spine
        $s.components.serializer.ids.aliases = @('Dynamicweb.MCP')
        (Get-Fails (Invoke-Spine -Spine $s)).msg -join ' ' | Should -Match "id 'Dynamicweb\.MCP' is claimed by both"
    }
}

Describe 'S3 a floor never exceeds current' {
    It 'FAILs a floor above the proven version' {
        $s = Copy-Doc $script:spine
        (Get-Floor $s 'mcp' 'skills').min = '0.7.0-beta'
        (Get-Fails (Invoke-Spine -Spine $s)).msg -join ' ' | Should -Match "mcp floor for consumer 'skills' min '0\.7\.0-beta' is at or below current"
    }
    It 'FAILs a ring floor newer than the current ring' {
        $s = Copy-Doc $script:spine
        (Get-Floor $s 'dw' 'layers').ring = 'R0'
        (Get-Fails (Invoke-Spine -Spine $s)).msg -join ' ' | Should -Match "ring 'R0' is not newer than current ring 'R1'"
    }
    It 'FAILs a floor on a component with no current version' {
        $s = Copy-Doc $script:spine
        $s.components.storefront.floors = @([pscustomobject]@{ consumer = 'x'; min = '1.0.0'; reason = [pscustomobject]@{ ref = 'o/r#1'; why = 'w' } })
        (Get-Fails (Invoke-Spine -Spine $s)).msg -join ' ' | Should -Match 'has no current version'
    }
}

Describe 'S4 current never runs ahead of gateProven' {
    It 'FAILs a gateProven-sourced current above gateProven' {
        $s = Copy-Doc $script:spine
        $s.components.serializer.current.version = '1.0.7-beta'
        (Get-Fails (Invoke-Spine -Spine $s)).msg -join ' ' | Should -Match "serializer current '1\.0\.7-beta' does not run ahead"
    }
    It 'PASSes a current that lags gateProven, and says so (a lag is not a defect)' {
        $s = Copy-Doc $script:spine
        $s.components.dw.current.version = '10.28.11'
        $rows = Invoke-Spine -Spine $s
        (Get-Fails $rows).Count | Should -Be 0
        ($rows | Where-Object { $_.msg -match 'dw current' }).msg | Should -Match 'gateProven is ahead'
    }
}

Describe 'S5 the base contract copies the layers floors' {
    It 'FAILs a contract floor that differs from the spine' {
        $c = Copy-Doc $script:contract
        ($c.compat.apps | Where-Object { $_.id -eq 'Truvio.Commerce.MCP' }).min = '0.6.0'
        (Get-Fails (Invoke-Spine -Contract $c)).msg -join ' ' | Should -Match "compat\.apps 'Truvio\.Commerce\.MCP' min '0\.6\.0'"
    }
    It 'FAILs a contract that names an app by its alias, pointing at the canonical id' {
        $s = Copy-Doc $script:spine
        $s.components.mcp.ids.aliases = @('Truvio.MCP')
        $c = Copy-Doc $script:contract
        ($c.compat.apps | Where-Object { $_.id -eq 'Truvio.Commerce.MCP' }).id = 'Truvio.MCP'
        (Get-Fails (Invoke-Spine -Spine $s -Contract $c)).msg -join ' ' | Should -Match "found it under 'Truvio\.MCP'"
    }
    It 'FAILs a contract that names the retired predecessor, naming the current package' {
        $c = Copy-Doc $script:contract
        ($c.compat.apps | Where-Object { $_.id -eq 'Truvio.Commerce.MCP' }).id = 'Dynamicweb.MCP'
        (Get-Fails (Invoke-Spine -Contract $c)).msg -join ' ' | Should -Match "found the retired predecessor 'Dynamicweb\.MCP'"
    }
    It 'FAILs a contract app with no spine floor behind it' {
        $c = Copy-Doc $script:contract
        $c.compat.apps += [pscustomobject]@{ id = 'Truvio.Commerce.PowerTools'; min = '0.12.0-beta'; required = $false }
        (Get-Fails (Invoke-Spine -Contract $c)).msg -join ' ' | Should -Match "names 'Truvio\.Commerce\.PowerTools', which has no spine floor"
    }
    It 'FAILs a dw floor the contract did not copy' {
        $c = Copy-Doc $script:contract
        $c.compat.dw.min = '10.28.12'
        (Get-Fails (Invoke-Spine -Contract $c)).msg -join ' ' | Should -Match "compat\.dw\.min '10\.28\.12' equals the spine layers floor '10\.28\.1'"
    }
}

Describe 'S6 the floor rule: a floor rises only when a consumer depends on the fix' {
    BeforeAll {
        # The base: the shipped spine with the serializer layers floor one release lower.
        $script:base = Copy-Doc $script:spine
        (Get-Floor $script:base 'serializer' 'layers').min = '1.0.5-beta'
        (Get-Floor $script:base 'serializer' 'layers').reason.ref = 'justdynamics/Truvio.Commerce.Serializer#30'
    }
    It 'FAILs a raised floor that keeps the base reason ref' {
        $head = Copy-Doc $script:spine
        (Get-Floor $head 'serializer' 'layers').reason.ref = 'justdynamics/Truvio.Commerce.Serializer#30'
        $fails = Get-Fails (Invoke-Spine -Spine $head -BaseSpine $script:base -BaseState 'present')
        $fails.msg -join ' ' | Should -Match 'floor raised without a consumer reason: serializer floor for .layers. \(min 1\.0\.5-beta -> 1\.0\.6-beta\)'
    }
    It 'PASSes the same raise when it cites a new consumer reason' {
        $rows = Invoke-Spine -BaseSpine $script:base -BaseState 'present'
        (Get-Fails $rows).Count | Should -Be 0
        ($rows | Where-Object { $_.msg -match 'floor rule' }).msg | Should -Match "with a new consumer reason 'justdynamics/Truvio\.Commerce\.Serializer#32'"
    }
    It 'PASSes a floor that is lowered or unchanged with the same ref' {
        $head = Copy-Doc $script:base
        (Get-Floor $head 'serializer' 'layers').min = '1.0.2-beta'
        $rows = Invoke-Spine -Spine $head -Contract ((Copy-Doc $script:contract) | ForEach-Object {
            ($_.compat.apps | Where-Object { $_.id -eq 'Truvio.Commerce.Serializer' }).min = '1.0.2-beta'; $_.minSerializerVersion = '1.0.2-beta'; $_ }) `
            -BaseSpine $script:base -BaseState 'present'
        (Get-Fails $rows).Count | Should -Be 0
        ($rows | Where-Object { $_.msg -match 'floor rule' }).msg | Should -Match 'no floor raised'
    }
    It 'FAILs a ring moved to a NEWER ring with the base reason ref' {
        $b = Copy-Doc $script:spine
        (Get-Floor $b 'dw' 'layers').ring = 'R2'
        $fails = Get-Fails (Invoke-Spine -BaseSpine $b -BaseState 'present')
        $fails.msg -join ' ' | Should -Match 'floor raised without a consumer reason: dw floor for .layers. \(ring R2 -> R1\)'
    }
    It 'does not count a prerelease case change as a raise (0.6.0-BETA == 0.6.0-beta)' {
        $b = Copy-Doc $script:spine
        (Get-Floor $b 'mcp' 'layers').min = '0.6.0-BETA'
        (Get-Fails (Invoke-Spine -BaseSpine $b -BaseState 'present')).Count | Should -Be 0
    }
    It 'FAILs closed when the merge base could not be read' {
        (Get-Fails (Invoke-Spine -BaseState 'unresolved')).msg -join ' ' | Should -Match 'could not be read'
    }
    It 'PASSes when the base carries no spine yet (every floor is new and carries its own reason)' {
        (Get-Fails (Invoke-Spine -BaseState 'absent')).Count | Should -Be 0
    }
}

Describe 'Get-BaseSpine - reading the spine at the merge base' {
    BeforeAll {
        $script:gitRepo = Join-Path $TestDrive 'repo'
        New-Item -ItemType Directory -Force -Path $script:gitRepo | Out-Null
        & git -C $script:gitRepo init -q -b main 2>$null
        & git -C $script:gitRepo config user.email 't@example.invalid'
        & git -C $script:gitRepo config user.name 't'
        'x' | Set-Content -LiteralPath (Join-Path $script:gitRepo 'README') -Encoding utf8
        & git -C $script:gitRepo add -A; & git -C $script:gitRepo commit -q -m 'no spine'
        & git -C $script:gitRepo tag nospine
        New-Item -ItemType Directory -Force -Path (Join-Path $script:gitRepo 'versions') | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'versions\spine.json') -Destination (Join-Path $script:gitRepo 'versions\spine.json')
        & git -C $script:gitRepo add -A; & git -C $script:gitRepo commit -q -m 'spine'
        & git -C $script:gitRepo tag withspine
    }
    It 'reads a present spine' {
        $r = Get-BaseSpine -RepoRoot $script:gitRepo -BaseRef 'withspine'
        $r.state | Should -Be 'present'
        $r.spine.components.mcp.ids.package | Should -Be 'Truvio.Commerce.MCP'
    }
    It 'reports absent when the base predates the spine' {
        # HEAD is withspine, so the merge base with nospine is nospine itself.
        (Get-BaseSpine -RepoRoot $script:gitRepo -BaseRef 'nospine').state | Should -Be 'absent'
    }
    It 'reports unresolved for a ref that does not exist' {
        (Get-BaseSpine -RepoRoot $script:gitRepo -BaseRef 'origin/nope').state | Should -Be 'unresolved'
    }
}
