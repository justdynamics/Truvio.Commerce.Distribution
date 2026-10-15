<#
.SYNOPSIS
gateProven as a projection of the editions record (owner ruling std-q31-gateproven-from-record, 2026-10-15).

.DESCRIPTION
The Truvio editions are the increments of one solution, truvio-editions, kept by the Workbench console
`solution` (DEMO-TO-DELIVERY-STANDARD section 2a, phase 2). An edition is proven when its record carries a
`proven` line for a release (or, for a proof made before the record, a `legacy-proof` line; ruling
std-q32-headless-stamp-legacy-proof). `solution status truvio-editions --json` lists per increment
`releases: [{ tag, built, proven: { ts, runId, host, resultsDigest } | null, confirmed, legacy }]`.

`legacy` is the legacy-proof line `{ts, runId, host}` or null; `proven` falls back to that line, so a release
is legacy when `legacy` is set and carries the run of `proven`.

The Foundry writer (tools/harness/Write-IndexGateProven.ps1) commits ConvertTo-EditionsRecordExtract of that
status (only what the projection reads, so the file changes when a release line changes and never with the
day) beside INDEX.json as layers/editions-record.json, and projects it into gateProven with
ConvertTo-GateProvenProjection below. CI (check 14 of Validate-Distribution.ps1) requires the file whenever
gateProven names editions, checks that it is an extract, projects it again and compares. One function, both
sides, so the writer and the check cannot disagree.

The projection is three keys of gateProven:
  editions  { <edition>: <runId> }   the run of the newest proven (else legacy) release; the map every
                                     reader of gateProven keeps reading (print-release-tags, Bacpac.ps1)
  releases  { <edition>: { tag, runId, host, ts, resultsDigest, legacy } }
  date      yyyy-MM-dd (UTC) of the newest of those lines
The other keys of gateProven (dw, apps, swift, skills, proofs) are observations of the proving host and the
delivered tree, written beside the projection; they are not on the record and this check does not read them.

Functions only.
#>

$script:GateProvenRunIdPattern = '^[0-9]{8}-[0-9]{6}$'

# The deterministic part of `solution status truvio-editions --json`: per increment (by id) its release lines
# as the console lists them, without state, dwell or counters.
function ConvertTo-EditionsRecordExtract {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Status)
    $line = { param($l, [string[]]$Keys) if ($null -eq $l) { return $null }; $o = [ordered]@{}; foreach ($k in $Keys) { $o[$k] = $(if ($null -ne $l.$k) { $l.$k } else { $null }) }; $o }
    $incs = foreach ($inc in @($Status.increments | Where-Object { $_ } | Sort-Object { "$($_.id)" })) {
        [ordered]@{ id = "$($inc.id)"; releases = @(foreach ($r in @($inc.releases | Where-Object { $_ })) {
            [ordered]@{ tag = "$($r.tag)"
                        proven = (& $line $r.proven @('ts', 'runId', 'host', 'resultsDigest'))
                        legacy = (& $line $r.legacy @('ts', 'runId', 'host'))
                        confirmed = $(if ($null -ne $r.confirmed) { $r.confirmed } else { $null }) } }) }
    }
    return [ordered]@{ slug = "$($Status.slug)"; increments = @($incs) }
}

function ConvertTo-GateProvenProjection {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Status)
    $editions = [ordered]@{}
    $releases = [ordered]@{}
    $newest = $null
    foreach ($inc in @($Status.increments | Where-Object { $_ } | Sort-Object { "$($_.id)" })) {
        $best = $null; $bestAt = $null
        foreach ($r in @($inc.releases | Where-Object { $_ })) {
            $p = $r.proven
            if (-not $p -or "$($p.runId)" -notmatch $script:GateProvenRunIdPattern) { continue }
            $at = ConvertTo-GateProvenInstant $p.ts
            # The newest proven line wins; on equal times the later release in the record does.
            if ($null -eq $bestAt -or $at -ge $bestAt) {
                $bestAt = $at
                $best = [ordered]@{ tag = "$($r.tag)"; runId = "$($p.runId)"; host = $(if ($p.host) { "$($p.host)" } else { $null })
                                    ts = $at.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ'); resultsDigest = $(if ($p.resultsDigest) { "$($p.resultsDigest)" } else { $null })
                                    legacy = [bool]($r.legacy -and "$($r.legacy.runId)" -eq "$($p.runId)") }
            }
        }
        if (-not $best) { continue }
        $editions["$($inc.id)"] = $best.runId
        $releases["$($inc.id)"] = $best
        if ($null -eq $newest -or $bestAt -gt $newest) { $newest = $bestAt }
    }
    return [ordered]@{
        date     = $(if ($newest) { $newest.UtcDateTime.ToString('yyyy-MM-dd') } else { $null })
        editions = $editions
        releases = $releases
    }
}

