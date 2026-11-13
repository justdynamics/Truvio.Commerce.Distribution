<#
ReleaseNotes.Tests.ps1: the release notes of the bacpac releases (tools/ci/ReleaseNotes.ps1,
layers/release-notes.schema.json, Foundry #1604, owner ruling distribution-release-notes-1604).

The generator reads this repository's records at two commits, so the fixture is a real git repository
built in TestDrive: a first registration (blank 10.28.12, swift-demo 5.3.0), a commit that moves the
layers, the DW pin, the Swift release and the spine, and a second registration (blank 10.30.1,
swift-demo 5.6.0 and the first dap-portal release). The red controls: an entry registered after the
rule without its record FAILs, a record naming another previous release stops the notes, a shallow
checkout is refused, and a draft whose notes cannot be generated or attached stays a draft.
No network: gh is a recording fake and Invoke-WebRequest is mocked.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot '..\Bacpac.ps1')
    $script:layersRoot = Join-Path $PSScriptRoot '..\..\..\layers'
    $script:notesSchema = Join-Path $script:layersRoot 'release-notes.schema.json'
    $script:bacpacsSchema = Join-Path $script:layersRoot 'bacpacs.schema.json'
    $script:sha = 'ab' * 32

    function Invoke-FixtureGit {
        param([string]$Repo, [string[]]$ArgumentList)
        $out = & git -C $Repo -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false -c tag.gpgsign=false -c core.autocrlf=false @ArgumentList 2>&1
        if ($LASTEXITCODE -ne 0) { throw "git $($ArgumentList -join ' ') failed: $out" }
        return $out
    }
    function Set-FixtureFile {
        param([string]$Repo, [string]$Path, $Value)
        $full = Join-Path $Repo $Path
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $full))
        $text = if ($Value -is [string]) { $Value } else { $Value | ConvertTo-Json -Depth 12 }
        [IO.File]::WriteAllText($full, $text, [Text.UTF8Encoding]::new($false))
    }
    function Save-FixtureCommit {
        param([string]$Repo, [string]$Message)
        $null = Invoke-FixtureGit $Repo @('add', '-A')
        $null = Invoke-FixtureGit $Repo @('commit', '-q', '-m', $Message)
        return "$(Invoke-FixtureGit $Repo @('rev-parse', 'HEAD'))".Trim()
    }
    function New-FixtureScrub { [ordered]@{ verdict = 'CLEAN'; tool = 'Foundry tools/bacpac/Test-BacpacScrub.ps1' } }
    function New-FixtureGateProven([string]$Dw, [string]$Swift) {
        [ordered]@{
            dw = [ordered]@{ version = $Dw; ring = 'R1-NET10' }; swiftVersion = $Swift
            editions = [ordered]@{ 'swift-demo' = '20260928-233540'; 'dap-portal' = '20260928-234223' }
            releases = [ordered]@{ 'swift-demo' = [ordered]@{ tag = 'editions/swift-demo/x'; host = 'foundry.example.invalid' } }
        }
    }
    function New-FixtureSpine([string]$Dw, [string]$Swift, [string]$Serializer) {
        [ordered]@{ components = [ordered]@{
            dw         = [ordered]@{ current = [ordered]@{ version = $Dw } }
            swift      = [ordered]@{ current = [ordered]@{ version = $Swift } }
            serializer = [ordered]@{ current = [ordered]@{ version = $Serializer } }
            mcp        = [ordered]@{ current = [ordered]@{ version = '0.6.0-beta' } }
        } }
    }

    # --- the fixture repository -------------------------------------------------------------
    $script:repo = Join-Path $TestDrive 'dist'
    [void][IO.Directory]::CreateDirectory($script:repo)
    $null = Invoke-FixtureGit $script:repo @('init', '-q', '-b', 'main')

    # A: the tree the first edition database is delivered from. No bacpac registered yet.
    Set-FixtureFile $script:repo 'layers/INDEX.json' ([ordered]@{ gateProven = (New-FixtureGateProven '10.28.12' '2.4.0') })
    Set-FixtureFile $script:repo 'versions/spine.json' (New-FixtureSpine '10.28.12' '2.4.0' '1.0.6-beta')
    Set-FixtureFile $script:repo 'editions/swift-demo.json' ([ordered]@{ name = 'swift-demo'; from = 'base@4.2.0'; add = @('feature-pricing@1.1.4', 'feature-old@1.0.0'); surfaces = @('surface-swift@1.18.1'); sampleData = $true; themes = @('default') })
    Set-FixtureFile $script:repo 'layers/theme-default/layer.json' ([ordered]@{ name = 'theme-default'; version = '2.6.1' })
    Set-FixtureFile $script:repo 'layers/sample-data/layer.json' ([ordered]@{ name = 'sample-data'; version = '6.5.0' })
    $script:cA = Save-FixtureCommit $script:repo 'A: the first delivered tree'

    # B: the first registration. Both lines start here.
    $script:blank1 = [ordered]@{ dwVersion = '10.28.12'; tag = 'databases/blank/10.28.12'; asset = 'blank-dw-10.28.12.bacpac'; sha256 = $script:sha; sizeBytes = 117191
                                 gateRunId = '20260929-110000'; scrubCheck = (New-FixtureScrub) }
    $script:swift1 = [ordered]@{ editionVersion = '5.3.0'; tag = 'editions/swift-demo/5.3.0'; asset = 'swift-demo-5.3.0.bacpac'; sha256 = $script:sha; sizeBytes = 1000
                                 gateRunId = '20260929-120000'; deliveryRunId = '20260929-110000'; provenRunId = '20260928-233540'
                                 distributionCommit = $script:cA; dwVersion = '10.28.12'; scrubCheck = (New-FixtureScrub) }
    Set-FixtureFile $script:repo 'layers/INDEX.json' ([ordered]@{ gateProven = (New-FixtureGateProven '10.28.12' '2.4.0')
        bacpacs = [ordered]@{ blank = $script:blank1; editions = [ordered]@{ 'swift-demo' = $script:swift1 } } })
    $script:cB = Save-FixtureCommit $script:repo 'Merge pull request #5 from fixture/first-bacpacs'
    $null = Invoke-FixtureGit $script:repo @('tag', '-a', 'databases/blank/10.28.12', '-m', 'blank 10.28.12')

    # C: the layers, the DW pin, the Swift release and the spine move. The second edition database is delivered from here.
    Set-FixtureFile $script:repo 'layers/INDEX.json' ([ordered]@{ gateProven = (New-FixtureGateProven '10.30.1' '2.5.0')
        bacpacs = [ordered]@{ blank = $script:blank1; editions = [ordered]@{ 'swift-demo' = $script:swift1 } } })
    Set-FixtureFile $script:repo 'versions/spine.json' (New-FixtureSpine '10.30.1' '2.5.0' '1.0.8-beta')
    Set-FixtureFile $script:repo 'editions/swift-demo.json' ([ordered]@{ name = 'swift-demo'; from = 'base@5.0.0'; add = @('feature-pricing@1.1.4', 'feature-new@1.0.0'); surfaces = @('surface-swift@1.19.0'); sampleData = $true; themes = @('default') })
    Set-FixtureFile $script:repo 'editions/dap-portal.json' ([ordered]@{ name = 'dap-portal'; from = 'base@5.0.0'; surfaces = @('surface-dap-portal@1.1.1') })
    Set-FixtureFile $script:repo 'layers/theme-default/layer.json' ([ordered]@{ name = 'theme-default'; version = '2.7.0' })
    Set-FixtureFile $script:repo 'layers/surface-swift/CHANGELOG.md' (@(
        '# Changelog - surface-swift', ''
        '## 1.20.0 (unreleased)', '', 'Not part of the release: above the new pin.', ''
        '## 1.19.0 (2026-10-20)', '', '**MINOR. Rebased on Swift 2.5.0.** Every overlay follows', 'the new release.', '', '### Overlays', '', 'A second paragraph that the summary leaves out.', ''
        '## 1.18.2', '', '### Checkout fix', '', 'Two checkout defects fixed.', ''
        '## 1.18.1', '', 'Already part of the previous release.', '') -join "`n")
    $script:cC = Save-FixtureCommit $script:repo "Merge pull request #7 from fixture/swift-2-5`n`nSwift 2.5.0: layers repinned"

    # D: the second registration. The new entries carry their releaseNotes record.
    $script:blank2 = [ordered]@{ dwVersion = '10.30.1'; tag = 'databases/blank/10.30.1'; asset = 'blank-dw-10.30.1.bacpac'; sha256 = $script:sha; sizeBytes = 119219; tables = 389
                                 gateRunId = '20261021-214455'; deliveryRunId = '20261021-214230'; provedWith = 'swift-demo 5.6.0 delivered onto the restored database'
                                 scrubCheck = (New-FixtureScrub); releaseNotes = [ordered]@{ schema = 'release-notes/v1'; previousTag = 'databases/blank/10.28.12' } }
    $script:swift2 = [ordered]@{ editionVersion = '5.6.0'; tag = 'editions/swift-demo/5.6.0'; asset = 'swift-demo-5.6.0.bacpac'; sha256 = $script:sha; sizeBytes = 315634
                                 gateRunId = '20261021-220532'; deliveryRunId = '20261021-220225'; provenRunId = '20260928-233540'
                                 distributionCommit = $script:cC; dwVersion = '10.30.1'; startsFrom = "blank-dw-10.30.1.bacpac (sha256 $script:sha)"
                                 scrubCheck = (New-FixtureScrub); releaseNotes = [ordered]@{ schema = 'release-notes/v1'; previousTag = 'editions/swift-demo/5.3.0' } }
    $script:dap1 = [ordered]@{ editionVersion = '2.6.0'; tag = 'editions/dap-portal/2.6.0'; asset = 'dap-portal-2.6.0.bacpac'; sha256 = $script:sha; sizeBytes = 243413
                               gateRunId = '20261021-221310'; deliveryRunId = '20261021-221047'; provenRunId = '20260928-234223'
                               distributionCommit = $script:cC; dwVersion = '10.30.1'
                               scrubCheck = (New-FixtureScrub); releaseNotes = [ordered]@{ schema = 'release-notes/v1'; previousTag = $null } }
    Set-FixtureFile $script:repo 'layers/INDEX.json' ([ordered]@{ gateProven = (New-FixtureGateProven '10.30.1' '2.5.0')
        bacpacs = [ordered]@{ blank = $script:blank2; editions = [ordered]@{ 'swift-demo' = $script:swift2; 'dap-portal' = $script:dap1 } } })
    $script:cD = Save-FixtureCommit $script:repo 'Merge pull request #9 from fixture/second-bacpacs'

    $script:index = Get-Content (Join-Path $script:repo 'layers/INDEX.json') -Raw | ConvertFrom-Json
    $script:swiftNotes = New-BacpacReleaseNotes -RepoRoot $script:repo -Kind edition -Edition 'swift-demo' -Entry $script:index.bacpacs.editions.'swift-demo' -Lead 'The lead paragraph.'
    $script:dapNotes = New-BacpacReleaseNotes -RepoRoot $script:repo -Kind edition -Edition 'dap-portal' -Entry $script:index.bacpacs.editions.'dap-portal'
    $script:blankNotes = New-BacpacReleaseNotes -RepoRoot $script:repo -Kind blank -Entry $script:index.bacpacs.blank

    function Copy-Entry($Entry) { return ($Entry | ConvertTo-Json -Depth 8 | ConvertFrom-Json) }
    function New-RegisterIndex($Blank, $Editions) {
        $bp = [ordered]@{}
        if ($Blank) { $bp.blank = $Blank }
        if ($Editions) { $bp.editions = $Editions }
        return ([ordered]@{ bacpacs = $bp } | ConvertTo-Json -Depth 10 | ConvertFrom-Json)
    }
    function Get-RecordRed($Index) { @(Test-ReleaseNotesRecord -Index $Index | Where-Object { -not $_.ok }) }
}

