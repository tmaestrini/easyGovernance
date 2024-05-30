using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-5.1
#>
Function Test-M365.1-5.1 {
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
    class M365OD4BValidator : BaselineValidator {
      M365OD4BValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}
  
      Connect() {
        $adminSiteUrl = "https://{0}-admin.sharepoint.com" -f $this.ValidationSettings.TenantId
        Connect-TenantPnPOnline -AdminSiteUrl $adminSiteUrl
      }
      
      [PSCustomObject] Extract() {
        $tenantSettings = Get-PnPTenant
        $tenantSyncClientRestriction = Get-PnPTenantSyncClientRestriction 
        return @{ tenant = $tenantSettings; tenantSyncClientRestriction = $tenantSyncClientRestriction }
      }
      
      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = $extractedSettings.tenant | Select-Object -ExcludeProperty OneDriveStorageQuota
        $settings | Add-Member -NotePropertyName OneDriveStorageQuota -NotePropertyValue ([int]$extractedSettings.tenant.OneDriveStorageQuota / 1024) # MB --> GB
        
        $settings | Add-Member -NotePropertyName TenantRestrictionEnabled -NotePropertyValue $extractedSettings.tenantSyncClientRestriction.TenantRestrictionEnabled
        $settings | Add-Member -NotePropertyName AllowedDomainList -NotePropertyValue $extractedSettings.tenantSyncClientRestriction.AllowedDomainList
        $settings | Add-Member -NotePropertyName ExcludedFileExtensions -NotePropertyValue $extractedSettings.tenantSyncClientRestriction.ExcludedFileExtensions
        
        return $settings
      }
    }
  }

  Process {
    try {
      $validator = [M365OD4BValidator]::new($Baseline, $tenantId, $ReturnAsObject)
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