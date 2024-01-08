<# 
.Synopsis
Sript to manage the Azure Resource Roles settings with simplicity in mind

.Description
    
    General flow:

    1  Get-AzRoleAssignment -RoleDefinitionName webmaster
    2 run the query GET https://management.azure.com//subscriptions/eedcaa84-3756-4da9-bf87-40068c3dd2a2/providers/Microsoft.Authorization/roleManagementPolicyAssignments?api-version=2020-10-01
    3 filter with role id found in 1 et get sub policyid
    "policyId": "/subscriptions/eedcaa84-3756-4da9-bf87-40068c3dd2a2/providers/Microsoft.Authorization/roleManagementPolicies/507081b0-bdfc-4a40-9403-fd447a75712a",
    4 use the policy id found in 3 to view the rules
    GET https://management.azure.com//subscriptions/eedcaa84-3756-4da9-bf87-40068c3dd2a2/providers/Microsoft.Authorization/roleManagementPolicies/507081b0-bdfc-4a40-9403-fd447a75712a?api-version=2020-10-01
    5 update the rule
    PATCH https://management.azure.com//subscriptions/eedcaa84-3756-4da9-bf87-40068c3dd2a2/providers/Microsoft.Authorization/roleManagementPolicies/507081b0-bdfc-4a40-9403-fd447a75712a?api-version=2020-10-01


.Parameter param1 
    describe param1
.Parameter param2
    describe param2
.Example
       *  show curent config :
       wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -show
    
       *  Set Activation duration to 14h
       wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -ActivationDuration "PT14H"
    
       *  Require approval on activation and define approvers
        wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -ApprovalRequired $true -Approvers @( @{"id"="00b34bb3-8a6b-45ce-a7bb-c7f7fb400507";"name"="Bob";"type"="User"} , @{"id"="cf0a2f3e-1223-49d4-b10b-01f2538dd5d7";"name"="TestDL";"type"="Group"} )
    
       *  Diable approval
        wip_PIMAzureResourceRoleSettings.ps1 -TenantID $tenant -SubscriptionId $subscripyion -rolename $rolename -ApprovalRequired $false 


        .Link
    https://learn.microsoft.com/en-us/azure/governance/resource-graph/first-query-rest-api 
    https://learn.microsoft.com/en-us/graph/identity-governance-pim-rules-overview
    Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
.Notes
    Author: MICHEL, Loic 
    Changelog:
    * 2018/01/08 08:00 Template generated with NewTemplate.ps1 V 0.2
    Todo: 
    * allow other scopes
#>