Describe 'Find-PreviousBacpacRelease: the previous release of the same line, from the history of INDEX.json' -Tag 'Unit' {
    It 'names the tag the edition entry carried before the current one replaced it' {
        $p = Find-PreviousBacpacRelease -RepoRoot $script:repo -Kind edition -Edition 'swift-demo' -Tag 'editions/swift-demo/5.6.0'
        $p.tag | Should -Be 'editions/swift-demo/5.3.0'
        $p.entry.distributionCommit | Should -Be $script:cA
        $p.registeredAt | Should -Be $script:cC
    }
    It 'names the previous blank database for a blank' {
        (Find-PreviousBacpacRelease -RepoRoot $script:repo -Kind blank -Tag 'databases/blank/10.30.1').tag | Should -Be 'databases/blank/10.28.12'
    }
    It 'answers nothing for the first release of a line' {
        Find-PreviousBacpacRelease -RepoRoot $script:repo -Kind edition -Edition 'dap-portal' -Tag 'editions/dap-portal/2.6.0' | Should -BeNullOrEmpty
        Find-PreviousBacpacRelease -RepoRoot $script:repo -Kind blank -Tag 'databases/blank/10.28.12' -Start $script:cB | Should -BeNullOrEmpty
    }
    It 'answers before the new entry is committed: the entry at HEAD is the previous release' {
        (Find-PreviousBacpacRelease -RepoRoot $script:repo -Kind edition -Edition 'swift-demo' -Tag 'editions/swift-demo/5.6.0' -Start $script:cC).tag | Should -Be 'editions/swift-demo/5.3.0'
    }
    It 'refuses a shallow checkout, which would call every release the first of its line' {
        $shallow = Join-Path $TestDrive 'shallow'
        $path = $script:repo -replace '\\', '/'
        $url = 'file://' + $(if ($path.StartsWith('/')) { $path } else { "/$path" })
        & git clone -q --depth 1 $url $shallow 2>&1 | Out-Null
        { Find-PreviousBacpacRelease -RepoRoot $shallow -Kind edition -Edition 'swift-demo' -Tag 'editions/swift-demo/5.6.0' } | Should -Throw '*shallow checkout*'
    }
}

