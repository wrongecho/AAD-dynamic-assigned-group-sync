<#
.Synopsis
Syncs AAD dynamic groups to AAD assigned groups

.Description
PowerShell script to sync users in dynamic Azure AD groups to assigned Azure AD security groups, as some third-party apps do not support Dynamic groups. To be run as an Azure function app.

Define the dynamic groups to check, and the assigned groups to sync to in the $groupsArray array.

#>

# Namespace / input bindings required to run.
using namespace System.Net
param($Request, $TriggerMetadata)


# Define which dynamic groups should be synced to which assigned groups
$groupsArray = @(
    [PSCustomObject]@{dynamicGroupName = 'Dynamic Group A'; dynamicGroupID = 'aaaa-aaaa-aaaa-aaaa-dynamic';  assignedGroupName = 'Assigned Group A'; assignedGroupID = 'aaaa-aaaa-aaaa-aaaa-assigned'}
    [PSCustomObject]@{dynamicGroupName = 'Dynamic Group B'; dynamicGroupID = 'bbbb-bbbb-bbbb-bbbb-dynamic';  assignedGroupName = 'Assigned Group B'; assignedGroupID = 'bbbb-bbbb-bbbb-bbbb-assigned'}
)

# Import Azure AD
Import-Module AzureAD -UseWindowsPowerShell

# Variables
$tenantID = $ENV:tenantID
$appID = $ENV:appID
$thumbprint = $ENV:thumbprint
$connect = $null

Write-Host
Write-Host "=============================="
Write-Host "Azure AD Group Sync"
Write-Host "=============================="
Write-Host

# Connect to Azure AD via the App Registration
#  authenticating via the Certificate stored under TLS/SSL settings (Private keys)
$connect = Connect-AzureAD -TenantId $tenantID -ApplicationId $appID -CertificateThumbprint $thumbprint

# Try to check Azure AD Connection
if($connect -eq $null){
    Write-Error "Error connecting to Azure AD."
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::Locked
        Body = "Error connecting to Azure AD."
    })
}

# Loop through each group as $group
foreach($group in $groupsArray){

    Write-Host "-- Syncing dynamic group" $group.dynamicGroupName "with assigned group" $group.assignedGroupName "--"
    
    # Get members of the dynamic group
    $dynamicGroupMembers = Get-AzureADGroupMember -ObjectId $group.dynamicGroupID  -All $true

    # Get members of the assigned group
    $assignedGroupMembers = Get-AzureADGroupMember -ObjectId $group.assignedGroupID -All $true

     # Loop through assigned users & show assigned users that should not be in the group (BAD - Remove them)
    foreach($assignedGroupMember in $assignedGroupMembers){
        if($dynamicGroupMembers.ObjectID -notcontains $assignedGroupMember.ObjectID){
            Write-Host -ForegroundColor Red "[-]" $assignedGroupMember.UserPrincipalName "is incorrectly in the assigned group - removing them."
            Remove-AzureADGroupMember -ObjectId $group.assignedGroupID -MemberId $assignedGroupMember.ObjectID
        }
    }

    # Loop through each member of the dynamic group
    foreach($dynamicGroupMember in $dynamicGroupMembers){

        # Show assigned users that should be in the group (GOOD)
        if($assignedGroupMembers.ObjectID -contains $dynamicGroupMember.ObjectId){
            Write-Host -ForegroundColor Green "[/]" $dynamicGroupMember.UserPrincipalName "is correctly in the assigned group - no action"
        }

        # Show missing users that should be in the group (BAD - Add them)
        if($assignedGroupMembers.ObjectID -notcontains $dynamicGroupMember.ObjectId){
            Write-Host -ForegroundColor Yellow "[+]" $dynamicGroupMember.UserPrincipalName "is missing from the assigned group - adding them"
            Add-AzureADGroupMember -ObjectId $group.assignedGroupID -RefObjectId $dynamicGroupMember.ObjectID
        }

    }

    # Blank Lines for readability
    Write-Host
    Write-Host
}

$body = "This HTTP triggered function executed successfully."

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [HttpStatusCode]::OK
    Body = $body
})
