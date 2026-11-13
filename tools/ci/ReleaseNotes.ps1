<#
.SYNOPSIS
Release notes for the bacpac releases (Foundry #1604, owner ruling distribution-release-notes-1604,
2026-11-05): every `databases/blank/<dw>` and `editions/<edition>/<version>` release carries a
generated "What changed" section, a "Provenance" section and the same content as a
`release-notes.json` asset (shape: layers/release-notes.schema.json), so a consumer such as an
Azure DevOps pipeline reads the release over the GitHub REST API without parsing Markdown.

.DESCRIPTION
The notes are a DELTA against the previous release of the same line: the previous blank database
for a blank, the previous release of the same edition for an edition. Everything is read from this
repository's own records at two commits, never re-typed:

  the line        layers/INDEX.json `bacpacs.blank` / `bacpacs.editions.<edition>`. The previous
                  release is the tag that entry carried before the current one replaced it, found by
                  walking the history of layers/INDEX.json (Find-PreviousBacpacRelease). A line with
                  no earlier entry is a first release, and the notes say so.
  records commit  the commit a release's records are read at: an edition's `distributionCommit`
                  (the tree its database was delivered from), a blank's tag commit (HEAD while the
                  tag is not cut yet).
  DW / Swift      the entry's dwVersion; gateProven.swiftVersion at the records commit.
  layers          the edition file's pins at the records commit (from, add, surfaces; the theme and
                  sample-data layers by their layer.json version), with the entries of the layer's
                  CHANGELOG.md above the previous version up to the new one.
  components      versions/spine.json `components.<id>.current.version`, without dw and swift (those
                  two are stated from the entry and gateProven).
  pull requests   the merge commits on the first-parent line between the two records commits.

The record (the validator's offline check, tools/ci/Bacpac.ps1 check 17): a bacpac entry carries
`releaseNotes` { schema, previousTag }, written by the Foundry from New-ReleaseNotesRecord when it
registers the file. The four releases published before the rule carry it too, backfilled from the
same history (owner decision 2026-11-12); Get-ReleaseNotesExemptTag is empty. At publication the
generator recomputes the previous release and refuses a record that names another one.

Functions only: dot-sourcing defines functions and nothing else. Needs git; no network.
#>

if (-not (Get-Command Compare-SpineVersion -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Test-VersionSpine.ps1') }

# Constants as functions: this file is dot-sourced from scripts, functions and test blocks alike.
function Get-ReleaseNotesSchemaName { return 'release-notes/v1' }
function Get-ReleaseNotesAssetName { return 'release-notes.json' }

# Releases that owe no release notes. Empty: the four releases published before the rule
# (databases/blank/10.29.8, editions/swift-demo/5.5.0, editions/dap-portal/2.5.0,
# editions/headless-demo/3.4.0) were backfilled (owner decision 2026-11-12). Their register entries
# carry the `releaseNotes` record the generator derives from history, and the next -Execute gives
# each published release its body and release-notes.json asset. A tag listed here passes check 17
# without a record and is left as it is by -Execute.
function Get-ReleaseNotesExemptTag {
    return @()
}

function Get-ReleaseNotesLinePattern {
    param([Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind, [string]$Edition)
    if ($Kind -eq 'blank') { return '^databases/blank/[0-9A-Za-z.+-]+$' }
    return "^editions/$([regex]::Escape($Edition))/[0-9]+\.[0-9]+\.[0-9]+$"
}

# ---------------------------------------------------------------------------
# Test-ReleaseNotesRecord: the offline rule, as { ok; message } rows over the parsed INDEX.
# An entry published before the rule passes without a record; every other entry carries one.
# ---------------------------------------------------------------------------
function Test-ReleaseNotesRecord {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Index)
    $rows = [System.Collections.Generic.List[object]]::new()
    $bp = if ($Index.PSObject.Properties['bacpacs']) { $Index.bacpacs } else { $null }
    if (-not $bp) { return @() }
    $exempt = @(Get-ReleaseNotesExemptTag)
    $lines = @()
    if ($bp.PSObject.Properties['blank'] -and $bp.blank) { $lines += [pscustomobject]@{ pre = 'bacpacs.blank'; kind = 'blank'; edition = ''; entry = $bp.blank } }
    if ($bp.PSObject.Properties['editions'] -and $bp.editions) {
        foreach ($p in @($bp.editions.PSObject.Properties)) { $lines += [pscustomobject]@{ pre = "bacpacs.editions.$($p.Name)"; kind = 'edition'; edition = $p.Name; entry = $p.Value } }
    }
    foreach ($l in $lines) {
        $e = $l.entry; $tag = "$($e.tag)"
        $rec = if ($e.PSObject.Properties['releaseNotes']) { $e.releaseNotes } else { $null }
        if (-not $rec) {
            if ($exempt -contains $tag) { $rows.Add([pscustomobject]@{ ok = $true; message = "$($l.pre) ($tag) was published before the release-notes rule: no releaseNotes record required" }); continue }
            $rows.Add([pscustomobject]@{ ok = $false; message = "$($l.pre) ($tag) carries no releaseNotes record: every bacpac release ships generated release notes (Foundry #1604). Register the file with the Foundry tools, which write the record from tools/ci/ReleaseNotes.ps1 New-ReleaseNotesRecord" })
            continue
        }
        $okSchema = ("$($rec.schema)" -eq (Get-ReleaseNotesSchemaName))
        $rows.Add([pscustomobject]@{ ok = $okSchema; message = "$($l.pre) releaseNotes.schema '$($rec.schema)' is '$(Get-ReleaseNotesSchemaName)'" })
        if (-not $rec.PSObject.Properties['previousTag']) {
            $rows.Add([pscustomobject]@{ ok = $false; message = "$($l.pre) releaseNotes names no previousTag: state the previous release of the line, or null for the first one" })
            continue
        }
        $prev = $rec.previousTag
        if ($null -eq $prev) { $rows.Add([pscustomobject]@{ ok = $true; message = "$($l.pre) releaseNotes.previousTag is null: the first release of its line" }); continue }
        $okLine = ("$prev" -match (Get-ReleaseNotesLinePattern -Kind $l.kind -Edition $l.edition)) -and ("$prev" -ne $tag)
        $rows.Add([pscustomobject]@{ ok = $okLine; message = "$($l.pre) releaseNotes.previousTag '$prev' is another release of the same line as '$tag'" })
    }
    return @($rows)
}

# ---------------------------------------------------------------------------
# git plumbing. Output is read as UTF-8 whatever the console says.
# ---------------------------------------------------------------------------
function Invoke-ReleaseNotesGit {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string[]]$ArgumentList)
    $old = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $out = @(& git -C $RepoRoot @ArgumentList 2>$null)
        if ($LASTEXITCODE -ne 0) { return $null }
        return , @($out | ForEach-Object { "$_" })
    } finally { [Console]::OutputEncoding = $old }
}

