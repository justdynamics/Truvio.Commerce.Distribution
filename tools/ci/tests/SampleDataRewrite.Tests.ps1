<#
.SYNOPSIS
Pester (v5+) runner for the sample-data rewrite generator's own tests (Distribution #163).

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

tools/sample-data/rewrite-sample-data.py rewrites a copy of the sample-data layer from a customer
data file. Its tests are Python unittest (the generator is Python, like the sample-data layer's tools) and run
it on the fictional Vellmark fixture: determinism, no sample row left outside the stable keys, the stable
keys intact, every reference resolving, the inventories agreeing with the tree, the refusals, and
Validate-Distribution.ps1 run on a Distribution where the copy stands in place of sample-data, and (when the
skills checkout carries the recipe input schema) that the generator schema accepts every member of it. This file
only runs them, so the CI step that runs tools/ci/tests runs them too. The ledger skills checkout CI makes
for the CPQ tests is passed on as TRUVIO_SKILLS_PATH, so the ledger checks run in the validator trees.
#>

BeforeAll {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:tests = Join-Path $script:root 'tools\sample-data\tests'
    $script:python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $script:python -or $script:python.Source -match 'WindowsApps') { $script:python = Get-Command python -ErrorAction SilentlyContinue }
}

Describe 'sample-data: the rewrite generator' {
    It 'passes its unit tests on the Vellmark fixture' {
        if (-not $script:python) { Set-ItResult -Skipped -Because 'no python on PATH'; return }
        $hadSkills = Test-Path Env:TRUVIO_SKILLS_PATH
        if (-not $hadSkills -and $env:CPQ_SKILLS_ROOT) { $env:TRUVIO_SKILLS_PATH = $env:CPQ_SKILLS_ROOT }
        try {
            # -B: no __pycache__ written beside the generator or its tests.
            $out = & $script:python.Source -B -m unittest discover -s $script:tests -v 2>&1
            $code = $LASTEXITCODE
        } finally {
            if (-not $hadSkills) { Remove-Item Env:TRUVIO_SKILLS_PATH -ErrorAction SilentlyContinue }
        }
        $code | Should -Be 0 -Because (($out | ForEach-Object { "$_" }) -join "`n")
    }
}
