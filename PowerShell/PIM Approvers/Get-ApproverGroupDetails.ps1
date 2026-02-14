# Script to get details about approver groups and what they approve

$reportPath = "$PSScriptRoot\PIM-Approvers-Report.md"
$outputPath = "$PSScriptRoot\Approver-Groups-Details.md"

Import-Module Microsoft.Graph.Groups -ErrorAction SilentlyContinue
Import-Module Microsoft.Graph.Users -ErrorAction SilentlyContinue

# Connect if needed
$requiredScopes = @("Group.Read.All", "User.Read.All", "GroupMember.Read.All")
$context = Get-MgContext

if ($null -eq $context -or ($requiredScopes | Where-Object { $_ -notin $context.Scopes }).Count -gt 0) {
    Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $requiredScopes -ErrorAction Stop
    Write-Host "Connected successfully!" -ForegroundColor Green
}

# Parse the existing report to extract approver groups
Write-Host "Parsing PIM approvers report..." -ForegroundColor Cyan
$reportContent = Get-Content $reportPath -Raw

# Extract all unique approver groups
$approverGroups = @{}
$currentPimGroup = $null

foreach ($line in (Get-Content $reportPath)) {
    if ($line -match '^## (.+)$') {
        $currentPimGroup = $matches[1]
    }
    elseif ($line -match '^- Group: (.+)$') {
        $groupName = $matches[1]
        if (-not $approverGroups.ContainsKey($groupName)) {
            $approverGroups[$groupName] = @()
        }
        $approverGroups[$groupName] += $currentPimGroup
    }
}

Write-Host "Found $($approverGroups.Count) unique approver groups" -ForegroundColor Green

# Generate the report
$markdown = @"
# PIM Approver Groups - Members and Responsibilities
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

This report shows all approver groups, their members, and which PIM groups they approve access for.

Total Approver Groups: $($approverGroups.Count)

---

"@

$counter = 0
foreach ($groupName in ($approverGroups.Keys | Sort-Object)) {
    $counter++
    Write-Host "[$counter/$($approverGroups.Count)] Processing: $groupName..." -ForegroundColor Cyan
    
    $markdown += "`n## $groupName`n`n"
    
    try {
        # Search for the group
        $escapedName = $groupName.Replace("'", "''")
        $group = Get-MgGroup -Filter "displayName eq '$escapedName'" -ErrorAction Stop | Select-Object -First 1
        
        if ($group) {
            $markdown += "**Group ID:** ``$($group.Id)```n`n"
            
            # Get group members
            $markdown += "### Members`n`n"
            $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction Stop
            
            if ($members.Count -gt 0) {
                foreach ($member in $members) {
                    $memberDetails = $null
                    
                    # Try to get as user first
                    try {
                        $memberDetails = Get-MgUser -UserId $member.Id -ErrorAction Stop
                        $markdown += "- **User:** $($memberDetails.DisplayName) ($($memberDetails.UserPrincipalName))`n"
                    } catch {
                        # Try as group
                        try {
                            $memberDetails = Get-MgGroup -GroupId $member.Id -ErrorAction Stop
                            $markdown += "- **Group:** $($memberDetails.DisplayName)`n"
                        } catch {
                            $markdown += "- **Unknown:** $($member.Id)`n"
                        }
                    }
                }
            } else {
                $markdown += "*No members found*`n"
            }
            
            # List PIM groups this approver group approves for
            $markdown += "`n### Approves Access For`n`n"
            $pimGroups = $approverGroups[$groupName] | Sort-Object -Unique
            
            foreach ($pimGroup in $pimGroups) {
                $markdown += "- $pimGroup`n"
            }
            
        } else {
            $markdown += "*Group not found in Azure AD*`n"
            
            # Still show what it approves
            $markdown += "`n### Approves Access For`n`n"
            $pimGroups = $approverGroups[$groupName] | Sort-Object -Unique
            
            foreach ($pimGroup in $pimGroups) {
                $markdown += "- $pimGroup`n"
            }
        }
        
    } catch {
        $markdown += "**Error:** $($_.Exception.Message)`n"
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        # Still show what it approves
        $markdown += "`n### Approves Access For`n`n"
        $pimGroups = $approverGroups[$groupName] | Sort-Object -Unique
        
        foreach ($pimGroup in $pimGroups) {
            $markdown += "- $pimGroup`n"
        }
    }
    
    $markdown += "`n---`n"
}

# Save the report
$markdown | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "`nReport generated: $outputPath" -ForegroundColor Green
