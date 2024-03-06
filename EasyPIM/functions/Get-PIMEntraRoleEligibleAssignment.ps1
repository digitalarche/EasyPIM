﻿<#
    .Synopsis
    List of PIM Entra Role active assignement 
    .Description
    Active assignment does not require to activate their role. https://learn.microsoft.com/en-us/graph/api/rbacapplication-list-roleeligibilityscheduleinstances?view=graph-rest-1.0&tabs=http
    .Parameter tenantID
    EntraID tenant ID
    .Parameter summary
    When enabled will return the most useful information only
    
    .Example
    PS> Get-PIMEntraRoleEligibleAssignment -tenantID $tid 

    List active assignement 


    .Link
    .Notes
    Author: Loïc MICHEL
    Homepage: https://github.com/kayasax/EasyPIM
#>
     
function Get-PIMEntraRoleEligibleAssignment {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [String]
        $tenantID,
        # select the most usefull info only
        [switch]$summary
    )

    $script:tenantID = $tenantID

    $endpoint = "/roleManagement/directory/roleEligibilityScheduleInstances?`$expand=roleDefinition,principal"
    $response = invoke-graph -Endpoint $endpoint
    $resu = @()
    $response.value | % {
        $_
        $r = @{
            "rolename"         = $_.roledefinition.displayName
            "roleid"           = $_.roledefinition.id
            "principalname"    = $_.principal.displayName
            "principalid"      = $_.principal.id
            "startDateTime"    = $_.startDateTime
            "endDateTime"      = $_.endDateTime
            "directoryScopeId" = $_.directoryScopeId
            "memberType"       = $_.memberType
            "assignmentType"   = $_.assignmentType
            #"activatedUsing"=$_.activatedUsing
            "type"             = $_.principal."@odata.type"
            "id"               = $_.id
        }
        $resu += New-Object PSObject -Property $r
    
  
    }


    if ($PSBoundParameters.Keys.Contains('summary')) {
        $resu = $resu | Select-Object rolename, roleid, principalid, principalName, principalEmail, PrincipalType, startDateTime, endDateTime, directoryScopeId
    }
    return $resu
}