function Get-ReleaseNotesFileAt {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$Commit, [Parameter(Mandatory)][string]$Path)
    $lines = Invoke-ReleaseNotesGit -RepoRoot $RepoRoot -ArgumentList @('show', "${Commit}:$Path")
    if ($null -eq $lines) { return $null }
    return (($lines -join "`n").TrimStart([char]0xFEFF))
}

function Get-ReleaseNotesJsonAt {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$Commit, [Parameter(Mandatory)][string]$Path)
    $text = Get-ReleaseNotesFileAt -RepoRoot $RepoRoot -Commit $Commit -Path $Path
    if (-not $text) { return $null }
    try { return ($text | ConvertFrom-Json) } catch { return $null }
}

# Several files in one git process (git cat-file --batch): spec '<commit>:<path>' -> text, $null when
# the commit carries no such file. A walk over the history of one file costs two git calls this way.
function Get-ReleaseNotesFileBatch {
    param([Parameter(Mandatory)][string]$RepoRoot, [string[]]$Spec)
    $map = @{}
    $Spec = @($Spec | Where-Object { $_ })
    if ($Spec.Count -eq 0) { return $map }
    $old = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $out = @($Spec | & git -C $RepoRoot cat-file --batch 2>$null | ForEach-Object { "$_" })
    } finally { [Console]::OutputEncoding = $old }
    $i = 0
    foreach ($s in $Spec) {
        if ($i -ge $out.Count) { $map[$s] = $null; continue }
        $header = $out[$i]; $i++
        if ($header -notmatch '^[0-9a-f]{40,64} blob [0-9]+$') { $map[$s] = $null; continue }
        $buf = [System.Collections.Generic.List[string]]::new()
        while ($i -lt $out.Count -and $out[$i] -notmatch '^[0-9a-f]{40,64} [a-z]+ [0-9]+$' -and $out[$i] -notmatch ' missing$') { $buf.Add($out[$i]); $i++ }
        $map[$s] = (($buf -join "`n").TrimStart([char]0xFEFF))
    }
    return $map
}

function ConvertFrom-ReleaseNotesJson([string]$Text) {
    if (-not $Text) { return $null }
    try { return ($Text | ConvertFrom-Json) } catch { return $null }
}

function Resolve-ReleaseNotesCommit {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$Rev)
    $r = Invoke-ReleaseNotesGit -RepoRoot $RepoRoot -ArgumentList @('rev-parse', '--quiet', '--verify', "$Rev^{commit}")
    if ($null -eq $r -or @($r).Count -eq 0) { return $null }
    return "$(@($r)[0])".Trim()
}