Describe 'New-ReleaseNotesRecord: what the Foundry writes into the register entry' -Tag 'Unit' {
    It 'names the previous release of the line' {
        $r = New-ReleaseNotesRecord -RepoRoot $script:repo -Kind blank -Tag 'databases/blank/10.31.0'
        $r.schema | Should -Be 'release-notes/v1'
        $r.previousTag | Should -Be 'databases/blank/10.30.1'
        @($r.Keys) | Should -Be @('schema', 'previousTag')
    }
    It 'records null for the first release of a line' {
        $r = New-ReleaseNotesRecord -RepoRoot $script:repo -Kind edition -Edition 'headless-demo' -Tag 'editions/headless-demo/3.5.0'
        $r.Contains('previousTag') | Should -BeTrue
        $r.previousTag | Should -BeNullOrEmpty
    }
}

Describe 'Get-LayerChangelogEntry: the entries between two versions' -Tag 'Unit' {
    BeforeAll { $script:log = Get-Content (Join-Path $script:repo 'layers/surface-swift/CHANGELOG.md') -Raw }
    It 'takes the entries above the previous version up to the new one, newest first' {
        $e = @(Get-LayerChangelogEntry -Text $script:log -From '1.18.1' -To '1.19.0')
        @($e | ForEach-Object { $_.version }) | Should -Be @('1.19.0', '1.18.2')
        $e[0].heading | Should -Be '1.19.0 (2026-10-20)'
    }
    It 'summarises an entry as its first paragraph on one line, without heading marks' {
        $e = @(Get-LayerChangelogEntry -Text $script:log -From '1.18.1' -To '1.19.0')
        $e[0].summary | Should -Be '**MINOR. Rebased on Swift 2.5.0.** Every overlay follows the new release.'
        $e[0].body | Should -Match 'A second paragraph that the summary leaves out\.'
        $e[1].summary | Should -Be 'Checkout fix'
    }
    It 'is empty without a changelog or without an entry in the range' {
        @(Get-LayerChangelogEntry -Text '' -From '1.0.0' -To '2.0.0').Count | Should -Be 0
        @(Get-LayerChangelogEntry -Text $script:log -From '1.20.0' -To '1.21.0').Count | Should -Be 0
    }
}

