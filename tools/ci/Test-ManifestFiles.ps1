<#
.SYNOPSIS
Manifest files[] vs disk for SqlTable entries (Distribution #89, part 1).

.DESCRIPTION
A layer's replace/replace-manifest.json and merge/merge-manifest.json name, per SqlTable entry,
every row file the Serializer reads for that table in files[]. Serializer strict mode refuses a
delivery whose directory holds a document the entry does not name ("N document(s) ... are not
named by the manifest entry's files[]"), so a manifest that drifts from its tree passes CI and
fails on the first remote delivery. PR #88 did exactly that: base 4.0.0 renamed row files (the
name comes from the name column) and the manifest kept the old names.

For every SqlTable entry the declared files[] set is compared with the *.yml files directly in
the entry's directory, _sql/<table>/ below the manifest's mode directory, BOTH directions:
  declared-not-on-disk -> a renamed, deleted or misspelt row file still named;
  disk-not-declared    -> a row file the Serializer would find and strict mode would refuse.

Path form, taken from the committed manifests: files[] entries are relative to the mode
directory (replace/ or merge/), '/'-separated, '_sql/<table>/<file>.yml'. The table schema file
_meta.yml is listed like any row file when the table carries one, so it is compared like any
other file. Names compare ordinally (case-sensitive): the Linux CI runner and the Serializer on a
Linux host are case-sensitive, so a case-only rename is drift.

Content entries are out of scope here (part 2 of #89, owner decision pending).

Functions only; dot-sourced by Validate-Distribution.ps1 and tools/ci/tests.
#>

# Compare every SqlTable entry of one manifest with its directory. Returns one result per
# entry: @{ ok; entryId; table; declared; onDisk; notOnDisk[]; notDeclared[] }. A manifest that
# does not parse, or an entry with no table, is returned as a failing result with a reason.
function Test-SqlTableManifestFiles {
    param([Parameter(Mandatory)][string]$ManifestPath)

    $modeDir = Split-Path -Parent $ManifestPath
    $doc = $null
    try { $doc = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop }
    catch {
        return @([pscustomobject]@{ ok = $false; entryId = ''; table = ''; declared = 0; onDisk = 0
            notOnDisk = @(); notDeclared = @(); reason = "manifest does not parse: $($_.Exception.Message)" })
    }

    $results = @()
    foreach ($e in @($doc.entries)) {
        if (-not $e -or "$($e.providerType)" -ne 'SqlTable') { continue }
        $table = "$($e.table)"
        if ([string]::IsNullOrWhiteSpace($table)) {
            $results += [pscustomobject]@{ ok = $false; entryId = "$($e.entryId)"; table = ''; declared = 0; onDisk = 0
                notOnDisk = @(); notDeclared = @(); reason = 'SqlTable entry names no table' }
            continue
        }

        $declared = @(@($e.files) | Where-Object { $null -ne $_ } | ForEach-Object { "$_" -replace '\\', '/' })
        $tableDir = Join-Path (Join-Path $modeDir '_sql') $table
        $onDisk = @()
        if (Test-Path -LiteralPath $tableDir -PathType Container) {
            $onDisk = @(Get-ChildItem -LiteralPath $tableDir -File -Filter '*.yml' -ErrorAction SilentlyContinue |
                Where-Object { $_.Extension -ceq '.yml' } |
                ForEach-Object { "_sql/$table/$($_.Name)" })
        }

        $declSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$declared, [System.StringComparer]::Ordinal)
        $diskSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$onDisk,   [System.StringComparer]::Ordinal)
        $notOnDisk   = @($declared | Where-Object { -not $diskSet.Contains($_) } | Sort-Object -Unique -CaseSensitive)
        $notDeclared = @($onDisk   | Where-Object { -not $declSet.Contains($_) } | Sort-Object -Unique -CaseSensitive)

        $results += [pscustomobject]@{
            ok          = ($notOnDisk.Count -eq 0 -and $notDeclared.Count -eq 0)
            entryId     = "$($e.entryId)"
            table       = $table
            declared    = $declared.Count
            onDisk      = $onDisk.Count
            notOnDisk   = $notOnDisk
            notDeclared = $notDeclared
            reason      = ''
        }
    }
    return $results
}

# One validator line per manifest: PASS with the totals, or FAIL naming every differing entry
# and every differing file. Returns @{ ok; msg }.
function Get-SqlTableManifestFilesFinding {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results
    )
    $bad = @($Results | Where-Object { -not $_.ok })
    $files = ($Results | Measure-Object -Property declared -Sum).Sum
    if ($bad.Count -eq 0) {
        return [pscustomobject]@{ ok = $true
            msg = "$Label SqlTable files[] match disk ($($Results.Count) entr$(if($Results.Count -eq 1){'y'}else{'ies'}), $([int]$files) file(s))" }
    }
    $parts = foreach ($b in $bad) {
        $name = if ($b.table) { "_sql/$($b.table)" } else { "entry '$($b.entryId)'" }
        if ($b.reason) { "$name - $($b.reason)"; continue }
        $d = @()
        if ($b.notOnDisk.Count)   { $d += "declared-not-on-disk $($b.notOnDisk.Count): " + ($b.notOnDisk -join ', ') }
        if ($b.notDeclared.Count) { $d += "disk-not-declared $($b.notDeclared.Count): " + ($b.notDeclared -join ', ') }
        "$name ($($b.declared) declared / $($b.onDisk) on disk) - " + ($d -join '; ')
    }
    return [pscustomobject]@{ ok = $false
        msg = "$Label SqlTable files[] differ from disk in $($bad.Count) of $($Results.Count) entr$(if($Results.Count -eq 1){'y'}else{'ies'}) - " +
              ($parts -join ' || ') + ". Serializer strict mode refuses this delivery. Remediation: regenerate files[] from the " +
              "directory (or restore the renamed row files) so both sets are equal." }
}