function Get-BacpacLineEntry {
    param($Index, [Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind, [string]$Edition)
    if (-not $Index -or -not $Index.PSObject.Properties['bacpacs'] -or -not $Index.bacpacs) { return $null }
    $bp = $Index.bacpacs
    if ($Kind -eq 'blank') { if ($bp.PSObject.Properties['blank']) { return $bp.blank } else { return $null } }
    if (-not $bp.PSObject.Properties['editions'] -or -not $bp.editions -or -not $bp.editions.PSObject.Properties[$Edition]) { return $null }
    return $bp.editions.$Edition
}

# ---------------------------------------------------------------------------
# Find-PreviousBacpacRelease: the release the line's register entry named before -Tag replaced it.
# Walks the first-parent history of layers/INDEX.json from -Start; $null when the line has no
# earlier release. Returns { tag; entry; registeredAt }.
# ---------------------------------------------------------------------------
function Find-PreviousBacpacRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind,
        [string]$Edition,
        [Parameter(Mandatory)][string]$Tag,
        [string]$Start = 'HEAD'
    )
    if ($Kind -eq 'edition' -and -not $Edition) { throw 'Find-PreviousBacpacRelease: -Edition is required for an edition line.' }
    # A shallow checkout has no history to read: it would call every release the first of its line.
    $shallow = Invoke-ReleaseNotesGit -RepoRoot $RepoRoot -ArgumentList @('rev-parse', '--is-shallow-repository')
    if ($null -eq $shallow) { throw "Find-PreviousBacpacRelease: $RepoRoot is not a git checkout." }
    if ("$(@($shallow)[0])".Trim() -eq 'true') { throw "Find-PreviousBacpacRelease: $RepoRoot is a shallow checkout; the previous release is read from the history of layers/INDEX.json (fetch-depth 0)." }
    $commits = Invoke-ReleaseNotesGit -RepoRoot $RepoRoot -ArgumentList @('log', '--first-parent', '--format=%H', $Start, '--', 'layers/INDEX.json')
    if ($null -eq $commits) { throw "Find-PreviousBacpacRelease: git log on layers/INDEX.json from '$Start' failed in $RepoRoot (a shallow or missing checkout cannot name the previous release)." }
    $pattern = Get-ReleaseNotesLinePattern -Kind $Kind -Edition $Edition
    $files = Get-ReleaseNotesFileBatch -RepoRoot $RepoRoot -Spec @(@($commits) | ForEach-Object { "${_}:layers/INDEX.json" })
    foreach ($c in @($commits)) {
        $text = $files["${c}:layers/INDEX.json"]
        if (-not $text -or $text.IndexOf('"bacpacs"') -lt 0) { continue }
        $ix = $null
        try { $ix = $text | ConvertFrom-Json } catch { continue }
        $e = Get-BacpacLineEntry -Index $ix -Kind $Kind -Edition $Edition
        if (-not $e) { continue }
        $t = "$($e.tag)"
        if ($t -and $t -ne $Tag -and $t -match $pattern) { return [pscustomobject]@{ tag = $t; entry = $e; registeredAt = "$c" } }
    }
    return $null
}

# ---------------------------------------------------------------------------
# New-ReleaseNotesRecord: the `releaseNotes` record of a bacpac entry about to be registered. The
# Foundry calls this against the Distribution checkout it writes the entry into.
# ---------------------------------------------------------------------------
function New-ReleaseNotesRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind,
        [string]$Edition,
        [Parameter(Mandatory)][string]$Tag,
        [string]$Start = 'HEAD'
    )
    $prev = Find-PreviousBacpacRelease -RepoRoot $RepoRoot -Kind $Kind -Edition $Edition -Tag $Tag -Start $Start
    return [ordered]@{ schema = (Get-ReleaseNotesSchemaName); previousTag = $(if ($prev) { $prev.tag } else { $null }) }
}

# The commit a release's records are read at.
function Resolve-ReleaseRecordsCommit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind,
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)][string]$Fallback
    )
    if ($Kind -eq 'edition' -and "$($Entry.distributionCommit)" -match '^[0-9a-f]{40}$') {
        $c = Resolve-ReleaseNotesCommit -RepoRoot $RepoRoot -Rev "$($Entry.distributionCommit)"
        if ($c) { return $c }
    }
    $c = Resolve-ReleaseNotesCommit -RepoRoot $RepoRoot -Rev "refs/tags/$($Entry.tag)"
    if ($c) { return $c }
    $c = Resolve-ReleaseNotesCommit -RepoRoot $RepoRoot -Rev $Fallback
    if (-not $c) { throw "Resolve-ReleaseRecordsCommit: neither $($Entry.tag) nor '$Fallback' resolves to a commit in $RepoRoot." }
    return $c
}

# The layers an edition file composes, as an ordered name -> version map: the pins of from, add and
# surfaces; the theme layers and the sample-data layer by their layer.json version at that commit.
function Get-EditionLayerPin {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$Commit, [Parameter(Mandatory)][string]$Edition, $Spec)
    $spec = if ($Spec) { $Spec } else { Get-ReleaseNotesJsonAt -RepoRoot $RepoRoot -Commit $Commit -Path "editions/$Edition.json" }
    if (-not $spec) { return $null }
    $pins = [ordered]@{}
    $refs = @()
    foreach ($k in 'from', 'add', 'surfaces') { if ($spec.PSObject.Properties[$k]) { $refs += @($spec.$k) } }
    foreach ($r in $refs) { if ($r -and "$r" -match '^(?<n>[a-z0-9-]+)@(?<v>\S+)$') { $pins[$Matches['n']] = $Matches['v'] } }
    $unpinned = @()
    if ($spec.PSObject.Properties['themes']) { foreach ($t in @($spec.themes)) { if ($t) { $unpinned += "theme-$t" } } }
    if ($spec.PSObject.Properties['sampleData'] -and $spec.sampleData) { $unpinned += 'sample-data' }
    $manifests = Get-ReleaseNotesFileBatch -RepoRoot $RepoRoot -Spec @($unpinned | ForEach-Object { "${Commit}:layers/$_/layer.json" })
    foreach ($n in $unpinned) {
        $lj = ConvertFrom-ReleaseNotesJson $manifests["${Commit}:layers/$n/layer.json"]
        $pins[$n] = if ($lj -and "$($lj.version)") { "$($lj.version)" } else { 'unknown' }
    }
    return $pins
}

