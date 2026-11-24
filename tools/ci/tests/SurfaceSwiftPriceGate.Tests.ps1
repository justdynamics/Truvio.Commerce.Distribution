<#
.SYNOPSIS
Pester guard for surface-swift 1.19.7 (Foundry #1773): the list repeater and the product detail grid keep the
price out of the analytics data layer when the area's price gate is on.
#>
BeforeAll {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:layerDir = Join-Path $script:root 'layers\surface-swift'
    $script:layer = Get-Content -Raw -LiteralPath (Join-Path $script:layerDir 'layer.json') | ConvertFrom-Json
    $script:files = @{
        repeater = 'Templates/Designs/Swift-v2/Paragraph/Swift-v2_ProductListItemRepeater.cshtml'
        detail   = 'Templates/Designs/Swift-v2/eCom/ProductCatalog/ProductDetailRenderGrid.cshtml'
    }
    $script:read = { param($rel) Get-Content -Raw -LiteralPath (Join-Path $script:layerDir ('files/' + $rel)) }
}

Describe 'surface-swift: the price gate holds in the data layer (1.19.7)' {

    It 'both overrides ship in files/ and are registered in files[] and placeholders[]' {
        foreach ($rel in $script:files.Values) {
            Test-Path -LiteralPath (Join-Path $script:layerDir ('files/' + $rel)) -PathType Leaf | Should -BeTrue
            @($script:layer.files) | Should -Contain $rel
            $e = @($script:layer.placeholders | Where-Object { $_.path -eq $rel })
            $e.Count | Should -Be 1
            $e[0].why | Should -Match '1773'
        }
    }

    It 'both read the gate the way the price template does' {
        foreach ($rel in $script:files.Values) {
            $t = & $script:read $rel
            $t | Should -Match 'GetRawValueString\("AnonymousUsers", string\.Empty\)'
            $t | Should -Match 'bool hidePrice = anonymousUsersLimitations\.Contains\("price"\) && Pageview\.User == null;'
        }
    }

    It 'every price in a push sits inside the gate' {
        foreach ($rel in $script:files.Values) {
            $t = & $script:read $rel
            $prices = @([regex]::Matches($t, '(?m)^\s*(<text>)?(price|value): @'))
            $prices.Count | Should -BeGreaterThan 0
            $gated = @([regex]::Matches($t, '@if \(!hidePrice\)\s*\{\s*<text>currency: "@\w+\.Price\.CurrencyCode",\s*(value|price): @'))
            $gated.Count | Should -Be @([regex]::Matches($t, '(?m)^\s*(<text>)?currency: "@\w+\.Price\.CurrencyCode"')).Count
        }
    }

    It 'the repeater''s onclick passes no price when the gate is on' {
        $t = & $script:read $script:files.repeater
        $t | Should -Match ([regex]::Escape('{(hidePrice ? "" : product.Price.ToStringInvariant())}'))
        $t | Should -Not -Match ([regex]::Escape("'{product.Price.ToStringInvariant()}'"))
    }

    It 'RED CONTROL: the stock lines are flagged' {
        $stock = "currency: `"@product.Price.CurrencyCode`",`r`nprice: @product.Price.ToStringInvariant(),"
        @([regex]::Matches($stock, '@if \(!hidePrice\)\s*\{\s*<text>currency:')).Count | Should -Be 0
        "'{product.Price.ToStringInvariant()}'" | Should -Match ([regex]::Escape("'{product.Price.ToStringInvariant()}'"))
    }
}
