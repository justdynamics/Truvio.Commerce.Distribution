<#
.SYNOPSIS
READ-ONLY. Validate proposed CPQ specifications, package locks and layer declarations.
.DESCRIPTION
PowerShell 7. Offline contract validation only; no downloads, compilation, installation,
database access or certification. See contracts/cpq/README.md. Unknown structures,
unresolved references and package identities fail before a consumer may act.
.EXAMPLE
Test-CpqLayerContract -LayerRoot ./layers/feature-cpq -Layer $layer -ContractRoot ./contracts/cpq
#>
#Requires -Version 7.0

function Read-CpqJson {
    param([Parameter(Mandatory)][string]$Path)
    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    $document = [System.Text.Json.JsonDocument]::Parse($raw)
    function Assert-UniqueJsonKeys([System.Text.Json.JsonElement]$Node) {
        if ($Node.ValueKind -eq 'Object') {
            $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($property in $Node.EnumerateObject()) {
                if (-not $names.Add($property.Name)) { throw 'Duplicate JSON property.' }
                Assert-UniqueJsonKeys $property.Value
            }
        } elseif ($Node.ValueKind -eq 'Array') {
            foreach ($item in $Node.EnumerateArray()) { Assert-UniqueJsonKeys $item }
        }
    }
    # ConvertFrom-Json can materialize ISO strings as DateTime and normalize their
    # fractional seconds on a later write. That changes a trusted receipt digest.
    # Preserve JSON strings and array shape independently of PowerShell's DateKind default.
    function ConvertFrom-CpqJsonNode([System.Text.Json.JsonElement]$Node) {
        switch($Node.ValueKind.ToString()){
            'Object' {
                $map=[hashtable]::new([StringComparer]::Ordinal)
                foreach($p in $Node.EnumerateObject()){$map[$p.Name]=ConvertFrom-CpqJsonNode $p.Value}
                return $map
            }
            'Array' {return ,@(foreach($item in $Node.EnumerateArray()){ConvertFrom-CpqJsonNode $item})}
            'String' {return $Node.GetString()}
            'Number' {
                $integer=0L;if($Node.TryGetInt64([ref]$integer)){return $integer}
                $number=[decimal]0;if($Node.TryGetDecimal([ref]$number)){return $number}
                return $Node.GetDouble()
            }
            'True' {return $true}
            'False' {return $false}
            'Null' {return ,$null}
            default {throw 'Unsupported CPQ JSON value.'}
        }
    }
    try { Assert-UniqueJsonKeys $document.RootElement; return ConvertFrom-CpqJsonNode $document.RootElement }
    finally { $document.Dispose() }
}

function Assert-CpqSchema {
    param([Parameter(Mandatory)]$Data, [Parameter(Mandatory)][string]$Schema)
    $json = ConvertTo-Json -InputObject $Data -Depth 100 -Compress
    try { $valid = Test-Json -Json $json -SchemaFile $Schema -ErrorAction Stop }
    catch { throw "CPQ schema validation failed: $([IO.Path]::GetFileName($Schema))." }
    if (-not $valid) { throw "CPQ schema validation failed: $([IO.Path]::GetFileName($Schema))." }
}

function ConvertTo-CpqCanonicalJson {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [Collections.IDictionary]) {
        [string[]]$keys = @($Value.Keys)
        [Array]::Sort($keys, [StringComparer]::Ordinal)
        $parts = foreach ($key in $keys) {
            (ConvertTo-Json -InputObject $key -Compress) + ':' + (ConvertTo-CpqCanonicalJson $Value[$key])
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        $parts = foreach ($item in $Value) { ConvertTo-CpqCanonicalJson $item }
        return '[' + ($parts -join ',') + ']'
    }
    return ConvertTo-Json -InputObject $Value -Depth 100 -Compress
}

