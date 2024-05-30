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
        $tenantId = $this.ValidationSettings.TenantId
        $adminSiteUrl = "https://${tenantId}-admin.sharepoint.com"
        Connect-TenantPnPOnline -AdminSiteUrl $adminSiteUrl
      }

      [PSCustomObject] Extract() {
        $tenantSettings = Get-PnPTenant
        $browserIdleSignout = Get-PnPBrowserIdleSignout

        return @{ tenant = $tenantSettings; browserIdleSignout = $browserIdleSignout }
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = $extractedSettings.tenant
        $settings | Add-Member -NotePropertyName BrowserIdleSignout -NotePropertyValue $extractedSettings.browserIdleSignout.Enabled
        $settings | Add-Member -NotePropertyName BrowserIdleSignoutMinutes -NotePropertyValue $extractedSettings.browserIdleSignout.SignOutAfter.TotalMinutes
        $settings | Add-Member -NotePropertyName BrowserIdleSignoutWarningMinutes -NotePropertyValue $extractedSettings.browserIdleSignout.WarnAfter.TotalMinutes
  
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