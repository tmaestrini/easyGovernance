#############################################
#### M365 ADMIN CENTER Settings (Call API)
#############################################

<#
.Synopsis 
    Handle M365 Admin Center (MAC) Settings
.DESCRIPTION
.EXAMPLE
   Get-M365TenantSettingsServices
#>

Function Invoke-M365AdminCenterRequest {
    param (
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
    
    if (!$Global:connectionContextName) { throw "Invoke-M365AdminCenterRequest > No connection context provided." }
    $ctx = Get-AzContext -Name $Global:connectionContextName
    $tenantId = $ctx.Tenant.Id

    $token = Get-AzAccessToken -ResourceUrl "https://admin.microsoft.com"
    $headers = @{ Authorization = "Bearer $($token.Token)" }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            # $path = ($req.path) -replace "{{tenantId}}", $tenantId
            $path = "https://admin.microsoft.com/$($req.path -replace "{{tenantId}}", $tenantId)"
            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -RetryIntervalSec 1 -MaximumRetryCount 10 -ConnectionTimeoutSeconds 10
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value ($req.attr ? $result.$($req.attr) : $result)
        }
        catch {
            Write-Log -Level ERROR "M365 Admin Center: $($req.name) / $_"
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
            "MSSearchBing", "MSTeams", "MSTeamsAllowGuestAccess", "MSToDo", "MSVivaInsights", "ModernAuth", "News", "OfficeScripts", "Reports", "SearchIntelligenceAnalytics",
            "SharePoint", "Sway", "SwayShareWithExternalUsers", "UserOwnedAppsandServices", "VivaLearning", "Whiteboard")][string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "AccountLinking" {  }  
        "AdoptionScore" {  }  
        "AzureSpeechServices" { @{name = $_; path = "admin/api/services/apps/azurespeechservices"; attr = "isTenantEnabled" } }
        "Bookings" { @{name = $_; path = "admin/api/settings/apps/bookings"; attr = "Enabled" } }
        "MSVivaBriefing" {  }
        "CalendarSharing" { @{name = $_; path = "admin/api/settings/apps/calendarsharing"; attr = "EnableCalendarSharing" } }
        "Copilot4Sales" { @{name = $_; path = "fd/peopleadminservice/{{tenantId}}/settings/salesInsights"; attr = "isEnabledInOrganization" } }
        "Cortana" { @{name = $_; path = "admin/api/services/apps/cortana"; attr = "Enabled" } }
        "M365Groups" {  }
        "M365AppsInstallationOpt" { @{name = $_; path = "fd/dms/odata/TenantInfo({{tenantId}})"; attr = "EffectiveBranch" } }
        "M365Lighthouse" { @{name = $_; path = "admin/api/services/apps/m365lighthouse"; attr = "AccountEnabled" } }
        "M365OTW" { @{name = $_; path = "admin/api/settings/apps/officeonline"; attr = "Enabled" } }
        "MSUserCommunication" { @{name = $_; path = "admin/api/settings/apps/EndUserCommunications"; attr = "ServiceEnabled" } }
        "MSForms" { @{name = $_; path = "admin/api/settings/apps/officeforms" } }
        "MSGraphDataConnect" { @{name = $_; path = "admin/api/settings/apps/o365dataplan"; attr = "ServiceEnabled" } }
        "MSLoop" { @{name = $_; path = "admin/api/settings/apps/looppolicy"; attr = "LoopPolicy" } }
        "MSPlanner" { @{name = $_; path = "admin/api/services/apps/planner"; attr = "isPlannerAllowed" } }
        "MSSearchBing" { @{name = $_; path = "fd/bfb/api/v3/office/switch/feature"; attr = "BingDefault" } }
        "MSTeams" { @{name = $_; path = "admin/api/users/teamssettingsinfo"; attr = "IsTeamsEnabled" } }
        "MSTeamsAllowGuestAccess" { @{name = $_; path = "fd/IC3Config/Skype.Policy/configurations/TeamsClientConfiguration"; attr = "0.AllowGuestUser" } }
        # "MSToDo" { @{name = $_; path = "n/a" } }
        "MSVivaInsights" { @{name = $_; path = "admin/api/services/apps/vivainsights" } }
        "ModernAuth" { @{name = $_; path = "admin/api/services/apps/modernAuth" ; attr = "EnableModernAuth" } }
        "News" { @{name = $_; path = "admin/api/searchadminapi/news/options/Bing" ; attr = "NewsOptions.HomepageOptions.IsEnabled" } }
        "OfficeScripts" { @{name = $_; path = "admin/api/settings/apps/officescripts" ; attr = "EnabledOption" } }
        "Reports" { @{name = $_; path = "admin/api/reports/config/GetTenantConfiguration" ; attr = "Output.0.PrivacyEnabled" } }
        "SearchIntelligenceAnalytics" { @{name = $_; path = "admin/api/services/apps/searchintelligenceanalytics" ; attr = "userFiltersOptIn" } }
        "SharePoint" { @{name = $_; path = "admin/api/settings/apps/sitessharing"; attr = "CollaborationType" } }
        "SwayShareWithExternalUsers" { @{name = $_; path = "admin/api/settings/apps/Sway"; attr = "ExternalSharingEnabled" } }
        "UserOwnedAppsandServices" { @{name = $_; path = "admin/api/settings/apps/store" } }
        "VivaLearning" { @{name = $_; path = "admin/api/settings/apps/learning" } }
        "Whiteboard" { @{name = $_; path = "admin/api/settings/apps/whiteboard"; attr = "IsEnabled" } }
        
        Default {}
    }

    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch { }
}

Function Get-M365TenantSettingsSecurityAndPrivacy {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("IdleSessionTimeout", "PasswordExpirationPolicyNeverExpire", "PrivacyProfile", "Pronouns", "SharingAllowUsersToAddGuests")][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "IdleSessionTimeout" { @{name = $_; path = "admin/api/settings/security/activitybasedtimeout" } }
        "PasswordExpirationPolicyNeverExpire" { @{name = $_; path = "admin/api/Settings/security/passwordpolicy"; attr = "NeverExpire" } }
        "PrivacyProfile" { @{name = $_; path = "admin/api/Settings/security/privacypolicy" } }
        "Pronouns" { @{name = $_; path = "fd/peopleadminservice/{{tenantId}}/settings/pronouns"; attr = "isEnabledInOrganization" } }
        "SharingAllowUsersToAddGuests" { @{name = $_; path = "admin/api/settings/security/guestUserPolicy"; attr = "AllowGuestInvitations" } }
        
        Default {}
    }
    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch { }
}

Function Get-M365TenantSettingsOrgProfile {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("CustomThemes", "DataLocation", "HelpDeskInfo", "ReleasePreferences", "EmailNotFromOwnDomain")][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "CustomThemes" { @{name = $_; path = "admin/api/Settings/company/theme/v2" } }
        "DataLocation" { @{name = $_; path = "admin/api/tenant/datalocation" } }
        "HelpDeskInfo" { @{name = $_; path = "admin/api/Settings/company/helpdesk" } }
        "ReleasePreferences" { @{name = $_; path = "admin/api/Settings/company/releasetrack"; attr = "ReleaseTrack" } }
        "EmailNotFromOwnDomain" { @{name = $_; path = "admin/api/Settings/company/sendfromaddress"; attr = "ServiceEnabled" } }
        
        Default {}
    }
    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch { }
}