# Problems (strings) between INDEX.json gateProven and the projection of the record; empty means equal.
function Test-GateProvenProjection {
    [CmdletBinding()]
    param($GateProven, $Status)
    $problems = @()
    if ($null -eq $Status -or $null -eq $Status.increments) { return @('the editions record is missing or carries no increments') }
    if ((ConvertTo-GateProvenCanonical (ConvertTo-EditionsRecordExtract -Status $Status)) -ne (ConvertTo-GateProvenCanonical $Status)) {
        $problems += 'layers/editions-record.json is not an extract of the record (ConvertTo-EditionsRecordExtract): it carries keys the projection does not read, or lacks some'
    }
    $want = ConvertTo-GateProvenProjection -Status $Status
    if ($want.editions.Count -eq 0) { $problems += 'the editions record carries no proven or legacy-proof release: nothing is proven' }
    if ("$($GateProven.date)" -ne "$($want.date)") { $problems += "date '$($GateProven.date)' is not the projection's '$($want.date)'" }
    foreach ($key in 'editions', 'releases') {
        $have = ConvertTo-GateProvenCanonical $GateProven.$key
        $need = ConvertTo-GateProvenCanonical $want[$key]
        if ($have -ne $need) { $problems += "$key is not the projection of the record: INDEX.json has $have, the record gives $need" }
    }
    return $problems
}

# A record or index timestamp as a DateTimeOffset. ConvertFrom-Json turns ISO strings into DateTime, so
# both shapes arrive here; a string without an offset is read as UTC.
function ConvertTo-GateProvenInstant {
    param($Value)
    if ($Value -is [datetimeoffset]) { return $Value }
    if ($Value -is [datetime]) { return [datetimeoffset]$(if ($Value.Kind -eq 'Unspecified') { [datetime]::SpecifyKind($Value, 'Utc') } else { $Value }) }
    return [datetimeoffset]::Parse("$Value", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
}

# Compact JSON with keys sorted at every level, so key order never reads as a difference. Timestamps are
# compared as UTC instants, whichever shape the JSON reader gave them.
function ConvertTo-GateProvenCanonical {
    param($Node)
    if ($null -eq $Node) { return 'null' }
    if ($Node -is [datetime] -or $Node -is [datetimeoffset]) { return ((ConvertTo-GateProvenInstant $Node).UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ssZ') | ConvertTo-Json -Compress) }
    if ($Node -is [string]) { return ($Node | ConvertTo-Json -Compress) }
    if ($Node -is [bool] -or $Node -is [ValueType]) { return ($Node | ConvertTo-Json -Compress) }
    if ($Node -is [System.Collections.IDictionary]) { $names = @($Node.Keys | ForEach-Object { "$_" }); $get = { param($n) $Node[$n] } }
    elseif ($Node -is [pscustomobject]) { $names = @($Node.PSObject.Properties.Name); $get = { param($n) $Node.$n } }
    else { return '[' + (@($Node | ForEach-Object { ConvertTo-GateProvenCanonical $_ }) -join ',') + ']' }
    $parts = foreach ($n in @($names | Sort-Object -Culture '' -CaseSensitive)) { ($n | ConvertTo-Json -Compress) + ':' + (ConvertTo-GateProvenCanonical (& $get $n)) }
    return '{' + (@($parts) -join ',') + '}'
}
