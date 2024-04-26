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
    )][string] $tenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    $adminSiteUrl = "https://${tenantId}-admin.sharepoint.com"
    
    function Connect() {
      try {
        Connect-TenantPnPOnline -AdminSiteUrl $adminSiteUrl
      }
      catch {
        throw $_
      }
    }

    function Extract() {
      try {
        $tenantSettings = Get-PnPTenant
        $browserIdleSignout = Get-PnPBrowserIdleSignout

        return @{ tenant = $tenantSettings; browserIdleSignout = $browserIdleSignout }
      }
      catch {
        throw "Test-M365.1-5.2 > Exctraction failed: $_" 
      } 
    }

    function Transform([PSCustomObject] $extractedSettings) {
      $settings = $extractedSettings.tenant
      $settings | Add-Member -NotePropertyName BrowserIdleSignout -NotePropertyValue $extractedSettings.browserIdleSignout.Enabled
      $settings | Add-Member -NotePropertyName BrowserIdleSignoutMinutes -NotePropertyValue $extractedSettings.browserIdleSignout.SignOutAfter.TotalMinutes
      $settings | Add-Member -NotePropertyName BrowserIdleSignoutWarningMinutes -NotePropertyValue $extractedSettings.browserIdleSignout.WarnAfter.TotalMinutes

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