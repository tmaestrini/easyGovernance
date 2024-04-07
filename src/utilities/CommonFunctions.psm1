<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Initialize-Logging
#>
Function Test-RequiredModules() {
  $requiredModules = @(
    @{name = "powershell-yaml"; version = "" }
    @{name = "PnP.PowerShell"; version = "2.4.0" }
    @{name = "Microsoft.Graph"; version = "2.15.0" }
    @{name = "Logging"; version = "4.8.5" }
  )
  $moduleCheckOk = $true
  foreach ($module in $requiredModules) {
    try {
      $m = Get-Module -ListAvailable -Name $module.name | Sort-Object Version -Descending | Select-Object -First 1
      if ($null -eq $m ) { throw "$($module.name) is not installed: Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" }
      elseif ($module.version -notin @($m.Version.ToString(), "")) { throw "$($module.name) must refer to version $($module.version): Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" }
    }
    catch {
      Write-Host "Module $($_)" -ForegroundColor Yellow
      $moduleCheckOk = $false
    }
  }
  if (!$moduleCheckOk) { throw "Module check failed" }
}

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Initialize-Logging
#>
Function Initialize-Logging() {
  Set-LoggingDefaultLevel -Level 'INFO'
  Add-LoggingTarget -Name Console
  Add-LoggingTarget -Name File -Configuration @{Path = (Join-Path -Path $PSScriptRoot -ChildPath '../../logs/Provisioning_%{+%Y%m%d}.log') }
}