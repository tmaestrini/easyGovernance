# Import-Module ./src/utilities/ProvisioningFunctions.psm1 -Force
<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Set.SPO
#>
Function Set-M365.SPO {
  [CmdletBinding()]
  [Alias()]
  [OutputType([hashtable])]
  
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The baseline to apply"
    )][PSCustomObject]$Baseline,
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the tenant (https://[tenantId].sharepoint.com)"
    )][string] $TenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    $adminSiteUrl = "https://${TenantId}-admin.sharepoint.com"

    function Connect() {
      Connect-PnPOnline -Url $adminSiteUrl -Interactive
      if ($null -eq (Get-PnPConnection)) { throw "✖︎ Connection failed!" }
    }

    function ExtractAndTransform([PSCustomObject] $Baseline) {
      # TODO: extract the settings and group by tool / module
      return $Baseline
    }
  }
  Process {
    try {
      Write-Host "`n-----------------------------------------"
      Write-Host "◉ Baseline: $($Baseline.Id)`n"
      
      # Establish connection to tenant & services
      Connect

      # Validate tenant settings
      $settingsByModule = ExtractAndTransform $Baseline

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
    finally {
      Disconnect-PnPOnline
      $_
    }
  }
}