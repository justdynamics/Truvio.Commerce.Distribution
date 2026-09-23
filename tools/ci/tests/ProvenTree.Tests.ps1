<#
.SYNOPSIS
Pester (v5+) tests for the provenTree proof key: tools/ci/ProvenTree.ps1 (the validator's check 14)
and the tag rule in tools/ci/print-release-tags.ps1 (owner ruling 2026-09-23, "proof rides with
delivery"). Four cases, each on a throwaway Distribution tree:

  match                   the tree is what the proving run delivered: validator PASS, layer tagged
  mismatch without bump   same version, other tree: validator FAIL, layer not tagged
  mismatch with bump      version bumped: validator NOTE (unproven), layer not tagged
  legacy                  gateProven carries no proofs: validator NOTE, tags keep the pre-key rule

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\ProvenTree.ps1')
    $script:tagScript = (Resolve-Path (Join-Path $PSScriptRoot '..\print-release-tags.ps1')).Path
    $script:run = '20260923-122859'
    $script:commit = 'ae3c6d5688b24941d33ff7de0f815c4f6a530e7c'

    function Write-Text([string]$Path, [string]$Text) {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
        [IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
    }
    function Set-Layer([string]$Repo, [string]$Name, [string]$Version, [string]$Body = 'a: 1') {
        Write-Text (Join-Path $Repo "layers/$Name/layer.json") (@{ name = $Name; version = $Version } | ConvertTo-Json)
        Write-Text (Join-Path $Repo "layers/$Name/merge/row.yml") "$Body`n"
    }
    function Set-Index([string]$Repo, $Proofs) {
        $gp = [ordered]@{
            date = '2026-09-23'; dw = [ordered]@{ ring = 'R1-NET10'; version = '10.28.12' }; swift = @{ tag = 'v2.4.0' }
            gateRunId = $script:run; swiftVersion = '2.4.0'; dwPlatformVersion = '10.28.12'
            editions = [ordered]@{ 'swift-demo' = $script:run }
        }
        if ($Proofs) { $gp.proofs = $Proofs }
        Write-Text (Join-Path $Repo 'layers/INDEX.json') ([ordered]@{ gateProven = $gp; layers = @() } | ConvertTo-Json -Depth 10)
    }
    function Set-Edition([string]$Repo, [string]$FeatureVersion = '1.0.0') {
        Write-Text (Join-Path $Repo 'editions/swift-demo.json') (@{ name = 'swift-demo'; from = 'base@1.0.0'; add = @("feature-x@$FeatureVersion") } | ConvertTo-Json)
    }
    # The proof a restamp would write for the tree as it stands.
    function Get-ProofFor([string]$Repo) {
        $tree = [ordered]@{}
        foreach ($n in 'base', 'feature-x') {
            $v = (Get-Content -Raw (Join-Path $Repo "layers/$n/layer.json") | ConvertFrom-Json).version
            $tree[$n] = [ordered]@{ version = $v; hash = Get-LayerTreeHash -LayerPath (Join-Path $Repo "layers/$n") }
        }
        [ordered]@{ 'swift-demo' = [ordered]@{ runId = $script:run; deliveryRunId = '20260923-122725'; distributionCommit = $script:commit
                                               checkSet = 2; harnessCommit = $script:commit; algorithm = 'layer-tree/v1'; provenTree = $tree } }
    }
    # A proven Distribution tree: base 1.0.0 + feature-x 1.0.0, stamped with its own proof (or none).
    function New-ProvenRepo([switch]$Legacy) {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        Set-Layer $repo 'base' '1.0.0'
        Set-Layer $repo 'feature-x' '1.0.0'
        Set-Edition $repo
        Set-Index $repo $(if ($Legacy) { $null } else { Get-ProofFor $repo })
        return $repo
    }
    function Read-Gp([string]$Repo) { (Get-Content -Raw (Join-Path $Repo 'layers/INDEX.json') | ConvertFrom-Json).gateProven }
    function Get-Findings([string]$Repo) { @(Get-ProvenTreeFinding -Status @(Get-ProvenTreeStatus -RepoRoot $Repo -GateProven (Read-Gp $Repo))) }
    function Invoke-Tags([string]$Repo) { @(& pwsh -NoProfile -File $script:tagScript -RepoRoot $Repo *>&1 | ForEach-Object { "$_" }) }
}

Describe 'provenTree: match' {
    BeforeAll { $script:repo = New-ProvenRepo }
    It 'the validator passes every proven layer' {
        $f = Get-Findings $script:repo
        @($f | Where-Object level -eq 'PASS').Count | Should -Be 2
        @($f | Where-Object level -ne 'PASS').Count | Should -Be 0
        @(Test-ProvenTreeShape -GateProven (Read-Gp $script:repo)).Count | Should -Be 0
    }
    It 'release-tags tags each layer with its run and tree, and the edition with the verified provenTree' {
        $out = Invoke-Tags $script:repo
        $h = Get-LayerTreeHash -LayerPath (Join-Path $script:repo 'layers/feature-x')
        @($out | Where-Object { $_ -like "git tag -a 'layers/feature-x/1.0.0'*gate run $($script:run), tree $h*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like "git tag -a 'layers/base/1.0.0'*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like "git tag -a 'editions/swift-demo/*provenTree verified (2 layers)*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like '*Notice*' }).Count | Should -Be 0
    }
}

Describe 'provenTree: mismatch without a version bump' {
    BeforeAll {
        $script:repo = New-ProvenRepo
        Set-Layer $script:repo 'feature-x' '1.0.0' 'a: 2'     # the tree moves, the version does not
    }
    It 'the validator FAILs: layer X changed since proving run Y without a version bump' {
        $f = Get-Findings $script:repo
        $fail = @($f | Where-Object level -eq 'FAIL')
        $fail.Count | Should -Be 1
        $fail[0].message | Should -BeLike "layer feature-x changed since proving run $($script:run) without a version bump*"
        @($f | Where-Object { $_.level -eq 'PASS' -and $_.message -like '*layer base *' }).Count | Should -Be 1
    }
    It 'release-tags does not tag the layer or the edition: tree differs from proving run' {
        $out = Invoke-Tags $script:repo
        @($out | Where-Object { $_ -like "git tag -a 'layers/feature-x/*" }).Count | Should -Be 0
        @($out | Where-Object { $_ -like "#   - layers/feature-x/1.0.0 (tree differs from proving run $($script:run)*changed-without-bump*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like "git tag -a 'layers/base/1.0.0'*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like "git tag -a 'editions/swift-demo/*" }).Count | Should -Be 0
        @($out | Where-Object { $_ -like "#   - editions/swift-demo/* (tree differs from proving run $($script:run): feature-x changed-without-bump)" }).Count | Should -Be 1
    }
}

Describe 'provenTree: mismatch with a version bump' {
    BeforeAll {
        $script:repo = New-ProvenRepo
        Set-Layer $script:repo 'feature-x' '1.0.1' 'a: 2'     # a delivery PR before its gate run restamps
        Set-Edition $script:repo '1.0.1'
    }
    It 'the validator passes with a NOTE: the layer is unproven and will not be tagged' {
        $f = Get-Findings $script:repo
        @($f | Where-Object level -eq 'FAIL').Count | Should -Be 0
        $note = @($f | Where-Object level -eq 'NOTE')
        $note.Count | Should -Be 1
        $note[0].message | Should -BeLike "layer feature-x 1.0.1 is unproven: proving run $($script:run) delivered 1.0.0*release-tags will not tag it*"
    }
    It 'release-tags lists it under Not tagged here: tree differs from proving run' {
        $out = Invoke-Tags $script:repo
        @($out | Where-Object { $_ -like "git tag -a 'layers/feature-x/*" }).Count | Should -Be 0
        @($out | Where-Object { $_ -like "#   - layers/feature-x/1.0.1 (tree differs from proving run $($script:run)*unproven*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like "git tag -a 'layers/base/1.0.0'*" }).Count | Should -Be 1
    }
}

Describe 'provenTree: legacy gateProven (no proofs yet)' {
    BeforeAll {
        $script:repo = New-ProvenRepo -Legacy
        Set-Layer $script:repo 'feature-x' '1.0.0' 'a: 2'     # undetectable before the key: today's rule stands
    }
    It 'the validator passes with a legacy NOTE and no hash is computed' {
        $f = Get-Findings $script:repo
        $f.Count | Should -Be 1
        $f[0].level | Should -Be 'NOTE'
        $f[0].message | Should -BeLike "edition swift-demo (run $($script:run)) carries no provenTree yet*"
    }
    It 'release-tags keeps the pre-key rule (every composed layer tagged, no tree in the message) and prints a notice' {
        $out = Invoke-Tags $script:repo
        $l = @($out | Where-Object { $_ -like "git tag -a 'layers/feature-x/1.0.0'*" })
        $l.Count | Should -Be 1
        $l[0] | Should -Not -BeLike '*tree sha256*'
        @($out | Where-Object { $_ -like "git tag -a 'editions/swift-demo/*" }).Count | Should -Be 1
        @($out | Where-Object { $_ -like '*gateProven carries no provenTree yet for swift-demo (legacy)*' }).Count | Should -Be 1
    }
}

Describe 'provenTree: shape' {
    It 'rejects a proof whose runId is not the attested run, a bad hash, a bad commit and an unknown algorithm' {
        $repo = New-ProvenRepo
        $gp = Read-Gp $repo
        $p = $gp.proofs.'swift-demo'
        $p.runId = '20260101-000000'; $p.distributionCommit = 'abc'; $p.algorithm = 'layer-tree/v9'
        $p.provenTree.base.hash = 'sha1:00'
        $problems = @(Test-ProvenTreeShape -GateProven $gp)
        ($problems -join ' | ') | Should -BeLike '*runId*not the attested run*'
        ($problems -join ' | ') | Should -BeLike '*distributionCommit must be a 40-hex commit*'
        ($problems -join ' | ') | Should -BeLike "*algorithm 'layer-tree/v9'*"
        ($problems -join ' | ') | Should -BeLike '*provenTree.base.hash must be sha256*'
    }
    It 'rejects a proof for an edition gateProven does not attest' {
        $repo = New-ProvenRepo
        $gp = Read-Gp $repo
        $gp.proofs | Add-Member -NotePropertyName 'dap-portal' -NotePropertyValue $gp.proofs.'swift-demo'
        (@(Test-ProvenTreeShape -GateProven $gp) -join ' | ') | Should -BeLike '*proofs.dap-portal names an edition absent from gateProven.editions*'
    }
    It 'reports a proven layer that is gone from the tree as missing, never as a failure' {
        $repo = New-ProvenRepo
        Remove-Item -Recurse -Force (Join-Path $repo 'layers/feature-x')
        $f = Get-Findings $repo
        @($f | Where-Object level -eq 'FAIL').Count | Should -Be 0
        @($f | Where-Object { $_.level -eq 'NOTE' -and $_.message -like '*feature-x*not in this tree*' }).Count | Should -Be 1
    }
}
