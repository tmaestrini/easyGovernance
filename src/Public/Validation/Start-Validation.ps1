Import-Module ./src/utilities/CommonFunctions.psm1 -Force
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
    Initialize-Logging
    $tenantConfig = Get-TenantTemplate -TemplateName $TemplateName

    Clear-Host
    Write-Log "`========================================="
    Write-Log "⭐︎ VALIDATING TENANT: $($tenantConfig.Tenant)"
    Write-Log "========================================="
    Write-Log "Baseline Validation Results"
        
    # Run baselines
    $returnedBaselines = @();
    foreach ($selectedBaseline in $tenantConfig.Baselines) {      
      try {
        $baseline = Get-BaselineTemplate -BaselineId $selectedBaseline
        Write-Log "-----------------------------------------"
        Write-Log "◉ Baseline: $($baseline.Id)"
        
        if ($baseline.Id -eq 'M365.SPO-5.2') { $returnedBaselines += Test-M365.SPO -baseline $baseline -tenantId $tenantConfig.Tenant -ReturnAsObject:$returnAsObject }
        Write-Log -Message "Baseline validation terminated"
      }
      catch {
        Write-Log -Level ERROR -Message "$($_)"
      }
    }
    Write-Log "========================================="
    if (!$ReturnAsObject) { $returnedBaselines }
    if ($ReturnAsObject) { return $returnedBaselines }
  }
  catch {
    $_
  }
}