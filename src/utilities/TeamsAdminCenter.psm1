#############################################
#### TEAMS Admin Center Settings (Call API)
#############################################

<#
.Synopsis
    Handle TEAMS Admin Center (TAC) Settings.
    Don't forget to call Connect-TeamsAdminCenter before using any other functions.
.DESCRIPTION
.EXAMPLE
   Connect-TeamsAdminCenter
#>

$Script:TeamsAdminCenterToken = $null
$Script:ScopeConfig = @{}

Function Connect-TeamsAdminCenter {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "Scope1")] [string]$Scope = "Standard"
    )

    $Script:ScopeConfig = switch ($Scope) {
        "Scope1" { 
            @{
                Resource = "https://api.spaces.skype.com"  # Microsoft Teams Policy Center
                BaseUrl  = "https://admin.microsoft.com/api"
            }
        }
        Default { 
            @{
                Resource = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239"  # Microsoft Teams Admin Portal Service
                BaseUrl  = "https://api.interfaces.records.teams.microsoft.com"
            }
        }
    }    
    
    try {
        if (!$Global:connectionContextName) { throw "No valid access provided." }
        $ctx = Get-AzContext -Name $Global:connectionContextName

        $Script:TeamsAdminCenterToken = Get-AzAccessToken -ResourceUrl $Script:ScopeConfig.Resource -TenantId $ctx.Tenant.Id
        Write-Log -Level DEBUG "Connection established to Teams Admin Center ($Scope)"
    }
    catch {
        Write-Log -Level ERROR $_.Exception
    }
}

Function Invoke-TeamsAdminCenterRequest {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "Scope1")] [string]$Scope = "Standard",
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
        
    if ($Scope -ne "Standard") {
        Connect-TeamsAdminCenter -Scope $Scope
    }

    try {
        if (!$Global:connectionContextName) { throw "No connection context provided." }
        if ($null -eq $Script:TeamsAdminCenterToken) { throw "No token available, please connect first." }

        $token = ConvertFrom-SecureString $Script:TeamsAdminCenterToken.Token -AsPlainText
    }
    catch {
        Write-Log -Level WARNING "Failed to invoke request(s): $_"
        throw $_
    }

    $headers = @{ Authorization = "Bearer $token" }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $path = "$($Script:ScopeConfig.BaseUrl)/$($req.path -replace "{{tenantId}}", $tenantId)"
            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -OperationTimeoutSeconds 30 -RetryIntervalSec 1 -MaximumRetryCount 3 -ConnectionTimeoutSeconds 10
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value ($req.attr ? $result.$($req.attr) : $result)
        }
        catch {
            Write-Log -Level ERROR "$($req.name) / Error: $_"
        }
    }
    
    $requests | Foreach-Object -Parallel {
        try {
            $_
        }
        catch {
            Write-Log -Level ERROR $_
        } 
    } -ThrottleLimit 5
    return $propertiesValues
}

Function Get-TeamsSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("FeedSuggestionsInUsersActivityFeed", "WhoCanManageTags", "LetTeamOwnersChangeWhoCanManageTags", 
            "CustomTags", "ShiftsAppCanApplyTags", "AllowEmailIntoChannel", "AllowCitrix", "AllowDropBox", 
            "AllowBox", "AllowGoogleDrive", "AllowEgnyte", "AllowOrganizationTabForUsers", 
            "Require2ndAuthforMeeting", "SetContentPin", "SurfaceHubCanSendMails", "ScopeDirectorySearch", 
            "ExtendedWorkInfoInPeopleSearch", "RoleBasedChatPermissions", "ProvideLinkToSupportRequestPage")]
        [string[]]$Properties
    )

    $feedSuggestionsInUsersActivityFeedProperties = @("FeedSuggestionsInUsersActivityFeed")
    $teamsTargetingProperties = @("WhoCanManageTags", "LetTeamOwnersChangeWhoCanManageTags", "CustomTags", "ShiftsAppCanApplyTags")
    $teamsClientProperties = @("AllowEmailIntoChannel", "AllowCitrix", "AllowDropBox", "AllowBox", "AllowGoogleDrive", 
        "AllowEgnyte", "AllowOrganizationTabForUsers", "Require2ndAuthforMeeting", "SetContentPin", 
        "SurfaceHubCanSendMails", "ScopeDirectorySearch", "ExtendedWorkInfoInPeopleSearch", "RoleBasedChatPermissions", "ProvideLinkToSupportRequestPage")

    $apiSelection = @()
    
    # FeedSuggestionsInUsersActivityFeed in API call
    if ($Properties | Where-Object { $_ -in $feedSuggestionsInUsersActivityFeedProperties }) {
        $apiSelection += @{name = "FeedSuggestionsInUsersActivityFeed"; path = "Skype.Policy/configurations/TeamsNotificationAndFeedsPolicy/configuration/Global"; attr = "SuggestedFeedsEnabledType" }
    }
    # TeamsTargetingPolicy in API call
    if ($Properties | Where-Object { $_ -in $teamsTargetingProperties }) {
        $apiSelection += @{
            name = "TeamsTargetingPolicy"; path = "Skype.Policy/configurations/TeamsTargetingPolicy/configuration/Global"
        }
    }
    # TeamsClientConfiguration in API call
    if ($Properties | Where-Object { $_ -in $teamsClientProperties }) {
        $apiSelection += @{
            name = "TeamsClientConfiguration"; path = "Skype.Policy/configurations/TeamsClientConfiguration/configuration/Global"
        }
    }

    # Only make the API call if we have requests to make
    if ($apiSelection.Count -gt 0) {
        try {
            return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
        }
        catch { 
            throw $_
        }
    }
    else {
        Write-Log -Level WARNING "No matching API requests found for the specified properties"
        return @{}
    }
}

Function Get-TeamsPolicies {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("OrgWideTeamsPolicy")]
        [string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "OrgWideTeamsPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsChannelsPolicy/configuration/Global" } }

        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
    }

    try {
        return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}

Function Get-AppsPolicies {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("OrgWideAppPolicy")]
        [string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "OrgWideAppPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsAppSetupPolicy" } }

        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
    }

    try {
        return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}

Function Get-CallingPolicies {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("OrgWideCallingPolicy")]
        [string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "OrgWideCallingPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsCallingPolicy/configuration/Global" } }

        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
    }

    try {
        return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}

Function Get-MeetingsPolicies {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("OrgWideMeetingsPolicy")]
        [string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "GlobalMeetingsPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsMeetingPolicy/configuration/Global" } }

        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
    }

    try {
        return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}