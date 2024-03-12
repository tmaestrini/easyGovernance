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
  }
  Process {
    try {   
      Connect-PnPOnline -Url $adminSiteUrl -Interactive

      $fileContent = Get-Content "baselines/$($baselineId.Trim()).yml" -Raw
      $baseline = ConvertFrom-Yaml $fileContent -AllDocuments

      if ($null -eq (Get-PnPConnection)) { throw "✖︎ Connection failed!" }
  
      if ($baseline.Topic -eq "SharePoint Online") {
        $tenantSettings = Get-PnPTenant 
        Write-Host "`n-----------------------------------------"
        Write-Host "◉ Baseline: $baselineId`n"
        
        $test = Test-Settings $tenantSettings -Baseline $baseline | Sort-Object -Property Group, Setting
        $testGrouped = ($test | Format-Table -GroupBy Group -Wrap -Property Setting, Result) 
        
        if (!$ReturnAsObject) { $testGrouped | Out-Host }
        $stats = Get-TestStatistics $test

        if ($returnAsObject) {
          return @{
            Baseline          = $baselineId; 
            Result            = $test; 
            ResultGroupedText = $testGrouped;
            Statistics        = $stats 
          } 
        }
      }
    }
    catch {
      Disconnect-PnPOnline
      $_
    }
  }
}