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
    
  Initialize-EasyGovernance
  if ($KeepConnectionsAlive.IsPresent) { $Script:KeepConnectionsAlive = $true }
  
  try {
    $tenantConfig = Get-TenantTemplate -TemplateName $TemplateName
    Connect-Tenant -Tenant $tenantConfig.Tenant

    Write-Log "*****************************************"
    Write-Log "⭐︎ VALIDATING TENANT: $($tenantConfig.Tenant)"
    Write-Log "*****************************************"
    Write-Log "Baseline Validation Results"

    # Prepare baselines
    $validationResults = @();
    foreach ($selectedBaseline in $tenantConfig.Baselines) {      
      try {
        $baseline = Get-BaselineTemplate -BaselineId $selectedBaseline
        Write-Log "-----------------------------------------"
        Write-Log "◉ Baseline: $($baseline.Id), Version $($baseline.Version)"
        
        # Run baseline validation dynamically (following the name of the function: Test-<Name of Baseline>)
        $arguments = @{baseline = $baseline; tenantId = $tenantConfig.Tenant; ReturnAsObject = $returnAsObject }
        $validationResults += Invoke-Expression "Test-$($baseline.Id) @arguments"

        Write-Log -Message "Baseline validation terminated"
      }
      catch {
        Write-Log -Level ERROR -Message "$($_)"
      }
    }

    Disconnect-Tenant
    Write-Log "*****************************************"
    if (!$ReturnAsObject) { $validationResults }
    if ($ReturnAsObject) { return @{Tenant = $tenantConfig.Tenant; Validation = $validationResults } }
  }
  catch {
    Write-Log -Level ERROR -Message "$($_)"
  }
}