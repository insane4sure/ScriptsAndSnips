# Script to get PIM approvers for all groups and generate a report

$groups = @(
    @{Name='SG_PIM_Role-GlobalAdmin'; Id='f033176c-6407-4730-bd73-8483d05f8e48'},
    @{Name='SG_PIM_Role-UserAdmin'; Id='d1e48010-224f-413c-9f75-eece1d5ca08f'},
    @{Name='SG_PIM_Role-SharePointAdmin'; Id='4ff19731-ce9f-4a6c-a98d-2a0af516d355'},
    @{Name='SG_PIM_Role-ExchangeAdmin'; Id='dc9fa670-60d6-4eb4-9622-901181c32329'},
    @{Name='SG_PIM_Role-IntuneAdmin'; Id='853ac8ad-6873-47c8-b0b8-7ffeb136738f'},
    @{Name='SG_PIM_Role-SecurityAdmin'; Id='b29acfd8-8c3c-44bb-8e6d-bc367b1a2a5d'},
    @{Name='SG_PIM_Role-ConditionalAccessAdmin'; Id='d736a658-c064-4772-8a6a-814cce494d51'},
    @{Name='SG_PIM_Role-EnterpriseApplicationAdmin'; Id='c7ff1ee1-daca-405a-8e78-71618397dff7'},
    @{Name='SG-PIM-RG-ATLWEB'; Id='52b57f7b-614b-4f3b-9027-0619eba418f6'},
    @{Name='SG_PIM-Visual-Studio-Owner'; Id='8caeecbd-dfbf-461d-a43e-4bec53aea90f'},
    @{Name='SG-PIM-App-SaberinRootAWS'; Id='3175281c-85d3-498c-bcfd-729418eaf75c'},
    @{Name='SG-PIM-HFT-CT-DevAdmin'; Id='0327f8a6-6138-4cef-8763-03cbcdfceec9'},
    @{Name='SG_PIM_SG_DevMachineAdmins'; Id='ccf0f752-a104-4f17-a2ee-b45feb145096'},
    @{Name='SG-PIM-ADO-AgentPool-SelfHostedAdministrator'; Id='6746715a-e1b9-469d-b054-feaff3e6e503'},
    @{Name='SG-PIM-Application Admin Proxy'; Id='73223b78-0e5e-47d0-80d4-73d36fb96b44'},
    @{Name='SG-PIM-App-SDP_ProdHostingAWS-Admin'; Id='583a10fb-cd91-4092-8112-3e1f1d7b4aec'},
    @{Name='SG-PIM-App-TPA-DEV-AWS-Admin'; Id='c6ac1c26-0180-4bce-ae16-306d4b57ecf4'},
    @{Name='SG-PIM-SDP-ADO-ProjectAdministrators'; Id='9ce83c09-0858-4086-ac1c-809ca5caa49c'},
    @{Name='SG-Client_BWT-AWS-Prod'; Id='46c36cc7-be1d-4788-98a4-8d1b716768cc'},
    @{Name='SG-PIM-App-BWT_PROD_AWS-Admin'; Id='2e7a4f86-141f-47ee-838e-04e1a7255ad0'},
    @{Name='SG-PIM-TPA-DEV-RG-Owner'; Id='c556a802-2113-4954-868e-8bb22b670b00'},
    @{Name='SG-PIM-ADO-HFT'; Id='edc7545e-da16-4988-8d65-762cd29ce088'},
    @{Name='sg-pim-sar-dev'; Id='91501802-28aa-4d96-947b-39c5fe1f5c16'},
    @{Name='SG-PIM-App-SaberinDevAWS-Admin'; Id='f22e6268-8466-4ead-ac2b-f401c06b064b'},
    @{Name='SG-PIM-App-SaberinHostingAWS-Admin'; Id='a0b86255-5fbd-4385-ab37-856e8ade5222'},
    @{Name='SG-PIM-App-SaberinDataToolsForLPC-CT'; Id='a8338c62-f165-489f-b9dd-fa76dde2e96a'},
    @{Name='sg-pim-rg-sdp-prod'; Id='bcc1f357-78b9-41d5-922f-2d28060fba8b'},
    @{Name='SG-PIM-PMS-Prod-Admins'; Id='d5c9d815-b3fd-4943-8102-89d1c15c351a'},
    @{Name='SG-PIM-HFT-DEV-OwnerAdmin'; Id='318aee9f-8f36-42d5-9401-2fccb99cb53e'},
    @{Name='SG-PIM-ADO-SAR'; Id='0e7c2ae7-c194-4a61-afa2-2b644a43def5'},
    @{Name='SG_PIM_Cloud Application Administrator'; Id='74510aa8-9010-4f6c-b1bd-92c9881e3041'},
    @{Name='SG_PIM_GlobalAdmin'; Id='f693de9f-d0f7-4590-87f7-4cc8e8869490'},
    @{Name='SG_SP_test_Admin'; Id='6cf13c1f-a1eb-456e-a087-a0d19077aab0'},
    @{Name='SG_SP_adv-shared_Admin'; Id='8aa5bb2b-0419-4152-80ca-3a9588a7eaf9'},
    @{Name='SG_SP_dma-shared-collaboration-rfp-data-room_Admin'; Id='1486b044-19cc-47b4-ba71-cf38eedb823b'}
)

$scriptPath = "$PSScriptRoot\GetPimApprovers.ps1"
$reportPath = "$PSScriptRoot\PIM-Approvers-Report.md"

# Initialize markdown report
$markdown = @"
# PIM Approvers Report
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Total Groups: $($groups.Count)

---

"@

Import-Module Microsoft.Graph.Identity.Governance -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.Groups -ErrorAction SilentlyContinue

