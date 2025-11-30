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
        "AdoptionScore" { [ApiRequestDefinition]::new($_, "admin/api/reports/productivityScoreCustomerOption", "Output") }  
        "AzureSpeechServices" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/azurespeechservices", "isTenantEnabled") }
        "Bookings" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/bookings", "Enabled") }
        "MSVivaBriefing" {  }
        "CalendarSharing" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/calendarsharing", "EnableCalendarSharing") }
        "Copilot4Sales" { [ApiRequestDefinition]::new($_, "fd/peopleadminservice/{{tenantId}}/settings/salesInsights", "isEnabledInOrganization") }
        "Cortana" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/cortana", "Enabled") }
        "M365Groups" {  }
        "M365AppsInstallationOpt" { [ApiRequestDefinition]::new($_, "fd/dms/odata/TenantInfo({{tenantId}})", "EffectiveBranch") }
        "M365Lighthouse" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/m365lighthouse", "AccountEnabled") }
        "M365OTW" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/officeonline", "Enabled") }
        "MSUserCommunication" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/EndUserCommunications", "ServiceEnabled") }
        "MSForms" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/officeforms") }
        "MSGraphDataConnect" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/o365dataplan", "ServiceEnabled") }
        "MSLoop" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/looppolicy", "LoopPolicy") }
        "MSPlanner" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/planner", "allowCalendarSharing") }
        "MSTeams" { [ApiRequestDefinition]::new($_, "admin/api/users/teamssettingsinfo", "IsTeamsEnabled") }
        "MSTeamsAllowGuestAccess" { [ApiRequestDefinition]::new($_, "fd/IC3Config/Skype.Policy/configurations/TeamsClientConfiguration", "0.AllowGuestUser") }
        # "MSToDo" { @{name = $_; path = "n/a" } }
        "MSVivaInsights" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/vivainsights") }
        "ModernAuth" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/modernAuth", "EnableModernAuth") }
        "News" { [ApiRequestDefinition]::new($_, "admin/api/searchadminapi/news/options/Bing", "NewsOptions.HomepageOptions.IsEnabled") }
        "OfficeScripts" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/officescripts", "EnabledOption") }
        "Reports" { [ApiRequestDefinition]::new($_, "admin/api/reports/config/GetTenantConfiguration", "Output.0.PrivacyEnabled") }
        "SearchIntelligenceAnalytics" { [ApiRequestDefinition]::new($_, "admin/api/services/apps/searchintelligenceanalytics", "userFiltersOptIn") }
        "SharePoint" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/sitessharing", "CollaborationType") }
        "SwayShareWithExternalUsers" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/Sway", "ExternalSharingEnabled") }
        "UserOwnedAppsandServices" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/store") }
        "VivaLearning" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/learning") }
        "Whiteboard" { [ApiRequestDefinition]::new($_, "admin/api/settings/apps/whiteboard", "IsEnabled") }
        
        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
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
        "IdleSessionTimeout" { [ApiRequestDefinition]::new($_, "admin/api/settings/security/activitybasedtimeout") }
        "PasswordExpirationPolicyNeverExpire" { [ApiRequestDefinition]::new($_, "admin/api/Settings/security/passwordpolicy", "NeverExpire") }
        "PrivacyProfile" { [ApiRequestDefinition]::new($_, "admin/api/Settings/security/privacypolicy") }
        "Pronouns" { [ApiRequestDefinition]::new($_, "fd/peopleadminservice/{{tenantId}}/settings/pronouns") }
        "SharingAllowUsersToAddGuests" { [ApiRequestDefinition]::new($_, "admin/api/settings/security/guestUserPolicy", "AllowGuestInvitations") }
        
        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
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
        "CustomThemes" { [ApiRequestDefinition]::new($_, "admin/api/Settings/company/theme/v2") }
        "DataLocation" { [ApiRequestDefinition]::new($_, "admin/api/tenant/datalocation") }
        "HelpDeskInfo" { [ApiRequestDefinition]::new($_, "admin/api/Settings/company/helpdesk") }
        "ReleasePreferences" { [ApiRequestDefinition]::new($_, "admin/api/Settings/company/releasetrack", "ReleaseTrack") }
        "EmailNotFromOwnDomain" { [ApiRequestDefinition]::new($_, "admin/api/Settings/company/sendfromaddress", "ServiceEnabled") }
        
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
        "LicensedProducts" { [ApiRequestDefinition]::new($_, "fd/m365licensing/v3/licensedProducts?allotmentSourceOwnerType=User&allotmentSourceType=LowFrictionTrial&allotmentSourceState=Active%2CDeleted%2CSuspended%2CLockout%2CWarning&displayNameLanguage=en-US", "value") }
        "OnlyGroupBasedLicenseAssignmentOld" { [ApiRequestDefinition]::new($_, "fd/CommerceAPI/my-org/subscriptions?`$expand=subscribedSku&`$filter=parentId%20eq%20null%20and%20isBoxUi%20eq%20true%20and%20status%20ne%204", "value") }
        "OnlyGroupBasedLicenseAssignment" { [ApiRequestDefinition]::new($_, "fd/MSGraph/v1.0/users?`$select=displayName,licenseAssignmentStates", "value") }
        "DirectLicenseAssignments" { [ApiRequestDefinition]::new($_, "fd/MSGraph/v1.0/users?`$select=displayName,licenseAssignmentStates", "value") }
        "GroupLicenseAssignments" { [ApiRequestDefinition]::new($_, "fd/MSGraph/v1.0/groups?`$select=displayName,assignedLicenses", "value") }
        "SelfServicePurchase" { [ApiRequestDefinition]::new($_, "admin/api/selfServicePurchasePolicy/products", "items") }
        "AssignmentErrors" { [ApiRequestDefinition]::new($_, "fd/MSGraph/beta/admin/cloudLicensing/assignmentErrors?%24top=100&%24expand=assignedTo", "value") }
        Default {}
    }

    try {
        return Invoke-M365AdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}
