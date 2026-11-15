<#
.SYNOPSIS
Pester (v5+) guard for surface-swift's two related-products row fixes
(surface-swift 1.19.5; compaction card k-975015d3).

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

Stock Swift 2.5.0 eCom/ProductCatalog/RelatedProductsList.cshtml has two row defects:
- every default image goes through /Admin/Public/GetImage.ashx?...&format=webp, which answers
  HTTP 500 for an SVG, so an SVG catalogue shows broken related-product thumbnails;
- the Stock cell says "Out of stock" for a stock-type product at zero even when the product is
  marked never out of stock (the add-to-cart cell of the same row already reads NeverOutOfstock).
The surface-swift override fixes both. This test keeps both fixes in place when the layer is
re-based on a later Swift release, or when the override is regenerated from stock.
#>

BeforeAll {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:layerDir = Join-Path $script:root 'layers\surface-swift'
    $script:layer = Get-Content -Raw -LiteralPath (Join-Path $script:layerDir 'layer.json') | ConvertFrom-Json
    $script:rel = 'Templates/Designs/Swift-v2/eCom/ProductCatalog/RelatedProductsList.cshtml'
    $script:text = Get-Content -Raw -LiteralPath (Join-Path $script:layerDir ('files/' + $script:rel))

    # The line that builds the thumbnail URL from the product's default image.
    $script:thumbLine = { param($t) @($t -split "`r?`n" | Where-Object { $_ -match '^\s*image\s*=.*GetImage\.ashx' }) }
    # An "Out of stock" condition on StockLevel that does not also read NeverOutOfstock.
    $script:stockCondition = { param($t) @($t -split "`r?`n" | Where-Object { $_ -match '@if\s*\(.*StockLevel\s*<=\s*0' }) }
}

Describe 'surface-swift: the related-products row fixes stay in place' {

    It 'the override ships in files/ and is registered in files[] and placeholders[]' {
        Test-Path -LiteralPath (Join-Path $script:layerDir ('files/' + $script:rel)) -PathType Leaf | Should -BeTrue
        @($script:layer.files) | Should -Contain $script:rel
        $entry = @($script:layer.placeholders | Where-Object { $_.path -eq $script:rel })
        $entry.Count | Should -Be 1
        $entry[0].kind | Should -Be 'template'
        $entry[0].why | Should -Match 'NeverOutOfstock'
        $entry[0].why | Should -Match 'SVG'
    }

    It 'an SVG default image bypasses GetImage.ashx; raster images keep it' {
        $lines = @(& $script:thumbLine $script:text)
        $lines.Count | Should -Be 1 -Because 'one line builds the related-product thumbnail URL'
        $lines[0] | Should -Match 'imageIsSvg\s*\?\s*image\s*:' -Because 'an SVG is linked as the file itself'
        $script:text | Should -Match 'bool\s+imageIsSvg\s*=.*EndsWith\("\.svg",\s*StringComparison\.OrdinalIgnoreCase\)'
        $script:text | Should -Match '@if\s*\(imageIsSvg\)\s*\{\s*<img src="@image" width="30" height="30"'
    }

    It 'the image helper is not used on the product thumbnail either' {
        $script:text | Should -Not -Match 'ImageHelper|GetImageUrl\(' -Because 'the Swift image helper also routes through GetImage'
    }

    It 'every "Out of stock" condition on StockLevel also reads NeverOutOfstock' {
        $conds = @(& $script:stockCondition $script:text)
        $conds.Count | Should -BeGreaterThan 0
        $conds | ForEach-Object { $_ | Should -Match '!\s*product\.NeverOutOfstock' }
    }

    It 'RED CONTROL: the checks flag the stock Swift 2.5.0 lines' {
        $stock = @(
            '						image = !string.IsNullOrEmpty(image) ? $"/Admin/Public/GetImage.ashx?image={image}&width=30&format=webp" : null;',
            '									@if (product.ProductType == Dynamicweb.Ecommerce.Products.ProductType.Stock && product.StockLevel <= 0)'
        ) -join "`r`n"
        $thumb = @(& $script:thumbLine $stock)
        $thumb.Count | Should -Be 1
        $thumb[0] | Should -Not -Match 'imageIsSvg\s*\?\s*image\s*:'
        $cond = @(& $script:stockCondition $stock)
        $cond.Count | Should -Be 1
        $cond[0] | Should -Not -Match '!\s*product\.NeverOutOfstock'
    }
}
