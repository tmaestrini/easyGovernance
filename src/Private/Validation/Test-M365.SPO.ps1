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
  [OutputType([int])]
  
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the baseline (see filename for reference)"
    )][string] $baselineId,
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the tenant (https://[tenantId].sharepoint.com)"
    )][string] $tenantId
  )
 
  Begin {
    $adminSiteUrl = "https://${tenantId}-admin.sharepoint.com"
  }

  Process {
    try {   
      Connect-PnPOnline -Url $adminSiteUrl -Interactive

      $fileContent = Get-Content "baselines/$($baselineId.Trim()).yml" -Raw
      $baseline = ConvertFrom-Yaml $fileContent -AllDocuments
      $adminSiteUrl
      if ($null -eq (Get-PnPConnection)) { throw "✖︎ Connection failed!" }
  
      if ($baseline.Topic -eq "SharePoint Online") {
        $tenantSettings = Get-PnPTenant 
        Clear-Host
        Write-Host "`n------------------------------`n⭐︎ Baseline Validation Results`n------------------------------"
        Write-Host "Baseline: $baselineId`n"

        Test-Settings $tenantSettings -Baseline $baseline | Sort-Object -Property Group, Key `
      | Format-Table -GroupBy Group -Wrap -Property Setting, Result
            
      }
    }
    catch {
      Disconnect-PnPOnline
      $_
    }
  }
  
  End {}
}