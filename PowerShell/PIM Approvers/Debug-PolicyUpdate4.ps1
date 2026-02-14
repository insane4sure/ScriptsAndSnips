# Try PATCH with the complete rule structure (including @odata.type and id)
$groupId = '52b57f7b-614b-4f3b-9027-0619eba418f6'

$memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$groupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
$policyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
$policyId = $policyResponse.value[0].policyId

$policyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)?`$expand=rules"
$policy = Invoke-MgGraphRequest -Method GET -Uri $policyDetailUri

$approvalRule = $policy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
$ruleId = $approvalRule.id

Write-Host "Testing with complete rule structure..." -ForegroundColor Yellow

$habibId = '15538e7c-80e3-4723-8745-71569c6de58c'

# Add Habib WITH description
$newApprover = @{
    '@odata.type' = '#microsoft.graph.singleUser'
    'description' = 'Habib Rahman'
    'id' = $habibId
    'isBackup' = $false
}

$approvalRule.setting.approvalStages[0].primaryApprovers += $newApprover

# Send with the complete rule structure (including id and @odata.type)
$updateUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)/rules/$($ruleId)"
$updateBody = @{
    '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyApprovalRule'
    'id' = $ruleId
    'setting' = $approvalRule.setting
    'target' = $approvalRule.target
} | ConvertTo-Json -Depth 10

Write-Host "Request body (first 800 chars):`n$($updateBody.Substring(0, [Math]::Min(800, $updateBody.Length)))`n" -ForegroundColor Gray

try {
    $result = Invoke-MgGraphRequest -Method PATCH -Uri $updateUri -Body $updateBody -ContentType 'application/json' -ErrorAction Stop
    Write-Host "✓ Success! Habib has been added." -ForegroundColor Green
}
catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