Describe 'New-BacpacReleaseNotes: an edition release against the previous release of that edition' -Tag 'Unit' {
    BeforeAll { $script:d = $script:swiftNotes.Document }
    It 'compares the records at the two distributionCommits' {
        $script:swiftNotes.PreviousTag | Should -Be 'editions/swift-demo/5.3.0'
        $script:d.firstOfLine | Should -BeFalse
        $script:d.previous.tag | Should -Be 'editions/swift-demo/5.3.0'
        $script:d.previous.version | Should -Be '5.3.0'
        $script:d.previous.recordsCommit | Should -Be $script:cA
        $script:d.recordsCommit | Should -Be $script:cC
        $script:d.version | Should -Be '5.6.0'
    }
    It 'states the DW and Swift deltas' {
        $script:d.dw.from | Should -Be '10.28.12'; $script:d.dw.to | Should -Be '10.30.1'; $script:d.dw.changed | Should -BeTrue
        $script:d.swift.from | Should -Be '2.4.0'; $script:d.swift.to | Should -Be '2.5.0'; $script:d.swift.changed | Should -BeTrue
    }
    It 'states every layer pin: changed, unchanged, added and removed' {
        $by = @{}; foreach ($l in $script:d.layers) { $by[$l.name] = $l }
        $by['base'].from | Should -Be '4.2.0'; $by['base'].to | Should -Be '5.0.0'; $by['base'].change | Should -Be 'changed'
        $by['feature-pricing'].change | Should -Be 'unchanged'
        $by['feature-new'].change | Should -Be 'added'; $by['feature-new'].from | Should -BeNullOrEmpty
        $by['feature-old'].change | Should -Be 'removed'; $by['feature-old'].to | Should -BeNullOrEmpty
        $by['theme-default'].from | Should -Be '2.6.1'; $by['theme-default'].to | Should -Be '2.7.0'
        $by['sample-data'].change | Should -Be 'unchanged'
    }
    It "carries a changed layer's CHANGELOG entries between the two versions, and none when it has no changelog" {
        $by = @{}; foreach ($l in $script:d.layers) { $by[$l.name] = $l }
        @($by['surface-swift'].changelog | ForEach-Object { $_.version }) | Should -Be @('1.19.0', '1.18.2')
        @($by['base'].changelog).Count | Should -Be 0
    }
    It 'states the spine component deltas, with dw and swift left to their own fields' {
        @($script:d.components | ForEach-Object { $_.id }) | Should -Be @('serializer', 'mcp')
        $script:d.components[0].from | Should -Be '1.0.6-beta'; $script:d.components[0].to | Should -Be '1.0.8-beta'; $script:d.components[0].change | Should -Be 'changed'
        $script:d.components[1].change | Should -Be 'unchanged'
    }
    It 'lists the pull requests merged between the two commits' {
        @($script:d.pullRequests | ForEach-Object { $_.number }) | Should -Be @(7, 5)
        $script:d.pullRequests[0].title | Should -Be 'Swift 2.5.0: layers repinned'
        $script:d.pullRequests[0].mergeCommit | Should -Be $script:cC
    }
    It 'tells the consumer what to do, derived from the deltas' {
        $a = $script:d.consumerActions -join "`n"
        $a | Should -Match 'restore it onto a NEW database'
        $a | Should -Match 'Move the host to DW 10\.30\.1'
        $a | Should -Match 'Swift release Files with Swift 2\.5\.0'
        $a | Should -Match 'base moved a major version \(4\.2\.0 to 5\.0\.0\)'
        $a | Should -Match 'feature-old is no longer part of the edition'
        $a | Should -Match 'serializer 1\.0\.8-beta \(was 1\.0\.6-beta\)'
        $a | Should -Match 'Administrator and persona passwords'
    }
    It 'carries the provenance of the register entry' {
        $script:d.provenance.sha256 | Should -Be $script:sha
        $script:d.provenance.gateRunId | Should -Be '20261021-220532'
        $script:d.provenance.distributionCommit | Should -Be $script:cC
        $script:d.provenance.provingHost | Should -Be 'foundry.example.invalid'
        $script:d.provenance.scrubVerdict | Should -Be 'CLEAN'
    }
    It 'renders two sections in a fixed order after the lead: What changed, then Provenance' {
        $md = $script:swiftNotes.Markdown
        $md | Should -Match '^The lead paragraph\.'
        @([regex]::Matches($md, '(?m)^## .+$') | ForEach-Object { $_.Value }) | Should -Be @('## What changed', '## Provenance')
        $md | Should -Match '\| DW version \| 10\.28\.12 \| 10\.30\.1 \| \*\*changed\*\* \|'
        $md | Should -Match '\| `surface-swift` \| 1\.18\.1 \| 1\.19\.0 \| changed \|'
        $md | Should -Match '- 1\.19\.0 \(2026-10-20\): \*\*MINOR\. Rebased on Swift 2\.5\.0\.\*\*'
        $md | Should -Match '### What a consumer must do'
        $md | Should -Match 'pull/7\) Swift 2\.5\.0: layers repinned'
    }
    It 'is the same document as JSON, valid against layers/release-notes.schema.json' {
        Test-Json -Json $script:swiftNotes.Json -SchemaFile $script:notesSchema | Should -BeTrue
        $back = $script:swiftNotes.Json | ConvertFrom-Json
        $back.schema | Should -Be 'release-notes/v1'
        $back.tag | Should -Be 'editions/swift-demo/5.6.0'
        @($back.layers).Count | Should -Be @($script:d.layers).Count
    }
    It 'is deterministic: the same records give the same bytes' {
        $again = New-BacpacReleaseNotes -RepoRoot $script:repo -Kind edition -Edition 'swift-demo' -Entry $script:index.bacpacs.editions.'swift-demo' -Lead 'The lead paragraph.'
        $again.Json | Should -Be $script:swiftNotes.Json
        $again.Markdown | Should -Be $script:swiftNotes.Markdown
    }
}

Describe 'New-BacpacReleaseNotes: the first release of a line says so plainly' -Tag 'Unit' {
    It 'has no previous release, no from value and no pull request list' {
        $d = $script:dapNotes.Document
        $script:dapNotes.PreviousTag | Should -BeNullOrEmpty
        $d.firstOfLine | Should -BeTrue
        $d.previous | Should -BeNullOrEmpty
        $d.dw.from | Should -BeNullOrEmpty; $d.dw.changed | Should -BeFalse
        @($d.layers | ForEach-Object { $_.change } | Select-Object -Unique) | Should -Be @('first')
        @($d.pullRequests).Count | Should -Be 0
        ($d.consumerActions -join "`n") | Should -Match 'First release of this line'
    }
    It 'states it in the body and still validates' {
        $script:dapNotes.Markdown | Should -Match 'First release of this line: there is no previous dap-portal database release to compare with'
        $script:dapNotes.Markdown | Should -Not -Match 'Compared with the previous release'
        Test-Json -Json $script:dapNotes.Json -SchemaFile $script:notesSchema | Should -BeTrue
    }
}