# What the repository records at one commit for a release line.
function Get-ReleaseRecordSnapshot {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind,
        [string]$Edition
    )
    $specs = @("${Commit}:layers/INDEX.json", "${Commit}:versions/spine.json")
    if ($Kind -eq 'edition') { $specs += "${Commit}:editions/$Edition.json" }
    $files = Get-ReleaseNotesFileBatch -RepoRoot $RepoRoot -Spec $specs
    $ix = ConvertFrom-ReleaseNotesJson $files["${Commit}:layers/INDEX.json"]
    $gp = if ($ix -and $ix.PSObject.Properties['gateProven']) { $ix.gateProven } else { $null }
    $swift = ''
    $provenHost = ''
    if ($gp) {
        $swift = "$($gp.swiftVersion)".Trim()
        if (-not $swift -and $gp.PSObject.Properties['swift'] -and $gp.swift) { $swift = ("$($gp.swift.tag)".Trim() -replace '^v', '') }
        if ($Kind -eq 'edition' -and $gp.PSObject.Properties['releases'] -and $gp.releases -and $gp.releases.PSObject.Properties[$Edition]) { $provenHost = "$($gp.releases.$Edition.host)" }
    }
    $components = [ordered]@{}
    $spine = ConvertFrom-ReleaseNotesJson $files["${Commit}:versions/spine.json"]
    if ($spine -and $spine.PSObject.Properties['components'] -and $spine.components) {
        foreach ($p in @($spine.components.PSObject.Properties)) {
            $v = if ($p.Value.PSObject.Properties['current'] -and $p.Value.current) { "$($p.Value.current.version)" } else { '' }
            if ($v) { $components[$p.Name] = $v }
        }
    }
    $layers = $null
    if ($Kind -eq 'edition') {
        $edSpec = ConvertFrom-ReleaseNotesJson $files["${Commit}:editions/$Edition.json"]
        if ($edSpec) { $layers = Get-EditionLayerPin -RepoRoot $RepoRoot -Commit $Commit -Edition $Edition -Spec $edSpec }
    }
    return [pscustomobject]@{ commit = $Commit; swift = $swift; components = $components; layers = $layers; provenHost = $provenHost }
}

# ---------------------------------------------------------------------------
# Get-LayerChangelogEntry: the `## <version>` entries of a CHANGELOG.md above -From up to -To.
# Pure. Returns rows { version; heading; body; summary } newest first, as the file orders them.
# ---------------------------------------------------------------------------
function Get-LayerChangelogEntry {
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string]$Text, [AllowNull()][AllowEmptyString()][string]$From, [Parameter(Mandatory)][string]$To)
    if (-not $Text) { return @() }
    $entries = [System.Collections.Generic.List[object]]::new()
    $cur = $null
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -match '^##\s+\[?v?(?<v>[0-9]+\.[0-9]+\.[0-9]+[0-9A-Za-z.+-]*)\]?') {
            $cur = [pscustomobject]@{ version = $Matches['v']; heading = ($line -replace '^##\s+', '').Trim(); lines = [System.Collections.Generic.List[string]]::new() }
            $entries.Add($cur); continue
        }
        if ($line -match '^#\s') { $cur = $null; continue }
        if ($cur) { $cur.lines.Add($line) }
    }
    $out = @()
    foreach ($e in $entries) {
        if ((Compare-SpineVersion -A $e.version -B $To) -gt 0) { continue }
        if ($From -and (Compare-SpineVersion -A $e.version -B $From) -le 0) { continue }
        $body = (($e.lines -join "`n").Trim())
        $first = @($body -split "(`n\s*){2,}" | Where-Object { "$_".Trim() }) | Select-Object -First 1
        $summary = ((("$first" -replace '(?m)^#+\s*', '') -replace '\s+', ' ').Trim())
        if ($summary.Length -gt 320) { $summary = $summary.Substring(0, 317).TrimEnd() + '...' }
        $out += [pscustomobject]@{ version = $e.version; heading = $e.heading; body = $body; summary = $summary }
    }
    return @($out)
}

