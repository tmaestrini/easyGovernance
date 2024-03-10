Import-Module ./src/utilities/TemplateFunctions.psm1 -Force

Function Start-Validation {
  param(
    [Parameter(
      Mandatory = $true,
      HelpMessage = "Full name of the template, including .yml (aka <name>.yml)"
    )][string]$TemplateName,
    [Parameter(
      Mandatory = $false
    )][switch]$KeepConnectionsAlive
  )
    
  try {
    # Set things up
    $tenantConfig = Get-TenantTemplate -TemplateName $TemplateName
    Clear-Host
    Write-Host "`n----------------------------------------`n⭐︎ VALIDATING TENANT: $($tenantConfig.Tenant) `n-----------------------------------------"
    
    $baselines = $tenantConfig.Baselines
    foreach ($baseline in $baselines) {
      if ($baseline -eq 'M365.SPO-5.2') { Test-M365.SPO -baselineId $baseline -tenantId $tenantConfig.Tenant }
    }
  }
  catch {
    $_
  }
}