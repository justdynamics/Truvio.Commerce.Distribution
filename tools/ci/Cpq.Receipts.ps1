<#
.SYNOPSIS
READ-ONLY. Check CPQ evidence binding, completeness and freshness against trusted run facts.
.DESCRIPTION
PowerShell 7. Requires Cpq.Contracts.ps1. This does not execute CPQ checks or turn a
structurally valid receipt into PASS. The caller supplies facts and a receipt digest from
the trusted measurement record, never from the untrusted receipt itself. No target writes.
Every row payload is validated against contracts/cpq/observation.schema.json, the same file
the producer validates on write. A PASS needs an implemented ledger binding in the locked
skills snapshot (Resolve-CpqReaderVerdict); a planned or absent binding never yields PASS.
.EXAMPLE
Assert-CpqReceipt -Receipt $receipt -Context $facts -Behavior $behavior -Spec $spec `
  -Packages $packages -ExpectedReceiptDigest $recordDigest -NotBefore $deliveryTime `
  -Now $clock -ContractRoot ./contracts/cpq
#>
#Requires -Version 7.0

# The one place that says which experiment step a check is judged on. The producer writes it
# into the row payload and the reader refuses a row that names another one.
function Get-CpqCheckOperation {
    param([Parameter(Mandatory)][string]$FunctionId)
    switch -CaseSensitive ($FunctionId) {
        'cpq.page' { return 'render' }
        'cpq.persistence' { return 'reopen' }
        'cpq.revisions' { return 'revision' }
        'cpq.cart' { return 'cart' }
        'cpq.quotes' { return 'quote' }
        'cpq.documents' { return 'document' }
        default { return 'recalculate' }
    }
}

# What the row's own step journal supports, compared with the independent case expectation.
# This never reads the row's label. UNVERIFIED means the journal cannot decide.
function Get-CpqObservationVerdict {
    param([Parameter(Mandatory)]$Row, [Parameter(Mandatory)]$Case, [Parameter(Mandatory)]$Spec)
    $operation = $Row.observed.operation
    if (-not $Row.observed.steps.Contains($operation)) { return 'UNVERIFIED' }
    $step = $Row.observed.steps[$operation]
    if ($step.result -cne 'PASS') { return $step.result }
    $seen = $step.observed
    if ($operation -ceq 'render') {
        foreach ($key in @('rendered', 'dwErrors', 'theme')) { if (-not $seen.Contains($key)) { return 'UNVERIFIED' } }
        if ($seen.rendered -ne $true -or $seen.dwErrors -ne 0 -or $seen.theme -cne $Spec.page.theme) { return 'FAIL' }
        return 'PASS'
    }
    if ($operation -cne 'document') {
        if (-not $seen.Contains('valid')) { return 'UNVERIFIED' }
        if ($seen.valid -ne $Case.expect.valid) { return 'FAIL' }
        if ($Case.expect.valid) {
            if (-not $seen.Contains('bom') -or -not $seen.Contains('sell')) { return 'UNVERIFIED' }
            if ((Get-CpqDigest $seen.bom) -cne (Get-CpqDigest $Case.expect.bom) -or $seen.sell -cne $Case.expect.sell) { return 'FAIL' }
            if ($operation -ceq 'recalculate' -and $Case.expect.Contains('beforeDiscount')) {
                if (-not $seen.Contains('beforeDiscount')) { return 'UNVERIFIED' }
                if ($seen.beforeDiscount -cne $Case.expect.beforeDiscount) { return 'FAIL' }
            }
        }
    }
    if ($operation -cne 'recalculate') {
        # An invalid configuration must leave nothing behind; a valid one must be read back by its owner.
        if (-not $Case.expect.valid) { if ($seen.Contains('destinationId')) { return 'FAIL' } }
        elseif (-not $seen.Contains('destinationId') -or $seen.readBack -ne $true -or $seen.ownerVerified -ne $true) { return 'UNVERIFIED' }
    }
    return 'PASS'
}

