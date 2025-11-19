using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-5.2
#>
Function Test-M365.1-5.2 {
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
    )][string] $TenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    class M365SPOValidator : BaselineValidator {
      M365SPOValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}
  
      Connect() {
        # Connection is handled system wide
        
        # $tenantId = $this.ValidationSettings.TenantId
        # $adminSiteUrl = "https://${tenantId}-admin.sharepoint.com"
        # Connect-TenantPnPOnline -AdminSiteUrl $adminSiteUrl
      }

      [PSCustomObject] Extract() {
        $tenantSettings = Get-PnPTenant
        $tenantInternalSettings = Get-PnPTenantInternalSetting

        # combine all values from $tenantSettings and $tenantInternalSettings
        [hashtable] $combinedSettings = @{}
        $tenantSettings.PSObject.Properties | ForEach-Object { $combinedSettings[$_.Name] = $_.Value }
        $tenantInternalSettings.PSObject.Properties | ForEach-Object { $combinedSettings[$_.Name] = $_.Value }
        $tenantSettingsToReturn = [PSCustomObject] $combinedSettings

        # Get browser idle sign-out settings
        $browserIdleSignout = Get-PnPBrowserIdleSignout

        return @{ tenant = $tenantSettingsToReturn; browserIdleSignout = $browserIdleSignout }
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        # Transform the extracted settings into the desired format
        $settings = $extractedSettings.tenant
        $settings | Add-Member -NotePropertyName BrowserIdleSignout -NotePropertyValue $extractedSettings.browserIdleSignout.Enabled
        $settings | Add-Member -NotePropertyName BrowserIdleSignoutMinutes -NotePropertyValue $extractedSettings.browserIdleSignout.SignOutAfter.TotalMinutes
        $settings | Add-Member -NotePropertyName BrowserIdleSignoutWarningMinutes -NotePropertyValue $extractedSettings.browserIdleSignout.WarnAfter.TotalMinutes

        $settings | Add-Member -NotePropertyName DenyPagesCreationByUsers -NotePropertyValue (-not [bool]$settings.SitePagesEnabled)
        $settings | Add-Member -NotePropertyName DenySiteCreationByUsers -NotePropertyValue ([bool]$settings.DisableSelfServiceSiteCreation)

        if ([string]::IsNullOrEmpty($settings.DisabledWebPartIds)) {
          # Property has a value
          $settings.DisabledWebPartIds = ""
        }

        # Build setting groups according to baseline structure
        $externalSharingSettings = @{
          SharingCapability                          = $settings.SharingCapability
          DefaultSharingLinkType                     = $settings.DefaultSharingLinkType
          DefaultLinkPermission                      = $settings.DefaultLinkPermission
          RequireAcceptingAccountMatchInvitedAccount = $settings.RequireAcceptingAccountMatchInvitedAccount
          RequireAnonymousLinksExpireInDays          = $settings.RequireAnonymousLinksExpireInDays
          FileAnonymousLinkType                      = $settings.FileAnonymousLinkType
          FolderAnonymousLinkType                    = $settings.FolderAnonymousLinkType
          CoreRequestFilesLinkEnabled                = $settings.CoreRequestFilesLinkEnabled
          ExternalUserExpireInDays                   = $settings.ExternalUserExpireInDays
          EmailAttestationRequired                   = $settings.EmailAttestationRequired
          EmailAttestationReAuthDays                 = $settings.EmailAttestationReAuthDays
          PreventExternalUsersFromResharing          = $settings.PreventExternalUsersFromResharing
          SharingDomainRestrictionMode               = $settings.SharingDomainRestrictionMode
          SharingAllowedDomainList                   = $settings.SharingAllowedDomainList
          ShowEveryoneClaim                          = $settings.ShowEveryoneClaim
          ShowEveryoneExceptExternalUsersClaim       = $settings.ShowEveryoneExceptExternalUsersClaim
          DisplayNamesOfFileViewersInSpo             = $settings.DisplayNamesOfFileViewersInSpo
        }

        $applicationsAndWebpartsSettings = @{
          DisabledWebPartIds = $settings.DisabledWebPartIds
        }

        $accessControlSettings = @{
          ConditionalAccessPolicy          = $settings.ConditionalAccessPolicy
          BrowserIdleSignout               = $settings.BrowserIdleSignout
          BrowserIdleSignoutMinutes        = $settings.BrowserIdleSignoutMinutes
          BrowserIdleSignoutWarningMinutes = $settings.BrowserIdleSignoutWarningMinutes
          LegacyAuthProtocolsEnabled       = $settings.LegacyAuthProtocolsEnabled
        }

        $siteCreationAndStorageLimitsSettings = @{
          NotificationsInSharePointEnabled = $settings.NotificationsInSharePointEnabled
          DenyPagesCreationByUsers         = $settings.DenyPagesCreationByUsers
          DenySiteCreationByUsers          = $settings.DenySiteCreationByUsers
        }

        $filesSettings = @{
          DisallowInfectedFileDownload = $settings.DisallowInfectedFileDownload
        }

        return @{
          ExternalSharing              = $externalSharingSettings
          ApplicationsAndWebparts      = $applicationsAndWebpartsSettings
          AccessControl                = $accessControlSettings
          SiteCreationAndStorageLimits = $siteCreationAndStorageLimitsSettings
          Files                        = $filesSettings
        } 
      }
    }
  }
  Process {
    try {
      $validator = [M365SPOValidator]::new($Baseline, $tenantId, $ReturnAsObject)
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