function Get-CpqDigest {
    param([Parameter(Mandatory)]$Data)
    $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-CpqCanonicalJson $Data))
    return 'sha256:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Resolve-CpqContractPath {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Relative)
    if ($Relative -cnotmatch '^[A-Za-z0-9_-]+(?:/[A-Za-z0-9_.-]+)*\.json$' -or
        $Relative.Split('/') -contains '..') { throw 'Invalid CPQ relative path.' }
    $base = [IO.Path]::GetFullPath($Root)
    $path = $base
    foreach ($part in $Relative.Split('/')) {
        $path = Join-Path $path $part
        $entry = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'CPQ contract path follows a link.' }
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'CPQ contract is not a file.' }
    return $path
}

function Get-CpqIdentityMap {
    param([AllowEmptyCollection()][object[]]$Items, [string]$Field = 'key')
    $map = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Items) {
        if ($null -eq $item) { continue }
        $id = [string]$item[$Field]
        if (-not $id -or $map.ContainsKey($id)) { throw 'Missing or duplicate CPQ identity.' }
        $map.Add($id, $item)
    }
    return ,$map
}

function Assert-CpqSpec {
    param([Parameter(Mandatory)]$Spec, [Parameter(Mandatory)][string]$ContractRoot)
    Assert-CpqSchema $Spec (Join-Path $ContractRoot 'spec.schema.json')
    $groups = Get-CpqIdentityMap @($Spec.groups)
    $fields = Get-CpqIdentityMap @($Spec.inputs)
    $products = Get-CpqIdentityMap @($Spec.catalogue)
    $variables = Get-CpqIdentityMap @($Spec.variables)
    $lookups = Get-CpqIdentityMap @($Spec.lookups)
    $cases = Get-CpqIdentityMap @($Spec.cases) 'id'
    $productFields = @('key', 'price', 'cost') + @($Spec.catalogue | ForEach-Object { if ($_.attributes) { $_.attributes.Keys } })
    foreach ($field in $Spec.inputs) {
        if (-not $groups.ContainsKey($field.group)) { throw 'Input names an unknown group.' }
        if ($field.ContainsKey('lookup') -and -not $lookups.ContainsKey($field.lookup)) { throw 'Input names an unknown lookup.' }
        if ($field.ContainsKey('lookup') -and $field.ContainsKey('options')) { throw 'Input must choose a lookup or authored options.' }
        if ($field.ContainsKey('min') -and $field.ContainsKey('max') -and $field.min -gt $field.max) { throw 'Input bounds are inverted.' }
        if ($field.ContainsKey('options')) {
            $values = @($field.options | ForEach-Object { ConvertTo-CpqCanonicalJson $_.value })
            if (@($values | Sort-Object -Unique).Count -ne $values.Count) { throw 'Duplicate option value.' }
            if ($field.ContainsKey('default') -and (ConvertTo-CpqCanonicalJson $field.default) -cnotin $values) { throw 'Default is not a declared option.' }
        }
        if ($field.type -eq 'number' -and $field.ContainsKey('default')) {
            if ($field.default -is [string] -or $field.default -is [bool] -or $null -eq $field.default) { throw 'Number default must be numeric.' }
            if (($field.ContainsKey('min') -and $field.default -lt $field.min) -or ($field.ContainsKey('max') -and $field.default -gt $field.max)) { throw 'Default is outside input bounds.' }
        }
    }
    foreach ($tab in $Spec.page.tabs) { if (-not $groups.ContainsKey($tab)) { throw 'Page tab names an unknown group.' } }
    foreach ($items in @('constraints','inputRules','bom')) { $null = Get-CpqIdentityMap @($Spec[$items]) 'id' }
    $null = Get-CpqIdentityMap @($Spec.pricing.rules) 'id'
    foreach ($family in @(@($Spec.inputRules), @($Spec.pricing.rules))) {
        $orders = @($family | ForEach-Object order)
        if (@($orders | Sort-Object -Unique).Count -ne $orders.Count) { throw 'Rule order must be unambiguous within each family.' }
    }
    function Assert-CpqReferences($Node, [bool]$AllowProduct = $false) {
        if ($Node -is [Collections.IDictionary]) {
            foreach ($value in $Node.Values) { Assert-CpqReferences $value $AllowProduct }
        } elseif ($Node -is [Collections.IEnumerable] -and $Node -isnot [string]) {
            foreach ($value in $Node) { Assert-CpqReferences $value $AllowProduct }
        } elseif ($Node -is [string] -and $Node.StartsWith('$')) {
            if ($Node -cnotmatch '^\$(input|variable|product)\.([A-Za-z][A-Za-z0-9_-]*)$') { throw 'Malformed CPQ expression reference.' }
            $kind, $name = $Matches[1], $Matches[2]
            if (($kind -eq 'input' -and -not $fields.ContainsKey($name)) -or
                ($kind -eq 'variable' -and -not $variables.ContainsKey($name)) -or
                ($kind -eq 'product' -and (-not $AllowProduct -or $name -cnotin $productFields))) { throw 'Unknown or out-of-scope CPQ expression reference.' }
        }
    }
    foreach ($rule in @($Spec.constraints) + @($Spec.inputRules) + @($Spec.bom) + @($Spec.pricing.rules)) { Assert-CpqReferences $rule }
    foreach ($lookup in @($Spec.lookups)) { Assert-CpqReferences $lookup.where $true }
    foreach ($rule in $Spec.inputRules) {
        foreach ($action in @($rule.then) + @($rule.else)) {
            $operation = @($action.Values)[0]
            if (-not $fields.ContainsKey($operation.input)) { throw 'Action target is not an input.' }
            if ($action.ContainsKey('allowOptions')) {
                $target = $fields[$operation.input]
                $values = if ($target.lookup) { @($Spec.catalogue | ForEach-Object { ConvertTo-CpqCanonicalJson $_.key }) } else { @($target.options | ForEach-Object { ConvertTo-CpqCanonicalJson $_.value }) }
                foreach ($value in $operation.values) {
                    if ((ConvertTo-CpqCanonicalJson $value) -cnotin $values) { throw 'Action names an unknown option.' }
                }
            }
        }
    }
    foreach ($line in $Spec.bom) {
        if (-not $products.ContainsKey($line.sku)) { throw 'BOM line names an unknown product.' }
        if ($line.quantity -is [string]) {
            $kind, $name = $line.quantity.Substring(1).Split('.')
            if ($kind -eq 'input' -and $fields[$name].type -cne 'number') { throw 'BOM quantity must reference a number input.' }
            if ($kind -eq 'variable') {
                $value = $variables[$name].value
                if ($null -eq $value -or $value -is [string] -or $value -is [bool] -or $value -le 0) {
                    throw 'BOM quantity variable must be a positive number.'
                }
            }
        }
    }
    foreach ($rule in $Spec.pricing.rules) { if ([decimal]$rule.discountPercent -gt 100) { throw 'Discount must not exceed 100 percent.' } }
    foreach ($case in $Spec.cases) {
        foreach ($name in $case.answers.Keys) { if (-not $fields.ContainsKey($name)) { throw 'Case names an unknown input.' } }
        if ($case.expect.bom) { foreach ($sku in $case.expect.bom.Keys) { if (-not $products.ContainsKey($sku)) { throw 'Case expects an unknown product.' } } }
        if ($case.expect.valid) {
            foreach ($field in $Spec.inputs) {
                if ($field.required -and -not $case.answers.Contains($field.key) -and -not $field.ContainsKey('default')) { throw 'Valid case omits a required answer without a default.' }
            }
        }
    }
}

