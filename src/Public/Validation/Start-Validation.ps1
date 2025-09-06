Function Start-Validation {
  param(
    [Parameter(
      Mandatory = $true,
      HelpMessage = "Full name of the template, including .yml (aka <name>.yml)"
    )][string]$TemplateName,
    [Parameter(
      Mandatory = $false,
      HelpMessage = "Force reload of baselines (overwrites already loaded baselines in memory by reading from file system)"
    )][Switch]$ReloadBaselines,
    [Parameter(
      Mandatory = $false
    )][switch]$KeepConnectionsAlive,
    [Parameter(
      Mandatory = $false,
      HelpMessage = "Returns the results as an object"
    )][switch]$ReturnAsObject
  )
  
  try {
    Initialize-EasyGovernance
    if ($KeepConnectionsAlive.IsPresent) { $Script:KeepConnectionsAlive = $true }

    Write-Log "New tenant validation routine started"
  
    $tenantConfig = Get-TenantTemplate -TemplateName $TemplateName
    Connect-Tenant -Tenant $tenantConfig.Tenant

    Write-Log "*****************************************"
    Write-Log "🔥 VALIDATING TENANT: $($tenantConfig.Tenant)"
    Write-Log "*****************************************"
    Write-Log "Baseline Validation Results"

    # Prepare baselines
    $validationResults = @();
    foreach ($selectedBaseline in $tenantConfig.Baselines) {      
      try {
        if ($tenantConfig.BaselinesPath) { 
          Write-Log "Trying to load baselines from path: '$($tenantConfig.BaselinesPath)'"
          $baseline = Get-BaselineTemplate -BaselineId $selectedBaseline -BaselinesPath $tenantConfig.BaselinesPath -Force:$ReloadBaselines.IsPresent
        }
        else { 
          $baseline = Get-BaselineTemplate -BaselineId $selectedBaseline -Force:$ReloadBaselines.IsPresent
        }
      
        Write-Log "-----------------------------------------"
        Write-Log "◉ Baseline: $($baseline.Id), Version $($baseline.Version)"
        
        # Run baseline validation dynamically (following the name of the function: Test-<Name of Baseline>)
        $arguments = @{baseline = $baseline; tenantId = $tenantConfig.Tenant; ReturnAsObject = $returnAsObject }
        $validationResults += Invoke-Expression "Test-$($baseline.Id) @arguments"

        Write-Log -Message "Baseline validation terminated"
      }
      catch {
        Write-Log -Level ERROR -Message "Baseline validation failed, see log for details"
        # Write-Log -Level ERROR -Message "$($_)"
      }
    }

    if (!$ReturnAsObject) { $validationResults }
    if ($ReturnAsObject) { return @{Tenant = $tenantConfig.Tenant; Validation = $validationResults } }
  }
  catch {
    Write-Log -Level ERROR -Message "$($_)"
  } 
  finally {
    if (!$Script:KeepConnectionsAlive) { Disconnect-Tenant }
    Write-Log "*****************************************"
  }
}