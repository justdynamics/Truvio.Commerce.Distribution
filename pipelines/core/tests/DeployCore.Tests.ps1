#Requires -Version 7.0
# Unit tests of the deploy core that need no host: the plan of every edition, the composition into one
# tree per mode, the solution layout and its refusals. The delivery itself needs a live Dynamicweb host
# and is not run here.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    Import-Module (Join-Path $PSScriptRoot '../DeployCore.psm1') -Force
    . (Join-Path $script:RepoRoot 'tools/ci/Pipelines.ps1')
    $script:Work = Join-Path ([System.IO.Path]::GetTempPath()) ("deploycore-tests-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $script:Work | Out-Null
    $script:Example = Join-Path $script:RepoRoot 'pipelines/core/examples/pim-solution'
    function New-TestReport { param([string]$Name) New-DeployReport -WorkDir (Join-Path $script:Work $Name) }
    function Read-Manifest { param([string]$Path) Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json }
}

AfterAll {
    if ($script:Work -and (Test-Path -LiteralPath $script:Work)) { Remove-Item -LiteralPath $script:Work -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Get-EditionPlan' {
    It 'resolves base-only into the base alone, with no problems' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only
        $plan.problems | Should -BeNullOrEmpty
        @($plan.layers).Count | Should -Be 1
        $plan.layers[0].name | Should -Be 'base'
        $plan.hasSurface | Should -BeFalse
        $plan.hasDemoData | Should -BeFalse
    }
    It 'pins every layer of swift-demo at the version the checkout carries, sample data after the surface' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition swift-demo
        $plan.problems | Should -BeNullOrEmpty
        $names = @($plan.layers | ForEach-Object name)
        $names[0] | Should -Be 'base'
        $names | Should -Contain 'surface-swift'
        $names | Should -Contain 'theme-default'
        [array]::IndexOf($names, 'sample-data') | Should -BeGreaterThan ([array]::IndexOf($names, 'surface-swift'))
        $plan.hasDemoData | Should -BeTrue
    }
    It 'refuses an edition with sample data on <_>' -ForEach 'acceptance', 'production' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition swift-demo -Environment $_
        ($plan.problems -join ' ') | Should -Match 'test environment only'
    }
    It 'accepts the storefront without sample data on production' {
        (Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-swift -Environment production).problems | Should -BeNullOrEmpty
    }
    It 'refuses a composition with more than one content area' {
        ((Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition headless-demo).problems -join ' ') | Should -Match 'at most one content area'
    }
    It 'throws on an edition that does not exist' {
        { Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition no-such-edition } | Should -Throw
    }
}

Describe 'the solution layout' {
    It 'adds the example solution''s class folder, files and settings after the edition' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $script:Example
        $plan.problems | Should -BeNullOrEmpty
        @($plan.layers | ForEach-Object name) | Should -Be @('base', 'merge.pim-reference', 'solution-files')
        @($plan.solutionSettings | ForEach-Object path) | Should -Contain '/Globalsettings/Features/Productsfeatures/Completenessfeature'
    }
    It 'delivers testdata to test and withholds it elsewhere' {
        $solution = Join-Path $script:Work 'solution-testdata'
        $unit = Join-Path $solution 'testdata/serializer/merge.sample-products'
        New-Item -ItemType Directory -Force -Path $unit | Out-Null
        '{"schemaVersion":2,"mode":"merge","entries":[]}' | Set-Content -LiteralPath (Join-Path $unit 'merge-manifest.json')
        $test = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $solution -Environment test
        @($test.layers | Where-Object role -eq 'testdata').Count | Should -Be 1
        $test.withheld | Should -BeNullOrEmpty
        $acceptance = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $solution -Environment acceptance
        $acceptance.problems | Should -BeNullOrEmpty
        @($acceptance.layers | Where-Object role -eq 'testdata').Count | Should -Be 0
        ($acceptance.withheld -join ' ') | Should -Match 'not delivered to acceptance'
    }
    It 'refuses a setting that names <_>' -ForEach '/Globalsettings/System/Database/Password', '/Globalsettings/System/Mail/SmtpServer', '/Globalsettings/Modules/X/ApiKey' {
        $solution = Join-Path $script:Work ("solution-secret-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $solution | Out-Null
        (@{ settings = @{ $_ = 'x' } } | ConvertTo-Json) | Set-Content -LiteralPath (Join-Path $solution 'settings.json')
        ((Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $solution).problems -join ' ') | Should -Match 'never travels with a release'
    }
    It 'refuses a class folder that is not named <mode>.<name> or has no manifest' {
        $solution = Join-Path $script:Work 'solution-badunit'
        New-Item -ItemType Directory -Force -Path (Join-Path $solution 'serializer/reference') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $solution 'serializer/merge.nomanifest') | Out-Null
        $problems = (Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $solution).problems -join ' '
        $problems | Should -Match 'is not named'
        $problems | Should -Match 'carries no merge-manifest.json'
    }
}

