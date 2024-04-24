Import-Module ./src/utilities/ValidationFunctions.psm1 -Force
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
    $adminSiteUrl = "https://${tenantId}-admin.sharepoint.com"

    function Connect() {
      Connect-PnPOnline -Url $adminSiteUrl -Interactive
      if ($null -eq (Get-PnPConnection)) { throw "✖︎ Connection failed!" }
      Write-Log -Level INFO "Connection established"
    }

    function Extract() {
      try {
        $tenantSettings = Get-PnPTenant
        $tenantSyncClientRestriction = Get-PnPTenantSyncClientRestriction

        return @{ tenant = $tenantSettings; tenantSyncClientRestriction = $tenantSyncClientRestriction }
      }
      catch {
        throw "Test-M365.OD4B > Exctraction failed: $_" 
      } 
    }

    function Transform([PSCustomObject] $extractedSettings) {
      $settings = $extractedSettings.tenant | Select-Object -ExcludeProperty OneDriveStorageQuota
      $settings | Add-Member -NotePropertyName OneDriveStorageQuota -NotePropertyValue ([int]$extractedSettings.tenant.OneDriveStorageQuota / 1024) # MB --> GB
      
      $settings | Add-Member -NotePropertyName TenantRestrictionEnabled -NotePropertyValue $extractedSettings.tenantSyncClientRestriction.TenantRestrictionEnabled
      $settings | Add-Member -NotePropertyName AllowedDomainList -NotePropertyValue $extractedSettings.tenantSyncClientRestriction.AllowedDomainList
      $settings | Add-Member -NotePropertyName ExcludedFileExtensions -NotePropertyValue $extractedSettings.tenantSyncClientRestriction.ExcludedFileExtensions
      
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
    finally {
      Disconnect-PnPOnline
    }
  }
}