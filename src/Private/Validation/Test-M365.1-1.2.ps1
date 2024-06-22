using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-1.2
#>

Function Test-M365.1-1.2 {
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
    class M365LicValidator : BaselineValidator {
      M365LicValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}
  
      Connect() {
        # Unattended mode
        if ($Global:UnattendedScriptParameters) {
          Connect-M365LicenseManager -Credential $Global:UnattendedScriptParameters.Credentials -Tenant $this.ValidationSettings.TenantId
        }
        else {
          Connect-M365LicenseManager -Credential (Get-Credential -Message "Enter your admin credentials for the License Manager") -Tenant $this.ValidationSettings.TenantId
        }
      }

      [PSCustomObject] Extract() {
        $settings = @{}

        # Licenses infos
        $settings.Licenses = Get-M365LicensingConfiguration -Properties SelfServicePurchase, LicenseError, OnlyGroupBasedLicenseAssignment
        
        # Commerce infos
        # $settings.Commerce = Get-SelfServiceLicensing
        
        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}

        # Licenses
        $licensesEnabled = ($extractedSettings.Licenses.SelfServicePurchase | Where-Object { $_.policyValue -eq "Enabled" }).length
        
        $settings.SelfServicePurchase = $licensesEnabled.length -gt 0 ? "Enabled" : "Disabled"

        return $settings
      }
    }
  }

  Process {
    try {
      $validator = [M365LicValidator]::new($Baseline, $tenantId, $ReturnAsObject)
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