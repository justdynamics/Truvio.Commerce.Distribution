<#
.SYNOPSIS
Protected-string regression guard (plan §3.1) — proves the v3.0 layer/mode vocabulary
(deploy->replace, seed->merge, pack->layer) never leaked into an UPSTREAM DW/Swift
identifier or a YAML value / DW filesystem path. Ported verbatim from the harness
(tools/harness/Invoke-ProtectedStringCheck.ps1) so the Distribution CI is self-contained.

Fails closed on (A) mangled anchors ("Replace 2 Nederlands", "Swift-v2_Merge", ...),
(B) a mode word as a DW path segment inside a value ("/replace/", "\merge\"), and
(C) missing positive anchors ("Swift 2" + "Swift-v2_" must survive in the content-carrying layer: surface-swift since the Swift 2.4 base split).
#>
function Test-ProtectedStrings {
    param(
        [Parameter(Mandatory)][string]$LayersRoot
    )

    if (-not (Test-Path -LiteralPath $LayersRoot -PathType Container)) {
        return @{ check = 8; name = 'Protected-string guard (plan 3.1)'; result = 'FAIL'
                  detail = "layers root not found at '$LayersRoot' — cannot run the protected-string scan (fail-closed)" }
    }

    $contentFiles = @(
        Get-ChildItem -LiteralPath $LayersRoot -Recurse -File -Include '*.yml','*.yaml','*.cshtml','*.cs' -ErrorAction SilentlyContinue
    )

    $mangledRx = @(
        '\b(Replace|Merge|Deploy|Seed) 2 Nederlands\b',
        '\b(Replace|Merge|Deploy|Seed) 2\b',
        '(Replace|Merge)-v2_',
        'Swift-v2_(Replace|Merge)\b',
        'Headless_(Replace|Merge)\b'
    ) -join '|'

    $pathLeakRx = '[\\/](replace|merge)[\\/]'

    $violations = @()
    foreach ($f in $contentFiles) {
        try {
            $hitsA = Select-String -LiteralPath $f.FullName -Pattern $mangledRx -AllMatches -ErrorAction Stop
            foreach ($h in $hitsA) { $violations += "MANGLED-ANCHOR $($f.FullName):$($h.LineNumber): $($h.Line.Trim())" }
            $hitsB = Select-String -LiteralPath $f.FullName -Pattern $pathLeakRx -AllMatches -ErrorAction Stop
            foreach ($h in $hitsB) { $violations += "MODE-IN-PATH $($f.FullName):$($h.LineNumber): $($h.Line.Trim())" }
        } catch {
            $violations += "SCAN-ERROR $($f.FullName): $_"
        }
    }

    # Base split (Swift 2.4): the Swift content anchors live in surface-swift;
    # pre-split trees keep the base fallback.
    $baseRoot = Join-Path $LayersRoot 'surface-swift'
    if (-not (Test-Path -LiteralPath $baseRoot -PathType Container)) {
        $baseRoot = Join-Path $LayersRoot 'base'
    }
    $missingAnchors = @()
    if (Test-Path -LiteralPath $baseRoot -PathType Container) {
        foreach ($anchor in @('Swift 2', 'Swift-v2_')) {
            $present = Select-String -LiteralPath (Get-ChildItem -LiteralPath $baseRoot -Recurse -File -Include '*.yml' -ErrorAction SilentlyContinue).FullName `
                -Pattern ([regex]::Escape($anchor)) -List -ErrorAction SilentlyContinue
            if (-not $present) { $missingAnchors += $anchor }
        }
    } else {
        $missingAnchors += "(content-carrying layer root missing)"
    }

    if ($violations.Count -eq 0 -and $missingAnchors.Count -eq 0) {
        return @{ check = 8; name = 'Protected-string guard (plan 3.1)'; result = 'PASS'
                  detail = "scanned $($contentFiles.Count) content file(s) under layers/; zero mangled-anchor / mode-in-path violations; base anchors 'Swift 2' + 'Swift-v2_' present" }
    }

    $detailParts = @()
    if ($violations.Count -gt 0)    { $detailParts += "$($violations.Count) violation(s): $((@($violations) | Select-Object -First 8) -join ' | ')" }
    if ($missingAnchors.Count -gt 0){ $detailParts += "missing base anchor(s): $($missingAnchors -join ', ')" }
    return @{ check = 8; name = 'Protected-string guard (plan 3.1)'; result = 'FAIL'
              detail = ($detailParts -join ' ;; ') + ' — a protected DW/Swift string was altered by the vocabulary rewrite (plan 3.1)' }
}
