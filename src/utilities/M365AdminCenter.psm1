using module "../Private/Validation/Class/ApiRequestDefinition.psm1"

#############################################
#### M365 ADMIN CENTER Settings (Call API)
#############################################

<#
.Synopsis 
    Handle M365 Admin Center (MAC) Settings.
    Don't forget to call Connect-M365AdminCenter before using any other functions.
.DESCRIPTION
.EXAMPLE
   Connect-M365AdminCenter
   Get-M365TenantSettingsServices
#>

$Script:M365AdminCenterToken = $null
$Script:TenantId = $null

Function Connect-M365AdminCenter {

    $resource = "https://admin.microsoft.com"

    try {
        if (!$Global:connectionContextName) { throw "No valid access provided." }
        $ctx = Get-AzContext -Name $Global:connectionContextName
        
        $Script:TenantId = $ctx.Tenant.Id
        $Script:M365AdminCenterToken = Get-AzAccessToken -ResourceUrl $resource -TenantId $Script:TenantId
        Write-Log -Level DEBUG "Connection established to M365 Admin Center"
    }
    catch {
        Write-Log -Level ERROR $_.Exception
    }
}

Function Invoke-M365AdminCenterRequest {
    param (
        [Parameter(Mandatory = $true)][ApiRequestDefinition[]]$ApiRequests
    )
    
    try {
        if (!$Global:connectionContextName) { throw "No connection context provided." }
        if ($null -eq $Script:M365AdminCenterToken) { throw "No token available, please connect first." }
    
        $token = ConvertFrom-SecureString $Script:M365AdminCenterToken.Token -AsPlainText
    }
    catch {
        Write-Log -Level WARNING "Failed to invoke request(s): $_"
        throw $_
    }

    $headers = @{ 
        Authorization = "Bearer $token" 
        "Content-Type" = "application/json"
    }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $url = [System.UriBuilder]::new("https://admin.microsoft.com")
            $url.Path = [System.IO.Path]::Combine($url.Path, ($req.path -replace "{{tenantId}}", $Script:TenantId))

            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $url.Uri -Headers $headers -Method "$($method)" -OperationTimeoutSeconds 30 -RetryIntervalSec 1 -MaximumRetryCount 3 -ConnectionTimeoutSeconds 10
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

Function Get-M365TenantSettingsServices {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("AccountLinking", "AdoptionScore", "AzureSpeechServices", "Bookings", "MSVivaBriefing", "CalendarSharing", "Copilot4Sales",
            "Cortana", "M365Groups", "M365AppsInstallationOpt", "M365Lighthouse", "M365OTW", "MSUserCommunication", "MSForms", "MSGraphDataConnect", "MSLoop", "MSPlanner",
            "MSTeams", "MSTeamsAllowGuestAccess", "MSToDo", "MSVivaInsights", "ModernAuth", "News", "OfficeScripts", "Reports", "SearchIntelligenceAnalytics",
            "SharePoint", "Sway", "SwayShareWithExternalUsers", "UserOwnedAppsandServices", "VivaLearning", "Whiteboard")][string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "AccountLinking" {  }  
        "AdoptionScore" { [ApiRequestDefinition]@{name = $_; path = "admin/api/reports/productivityScoreCustomerOption"; attr = "Output" } }  
        "AzureSpeechServices" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/azurespeechservices"; attr = "isTenantEnabled" } }
        "Bookings" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/bookings"; attr = "Enabled" } }
        "MSVivaBriefing" {  }
        "CalendarSharing" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/calendarsharing"; attr = "EnableCalendarSharing" } }
        "Copilot4Sales" { [ApiRequestDefinition]@{name = $_; path = "fd/peopleadminservice/{{tenantId}}/settings/salesInsights"; attr = "isEnabledInOrganization" } }
        "Cortana" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/cortana"; attr = "Enabled" } }
        "M365Groups" {  }
        "M365AppsInstallationOpt" { [ApiRequestDefinition]@{name = $_; path = "fd/dms/odata/TenantInfo({{tenantId}})"; attr = "EffectiveBranch" } }
        "M365Lighthouse" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/m365lighthouse"; attr = "AccountEnabled" } }
        "M365OTW" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/officeonline"; attr = "Enabled" } }
        "MSUserCommunication" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/EndUserCommunications"; attr = "ServiceEnabled" } }
        "MSForms" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/officeforms" } }
        "MSGraphDataConnect" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/o365dataplan"; attr = "ServiceEnabled" } }
        "MSLoop" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/looppolicy"; attr = "LoopPolicy" } }
        "MSPlanner" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/planner"; attr = "allowCalendarSharing" } }
        "MSTeams" { [ApiRequestDefinition]@{name = $_; path = "admin/api/users/teamssettingsinfo"; attr = "IsTeamsEnabled" } }
        "MSTeamsAllowGuestAccess" { [ApiRequestDefinition]@{name = $_; path = "fd/IC3Config/Skype.Policy/configurations/TeamsClientConfiguration"; attr = "0.AllowGuestUser" } }
        # "MSToDo" { @{name = $_; path = "n/a" } }
        "MSVivaInsights" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/vivainsights" } }
        "ModernAuth" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/modernAuth" ; attr = "EnableModernAuth" } }
        "News" { [ApiRequestDefinition]@{name = $_; path = "admin/api/searchadminapi/news/options/Bing" ; attr = "NewsOptions.HomepageOptions.IsEnabled" } }
        "OfficeScripts" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/officescripts" ; attr = "EnabledOption" } }
        "Reports" { [ApiRequestDefinition]@{name = $_; path = "admin/api/reports/config/GetTenantConfiguration" ; attr = "Output.0.PrivacyEnabled" } }
        "SearchIntelligenceAnalytics" { [ApiRequestDefinition]@{name = $_; path = "admin/api/services/apps/searchintelligenceanalytics" ; attr = "userFiltersOptIn" } }
        "SharePoint" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/sitessharing"; attr = "CollaborationType" } }
        "SwayShareWithExternalUsers" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/Sway"; attr = "ExternalSharingEnabled" } }
        "UserOwnedAppsandServices" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/store" } }
        "VivaLearning" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/learning" } }
        "Whiteboard" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/apps/whiteboard"; attr = "IsEnabled" } }
        
        Default {}
    }

    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}

