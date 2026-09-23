<#
.SYNOPSIS
The provenTree proof key: does the tree in front of us equal the tree a gate run delivered?

.DESCRIPTION
Owner ruling 2026-09-23 ("proof rides with delivery", register redesign-floors): a provenance tag
must never name a gate run that did not deliver the tagged tree. The Foundry's
Write-IndexGateProven.ps1 records, per proven edition,

  gateProven.proofs.<edition> = {
      runId,                 the attested run (equals gateProven.editions.<edition>)
      deliveryRunId,         the run that delivered, when a separate measure run attests
      distributionCommit,    the Distribution commit the run delivered
      checkSet,              the Foundry check-set version the run was held to
      harnessCommit,         the Foundry commit the gate ran from
      algorithm,             'layer-tree/v1' (tools/ci/Get-LayerTreeHash.ps1)
      provenTree: { <layer>: { version, hash } }   every layer the delivery composed
  }

`proofs` is a sibling of `editions`, never a change of it: every reader of the edition -> runId map
keeps reading strings. An edition in `editions` with no `proofs` entry is LEGACY (stamped before the
key existed): its tags keep the pre-key rule, with a notice, until the next restamp fills it.

This file is used by Validate-Distribution.ps1 (check 14) and print-release-tags.ps1. Functions only.
#>

. (Join-Path $PSScriptRoot 'Get-LayerTreeHash.ps1')

$script:ProvenTreeHashPattern = '^sha256:[0-9a-f]{64}$'

function Get-ProvenTreeMember {
    param($Node, [string]$Name)
    if ($null -eq $Node) { return $null }
    if ($Node -is [System.Collections.IDictionary]) { return $Node[$Name] }
    $p = $Node.PSObject.Properties[$Name]
    if ($p) { return $p.Value }
    return $null
}

function Get-ProvenTreeNames {
    param($Node)
    if ($null -eq $Node) { return @() }
    if ($Node -is [System.Collections.IDictionary]) { return @($Node.Keys | ForEach-Object { "$_" }) }
    return @($Node.PSObject.Properties | ForEach-Object { $_.Name })
}

# Shape of gateProven.proofs. Returns a list of problems (strings); empty means well-formed or absent.
function Test-ProvenTreeShape {
    [CmdletBinding()]
    param($GateProven)
    $problems = @()
    $proofs = Get-ProvenTreeMember $GateProven 'proofs'
    if ($null -eq $proofs) { return }
    $editions = Get-ProvenTreeMember $GateProven 'editions'
    foreach ($en in (Get-ProvenTreeNames $proofs)) {
        $p = Get-ProvenTreeMember $proofs $en
        $attested = "$(Get-ProvenTreeMember $editions $en)"
        $run = "$(Get-ProvenTreeMember $p 'runId')"
        if ([string]::IsNullOrEmpty($attested)) { $problems += "proofs.$en names an edition absent from gateProven.editions" }
        elseif ($run -ne $attested) { $problems += "proofs.$en.runId '$run' is not the attested run '$attested' (gateProven.editions.$en)" }
        $dr = Get-ProvenTreeMember $p 'deliveryRunId'
        if ($null -ne $dr -and "$dr" -notmatch '^[0-9]{8}-[0-9]{6}$') { $problems += "proofs.$en.deliveryRunId '$dr' is not a runs/<ts> id" }
        if ("$(Get-ProvenTreeMember $p 'distributionCommit')" -notmatch '^[0-9a-f]{40}$') { $problems += "proofs.$en.distributionCommit must be a 40-hex commit" }
        $cs = Get-ProvenTreeMember $p 'checkSet'
        if ($null -ne $cs -and "$cs" -notmatch '^[0-9]+$') { $problems += "proofs.$en.checkSet '$cs' must be an integer or null" }
        $alg = "$(Get-ProvenTreeMember $p 'algorithm')"
        if ($alg -ne $script:LayerTreeHashAlgorithm) { $problems += "proofs.$en.algorithm '$alg' is not '$($script:LayerTreeHashAlgorithm)', the only tree hash this repository computes" }
        $tree = Get-ProvenTreeMember $p 'provenTree'
        $layers = Get-ProvenTreeNames $tree
        if ($layers.Count -eq 0) { $problems += "proofs.$en.provenTree is empty: a delivery composes at least the base" }
        foreach ($ln in $layers) {
            $e = Get-ProvenTreeMember $tree $ln
            if ("$(Get-ProvenTreeMember $e 'version')" -notmatch '^[0-9]+\.[0-9]+\.[0-9]+') { $problems += "proofs.$en.provenTree.$ln.version must be a semver" }
            if ("$(Get-ProvenTreeMember $e 'hash')" -notmatch $script:ProvenTreeHashPattern) { $problems += "proofs.$en.provenTree.$ln.hash must be sha256:<64 hex>" }
        }
    }
    return $problems
}

