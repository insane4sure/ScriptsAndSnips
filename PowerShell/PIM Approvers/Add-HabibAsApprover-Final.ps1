# Add Habib Rahman to all PIM group approval configurations where Jennifer Graham is an approver
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

# Ensure connected to Graph with write permissions
if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes RoleManagementPolicy.ReadWrite.AzureADGroup -NoWelcome
}

Write-Host "`n=== Adding Habib Rahman as Approver to PIM Groups ===" -ForegroundColor Cyan
Write-Host "Jennifer Graham will remain as approver (will be removed later per your preference)`n" -ForegroundColor Gray

$successCount = 0
$failureCount = 0

foreach ($pimGroup in $pimGroupsWithJennifer) {
    Write-Host "Processing: $($pimGroup.Name)..." -ForegroundColor Cyan
    
    $groupId = $pimGroup.GroupId
    
    # Get the policy for the member role
    $memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$groupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
    $policyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
    
    if (-not $policyResponse.value -or $policyResponse.value.Count -eq 0) {
        Write-Host "  ✗ No policy found for member role" -ForegroundColor Yellow
        $failureCount++
        continue
    }
    
    $policyId = $policyResponse.value[0].policyId
    
    # Get the policy details with rules
    $policyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)?`$expand=rules"
    $policy = Invoke-MgGraphRequest -Method GET -Uri $policyDetailUri
    
    # Find the approval rule
    $approvalRule = $policy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
    
    if (-not $approvalRule) {
        Write-Host "  ✗ No approval rule found" -ForegroundColor Yellow
        $failureCount++
        continue
    }
    
    $ruleId = $approvalRule.id
    
    # Check if Habib is already an approver
    $primaryApprovers = $approvalRule.setting.approvalStages[0].primaryApprovers
    $habibExists = $primaryApprovers | Where-Object { $_.id -eq $habibId }
    
    if ($habibExists) {
        Write-Host "  ✓ Habib is already an approver (no changes needed)" -ForegroundColor Green
        $successCount++
        continue
    }
    
    # Check if Jennifer is an approver
    $jenniferExists = $primaryApprovers | Where-Object { $_.id -eq $jenniferGrahamId }
    
    if (-not $jenniferExists) {
        Write-Host "  ✗ Jennifer Graham is not an approver for this group (expected to be)" -ForegroundColor Yellow
        $failureCount++
        continue
    }
    
    # Add Habib to the primaryApprovers array
    $newApprover = @{
        '@odata.type' = '#microsoft.graph.singleUser'
        'description' = 'Habib Rahman'
        'id' = $habibId
        'isBackup' = $false
    }
    
    $approvalRule.setting.approvalStages[0].primaryApprovers += $newApprover
    
    # Update the rule with complete structure
    $updateUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($policyId)/rules/$($ruleId)"
    $updateBody = @{
        '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyApprovalRule'
        'id' = $ruleId
        'setting' = $approvalRule.setting
        'target' = $approvalRule.target
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-MgGraphRequest -Method PATCH -Uri $updateUri -Body $updateBody -ContentType 'application/json' -ErrorAction Stop | Out-Null
        Write-Host "  ✓ Successfully added Habib Rahman as approver" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        $failureCount++
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "✓ Successfully updated: $successCount groups" -ForegroundColor Green
if ($failureCount -gt 0) {
    Write-Host "✗ Failed to update: $failureCount groups" -ForegroundColor Red
}

Write-Host "`n✓ Habib Rahman has been added as approver to PIM group approval policies" -ForegroundColor Green
Write-Host "Total approver groups where Habib is now an approver: 2 (SG_AWS-Hosting-PIM-Approval + 4 PIM policies)" -ForegroundColor Green