function Compare-CpqNuGetVersion {
    param([string]$Left, [string]$Right)
    # NuGet compares release labels without case; numeric labels sort before text.
    $parsed = @()
    foreach ($value in @($Left, $Right)) {
        if ($value -cnotmatch '^([0-9]+\.[0-9]+\.[0-9]+(?:\.[0-9]+)?)(?:-([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*))?$') { throw 'Invalid NuGet version.' }
        $core = [version]$Matches[1]; $label = $Matches[2]
        $parsed += @{core=[version]::new($core.Major,$core.Minor,$core.Build,[Math]::Max(0,$core.Revision));labels=@(if($label){$label.Split('.')})}
    }
    $comparison = $parsed[0].core.CompareTo($parsed[1].core)
    if ($comparison) { return $comparison }
    $a = $parsed[0].labels; $b = $parsed[1].labels
    if (-not $a.Count) { if (-not $b.Count) { return 0 }; return 1 }
    if (-not $b.Count) { return -1 }
    for ($i=0; $i -lt [Math]::Min($a.Count,$b.Count); $i++) {
        $an = $a[$i] -match '^[0-9]+$'; $bn = $b[$i] -match '^[0-9]+$'
        if ($an -and $bn) { $comparison = ([Numerics.BigInteger]::Parse($a[$i])).CompareTo([Numerics.BigInteger]::Parse($b[$i])) }
        elseif ($an) { $comparison = -1 }
        elseif ($bn) { $comparison = 1 }
        else { $comparison = [StringComparer]::OrdinalIgnoreCase.Compare($a[$i],$b[$i]) }
        if ($comparison) { return $comparison }
    }
    return $a.Count.CompareTo($b.Count)
}