# The merged pull requests on the first-parent line between two commits, newest first.
function Get-ReleaseNotesPullRequest {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$From, [Parameter(Mandatory)][string]$To)
    $raw = Invoke-ReleaseNotesGit -RepoRoot $RepoRoot -ArgumentList @('log', '--first-parent', '--format=%H%x1f%s%x1f%b%x1e', "$From..$To")
    if ($null -eq $raw) { return @() }
    $out = @(); $seen = @{}
    foreach ($rec in ((@($raw) -join "`n") -split [char]0x1e)) {
        $f = $rec.Trim("`n", "`r", ' ') -split [char]0x1f
        if ($f.Count -lt 2 -or -not $f[0]) { continue }
        $subject = "$($f[1])"; $bodyText = if ($f.Count -gt 2) { "$($f[2])" } else { '' }
        $n = 0; $title = ''
        if ($subject -match '^Merge pull request #(?<n>[0-9]+)\b') {
            $n = [int]$Matches['n']
            $title = "$(@($bodyText -split "`r?`n" | Where-Object { "$_".Trim() }) | Select-Object -First 1)".Trim()
            if (-not $title) { $title = $subject }
        } elseif ($subject -match '^(?<t>.+?)\s*\(#(?<n>[0-9]+)\)$') {
            $n = [int]$Matches['n']; $title = $Matches['t'].Trim()
        } else { continue }
        if ($seen.ContainsKey($n)) { continue }
        $seen[$n] = $true
        $out += [pscustomobject]@{ number = $n; title = $title; mergeCommit = "$($f[0])" }
    }
    return @($out)
}

function Get-ReleaseNotesDelta {
    param([AllowNull()][AllowEmptyString()][string]$From, [AllowNull()][AllowEmptyString()][string]$To)
    $f = if ($From) { $From } else { $null }
    $t = if ($To) { $To } else { $null }
    return [ordered]@{ from = $f; to = $t; changed = [bool]($f -and $t -and $f -ne $t) }
}

function Get-ReleaseNotesMajor([string]$Version) {
    $n = 0
    [void][int]::TryParse((("$Version".TrimStart('vV')) -split '[.+-]')[0], [ref]$n)
    return $n
}