Describe 'New-Composition' {
    It 'stages base-only as the base''s own entries and files' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only
        $c = New-Composition -Plan $plan -Report (New-TestReport 'compose-base')
        $c.failures | Should -BeNullOrEmpty
        $source = Read-Manifest (Join-Path $script:RepoRoot 'layers/base/replace/replace-manifest.json')
        $staged = Read-Manifest (Join-Path $c.root 'replace/replace-manifest.json')
        @($staged.entries).Count | Should -Be @($source.entries).Count
        @($staged.entries | ForEach-Object entryId) | Should -Be @($source.entries | ForEach-Object entryId)
        Test-Path -LiteralPath $c.config | Should -BeTrue
    }
    It 'stages swift-demo with every named file present and every content area on the target website' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition swift-demo
        $c = New-Composition -Plan $plan -Report (New-TestReport 'compose-swift') -AreaId 1
        $c.failures | Should -BeNullOrEmpty
        foreach ($mode in 'replace', 'merge') {
            $staged = Read-Manifest (Join-Path $c.root "$mode/$mode-manifest.json")
            $expected = 0
            foreach ($l in $plan.layers) {
                $m = Join-Path $l.dir "$mode/$mode-manifest.json"
                if (Test-Path -LiteralPath $m) { $expected += @((Read-Manifest $m).entries).Count }
            }
            (@($staged.entries).Count + $c.modes[$mode].overrides) | Should -Be $expected
            @($staged.entries | Where-Object { $null -ne $_.areaId } | ForEach-Object areaId | Sort-Object -Unique) | Should -Be @(1)
            @($staged.entries | Where-Object { "$($_.entryId)" -match 'area-(?!1(/|$))' }).Count | Should -Be 0
        }
        $config = Read-Manifest $c.config
        @($config.predicates | Where-Object { $_.providerType -eq 'Content' } | ForEach-Object areaId | Sort-Object -Unique) | Should -Be @(1)
    }
    It 'reports a file no composed layer ships' {
        $solution = Join-Path $script:Work 'solution-missingfile'
        $unit = Join-Path $solution 'serializer/merge.broken'
        New-Item -ItemType Directory -Force -Path $unit | Out-Null
        '{"schemaVersion":2,"mode":"merge","entries":[{"providerType":"SqlTable","table":"X","entryId":"sql/X","files":["_sql/X/1.yml"]}]}' | Set-Content -LiteralPath (Join-Path $unit 'merge-manifest.json')
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $solution
        $c = New-Composition -Plan $plan -Report (New-TestReport 'compose-missing')
        ($c.failures -join ' ') | Should -Match 'names a file no composed layer ships'
    }
    It 'composes the example solution''s class folder into the merge tree' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition base-only -SolutionRoot $script:Example
        $c = New-Composition -Plan $plan -Report (New-TestReport 'compose-example')
        $c.failures | Should -BeNullOrEmpty
        @((Read-Manifest (Join-Path $c.root 'merge/merge-manifest.json')).entries | ForEach-Object entryId) | Should -Contain 'sql/EcomCompletionRules'
        @((Read-Manifest $c.config).predicates | ForEach-Object name) | Should -Contain 'pim-solution EcomCompletionRules'
    }
}

Describe 'helpers' {
    It 'orders Dynamicweb versions' {
        Compare-DwVersion '10.30.8+abc' '10.29.0' | Should -Be 1
        Compare-DwVersion '10.28.11' '10.29.0' | Should -Be -1
        Compare-DwVersion '10.29.0' '10.29' | Should -Be 0
    }
    It 'refuses an unmapped pipeline secret as a key' {
        $env:DW_API_KEY_TEST = '$(DW_API_KEY)'
        { Resolve-DwApiKey -EnvName 'DW_API_KEY_TEST' } | Should -Throw
        $env:DW_API_KEY_TEST = $null
    }
    It 'refuses a rooted path and a parent segment as a Files directory' {
        { ConvertTo-FilesDirectory 'C:\temp' } | Should -Throw
        { ConvertTo-FilesDirectory 'System/../..' } | Should -Throw
        ConvertTo-FilesDirectory '/Files/System/Items/' | Should -Be 'System/Items'
    }
    It 'reads the settings fragments a layer ships as leaves under Features' {
        $plan = Get-EditionPlan -DistributionRoot $script:RepoRoot -Edition swift-demo
        $leaf = @(Get-SettingsFragmentLeaf -Plan $plan | Where-Object { $_.key -eq '/Globalsettings/Features/Commerce/Newdiscountexperience' })
        $leaf.Count | Should -Be 1
        $leaf[0].allowed | Should -BeTrue
        $leaf[0].value | Should -Be 'True'
    }
}

Describe 'the pipeline items' {
    It 'pass the validator''s structural check' {
        $rows = @(Test-PipelineItem -RepoRoot $script:RepoRoot)
        $rows.Count | Should -BeGreaterThan 0
        @($rows | Where-Object { -not $_.ok } | ForEach-Object msg) | Should -BeNullOrEmpty
    }
    It 'get one release tag each' {
        $tags = @(Get-PipelineReleaseTag -RepoRoot $script:RepoRoot | ForEach-Object Tag)
        $tags | Should -Contain "pipelines/core/$((Get-Content (Join-Path $script:RepoRoot 'pipelines/core/pipeline.json') -Raw | ConvertFrom-Json).version)"
        $tags | Should -Contain "pipelines/azure/$((Get-Content (Join-Path $script:RepoRoot 'pipelines/azure/pipeline.json') -Raw | ConvertFrom-Json).version)"
    }
}