function Get-CpqAssemblyEntry {
    param($Assembly)
    $ordinary = "lib/$($Assembly.tfm)/$($Assembly.name).dll"
    if (-not $Assembly.ContainsKey('entry')) { return $ordinary }
    $bundled = "Files/System/AddIns/Installed/$($Assembly.name)/$ordinary"
    if ($Assembly.entry -cnotin @($ordinary,$bundled)) { throw 'Package assembly entry differs from its name, TFM or supported add-in layout.' }
    return $Assembly.entry
}

function Assert-CpqPackages {
    param([Parameter(Mandatory)]$Packages, [Parameter(Mandatory)][string]$ContractRoot)
    Assert-CpqSchema $Packages (Join-Path $ContractRoot 'packages.schema.json')
    $map = Get-CpqIdentityMap @($Packages.packages) 'id'
    foreach ($role in @('admin','runtime','studio','mcp')) {
        if (@($Packages.packages | Where-Object role -EQ $role).Count -ne 1) { throw "Exactly one $role package is required." }
    }
    $profile = @{
        admin=@('CPQ_Admin','10.24.2'); runtime=@('DW_CPQ_API','10.24.2')
        studio=@('Truvio.Commerce.CpqStudio','0.7.0')
    }
    foreach ($role in $profile.Keys) {
        $pinned = @($Packages.packages | Where-Object role -EQ $role)[0]
        if ($pinned.id -cne $profile[$role][0] -or $pinned.version -cne $profile[$role][1]) { throw 'Package identity/version differs from the declared engine profile.' }
    }
    $mcp = @($Packages.packages | Where-Object role -EQ 'mcp')[0]
    if ($mcp.id -cne 'Truvio.Commerce.MCP' -or 'Truvio.Commerce.MCP' -cnotin $mcp.assemblies.name) { throw 'MCP dependency identity differs from the reviewed profile.' }
    $mcpHost = @($Packages.packages | Where-Object { 'Truvio.Commerce.MCP.Host' -cin $_.assemblies.name })
    if ($mcpHost.Count -ne 1 -or $mcpHost[0].role -cnotin @('mcp','mcp-host')) { throw 'Exactly one MCP.Host assembly carrier is required.' }
    $separateHost = @($Packages.packages | Where-Object role -EQ 'mcp-host')
    if ($separateHost.Count -gt 1 -or ($separateHost.Count -and ($separateHost[0].id -cne 'Truvio.Commerce.MCP.Host' -or $mcpHost[0].id -cne $separateHost[0].id))) { throw 'MCP.Host package identity differs from the reviewed profile.' }
    foreach ($package in @($mcp,$mcpHost[0])) {
        if ((Compare-CpqNuGetVersion $package.version '0.6.5-beta') -lt 0) { throw 'MCP dependency is below the Studio floor (0.6.5-beta).' }
    }
    foreach ($id in @('CPQ_Admin','DW_CPQ_API','Truvio.Commerce.MCP',$mcpHost[0].id)) {
        if ($id -cnotin $map['Truvio.Commerce.CpqStudio'].dependsOn) { throw 'Studio dependency declaration is incomplete.' }
    }
    $assemblies = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($package in $Packages.packages) {
        if ($package.sha256 -eq ('sha256:' + ('0' * 64))) { throw 'Missing package digest.' }
        $uri = [uri]$package.source.uri
        if ($uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) { throw 'Package source must be an HTTPS identity without credentials, query or fragment.' }
        if ($package.source.kind -eq 'build' -and $package.source.commit -eq ('0' * 40)) { throw 'Missing source build identity.' }
        if (-not @($package.assemblies | Where-Object { $_.name.StartsWith($package.id, [StringComparison]::OrdinalIgnoreCase) }).Count) { throw 'Package and entry assembly identities do not match.' }
        foreach ($assembly in $package.assemblies) {
            $null = Get-CpqAssemblyEntry $assembly
            if (-not $assemblies.Add($assembly.name)) { throw 'Duplicate loaded assembly identity.' }
            if ($assembly.sha256 -eq ('sha256:' + ('0' * 64))) { throw 'Missing assembly digest.' }
        }
        foreach ($dependency in $package.dependsOn) { if (-not $map.ContainsKey($dependency)) { throw 'Package dependency is not locked.' } }
        if ($package.ContainsKey('nugetDependencies')) {
            foreach ($dependency in $package.nugetDependencies) {
                if ($dependency -cnotin $package.dependsOn) { throw 'NuGet dependency is missing from the installation graph.' }
            }
        }
    }
    $done = @{}; $visiting = @{}
    function Visit-CpqPackage([string]$Id) {
        if ($done.ContainsKey($Id)) { return }
        if ($visiting.ContainsKey($Id)) { throw 'Package dependency cycle.' }
        $visiting[$Id] = $true
        foreach ($dependency in $map[$Id].dependsOn) { Visit-CpqPackage $dependency }
        $visiting.Remove($Id); $done[$Id] = $true
    }
    foreach ($id in $map.Keys) { Visit-CpqPackage $id }
    if (-not $assemblies.Contains('DocumentFormat.OpenXml')) { throw 'DOCX dependency identity is missing.' }
}

