# Debug script to analyze the full approval rule structure
$groupId = '52b57f7b-614b-4f3b-9027-0619eba418f6'

# Get the policy for the member role
$memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$groupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
$policyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
$policyId = $policyResponse.value[0].policyId

# Get the policy details with rules
$policyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)?`$expand=rules"
$policy = Invoke-MgGraphRequest -Method GET -Uri $policyDetailUri

# Find the approval rule
$approvalRule = $policy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }

Write-Host "Full approval rule structure:" -ForegroundColor Green
$approvalRule | ConvertTo-Json -Depth 10

Write-Host "`n`nTrying PATCH with ONLY the setting (not wrapped in object)..." -ForegroundColor Yellow

$habibId = '15538e7c-80e3-4723-8745-71569c6de58c'
$ruleId = $approvalRule.id

# Add Habib
$newApprover = @{
    '@odata.type' = '#microsoft.graph.singleUser'
    'id' = $habibId
    'isBackup' = $false
}

$approvalRule.setting.approvalStages[0].primaryApprovers += $newApprover

# Try just sending the setting directly
$updateUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)/rules/$($ruleId)"
$updateBody = $approvalRule.setting | ConvertTo-Json -Depth 10

Write-Host "Request body:`n$updateBody`n"

try {
    $result = Invoke-MgGraphRequest -Method PATCH -Uri $updateUri -Body $updateBody -ContentType 'application/json' -ErrorAction Stop
    Write-Host "✓ Success!" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
}
