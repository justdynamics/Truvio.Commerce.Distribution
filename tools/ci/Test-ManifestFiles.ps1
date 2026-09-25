<#
.SYNOPSIS
Manifest files[] vs disk for SqlTable entries (Distribution #89, part 1) and Content entries
(part 2).

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

Content entries (part 2, Test-ContentManifestFiles) are compared per mode directory. The
Serializer reads a Content entry's YAML from the area directory _content/<areaName>/ and uses
files[] as a PAGE filter (ContentDeserializer.PruneToEntryFiles): a page is written when its
page.yml is named or a descendant page is kept, and a kept page brings every grid row and
paragraph file under its folder. So:
  declared-not-on-disk -> a renamed, moved or deleted document still named (the surface-swift
                          paragraph drift of PR #62 and #65);
  disk-not-declared    -> a document no entry of the mode names: a page.yml that is pruned and
                          never written, or a paragraph that rides along only by accident of
                          its folder.
The entry's subtree root is resolved from its path the way the Serializer names folders: each
page name with the Windows-invalid file-name characters replaced by '_' (so '/Header / Footer'
is the folder 'Header _ Footer'), optionally followed by the ' [xxxxxx]' sibling de-dup suffix.

Allowed, by design: a subtree serialize (path below the area root) writes and lists its frame,
which is the area's area.yml, the page.yml of every ancestor page above the subtree root
(structural stubs, ContentSerializer ancestor pass-through) and _content/templates.manifest.yml.
A feature layer ships only its subtree, because the layer that owns those pages ships them. A
frame file that files[] lists and the tree does not carry is harmless: files[] only filters the
tree that is on disk, and templates.manifest.yml is read from disk, never through files[]. So a
listed-but-absent frame file of the entry's own subtree passes; any other absent file fails, and
so does a declared file outside the entry's subtree and frame.

Declared override (ruling dla-q4): the kind:sample-data layer composes after every surface and
ships storefront copy at a surface's own paths; the composed tree holds one file per path, so
its copy is the one the surface's entry deserializes. Such a file is declared by the surface
manifest entry that deserializes it, and the sample-data manifest adds no Content entry for it:
a second entry would run the pages twice, and Compose-Edition remaps every entry to the edition's
one area, so on an edition without the Swift 2 area it would write storefront pages into another
area. A disk file of a sample-data layer passes when a kind:surface layer's manifest of the same
mode declares the same path; the validator reports how many ride this way.

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

# ---------------------------------------------------------------------------------------------
# Content entries (Distribution #89, part 2).
# ---------------------------------------------------------------------------------------------

# The Serializer's folder name for a page or area name (FileSystemStore.SanitizeFolderName, on the
# Windows host that serializes): trimmed, each Windows-invalid file-name character -> '_', and an
# empty name -> '_unnamed'. Spelled out rather than [IO.Path]::GetInvalidFileNameChars(), which on
# the Linux CI runner lists only '/' and NUL.
function ConvertTo-ContentFolderName {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Name)
    $t = $Name.Trim()
    if ($t -eq '') { return '_unnamed' }
    $sb = [System.Text.StringBuilder]::new()
    foreach ($c in $t.ToCharArray()) {
        if ([int]$c -lt 32 -or '"<>|:*?\/'.IndexOf($c) -ge 0) { [void]$sb.Append('_') } else { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

# Resolve a Content entry's subtree root folder ('_content/<area>/<page>/...') from its path. A
# page name may itself contain '/' ('Header / Footer'), so each step tries every split of the
# remaining path and takes the child folder that matches its sanitized name, with or without the
# ' [xxxxxx]' sibling de-dup suffix. $Folders is the set of folders the tree and files[] describe.
# Returns @{ root; ancestors[] } (ancestors: the page folders strictly above root, below the area
# folder), or $null when the path does not resolve to a folder.
function Resolve-ContentEntryRoot {
    param(
        [Parameter(Mandatory)][string]$AreaFolder,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[string]]$Folders
    )
    $cur = $AreaFolder
    $ancestors = @()
    $rest = $Path.Trim('/')
    while ($rest -ne '') {
        $cuts = @()
        for ($i = 0; $i -lt $rest.Length; $i++) { if ($rest[$i] -eq '/') { $cuts += $i } }
        $cuts += $rest.Length
        $next = $null; $nextRest = $null
        foreach ($k in $cuts) {
            $name = ConvertTo-ContentFolderName -Name $rest.Substring(0, $k)
            $pattern = '^' + [regex]::Escape("$cur/$name") + '( \[[0-9a-f]{6}\])?$'
            $hit = @($Folders | Where-Object { $_ -cmatch $pattern } | Sort-Object -CaseSensitive) | Select-Object -First 1
            if ($hit) {
                $next = $hit
                $nextRest = if ($k -ge $rest.Length) { '' } else { $rest.Substring($k + 1).TrimStart('/') }
                break
            }
        }
        if (-not $next) { return $null }
        if ($nextRest -ne '') { $ancestors += $next }
        $cur = $next
        $rest = $nextRest
    }
    return [pscustomobject]@{ root = $cur; ancestors = $ancestors }
}

# Compare the Content entries of one mode directory (replace/ or merge/) with its _content tree.
# The manifest may be absent (a mode tree that ships _content and no manifest declares nothing).
# -OverrideDeclared: paths another layer's manifest of this mode declares, which this layer's copy
# overrides by composition order (sample-data only, ruling dla-q4; the caller decides who gets it).
# Returns $null when the mode has neither Content entries nor _content files, else
# @{ ok; entries[]; onDisk; declared; notDeclared[]; overrides[]; reason }, each entry
# @{ ok; entryId; root; declared; frameAbsent[]; notOnDisk[]; outside[]; reason }.
function Test-ContentManifestFiles {
    param(
        [Parameter(Mandatory)][string]$ModeDir,
        [string[]]$OverrideDeclared = @()
    )
    $mode = Split-Path -Leaf $ModeDir
    $manifestPath = Join-Path $ModeDir "$mode-manifest.json"
    $contentDir = Join-Path $ModeDir '_content'

    $onDisk = @()
    if (Test-Path -LiteralPath $contentDir -PathType Container) {
        $base = (Resolve-Path -LiteralPath $ModeDir).ProviderPath.TrimEnd('\', '/')
        $onDisk = @(Get-ChildItem -LiteralPath $contentDir -File -Recurse -Filter '*.yml' -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -ceq '.yml' } |
            ForEach-Object { $_.FullName.Substring($base.Length + 1) -replace '\\', '/' })
    }

    $entries = @()
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        try { $doc = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -ErrorAction Stop }
        catch {
            return [pscustomobject]@{ ok = $false; entries = @(); onDisk = $onDisk.Count; declared = 0; notDeclared = @(); overrides = @()
                reason = "manifest does not parse: $($_.Exception.Message)" }
        }
        $entries = @(@($doc.entries) | Where-Object { $_ -and "$($_.providerType)" -eq 'Content' })
    }
    if ($entries.Count -eq 0 -and $onDisk.Count -eq 0) { return $null }

    $diskSet = [System.Collections.Generic.HashSet[string]]::new([string[]]$onDisk, [System.StringComparer]::Ordinal)
    $allDeclared = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($e in $entries) { foreach ($f in @($e.files)) { if ($null -ne $f) { [void]$allDeclared.Add(("$f" -replace '\\', '/')) } } }

    # Every folder the tree and files[] describe, for root resolution.
    $folders = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($p in @($onDisk) + @($allDeclared)) {
        $d = $p
        while (($i = $d.LastIndexOf('/')) -gt 0) { $d = $d.Substring(0, $i); [void]$folders.Add($d) }
    }

    $results = @()
    foreach ($e in $entries) {
        $declared = @(@($e.files) | Where-Object { $null -ne $_ } | ForEach-Object { "$_" -replace '\\', '/' })
        $areaFolder = '_content/' + (ConvertTo-ContentFolderName -Name "$($e.areaName)")
        $res = Resolve-ContentEntryRoot -AreaFolder $areaFolder -Path "$($e.path)" -Folders $folders
        if (-not $res) {
            $results += [pscustomobject]@{ ok = $false; entryId = "$($e.entryId)"; root = ''; declared = $declared.Count
                frameAbsent = @(); notOnDisk = @(); outside = @()
                reason = "path '$($e.path)' in area '$($e.areaName)' resolves to no folder under $areaFolder/" }
            continue
        }
        $frame = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        [void]$frame.Add('_content/templates.manifest.yml')
        [void]$frame.Add("$areaFolder/area.yml")
        foreach ($a in $res.ancestors) { [void]$frame.Add("$a/page.yml") }

        $inRoot = { param($f) $f.StartsWith("$($res.root)/", [System.StringComparison]::Ordinal) }
        $notOnDisk   = @($declared | Where-Object { -not $diskSet.Contains($_) -and -not $frame.Contains($_) } | Sort-Object -Unique -CaseSensitive)
        $frameAbsent = @($declared | Where-Object { -not $diskSet.Contains($_) -and $frame.Contains($_) } | Sort-Object -Unique -CaseSensitive)
        $outside     = @($declared | Where-Object { -not $frame.Contains($_) -and -not (& $inRoot $_) } | Sort-Object -Unique -CaseSensitive)
        $results += [pscustomobject]@{
            ok = ($notOnDisk.Count -eq 0 -and $outside.Count -eq 0); entryId = "$($e.entryId)"; root = $res.root
            declared = $declared.Count; frameAbsent = $frameAbsent; notOnDisk = $notOnDisk; outside = $outside; reason = ''
        }
    }

    $overrideSet = [System.Collections.Generic.HashSet[string]]::new([string[]]@($OverrideDeclared | Where-Object { $_ }), [System.StringComparer]::Ordinal)
    $undeclared = @($onDisk | Where-Object { -not $allDeclared.Contains($_) })
    $overrides   = @($undeclared | Where-Object { $overrideSet.Contains($_) } | Sort-Object -Unique -CaseSensitive)
    $notDeclared = @($undeclared | Where-Object { -not $overrideSet.Contains($_) } | Sort-Object -Unique -CaseSensitive)

    return [pscustomobject]@{
        ok          = (@($results | Where-Object { -not $_.ok }).Count -eq 0 -and $notDeclared.Count -eq 0)
        entries     = $results
        onDisk      = $onDisk.Count
        declared    = $allDeclared.Count
        notDeclared = $notDeclared
        overrides   = $overrides
        reason      = ''
    }
}

# One validator line per mode directory: PASS with the totals (frame files listed-but-absent and
# declared overrides counted, never silent), or FAIL naming every differing entry and file.
function Get-ContentManifestFilesFinding {
    param(
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)]$Result
    )
    $frameN = [int](@($Result.entries | ForEach-Object { $_.frameAbsent.Count }) | Measure-Object -Sum).Sum
    $notes = @()
    if ($frameN -gt 0) { $notes += "$frameN frame file(s) listed and shipped by the owning layer" }
    if ($Result.overrides.Count -gt 0) { $notes += "$($Result.overrides.Count) declared override(s) of a surface path" }
    $tail = if ($notes.Count) { '; ' + ($notes -join '; ') } else { '' }
    $n = @($Result.entries).Count
    if ($Result.ok) {
        return [pscustomobject]@{ ok = $true
            msg = "$Label Content files[] match disk ($n entr$(if($n -eq 1){'y'}else{'ies'}), $($Result.onDisk) file(s) on disk$tail)" }
    }
    if ($Result.reason) { return [pscustomobject]@{ ok = $false; msg = "$Label Content - $($Result.reason)" } }
    $parts = @()
    foreach ($b in @($Result.entries | Where-Object { -not $_.ok })) {
        if ($b.reason) { $parts += "'$($b.entryId)' - $($b.reason)"; continue }
        $d = @()
        if ($b.notOnDisk.Count) { $d += "declared-not-on-disk $($b.notOnDisk.Count): " + ($b.notOnDisk -join ', ') }
        if ($b.outside.Count)   { $d += "declared outside the subtree $($b.root)/ $($b.outside.Count): " + ($b.outside -join ', ') }
        $parts += "'$($b.entryId)' - " + ($d -join '; ')
    }
    if ($Result.notDeclared.Count) {
        $parts += "disk-not-declared by any Content entry $($Result.notDeclared.Count): " + ($Result.notDeclared -join ', ')
    }
    return [pscustomobject]@{ ok = $false
        msg = "$Label Content files[] differ from disk - " + ($parts -join ' || ') + ". Remediation: regenerate the " +
              "entry's files[] from its subtree (or restore the moved documents) so every document on disk is named " +
              "by one entry and every named document is on disk." }
}