# Candidate evidence is not installable and has no roles, so Assert-CpqPackages does not apply. What is decidable
# offline still holds: the engine profile's identities and versions, the MCP floor, one assembly per name, an entry
# path that follows from the assembly name, well-formed digests, and installedMatchesPackage agreeing with them.
# The digest values themselves cannot be checked here: the repository holds no package bytes.
function Assert-CpqCandidatePackages {
    param([Parameter(Mandatory)]$Packages)
    $map = Get-CpqIdentityMap @($Packages.packages) 'id'
    foreach ($pin in @(@('CPQ_Admin','10.24.2'), @('DW_CPQ_API','10.24.2'), @('Truvio.Commerce.CpqStudio','0.7.0'))) {
        if (-not $map.ContainsKey($pin[0]) -or $map[$pin[0]].id -cne $pin[0] -or $map[$pin[0]].version -cne $pin[1]) { throw 'Candidate package identity/version differs from the declared engine profile.' }
    }
    if (-not $map.ContainsKey('Truvio.Commerce.MCP')) { throw 'Candidate MCP dependency identity is missing.' }
    $mcp = $map['Truvio.Commerce.MCP']
    foreach ($version in @($mcp.version) + @(if ($mcp.ContainsKey('minimumVersion')) { $mcp.minimumVersion })) {
        if ((Compare-CpqNuGetVersion $version '0.6.5-beta') -lt 0) { throw 'Candidate MCP dependency is below the Studio floor (0.6.5-beta).' }
    }
    if ($mcp.ContainsKey('minimumVersion') -and (Compare-CpqNuGetVersion $mcp.version $mcp.minimumVersion) -lt 0) { throw 'Candidate MCP dependency is below its own minimum version.' }
    $digest = '^sha256:(?!0{64}$)[a-f0-9]{64}$'
    $assemblies = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($package in $Packages.packages) {
        if ("$($package.packageSha256)" -cnotmatch $digest) { throw 'Candidate package digest is missing or malformed.' }
        if (-not @($package.assemblies | Where-Object { "$($_.name)".StartsWith($package.id, [StringComparison]::OrdinalIgnoreCase) }).Count) { throw 'Candidate package and entry assembly identities do not match.' }
        foreach ($assembly in $package.assemblies) {
            if (-not $assembly.name -or -not $assemblies.Add($assembly.name)) { throw 'Missing or duplicate candidate assembly identity.' }
            $name = [regex]::Escape($assembly.name)
            if ("$($assembly.entry)" -cnotmatch "^(?:Files/System/AddIns/Installed/$name/)?lib/net(?:standard|coreapp)?[0-9]+\.[0-9]+/$name\.dll$") { throw 'Candidate assembly entry differs from its name, TFM or supported add-in layout.' }
            if ("$($assembly.packageEntrySha256)" -cnotmatch $digest) { throw 'Candidate assembly digest is missing or malformed.' }
            if ($assembly.ContainsKey('installedSha256') -ne $assembly.ContainsKey('installedMatchesPackage')) { throw 'Candidate installed digest and installedMatchesPackage must appear together.' }
            if ($assembly.ContainsKey('installedSha256')) {
                if ("$($assembly.installedSha256)" -cnotmatch $digest) { throw 'Candidate assembly digest is missing or malformed.' }
                if ($assembly.installedMatchesPackage -isnot [bool] -or $assembly.installedMatchesPackage -ne ($assembly.installedSha256 -ceq $assembly.packageEntrySha256)) { throw 'Candidate installedMatchesPackage contradicts its digests.' }
            }
        }
    }
}

