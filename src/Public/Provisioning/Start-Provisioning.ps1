Import-Module ./src/utilities/TemplateFunctions.psm1 -Force

Function Start-Provisioning {
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
    Write-Host "🚀 PROVISIONING TENANT: $($tenantConfig.Tenant)"
    Write-Host "========================================="
        
    # Prepare baselines
    $provisioningResult = @();
    foreach ($baselineReference in $tenantConfig.Baselines) {
      try {
        # Run baselines
        $baseline = Get-BaselineTemplate -BaselineId $baselineReference 
        if ($baseline.Id -eq 'M365.SPO-5.2') { $provisioningResult += Set-M365.SPO -TenantId $tenantConfig.Tenant -Baseline $baseline }
      }
      catch {
        Write-Host "✖︎ $($_)" -ForegroundColor DarkYellow
      }
    }
    if (!$ReturnAsObject) { $provisioningResult }
    if ($ReturnAsObject) { return $provisioningResult }
  }
  catch {
    $_
  }
}