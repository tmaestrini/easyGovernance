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
    $adminSiteUrl = "https://${tenantId}-admin.sharepoint.com"

    function Connect() {
    }

    function Extract() {
      try {
        $settings = @{}

        # Office365Services
        # $settings.Services = Get-M365TenantSettingsServices -Properties AzureSpeechServices, Bookings, CalendarSharing, Cortana, Copilot4Sales, M365AppsInstallationOpt, `
        #   M365Lighthouse, MSGraphDataConnect, MSLoop, MSPlanner, M365Groups, M365OTW, ModernAuth, MSForms, MSTeams, MSTeamsAllowGuestAccess, MSToDo, MSUserCommunication, `
        #   MSSearchBing, MSVivaBriefing, MSVivaInsights, OfficeScripts, Reports, SearchIntelligenceAnalytics, SharePoint, Sway, SwayShareWithExternalUsers, `
        #   UserOwnedAppsandServices, VivaLearning, Whiteboard
        
        # SecurityAndPrivacy
        $settings.SecurityAndPrivacy = Get-M365TenantSettingsSecurityAndPrivacy -Properties IdleSessionTimeout, PasswordExpirationPolicyNeverExpire, PrivacyProfile, Pronouns, SharingAllowUsersToAddGuests
        
        #OrganizationProfile
        
        return $settings
      }
      catch {
        Write-Log -Level CRITICAL "Baseline exctraction failed: $_" 
      } 
    }

    function Transform([PSCustomObject] $extractedSettings) {
      $settings = @{}
      
      # Office365Services
      $settings.AccountLinking = "n/a"
      $settings.AdoptionScore = "n/a"
      $settings.AzureSpeechServices = $extractedSettings.AzureSpeechServices
      $settings.Bookings = $extractedSettings.Bookings
      $settings.CalendarSharing = $extractedSettings.CalendarSharing
      $settings.Copilot4Sales = $extractedSettings.Copilot4Sales
      $settings.Cortana = $extractedSettings.Cortana
      $settings.M365Groups = "needs to be specified"
      $settings.M365AppsInstallationOpt = $extractedSettings.M365AppsInstallationOpt
      $settings.M365Lighthouse = $extractedSettings.M365Lighthouse
      $settings.M365OTW = $extractedSettings.M365OTW
      $settings.MSUserCommunication = $extractedSettings.MSUserCommunication
      $settings.MSForms = "needs to be specified"
      $settings.MSGraphDataConnect = $extractedSettings.MSGraphDataConnect
      $settings.MSLoop = $extractedSettings.MSLoop
      $settings.MSPlanner = $extractedSettings.MSPlanner
      $settings.MSSearchBing = ""
      $settings.MSTeams = $extractedSettings.MSTeams
      $settings.MSTeamsAllowGuestAccess = $extractedSettings.MSTeamsAllowGuestAccess
      $settings.MSToDo = $extractedSettings.MSToDo
      $settings.MSVivaInsights = $extractedSettings.MSVivaInsights
      $settings.ModernAuth = $extractedSettings.ModernAuth
      $settings.News = $extractedSettings.News
      $settings.OfficeScripts = $extractedSettings.OfficeScripts
      $settings.Reports = $extractedSettings.Reports
      $settings.SearchIntelligenceAnalytics = $extractedSettings.SearchIntelligenceAnalytics
      $settings.SharePoint = $extractedSettings.SharePoint
      $settings.SwayShareWithExternalUsers = $extractedSettings.SwayShareWithExternalUsers
      $settings.UserOwnedAppsandServices = $extractedSettings.UserOwnedAppsandServices
      $settings.VivaLearning = $extractedSettings.VivaLearning
      $settings.Whiteboard = $extractedSettings.Whiteboard
      
      return $settings
    }

    function Validate([PSCustomObject] $tenantSettings, [PSCustomObject] $baseline) {
      $testResult = Test-Settings $tenantSettings -Baseline $baseline | Sort-Object -Property Group, Setting
      return $testResult
    }
  }
  Process {
    try {
      # Establish connection to tenant & services
      Connect

      # Validate tenant settings
      $settingsToValidate = Extract
      $tenantSettings = Transform $settingsToValidate
      $result = Validate $tenantSettings -baseline $baseline

      # Output
      $resultGrouped = ($result | Format-Table -GroupBy Group -Wrap -Property Setting, Result) 
      if (!$ReturnAsObject) { $resultGrouped | Out-Host }
      $resultStats = Get-TestStatistics $result
      $resultStats.asText | Out-Host

      # Return data
      if ($returnAsObject) {
        return @{
          Baseline          = $baseline.Id;
          Version           = $baseline.Version;
          Result            = $result; 
          ResultGroupedText = $resultGrouped;
          Statistics        = $resultStats.stats;
          StatisticsAsText  = $resultStats.asText;
        } 
      }
    }
    catch {
      throw $_
    }
  }
}