function Assert-CpqBehavior {
    param([Parameter(Mandatory)]$Behavior, [Parameter(Mandatory)]$Spec, [Parameter(Mandatory)]$Packages, [Parameter(Mandatory)][string]$ContractRoot)
    Assert-CpqSchema $Behavior (Join-Path $ContractRoot 'behavior.schema.json')
    if ($Behavior.engineProfile -cne $Spec.engineProfile -or $Behavior.engineProfile -cne $Packages.engineProfile) { throw 'CPQ engine profiles differ.' }
    if ($Behavior.specDigest -cne (Get-CpqDigest $Spec) -or $Behavior.packageLockDigest -cne (Get-CpqDigest $Packages)) { throw 'CPQ contract content digest differs.' }
    $cases = Get-CpqIdentityMap @($Spec.cases) 'id'
    $null = Get-CpqIdentityMap @($Behavior.checks) 'id'
    foreach ($check in $Behavior.checks) {
        if (-not $check.id.StartsWith($check.functionId + '.', [StringComparison]::Ordinal)) { throw 'Check/function ownership differs.' }
        foreach ($id in $check.caseIds) { if (-not $cases.ContainsKey($id)) { throw 'Behavior names an unknown case.' } }
    }
}

function Test-CpqLayerContract {
    param([Parameter(Mandatory)][string]$LayerRoot, [Parameter(Mandatory)]$Layer, [Parameter(Mandatory)][string]$ContractRoot, [switch]$ForDelivery)
    $probes = @($Layer.asserts.behaviorProbes | Where-Object { $_.kind -like 'cpq-*' })
    if (-not $Layer.ContainsKey('cpq')) {
        if ($probes.Count) { throw 'CPQ probe requires a layer CPQ declaration.' }
        return
    }
    Assert-CpqSchema $Layer.cpq (Join-Path $ContractRoot 'layer-declaration.schema.json')
    if ($Layer.kind -cne 'feature') { throw 'CPQ carriage must be a feature layer.' }
    $spec = Read-CpqJson (Resolve-CpqContractPath $LayerRoot $Layer.cpq.spec)
    $packages = Read-CpqJson (Resolve-CpqContractPath $LayerRoot $Layer.cpq.packages)
    $behavior = Read-CpqJson (Resolve-CpqContractPath $LayerRoot $Layer.cpq.behavior)
    Assert-CpqSpec $spec $ContractRoot
    if($Layer.cpq.status -ceq 'candidate'){
        if($Layer.version -notmatch '-candidate$'){throw 'Candidate layer requires a candidate version.'}
        Assert-CpqSchema $packages (Join-Path $ContractRoot 'packages-candidate.schema.json')
        Assert-CpqCandidatePackages $packages
        # The layer carries a copy of the shared candidate evidence; the two may not drift apart.
        $shared = Join-Path $ContractRoot 'packages.candidate.lock.json'
        if (-not (Test-Path -LiteralPath $shared -PathType Leaf) -or (Get-CpqDigest $packages) -cne (Get-CpqDigest (Read-CpqJson $shared))) {
            throw 'Candidate package lock differs from contracts/cpq/packages.candidate.lock.json.'
        }
        $null=Get-CpqIdentityMap @($Layer.cpq.blockers) 'id'
        $paths=$Layer.cpq.candidateArtifacts
        $compiled=Read-CpqJson (Resolve-CpqContractPath $LayerRoot $paths.compiled)
        $identity=Read-CpqJson (Resolve-CpqContractPath $LayerRoot $paths.identityMap)
        $cases=Read-CpqJson (Resolve-CpqContractPath $LayerRoot $paths.cases)
        $content=Read-CpqJson (Resolve-CpqContractPath $LayerRoot $paths.content)
        $fresh=ConvertTo-CpqCandidate $spec $ContractRoot $identity
        if((Get-CpqDigest $compiled) -cne (Get-CpqDigest $fresh) -or (Get-CpqDigest $identity) -cne (Get-CpqDigest $fresh.identityMap)){throw 'Candidate compiler artifacts are stale or altered.'}
        if($cases.modelKey -cne $spec.id -or (Get-CpqDigest $cases.cases) -cne (Get-CpqDigest $spec.cases)){throw 'Candidate case fixtures differ from the spec.'}
        if($content.status -cne 'candidate' -or $content.applyAllowed -ne $false -or $content.modelKey -cne $spec.id){throw 'Candidate content plan must be non-executable and model-bound.'}
        foreach($key in @('catalogue','context','page','output')){if((Get-CpqDigest $content[$key]) -cne (Get-CpqDigest $spec[$key])){throw 'Candidate content intent differs from the spec.'}}

        if($ForDelivery){throw ('CPQ candidate refused for delivery: '+(($Layer.cpq.blockers | ForEach-Object { $_.id+': '+$_.reason }) -join '; '))}
    } else {
        if($Layer.version -match '-candidate$'){throw 'Candidate version requires candidate status.'}
        Assert-CpqPackages $packages $ContractRoot
    }
    Assert-CpqBehavior $behavior $spec $packages $ContractRoot
    if ($probes.Count -ne 1 -or $probes[0].kind -cne 'cpq-contract-v1' -or $probes[0].contract -cne $Layer.cpq.behavior) { throw 'Layer requires one matching CPQ behavior probe.' }
    if ($probes[0].ContainsKey('renderProof') -and -not $probes[0].renderProof) { throw 'CPQ render proof cannot be disabled.' }
    if ($probes[0].ContainsKey('requiresFixtures')) { throw 'CPQ fixtures must not be skipped with sampleData false.' }
    foreach ($check in $behavior.checks) { if ($check.functionId -cnotin @($Layer.ledger.provides)) { throw 'CPQ check has no layer provider.' } }
}