# ---------------------------------------------------------------------------
# New-BacpacReleaseNotes: the notes of one bacpac release. -Entry is the register entry (so the
# Foundry can ask before the entry is committed); everything else is read from git.
# Returns { Tag; PreviousTag; Document; Json; Markdown }. Throws when the JSON does not validate
# against layers/release-notes.schema.json or the entry's record names another previous release.
# ---------------------------------------------------------------------------
function New-BacpacReleaseNotes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][ValidateSet('blank', 'edition')][string]$Kind,
        [string]$Edition,
        [Parameter(Mandatory)]$Entry,
        [string]$Head = 'HEAD',
        [string]$Repo = 'justdynamics/Truvio.Commerce.Distribution',
        [string]$Lead
    )
    if ($Kind -eq 'edition' -and -not $Edition) { throw 'New-BacpacReleaseNotes: -Edition is required for an edition release.' }
    $tag = "$($Entry.tag)"
    if ($tag -notmatch (Get-ReleaseNotesLinePattern -Kind $Kind -Edition $Edition)) { throw "New-BacpacReleaseNotes: '$tag' is not a tag of the $Kind line$(if ($Edition) { " $Edition" })." }
    $version = if ($Kind -eq 'blank') { "$($Entry.dwVersion)" } else { "$($Entry.editionVersion)" }
    $title = if ($Kind -eq 'blank') { "Blank DW10 database, DW $version" } else { "$Edition $version database" }

    $prev = Find-PreviousBacpacRelease -RepoRoot $RepoRoot -Kind $Kind -Edition $Edition -Tag $tag -Start $Head
    $prevTag = if ($prev) { "$($prev.tag)" } else { $null }
    $rec = if ($Entry -is [System.Collections.IDictionary]) { if ($Entry.Contains('releaseNotes')) { $Entry['releaseNotes'] } else { $null } }
           elseif ($Entry.PSObject.Properties['releaseNotes']) { $Entry.releaseNotes } else { $null }
    if ($rec) {
        $recPrev = if ($rec -is [System.Collections.IDictionary]) { $rec['previousTag'] } else { $rec.previousTag }
        if ("$recPrev" -ne "$prevTag") {
            throw "release notes for ${tag}: the entry's releaseNotes.previousTag is '$(if ($null -eq $recPrev) { 'null' } else { $recPrev })' but the history of layers/INDEX.json names '$(if ($null -eq $prevTag) { 'no previous release' } else { $prevTag })'. Register the entry again (New-ReleaseNotesRecord)."
        }
    }

    $toCommit = Resolve-ReleaseRecordsCommit -RepoRoot $RepoRoot -Kind $Kind -Entry $Entry -Fallback $Head
    $to = Get-ReleaseRecordSnapshot -RepoRoot $RepoRoot -Commit $toCommit -Kind $Kind -Edition $Edition
    $from = $null; $fromCommit = $null; $prevVersion = $null
    if ($prev) {
        $fromCommit = Resolve-ReleaseRecordsCommit -RepoRoot $RepoRoot -Kind $Kind -Entry $prev.entry -Fallback $prev.registeredAt
        $from = Get-ReleaseRecordSnapshot -RepoRoot $RepoRoot -Commit $fromCommit -Kind $Kind -Edition $Edition
        $prevVersion = if ($Kind -eq 'blank') { "$($prev.entry.dwVersion)" } else { "$($prev.entry.editionVersion)" }
    }

    $dw = Get-ReleaseNotesDelta -From $(if ($prev) { "$($prev.entry.dwVersion)" }) -To "$($Entry.dwVersion)"
    $swift = Get-ReleaseNotesDelta -From $(if ($from) { $from.swift }) -To $to.swift

    # Layers: the union of both sides, in the new edition's order, removed layers last.
    $layers = @()
    if ($Kind -eq 'edition') {
        $toPins = if ($to.layers) { $to.layers } else { [ordered]@{} }
        $fromPins = if ($from -and $from.layers) { $from.layers } else { [ordered]@{} }
        $names = @($toPins.Keys) + @($fromPins.Keys | Where-Object { -not $toPins.Contains($_) })
        $moved = @($names | Where-Object { $prev -and $fromPins.Contains($_) -and $toPins.Contains($_) -and "$($fromPins[$_])" -ne "$($toPins[$_])" })
        $logs = Get-ReleaseNotesFileBatch -RepoRoot $RepoRoot -Spec @($moved | ForEach-Object { "${toCommit}:layers/$_/CHANGELOG.md" })
        foreach ($n in $names) {
            $a = if ($fromPins.Contains($n)) { "$($fromPins[$n])" } else { $null }
            $b = if ($toPins.Contains($n)) { "$($toPins[$n])" } else { $null }
            $change = if (-not $prev) { 'first' } elseif (-not $a) { 'added' } elseif (-not $b) { 'removed' } elseif ($a -ne $b) { 'changed' } else { 'unchanged' }
            $log = @()
            if ($change -eq 'changed') {
                $text = $logs["${toCommit}:layers/$n/CHANGELOG.md"]
                $log = @(Get-LayerChangelogEntry -Text $text -From $a -To $b)
            }
            $layers += [ordered]@{
                name = $n; from = $a; to = $b; change = $change
                changelog = @($log | ForEach-Object { [ordered]@{ version = $_.version; heading = $_.heading; summary = $_.summary; body = $_.body } })
            }
        }
    }

    $components = @()
    $toC = $to.components
    $fromC = if ($from) { $from.components } else { [ordered]@{} }
    foreach ($id in (@($toC.Keys) + @($fromC.Keys | Where-Object { -not $toC.Contains($_) }))) {
        if ($id -in 'dw', 'swift') { continue }   # stated in `dw` and `swift`, from the entry and gateProven
        $a = if ($fromC.Contains($id)) { "$($fromC[$id])" } else { $null }
        $b = if ($toC.Contains($id)) { "$($toC[$id])" } else { $null }
        $change = if (-not $prev) { 'first' } elseif (-not $a) { 'added' } elseif (-not $b) { 'removed' } elseif ($a -ne $b) { 'changed' } else { 'unchanged' }
        $components += [ordered]@{ id = $id; from = $a; to = $b; change = $change }
    }

    $prs = @()
    if ($prev) { $prs = @(Get-ReleaseNotesPullRequest -RepoRoot $RepoRoot -From $fromCommit -To $toCommit | ForEach-Object { [ordered]@{ number = $_.number; title = $_.title; mergeCommit = $_.mergeCommit } }) }

    # What a consumer must do: derived from the deltas, never free text.
    $actions = [System.Collections.Generic.List[string]]::new()
    $actions.Add("Check the sha256 of $($Entry.asset) ($($Entry.sha256)) and restore it onto a NEW database. A bacpac replaces a database, it does not upgrade one: nothing written to a database restored from an earlier release is carried over.")
    if (-not $prev) { $actions.Add('First release of this line: there is no earlier release to move from.') }
    if ($dw.changed) { $actions.Add("Move the host to DW $($dw.to) before pointing it at this database (the previous release was DW $($dw.from)).") }
    elseif ($prev) { $actions.Add("No DW platform change: this release and the previous one are both DW $($dw.to).") }
    if ($Kind -eq 'edition') {
        if ($swift.changed) { $actions.Add("Replace the host's Swift release Files with Swift $($swift.to) (the previous release was proven on Swift $($swift.from)).") }
        $actions.Add("Take the layer files from Distribution commit $toCommit ($(@($layers | Where-Object { $_.change -ne 'removed' }).Count) layers): the bacpac is the database only, the host still needs the Swift release Files and the files the edition's layers deliver.")
        foreach ($l in @($layers | Where-Object { $_.change -eq 'changed' -and (Get-ReleaseNotesMajor $_.to) -gt (Get-ReleaseNotesMajor $_.from) })) {
            $actions.Add("$($l.name) moved a major version ($($l.from) to $($l.to)): read its CHANGELOG before moving a customised host.")
        }
        foreach ($l in @($layers | Where-Object { $_.change -eq 'removed' })) { $actions.Add("$($l.name) is no longer part of the edition: its content and files are not in this release.") }
    }
    $movedComponents = @($components | Where-Object { $_.change -in 'changed', 'added' })
    if ($Kind -eq 'edition' -and $movedComponents.Count -gt 0) {
        $actions.Add("Bring the components the host and its tooling use up to the versions this release was proven with: $(@($movedComponents | ForEach-Object { "$($_.id) $($_.to)$(if ($_.from) { " (was $($_.from))" })" }) -join ', '). Older versions are outside the proof.")
    }
    $actions.Add("Set the Administrator$(if ($Kind -eq 'edition') { ' and persona' }) password$(if ($Kind -eq 'edition') { 's' }) before the first sign-in: the file ships scrubbed, with no password on any user and no API key (CONTRIBUTING.md, 'Bacpac release assets').")

    $prov = [ordered]@{
        asset              = "$($Entry.asset)"
        sha256             = "$($Entry.sha256)"
        sizeBytes          = [long]$Entry.sizeBytes
        dwVersion          = "$($Entry.dwVersion)"
        gateRunId          = "$($Entry.gateRunId)"
        deliveryRunId      = $(if ("$($Entry.deliveryRunId)") { "$($Entry.deliveryRunId)" } else { $null })
        provenRunId        = $(if ($Kind -eq 'edition' -and "$($Entry.provenRunId)") { "$($Entry.provenRunId)" } else { $null })
        distributionCommit = $(if ($Kind -eq 'edition' -and "$($Entry.distributionCommit)") { "$($Entry.distributionCommit)" } else { $null })
        scrubVerdict       = "$($Entry.scrubCheck.verdict)"
        provingHost        = $(if ($Kind -eq 'edition' -and $to.provenHost) { $to.provenHost } else { $null })
        provedWith         = $(if ("$($Entry.provedWith)") { "$($Entry.provedWith)" } else { $null })
        startsFrom         = $(if ("$($Entry.startsFrom)") { "$($Entry.startsFrom)" } else { $null })
    }

    $doc = [ordered]@{
        schema          = (Get-ReleaseNotesSchemaName)
        repository      = $Repo
        tag             = $tag
        kind            = $Kind
        edition         = $(if ($Kind -eq 'edition') { $Edition } else { $null })
        version         = $version
        title           = $title
        firstOfLine     = [bool](-not $prev)
        previous        = $(if ($prev) { [ordered]@{ tag = $prevTag; version = $prevVersion; recordsCommit = $fromCommit } } else { $null })
        recordsCommit   = $toCommit
        dw              = $dw
        swift           = $swift
        layers          = @($layers)
        components      = @($components)
        pullRequests    = @($prs)
        consumerActions = @($actions)
        provenance      = $prov
    }
    $json = $doc | ConvertTo-Json -Depth 12
    $schemaFile = Join-Path (Join-Path $PSScriptRoot '..') (Join-Path '..' (Join-Path 'layers' 'release-notes.schema.json'))
    $ok = $false; $err = ''
    try { $ok = Test-Json -Json $json -SchemaFile $schemaFile -ErrorAction Stop } catch { $ok = $false; $err = $_.Exception.Message }
    if (-not $ok) { throw "release notes for ${tag}: the generated release-notes.json does not validate against layers/release-notes.schema.json: $err" }

    $md = ConvertTo-ReleaseNotesMarkdown -Document $doc -Lead $Lead
    return [pscustomobject]@{ Tag = $tag; PreviousTag = $prevTag; Document = $doc; Json = $json; Markdown = $md }
}