Describe 'New-BacpacReleaseNotes: a blank database against the previous blank database' -Tag 'Unit' {
    It 'states the DW version delta and carries no layer' {
        $d = $script:blankNotes.Document
        $d.kind | Should -Be 'blank'; $d.edition | Should -BeNullOrEmpty
        $d.previous.tag | Should -Be 'databases/blank/10.28.12'
        $d.previous.recordsCommit | Should -Be $script:cB
        $d.recordsCommit | Should -Be $script:cD
        $d.dw.from | Should -Be '10.28.12'; $d.dw.to | Should -Be '10.30.1'
        @($d.layers).Count | Should -Be 0
        ($d.consumerActions -join "`n") | Should -Match 'Move the host to DW 10\.30\.1'
        ($d.consumerActions -join "`n") | Should -Not -Match 'Swift release Files'
        $d.provenance.provedWith | Should -Match 'swift-demo 5\.6\.0'
        Test-Json -Json $script:blankNotes.Json -SchemaFile $script:notesSchema | Should -BeTrue
    }
    It 'renders the blank body without a layer section' {
        $script:blankNotes.Markdown | Should -Match '\| Blank database \| 10\.28\.12 \| 10\.30\.1 \| changed \|'
        $script:blankNotes.Markdown | Should -Not -Match '### Layers'
    }
}

Describe 'Red controls on the generator' -Tag 'Unit' {
    It 'stops when the entry record names another previous release than the history does' {
        $e = Copy-Entry $script:index.bacpacs.editions.'swift-demo'
        $e.releaseNotes.previousTag = 'editions/swift-demo/5.2.0'
        { New-BacpacReleaseNotes -RepoRoot $script:repo -Kind edition -Edition 'swift-demo' -Entry $e } | Should -Throw "*previousTag is 'editions/swift-demo/5.2.0'*names 'editions/swift-demo/5.3.0'*"
    }
    It 'stops when the record claims a first release that has a predecessor' {
        $e = Copy-Entry $script:index.bacpacs.blank
        $e.releaseNotes.previousTag = $null
        { New-BacpacReleaseNotes -RepoRoot $script:repo -Kind blank -Entry $e } | Should -Throw "*previousTag is 'null'*"
    }
    It 'stops on a tag that is not of the line' {
        $e = Copy-Entry $script:index.bacpacs.editions.'swift-demo'
        { New-BacpacReleaseNotes -RepoRoot $script:repo -Kind edition -Edition 'dap-portal' -Entry $e } | Should -Throw '*is not a tag of the edition line dap-portal*'
    }
    It 'the schema rejects a document without consumer actions, with another schema name or with an unknown field' {
        $d = $script:swiftNotes.Json | ConvertFrom-Json
        $d.consumerActions = @()
        Test-Json -Json ($d | ConvertTo-Json -Depth 12) -SchemaFile $script:notesSchema -ErrorAction SilentlyContinue | Should -BeFalse
        $d = $script:swiftNotes.Json | ConvertFrom-Json
        $d.schema = 'release-notes/v2'
        Test-Json -Json ($d | ConvertTo-Json -Depth 12) -SchemaFile $script:notesSchema -ErrorAction SilentlyContinue | Should -BeFalse
        $d = $script:swiftNotes.Json | ConvertFrom-Json
        $d | Add-Member -NotePropertyName handWritten -NotePropertyValue 'x'
        Test-Json -Json ($d | ConvertTo-Json -Depth 12) -SchemaFile $script:notesSchema -ErrorAction SilentlyContinue | Should -BeFalse
    }
}

