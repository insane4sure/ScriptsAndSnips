
<#
.SYNOPSIS
    Gets approvers for Azure AD Privileged Identity Management (PIM) Groups

.DESCRIPTION
    This script retrieves the approval settings and approvers for PIM-enabled groups in Azure AD.
    It uses Microsoft Graph API to fetch the policy information.

.PARAMETER GroupId
    The Object ID of the PIM-enabled group

.PARAMETER GroupName
    The display name of the PIM-enabled group (will search for it)

.EXAMPLE
    .\Get-PIMGroupApprovers.ps1 -GroupId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\Get-PIMGroupApprovers.ps1 -GroupName "Security Admins"

.NOTES
    Requires: Microsoft.Graph PowerShell module
    Install: Install-Module Microsoft.Graph -Scope CurrentUser
#>

[CmdletBinding(DefaultParameterSetName = 'ById')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ById')]
    [string]$GroupId,
    
    [Parameter(Mandatory = $true, ParameterSetName = 'ByName')]
    [string]$GroupName
)

# Check if Microsoft.Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Identity.Governance)) {
    Write-Error "Microsoft.Graph.Identity.Governance module is not installed. Install it with: Install-Module Microsoft.Graph.Identity.Governance -Scope CurrentUser"
    exit 1
}

# Import required modules
Import-Module Microsoft.Graph.Identity.Governance
Import-Module Microsoft.Graph.Groups

# Check if already connected to Microsoft Graph
$requiredScopes = @("RoleManagementPolicy.Read.AzureADGroup", "PrivilegedAccess.Read.AzureADGroup", "Group.Read.All", "User.Read.All")
$context = Get-MgContext
$needsConnection = $false

if ($null -eq $context) {
    $needsConnection = $true
    Write-Host "Not connected to Microsoft Graph." -ForegroundColor Yellow
} else {
    # Check if we have all required scopes
    $missingScopes = $requiredScopes | Where-Object { $_ -notin $context.Scopes }
    if ($missingScopes.Count -gt 0) {
        $needsConnection = $true
        Write-Host "Current connection missing required scopes: $($missingScopes -join ', ')" -ForegroundColor Yellow
    } else {
        Write-Host "Already connected to Microsoft Graph with required scopes." -ForegroundColor Green
    }
}

if ($needsConnection) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    try {
        Connect-MgGraph -Scopes $requiredScopes -ErrorAction Stop
        Write-Host "Connected successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit 1
    }
}

# If GroupName is provided, get the GroupId
if ($PSCmdlet.ParameterSetName -eq 'ByName') {
    Write-Host "Searching for group: $GroupName..." -ForegroundColor Cyan
    # Escape single quotes in the group name to prevent filter injection
    $escapedGroupName = $GroupName.Replace("'", "''")
    $group = Get-MgGroup -Filter "displayName eq '$escapedGroupName'" -ErrorAction SilentlyContinue
    
    if (-not $group) {
        Write-Error "Group '$GroupName' not found."
        exit 1
    }
    
    $GroupId = $group.Id
    Write-Host "Found group: $($group.DisplayName) (ID: $GroupId)" -ForegroundColor Green
}

# Get group details
Write-Host "`nRetrieving group information..." -ForegroundColor Cyan
try {
    $group = Get-MgGroup -GroupId $GroupId -ErrorAction Stop
    Write-Host "Group: $($group.DisplayName)" -ForegroundColor White
    Write-Host "Group ID: $GroupId" -ForegroundColor White
} catch {
    Write-Error "Failed to retrieve group: $_"
    exit 1
}

# Get PIM policy for the group
Write-Host "`nRetrieving PIM policy settings..." -ForegroundColor Cyan

