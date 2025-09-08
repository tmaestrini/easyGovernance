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
$Script:BaseUri = "https://api.interfaces.records.teams.microsoft.com"

Function Connect-TeamsAdminCenter {

    $resource = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239" # Microsoft Teams Admin Portal Service

    try {
        if (!$Global:connectionContextName) { throw "No valid access provided." }
        $ctx = Get-AzContext -Name $Global:connectionContextName

        $Script:TeamsAdminCenterToken = Get-AzAccessToken -ResourceUrl $resource -TenantId $ctx.Tenant.Id
        Write-Log -Level DEBUG "Connection established to Teams Admin Center"
    }
    catch {
        Write-Log -Level ERROR $_.Exception
    }
}

Function Invoke-TeamsAdminCenterRequest {
    param (
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
    
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
            $path = "$($Script:BaseUri)/$($req.path -replace "{{tenantId}}", $tenantId)"
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
    
    # TeamsTargetingPolicy in API call
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