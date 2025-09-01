using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-1.1
#>
Function Test-M365.1-1.1 {
  [CmdletBinding()]
  [Alias()]
  [OutputType([hashtable])]
  
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The baseline itself"
    )][PSCustomObject]$Baseline,
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the tenant (https://[tenantId].sharepoint.com)"
    )][string] $tenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    class M365TenantValidator : BaselineValidator {
      M365TenantValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}
  
      Connect() {
        # Connection is handled system-wide
      }

      [PSCustomObject] Extract() {
        $settings = @{}

        # Office365Services
        $settings.Services = Get-M365TenantSettingsServices -Properties AdoptionScore, AzureSpeechServices, Bookings, CalendarSharing, Cortana, Copilot4Sales, M365AppsInstallationOpt, `
          M365Lighthouse, MSGraphDataConnect, MSLoop, MSPlanner, M365Groups, M365OTW, ModernAuth, MSForms, MSTeams, MSTeamsAllowGuestAccess, MSToDo, MSUserCommunication, `
          MSVivaBriefing, MSVivaInsights, OfficeScripts, Reports, SearchIntelligenceAnalytics, SharePoint, Sway, SwayShareWithExternalUsers, `
          UserOwnedAppsandServices, VivaLearning, Whiteboard
        
        # SecurityAndPrivacy
        $settings.SecurityAndPrivacy = Get-M365TenantSettingsSecurityAndPrivacy -Properties IdleSessionTimeout, PasswordExpirationPolicyNeverExpire, PrivacyProfile, Pronouns, SharingAllowUsersToAddGuests
        
        #OrganizationProfile
        $settings.OrganizationProfile = Get-M365TenantSettingsOrgProfile -Properties CustomThemes, DataLocation, HelpDeskInfo, ReleasePreferences, EmailNotFromOwnDomain
        
        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}
      
        # Office365Services
        $settings.AccountLinking = "n/a"
        $adoptionScoreSettings = $extractedSettings.Services.AdoptionScore | ConvertFrom-Json
        $settings.AdoptionScore = @{
          ActionFlowOptedIn    = $adoptionScoreSettings[0].ActionFlowOptedInValue;
          CohortInsightOptedIn = $adoptionScoreSettings[0].CohortInsightOptedInValue;
          PSGroupsOptedOut     = $adoptionScoreSettings[0].PSGroupsOptedOutValue;
        }
        $settings.AzureSpeechServices = $extractedSettings.Services.AzureSpeechServices
        $settings.Bookings = $extractedSettings.Services.Bookings
        $settings.CalendarSharing = $extractedSettings.Services.CalendarSharing
        $settings.Copilot4Sales = $extractedSettings.Services.Copilot4Sales
        $settings.Cortana = $extractedSettings.Services.Cortana
        $settings.M365Groups = "needs to be specified"
        $settings.M365AppsInstallationOpt = $extractedSettings.Services.M365AppsInstallationOpt
        $settings.M365Lighthouse = $extractedSettings.Services.M365Lighthouse
        $settings.M365OTW = $extractedSettings.Services.M365OTW
        $settings.MSUserCommunication = $extractedSettings.Services.MSUserCommunication
        $settings.MSForms = "needs to be specified"
        $settings.MSGraphDataConnect = $extractedSettings.Services.MSGraphDataConnect
        $settings.MSLoop = $extractedSettings.Services.MSLoop
        $settings.MSPlanner = @{
          allowCalendarSharing = $extractedSettings.Services.MSPlanner
        }
        $settings.MSTeams = $extractedSettings.Services.MSTeams
        $settings.MSTeamsAllowGuestAccess = $extractedSettings.Services.MSTeamsAllowGuestAccess
        $settings.MSToDo = $extractedSettings.Services.MSToDo
        $settings.MSVivaInsights = $extractedSettings.Services.MSVivaInsights
        $settings.ModernAuth = $extractedSettings.Services.ModernAuth
        $settings.News = $extractedSettings.Services.News
        $settings.OfficeScripts = $extractedSettings.Services.OfficeScripts
        $settings.Reports = $extractedSettings.Services.Reports
        $settings.SearchIntelligenceAnalytics = $extractedSettings.Services.SearchIntelligenceAnalytics
        $settings.SharePoint = $extractedSettings.Services.SharePoint
        $settings.SwayShareWithExternalUsers = $extractedSettings.Services.SwayShareWithExternalUsers
        $settings.UserOwnedAppsandServices = $extractedSettings.Services.UserOwnedAppsandServices
        $settings.VivaLearning = $extractedSettings.Services.VivaLearning
        $settings.Whiteboard = $extractedSettings.Services.Whiteboard
        
        # # SecurityAndPrivacy
        $settings.IdleSessionTimeout = $extractedSettings.SecurityAndPrivacy.IdleSessionTimeout
        $settings.PasswordExpirationPolicyNeverExpire = $extractedSettings.SecurityAndPrivacy.PasswordExpirationPolicyNeverExpire
        $settings.PrivacyProfile = $extractedSettings.SecurityAndPrivacy.PrivacyProfile
        $settings.Pronouns = $extractedSettings.SecurityAndPrivacy.Pronouns
        $settings.SharingAllowUsersToAddGuests = $extractedSettings.SecurityAndPrivacy.SharingAllowUsersToAddGuests
  
        # #OrganizationProfile
        $settings.CustomThemes = $extractedSettings.OrganizationProfile.CustomThemes
        $settings.DataLocation = $extractedSettings.OrganizationProfile.DataLocation
        $settings.HelpDeskInfo = $extractedSettings.OrganizationProfile.HelpDeskInfo
        $settings.ReleasePreferences = $extractedSettings.OrganizationProfile.ReleasePreferences
        $settings.EmailNotFromOwnDomain = $extractedSettings.OrganizationProfile.EmailNotFromOwnDomain
        
        return $settings  
      }
    }
  }
  Process {
    try {
      $validator = [M365TenantValidator]::new($Baseline, $tenantId, $ReturnAsObject)
      $validator.StartValidation()
      $result = $validator.GetValidationResult()
      
      if ($returnAsObject) {
        return $result
      }
    }
    catch {
      throw $_
    }
  }
}