<#
.SYNOPSIS
Version spine checks (redesign plan 4D; owner ruling redesign-floors, 2026-09-23): versions/spine.json
is the one record of every outward component's proven `current`, its per-consumer `floors` and its
package `ids`. FUNCTIONS ONLY, dot-sourced by Validate-Distribution.ps1 and by the Pester tests
(tools/ci/tests/VersionSpine.Tests.ps1), the same shape as Test-ProtectedStrings.ps1.

Checks (each returns rows @{ ok; msg }; the caller logs them fail-closed):
  S1 shape       - the spine parses; every component carries ids.package, current and floors[];
                   no id or alias is claimed by two components.
  S2 reasons     - every floor names its consumer once per component, a min, and a reason whose
                   ref is '<owner>/<repo>#<n>' (issue/PR) or '<owner>/<repo>@<sha>' (commit) plus a why.
  S3 floor<=cur  - no floor exceeds its component's current: a floor above the proven version is a
                   claim nobody measured. A ring floor may not name a NEWER ring than current.
  S4 cur<=proven - a `current` sourced from gateProven never runs ahead of layers/INDEX.json
                   gateProven. Running behind is reported, not failed (a lag is not a defect).
  S5 contract    - layers/base/base.contract.json compat equals the spine floors of consumer
                   `layers`. The spine is the source; the contract is the copy.
  S6 floor rule  - against the merge base: a raised floor (min up, or ring newer) must carry a
                   reason.ref that differs from the base's, or CI fails "floor raised without a
                   consumer reason". A floor rises only when a consumer depends on the fix.

Version order: SemVer 2.0 with NuGet's prerelease reading (Compare-SpineVersion).
#>

