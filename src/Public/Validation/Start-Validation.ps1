Import-Module ./src/utilities/TemplateFunctions.psm1 -Force

Function Start-Validation {
  param(
    [Parameter(
      Mandatory = $true,
      HelpMessage = "Full name of the template, including .yml (aka <name>.yml)"
    )][string]$TemplateName,
    [Parameter(
      Mandatory = $false
    )][switch]$KeepConnectionsAlive,
    [Parameter(
      Mandatory = $false,
      HelpMessage = "Returns the results as an object"
    )][switch]$ReturnAsObject
  )
    
  try {
    # Set things up
    $tenantConfig = Get-TenantTemplate -TemplateName $TemplateName

    Clear-Host
    Write-Host "========================================="
    Write-Host "⭐︎ VALIDATING TENANT: $($tenantConfig.Tenant)"
    Write-Host "========================================="
    Write-Host "`nBaseline Validation Results"
        
    # Run baselines
    $returnedBaselines = @();
    $baselines = $tenantConfig.Baselines
    foreach ($baseline in $baselines) {
      if ($baseline -eq 'M365.SPO-5.2') { $returnedBaselines += Test-M365.SPO -baselineId $baseline -tenantId $tenantConfig.Tenant -ReturnAsObject:$returnAsObject }
    }
    if (!$ReturnAsObject) { $returnedBaselines }
    if ($ReturnAsObject) { return $returnedBaselines }
  }
  catch {
    $_
  }
}