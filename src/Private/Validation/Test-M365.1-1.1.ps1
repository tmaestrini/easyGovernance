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
        Connect-M365AdminCenter
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
        $adoptionScoreSettings = $extractedSettings.Services.AdoptionScore | ConvertFrom-Json
        $settings.Office365Services = @{
          AccountLinking              = "n/a"
          AdoptionScore               = @{
            ActionFlowOptedIn    = $adoptionScoreSettings[0].ActionFlowOptedInValue;
            CohortInsightOptedIn = $adoptionScoreSettings[0].CohortInsightOptedInValue;
            PSGroupsOptedOut     = $adoptionScoreSettings[0].PSGroupsOptedOutValue;
          }
          AzureSpeechServices         = $extractedSettings.Services.AzureSpeechServices
          Bookings                    = $extractedSettings.Services.Bookings
          CalendarSharing             = $extractedSettings.Services.CalendarSharing
          Copilot4Sales               = $extractedSettings.Services.Copilot4Sales
          Cortana                     = $extractedSettings.Services.Cortana
          M365Groups                  = "needs to be specified"
          M365AppsInstallationOpt     = $extractedSettings.Services.M365AppsInstallationOpt
          M365Lighthouse              = $extractedSettings.Services.M365Lighthouse
          M365OTW                     = $extractedSettings.Services.M365OTW
          MSUserCommunication         = $extractedSettings.Services.MSUserCommunication
          MSForms                     = "needs to be specified"
          MSGraphDataConnect          = $extractedSettings.Services.MSGraphDataConnect
          MSLoop                      = $extractedSettings.Services.MSLoop
          MSPlanner                   = @{
            allowCalendarSharing = $extractedSettings.Services.MSPlanner
          }
          MSTeams                     = $extractedSettings.Services.MSTeams
          MSTeamsAllowGuestAccess     = $extractedSettings.Services.MSTeamsAllowGuestAccess
          MSToDo                      = $extractedSettings.Services.MSToDo
          MSVivaInsights              = $extractedSettings.Services.MSVivaInsights
          ModernAuth                  = $extractedSettings.Services.ModernAuth
          News                        = $extractedSettings.Services.News
          OfficeScripts               = $extractedSettings.Services.OfficeScripts
          Reports                     = $extractedSettings.Services.Reports
          SearchIntelligenceAnalytics = $extractedSettings.Services.SearchIntelligenceAnalytics
          SharePoint                  = $extractedSettings.Services.SharePoint
          SwayShareWithExternalUsers  = $extractedSettings.Services.SwayShareWithExternalUsers
          UserOwnedAppsandServices    = $extractedSettings.Services.UserOwnedAppsandServices
          VivaLearning                = $extractedSettings.Services.VivaLearning
          Whiteboard                  = $extractedSettings.Services.Whiteboard
        }
        
        # SecurityAndPrivacy
        $settings.SecurityAndPrivacy = @{
          IdleSessionTimeout                  = $extractedSettings.SecurityAndPrivacy.IdleSessionTimeout
          PasswordExpirationPolicyNeverExpire = $extractedSettings.SecurityAndPrivacy.PasswordExpirationPolicyNeverExpire
          PrivacyProfile                      = $extractedSettings.SecurityAndPrivacy.PrivacyProfile
          Pronouns                            = $extractedSettings.SecurityAndPrivacy.Pronouns
          SharingAllowUsersToAddGuests        = $extractedSettings.SecurityAndPrivacy.SharingAllowUsersToAddGuests
        }
          
        # OrganizationProfile
        $settings.OrganizationProfile = @{
          CustomThemes = $extractedSettings.OrganizationProfile.CustomThemes
          DataLocation = $extractedSettings.OrganizationProfile.DataLocation
          HelpDeskInfo = $extractedSettings.OrganizationProfile.HelpDeskInfo
          ReleasePreferences = $extractedSettings.OrganizationProfile.ReleasePreferences
          EmailNotFromOwnDomain = $extractedSettings.OrganizationProfile.EmailNotFromOwnDomain
        }
        
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