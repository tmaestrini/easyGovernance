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
        Connect-M365AdminCenter
      }

      [PSCustomObject] Extract() {
        $settings = @{}

        $settings.Licensing = Get-M365TenantLicensing -Properties AssignmentErrors, LicensedProducts, SelfServicePurchase, DirectLicenseAssignments
        return $settings
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}

        # Licensing errors
        $settings.LicenseErrors = ($extractedSettings.Licensing.AssignmentErrors.Length -ne 0)
        
        # Licensing enabled
        $selfServicePurchaseAllowed = $extractedSettings.Licensing.SelfServicePurchase | Where-Object { $_.policyId -eq "AllowSelfServicePurchase" }
        $settings.SelfServicePurchase = $selfServicePurchaseAllowed.Length -gt 0 ? "Enabled" : "Disabled"
        if ($settings.SelfServicePurchase -eq "Enabled") {
          $settings.SelfServicePurchaseEnabledLicenses = $selfServicePurchaseAllowed
        }

        # Group based licensing
        # Check if there are any users with direct license assignments (assignedByGroup = null)
        $directAssignments = @()
        $totalUsersWithLicenses = 0
        
        if ($extractedSettings.Licensing.DirectLicenseAssignments) {
          foreach ($user in $extractedSettings.Licensing.DirectLicenseAssignments) {
            if ($user.licenseAssignmentStates -and $user.licenseAssignmentStates.Count -gt 0) {
              $totalUsersWithLicenses++
              
              # Check if any license assignment has assignedByGroup = null (direct assignment)
              $directLicenses = $user.licenseAssignmentStates | Where-Object { 
                $null -eq $_.assignedByGroup -or $_.assignedByGroup -eq "" 
              }
              
              if ($directLicenses -and $directLicenses.Count -gt 0) {
                $directAssignments += [PSCustomObject]@{
                  UserDisplayName = $user.displayName
                  DirectLicenses = $directLicenses
                }
              }
            }
          }
        }
        
        $onlyGroupBasedLicensing = ($directAssignments.Count -eq 0) -and ($totalUsersWithLicenses -gt 0)
        $settings.OnlyGroupBasedLicenseAssignment = $onlyGroupBasedLicensing 
        $settings.TotalUsersWithLicenses = $totalUsersWithLicenses
        $settings.UsersWithDirectAssignments = $directAssignments.Count
        
        # Store details for additional information
        if ($directAssignments.Count -gt 0) {
          $settings.DirectAssignmentDetails = $directAssignments
        }

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