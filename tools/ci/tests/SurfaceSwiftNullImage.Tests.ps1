<#
.SYNOPSIS
Pester (v5+) guard for surface-swift's three null-safe search and favourite overrides
(surface-swift 1.19.4; compaction card k-7fd9de33).

  pwsh -NoProfile -Command "Invoke-Pester -Path tools/ci/tests -CI"

Stock Swift 2.5.0 dereferences ProductViewModel.DefaultImage.Value (and, in the header dropdown,
PrimaryOrDefaultGroup.Id) unguarded in eCom/ProductCatalog/ExpressBuySearchResponse.cshtml,
ProductSearchDropdownResponse.cshtml and Favorites.cshtml. A catalogue with valid products that carry
no image (a migrated catalogue) then throws a NullReferenceException in any search whose result set
contains one: Quick add and the header type-ahead answer nothing, and the favourite toggle fails.
The overrides keep the stock file and add the null guards. This test keeps them registered and keeps
the guards in place when the layer is re-based on a later Swift release.
#>

BeforeAll {
    $script:root = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $script:layerDir = Join-Path $script:root 'layers\surface-swift'
    $script:layer = Get-Content -Raw -LiteralPath (Join-Path $script:layerDir 'layer.json') | ConvertFrom-Json
    $script:overrides = @(
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/ExpressBuySearchResponse.cshtml',
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/ProductSearchDropdownResponse.cshtml',
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/Favorites.cshtml'
    )
    # A member access on DefaultImage or PrimaryOrDefaultGroup that is not null-conditional.
    $script:unguarded = '(?<![?\w])(DefaultImage|PrimaryOrDefaultGroup)\.(Value|Id)\b'
}

Describe 'surface-swift: the search and favourite templates survive a product without an image' {

    It '<_> ships in files/ and is registered in layer.json files[] and placeholders[] with a why' -ForEach @(
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/ExpressBuySearchResponse.cshtml',
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/ProductSearchDropdownResponse.cshtml',
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/Favorites.cshtml'
    ) {
        $rel = $_
        Test-Path -LiteralPath (Join-Path $script:layerDir ('files/' + $rel)) -PathType Leaf | Should -BeTrue
        @($script:layer.files) | Should -Contain $rel
        $entry = @($script:layer.placeholders | Where-Object { $_.path -eq $rel })
        $entry.Count | Should -Be 1
        $entry[0].kind | Should -Be 'template'
        $entry[0].why | Should -Match 'image'
    }

    It '<_> dereferences DefaultImage and PrimaryOrDefaultGroup only null-safely' -ForEach @(
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/ExpressBuySearchResponse.cshtml',
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/ProductSearchDropdownResponse.cshtml',
        'Templates/Designs/Swift-v2/eCom/ProductCatalog/Favorites.cshtml'
    ) {
        $lines = Get-Content -LiteralPath (Join-Path $script:layerDir ('files/' + $_))
        $hits = @(for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $script:unguarded) { "line $($i + 1): $($lines[$i].Trim())" }
        })
        $hits | Should -BeNullOrEmpty -Because 'a product without an image (or without a primary group) must render, not throw'
    }

    It 'RED CONTROL: the guard pattern flags the stock Swift 2.5.0 lines it replaced' {
        @(
            '<img src="/Admin/public/getimage.ashx?image=@Dynamicweb.Context.Current.Server.UrlEncode(product.DefaultImage.Value)&width=60">',
            'var defaultGroupId = suggestion.PrimaryOrDefaultGroup.Id;',
            'string productImage = "/Admin/Public/GetImage.ashx?Image=" + Model.DefaultImage.Value + "&width=80";'
        ) | ForEach-Object { $_ | Should -Match $script:unguarded }
        @(
            'Server.UrlEncode(product.DefaultImage?.Value ?? string.Empty)',
            'var defaultGroupId = suggestion.PrimaryOrDefaultGroup?.Id ?? string.Empty;',
            'string defaultImage = Model.DefaultImage?.Value ?? string.Empty;',
            'if (productViewModel != null && productViewModel?.PrimaryOrDefaultGroup?.Id != null)'
        ) | ForEach-Object { $_ | Should -Not -Match $script:unguarded }
    }
}