[CmdletBinding()] #make script react as cmdlet (-verbose etc..)
param(
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $TenantID,

    [Parameter(Position = 1, Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $SubscriptionId,

    [Parameter(Position = 2, Mandatory = $true, ValueFromPipeline = $true)]
    [ValidateNotNullOrEmpty()]
    [System.String[]]
    $rolename,

    [Switch]
    $show, # show current config only, no change made
    
    [Switch]
    $export, # export config to csv

    [String]
    $exportFilename = $null,

    [System.String]
    $ActivationDuration = $null,

   
    [Parameter(HelpMessage = "Accepted values: 'None' or any combination of these options (Case SENSITIVE):  'Justification, 'MultiFactorAuthentication', 'Ticketing'", ValueFromPipeline = $true)]
    [ValidateScript({

            # WARNING: options are CASE SENSITIVE
            $valid = $true
            $acceptedValues = @("None", "Justification", "MultiFactorAuthentication", "Ticketing")
            $_ | ForEach-Object { if (!( $acceptedValues -Ccontains $_)) { $valid = $false } }
            $valid
        })]
    [System.String[]]
    $ActivationRequirement, # accepted values: "None","Justification", "MultiFactorAuthentication", "Ticketing"
     
    [Bool]
    $ApprovalRequired,

    $Approvers, # @(@{"Id"="XXXXXX";"Name"="John":"Type"="user|group"}, .... )
    
    [Parameter(ValueFromPipeline = $true)]
    [System.String]
    $MaximumAssignationDuration = $null,
    
    [Parameter(ValueFromPipeline = $true)]
    [Bool]
    $AllowPermanentEligibilty,

    [Parameter(ValueFromPipeline = $true)]
    [System.String]
    $MaximumActiveAssignmentDuration = $null, # Duration ref https://en.wikipedia.org/wiki/ISO_8601#Durations
    
    [Parameter(ValueFromPipeline = $true)]
    [Bool]
    $AllowPermanentActiveAssignment,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_EligibleAssignment_Alert, # @{"isDefaultRecipientEnabed"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    
    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_EligibleAssignment_Assignee, # @{"isDefaultRecipientEnabed"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    
    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_EligibleAssignment_Approvers, # @{"isDefaultRecipientEnabed"="true|false"; "notificationLevel"="All|Critical"};"Recipients" = @("email1@domain.com","email2@domain.com")} 
    
    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_ActiveAssignment_Alert,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_ActiveAssignment_Assignee,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_ActiveAssignment_Approvers,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_Activation_Alert,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_Activation_Assignee,

    [Parameter(ValueFromPipeline = $true)]
    [System.Collections.Hashtable]
    $Notification_Activation_Approvers

)
#***************************************
#* CONFIGURATION
#***************************************

# LOG TO FILE ( if enable by default it will create a LOGS subfolder in the script folder, and create a logfile with the name of the script )
$logToFile = $false

# TEAMS NOTIDICATION
# set to $true if you want to send fatal error on a Teams channel using Webhook see doc to setup
$TeamsNotif = $false 
# your Teams Inbound WebHook URL
$teamsWebhookURL = "https://microsoft.webhook.office.com/webhookb2/0b9bf9c2-fc4b-42b2-aa56-c58c805068af@72f988bf-86f1-41af-91ab-2d7cd011db47/IncomingWebhook/40db225a69854e49b617eb3427bcded8/8dd39776-145b-4f26-8ac4-41c5415307c7"
#The description will be used as the notification subject
$description = "PIM Azure role setting" 

#***************************************
#* PRIVATE VARIABLES DON'T TOUCH !!
#***************************************
$_scriptFullName = $MyInvocation.myCommand.definition
$_scriptName = Split-Path -Leaf $_scriptFullName
$_scriptPath = split-path -Parent   $_scriptFullName
$HostFQDN = $env:computername + "." + $env:USERDNSDOMAIN
# ERROR HANDLING
$ErrorActionPreference = "STOP" # make all errors terminating ones so they can be catch

#from now every error will be treated as exception and terminate the script
try {
    
    <# 
      .Synopsis
       Log message to file and display it on screen with basic colour hilights.
       The function include a log rotate feature.
      .Description
       Write $msg to screen and file with additional inforamtions : date and time, 
       name of the script from where the function was called, line number and user who ran the script.
       If logfile path isn't specified it will default to C:\UPF\LOGS\<scriptname.ps1.log>
       You can use $Maxsize and $MaxFile to specified the size and number of logfiles to keep (default is 3MB, and 3files)
       Use the switch $noEcho if you dont want the message be displayed on screen
      .Parameter msg 
       The message to log
      .Parameter logfile
       Name of the logfile to use (default = <scriptname>.ps1.log)
      .Parameter logdir
       Path to the logfile's directory (defaut = C:\UPF\LOGS)
       .Parameter noEcho 
       Don't print message on screen
      .Parameter maxSize
       Maximum size (in bytes) before logfile is rotate (default is 3MB)
      .Parameter maxFile
       Number of logfile history to keep (default is 3)
      .Example
        log "A message to display on screen and file"
      .Example
        log "this message will not appear on screen" -noEcho
      .Link
      http://www.colas.com
      .Notes
      	Changelog :
         * 27/08/2017 version initiale	
         * 21/09/2017 correction of rotating step
      	Todo : 
     #>
    function log {
        [CmdletBinding()]
        param(
            [string]$msg,
            $logfile = $null,
            $logdir = $(join-path -path $script:_scriptPath -childpath "LOGS"), # Path to logfile
            [switch]$noEcho, # if set dont display output to screen, only to logfile
            $MaxSize = 3145728, # 3MB
            #$MaxSize = 1,
            $Maxfile = 3 # how many files to keep
        )

        #do nothing if logging is disabled
        if ($true -eq $logToFile ) {
     
            # When no logfile is specified we append .log to the scriptname 
            if ( $logfile -eq $null ) { 
                $logfile = $(Split-Path -Leaf $MyInvocation.ScriptName) + ".log"
            }
       
            # Create folder if needed
            if ( !(test-path  $logdir) ) {
                $null = New-Item -ItemType Directory -Path $logdir  -Force
            }
         
            # Ensure logfile will be save in logdir
            if ( $logfile -notmatch [regex]::escape($logdir)) {
                $logfile = "$logdir\$logfile"
            }
         
            # Create file
            if ( !(Test-Path $logfile) ) {
                write-verbose "$logfile not found, creating it"
                $null = New-Item -ItemType file $logfile -Force  
            }
            else {
                # file exists, do size exceeds limit ?
                if ( (get-childitem $logfile | select -expand length) -gt $Maxsize) {
                    echo "$(Get-Date -Format yyy-MM-dd-HHmm) - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : Log size exceed $MaxSize, creating a new file." >> $logfile 
                 
                    # rename current logfile
                    $LogFileName = $($($LogFile -split "\\")[-1])
                    $basename = ls $LogFile | select -expand basename
                    $dirname = ls $LogFile | select -expand directoryname
     
                    Write-Verbose "Rename-Item $LogFile ""$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"""
                    Rename-Item $LogFile "$($LogFileName.substring(0,$LogFileName.length-4))-$(Get-Date -format yyyddMM-HHmmss).log"
     
                    # keep $Maxfile  logfiles and delete the older ones
                    $filesToDelete = ls  "$dirname\$basename*.log" | sort LastWriteTime -desc | select -Skip $Maxfile 
                    $filesToDelete | remove-item  -force
                }
            }
     
            echo "$(Get-Date -Format yyy-MM-dd-HHmm) - $(whoami) - $($MyInvocation.ScriptName) (L $($MyInvocation.ScriptLineNumber)) : $msg" >> $logfile
        }# end logging to file

        # Display $msg if $noEcho is not set
        if ( $noEcho -eq $false) {
            #colour it up...
            if ( $msg -match "Erreur|error") {
                write-host $msg -ForegroundColor red
            }
            elseif ($msg -match "avertissement|attention|warning") {
                write-host $msg -ForegroundColor yellow
            }
            elseif ($msg -match "info|information") {
                write-host $msg -ForegroundColor cyan
            }    
            elseif ($msg -match "succès|succes|success|OK") {
                write-host $msg -ForegroundColor green
            }
            else {
                write-host $msg 
            }
        }
    } #end function log
    function send-teamsnotif {
        [CmdletBinding()] #make script react as cmdlet (-verbose etc..)
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string] $message,
            [string] $details,
            [string] $stacktrace = $null
        )

        
        <#$JSONBody = [PSCustomObject][Ordered]@{
            "@type"      = "MessageCard"
            "@context"   = "http://schema.org/extensions"
            "summary"    = "Alert from : $description ($_scriptFullName)"
            "themeColor" = '0078D7'
            "title"      = "Alert from $env:computername"
            "text"       = "$message"
        }#>

        $JSONBody = @{
            "@type"    = "MessageCard"
            "@context" = "<http://schema.org/extensions>"
            "title"    = "Alert for $description @ $env:computername  "
            "text"     = "An exception occured:"
            "sections" = @(
                @{
                    "activityTitle" = "Message : $message"
                },
                @{
                    "activityTitle" = "Details : $details"
                },
                @{
                    "activityTitle" = " Script path "
                    "activityText"  = "$_scriptFullName"
                },
            
                @{
                    "activityTitle" = "Stacktrace"
                    "activityText"  = "$stacktrace"
                }
            )
        }

        $TeamMessageBody = ConvertTo-Json $JSONBody -Depth 100
        
        $parameters = @{
            "URI"         = $teamsWebhookURL
            "Method"      = 'POST'
            "Body"        = $TeamMessageBody
            "ContentType" = 'application/json'
        }
        $null = Invoke-RestMethod @parameters
    }#end function senfd-teamsnotif
   
    #log "`n******************************************`nInfo : script is starting`n******************************************"
    #$rolename="Webmaster"

    #at least one approver required if approval is enable
    # todo chech if a parameterset would be better
    if ($ApprovalRequired -eq $true -and $Approvers -eq $null) { throw "`n /!\ At least one approver is required if approval is enable, please set -Approvers parameter`n`n" }
    
    $scope = "subscriptions/$subscriptionID"
    $ARMhost = "https://management.azure.com"
    $ARMendpoint = "$ARMhost/$scope/providers/Microsoft.Authorization"
    
    # Log in first with Connect-AzAccount if not using Cloud Shell
    Write-Verbose ">> Connecting to Azure with tenantID $tenantID"
    if ( (get-azcontext) -eq $null) { Connect-AzAccount -Tenant $tenantID }

    # Get access Token
    Write-Verbose ">> Getting access token"
    $token = Get-AzAccessToken
    #Write-Verbose ">> token=$($token.Token)"
    
    # setting the authentication headers for MSGraph calls
    $authHeader = @{
        'Content-Type'  = 'application/json'
        'Authorization' = 'Bearer ' + $token.Token
    }

    # export 
    $exports=@()

    # run the flow for each role name.
    $rolename | ForEach-Object {

        # 1 Get ID of the role $rolename assignable at the provided scope
        $restUri = "$ARMendpoint/roleDefinitions?api-version=2022-04-01&`$filter=roleName eq '$_'"
        write-verbose " #1 Get role definition for the role $_ assignable at the scope $scope at $restUri"
        $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
        $roleID = $response.value.id
        if ($null -eq $roleID) { throw "An exception occured : can't find a roleID for $_ at scope $scope" }
        Write-Verbose ">> RodeId = $roleID"

        # 2  get the role assignment for the roleID found at #1
        $restUri = "$ARMendpoint/roleManagementPolicyAssignments?api-version=2020-10-01&`$filter=roleDefinitionId eq '$roleID'"
        write-verbose " #2 Get the Assignment for $_ at $restUri"
        $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false
        $policyId = $response.value.properties.policyId #.split('/')[-1] 
        Write-Verbose ">> policy ID = $policyId"

        # 3 get the role policy for the policyID found in #2
        $restUri = "$ARMhost/$policyId/?api-version=2020-10-01"
        write-verbose " #3 get role policy at $restUri"
        $response = Invoke-RestMethod -Uri $restUri -Method Get -Headers $authHeader -verbose:$false

        # Get config values in a new object:

        # Maximum end user activation duration in Hour (PT24H) // Max 24H in portal but can be greater
        $_activationDuration = $response.properties.rules | ? { $_.id -eq "Expiration_EndUser_Assignment" } | select -ExpandProperty maximumduration
        # End user enablement rule (MultiFactorAuthentication, Justification, Ticketing)
        $_enablementRules = $response.properties.rules | ? { $_.id -eq "Enablement_EndUser_Assignment" } | select -expand enabledRules
        # approval required 
        $_approvalrequired = $($response.properties.rules | ? { $_.id -eq "Approval_EndUser_Assignment" }).setting.isapprovalrequired
        # approvers 
        $_approvers = $($response.properties.rules | ? { $_.id -eq "Approval_EndUser_Assignment" }).setting.approvalstages.primaryapprovers
        # permanent assignmnent eligibility
        $_eligibilityExpirationRequired = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Eligibility" } | Select-Object -expand isExpirationRequired
        if ($_eligibilityExpirationRequired -eq "true") { 
            $_permanantEligibility = "false"
        }
        else { 
            $_permanantEligibility = "true"
        }
        # maximum assignment eligibility duration
        $_maxAssignmentDuration = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Eligibility" } | Select-Object -expand maximumDuration
        
        # pemanent activation
        $_activeExpirationRequired = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Assignment" } | Select-Object -expand isExpirationRequired
        if ($_activeExpirationRequired -eq "true") { 
            $_permanantActiveAssignment = "false"
        }
        else { 
            $_permanantActiveAssignment = "true"
        }
        # maximum activation duration
        $_maxActiveAssignmentDuration = $response.properties.rules | ? { $_.id -eq "Expiration_Admin_Assignment" } | Select-Object -expand maximumDuration

        #################
        # Notifications #
        #################

        # Notification Eligibility Alert (Send notifications when members are assigned as eligible to this role)
        $_Notification_Admin_Admin_Eligibility = $response.properties.rules | ? { $_.id -eq "Notification_Admin_Admin_Eligibility" } 
       
        # Notification Eligibility Assignee (Send notifications when members are assigned as eligible to this role: Notification to the assigned user (assignee))
        $_Notification_Eligibility_Assignee = $response.properties.rules | ? { $_.id -eq "Notification_Requestor_Admin_Eligibility" } 
        
        # Notification Eligibility Approvers (Send notifications when members are assigned as eligible to this role: request to approve a role assignment renewal/extension)
        $_Notification_Eligibility_Approvers = $response.properties.rules | ? { $_.id -eq "Notification_Approver_Admin_Eligibility" }

        # Notification Active Assignment Alert (Send notifications when members are assigned as active to this role)
        $_Notification_Active_Alert = $response.properties.rules | ? { $_.id -eq "Notification_Admin_Admin_Assignment" } 
        # Notification Active Assignment Assignee (Send notifications when members are assigned as active to this role: Notification to the assigned user (assignee))
        $_Notification_Active_Assignee = $response.properties.rules | ? { $_.id -eq "Notification_Requestor_Admin_Assignment" } 
        # Notification Active Assignment Approvers (Send notifications when members are assigned as active to this role: Request to approve a role assignment renewal/extension)
        $_Notification_Active_Approvers = $response.properties.rules | ? { $_.id -eq "Notification_Approver_Admin_Assignment" } 
        
        # Notification Role Activation Alert (Send notifications when eligible members activate this role: Role activation alert)
        $_Notification_Activation_Alert = $response.properties.rules | ? { $_.id -eq "Notification_Admin_EndUser_Assignment" } 
        # Notification Role Activation Assignee (Send notifications when eligible members activate this role: Notification to activated user (requestor))
        $_Notification_Activation_Assignee = $response.properties.rules | ? { $_.id -eq "Notification_Requestor_EndUser_Assignment" } 
        # Notification Role Activation Approvers (Send notifications when eligible members activate this role: Request to approve an activation)
        $_Notification_Activation_Approvers = $response.properties.rules | ? { $_.id -eq "Notification_Approver_EndUser_Assignment" } 


        $config = [PSCustomObject]@{
            RoleName                                                    = $_
            PolicyID                                                    = $policyId
            ActivationDuration                                          = $_activationDuration
            EnablementRules                                             = $_enablementRules -join ','
            ApprovalRequired                                            = $_approvalrequired
            Approvers                                                   = $_approvers -join ','
            AllowPermanentEligibleAssignment                            = $_permanantEligibility
            MaximumEligibleAssignmentDuration                           = $_maxAssignmentDuration
            AllowPermanentActiveAssignment                              = $_permanantActiveAssignment
            MaximumActiveAssignmentDuration                             = $_maxActiveAssignmentDuration
            Notification_Eligibility_Alert_isDefaultRecipientEnabed     = $($_Notification_Admin_Admin_Eligibility.isDefaultRecipientsEnabled)
            Notification_Eligibility_Alert_NotificationLevel            = $($_Notification_Admin_Admin_Eligibility.notificationLevel)
            Notification_Eligibility_Alert_Recipients                   = $($_Notification_Admin_Admin_Eligibility.notificationRecipients) -join ','
            Notification_Eligibility_Assignee_isDefaultRecipientEnabed  = $($_Notification_Eligibility_Assignee.isDefaultRecipientsEnabled)
            Notification_Eligibility_Assignee_NotificationLevel         = $($_Notification_Eligibility_Assignee.NotificationLevel)
            Notification_Eligibility_Assignee_Recipients                = $($_Notification_Eligibility_Assignee.notificationRecipients) -join ','
            Notification_Eligibility_Approvers_isDefaultRecipientEnabed = $($_Notification_Eligibility_Approvers.isDefaultRecipientsEnabled)
            Notification_Eligibility_Approvers_NotificationLevel        = $($_Notification_Eligibility_Approvers.NotificationLevel)
            Notification_Eligibility_Approvers_Recipients               = $($_Notification_Eligibility_Approvers.notificationRecipients -join ',')
            Notification_Active_Alert_isDefaultRecipientEnabed          = $($_Notification_Active_Alert.isDefaultRecipientsEnabled)
            Notification_Active_Alert_NotificationLevel                 = $($_Notification_Active_Alert.notificationLevel)
            Notification_Active_Alert_Recipients                        = $($_Notification_Active_Alert.notificationRecipients -join ',')
            Notification_Active_Assignee_isDefaultRecipientEnabed       = $($_Notification_Active_Assignee.isDefaultRecipientsEnabled)
            Notification_Active_Assignee_NotificationLevel              = $($_Notification_Active_Assignee.notificationLevel)
            Notification_Active_Assignee_Recipients                     = $($_Notification_Active_Assignee.notificationRecipients -join ',')
            Notification_Active_Approvers_isDefaultRecipientEnabed      = $($_Notification_Active_Approvers.isDefaultRecipientsEnabled)
            Notification_Active_Approvers_NotificationLevel             = $($_Notification_Active_Approvers.notificationLevel)
            Notification_Active_Approvers_Recipients                    = $($_Notification_Active_Approvers.notificationRecipients -join ',')
            Notification_Activation_Alert_isDefaultRecipientEnabed      = $($_Notification_Activation_Alert.isDefaultRecipientsEnabled)
            Notification_Activation_Alert_NotificationLevel             = $($_Notification_Activation_Alert.NotificationLevel)
            Notification_Activation_Alert_Recipients                    = $($_Notification_Activation_Alert.NotificationRecipients -join ',')
            Notification_Activation_Assignee_isDefaultRecipientEnabed   = $($_Notification_Activation_Assignee.isDefaultRecipientsEnabled)
            Notification_Activation_Assignee_NotificationLevel          = $($_Notification_Activation_Assignee.NotificationLevel)
            Notification_Activation_Assignee_Recipients                 = $($_Notification_Activation_Assignee.NotificationRecipients -join ',')
            Notification_Activation_Approvers_isDefaultRecipientEnabed  = $($_Notification_Activation_Approvers.isDefaultRecipientsEnabled)
            Notification_Activation_Approvers_NotificationLevel         = $($_Notification_Activation_Approvers.NotificationLevel)
            Notification_Activation_Approvers_Recipients                = $($_Notification_Activation_Approvers.NotificationRecipients -join ',')
        }

        if ($show) {
            #show curent config and quit
            return $config # $response 
        }

        if ( $export ) {
          $exports +=  $config     
        }
    
        # Build our rules to patch based on parameter used
        $rules = @()

        # Set Maximum activation duration
        if ( ($null -ne $ActivationDuration) -and ("" -ne $ActivationDuration) ) {
            Write-Verbose "Editing Activation duration : $activationDuration"
            $properties = @{
                "isExpirationRequired" = "true";
                "maximumDuration"      = "$ActivationDuration";
                "id"                   = "Expiration_EndUser_Assignment";
                "ruleType"             = "RoleManagementPolicyExpirationRule";
                "target"               = @{
                    "caller"     = "EndUser";
                    "operations" = @("All")
                };
                "level"                = "Assignment"
            }       
            $rule = $properties | ConvertTo-Json
            #update rules if required
            if ($PSBoundParameters.Keys.Contains('ActivationDuration')) {  
                $rules += $rule
            }
        }

        # Set activation requirement MFA/justification/ticketing
        if ($null -ne $ActivationRequirement) {
            if ($ActivationRequirement -eq "None") {
                $enabledRules = "[],"
            }
            else {
                $formatedRules = '['
                
                $ActivationRequirement | % {
                    $formatedRules += '"'
                    $formatedRules += "$_"
                    $formatedRules += '",'
                    
                }
                $formatedRules += "],"
                $enabledRules = $formatedRules
                Write-Verbose "************* $enabledRules "
            }
                
            $properties = '{
                    "enabledRules": '+ $enabledRules + '
                    "id": "Enablement_EndUser_Assignment",
                    "ruleType": "RoleManagementPolicyEnablementRule",
                    "target": {
                        "caller": "EndUser",
                        "operations": [
                            "All"
                        ],
                        "level": "Assignment",
                        "targetObjects": [],
                        "inheritableSettings": [],
                        "enforcedSettings": []
                    }
                }'
            $rule = $properties
            
            #update if required
            if ($PSBoundParameters.Keys.Contains('ActivationRequirement')) {  
                $rules += $rule
            }          
        }

        # Approval and approvers
        $approvalChanged = $false
        if ( ($PSBoundParameters.Keys.Contains('ApprovalRequired')) -or ($PSBoundParameters.Keys.Contains('Approvers'))) {
            $approvalChanged = $true
            if ($ApprovalRequired -eq $false) { $req = "false" }else { $req = "true" }
        
            $rule = '
        {
        "setting": {'
            if ($null -ne $ApprovalRequired) {
                $rule += '"isApprovalRequired": ' + $req + ','
            }
            $rule += '
        "isApprovalRequiredForExtension": false,
        "isRequestorJustificationRequired": true,
        "approvalMode": "SingleStage",
        "approvalStages": [
            {
            "approvalStageTimeOutInDays": 1,
            "isApproverJustificationRequired": true,
            "escalationTimeInMinutes": 0,
        '

            if ($null -ne $Approvers) {
                #at least one approver required if approval is enable
                $rule += '
            "primaryApprovers": [
            '
                $cpt = 0    
                $Approvers | ForEach-Object {
                    $id = $_.Id
                    $name = $_.Name
                    $type = $_.Type

                    if ($cpt -gt 0) {
                        $rule += ","
                    }
                    $rule += '
            {
                "id": "'+ $id + '",
                "description": "'+ $name + '",
                "isBackup": false,
                "userType": "'+ $type + '"
            }
            '
                    $cpt++
                }

                $rule += '
            ],'
            }

            $rule += ' 
        "isEscalationEnabled": false,
            "escalationApprovers": null
                    }]
                 },
        "id": "Approval_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyApprovalRule",
        "target": {
            "caller": "EndUser",
            "operations": [
                "All"
            ],
            "level": "Assignment",
            "targetObjects": null,
            "inheritableSettings": null,
            "enforcedSettings": null
        
        }}'
            if ($true -eq $approvalChanged) {
                $rules += $rule
            }
            
        }


        # eligibility assignement
        $eligibilityChanged = $false
        if ( $PSBoundParameters.ContainsKey('MaximumAssignationDuration')) {
            $max = $PSBoundParameters["MaximumAssignationDuration"]
            $eligibilityChanged = $true
        }
        else { $max = $_maxAssignmentDuration }
        if ( $PSBoundParameters.ContainsKey('AllowPermanentEligibilty')) {
            if ( $AllowPermanentEligibilty) {
                $expire = "false"
            }
            else {
                $expire = "true"
            }
            $eligibilityChanged = $true
        }
        else { $expire = $_eligibilityExpirationRequired.ToString().ToLower() }
       
        $rule = '
        {
        "isExpirationRequired": '+ $expire + ',
        "maximumDuration": "'+ $max + '",
        "id": "Expiration_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
          "caller": "Admin",
          "operations": [
            "All"
          ],
          "level": "Eligibility",
          "targetObjects": null,
          "inheritableSettings": null,
          "enforcedSettings": null
        }
    }
    '
        # update rule only if a change was requested
        if ( $true -eq $eligibilityChanged) {
            $rules += $rule
        }
        

        #active assignement limits
        $ActiveAssignmentChanged = $false
        if ( $PSBoundParameters.ContainsKey('MaximumActiveAssignmentDuration')) {
            $max2 = $PSBoundParameters["MaximumActiveAssignmentDuration"]
            $ActiveAssignmentChanged = $true
        }
        else { $max2 = $_maxAssignmentDuration }
        if ( $PSBoundParameters.ContainsKey('AllowPermanentActiveAssignment')) {
            if ( $AllowPermanentActiveAssignment) {
                $expire2 = "false"
            }
            else {
                $expire2 = "true"
            }
            $ActiveAssignmentChanged = $true
        }
        else { $expire2 = $_activeExpirationRequired.ToString().ToLower() }

        $rule = '
        {
        "isExpirationRequired": '+ $expire2 + ',
        "maximumDuration": "'+ $max2 + '",
        "id": "Expiration_Admin_Assignment",
        "ruleType": "RoleManagementPolicyExpirationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
'
        if ( $true -eq $ActiveAssignmentChanged) {
            $rules += $rule
        }

        #################
        # Notifications #
        #################

        # Notif Eligibility assignment Alert
        if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Alert')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Alert.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
            $Notification_EligibleAssignment_Alert.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        
            $rule += '
        ],
        "id": "Notification_Admin_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
    '
            $rules += $rule
        }
 
        # Notif elligibility assignee
        if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Assignee')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Assignee_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Requestor",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Assignee.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Assignee.notificationLevel + '",
        "notificationRecipients": [
        '
            $Notification_EligibleAssignment_Assignee.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        
            $rule += '
        ],
        "id": "Notification_Requestor_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }'
            $rules += $rule
        }


        # Notif elligibility approver
        if ($PSBoundParameters.Keys.Contains('Notification_EligibleAssignment_Approvers')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Approvers_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_EligibleAssignment_Approvers.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_EligibleAssignment_Approvers.notificationLevel + '",
        "notificationRecipients": [
        '
            $Notification_EligibleAssignment_Approvers.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        
            $rule += '
        ],
        "id": "Notification_Approver_Admin_Eligibility",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }'
            $rules += $rule
        }


        # Notif Active Assignment Alert
        if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Alert')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Alert.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_ActiveAssignment_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
            $Notification_ActiveAssignment_Alert.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        
            $rule += '
        ],
        "id": "Notification_Admin_Admin_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
            $rules += $rule
        }

      
        # Notif Active Assignment Assignee
        if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Assignee')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
                {
                "notificationType": "Email",
                "recipientType": "Requestor",
                "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Assignee.isDefaultRecipientEnabed + ',
                "notificationLevel": "'+ $Notification_ActiveAssignment_Assignee.notificationLevel + '",
                "notificationRecipients": [
                '
            $Notification_ActiveAssignment_Assignee.Recipients | % {
                $rule += '"' + $_ + '",'
            }

            $rule += '
                ],
                "id": "Notification_Requestor_Admin_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "target": {
                "caller": "Admin",
                "operations": [
                    "All"
                ],
                "level": "Eligibility",
                "targetObjects": null,
                "inheritableSettings": null,
                "enforcedSettings": null
                }
                }
                '
            $rules += $rule
        }

        # Notif Active Assignment Approvers
        if ($PSBoundParameters.Keys.Contains('Notification_ActiveAssignment_Approvers')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
                {
                "notificationType": "Email",
                "recipientType": "Approver",
                "isDefaultRecipientsEnabled": '+ $Notification_ActiveAssignment_Approvers.isDefaultRecipientEnabed + ',
                "notificationLevel": "'+ $Notification_ActiveAssignment_Approvers.notificationLevel + '",
                "notificationRecipients": [
                '
            $Notification_ActiveAssignment_Approvers.Recipients | % {
                $rule += '"' + $_ + '",'
            }

            $rule += '
                ],
                "id": "Notification_Approver_Admin_Assignment",
                "ruleType": "RoleManagementPolicyNotificationRule",
                "target": {
                "caller": "Admin",
                "operations": [
                    "All"
                ],
                "level": "Eligibility",
                "targetObjects": null,
                "inheritableSettings": null,
                "enforcedSettings": null
                }
                }
                '
            $rules += $rule
        }

        
        # Notification Activation alert 
        if ($PSBoundParameters.Keys.Contains('Notification_Activation_Alert')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Admin",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Alert.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_Activation_Alert.notificationLevel + '",
        "notificationRecipients": [
        '
            $Notification_Activation_Alert.Recipients | % {
                $rule += '"' + $_ + '",'
            }

            $rule += '
        ],
        "id": "Notification_Admin_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
            $rules += $rule
        }

        # Notification Activation Assignee 
        if ($PSBoundParameters.Keys.Contains('Notification_Activation_Assignee')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Requestor",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Assignee.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_Activation_Assignee.notificationLevel + '",
        "notificationRecipients": [
        '
            $Notification_Activation_Assignee.Recipients | % {
                $rule += '"' + $_ + '",'
            }

            $rule += '
        ],
        "id": "Notification_Requestor_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
            $rules += $rule
        }

        # Notification Activation Approvers 
        if ($PSBoundParameters.Keys.Contains('Notification_Activation_Approvers')) {
            # @{"Notification_Eligibility_isDefaultRecipientEnabed"="true|false"; "Notification_EligibleAssignment_Alert_notificationLevel"="All|Critical"};"Notification_Admin_Admin_Eligibility_notificationRecipients" = @("email1@domain.com","email2@domain.com")} 
            $rule = '
        {
        "notificationType": "Email",
        "recipientType": "Approver",
        "isDefaultRecipientsEnabled": '+ $Notification_Activation_Approvers.isDefaultRecipientEnabed + ',
        "notificationLevel": "'+ $Notification_Activation_Approvers.notificationLevel + '",
        "notificationRecipients": [
        '
            <# 
            # Cant add backup recipient for this rule

            $Notification_Activation_Approvers.Recipients | % {
                $rule += '"' + $_ + '",'
            }
        #>
            $rule += '
        ],
        "id": "Notification_Approver_EndUser_Assignment",
        "ruleType": "RoleManagementPolicyNotificationRule",
        "target": {
        "caller": "Admin",
        "operations": [
            "All"
        ],
        "level": "Eligibility",
        "targetObjects": null,
        "inheritableSettings": null,
        "enforcedSettings": null
        }
        }
        '
            $rules += $rule
        }
        # bringing all the rules together
        $allrules = $rules -join ','
        #Write-Verbose "All rules: $allrules"

        $body = '
    {
        "properties": {
          "scope": "'+ $scope + '",  
          "rules": [
    '
        $body += $allrules
        $body += '
          ],
          "level": "Assignment"
        }
    }'
        write-verbose "`n>> PATCH body: $body"

        $response = Invoke-RestMethod -Uri $restUri -Method PATCH -Headers $authHeader -Body $body -verbose:$false
       
 
    }
    
    # finalize export
    $date=get-date -Format FileDate
    if(!($exportFilename)){$exportFilename = ".\EXPORTS\$date.csv"}
    $exportPath = Split-Path $exportFilename -Parent
    #create export folder if no exist
    if ( !(test-path  $exportFilename) ) {
        $null = New-Item -ItemType Directory -Path $exportPath -Force
    }
    $exports | select * | ConvertTo-Csv | out-file $exportFilename
    
}
catch {
    $_ # echo the exception
    $err = $($_.exception.message | out-string) 
    $errorRecord = $Error[0] 
    $details = $errorRecord.errordetails # |fl -force
    $position = $errorRecord.InvocationInfo.positionMessage
    $Exception = $ErrorRecord.Exception
    
    if ($TeamsNotif) { send-teamsnotif "$err" "$details<BR/> TIPS: try to check the scope and the role name" "$position" }
    Log "An exception occured: $err `nDetails: $details `nPosition: $position"
    Log "Error, script did not terminate normaly"
    break
}

log "Success! Script ended normaly"


