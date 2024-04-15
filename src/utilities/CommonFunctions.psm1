<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Initialize-Logging
#>
Function Initialize-EasyGovernance() {
  
  Function Test-RequiredModules() {
    $requiredModules = @(
      @{name = "powershell-yaml"; version = "" }
      @{name = "PnP.PowerShell"; version = "2.4.0" }
      @{name = "Microsoft.Graph"; version = "2.15.0" }
      @{name = "Logging"; version = "4.8.5" }
      @{name = "MarkdownPS"; version = "1.9" }
      @{name = "MarkdownToHTML"; version = "2.7.1" }  
    )
    $moduleCheckOk = $true
    foreach ($module in $requiredModules) {
      try {
        $m = Get-Module -ListAvailable -Name $module.name | Sort-Object Version -Descending | Select-Object -First 1
        if ($null -eq $m ) { throw "Module '$($module.name)' is not installed: Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" }
        elseif ($module.version -notin @($m.Version.ToString(), "")) { throw "Module '$($module.name)' must refer to version $($module.version): Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" }
      }
      catch {
        Write-Host "$($_)" -ForegroundColor Yellow
        $moduleCheckOk = $false
      }
    }
    if (!$moduleCheckOk) { 
      throw "✘ Module check failed. Please install dependencies and try again." 
    }
  }
    
  Function Initialize-Logging() {
    Set-LoggingDefaultLevel -Level 'INFO'
    Add-LoggingTarget -Name Console
    Add-LoggingTarget -Name File -Configuration @{Path = (Join-Path -Path $PSScriptRoot -ChildPath '../../logs/easyGovernance_%{+%Y%m%d}.log') }
  }

  Clear-Host
  Write-Host "easyGovernance · Tenant Validation Tool" -ForegroundColor Green
  Write-Host "👉 https://github.com/tmaestrini/easyGovernance`n" -ForegroundColor Green

  # Set things up
  try {
    Test-RequiredModules
    Initialize-Logging    
  }
  catch {
    Write-Host "✘ Module check failed. Please install dependencies and try again." -ForegroundColor Red
    throw "Terminating during initalization"
  }
}