try {
    # Get assignment policies
    $memberPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$GroupId' and scopeType eq 'Group' and roleDefinitionId eq 'member'"
    $ownerPolicyUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '$GroupId' and scopeType eq 'Group' and roleDefinitionId eq 'owner'"
    
    # Get member policy
    Write-Host "`n=== MEMBER ROLE APPROVAL SETTINGS ===" -ForegroundColor Yellow
    $memberPolicyResponse = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyUri
    
    if ($memberPolicyResponse.value.Count -gt 0) {
        $memberPolicyId = $memberPolicyResponse.value[0].policyId
        
        if ([string]::IsNullOrEmpty($memberPolicyId)) {
            Write-Host "No policy ID found for member role." -ForegroundColor Yellow
        } else {
            $memberPolicyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($memberPolicyId)?`$expand=rules"
            $memberPolicy = Invoke-MgGraphRequest -Method GET -Uri $memberPolicyDetailUri
            
            # Find approval rule
            $approvalRule = $memberPolicy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
            
            if ($approvalRule) {
                Write-Host "`nApproval Required: " -NoNewline
                Write-Host "$($approvalRule.setting.isApprovalRequired)" -ForegroundColor $(if($approvalRule.setting.isApprovalRequired){"Green"}else{"Yellow"})
                
                if ($approvalRule.setting.isApprovalRequired) {
                    Write-Host "Approval Stages: $($approvalRule.setting.approvalStages.Count)"
                    
                    foreach ($stage in $approvalRule.setting.approvalStages) {
                        Write-Host "`n  Stage $($stage.approvalStageTimeOutInDays) day(s) timeout:" -ForegroundColor Cyan
                        
                        foreach ($approver in $stage.primaryApprovers) {
                            switch ($approver.'@odata.type') {
                                '#microsoft.graph.singleUser' {
                                    $user = Get-MgUser -UserId $approver.id -ErrorAction SilentlyContinue
                                    Write-Host "    - User: $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor White
                                }
                                '#microsoft.graph.groupMembers' {
                                    $approverGroup = Get-MgGroup -GroupId $approver.id -ErrorAction SilentlyContinue
                                    Write-Host "    - Group: $($approverGroup.DisplayName)" -ForegroundColor White
                                }
                                '#microsoft.graph.requestorManager' {
                                    Write-Host "    - Requestor's Manager" -ForegroundColor White
                                }
                                default {
                                    Write-Host "    - $($approver.'@odata.type'): $($approver | ConvertTo-Json -Compress)" -ForegroundColor Gray
                                }
                            }
                        }
                        
                        if ($stage.escalationApprovers.Count -gt 0) {
                            Write-Host "    Escalation Approvers:" -ForegroundColor Magenta
                            foreach ($approver in $stage.escalationApprovers) {
                                switch ($approver.'@odata.type') {
                                    '#microsoft.graph.singleUser' {
                                        $user = Get-MgUser -UserId $approver.id -ErrorAction SilentlyContinue
                                        Write-Host "      - User: $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor White
                                    }
                                    '#microsoft.graph.groupMembers' {
                                        $approverGroup = Get-MgGroup -GroupId $approver.id -ErrorAction SilentlyContinue
                                        Write-Host "      - Group: $($approverGroup.DisplayName)" -ForegroundColor White
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Write-Host "No approval rules found for member role." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "No PIM policy found for member role." -ForegroundColor Yellow
    }
    
    # Get owner policy
    Write-Host "`n=== OWNER ROLE APPROVAL SETTINGS ===" -ForegroundColor Yellow
    $ownerPolicyResponse = Invoke-MgGraphRequest -Method GET -Uri $ownerPolicyUri
    
    if ($ownerPolicyResponse.value.Count -gt 0) {
        $ownerPolicyId = $ownerPolicyResponse.value[0].policyId
        
        if ([string]::IsNullOrEmpty($ownerPolicyId)) {
            Write-Host "No policy ID found for owner role." -ForegroundColor Yellow
        } else {
            $ownerPolicyDetailUri = "https://graph.microsoft.com/beta/policies/roleManagementPolicies/$($ownerPolicyId)?`$expand=rules"
            $ownerPolicy = Invoke-MgGraphRequest -Method GET -Uri $ownerPolicyDetailUri
            
            # Find approval rule
            $approvalRule = $ownerPolicy.rules | Where-Object { $_.'@odata.type' -like '*ApprovalRule' }
            
            if ($approvalRule) {
                Write-Host "`nApproval Required: " -NoNewline
                Write-Host "$($approvalRule.setting.isApprovalRequired)" -ForegroundColor $(if($approvalRule.setting.isApprovalRequired){"Green"}else{"Yellow"})
                
                if ($approvalRule.setting.isApprovalRequired) {
                    Write-Host "Approval Stages: $($approvalRule.setting.approvalStages.Count)"
                    
                    foreach ($stage in $approvalRule.setting.approvalStages) {
                        Write-Host "`n  Stage $($stage.approvalStageTimeOutInDays) day(s) timeout:" -ForegroundColor Cyan
                        
                        foreach ($approver in $stage.primaryApprovers) {
                            switch ($approver.'@odata.type') {
                                '#microsoft.graph.singleUser' {
                                    $user = Get-MgUser -UserId $approver.id -ErrorAction SilentlyContinue
                                    Write-Host "    - User: $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor White
                                }
                                '#microsoft.graph.groupMembers' {
                                    $approverGroup = Get-MgGroup -GroupId $approver.id -ErrorAction SilentlyContinue
                                    Write-Host "    - Group: $($approverGroup.DisplayName)" -ForegroundColor White
                                }
                                '#microsoft.graph.requestorManager' {
                                    Write-Host "    - Requestor's Manager" -ForegroundColor White
                                }
                                default {
                                    Write-Host "    - $($approver.'@odata.type'): $($approver | ConvertTo-Json -Compress)" -ForegroundColor Gray
                                }
                            }
                        }
                        
                        if ($stage.escalationApprovers.Count -gt 0) {
                            Write-Host "    Escalation Approvers:" -ForegroundColor Magenta
                            foreach ($approver in $stage.escalationApprovers) {
                                switch ($approver.'@odata.type') {
                                    '#microsoft.graph.singleUser' {
                                        $user = Get-MgUser -UserId $approver.id -ErrorAction SilentlyContinue
                                        Write-Host "      - User: $($user.DisplayName) ($($user.UserPrincipalName))" -ForegroundColor White
                                    }
                                    '#microsoft.graph.groupMembers' {
                                        $approverGroup = Get-MgGroup -GroupId $approver.id -ErrorAction SilentlyContinue
                                        Write-Host "      - Group: $($approverGroup.DisplayName)" -ForegroundColor White
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                Write-Host "No approval rules found for owner role." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "No PIM policy found for owner role." -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Failed to retrieve PIM policy: $_"
    Write-Error $_.Exception.Message
}

Write-Host "`n" -NoNewline

