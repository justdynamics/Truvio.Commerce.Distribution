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

Describe 'Distribution #132 item 5: line endings of the pinned snapshot' {
    It 'finds no CRLF file in the pinned canonical checkout' {
        @(Get-LedgerCrlfFile $script:snapshot.root).Count | Should -Be 0
    }
    It 'RED CONTROL: a CRLF snapshot is refused by name, even when the lock digest was taken from it' {
        $skills = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $release = Join-Path $skills 'skills/dw-demo-ledger/assets/releases/1.0.0'
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $release 'functions'), (Join-Path $skills 'skills/dw-demo-ledger/scripts')
        Copy-Item (Join-Path $script:skills 'skills/dw-demo-ledger/scripts/Ledger.Core.ps1') (Join-Path $skills 'skills/dw-demo-ledger/scripts')
        [IO.File]::WriteAllText((Join-Path $release 'manifest.json'), "{`r`n  `"schema`": 1,`r`n  `"dwVersion`": `"1.0.0`"`r`n}`r`n")
        [IO.File]::WriteAllText((Join-Path $release 'functions/a.json'), "{`"schema`":1,`"area`":`"a`",`"functions`":[]}`n")
        & git -C $skills init -q 2>$null; & git -C $skills -c core.autocrlf=false add -A 2>$null
        & git -C $skills -c user.name=t -c user.email=t@example.invalid -c core.autocrlf=false commit -q -m snapshot 2>$null
        . (Join-Path $skills 'skills/dw-demo-ledger/scripts/Ledger.Core.ps1')
        $lock = @{ repo = 'dynamicweb/skills'; commit = (& git -C $skills rev-parse HEAD); manifest = 'skills/dw-demo-ledger/assets/releases/1.0.0/manifest.json'; digest = (Get-LedgerDigest $release) }
        { Read-DistributionLedgerSnapshot $lock $skills } | Should -Throw '*CRLF line endings in 1 snapshot file(s) (first: manifest.json)*'
        @(Get-LedgerCrlfFile $release) | Should -Be @('manifest.json')
    }
}