# One row payload against contracts/cpq/observation.schema.json and the trusted run facts.
# The producer calls this on write and Assert-CpqReceipt calls it for every row on read.
function Assert-CpqObservationPayload {
    param(
        [Parameter(Mandatory)]$Row,
        [Parameter(Mandatory)]$Check,
        [Parameter(Mandatory)]$Case,
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)]$Spec,
        [Parameter(Mandatory)][string]$ContractRoot
    )
    if ($Row.observed -isnot [Collections.IDictionary]) { throw 'Receipt row has no payload object.' }
    Assert-CpqSchema $Row.observed (Join-Path $ContractRoot 'observation.schema.json')
    $payload = $Row.observed
    if ($payload.operation -cne (Get-CpqCheckOperation $Check.functionId)) { throw 'Receipt row payload names another operation than its check.' }
    $order = @('render', 'recalculate', 'save', 'reopen', 'revision', 'cart', 'quote', 'document')
    $count = @($payload.steps.Keys).Count
    for ($i = 0; $i -lt $order.Count; $i++) {
        $present = $payload.steps.Contains($order[$i])
        if ($present -ne ($i -lt $count)) { throw 'Receipt row step journal is not an unbroken prefix of the experiment order.' }
        if (-not $present) { continue }
        $step = $payload.steps[$order[$i]]
        if ($i -lt $count - 1 -and $step.result -cne 'PASS') { throw 'Receipt row step journal continues after a step that did not pass.' }
        if ($step.observed.hostId -cne $Context.hostId -or $step.observed.caseId -cne $Row.caseId -or
            $step.observed.modelVersionId -ne $Context.modelVersionId) { throw 'Receipt row step escaped its host, case or model version.' }
        if ($step.read.expectedSubjects -ne $step.read.observedSubjects) { throw 'Receipt row step read is incomplete.' }
    }
    $verdict = Get-CpqObservationVerdict $Row $Case $Spec
    if (($Row.result -ceq 'PASS' -and $verdict -cne 'PASS') -or
        ($verdict -cin @('FAIL', 'ERROR') -and $Row.result -cne $verdict)) { throw 'Receipt row label contradicts its own observation.' }
}

# The ledger binding that lets a receipt count, read from the edition's locked skills snapshot
# (Read-DistributionLedgerSnapshot). Anything but exactly one implemented receipt binding is not bound.
function Get-CpqReceiptBinding {
    param([Parameter(Mandatory)][string]$CheckId, $Snapshot)
    if (-not $Snapshot -or $Snapshot.checks -isnot [Collections.IDictionary] -or -not $Snapshot.checks.Contains($CheckId)) { return 'unbound' }
    $bindings = @(@($Snapshot.checks[$CheckId].bindings) | Where-Object { $_ -and $_.handler -ceq 'cpq-behavior-receipt' })
    if ($bindings.Count -ne 1 -or $bindings[0].surface -cne 'file') { return 'unbound' }
    if ($bindings[0].status -ceq 'implemented') { return 'implemented' }
    if ($bindings[0].status -ceq 'planned') { return 'planned' }
    return 'unbound'
}

# The consumer's verdict for one check. A reader's PASS stands only when the reader reports
# complete evidence AND the locked snapshot binds the check to an implemented receipt handler.
# FAIL and ERROR are kept whatever the binding says.
function Resolve-CpqReaderVerdict {
    param([Parameter(Mandatory)][string]$CheckId, $Observation, $Snapshot)
    $binding = Get-CpqReceiptBinding $CheckId $Snapshot
    $result = [string]$Observation.result
    if ($result -cnotin @('PASS', 'FAIL', 'ERROR', 'UNVERIFIED')) { $result = 'ERROR' }
    $complete = $Observation.complete -eq $true -and $binding -ceq 'implemented'
    if ($result -ceq 'PASS' -and -not $complete) { $result = 'UNVERIFIED' }
    return @{ id = $CheckId; result = $result; complete = $complete; binding = $binding }
}

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
        Assert-CpqObservationPayload -Row $row -Check $checks[$row.checkId] -Case $cases[$row.caseId] -Context $Context -Spec $Spec -ContractRoot $ContractRoot
    }
    if (-not $seen.SetEquals($expected)) { throw 'Receipt is missing required check/case observations.' }
    # Deliberately no readiness verdict. FAIL/ERROR/UNVERIFIED are valid report outcomes.
}
