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
        # $s = Get-M365TenantSettings -Properties "tenant/localdatalocation", "services/apps/azurespeechservices"
        $settings = Get-M365TenantSettings -Properties "services/apps/azurespeechservices", "settings/apps/bookings"
        return $settings
      }
      catch {
        throw "Baseline exctraction failed: $_" 
      } 
    }

    function Transform([PSCustomObject] $extractedSettings) {
      $settings = @{}
      
      # Office365Services
      $settings.AzureSpeechServices = $extractedSettings.azurespeechservices.isTenantEnabled
      $settings.Bookings = $extractedSettings.bookings.Enabled
      
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