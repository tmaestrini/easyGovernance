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
        $combinedSettings = @{}
        $tenantSettings.PSObject.Properties | ForEach-Object { $combinedSettings[$_.Name] = $_.Value }
        $tenantInternalSettings.PSObject.Properties | ForEach-Object { $combinedSettings[$_.Name] = $_.Value }
        $tenantSettingsToReturn = [PSCustomObject] $combinedSettings

        # Get browser idle sign-out settings
        $browserIdleSignout = Get-PnPBrowserIdleSignout

        return @{ tenant = $tenantSettingsToReturn; browserIdleSignout = $browserIdleSignout }
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
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

        return $settings
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