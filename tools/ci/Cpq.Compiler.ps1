<#
.SYNOPSIS
Compile a portable CPQ spec to deterministic candidate rows. No target access or apply.
.DESCRIPTION
PowerShell 7; requires Cpq.Contracts.ps1. See contracts/cpq/compiler.md.
Native JSON is an authoring candidate, not engine certification. Requirements without a
proven native mapping stay explicit in deliveryRequirements and block an executable plan.
.EXAMPLE
$candidate = ConvertTo-CpqCandidate -Spec $spec -ContractRoot ./contracts/cpq
#>
#Requires -Version 7.0
function ConvertTo-CpqNativeValue {
    param([AllowNull()]$Value)
    if($Value -is [array]){return ,@(foreach($v in $Value){ConvertTo-CpqNativeValue $v})}
    if($Value -is [string] -and $Value.StartsWith('$')){
        if($Value -cmatch '^\$input\.([A-Za-z][A-Za-z0-9_-]*)$'){return 'formInput['+$Matches[1]+']'}
        throw 'Unsupported compiler reference.'
    }
    return ,$Value
}
function ConvertTo-CpqCondition {
    param($Condition)
    if(-not $Condition){return ,@()}
    $op=@($Condition.Keys)[0]
    if($op -in @('and','or')){
        $children=@(foreach($child in $Condition[$op]){ConvertTo-CpqCondition $child})
        return @{group_operator=$op.ToUpperInvariant();$op=$children}
    }
    if($op -ceq 'hasvalue'){return ,@((ConvertTo-CpqNativeValue $Condition[$op]),'hasvalue','')}
    if($op -cnotin @('eq','neq','gt','gte','lt','lte','in','nin','contains','startswith','endswith')){throw 'Unsupported compiler condition.'}
    return ,@((ConvertTo-CpqNativeValue $Condition[$op][0]),$op,(ConvertTo-CpqNativeValue $Condition[$op][1]))
}
function ConvertTo-CpqConditionText {
    param($Condition)
    if(-not $Condition){return ''}
    $node=ConvertTo-CpqCondition $Condition
    if($node -isnot [Collections.IDictionary]){$node=@{group_operator='AND';and=@(,$node)}}
    return ConvertTo-CpqCanonicalJson @(,$node)
}
function ConvertTo-CpqActions {
    param([object[]]$Actions,$Inputs)
    $out=[Collections.Generic.List[object]]::new()
    foreach($action in $Actions){
        if($action.allowOptions){
            $a=$action.allowOptions;$all=@($Inputs[$a.input].options.value)
            if(@($all | Where-Object {$_ -isnot [string]}).Count){throw 'allowOptions requires string option values in this adapter.'}
            $out.Add(@{action='enableoptions';target="formInput[$($a.input)]";options=@($a.values)})
            $excluded=@($all | Where-Object {$_ -cnotin $a.values})
            if($excluded.Count){$out.Add(@{action='disableoptions';target="formInput[$($a.input)]";options=$excluded})}
        } elseif($action.set){
            $a=$action.set;$out.Add(@{action='setvalue';setvalue=@{"formInput[$($a.input)]"=(ConvertTo-CpqNativeValue $a.value)}})
        } elseif($action.properties){
            $a=$action.properties;$values=@{}
            foreach($k in @('visible','enabled','required','readOnly')){if($a.ContainsKey($k)){$values["formInput[$($a.input).$($k.ToLowerInvariant())]"]=$a[$k]}}
            $out.Add(@{action='setvalue';setvalue=$values})
        } else {throw 'Unsupported compiler action.'}
    }
    return ,$out.ToArray()
}
function ConvertTo-CpqCandidate {
    param($Spec,[string]$ContractRoot,$IdentityMap)
    Assert-CpqSpec $Spec $ContractRoot
    if($Spec.lookups.Count -gt 0 -or $Spec.variables.Count -gt 0){throw 'Typed lookup and variable compilation is not characterized; preserve the spec for review.'}
    if($Spec.pricing.additionalMarkupPercent -ne '0'){throw 'Nonzero margin grammar is not characterized.'}
    if(@($Spec.inputs | Where-Object {$_.type -cnotin @('radiobox','select','number','text')}).Count){throw 'Input type has no reviewed compiler mapping.'}
    if($Spec.output.routing -or $Spec.output.visual3d -or $Spec.context.erp -cne 'none'){throw 'Unsupported engine profile extension.'}
    if($Spec.id.Length -gt 50 -or @($Spec.groups | Where-Object {$_.key.Length -gt 100 -or $_.label.Length -gt 500 -or $_.key -in @('Compiler_InputRules','Compiler_BOM')}).Count){throw 'Model/group identity exceeds native bounds or collides with a reserved compiler group.'}
    $entries=@{}
    if($IdentityMap){
        if($IdentityMap.schemaVersion -ne 1 -or $IdentityMap.modelKey -cne $Spec.id -or $IdentityMap.entries -isnot [Collections.IDictionary]){throw 'Identity map belongs to another model or contract.'}
        foreach($key in $IdentityMap.entries.Keys){
            $id=$IdentityMap.entries[$key]
            if($id -isnot [long] -and $id -isnot [int]){throw 'Identity map requires integer IDs.'}
            if($id -lt 100000 -or $id -gt [int]::MaxValue -or $id -in $entries.Values){throw 'Invalid or colliding identity map.'}
            $entries[$key]=$id
        }
    }
    function Get-CompiledId([string]$Table,[string]$Key,[switch]$Model){
        $scope=if($Model){'model'}else{'v'+$Spec.version}
        $symbol="$Table/$scope/$Key"
        if(-not $entries.ContainsKey($symbol)){
            $bytes=[Text.Encoding]::UTF8.GetBytes($Spec.id+'/'+$symbol)
            $hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))
            $id=[int](100000+([Convert]::ToUInt32($hash.Substring(0,8),16)%1000000000))
            if($id -in $entries.Values){throw 'Deterministic identity collision; supply a reviewed explicit identity map.'}
            $entries[$symbol]=$id
        }
        return $entries[$symbol]
    }
    $rows=[Collections.Generic.List[object]]::new()
    function Add-CompiledRow([string]$Table,[string]$Key,[string]$IdColumn,$Values,[switch]$Model){
        $id=Get-CompiledId $Table $Key -Model:$Model;$Values[$IdColumn]=$id
        $rows.Add(@{table=$Table;id=$id;values=$Values});return $id
    }
    $modelId=Add-CompiledRow CPQModel $Spec.id ModelId @{ModelName=$Spec.id;ModelDefault=$false;ModelDescription='';ModelSeq=0} -Model
    $versionId=Add-CompiledRow CPQModelVersion version ModelVersionId @{ModelVersionModelId=$modelId;ModelVersionNumber=[string]$Spec.version;ModelVersionDescription='';ModelVersionActive=$false;ModelVersionSetting=''}
    $groupIds=@{}
    foreach($group in $Spec.groups | Sort-Object order,key){
        $groupIds[$group.key]=Add-CompiledRow CPQGroup ('input/'+$group.key) GroupId @{GroupModelVersionId=$versionId;GroupMode='input';GroupParentId='0';GroupName=$group.key;GroupLabel=$group.label;GroupSeq=$group.order;GroupEnabled=$true;GroupArray=$false;GroupTable=$false;GroupCondition=''}
    }
    $inputs=Get-CpqIdentityMap @($Spec.inputs)
    $limits=[Collections.Generic.List[object]]::new()
    $inputSequence=0
    foreach($input in $Spec.inputs){
        $inputSequence++
        if($input.key.Length -gt 100 -or @($input.options | Where-Object {$null -ne $_ -and $_.value -isnot [string]}).Count){throw 'Input identity or option value has no supported native storage mapping.'}
        $settings=[Collections.Generic.List[object]]::new()
        foreach($key in @('min','max','step')){if($input.ContainsKey($key)){$settings.Add(@{name=$key;value=[string]$input[$key];type='string'})}}
        if($input.type -in @('select','radiobox')){$settings.Add(@{name='option-columns';value=[string]$Spec.page.optionColumns;type='string'})}
        $options=@(foreach($option in $input.options){
            $o=@{value=$option.value;label=$option.label;seq=1+[array]::IndexOf($input.options,$option);disabled=$false;visible=$true}
            if($option.ContainsKey('image')){$o.image=$option.image};$o
        })
        $label=if($input.label){$input.label}else{$input.key}
        $values=@{InputGroupId=$groupIds[$input.group];InputName=$input.key;InputLabel=$label;InputType=$input.type;InputEnabled=$true;InputRequired=($input.required -eq $true);InputVisible=$true;InputReadOnly=$false;InputSeq=$inputSequence;InputDefaultValue='';InputOptions=(ConvertTo-CpqCanonicalJson $options);InputSettings=(ConvertTo-CpqCanonicalJson $settings.ToArray());InputDataSource='';InputDataParameters=''}
        if($input.ContainsKey('default')){
            if($input.default -is [array] -or $input.default -is [bool] -or $null -eq $input.default){throw 'Array/boolean/null default has no characterized storage mapping.'}
            if($input.default -is [string] -and $input.default.StartsWith('$')){throw 'Default references are literals in this engine; use literal values explicitly.'}
            $values.InputDefaultValue=[string]$input.default
        }
        $null=Add-CompiledRow CPQInput $input.key InputId $values
        $limit=@{input=$input.key;required=($input.required -eq $true)}
        foreach($k in @('min','max','step','maxLength','use')){if($input.ContainsKey($k)){$limit[$k]=$input[$k]}}
        $limits.Add($limit)
    }
    if($Spec.inputRules.Count -gt 0){
        $gid=Add-CompiledRow CPQGroup rules GroupId @{GroupModelVersionId=$versionId;GroupMode='input_rule';GroupParentId='0';GroupName='Compiler_InputRules';GroupLabel='Input rules';GroupSeq=10000;GroupEnabled=$true;GroupArray=$false;GroupTable=$false;GroupCondition=''}
        foreach($rule in $Spec.inputRules | Sort-Object order,id){
            $null=Add-CompiledRow CPQInputRule $rule.id InputRuleId @{InputRuleGroupId=$gid;InputRuleType='CPQOptions';InputRuleDescription=$rule.id;InputRuleEnabled=$true;InputRuleStop=$false;InputRuleSeq=$rule.order;InputRuleConditions=(ConvertTo-CpqConditionText $rule.when);InputRuleActions=(ConvertTo-CpqCanonicalJson (ConvertTo-CpqActions @($rule.then) $inputs));InputRuleActionsElse=(ConvertTo-CpqCanonicalJson (ConvertTo-CpqActions @($rule.else) $inputs))}
        }
    }
    $gid=Add-CompiledRow CPQGroup bom GroupId @{GroupModelVersionId=$versionId;GroupMode='bom_rule';GroupParentId='0';GroupName='Compiler_BOM';GroupLabel='BOM';GroupSeq=10001;GroupEnabled=$true;GroupArray=$false;GroupTable=$false;GroupCondition=''}
    $sequence=0
    foreach($rule in $Spec.bom){
        $sequence++;$qty=ConvertTo-CpqNativeValue $rule.quantity
        $line=@{no=$rule.sku;qty=[string]$qty;type='Item'}
        $null=Add-CompiledRow CPQBOMRule $rule.id BOMRuleId @{BOMRuleGroupId=$gid;BOMRuleDescription=$rule.id;BOMRuleEnabled=$true;BOMRuleSeq=$sequence;BOMRuleConditions=(ConvertTo-CpqConditionText $rule.when);BOMRuleBomItems=(ConvertTo-CpqCanonicalJson @(,$line))}
    }
    foreach($rule in $Spec.pricing.rules | Sort-Object order,id){
        $null=Add-CompiledRow CPQPriceRule $rule.id CPQPriceRuleId @{CPQPriceRuleModelVersionId=$versionId;Description=$rule.id;Enabled=$true;CPQPriceRuleSort=$rule.order;Conditions=(ConvertTo-CpqConditionText $rule.when);Margin='';Discount=$rule.discountPercent;DiscountType='Percent'}
    }
    $requirements=@(
        @{kind='server-validation';status='unresolved';constraints=@($Spec.constraints);inputs=$limits.ToArray()},
        @{kind='price-context-and-engine';status='unresolved';context=$Spec.context;pricing=$Spec.pricing;catalogue=$Spec.catalogue},
        @{kind='page-and-theme';status='unresolved';modelVersionId=$versionId;page=$Spec.page},
        @{kind='persistence-and-output';status='unresolved';output=$Spec.output},
        @{kind='engine-golden-cases';status='unresolved';cases=$Spec.cases}
    )
    return @{schemaVersion=1;kind='cpq-compiler-candidate';compiler='cpq-native/v1';modelKey=$Spec.id;specVersion=$Spec.version;specDigest=(Get-CpqDigest $Spec);modelId=$modelId;modelVersionId=$versionId;identityMap=@{schemaVersion=1;modelKey=$Spec.id;entries=$entries};rows=$rows.ToArray();deliveryRequirements=$requirements;applyAllowed=$false}
}
