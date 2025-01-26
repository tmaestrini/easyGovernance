####################################################
#### POWER PLATFORM ADMIN CENTER Settings (Call API)
####################################################

<#
.Synopsis 
    Handle Power Platform (PPL) Admin Center Settings
.DESCRIPTION
.EXAMPLE
   
#>

Function Invoke-PPLAdminCenterRequest {
    param (
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
    
    if (!$Global:connectionContextName) { throw "Invoke-PPLAdminCenterRequest > No connection context provided." }
    $ctx = Get-AzContext -Name $Global:connectionContextName
    $tenantId = $ctx.Tenant.Id

    $token = Get-AzAccessToken -ResourceUrl "https://service.powerapps.com"
    $headers = @{ Authorization = "Bearer $($token.Token)" }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $path = "https://api.bap.microsoft.com/providers/$($req.path -replace "{{tenantId}}", $tenantId)"
            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -RetryIntervalSec 1 -MaximumRetryCount 10 -ConnectionTimeoutSeconds 10
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value ($req.attr ? $result.$($req.attr) : $result)
        }
        catch {
            Write-Log -Level ERROR "PPL Admin Center: $($req.name) / $_"
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

Function Get-PPLEnvironmentSettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("DefaultEnvironment.Name", "DevelopmentEnvironments.DisableDeveloperEnvironmentCreationByNonAdminUsers",
            "ProductionEnvironments.DisableEnvironmentCreationByNonAdminUsers", "TrialEnvironments.DisableEnvironmentCreationByNonAdminUsers"
        )][string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "DefaultEnvironment.Name" { @{name = $_; path = "Microsoft.BusinessAppPlatform/scopes/admin/environments/?api-version=2024-05-01&`$filter=properties/environmentSku eq 'Default'"; attr="value"} }  
        # "AdoptionScore" {  }  
        # "AzureSpeechServices" { @{name = $_; path = "admin/api/services/apps/azurespeechservices"; attr = "isTenantEnabled" } }
        # "Bookings" { @{name = $_; path = "admin/api/settings/apps/bookings"; attr = "Enabled" } }
        # "MSVivaBriefing" {  }
        # "CalendarSharing" { @{name = $_; path = "admin/api/settings/apps/calendarsharing"; attr = "EnableCalendarSharing" } }
        # "Copilot4Sales" { @{name = $_; path = "fd/peopleadminservice/{{tenantId}}/settings/salesInsights"; attr = "isEnabledInOrganization" } }
        # "Cortana" { @{name = $_; path = "admin/api/services/apps/cortana"; attr = "Enabled" } }
        # "M365Groups" {  }
        # "M365AppsInstallationOpt" { @{name = $_; path = "fd/dms/odata/TenantInfo({{tenantId}})"; attr = "EffectiveBranch" } }
        # "M365Lighthouse" { @{name = $_; path = "admin/api/services/apps/m365lighthouse"; attr = "AccountEnabled" } }
        # "M365OTW" { @{name = $_; path = "admin/api/settings/apps/officeonline"; attr = "Enabled" } }
        # "MSUserCommunication" { @{name = $_; path = "admin/api/settings/apps/EndUserCommunications"; attr = "ServiceEnabled" } }
        # "MSForms" { @{name = $_; path = "admin/api/settings/apps/officeforms" } }
        # "MSGraphDataConnect" { @{name = $_; path = "admin/api/settings/apps/o365dataplan"; attr = "ServiceEnabled" } }
        # "MSLoop" { @{name = $_; path = "admin/api/settings/apps/looppolicy"; attr = "LoopPolicy" } }
        # "MSPlanner" { @{name = $_; path = "admin/api/services/apps/planner"; attr = "isPlannerAllowed" } }
        # "MSSearchBing" { @{name = $_; path = "admin/api/searchadminapi/configurations"; attr = "ServiceEnabled" } }
        # "MSTeams" { @{name = $_; path = "admin/api/users/teamssettingsinfo"; attr = "IsTeamsEnabled" } }
        # "MSTeamsAllowGuestAccess" { @{name = $_; path = "fd/IC3Config/Skype.Policy/configurations/TeamsClientConfiguration"; attr = "0.AllowGuestUser" } }
        # # "MSToDo" { @{name = $_; path = "n/a" } }
        # "MSVivaInsights" { @{name = $_; path = "admin/api/services/apps/vivainsights" } }
        # "ModernAuth" { @{name = $_; path = "admin/api/services/apps/modernAuth" ; attr = "EnableModernAuth" } }
        # "News" { @{name = $_; path = "admin/api/searchadminapi/news/options/Bing" ; attr = "NewsOptions.HomepageOptions.IsEnabled" } }
        # "OfficeScripts" { @{name = $_; path = "admin/api/settings/apps/officescripts" ; attr = "EnabledOption" } }
        # "Reports" { @{name = $_; path = "admin/api/reports/config/GetTenantConfiguration" ; attr = "Output.0.PrivacyEnabled" } }
        # "SearchIntelligenceAnalytics" { @{name = $_; path = "admin/api/services/apps/searchintelligenceanalytics" ; attr = "userFiltersOptIn" } }
        # "SharePoint" { @{name = $_; path = "admin/api/settings/apps/sitessharing"; attr = "CollaborationType" } }
        # "SwayShareWithExternalUsers" { @{name = $_; path = "admin/api/settings/apps/Sway"; attr = "ExternalSharingEnabled" } }
        # "UserOwnedAppsandServices" { @{name = $_; path = "admin/api/settings/apps/store" } }
        # "VivaLearning" { @{name = $_; path = "admin/api/settings/apps/learning" } }
        # "Whiteboard" { @{name = $_; path = "admin/api/settings/apps/whiteboard"; attr = "IsEnabled" } }
        
        Default {}
    }

    try {
        return Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { }
}

Function Get-PPLDataPoliciesSettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("DefaultEnvironment.PolicyName", "DefaultEnvironment.OnlyCoreConnectorsAllowed", 
            "NonDefaultEnvironments.MinimalActivePolicies"
        )][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "DefaultEnvironment.PolicyName" { @{name = $_; path = "admin/api/settings/security/activitybasedtimeout"; attr = "properties" } }
        "DefaultEnvironment.OnlyCoreConnectorsAllowed" { @{name = $_; path = "admin/api/Settings/security/passwordpolicy"; attr = "NeverExpire" } }
        "NonDefaultEnvironments.MinimalActivePolicies" { @{name = $_; path = "admin/api/Settings/security/privacypolicy" } }
        
        Default {}
    }
    try {
        return Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { }
}

