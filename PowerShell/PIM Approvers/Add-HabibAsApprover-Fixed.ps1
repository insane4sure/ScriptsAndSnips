# Add Habib Rahman to PIM approval configurations where Jennifer Graham is an approver
# Jennifer Graham ID: 08407626-a333-4298-97be-2b6e346ce0dd
# Habib Rahman ID: 15538e7c-80e3-4723-8745-71569c6de58c

# PIM Groups where Jennifer is an individual approver (member role)
$pimGroupsWithJennifer = @(
    @{ Name = 'SG-PIM-RG-ATLWEB'; GroupId = '52b57f7b-614b-4f3b-9027-0619eba418f6' },
    @{ Name = 'SG-Client_BWT-AWS-Prod'; GroupId = '46c36cc7-be1d-4788-98a4-8d1b716768cc' },
    @{ Name = 'SG-PIM-App-SaberinDevAWS-Admin'; GroupId = 'f22e6268-8466-4ead-ac2b-f401c06b064b' },
    @{ Name = 'SG-PIM-App-SaberinDataToolsForLPC-CT'; GroupId = 'a8338c62-f165-489f-b9dd-fa76dde2e96a' }
)

$habibId = '15538e7c-80e3-4723-8745-71569c6de58c'
$jenniferGrahamId = '08407626-a333-4298-97be-2b6e346ce0dd'

# Ensure connected to Graph
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes RoleManagementPolicy.ReadWrite.AzureADGroup, Group.Read.All -NoWelcome
}

foreach ($pimGroup in $pimGroupsWithJennifer) {
    Write-Host "`nProcessing: $($pimGroup.Name)..." -ForegroundColor Cyan
    
    $groupId = $pimGroup.GroupId
    
    # Get the policy for the member role
    $memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$groupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
    $policyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
    
    if (-not $policyResponse.value -or $policyResponse.value.Count -eq 0) {
        Write-Host "  No policy found for member role" -ForegroundColor Yellow
        continue
    }
    
    $policyId = $policyResponse.value[0].policyId
    Write-Host "  Policy ID: $policyId"
    
    # Get the policy details with rules
    $policyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)?`$expand=rules"
    $policy = Invoke-MgGraphRequest -Method GET -Uri $policyDetailUri
    
    # Find the approval rule
    $approvalRule = $policy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
    
    if (-not $approvalRule) {
        Write-Host "  No approval rule found" -ForegroundColor Yellow
        continue
    }
    
    $ruleId = $approvalRule.id
    Write-Host "  Rule ID: $ruleId"
    
    # Check if Habib is already an approver
    $primaryApprovers = $approvalRule.setting.approvalStages[0].primaryApprovers
    $habibExists = $primaryApprovers | Where-Object { $_.id -eq $habibId }
    
    if ($habibExists) {
        Write-Host "  Habib is already an approver" -ForegroundColor Green
        continue
    }
    
    # Check if Jennifer is an approver
    $jenniferExists = $primaryApprovers | Where-Object { $_.id -eq $jenniferGrahamId }
    
    if (-not $jenniferExists) {
        Write-Host "  Jennifer Graham is not an approver for this group" -ForegroundColor Yellow
        continue
    }
    
    Write-Host "  Found Jennifer Graham as approver, adding Habib..." -ForegroundColor Yellow
    
    # Create the Habib approver object (same structure as existing approvers)
    $habibApprover = @{
        '@odata.type' = '#microsoft.graph.singleUser'
        'id' = $habibId
        'isBackup' = $false
    }
    
    # Add Habib to the primaryApprovers array
    $approvalRule.setting.approvalStages[0].primaryApprovers += $habibApprover
    
    # Update the rule
    $updateUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)/rules/$($ruleId)"
    
    $updateBody = @{
        setting = $approvalRule.setting
    } | ConvertTo-Json -Depth 10
    
    Write-Host "  Sending update..." -ForegroundColor Gray
    try {
        $updateResult = Invoke-MgGraphRequest -Method PATCH -Uri $updateUri -Body $updateBody -ContentType 'application/json'
        Write-Host "  ✓ Successfully added Habib Rahman as approver" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Response: $($_.Exception.Response.StatusCode)" -ForegroundColor Red
    }
}

Write-Host "`n✓ Habib Rahman addition process complete" -ForegroundColor Green
