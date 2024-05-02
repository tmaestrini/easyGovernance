#############################################
#### M365 ADMIN CENTER Settings (Call API)
#############################################

<#
.Synopsis 
    Handle M365 Admin Center (MAC) Settings
.DESCRIPTION
.EXAMPLE
   Get-M365TenantSettings
#>
Function Get-M365TenantSettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("AccountLinking", "AdoptionScore", "AzureSpeechServices", "Bookings", "MSVivaBriefing", "CalendarSharing", "Copilot4Sales",
            "Cortana", "M365Groups", "M365AppsInstallationOpt", "M365Lighthouse", "M365OTW", "MSUserCommunication", "MSForms", "MSGraphDataConnect", "MSLoop", "MSPlanner",
            "MSSearchBing", "MSTeams", "MSTeamsAllowGuestAccess", "MSToDo", "MSVivaInsights", "ModernAuth", "News", "OfficeScripts", "Reports", "SearchIntelligenceAnalytics",
            "SharePoint", "Sway", "SwayShareWithExternalUsers", "UserOwnedAppsandServices", "VivaLearning", "Whiteboard")][string[]]$Properties
    )
    
    try {
        if (!$Global:connectionContextName) { throw "Get-M365TenantSettings > No connection context provided." }
        # Get-AzContext -Name $Global:connectionContextName | Out-Null
        $ctx = Get-AzContext -Name $Global:connectionContextName
        $tenantId = $ctx.Tenant.Id
        
        $apiSelection = switch ($Properties) {
            "AccountLinking" {  }  
            "AdoptionScore" {  }  
            "AzureSpeechServices" { @{name = $_; path = "admin/api/services/apps/azurespeechservices"; attr = "isTenantEnabled" } }
            "Bookings" { @{name = $_; path = "admin/api/settings/apps/bookings"; attr = "Enabled" } }
            "MSVivaBriefing" {  }
            "CalendarSharing" { @{name = $_; path = "admin/api/settings/apps/calendarsharing"; attr = "EnableCalendarSharing" } }
            "Copilot4Sales" { @{name = $_; path = "fd/peopleadminservice/$tenantId/settings/salesInsights"; attr = "isEnabledInOrganization" } }
            "Cortana" { @{name = $_; path = "admin/api/services/apps/cortana"; attr = "Enabled" } }
            "M365Groups" {  }
            "M365AppsInstallationOpt" { @{name = $_; path = "fd/dms/odata/TenantInfo($tenantId)"; attr = "EffectiveBranch" } }
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
            "MSToDo" { @{name = $_; path = "" } }
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

        $token = Get-AzAccessToken -ResourceUrl "https://admin.microsoft.com"
    }
    catch {
        throw $_
    }
    $headers = @{ Authorization = "Bearer $($token.Token)" }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $apiSelection | Foreach-Object {
        $req = $_
        try {
            $result = Invoke-RestMethod -Uri "https://admin.microsoft.com/$($req.path)" -Headers $headers
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