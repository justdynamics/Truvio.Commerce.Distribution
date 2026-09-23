<#
.SYNOPSIS
The one canonical tree hash of a layer directory (layer-tree/v1): the proof key that ties a
provenance tag to the gate run that delivered exactly that tree.

.DESCRIPTION
The Foundry's Write-IndexGateProven.ps1 hashes every layer a gate run composed, with THIS file
from the Distribution tree the run delivered, and records the result in
layers/INDEX.json gateProven.proofs.<edition>.provenTree. Validate-Distribution.ps1 and
print-release-tags.ps1 recompute it on the tree in front of them. One implementation, used by
both repositories, so the writer and the readers can never disagree about what a tree is.

Definition, layer-tree/v1:

  1. Files. Every regular file under the layer directory, recursively, dot-files included.
     Excluded: Markdown files directly in the layer root (README.md, CHANGELOG.md, BASE.md,
     BASELINE.md and any other <layer>/*.md). Those are documentation: neither the composer
     nor either delivery path (clean-room overlay, remote upload) reads them. A Markdown file
     BELOW the root is included, because a tree such as files/ ships whatever it holds.
     Everything else is included, because the tag layers/<name>/<version> names the whole
     directory at a commit, and a delivered tree is wider than replace/, merge/ and files/:
     config/ (serializer predicates), templates/, itemtypes/ and repositories/ reach the host
     (Foundry LayerTrees.ps1, #1218 was a delivered tree nobody listed), src/ is compiled by
     clean-room, and layer.json, base.contract.json and theme.json are read by the gate.
     Empty directories contribute nothing (git does not carry them).
  2. Path. The path relative to the layer directory with '/' separators, sorted ordinally
     (UTF-16 code unit order, which is byte order for the ASCII names the layers use).
  3. Content. A file whose first 8000 bytes hold no NUL byte is text: every CR LF pair becomes
     LF (a lone CR stays). A file with a NUL byte there is binary and is hashed as it is. This is
     git's own text heuristic, so a Windows checkout with core.autocrlf=true and a Linux CI
     checkout hash to the same value.
  4. Line. Per file: '<sha256 of the normalised content, lowercase hex>  <path>' and LF, the
     sha256sum text format.
  5. Hash. SHA-256 over the UTF-8 bytes (no BOM) of the lines concatenated in path order,
     written 'sha256:<lowercase hex>'.

A change to this definition is a new algorithm id (layer-tree/v2), never an edit of v1: every
recorded provenTree hash was computed under the id its proof names.

Functions only when dot-sourced. Executed directly it prints the hash of -LayerPath (or of
every layer under -LayersRoot, one '<name> <hash>' line each).

.EXAMPLE
pwsh tools/ci/Get-LayerTreeHash.ps1 -LayerPath layers/base
pwsh tools/ci/Get-LayerTreeHash.ps1 -LayersRoot layers
#>

$script:LayerTreeHashAlgorithm = 'layer-tree/v1'

# The ordered file list of a layer tree: @{ Path = '<relative/path>'; FullName = '<abs>' }.
function Get-LayerTreeFile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LayerPath)
    if (-not (Test-Path -LiteralPath $LayerPath -PathType Container)) { throw "Get-LayerTreeHash: layer directory not found: $LayerPath" }
    $root = (Resolve-Path -LiteralPath $LayerPath).Path.TrimEnd('\', '/')
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($f in [System.IO.Directory]::EnumerateFiles($root, '*', [System.IO.SearchOption]::AllDirectories)) {
        $rel = $f.Substring($root.Length + 1).Replace('\', '/')
        if ($rel -notmatch '/' -and $rel -match '(?i)\.md$') { continue }   # layer-root documentation
        $rows.Add([pscustomobject]@{ Path = $rel; FullName = $f })
    }
    # In place and ordinal: never the file system's enumeration order, which differs by OS.
    $rows.Sort([System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.Path, $b.Path) })
    return , $rows.ToArray()
}

# SHA-256 of one file's normalised content (step 3), lowercase hex.
function Get-LayerTreeFileDigest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $binary = [System.Array]::IndexOf($bytes, [byte]0, 0, [Math]::Min($bytes.Length, 8000)) -ge 0
    if (-not $binary -and [System.Array]::IndexOf($bytes, [byte]13) -ge 0) {
        # Drop the CR of every CR LF pair; copy the runs between them in one call each.
        $out = [System.IO.MemoryStream]::new($bytes.Length)
        $start = 0
        while ($true) {
            $cr = [System.Array]::IndexOf($bytes, [byte]13, $start)
            if ($cr -lt 0) { $out.Write($bytes, $start, $bytes.Length - $start); break }
            if (($cr + 1) -lt $bytes.Length -and $bytes[$cr + 1] -eq 10) {
                $out.Write($bytes, $start, $cr - $start)          # skip the CR, keep the LF
            } else {
                $out.Write($bytes, $start, $cr + 1 - $start)      # a lone CR stays
            }
            $start = $cr + 1
            if ($start -ge $bytes.Length) { break }
        }
        $bytes = $out.ToArray()
    }
    return ([System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

# The canonical manifest text (steps 1 to 4): the exact bytes step 5 hashes, as a string.
function Get-LayerTreeManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LayerPath)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($f in (Get-LayerTreeFile -LayerPath $LayerPath)) {
        [void]$sb.Append((Get-LayerTreeFileDigest -Path $f.FullName)).Append('  ').Append($f.Path).Append("`n")
    }
    return $sb.ToString()
}

# The layer-tree/v1 hash of a layer directory: 'sha256:<hex>'.
function Get-LayerTreeHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LayerPath)
    $text = Get-LayerTreeManifest -LayerPath $LayerPath
    $digest = [System.Security.Cryptography.SHA256]::HashData([System.Text.UTF8Encoding]::new($false).GetBytes($text))
    return 'sha256:' + ([System.Convert]::ToHexString($digest)).ToLowerInvariant()
}

if ($MyInvocation.InvocationName -ne '.') {
    & {
        param([string]$LayerPath, [string]$LayersRoot)
        $ErrorActionPreference = 'Stop'
        if ($LayerPath) { Get-LayerTreeHash -LayerPath $LayerPath; return }
        if (-not $LayersRoot) { throw 'Get-LayerTreeHash.ps1: pass -LayerPath <layer dir> or -LayersRoot <layers dir>' }
        foreach ($d in (Get-ChildItem -LiteralPath $LayersRoot -Directory | Sort-Object Name)) {
            if (-not (Test-Path -LiteralPath (Join-Path $d.FullName 'layer.json'))) { continue }
            "{0} {1}" -f $d.Name, (Get-LayerTreeHash -LayerPath $d.FullName)
        }
    } @args
}