# ---------------------------------------------------------------------------
# ConvertTo-ReleaseNotesMarkdown: the release body. Two sections, fixed order: "What changed" and
# "Provenance". Pure over the document.
# ---------------------------------------------------------------------------
function ConvertTo-ReleaseNotesMarkdown {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Document, [string]$Lead)
    $d = $Document
    $url = "https://github.com/$($d.repository)"
    $short = { param($c) if ($c) { "$c".Substring(0, [Math]::Min(8, "$c".Length)) } else { '' } }
    $cell = { param($v) if ($null -eq $v -or "$v" -eq '') { 'none' } else { "$v" } }
    $md = [System.Collections.Generic.List[string]]::new()
    if ($Lead) { $md.Add($Lead.Trim()); $md.Add('') }
    $md.Add('## What changed'); $md.Add('')
    $what = if ($d.kind -eq 'edition') { 'Edition version' } else { 'Blank database' }
    if ($d.firstOfLine) {
        $md.Add("First release of this line: there is no previous $(if ($d.kind -eq 'edition') { "$($d.edition) database" } else { 'blank database' }) release to compare with. What this release carries:")
        $md.Add('')
        $md.Add('| | This release |'); $md.Add('|---|---|')
        $md.Add("| $what | $($d.version) |")
        $md.Add("| DW version | $(& $cell $d.dw.to) |")
        $md.Add("| Swift release | $(& $cell $d.swift.to) |")
    } else {
        $md.Add("Compared with the previous release of this line, [$($d.previous.tag)]($url/releases/tag/$($d.previous.tag)). Read from the Distribution's records at commit ``$(& $short $d.previous.recordsCommit)`` (previous) and ``$(& $short $d.recordsCommit)`` (this release).")
        $md.Add('')
        $md.Add('| | Previous | This release | |'); $md.Add('|---|---|---|---|')
        $md.Add("| $what | $($d.previous.version) | $($d.version) | changed |")
        $md.Add("| DW version | $(& $cell $d.dw.from) | $(& $cell $d.dw.to) | $(if ($d.dw.changed) { '**changed**' } else { 'unchanged' }) |")
        $md.Add("| Swift release | $(& $cell $d.swift.from) | $(& $cell $d.swift.to) | $(if ($d.swift.changed) { '**changed**' } else { 'unchanged' }) |")
    }
    $md.Add('')

    if ($d.kind -eq 'edition') {
        $md.Add('### Layers'); $md.Add('')
        $rows = @($d.layers)
        if ($d.firstOfLine) {
            $md.Add('| Layer | Version |'); $md.Add('|---|---|')
            foreach ($l in $rows) { $md.Add("| ``$($l.name)`` | $($l.to) |") }
        } else {
            $moved = @($rows | Where-Object { $_.change -ne 'unchanged' })
            if ($moved.Count -eq 0) { $md.Add('No layer pin changed.') }
            else {
                $md.Add('| Layer | Previous | This release | |'); $md.Add('|---|---|---|---|')
                foreach ($l in $moved) { $md.Add("| ``$($l.name)`` | $(& $cell $l.from) | $(& $cell $l.to) | $($l.change) |") }
            }
            $same = @($rows | Where-Object { $_.change -eq 'unchanged' })
            if ($same.Count -gt 0) { $md.Add(''); $md.Add("Unchanged: $(@($same | ForEach-Object { "``$($_.name)`` $($_.to)" }) -join ', ').") }
            $logged = @($rows | Where-Object { @($_.changelog).Count -gt 0 })
            if ($logged.Count -gt 0) {
                $md.Add(''); $md.Add('### Layer changelogs'); $md.Add('')
                $md.Add("The first paragraph of each entry between the two versions; the full entries are in ``release-notes.json`` and in the layer's ``CHANGELOG.md``.")
                $md.Add('')
                foreach ($l in $logged) {
                    $md.Add("**$($l.name)** $($l.from) to $($l.to)")
                    foreach ($c in @($l.changelog)) { $md.Add("- $($c.heading): $($c.summary)") }
                    $md.Add('')
                }
                if ($md[$md.Count - 1] -eq '') { $md.RemoveAt($md.Count - 1) }
            }
        }
        $md.Add('')
    }

    $md.Add('### Components'); $md.Add('')
    $comps = @($d.components)
    if ($comps.Count -eq 0) { $md.Add('The Distribution recorded no version spine at these commits.') }
    elseif ($d.firstOfLine) {
        $md.Add("Proven with (``versions/spine.json`` ``current``): $(@($comps | ForEach-Object { "$($_.id) $($_.to)" }) -join ', ').")
    } else {
        $moved = @($comps | Where-Object { $_.change -ne 'unchanged' })
        if ($moved.Count -eq 0) { $md.Add('No proven component version changed (`versions/spine.json` `current`).') }
        else {
            $md.Add('| Component (`versions/spine.json` `current`) | Previous | This release | |'); $md.Add('|---|---|---|---|')
            foreach ($c in $moved) { $md.Add("| $($c.id) | $(& $cell $c.from) | $(& $cell $c.to) | $($c.change) |") }
        }
        $same = @($comps | Where-Object { $_.change -eq 'unchanged' })
        if ($same.Count -gt 0) { $md.Add(''); $md.Add("Unchanged: $(@($same | ForEach-Object { "$($_.id) $($_.to)" }) -join ', ').") }
    }
    $md.Add('')

    if (-not $d.firstOfLine) {
        $prs = @($d.pullRequests)
        $md.Add("### Merged pull requests ($($prs.Count))"); $md.Add('')
        if ($prs.Count -eq 0) { $md.Add('None between the two commits.') }
        else {
            $shown = @($prs | Select-Object -First 40)
            foreach ($p in $shown) { $md.Add("- [#$($p.number)]($url/pull/$($p.number)) $($p.title)") }
            if ($prs.Count -gt $shown.Count) { $md.Add("- and $($prs.Count - $shown.Count) more, listed in ``release-notes.json``") }
        }
        $md.Add('')
    }

    $md.Add('### What a consumer must do'); $md.Add('')
    $i = 0
    foreach ($a in @($d.consumerActions)) { $i++; $md.Add("$i. $a") }
    $md.Add('')

    $md.Add('## Provenance'); $md.Add('')
    $p = $d.provenance
    $md.Add('| | |'); $md.Add('|---|---|')
    $md.Add("| Asset | ``$($p.asset)`` ($($p.sizeBytes) bytes) |")
    $md.Add("| sha256 | ``$($p.sha256)`` |")
    $md.Add("| DW version | $($p.dwVersion) |")
    $md.Add("| Gate run on the restored file | $($p.gateRunId) |")
    if ($p.deliveryRunId) { $md.Add("| Delivery run | $($p.deliveryRunId) |") }
    if ($p.provenRunId) { $md.Add("| Edition proof run (gateProven) | $($p.provenRunId)$(if ($p.provingHost) { " on $($p.provingHost)" }) |") }
    if ($p.distributionCommit) { $md.Add("| Distribution commit | [``$(& $short $p.distributionCommit)``]($url/commit/$($p.distributionCommit)) |") }
    if ($p.startsFrom) { $md.Add("| Starts from | $($p.startsFrom) |") }
    if ($p.provedWith) { $md.Add("| Proved with | $($p.provedWith) |") }
    $md.Add("| Scrub check | $($p.scrubVerdict) |")
    $md.Add('')
    $md.Add("Machine-readable: the ``release-notes.json`` asset of this release (schema ``$($d.schema)``, [layers/release-notes.schema.json]($url/blob/main/layers/release-notes.schema.json)).")
    return (($md -join "`n").TrimEnd() + "`n")
}