Describe 'Test-ReleaseNotesRecord: a recorded bacpac release has its release-notes record (validator check 17)' -Tag 'Unit' {
    It 'passes entries registered after the rule that carry their record' {
        Get-RecordRed $script:index | Should -BeNullOrEmpty
        @(Test-ReleaseNotesRecord -Index $script:index).Count | Should -BeGreaterThan 0
    }
    It 'FAILs an entry registered after the rule without a record' {
        $e = Copy-Entry $script:index.bacpacs.editions.'swift-demo'
        $e.PSObject.Properties.Remove('releaseNotes')
        $red = Get-RecordRed (New-RegisterIndex $null ([ordered]@{ 'swift-demo' = $e }))
        $red.Count | Should -Be 1
        $red[0].message | Should -Match 'bacpacs\.editions\.swift-demo \(editions/swift-demo/5\.6\.0\) carries no releaseNotes record'
        $b = Copy-Entry $script:index.bacpacs.blank
        $b.PSObject.Properties.Remove('releaseNotes')
        (Get-RecordRed (New-RegisterIndex $b $null))[0].message | Should -Match 'bacpacs\.blank \(databases/blank/10\.30\.1\) carries no releaseNotes record'
    }
    It 'exempts no release: the four published before the rule were backfilled (owner decision 2026-11-12)' {
        @(Get-ReleaseNotesExemptTag).Count | Should -Be 0
        foreach ($t in 'databases/blank/10.29.8', 'editions/swift-demo/5.5.0', 'editions/dap-portal/2.5.0', 'editions/headless-demo/3.4.0') {
            $kind = if ($t -like 'databases/*') { 'blank' } else { 'edition' }
            $ix = if ($kind -eq 'blank') { New-RegisterIndex ([ordered]@{ tag = $t }) $null } else { New-RegisterIndex $null ([ordered]@{ ($t -split '/')[1] = [ordered]@{ tag = $t } }) }
            @(Get-RecordRed $ix).Count | Should -Be 1 -Because "$t carries no releaseNotes record"
        }
    }
    It 'the register in layers/INDEX.json carries a record on every entry' {
        $real = Get-Content -Raw -Encoding utf8 (Join-Path $PSScriptRoot '..\..\..\layers\INDEX.json') | ConvertFrom-Json
        $bp = if ($real.PSObject.Properties['bacpacs']) { $real.bacpacs } else { $null }
        $entries = @(if ($bp -and $bp.PSObject.Properties['blank'] -and $bp.blank) { 'blank' }) +
                   @(if ($bp -and $bp.PSObject.Properties['editions'] -and $bp.editions) { @($bp.editions.PSObject.Properties.Name) })
        $rows = @(Test-ReleaseNotesRecord -Index $real)
        # Every entry is bound to gateProven (check 17), so a restamp onto a new DW version empties the register
        # until files are cut at that version: an empty register has nothing to record. Each entry yields a row.
        if ($entries.Count) { $rows.Count | Should -BeGreaterOrEqual $entries.Count } else { $rows.Count | Should -Be 0 }
        @($rows | Where-Object { -not $_.ok }) | Should -BeNullOrEmpty
    }
    It 'an empty register (a restamp onto a new DW version) yields no row and no finding' {
        @(Test-ReleaseNotesRecord -Index ([pscustomobject]@{ bacpacs = [pscustomobject]@{} })).Count | Should -Be 0
        @(Test-ReleaseNotesRecord -Index ([pscustomobject]@{ bacpacs = [pscustomobject]@{ editions = [pscustomobject]@{} } })).Count | Should -Be 0
    }
    It 'FAILs a record with another schema name' {
        $e = Copy-Entry $script:index.bacpacs.blank
        $e.releaseNotes.schema = 'release-notes/v0'
        (Get-RecordRed (New-RegisterIndex $e $null))[0].message | Should -Match "releaseNotes\.schema 'release-notes/v0'"
    }
    It 'FAILs a record that names no previousTag at all (null is a statement, absence is not)' {
        $e = Copy-Entry $script:index.bacpacs.blank
        $e.releaseNotes.PSObject.Properties.Remove('previousTag')
        (Get-RecordRed (New-RegisterIndex $e $null))[0].message | Should -Match 'names no previousTag'
    }
    It 'FAILs a previousTag of another line or equal to the entry tag' {
        $e = Copy-Entry $script:index.bacpacs.editions.'swift-demo'
        $e.releaseNotes.previousTag = 'editions/dap-portal/2.5.0'
        (Get-RecordRed (New-RegisterIndex $null ([ordered]@{ 'swift-demo' = $e }))).Count | Should -Be 1
        $e.releaseNotes.previousTag = 'editions/swift-demo/5.6.0'
        (Get-RecordRed (New-RegisterIndex $null ([ordered]@{ 'swift-demo' = $e }))).Count | Should -Be 1
        $b = Copy-Entry $script:index.bacpacs.blank
        $b.releaseNotes.previousTag = 'editions/swift-demo/5.3.0'
        (Get-RecordRed (New-RegisterIndex $b $null)).Count | Should -Be 1
    }
    It 'is silent when INDEX.json registers no bacpac' {
        @(Test-ReleaseNotesRecord -Index ([pscustomobject]@{ gateProven = 1 })).Count | Should -Be 0
    }
    It 'keeps the live register valid: every entry in layers/INDEX.json passes' {
        $live = Get-Content (Join-Path $script:layersRoot 'INDEX.json') -Raw -Encoding utf8 | ConvertFrom-Json
        Get-RecordRed $live | Should -BeNullOrEmpty
    }
}

Describe 'layers/bacpacs.schema.json carries the record' -Tag 'Unit' {
    It 'accepts entries with and without a releaseNotes record' {
        Test-Json -Json ($script:index.bacpacs | ConvertTo-Json -Depth 10) -SchemaFile $script:bacpacsSchema | Should -BeTrue
        $live = Get-Content (Join-Path $script:layersRoot 'INDEX.json') -Raw -Encoding utf8 | ConvertFrom-Json
        Test-Json -Json ($live.bacpacs | ConvertTo-Json -Depth 12) -SchemaFile $script:bacpacsSchema | Should -BeTrue
    }
    It 'rejects a record with another schema name, an unknown field or a previousTag that is no release tag' {
        foreach ($mutate in @(
                { param($b) $b.blank.releaseNotes.schema = 'notes' },
                { param($b) $b.blank.releaseNotes | Add-Member -NotePropertyName sha256 -NotePropertyValue 'x' },
                { param($b) $b.blank.releaseNotes.previousTag = 'v1.0.0' })) {
            $b = Copy-Entry $script:index.bacpacs
            & $mutate $b
            Test-Json -Json ($b | ConvertTo-Json -Depth 10) -SchemaFile $script:bacpacsSchema -ErrorAction SilentlyContinue | Should -BeFalse
        }
    }
}