# One row per (edition, layer) of every proof, plus one 'legacy' row per attested edition with no proof.
#   match                 current version == proven version and current hash == proven hash
#   changed-without-bump  same version, different tree: CI fails
#   unproven              the version moved (a bump): not proven yet, never tagged, CI passes with a notice
#   missing               the layer directory is gone from this tree
#   legacy                the edition's proof predates the key (layer is $null)
function Get-ProvenTreeStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        $GateProven,
        [hashtable]$HashCache = @{}
    )
    $rows = [System.Collections.Generic.List[object]]::new()
    $editions = Get-ProvenTreeMember $GateProven 'editions'
    $proofs = Get-ProvenTreeMember $GateProven 'proofs'
    foreach ($en in @(Get-ProvenTreeNames $editions | Sort-Object)) {
        $run = "$(Get-ProvenTreeMember $editions $en)"
        $p = Get-ProvenTreeMember $proofs $en
        if ($null -eq $p) {
            $rows.Add([pscustomobject]@{ edition = $en; runId = $run; layer = $null; state = 'legacy'
                                         provenVersion = $null; provenHash = $null; currentVersion = $null; currentHash = $null })
            continue
        }
        $tree = Get-ProvenTreeMember $p 'provenTree'
        foreach ($ln in @(Get-ProvenTreeNames $tree | Sort-Object)) {
            $e = Get-ProvenTreeMember $tree $ln
            $pv = "$(Get-ProvenTreeMember $e 'version')"; $ph = "$(Get-ProvenTreeMember $e 'hash')"
            $dir = Join-Path (Join-Path $RepoRoot 'layers') $ln
            $lj = Join-Path $dir 'layer.json'
            $cv = $null; $ch = $null
            if (-not (Test-Path -LiteralPath $lj -PathType Leaf)) { $state = 'missing' }
            else {
                $cv = "$((Get-Content -LiteralPath $lj -Raw -Encoding utf8 | ConvertFrom-Json).version)"
                if (-not $HashCache.ContainsKey($ln)) { $HashCache[$ln] = Get-LayerTreeHash -LayerPath $dir }
                $ch = $HashCache[$ln]
                $state = if ($ch -eq $ph) { 'match' } elseif ($cv -eq $pv) { 'changed-without-bump' } else { 'unproven' }
            }
            $rows.Add([pscustomobject]@{ edition = $en; runId = $run; layer = $ln; state = $state
                                         provenVersion = $pv; provenHash = $ph; currentVersion = $cv; currentHash = $ch })
        }
    }
    return $rows.ToArray()
}

# The validator's reading of the status rows: @{ level = PASS|FAIL|NOTE; message }.
function Get-ProvenTreeFinding {
    [CmdletBinding()]
    param([AllowEmptyCollection()][object[]]$Status)
    $out = @()
    foreach ($r in @($Status)) {
        switch ($r.state) {
            'match' {
                $out += [pscustomobject]@{ level = 'PASS'; message = "provenTree: layer $($r.layer) $($r.currentVersion) is the tree proving run $($r.runId) delivered ($($r.edition))" }
            }
            'changed-without-bump' {
                $out += [pscustomobject]@{ level = 'FAIL'; message = "layer $($r.layer) changed since proving run $($r.runId) without a version bump (version $($r.currentVersion), proven tree $($r.provenHash), this tree $($r.currentHash); edition $($r.edition)). Bump the layer version, or restore the proven tree." }
            }
            'unproven' {
                $out += [pscustomobject]@{ level = 'NOTE'; message = "layer $($r.layer) $($r.currentVersion) is unproven: proving run $($r.runId) delivered $($r.provenVersion) ($($r.edition)). release-tags will not tag it until a gate run delivers this tree and restamps gateProven." }
            }
            'missing' {
                $out += [pscustomobject]@{ level = 'NOTE'; message = "layer $($r.layer) is in the provenTree of run $($r.runId) ($($r.edition)) but not in this tree; nothing to tag." }
            }
            'legacy' {
                $out += [pscustomobject]@{ level = 'NOTE'; message = "edition $($r.edition) (run $($r.runId)) carries no provenTree yet (stamped before the proof key): release tags keep the pre-key rule until the next restamp fills it." }
            }
        }
    }
    return $out
}
