<#
.SYNOPSIS
READ-ONLY. Check CPQ evidence binding, completeness and freshness against trusted run facts.
.DESCRIPTION
PowerShell 7. Requires Cpq.Contracts.ps1. This does not execute CPQ checks or turn a
structurally valid receipt into PASS. The caller supplies facts and a receipt digest from
the trusted measurement record, never from the untrusted receipt itself. No target writes.
.EXAMPLE
Assert-CpqReceipt -Receipt $receipt -Context $facts -Behavior $behavior -Spec $spec `
  -Packages $packages -ExpectedReceiptDigest $recordDigest -NotBefore $deliveryTime `
  -Now $clock -ContractRoot ./contracts/cpq
#>
#Requires -Version 7.0

function Assert-CpqReceipt {
    param(
        [Parameter(Mandatory)]$Receipt,
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Behavior,
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)]$Packages,
        [Parameter(Mandatory)][string]$ExpectedReceiptDigest,
        [Parameter(Mandatory)][datetimeoffset]$NotBefore,
        [Parameter(Mandatory)][datetimeoffset]$Now,
        [Parameter(Mandatory)][string]$ContractRoot
    )
    Assert-CpqSpec $Spec $ContractRoot
    Assert-CpqPackages $Packages $ContractRoot
    Assert-CpqBehavior $Behavior $Spec $Packages $ContractRoot
    Assert-CpqSchema $Context (Join-Path $ContractRoot 'context.schema.json')
    Assert-CpqSchema $Receipt (Join-Path $ContractRoot 'receipt.schema.json')
    if ($ExpectedReceiptDigest -cnotmatch '^sha256:[a-f0-9]{64}$' -or
        $ExpectedReceiptDigest -cne (Get-CpqDigest $Receipt)) { throw 'Receipt digest differs from the trusted record.' }
    $expectedContext = ConvertTo-CpqCanonicalJson $Context
    if ((ConvertTo-CpqCanonicalJson $Receipt.before) -cne $expectedContext -or
        (ConvertTo-CpqCanonicalJson $Receipt.after) -cne $expectedContext) { throw 'Receipt target, release, lock or before/after identity differs.' }
    if ($Context.specDigest -cne (Get-CpqDigest $Spec) -or
        $Context.packageLockDigest -cne (Get-CpqDigest $Packages) -or
        $Context.behaviorDigest -cne (Get-CpqDigest $Behavior) -or
        $Context.catalogueDigest -cne (Get-CpqDigest $Spec.catalogue) -or
        $Context.modelKey -cne $Spec.id) { throw 'Receipt context does not bind the supplied CPQ content.' }
    foreach ($hash in @($Context.modelDigest, $Context.ledger.digest)) {
        if ($hash -eq ('sha256:' + ('0' * 64))) { throw 'Missing measured model or ledger identity.' }
    }
    foreach ($sha in @($Context.distributionCommit, $Context.ledger.commit)) {
        if ($sha -eq ('0' * 40)) { throw 'Missing delivery or ledger commit identity.' }
    }
    $expectedAssemblies = @{}
    foreach ($package in $Packages.packages) {
        foreach ($assembly in $package.assemblies) {
            $identity = @{
                packageId=$package.id; packageVersion=$package.version; name=$assembly.name
                version=$assembly.version; tfm=$assembly.tfm; sha256=$assembly.sha256
            }
            $expectedAssemblies[$assembly.name] = ConvertTo-CpqCanonicalJson $identity
        }
    }
    $actualAssemblies = Get-CpqIdentityMap @($Context.loadedAssemblies) 'name'
    if ($actualAssemblies.Count -ne $expectedAssemblies.Count) { throw 'Loaded assembly inventory is incomplete.' }
    foreach ($name in $expectedAssemblies.Keys) {
        if (-not $actualAssemblies.ContainsKey($name) -or
            (ConvertTo-CpqCanonicalJson $actualAssemblies[$name]) -cne $expectedAssemblies[$name]) { throw 'Loaded assembly differs from the package lock.' }
    }
    try {
        $started = [datetimeoffset]::Parse($Receipt.startedAt, [Globalization.CultureInfo]::InvariantCulture)
        $completed = [datetimeoffset]::Parse($Receipt.completedAt, [Globalization.CultureInfo]::InvariantCulture)
    } catch { throw 'Receipt timestamp is invalid.' }
    if ($NotBefore -gt $Now -or $started -lt $NotBefore -or $completed -lt $started -or
        $completed -gt $Now -or ($Now - $started).TotalSeconds -gt $Behavior.maxAgeSeconds) { throw 'Receipt is stale, future-dated or outside this delivery.' }
    $cases = Get-CpqIdentityMap @($Spec.cases) 'id'
    $checks = Get-CpqIdentityMap @($Behavior.checks) 'id'
    $expected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($check in $Behavior.checks) {
        if ($check.id -cnotin @($Context.ledger.checkIds)) { throw 'Behavior check is outside the ledger lock.' }
        foreach ($id in $check.caseIds) { $null = $expected.Add($check.id + '/' + $id) }
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in $Receipt.observations) {
        $pair = $row.checkId + '/' + $row.caseId
        if (-not $expected.Contains($pair) -or -not $seen.Add($pair)) { throw 'Receipt has an unexpected or duplicate check/case identity.' }
        if ($row.inputDigest -cne (Get-CpqDigest $cases[$row.caseId].answers) -or
            $row.expectationDigest -cne (Get-CpqDigest $cases[$row.caseId].expect)) { throw 'Receipt input or expectation differs from the declared case.' }
        if ($row.read.expectedSubjects -ne $row.read.observedSubjects -or
            $row.read.observedSubjects -lt $checks[$row.checkId].minimumSubjects) { throw 'Receipt read is incomplete or below the required scope.' }
    }
    if (-not $seen.SetEquals($expected)) { throw 'Receipt is missing required check/case observations.' }
    # Deliberately no readiness verdict. FAIL/ERROR/UNVERIFIED are valid report outcomes.
}