# Connect once for all operations
$requiredScopes = @("RoleManagementPolicy.Read.AzureADGroup", "PrivilegedAccess.Read.AzureADGroup", "Group.Read.All", "User.Read.All")
$context = Get-MgContext

if ($null -eq $context -or ($requiredScopes | Where-Object { $_ -notin $context.Scopes }).Count -gt 0) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $requiredScopes -ErrorAction Stop
    Write-Host "Connected successfully!" -ForegroundColor Green
}

$counter = 0
foreach ($group in $groups) {
    $counter++
    Write-Host "[$counter/$($groups.Count)] Processing: $($group.Name)..." -ForegroundColor Cyan
    
    $markdown += "`n## $($group.Name)`n`n"
    $markdown += "**Group ID:** ``$($group.Id)```n`n"
    
    try {
        # Get group details
        $mgGroup = Get-MgGroup -GroupId $group.Id -ErrorAction Stop
        
        # Get policy assignments
        $memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$($group.Id)' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
        $ownerPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$($group.Id)' and scopeType eq 'Group' and roleDefinitionId eq 'owner'"
        
        # Process Member Role
        $markdown += "### Member Role`n`n"
        $memberPolicyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
        
        if ($memberPolicyResponse.value.Count -gt 0 -and $memberPolicyResponse.value[0].policyId) {
            $memberPolicyId = $memberPolicyResponse.value[0].policyId
            $memberPolicyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($memberPolicyId)?`$expand=rules"
            $memberPolicy = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyDetailUri
            
            $approvalRule = $memberPolicy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
            
            if ($approvalRule -and $approvalRule.setting.isApprovalRequired) {
                $markdown += "**Approval Required:** Yes`n`n"
                $markdown += "**Approval Stages:** $($approvalRule.setting.approvalStages.Count)`n`n"
                
                foreach ($stage in $approvalRule.setting.approvalStages) {
                    $markdown += "**Stage (Timeout: $($stage.approvalStageTimeOutInDays) days):**`n`n"
                    
                    if ($stage.primaryApprovers.Count -gt 0) {
                        $markdown += "Primary Approvers:`n"
                        foreach ($approver in $stage.primaryApprovers) {
                            switch ($approver.'@odata.type') {
                                '#microsoft.graph.singleUser' {
                                    $user = Get-MgUser -UserId $approver.id -ErrorAction SilentlyContinue
                                    $markdown += "- User: $($user.DisplayName) ($($user.UserPrincipalName))`n"
                                }
                                '#microsoft.graph.groupMembers' {
                                    $approverGroup = Get-MgGroup -GroupId $approver.id -ErrorAction SilentlyContinue
                                    $markdown += "- Group: $($approverGroup.DisplayName)`n"
                                }
                                '#microsoft.graph.requestorManager' {
                                    $markdown += "- Requestor's Manager`n"
                                }
                                default {
                                    $markdown += "- $($approver.'@odata.type')`n"
                                }
                            }
                        }
                    }
                    $markdown += "`n"
                }
            } else {
                $markdown += "**Approval Required:** No (Automatic activation)`n`n"
            }
        } else {
            $markdown += "No PIM policy configured`n`n"
        }
        
        # Process Owner Role
        $markdown += "### Owner Role`n`n"
        $ownerPolicyResponse = Invoke-MgGraphRequest -Method GET -Uri $ownerPolicyUri
        
        if ($ownerPolicyResponse.value.Count -gt 0 -and $ownerPolicyResponse.value[0].policyId) {
            $ownerPolicyId = $ownerPolicyResponse.value[0].policyId
            $ownerPolicyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($ownerPolicyId)?`$expand=rules"
            $ownerPolicy = Invoke-MgGraphRequest -Method GET -Uri $ownerPolicyDetailUri
            
            $approvalRule = $ownerPolicy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
            
            if ($approvalRule -and $approvalRule.setting.isApprovalRequired) {
                $markdown += "**Approval Required:** Yes`n`n"
                $markdown += "**Approval Stages:** $($approvalRule.setting.approvalStages.Count)`n`n"
                
                foreach ($stage in $approvalRule.setting.approvalStages) {
                    $markdown += "**Stage (Timeout: $($stage.approvalStageTimeOutInDays) days):**`n`n"
                    
                    if ($stage.primaryApprovers.Count -gt 0) {
                        $markdown += "Primary Approvers:`n"
                        foreach ($approver in $stage.primaryApprovers) {
                            switch ($approver.'@odata.type') {
                                '#microsoft.graph.singleUser' {
                                    $user = Get-MgUser -UserId $approver.id -ErrorAction SilentlyContinue
                                    $markdown += "- User: $($user.DisplayName) ($($user.UserPrincipalName))`n"
                                }
                                '#microsoft.graph.groupMembers' {
                                    $approverGroup = Get-MgGroup -GroupId $approver.id -ErrorAction SilentlyContinue
                                    $markdown += "- Group: $($approverGroup.DisplayName)`n"
                                }
                                '#microsoft.graph.requestorManager' {
                                    $markdown += "- Requestor's Manager`n"
                                }
                                default {
                                    $markdown += "- $($approver.'@odata.type')`n"
                                }
                            }
                        }
                    }
                    $markdown += "`n"
                }
            } else {
                $markdown += "**Approval Required:** No (Automatic activation)`n`n"
            }
        } else {
            $markdown += "No PIM policy configured`n`n"
        }
        
    } catch {
        $markdown += "**Error:** $($_.Exception.Message)`n`n"
        Write-Host "  Error processing group: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $markdown += "---`n`n"
}

# Save the report
$markdown | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "`nReport generated: $reportPath" -ForegroundColor Green
