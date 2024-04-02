Import-Module ./src/utilities/CommonFunctions.psm1 -Force
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
    $tenantConfig = Get-TenantTemplate -TemplateName $Tenantname

    Clear-Host
    Write-Log "========================================="
    Write-Log"🚀 PROVISIONING TENANT: $($tenantConfig.Tenant)"
    Write-Log "========================================="
        
    # Prepare baselines
    $provisioningResult = @();
    foreach ($baselineReference in $tenantConfig.Baselines) {
      try {
        # Run baselines
        $baseline = Get-BaselineTemplate -BaselineId $baselineReference
        Write-Log "-----------------------------------------"
        Write-Log "◉ Baseline: $($Baseline.Id)"
        if ($baseline.Id -eq 'M365.SPO-5.2') { $provisioningResult += Set-M365.SPO -TenantId $tenantConfig.Tenant -Baseline $baseline }
        Write-Log -Message "✔︎ successful"
      }
      catch {
        Write-Log -Level ERROR -Message "✖︎ $($_)"
      }
    }
    if (!$ReturnAsObject) { $provisioningResult }
    if ($ReturnAsObject) { return $provisioningResult }
  }
  catch {
    $_
  }
}