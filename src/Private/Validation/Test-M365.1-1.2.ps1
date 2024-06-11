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
      HelpMessage = "The id of the tenant (https://[tenantId].sharepoint.com)"
    )][string] $tenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    class M365LicValidator : BaselineValidator {
      M365LicValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}
  
      Connect() {
        # Connection is handled system-wide
      }

      [PSCustomObject] Extract() {
        $settings = @{}

        # Licenses infos
        $settings.Licenses = Get-M365LicInfos -Properties Errors, GroupBasedLicensing

        # Commerce infos
        $settings.Commerce = Get-SelfServiceLicensing
        
        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        return @{}
      }
    }
  }
  Process {
    try {
      throw "Validator not implemented yet"
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