Describe 'Distribution #132 item 1: a locked check that can never pass' {
    BeforeAll {
        function New-Snapshot([string[]]$FactKinds = @()) {
            @{
                handlers  = @{ 'sql-scalar' = @('sql'); 'mcp-count' = @('mcp') }
                factKinds = $FactKinds
                functions = @{
                    'f.plain' = @{ id = 'f.plain'; requires = @() }
                    'f.cap'   = @{ id = 'f.cap'; requires = @(@{ kind = 'capability'; id = 'f.plain'; expected = $true }) }
                    'f.app'   = @{ id = 'f.app'; requires = @(@{ kind = 'app'; id = 'Some.App'; expected = $true }) }
                    'f.flag'  = @{ id = 'f.flag'; requires = @(@{ kind = 'flag'; id = 'Some.Feature'; expected = $true }) }
                    'f.path'  = @{ id = 'f.path'; requires = @(@{ kind = 'flag'; id = '/Globalsettings/Settings/X'; expected = $true }) }
                }
                checks    = @{
                    'f.plain.ok'      = @{ id = 'f.plain.ok'; functionId = 'f.plain'; bindings = @(@{ status = 'planned'; surface = 'mcp'; handler = 'mcp-count' }, @{ status = 'implemented'; surface = 'sql'; handler = 'sql-scalar' }) }
                    'f.plain.planned' = @{ id = 'f.plain.planned'; functionId = 'f.plain'; bindings = @(@{ status = 'planned'; surface = 'mcp'; handler = 'mcp-count' }) }
                    'f.plain.handler' = @{ id = 'f.plain.handler'; functionId = 'f.plain'; bindings = @(@{ status = 'implemented'; surface = 'mcp'; handler = 'mcp-unknown' }) }
                    'f.plain.surface' = @{ id = 'f.plain.surface'; functionId = 'f.plain'; bindings = @(@{ status = 'implemented'; surface = 'file'; handler = 'sql-scalar' }) }
                    'f.cap.ok'        = @{ id = 'f.cap.ok'; functionId = 'f.cap'; bindings = @(@{ status = 'implemented'; surface = 'sql'; handler = 'sql-scalar' }) }
                    'f.app.ok'        = @{ id = 'f.app.ok'; functionId = 'f.app'; bindings = @(@{ status = 'implemented'; surface = 'sql'; handler = 'sql-scalar' }) }
                    'f.flag.ok'       = @{ id = 'f.flag.ok'; functionId = 'f.flag'; bindings = @(@{ status = 'implemented'; surface = 'sql'; handler = 'sql-scalar' }) }
                    'f.path.ok'       = @{ id = 'f.path.ok'; functionId = 'f.path'; bindings = @(@{ status = 'implemented'; surface = 'sql'; handler = 'sql-scalar' }) }
                }
            }
        }
        # Every shipped lock, planned once against its own pinned checkout.
        $script:shipped = @(foreach ($file in Get-ChildItem (Join-Path $script:distribution 'editions') -Filter '*.json') {
                if ($file.Name -eq 'edition.schema.json') { continue }
                $e = Get-Content $file.FullName -Raw | ConvertFrom-Json -AsHashtable
                @{ edition = $e; plan = (Get-EditionLedgerPlan $script:distribution $e $script:skills) }
            })
        function Get-Rule($Snapshot, [string]$Check) { @(Get-LedgerUnexecutableCheck $Snapshot @($Check)).rule -join ',' }
        function Test-Lock([string[]]$Checks, $Unexecutable = @(), [switch]$Candidate) {
            $edition = @{ name = 'ed'; ledger = @{ commit = 'a' * 40; checkIds = $Checks } }
            if ($Candidate) { $edition.delivery = @{ status = 'candidate' } }
            , @(Test-EditionLedgerExecutable -Edition $edition -Plan @{ snapshot = (New-Snapshot); checkIds = $Checks } -Exceptions @{ unexecutable = @($Unexecutable); removals = @() })
        }
    }
    It 'accepts a check with one implemented, allowlisted binding and no requirement' {
        Get-Rule (New-Snapshot) 'f.plain.ok' | Should -BeExactly ''
        (Test-Lock 'f.plain.ok').Count | Should -Be 0
    }
    It 'RED CONTROL: <Check> is <Rule>' -ForEach @(
        @{ Check = 'f.plain.planned'; Rule = 'no-implemented-binding' }
        @{ Check = 'f.plain.handler'; Rule = 'handler-not-allowlisted' }
        @{ Check = 'f.plain.surface'; Rule = 'handler-not-allowlisted' }
        @{ Check = 'f.cap.ok'; Rule = 'requirement-not-establishable' }
        @{ Check = 'f.app.ok'; Rule = 'requirement-not-establishable' }
        @{ Check = 'f.flag.ok'; Rule = 'requirement-not-establishable' }
        @{ Check = 'f.path.ok'; Rule = 'requirement-not-establishable' }
    ) {
        Get-Rule (New-Snapshot) $Check | Should -BeExactly $Rule
        $rows = Test-Lock $Check
        $rows.Count | Should -Be 1
        $rows[0].ok | Should -BeFalse
        $rows[0].msg | Should -BeLike "*locked check '$Check' can never pass at aaaaaaaa: $Rule*"
    }
    It 'a runner that discovers feature flags establishes a flag by name, never an app, a capability or a settings path' {
        $s = New-Snapshot @('flag')
        Get-Rule $s 'f.flag.ok' | Should -BeExactly ''
        foreach ($check in 'f.cap.ok', 'f.app.ok', 'f.path.ok') { Get-Rule $s $check | Should -BeExactly 'requirement-not-establishable' }
    }
    It 'an exact register entry turns the finding into a note' {
        $rows = Test-Lock 'f.plain.planned' @{ edition = 'ed'; check = 'f.plain.planned'; rule = 'no-implemented-binding'; ref = 'o/r#1'; reason = 'recorded finding' }
        $rows.Count | Should -Be 1; $rows[0].ok | Should -BeTrue; $rows[0].note | Should -BeTrue
    }
    It 'RED CONTROL: an entry for another edition, check or rule does not accept the finding' {
        foreach ($entry in @(
                @{ edition = 'other'; check = 'f.plain.planned'; rule = 'no-implemented-binding' }
                @{ edition = 'ed'; check = 'f.plain.planned'; rule = 'handler-not-allowlisted' })) {
            @((Test-Lock 'f.plain.planned' $entry) | Where-Object { -not $_.ok -and $_.msg -like '*can never pass*' }).Count | Should -Be 1
        }
    }
    It 'RED CONTROL: a stale register entry fails' {
        $rows = Test-Lock 'f.plain.ok' @{ edition = 'ed'; check = 'f.plain.ok'; rule = 'no-implemented-binding' }
        $rows[0].ok | Should -BeFalse; $rows[0].msg | Should -BeLike '*matches no finding*'
    }
    It 'a candidate edition reports its unexecutable checks and takes no exception' {
        $rows = Test-Lock 'f.plain.planned', 'f.plain.ok' -Candidate
        $rows.Count | Should -Be 1; $rows[0].note | Should -BeTrue; $rows[0].msg | Should -BeLike '*1 of 2 locked checks cannot pass*'
        $rows = Test-Lock 'f.plain.planned' @{ edition = 'ed'; check = 'f.plain.planned'; rule = 'no-implemented-binding' } -Candidate
        @($rows | Where-Object { -not $_.ok }).Count | Should -Be 1
    }
    It 'every shipped non-candidate lock is clean or exactly accepted by the committed register' {
        $register = ConvertFrom-LedgerExceptions (Get-Content (Join-Path $script:distribution 'contracts/ledger/exceptions.json') -Raw)
        $script:shipped.Count | Should -BeGreaterThan 0
        foreach ($lock in $script:shipped) {
            @(Test-EditionLedgerExecutable -Edition $lock.edition -Plan $lock.plan -Exceptions $register | Where-Object { -not $_.ok }).Count | Should -Be 0
        }
    }
    It 'RED CONTROL: without the register the three known locks fail on their seven checks' {
        $failed = foreach ($lock in $script:shipped) {
            Test-EditionLedgerExecutable -Edition $lock.edition -Plan $lock.plan -Exceptions @{ unexecutable = @(); removals = @() } | Where-Object { -not $_.ok } | ForEach-Object { $lock.edition.name }
        }
        ($failed | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' ' | Should -BeExactly 'base-swift=2 headless-demo=2 swift-demo=3'
    }
    It 'RED CONTROL: the register refuses an unknown rule, a missing reference and an unknown key' {
        $entry = '{"edition":"ed","check":"c.x","rule":"no-implemented-binding","ref":"o/r#1","reason":"recorded finding"}'
        { ConvertFrom-LedgerExceptions "{`"schemaVersion`":1,`"unexecutable`":[$entry]}" } | Should -Not -Throw
        { ConvertFrom-LedgerExceptions "{`"schemaVersion`":1,`"unexecutable`":[$($entry.Replace('no-implemented-binding','because'))]}" } | Should -Throw '*Invalid unexecutable entry*'
        { ConvertFrom-LedgerExceptions "{`"schemaVersion`":1,`"unexecutable`":[$($entry.Replace('o/r#1','later'))]}" } | Should -Throw '*Invalid unexecutable entry*'
        { ConvertFrom-LedgerExceptions '{"schemaVersion":1,"waived":[]}' } | Should -Throw '*Invalid ledger exceptions register*'
        { ConvertFrom-LedgerExceptions '{"schemaVersion":1,"removals":[{"kind":"check","subject":"ed","ruling":"some-ruling","reason":"no id given here"}]}' } | Should -Throw '*Invalid removal entry*'
    }
}

Describe 'Distribution #132 item 2: removing a lock, a locked check or carriage' {
    BeforeAll {
        function New-Record([string]$Removals = '[]') {
            ConvertTo-LedgerRecord -Editions @{
                'ed'    = '{"name":"ed","ledger":{"checkIds":["a.one","a.two"]}}'
                'plain' = '{"name":"plain"}'
            } -Layers @{
                'lay'  = '{"name":"lay","ledger":{"provides":["a","b"],"requires":["c"]}}'
                'bare' = '{"name":"bare"}'
            } -ExceptionsRaw "{`"schemaVersion`":1,`"removals`":$Removals}"
        }
        function Get-Fail($Head, $Base = (New-Record), [string[]]$GateProven = @()) {
            , @(Test-LedgerRemoval -Head $Head -Base $Base -BaseLabel 'origin/main' -GateProven $GateProven | Where-Object { -not $_.ok } | ForEach-Object msg)
        }
        function New-Ruling([string]$Kind, [string]$Subject, [string]$Id) {
            '[{"kind":"' + $Kind + '","subject":"' + $Subject + '",' + $(if ($Id) { '"id":"' + $Id + '",' }) + '"ruling":"owner-ruling-1","reason":"the owner allowed this removal"}]'
        }
    }
    It 'passes an unchanged record, an added lock, an added check and an added provides' {
        (Get-Fail (New-Record)).Count | Should -Be 0
        $head = New-Record
        $head.editions.plain = @{ lock = $true; checkIds = @('a.one') }; $head.editions.ed.checkIds += 'a.three'; $head.layers.lay.provides += 'd'
        $head.layers.bare = @{ carriage = $true; provides = @('a') }
        $rows = @(Test-LedgerRemoval -Head $head -Base (New-Record) -BaseLabel 'origin/main')
        $rows.Count | Should -Be 1; $rows[0].ok | Should -BeTrue; $rows[0].msg | Should -BeLike '*no lock, locked check or layer carriage removed against origin/main*'
    }
    It 'RED CONTROL: a removed lock fails' {
        $head = New-Record; $head.editions.ed = @{ lock = $false; checkIds = @() }
        $fail = Get-Fail $head
        $fail.Count | Should -Be 1; $fail[0] | Should -BeLike "*edition 'ed' no longer declares its ledger lock*kind 'lock', subject 'ed'*"
    }
    It 'RED CONTROL: a deleted edition that carried a lock fails; one that carried none does not' {
        $head = New-Record; $head.editions.Remove('ed'); $head.editions.Remove('plain')
        $fail = Get-Fail $head
        $fail.Count | Should -Be 1; $fail[0] | Should -BeLike "*edition 'ed' carried a ledger lock and is gone*"
    }
    It 'RED CONTROL: a check dropped from a lock fails' {
        $head = New-Record; $head.editions.ed.checkIds = @('a.one')
        $fail = Get-Fail $head
        $fail.Count | Should -Be 1; $fail[0] | Should -BeLike "*edition 'ed' no longer locks check 'a.two'*"
    }
    It 'RED CONTROL: removed carriage and a dropped provides fail; a dropped requires and a removed layer do not' {
        $head = New-Record; $head.layers.lay = @{ carriage = $false; provides = @() }
        (Get-Fail $head)[0] | Should -BeLike "*layer 'lay' no longer declares ledger carriage*"
        $head = New-Record; $head.layers.lay.provides = @('b')
        $fail = Get-Fail $head
        $fail.Count | Should -Be 1; $fail[0] | Should -BeLike "*layer 'lay' no longer provides 'a'*"
        $head = ConvertTo-LedgerRecord -Editions @{ 'ed' = '{"ledger":{"checkIds":["a.one","a.two"]}}'; 'plain' = '{}' } -Layers @{ 'lay' = '{"ledger":{"provides":["a","b"],"requires":[]}}' } -ExceptionsRaw ''
        (Get-Fail $head).Count | Should -Be 0
    }
    It 'a removal entry added by the same change allows exactly that removal' {
        $head = New-Record (New-Ruling 'check' 'ed' 'a.two'); $head.editions.ed.checkIds = @('a.one')
        (Get-Fail $head).Count | Should -Be 0
        @(Test-LedgerRemoval -Head $head -Base (New-Record) -BaseLabel 'origin/main')[0].msg | Should -BeLike '*(ruling owner-ruling-1)*'
    }
    It 'RED CONTROL: a removal entry already in the base register is spent' {
        $ruling = New-Ruling 'check' 'ed' 'a.two'
        $head = New-Record $ruling; $head.editions.ed.checkIds = @('a.one')
        (Get-Fail $head (New-Record $ruling)).Count | Should -Be 1
    }
    It 'RED CONTROL: a removal entry for another check, or one that matches nothing removed, fails' {
        $head = New-Record (New-Ruling 'check' 'ed' 'a.one'); $head.editions.ed.checkIds = @('a.one')
        $fail = Get-Fail $head
        $fail.Count | Should -Be 2; ($fail -join ' ') | Should -BeLike "*no longer locks check 'a.two'*matches nothing removed*"
        (Get-Fail (New-Record (New-Ruling 'lock' 'ed' '')))[0] | Should -BeLike '*new register entry (lock ed) matches nothing removed*'
    }
    It 'RED CONTROL: a gateProven edition without a lock fails, with or without a base' {
        (Get-Fail (New-Record) (New-Record) @('plain'))[0] | Should -BeLike '*plain: a gateProven edition must declare a ledger lock*'
        $rows = @(Test-LedgerRemoval -Head (New-Record) -Base $null -BaseState skipped -GateProven @('plain'))
        @($rows | Where-Object { -not $_.ok }).Count | Should -Be 1; @($rows | Where-Object ok)[0].msg | Should -BeLike '*not compared*'
    }
    It 'RED CONTROL: an unreadable base fails closed' {
        @(Test-LedgerRemoval -Head (New-Record) -Base $null -BaseState unresolved -BaseLabel 'origin/nope' | Where-Object { -not $_.ok }).Count | Should -Be 1
    }
    It 'RED CONTROL: the validator fails a lock deleted against the base branch of a real repository' {
        $repo = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Force -Path (Join-Path $repo 'editions'), (Join-Path $repo 'layers/lay')
        [IO.File]::WriteAllText((Join-Path $repo 'editions/ed.json'), '{"name":"ed","ledger":{"checkIds":["a.one"]}}')
        [IO.File]::WriteAllText((Join-Path $repo 'layers/lay/layer.json'), '{"name":"lay","ledger":{"provides":["a"],"requires":[]}}')
        $git = { & git -C $repo -c user.name=t -c user.email=t@example.invalid -c core.autocrlf=false @args 2>$null | Out-Null }
        & $git init -q -b main; & $git add -A; & $git commit -q -m base; & $git checkout -q -b change
        $base = Get-BaseLedgerRecord -RepoRoot $repo -BaseRef main
        $base.state | Should -BeExactly 'present'
        $base.record.editions.ed.checkIds | Should -Be @('a.one'); $base.record.layers.lay.provides | Should -Be @('a')
        @(Test-LedgerRemoval -Head (Get-LedgerRecord $repo) -Base $base.record -BaseLabel $base.label | Where-Object { -not $_.ok }).Count | Should -Be 0
        [IO.File]::WriteAllText((Join-Path $repo 'editions/ed.json'), '{"name":"ed"}')
        [IO.File]::WriteAllText((Join-Path $repo 'layers/lay/layer.json'), '{"name":"lay","ledger":{"provides":[],"requires":["a"]}}')
        & $git commit -q -a -m remove
        $out = (& pwsh -NoProfile -File (Join-Path $PSScriptRoot '../Validate-Distribution.ps1') -RepoRoot $repo -SpineBaseRef main 2>&1 | ForEach-Object { "$_" }) -join "`n"
        $out | Should -Match "FAIL[^\r\n]*ledger removal: edition 'ed' no longer declares its ledger lock against merge base [a-f0-9]{8} of main"
        $out | Should -Match "FAIL[^\r\n]*ledger removal: layer 'lay' no longer provides 'a'"
        (Get-BaseLedgerRecord -RepoRoot $repo -BaseRef 'origin/absent').state | Should -BeExactly 'unresolved'
    }
}