# ---------------------------------------------------------------------------
# Compare-SpineVersion: -1 / 0 / 1. SemVer 2.0 precedence with the NuGet reading of labels:
#   * numeric core segments compare numerically (any count: 10.28.12.0 is fine; missing = 0);
#   * a prerelease ranks BELOW its release (0.4.4-beta < 0.4.4, 10.28.1-PreRelease < 10.28.1);
#   * prerelease labels split on '.', numeric identifiers compare numerically (beta.10 > beta.9),
#     a numeric identifier ranks below an alphanumeric one, alphanumerics compare
#     case-INSENSITIVELY (0.6.0-BETA == 0.6.0-beta, as NuGet treats package versions), and a
#     shorter label that is a prefix of a longer one ranks lower (beta < beta.1);
#   * build metadata (+...) and a leading v are ignored.
# ---------------------------------------------------------------------------
function Compare-SpineVersion {
    param([Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$A,
          [Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$B)

    function Split-SpineVer([string]$v) {
        $v = "$v".Trim().TrimStart('vV')
        $v = ($v -split '\+', 2)[0]
        $core, $pre = ($v -split '-', 2)
        $nums = @(("$core" -split '\.') | ForEach-Object { [long]$n = 0; [void][long]::TryParse($_, [ref]$n); $n })
        return @{ nums = $nums; pre = "$pre" }
    }
    $x = Split-SpineVer $A
    $y = Split-SpineVer $B
    $len = [Math]::Max($x.nums.Count, $y.nums.Count)
    for ($i = 0; $i -lt $len; $i++) {
        # NB: never $a / $b here - PowerShell names are case-insensitive, so they would be the
        # [string]-typed parameters $A / $B and turn this into a string compare ('8' > '28').
        [long]$sa = if ($i -lt $x.nums.Count) { $x.nums[$i] } else { 0 }
        [long]$sb = if ($i -lt $y.nums.Count) { $y.nums[$i] } else { 0 }
        if ($sa -ne $sb) { return $(if ($sa -gt $sb) { 1 } else { -1 }) }
    }
    $xp = "$($x.pre)"; $yp = "$($y.pre)"
    if ([string]::IsNullOrEmpty($xp) -and [string]::IsNullOrEmpty($yp)) { return 0 }
    if ([string]::IsNullOrEmpty($xp)) { return 1 }
    if ([string]::IsNullOrEmpty($yp)) { return -1 }
    $xi = $xp -split '\.'; $yi = $yp -split '\.'
    $n = [Math]::Min($xi.Count, $yi.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $p = $xi[$i]; $q = $yi[$i]
        $pn = $p -match '^[0-9]+$'; $qn = $q -match '^[0-9]+$'
        if ($pn -and $qn) {
            $c = ([System.Numerics.BigInteger]::Parse($p)).CompareTo([System.Numerics.BigInteger]::Parse($q))
            if ($c -ne 0) { return [Math]::Sign($c) }
            continue
        }
        if ($pn) { return -1 }
        if ($qn) { return 1 }
        $c = [string]::Compare($p, $q, [System.StringComparison]::OrdinalIgnoreCase)
        if ($c -ne 0) { return [Math]::Sign($c) }
    }
    if ($xi.Count -eq $yi.Count) { return 0 }
    return $(if ($xi.Count -gt $yi.Count) { 1 } else { -1 })
}

# Ring number out of 'R1', 'R1-NET10', 'r2'. $null when not a ring. A LOWER number is a NEWER
# milestone (R0 newest), so a ring floor "rises" when its number falls.
function Get-SpineRingNumber {
    param([AllowNull()][string]$Ring)
    if ("$Ring".Trim() -match '^[Rr]([0-4])(-[A-Za-z0-9]+)?$') { return [int]$Matches[1] }
    return $null
}

# Every id a component answers to (package + aliases), for resolving an observed or declared id.
function Get-SpineIds {
    param([Parameter(Mandatory)][object]$Component)
    $ids = @()
    if ($Component.ids) {
        if ("$($Component.ids.package)".Trim()) { $ids += "$($Component.ids.package)".Trim() }
        foreach ($a in @($Component.ids.aliases)) { if ("$a".Trim()) { $ids += "$a".Trim() } }
    }
    return , $ids
}

# Resolve an id (package or alias, case-insensitive) to its component name, or $null.
function Resolve-SpineComponent {
    param([Parameter(Mandatory)][object]$Spine, [Parameter(Mandatory)][string]$Id)
    foreach ($p in $Spine.components.PSObject.Properties) {
        foreach ($i in (Get-SpineIds -Component $p.Value)) {
            if ([string]::Equals($i, $Id.Trim(), [System.StringComparison]::OrdinalIgnoreCase)) { return $p.Name }
        }
    }
    return $null
}

function Get-SpineFloor {
    param([object]$Component, [string]$Consumer)
    if ($null -eq $Component) { return $null }
    return @($Component.floors | Where-Object { $_ -and "$($_.consumer)" -eq $Consumer }) | Select-Object -First 1
}

# The gateProven value for a component whose current is sourced from it, or '' when gateProven
# does not record that component.
function Get-GateProvenVersion {
    param([object]$GateProven, [string]$Name, [object]$Component)
    if ($null -eq $GateProven) { return '' }
    switch ($Name) {
        'dw'     { return "$($GateProven.dw.version)".Trim() }
        'swift'  { $s = "$($GateProven.swiftVersion)".Trim(); if (-not $s) { $s = ("$($GateProven.swift.tag)".Trim() -replace '^[vV]', '') }; return $s }
        'skills' { return ("$($GateProven.skills)".Trim() -replace '^[vV]', '') }
    }
    $ids = Get-SpineIds -Component $Component
    $hits = @($GateProven.apps | Where-Object { $a = "$($_.id)"; @($ids | Where-Object { [string]::Equals($_, $a, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 })
    if ($hits.Count -eq 0) { return '' }
    $best = "$($hits[0].version)"
    foreach ($h in $hits) { if ((Compare-SpineVersion -A "$($h.version)" -B $best) -gt 0) { $best = "$($h.version)" } }
    return $best
}

# ---------------------------------------------------------------------------
# Test-VersionSpine: every check above. -Spine / -Contract / -GateProven / -BaseSpine take parsed
# objects so a test feeds fixtures; -BaseSpine $null with -BaseState says why there is none.
# ---------------------------------------------------------------------------
function Test-VersionSpine {
    param(
        [AllowNull()][object]$Spine,
        [AllowNull()][object]$Contract,
        [AllowNull()][object]$GateProven,
        [AllowNull()][object]$BaseSpine,
        # 'present' (BaseSpine given), 'absent' (base ref has no spine: every floor is new),
        # 'unresolved' (base ref could not be read: the floor rule cannot run, fail-closed),
        # 'skipped' (explicitly not compared, local runs only).
        [ValidateSet('present', 'absent', 'unresolved', 'skipped')][string]$BaseState = 'present',
        [string]$BaseLabel = 'origin/main'
    )
    # '<owner>/<repo>#<n>' names an issue or PR; '<owner>/<repo>@<sha>' names a commit (the
    # fallback when history carries no issue or PR, flagged `untraced` on the floor).
    $refRx = '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(#[0-9]+|@[0-9a-f]{7,40})$'
    $rows = [System.Collections.Generic.List[object]]::new()
    $add = { param($ok, $msg) $rows.Add(@{ ok = [bool]$ok; msg = "spine: $msg" }) }

    # ---- S1 shape --------------------------------------------------------------
    if ($null -eq $Spine -or $null -eq $Spine.components) {
        & $add $false "versions/spine.json missing or carries no components - the spine is the source every floor derives from"
        return , $rows.ToArray()
    }
    $comps = @($Spine.components.PSObject.Properties)
    $idOwner = @{}
    foreach ($c in $comps) {
        $v = $c.Value
        $okShape = ($v.ids -and "$($v.ids.package)".Trim() -and $null -ne $v.current -and $null -ne $v.PSObject.Properties['floors'])
        & $add $okShape "component '$($c.Name)' carries ids.package, current and floors[]"
        foreach ($i in (Get-SpineIds -Component $v)) {
            $k = $i.ToLowerInvariant()
            if ($idOwner.ContainsKey($k) -and $idOwner[$k] -ne $c.Name) {
                & $add $false "id '$i' is claimed by both '$($idOwner[$k])' and '$($c.Name)' - an alias must resolve to one component"
            } else { $idOwner[$k] = $c.Name }
        }
    }

    # ---- S2 reasons, S3 floor <= current ---------------------------------------
    foreach ($c in $comps) {
        $v = $c.Value
        $seen = @{}
        $curVer = if ($v.current) { "$($v.current.version)".Trim() } else { '' }
        $curRing = if ($v.current) { Get-SpineRingNumber -Ring "$($v.current.ring)" } else { $null }
        foreach ($f in @($v.floors)) {
            if (-not $f) { continue }
            $cons = "$($f.consumer)".Trim()
            $label = "$($c.Name) floor for consumer '$cons'"
            if (-not $cons) { & $add $false "$($c.Name): a floor names no consumer - a floor belongs to the consumer that depends on it"; continue }
            if ($seen.ContainsKey($cons)) { & $add $false "$label is stated twice"; continue }
            $seen[$cons] = $true
            $min = "$($f.min)".Trim()
            $ref = if ($f.reason) { "$($f.reason.ref)".Trim() } else { '' }
            $why = if ($f.reason) { "$($f.reason.why)".Trim() } else { '' }
            & $add ($min -ne '') "$label states a min ('$min')"
            & $add (($ref -match $refRx) -and $why -ne '') ("$label carries reason.ref '<owner>/<repo>#<n>' or '<owner>/<repo>@<sha>' " +
                "and a why (found ref '$ref'). Every floor names the consumer dependency that set it.")
            if ($min -ne '') {
                if ($curVer -eq '') {
                    & $add $false "$label states min '$min' but '$($c.Name)' has no current version - a floor with nothing proven above it"
                } else {
                    & $add ((Compare-SpineVersion -A $min -B $curVer) -le 0) ("$label min '$min' is at or below current '$curVer'. " +
                        "A floor above the proven version is a claim nobody measured. Remediation: lower the floor, or prove the version first.")
                }
            }
            $fr = "$($f.ring)".Trim()
            if ($fr) {
                $frn = Get-SpineRingNumber -Ring $fr
                if ($null -eq $frn) { & $add $false "$label ring '$fr' is not a release ring R0..R4" }
                elseif ($null -ne $curRing) {
                    & $add ($frn -ge $curRing) "$label ring '$fr' is not newer than current ring '$($v.current.ring)' (a lower ring number is a newer milestone)"
                }
            }
        }
    }

    # ---- S4 current <= gateProven ----------------------------------------------
    foreach ($c in $comps) {
        $v = $c.Value
        if ("$($v.current.source)" -ne 'gateProven') { continue }
        $cur = "$($v.current.version)".Trim()
        $gpv = Get-GateProvenVersion -GateProven $GateProven -Name $c.Name -Component $v
        if (-not $gpv) {
            & $add $false "$($c.Name) current is sourced from gateProven, but layers/INDEX.json gateProven records no version for it"
            continue
        }
        $cmp = Compare-SpineVersion -A $cur -B $gpv
        $note = if ($cmp -lt 0) { " (gateProven is ahead at '$gpv'; current may follow in any PR, and floors are bounded by current meanwhile)" } else { '' }
        & $add ($cmp -le 0) "$($c.Name) current '$cur' does not run ahead of gateProven '$gpv'$note"
    }

    # ---- S5 contract copies the `layers` floors -----------------------------------
    if ($null -eq $Contract -or $null -eq $Contract.compat) {
        & $add $false "layers/base/base.contract.json carries no compat block to compare with the spine"
    } else {
        $cc = $Contract.compat
        $dwF = Get-SpineFloor -Component $Spine.components.dw -Consumer 'layers'
        if ($dwF) {
            foreach ($k in 'min', 'ring', 'tfm') {
                $sv = "$($dwF.$k)".Trim(); $cv = "$($cc.dw.$k)".Trim()
                & $add ($sv -eq $cv) "base contract compat.dw.$k '$cv' equals the spine layers floor '$sv' (the spine is the source, the contract the copy)"
            }
        }
        $swF = Get-SpineFloor -Component $Spine.components.swift -Consumer 'layers'
        if ($swF) {
            & $add ("$($swF.tag)".Trim() -eq "$($cc.swift.tag)".Trim()) "base contract compat.swift.tag '$($cc.swift.tag)' equals the spine layers floor '$($swF.tag)'"
            & $add ("$($swF.min)".Trim() -eq "$($cc.swift.version)".Trim()) "base contract compat.swift.version '$($cc.swift.version)' equals the spine layers floor '$($swF.min)'"
            if ($Contract.PSObject.Properties.Name -contains 'swiftVersion') {
                & $add ("$($swF.min)".Trim() -eq "$($Contract.swiftVersion)".Trim()) "base contract swiftVersion '$($Contract.swiftVersion)' equals the spine layers floor '$($swF.min)'"
            }
        }
        # Apps: every component (other than dw/swift) with a `layers` floor is one compat.apps entry
        # under its canonical package id, and the contract carries no app the spine does not.
        $expected = @{}
        foreach ($c in $comps) {
            if ($c.Name -in 'dw', 'swift') { continue }
            $f = Get-SpineFloor -Component $c.Value -Consumer 'layers'
            if ($f) { $expected["$($c.Value.ids.package)"] = $f }
        }
        $contractApps = @($cc.apps | Where-Object { $_ })
        foreach ($id in ($expected.Keys | Sort-Object)) {
            $f = $expected[$id]
            $hit = @($contractApps | Where-Object { "$($_.id)" -eq $id })
            if ($hit.Count -ne 1) {
                $comp = Resolve-SpineComponent -Spine $Spine -Id $id
                $aliasHit = @($contractApps | Where-Object { (Resolve-SpineComponent -Spine $Spine -Id "$($_.id)") -eq $comp })
                $extra = if ($aliasHit.Count) { " (found it under '$($aliasHit[0].id)': the contract names the canonical package id, the spine carries the aliases)" } else { '' }
                & $add $false "base contract compat.apps carries exactly one '$id' entry$extra"
                continue
            }
            $req = if ($null -ne $f.required) { [bool]$f.required } else { $true }
            $creq = if ($null -ne $hit[0].required) { [bool]$hit[0].required } else { $true }
            & $add ("$($hit[0].min)".Trim() -eq "$($f.min)".Trim() -and $req -eq $creq) ("base contract compat.apps '$id' min '$($hit[0].min)' required $creq " +
                "equals the spine layers floor min '$($f.min)' required $req")
        }
        foreach ($a in $contractApps) {
            if (-not $expected.ContainsKey("$($a.id)")) {
                & $add $false "base contract compat.apps names '$($a.id)', which has no spine floor for consumer 'layers' - add the floor (with its reason) to versions/spine.json first"
            }
        }
        if ($Contract.PSObject.Properties.Name -contains 'minSerializerVersion') {
            $serF = Get-SpineFloor -Component $Spine.components.serializer -Consumer 'layers'
            if ($serF) { & $add ("$($Contract.minSerializerVersion)" -eq "$($serF.min)") "base contract minSerializerVersion '$($Contract.minSerializerVersion)' equals the spine layers floor '$($serF.min)'" }
        }
    }

    # ---- S6 the floor rule, against the merge base ------------------------------
    switch ($BaseState) {
        'unresolved' {
            & $add $false ("the merge base '$BaseLabel' could not be read, so the floor rule could not compare this PR's floors with it " +
                "(fail-closed). Remediation: fetch the base branch (git fetch origin main) before running the validator.")
        }
        'skipped' { & $add $true "floor rule not compared (-SpineBaseRef ''; local runs only)" }
        'absent'  { & $add $true "floor rule: '$BaseLabel' carries no versions/spine.json, so every floor is new; each carries its own reason (checked above)" }
        'present' {
            $raised = 0
            foreach ($c in $comps) {
                $bc = if ($BaseSpine -and $BaseSpine.components) { $BaseSpine.components.PSObject.Properties[$c.Name] } else { $null }
                if ($null -eq $bc) { continue }
                foreach ($f in @($c.Value.floors)) {
                    if (-not $f) { continue }
                    $bf = Get-SpineFloor -Component $bc.Value -Consumer "$($f.consumer)"
                    if ($null -eq $bf) { continue }
                    $up = @()
                    $hm = "$($f.min)".Trim(); $bm = "$($bf.min)".Trim()
                    if ($hm -and $bm -and (Compare-SpineVersion -A $hm -B $bm) -gt 0) { $up += "min $bm -> $hm" }
                    $hr = Get-SpineRingNumber -Ring "$($f.ring)"; $br = Get-SpineRingNumber -Ring "$($bf.ring)"
                    if ($null -ne $hr -and $null -ne $br -and $hr -lt $br) { $up += "ring $($bf.ring) -> $($f.ring)" }
                    if ($up.Count -eq 0) { continue }
                    $raised++
                    $href = if ($f.reason) { "$($f.reason.ref)".Trim() } else { '' }
                    $bref = if ($bf.reason) { "$($bf.reason.ref)".Trim() } else { '' }
                    $ok = ($href -ne '' -and -not [string]::Equals($href, $bref, [System.StringComparison]::OrdinalIgnoreCase))
                    $msg = if ($ok) { "floor rule: $($c.Name) floor for '$($f.consumer)' raised ($($up -join ', ')) with a new consumer reason '$href'" }
                           else { ("floor raised without a consumer reason: $($c.Name) floor for '$($f.consumer)' ($($up -join ', ')) keeps reason.ref '$bref' from $BaseLabel. " +
                                   "A floor rises only when a consumer depends on the fix, never to the latest release (redesign-floors). " +
                                   "Remediation: set reason.ref to the issue or PR the consumer depends on, or leave the floor where it was.") }
                    & $add $ok $msg
                }
            }
            if ($raised -eq 0) { & $add $true "floor rule: no floor raised against $BaseLabel" }
        }
    }
    return , $rows.ToArray()
}

# Read the spine at a git ref. Returns @{ state; spine }. state: present / absent / unresolved.
function Get-BaseSpine {
    param([Parameter(Mandatory)][string]$RepoRoot, [Parameter(Mandatory)][string]$BaseRef)
    $null = & git -C $RepoRoot rev-parse --verify --quiet "$BaseRef^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) { return @{ state = 'unresolved'; spine = $null; label = $BaseRef } }
    # The merge base when history allows it (a shallow CI clone may not), else the ref itself.
    $mb = (& git -C $RepoRoot merge-base HEAD $BaseRef 2>$null)
    $at = if ($LASTEXITCODE -eq 0 -and "$mb".Trim()) { "$mb".Trim() } else { $BaseRef }
    $label = if ($at -eq $BaseRef) { $BaseRef } else { "merge base $($at.Substring(0, 8)) of $BaseRef" }
    $null = & git -C $RepoRoot cat-file -e "${at}:versions/spine.json" 2>$null
    if ($LASTEXITCODE -ne 0) { return @{ state = 'absent'; spine = $null; label = $label } }
    $raw = (& git -C $RepoRoot show "${at}:versions/spine.json") -join "`n"
    try { return @{ state = 'present'; spine = ($raw | ConvertFrom-Json); label = $label } }
    catch { return @{ state = 'unresolved'; spine = $null; label = "$label (versions/spine.json did not parse)" } }
}