Function Get-M365TenantSettingsSecurityAndPrivacy {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("IdleSessionTimeout", "PasswordExpirationPolicyNeverExpire", "PrivacyProfile", "Pronouns", "SharingAllowUsersToAddGuests")][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "IdleSessionTimeout" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/security/activitybasedtimeout" } }
        "PasswordExpirationPolicyNeverExpire" { [ApiRequestDefinition]@{name = $_; path = "admin/api/Settings/security/passwordpolicy"; attr = "NeverExpire" } }
        "PrivacyProfile" { [ApiRequestDefinition]@{name = $_; path = "admin/api/Settings/security/privacypolicy" } }
        "Pronouns" { [ApiRequestDefinition]@{name = $_; path = "fd/peopleadminservice/{{tenantId}}/settings/pronouns" } }
        "SharingAllowUsersToAddGuests" { [ApiRequestDefinition]@{name = $_; path = "admin/api/settings/security/guestUserPolicy"; attr = "AllowGuestInvitations" } }
        
        Default {}
    }
    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch {
        throw $_
     }
}

Function Get-M365TenantSettingsOrgProfile {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("CustomThemes", "DataLocation", "HelpDeskInfo", "ReleasePreferences", "EmailNotFromOwnDomain")][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "CustomThemes" { [ApiRequestDefinition]@{name = $_; path = "admin/api/Settings/company/theme/v2" } }
        "DataLocation" { [ApiRequestDefinition]@{name = $_; path = "admin/api/tenant/datalocation" } }
        "HelpDeskInfo" { [ApiRequestDefinition]@{name = $_; path = "admin/api/Settings/company/helpdesk" } }
        "ReleasePreferences" { [ApiRequestDefinition]@{name = $_; path = "admin/api/Settings/company/releasetrack"; attr = "ReleaseTrack" } }
        "EmailNotFromOwnDomain" { [ApiRequestDefinition]@{name = $_; path = "admin/api/Settings/company/sendfromaddress"; attr = "ServiceEnabled" } }
        
        Default {}
    }
    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch {
        throw $_     
    }
}

Function Get-M365TenantLicensing {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("LicensedProducts", "OnlyGroupBasedLicenseAssignment", "SelfServicePurchase", "AssignmentErrors", "DirectLicenseAssignments", "GroupLicenseAssignments")][string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "LicensedProducts" { [ApiRequestDefinition]@{ name = $_; path = "fd/m365licensing/v3/licensedProducts?allotmentSourceOwnerType=User&allotmentSourceType=LowFrictionTrial&allotmentSourceState=Active%2CDeleted%2CSuspended%2CLockout%2CWarning&displayNameLanguage=en-US"; attr = "value" } }
        "OnlyGroupBasedLicenseAssignmentOld" { [ApiRequestDefinition]@{name = $_; path = "fd/CommerceAPI/my-org/subscriptions?`$expand=subscribedSku&`$filter=parentId%20eq%20null%20and%20isBoxUi%20eq%20true%20and%20status%20ne%204"; attr = "value" } }
        "OnlyGroupBasedLicenseAssignment" { [ApiRequestDefinition]@{ name = $_; path = "fd/MSGraph/v1.0/users?`$select=displayName,licenseAssignmentStates"; attr = "value" } }
        "DirectLicenseAssignments" { [ApiRequestDefinition]@{ name = $_; path = "fd/MSGraph/v1.0/users?`$select=displayName,licenseAssignmentStates"; attr = "value" } }
        "GroupLicenseAssignments" { [ApiRequestDefinition]@{ name = $_; path = "fd/MSGraph/v1.0/groups?`$select=displayName,assignedLicenses"; attr = "value" } }
        "SelfServicePurchase" { [ApiRequestDefinition]@{name = $_; path = "admin/api/selfServicePurchasePolicy/products"; attr = "items" } }
        "AssignmentErrors" { [ApiRequestDefinition]@{ name = $_; path = "fd/MSGraph/beta/admin/cloudLicensing/assignmentErrors?%24top=100&%24expand=assignedTo"; attr = "value" } }
        Default {}
    }

    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}
