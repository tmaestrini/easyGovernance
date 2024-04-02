Import-Module ./src/utilities/ValidationFunctions.psm1 -Force
<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.SPO
#>
Function Test-M365.SPO {
  [CmdletBinding()]
  [Alias()]
  [OutputType([hashtable])]
  
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the baseline (see filename for reference)"
    )][string] $baselineId,
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
    }

    function Extract() {      
      return Get-PnPTenant 
    }

    function Transform([PSCustomObject] $extractedSettings) {
      return $extractedSettings
    }

    function Validate([PSCustomObject] $tenantSettings, [PSCustomObject] $baseline) {
      $testResult = Test-Settings $tenantSettings -Baseline $baseline | Sort-Object -Property Group, Setting
      return $testResult
    }    
  }
  Process {
    try {      
      $fileContent = Get-Content "baselines/$($baselineId.Trim()).yml" -Raw
      $baseline = ConvertFrom-Yaml $fileContent -AllDocuments
      
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

      # Return data
      if ($returnAsObject) {
        return @{
          Baseline          = $baselineId; 
          Result            = $result; 
          ResultGroupedText = $resultGrouped;
          Statistics        = $resultStats 
        } 
      }
    }
    catch {
      Disconnect-PnPOnline
      Write-Log ERROR -Message $_
    }
  }
}