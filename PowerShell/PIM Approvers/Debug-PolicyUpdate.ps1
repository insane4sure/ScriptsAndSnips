# Debug script to get actual error details from Microsoft Graph
$groupId = '52b57f7b-614b-4f3b-9027-0619eba418f6'

# Get the policy for the member role
$memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$groupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
$policyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
$policyId = $policyResponse.value[0].policyId
Write-Host "Policy ID: $policyId"

# Get the policy details with rules
$policyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)?`$expand=rules"
$policy = Invoke-MgGraphRequest -Method GET -Uri $policyDetailUri

# Find the approval rule
$approvalRule = $policy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
$ruleId = $approvalRule.id

Write-Host "Rule ID: $ruleId"
Write-Host "`nCurrent approval rule setting:`n"
$approvalRule.setting | ConvertTo-Json -Depth 10

$habibId = '15538e7c-80e3-4723-8745-71569c6de58c'

# Try PATCH with just the approvers arrays
Write-Host "`n`nTrying PATCH with modified structure..."

$updateUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)/rules/$($ruleId)"

# Add Habib
$newApprover = @{
    '@odata.type' = '#microsoft.graph.singleUser'
    'id' = $habibId
    'isBackup' = $false
}

$approvalRule.setting.approvalStages[0].primaryApprovers += $newApprover

# Send update and capture full error
$updateBody = @{
    setting = $approvalRule.setting
} | ConvertTo-Json -Depth 10

Write-Host "Request body (first 500 chars):`n$($updateBody.Substring(0, [Math]::Min(500, $updateBody.Length)))`n"

try {
    $result = Invoke-MgGraphRequest -Method PATCH -Uri $updateUri -Body $updateBody -ContentType 'application/json' -ErrorAction Stop
    Write-Host "Success!"
}
catch {
    Write-Host "Error details:"
    Write-Host $_.Exception.Message
    Write-Host "`nFull exception:"
    $_ | Select-Object -Property * | Format-List
}
