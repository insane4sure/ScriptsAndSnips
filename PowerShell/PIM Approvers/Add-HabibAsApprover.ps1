# Script to add Habib Rahman as an approver to PIM groups where Jennifer Graham is an approver

$habibId = '15538e7c-80e3-4723-8745-71569c6de58c'
$jenniferEmail = 'Jennifer.Graham@saberin.com'

# PIM groups where Jennifer is an individual approver
$pimGroups = @(
    @{Name='SG-PIM-RG-ATLWEB'; Id='52b57f7b-614b-4f3b-9027-0619eba418f6'},
    @{Name='SG-Client_BWT-AWS-Prod'; Id='46c36cc7-be1d-4788-98a4-8d1b716768cc'},
    @{Name='SG-PIM-App-SaberinDevAWS-Admin'; Id='f22e6268-8466-4ead-ac2b-f401c06b064b'},
    @{Name='SG-PIM-App-SaberinDataToolsForLPC-CT'; Id='a8338c62-f165-489f-b9dd-fa76dde2e96a'}
)

Write-Host "Adding Habib Rahman as approver to $($pimGroups.Count) PIM groups..." -ForegroundColor Cyan

foreach ($pimGroup in $pimGroups) {
    Write-Host "`nProcessing: $($pimGroup.Name)..." -ForegroundColor Yellow
    
    try {
        # Get the member role policy assignment
        $memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$($pimGroup.Id)' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
        $policyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
        
        if ($policyResponse.value.Count -eq 0) {
            Write-Host "  No policy found for this group" -ForegroundColor Red
            continue
        }
        
        $policyId = $policyResponse.value[0].policyId
        Write-Host "  Policy ID: $policyId" -ForegroundColor Gray
        
        # Get the full policy with rules
        $policyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$policyId?`$expand=rules"
        $policy = Invoke-MgGraphRequest -Method GET -Uri $policyDetailUri
        
        # Find the approval rule
        $approvalRule = $policy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
        
        if (-not $approvalRule) {
            Write-Host "  No approval rule found" -ForegroundColor Red
            continue
        }
        
        # Check if Habib is already in the approvers list
        $habibExists = $false
        foreach ($stage in $approvalRule.setting.approvalStages) {
            foreach ($approver in $stage.primaryApprovers) {
                if ($approver.id -eq $habibId) {
                    $habibExists = $true
                    break
                }
            }
        }
        
        if ($habibExists) {
            Write-Host "  Habib is already an approver for this group" -ForegroundColor Green
            continue
        }
        
        # Add Habib to the primary approvers
        $newApprover = @{
            '@odata.type' = '#microsoft.graph.singleUser'
            'isBackup' = $false
            'id' = $habibId
            'description' = 'Habib Rahman'
        }
        
        foreach ($stage in $approvalRule.setting.approvalStages) {
            $stage.primaryApprovers += $newApprover
        }
        
        # Update the policy rule
        $updateUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$policyId/rules/$($approvalRule.id)"
        
        $body = @{
            '@odata.type' = $approvalRule.'@odata.type'
            'id' = $approvalRule.id
            'target' = $approvalRule.target
            'setting' = $approvalRule.setting
        } | ConvertTo-Json -Depth 10
        
        Invoke-MgGraphRequest -Method PATCH -Uri $updateUri -Body $body -ContentType 'application/json'
        Write-Host "  Successfully added Habib as approver!" -ForegroundColor Green
        
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nCompleted!" -ForegroundColor Cyan
Write-Host "`nNote: You'll need to manually remove Jennifer Graham from these approver lists later." -ForegroundColor Yellow