Describe 'Publish-BacpacRelease attaches the notes when it publishes (gh and the network faked)' -Tag 'Unit' {
    BeforeAll {
        $script:oldToken = $env:GH_TOKEN
        $env:GH_TOKEN = 'fixture-token'
        $script:bytes = [Text.Encoding]::UTF8.GetBytes('bacpac-bytes')
        $script:fileSha = ([BitConverter]::ToString([Security.Cryptography.SHA256]::HashData($script:bytes)) -replace '-', '').ToLowerInvariant()
        # gh as a recording fake: the release list is $global:RnReleases, every other call is logged.
        function global:gh {
            $piped = @($input) -join "`n"
            $global:LASTEXITCODE = 0
            $line = $args -join ' '
            if ($line -like 'api repos/*/releases?per_page=100*') { return (ConvertTo-Json -InputObject @(, @($global:RnReleases)) -Depth 8 -Compress) }
            $global:RnCalls.Add([pscustomobject]@{ kind = 'gh'; line = $line; body = $piped })
            if ($global:RnFailPatch -and $line -like 'api -X PATCH*') { $global:LASTEXITCODE = 1 }
        }
        function New-Release([string]$Tag, [bool]$Draft, [string[]]$Asset) {
            $i = 100
            [pscustomobject]@{ id = 4242; tag_name = $Tag; draft = $Draft; assets = @($Asset | ForEach-Object { $i++; [pscustomobject]@{ id = $i; name = $_ } }) }
        }
        function Get-Plan([string]$Tag) {
            $row = @(Get-BacpacReleasePlan -Index $script:index | Where-Object { $_.Tag -eq $Tag })[0]
            $row.Sha256 = $script:fileSha
            return $row
        }
    }
    AfterAll {
        $env:GH_TOKEN = $script:oldToken
        Remove-Item function:global:gh -ErrorAction SilentlyContinue
        Remove-Variable -Scope Global -Name RnReleases, RnCalls, RnFailPatch -ErrorAction SilentlyContinue
    }
    BeforeEach {
        $global:RnCalls = [System.Collections.Generic.List[object]]::new()
        $global:RnFailPatch = $false
        $global:RnFailUpload = $false
        Mock Invoke-WebRequest {
            if ($OutFile) { [IO.File]::WriteAllBytes($OutFile, $script:bytes); return }
            $global:RnCalls.Add([pscustomobject]@{ kind = 'upload'; line = "$Uri"; body = [Text.Encoding]::UTF8.GetString([byte[]]$Body) })
            if ($global:RnFailUpload) { throw 'HTTP 502' }
        }
    }

    It 'the plan rows carry what the generator needs' {
        $r = Get-Plan 'editions/swift-demo/5.6.0'
        $r.Kind | Should -Be 'edition'; $r.Edition | Should -Be 'swift-demo'; $r.Entry.tag | Should -Be 'editions/swift-demo/5.6.0'
        (Get-Plan 'databases/blank/10.30.1').Kind | Should -Be 'blank'
    }
    It 'publishes a draft with the notes: release-notes.json uploaded first, then the body written with the draft flag cleared' {
        $global:RnReleases = @(New-Release 'editions/swift-demo/5.6.0' $true @('swift-demo-5.6.0.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'editions/swift-demo/5.6.0') -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'published'
        $out[0].detail | Should -Match 'release notes against editions/swift-demo/5\.3\.0 \(body and release-notes\.json\)'
        @($global:RnCalls | ForEach-Object { $_.kind }) | Should -Be @('upload', 'gh')
        $global:RnCalls[0].line | Should -Be 'https://uploads.github.com/repos/o/r/releases/4242/assets?name=release-notes.json'
        Test-Json -Json $global:RnCalls[0].body -SchemaFile $script:notesSchema | Should -BeTrue
        $global:RnCalls[1].line | Should -Be 'api -X PATCH repos/o/r/releases/4242 --input -'
        $patch = $global:RnCalls[1].body | ConvertFrom-Json
        $patch.draft | Should -BeFalse
        $patch.body | Should -Match '## What changed'
        $patch.body | Should -Match '## Provenance'
        $patch.body | Should -Match '^The swift-demo 5\.6\.0 edition delivered onto the blank DW 10\.30\.1 database'
    }
    It 'replaces a release-notes.json an earlier run left on the draft' {
        $global:RnReleases = @(New-Release 'databases/blank/10.30.1' $true @('blank-dw-10.30.1.bacpac', 'release-notes.json'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'databases/blank/10.30.1') -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'published'
        $global:RnCalls[0].line | Should -Be 'api -X DELETE repos/o/r/releases/assets/102'
        @($global:RnCalls | ForEach-Object { $_.kind }) | Should -Be @('gh', 'upload', 'gh')
    }
    It 'leaves the draft unpublished when the notes cannot be generated' {
        $row = Get-Plan 'editions/swift-demo/5.6.0'
        $row.Entry = Copy-Entry $row.Entry
        $row.Entry.releaseNotes.previousTag = 'editions/swift-demo/5.2.0'
        $global:RnReleases = @(New-Release 'editions/swift-demo/5.6.0' $true @('swift-demo-5.6.0.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @($row) -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'error'
        $out[0].detail | Should -Match 'release notes could not be generated .*left unpublished'
        $global:RnCalls.Count | Should -Be 0
    }
    It 'leaves the draft unpublished without a checkout to generate from' {
        $global:RnReleases = @(New-Release 'editions/swift-demo/5.6.0' $true @('swift-demo-5.6.0.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'editions/swift-demo/5.6.0') -Repo 'o/r')
        $out[0].result | Should -Be 'error'
        $global:RnCalls.Count | Should -Be 0
    }
    It 'leaves the draft unpublished when release-notes.json cannot be attached' {
        $global:RnFailUpload = $true
        $global:RnReleases = @(New-Release 'editions/swift-demo/5.6.0' $true @('swift-demo-5.6.0.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'editions/swift-demo/5.6.0') -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'error'
        $out[0].detail | Should -Match 'could not be attached to the draft .*left unpublished'
        @($global:RnCalls | Where-Object { $_.kind -eq 'gh' }).Count | Should -Be 0
    }
    It '-VerifyOnly (the dry run) writes nothing and names the notes' {
        $global:RnReleases = @(New-Release 'editions/dap-portal/2.6.0' $true @('dap-portal-2.6.0.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'editions/dap-portal/2.6.0') -Repo 'o/r' -RepoRoot $script:repo -VerifyOnly)
        $out[0].result | Should -Be 'verified'
        $out[0].detail | Should -Match 'no previous release \(first of its line\)'
        $global:RnCalls.Count | Should -Be 0
    }
    It 'gives a published release that lacks release-notes.json its notes, and touches no bacpac asset' {
        $global:RnReleases = @(New-Release 'editions/swift-demo/5.6.0' $false @('swift-demo-5.6.0.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'editions/swift-demo/5.6.0') -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'present'
        @($global:RnCalls | ForEach-Object { $_.kind }) | Should -Be @('upload', 'gh')
        $patch = $global:RnCalls[1].body | ConvertFrom-Json
        @($patch.PSObject.Properties.Name) | Should -Be @('body')
    }
    It 'leaves a published release that carries its notes alone' {
        $global:RnReleases = @(New-Release 'editions/swift-demo/5.6.0' $false @('swift-demo-5.6.0.bacpac', 'release-notes.json'))
        $out = @(Publish-BacpacRelease -Plan @(Get-Plan 'editions/swift-demo/5.6.0') -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'present'
        $global:RnCalls.Count | Should -Be 0
    }
    It 'backfills a release published before the rule: one asset added and the body written, nothing else' {
        $row = Get-Plan 'databases/blank/10.30.1'
        $row.Tag = 'databases/blank/10.29.8'; $row.Asset = 'blank-dw-10.29.8.bacpac'
        $global:RnReleases = @(New-Release 'databases/blank/10.29.8' $false @('blank-dw-10.29.8.bacpac'))
        $out = @(Publish-BacpacRelease -Plan @($row) -Repo 'o/r' -RepoRoot $script:repo)
        $out[0].result | Should -Be 'present'
        $out[0].detail | Should -Match 'attached \(body and release-notes\.json\)'
        @($global:RnCalls | ForEach-Object { $_.kind }) | Should -Be @('upload', 'gh')
        $global:RnCalls[0].line | Should -Match '/assets\?name=release-notes\.json$'
        $patch = $global:RnCalls[1].body | ConvertFrom-Json
        @($patch.PSObject.Properties.Name) | Should -Be @('body')
    }
}

Describe 'Wiring: print-release-tags.ps1 and the validator' -Tag 'Unit' {
    BeforeAll {
        $script:tags = Get-Content -Raw (Join-Path $PSScriptRoot '..\print-release-tags.ps1')
        $script:validator = Get-Content -Raw (Join-Path $PSScriptRoot '..\Validate-Distribution.ps1')
    }
    It 'the dry run prints the notes the generator makes, and -Execute hands the checkout to the publisher' {
        $script:tags | Should -Match 'New-BacpacReleaseNotes -RepoRoot \$RepoRoot -Kind \$r\.Kind -Edition \$r\.Edition -Entry \$r\.Entry'
        $script:tags | Should -Match 'Publish-BacpacRelease -Plan \$releasePlan -Repo \$Repo -RepoRoot \$RepoRoot\)'
        $script:tags | Should -Match 'Publish-BacpacRelease -Plan \$releasePlan -Repo \$Repo -VerifyOnly -RepoRoot \$RepoRoot'
    }
    It 'check 17 runs the record rule' {
        $script:validator | Should -Match 'Test-ReleaseNotesRecord -Index \$index'
    }
    It 'the dry run, run for real on a small Distribution tree, prints the body and the asset it would publish' {
        $tree = Join-Path $TestDrive 'tagtree'
        $ci = Join-Path (Join-Path $tree 'tools') 'ci'
        [void][IO.Directory]::CreateDirectory($ci)
        Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -File -Filter '*.ps1' | Copy-Item -Destination $ci
        [void][IO.Directory]::CreateDirectory((Join-Path $tree 'layers'))
        Copy-Item -LiteralPath $script:notesSchema -Destination (Join-Path $tree 'layers')
        $null = Invoke-FixtureGit $tree @('init', '-q', '-b', 'main')
        Set-FixtureFile $tree 'editions/swift-demo.json' ([ordered]@{ name = 'swift-demo'; from = 'base@1.0.0' })
        Set-FixtureFile $tree 'layers/base/layer.json' ([ordered]@{ name = 'base'; version = '1.0.0' })
        $gp = [ordered]@{ date = '2026-11-12'; dw = [ordered]@{ version = '10.30.1' }; swiftVersion = '2.5.0'; editions = [ordered]@{ 'swift-demo' = '20261016-073012' } }
        Set-FixtureFile $tree 'layers/INDEX.json' ([ordered]@{ gateProven = $gp; layers = @() })
        $null = Save-FixtureCommit $tree 'the tree before the blank database'
        $blank = [ordered]@{ dwVersion = '10.30.1'; tag = 'databases/blank/10.30.1'; asset = 'blank-dw-10.30.1.bacpac'; sha256 = $script:sha; sizeBytes = 119219
                             gateRunId = '20261021-214455'; scrubCheck = (New-FixtureScrub); releaseNotes = [ordered]@{ schema = 'release-notes/v1'; previousTag = $null } }
        Set-FixtureFile $tree 'layers/INDEX.json' ([ordered]@{ gateProven = $gp; layers = @(); bacpacs = [ordered]@{ blank = $blank } })
        $null = Save-FixtureCommit $tree 'Merge pull request #3 from fixture/blank'
        $out = (& pwsh -NoProfile -File (Join-Path $ci 'print-release-tags.ps1') -RepoRoot $tree -ShowReleaseNotesJson 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should -Match "gh release: 'databases/blank/10\.30\.1' <- blank-dw-10\.30\.1\.bacpac"
        $out | Should -Match "# Release notes 'databases/blank/10\.30\.1' \(first release of its line\): release body"
        $out | Should -Match '(?m)^## What changed$'
        $out | Should -Match 'First release of this line: there is no previous blank database release to compare with'
        $out | Should -Match '(?m)^## Provenance$'
        $out | Should -Match "# Release notes 'databases/blank/10\.30\.1': release-notes\.json asset"
        $out | Should -Match '"schema": "release-notes/v1"'
        $out | Should -Not -Match '\[error\]'
        & git -C $tree tag --list | Should -BeNullOrEmpty -Because 'the dry run cuts nothing'
    }
    It 'the dry run names a release whose notes cannot be generated, instead of printing none' {
        $tree = Join-Path $TestDrive 'tagtree'
        $ix = Get-Content (Join-Path $tree 'layers/INDEX.json') -Raw | ConvertFrom-Json
        $ix.bacpacs.blank.releaseNotes.previousTag = 'databases/blank/10.29.8'
        Set-FixtureFile $tree 'layers/INDEX.json' $ix
        $out = (& pwsh -NoProfile -File (Join-Path $tree 'tools/ci/print-release-tags.ps1') -RepoRoot $tree 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should -Match "# Release notes 'databases/blank/10\.30\.1': \[error\].*previousTag is 'databases/blank/10\.29\.8'.*-Execute would leave this release unpublished"
    }
}