Function Get-PPLSecuritySettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("TenantIsolation.IsolationControl", "ContentSecurityPolicy.CanvasApps", "ContentSecurityPolicy.ModelDrivenApps",
            "ContentSecurityPolicy.EnableReportingViolations", "ContentSecurityPolicy.EnableForDefaultEnvironment", 
            "ContentSecurityPolicy.EnableForDevelopmentEnvironments", "ContentSecurityPolicy.EnableForProductionEnvironments"
        )][string[]]$Properties
    )
    

    $apiSelection = switch ($Properties) {
        "TenantIsolation.IsolationControl" { @{name = $_; path = "admin/api/Settings/company/theme/v2" } }
        "ContentSecurityPolicy.CanvasApps" { @{name = $_; path = "admin/api/tenant/datalocation" } }
        "ContentSecurityPolicy.ModelDrivenApps" { @{name = $_; path = "admin/api/Settings/company/helpdesk" } }
        "ContentSecurityPolicy.EnableReportingViolations" { @{name = $_; path = "admin/api/Settings/company/releasetrack"; attr = "ReleaseTrack" } }
        "ContentSecurityPolicy.EnableForDefaultEnvironment" { @{name = $_; path = "admin/api/Settings/company/sendfromaddress"; attr = "ServiceEnabled" } }
        "ContentSecurityPolicy.EnableForDevelopmentEnvironments" { @{name = $_; path = "admin/api/Settings/company/sendfromaddress"; attr = "ServiceEnabled" } }
        "ContentSecurityPolicy.EnableForProductionEnvironments" { @{name = $_; path = "admin/api/Settings/company/sendfromaddress"; attr = "ServiceEnabled" } }
        
        Default {}
    }
    try {
        return Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { }
}