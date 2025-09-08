using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-6.1
#>

Function Test-M365.1-6.1 {
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
      HelpMessage = "The id of the tenant (https://[tenantId].onmicrosoft.com)"
    )][string] $tenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    class TeamsSettingsValidator : BaselineValidator {
      TeamsSettingsValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}

      Connect() {
        Connect-TeamsAdminCenter
      }

      [PSCustomObject] Extract() {
        $settings = @{}

        $settings.Settings = Get-TeamsSettings -Properties FeedSuggestionsInUsersActivityFeed, WhoCanManageTags, LetTeamOwnersChangeWhoCanManageTags, CustomTags, ShiftsAppCanApplyTags, AllowEmailIntoChannel
        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}

        # FeedSuggestionsInUsersActivityFeed
        $settings.FeedSuggestionsInUsersActivityFeed = ($extractedSettings.Settings.FeedSuggestionsInUsersActivityFeed -eq "EnabledUserOverride")

        # TeamsTargetingPolicy contain string values that need to be transformed to boolean or other string values
        $settings.WhoCanManageTags = ($extractedSettings.Settings.TeamsTargetingPolicy.ManageTagsPermissionMode -eq "EnabledTeamOwner") ? "TeamOwners" : $extractedSettings.Settings.WhoCanManageTags
        $settings.LetTeamOwnersChangeWhoCanManageTags = ($extractedSettings.Settings.TeamsTargetingPolicy.TeamOwnersEditWhoCanManageTagsMode -eq "TeamOwnersEditWhoCanManageTagsMode")
        $settings.CustomTags = ($extractedSettings.Settings.TeamsTargetingPolicy.CustomTagsMode -eq "Enabled")
        $settings.ShiftsAppCanApplyTags = ($extractedSettings.Settings.TeamsTargetingPolicy.ShiftBackedTagsMode -eq "ShiftBackedTagsMode")

        # TeamsClientConfiguration contain boolean values
        $settings.AllowUsersCanSendEmailsToAChannel = $extractedSettings.Settings.TeamsClientConfiguration.AllowEmailIntoChannel ?? 'n/a'
        $settings.AllowCitrix = $extractedSettings.Settings.TeamsClientConfiguration.AllowShareFile ?? 'n/a'
        $settings.AllowDropBox = $extractedSettings.Settings.TeamsClientConfiguration.AllowDropBox ?? 'n/a'
        $settings.AllowBox = $extractedSettings.Settings.TeamsClientConfiguration.AllowBox ?? 'n/a'
        $settings.AllowGoogleDrive = $extractedSettings.Settings.TeamsClientConfiguration.AllowGoogleDrive ?? 'n/a'
        $settings.AllowEgnyte = $extractedSettings.Settings.TeamsClientConfiguration.AllowEgnyte ?? 'n/a'
        $settings.AllowOrganizationTabForUsers = $extractedSettings.Settings.TeamsClientConfiguration.AllowOrganizationTab ?? 'n/a'
        $settings.Require2ndAuthforMeeting = $extractedSettings.Settings.TeamsClientConfiguration.ResourceAccountContentAccess ?? 'n/a'
        $settings.SetContentPin = $extractedSettings.Settings.TeamsClientConfiguration.ContentPin ?? 'n/a'
        $settings.SurfaceHubCanSendMails = $extractedSettings.Settings.TeamsClientConfiguration.SurfaceHubCanSendMails ?? 'n/a'
        $settings.ScopeDirectorySearch = $extractedSettings.Settings.TeamsClientConfiguration.AllowScopedPeopleSearchandAccess ?? 'n/a'
        $settings.ExtendedWorkInfoInPeopleSearch = $extractedSettings.Settings.TeamsClientConfiguration.ExtendedWorkInfoInPeopleSearch ?? 'n/a'
        $settings.RoleBasedChatPermissions = $extractedSettings.Settings.TeamsClientConfiguration.AllowRoleBasedChatPermissions ?? 'n/a'
        $settings.ProvideLinkToSupportRequestPage = $extractedSettings.Settings.TeamsClientConfiguration.ProvideLinkToSupportRequestPage ?? 'n/a'
        
        return $settings
      }
    }
  }

  Process {
    try {
      $validator = [TeamsSettingsValidator]::new($Baseline, $tenantId, $ReturnAsObject)
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