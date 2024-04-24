$connectionContextName = "easyGovernance"

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Initialize-EasyGovernance
#>
Function Initialize-EasyGovernance() {    
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
    Initialize-Logging
  }
  catch {
    Write-Host "✘ Initialization failed." -ForegroundColor Red
    throw "Terminating routine"
  }
}

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-RequiredModules
#>
Function Test-RequiredModules() {
  $requiredModules = @(
    @{name = "powershell-yaml" }
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
      if ($null -eq $m ) { 
        if ($null -eq $module.version -or "" -eq $module.version) {
          throw "Module '$($module.name)' is not installed: Install-Module $($module.name) -Scope CurrentUser" 
        }
        throw "Module '$($module.name)' is not installed: Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" 
      }
      elseif ($null -ne $module.version -and $module.version -notin @($m.Version.ToString(), "")) { 
        throw "Module '$($module.name)' must refer to version $($module.version): Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" 
      }
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

Function Connect-Tenant {
  [CmdletBinding()]
  [OutputType([void])]

  Param
  (
    [Parameter(Mandatory = $true, 
      HelpMessage = "The name of the tenant")][string] $Tenant
  )

  Write-Host "Establishing connection to your Azure tenant '$Tenant.onmicrosoft.com':"
  Write-Host "👉 Press any key to login as administrator..."
  $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
  
  try {
    Write-Log -Level INFO -Message "Trying to establish connection to tenant '$Tenant.onmicrosoft.com'"
    $ctx = Get-AzContext -Name $connectionContextName
    if ($null -eq $ctx) {
      Connect-AzAccount -Tenant "$Tenant.onmicrosoft.com" -ContextName $connectionContextName -AuthScope AadGraph -ErrorAction Stop | Out-Null
    }
    Write-Log -Level INFO -Message "Connection ok"
  }
  catch {
    Write-Log -Level ERROR -Message "failed: $_"
  }
}

Function Disconnect-Tenant {
  Write-Log -Message "Disconnecting from tenant"

  if($null -ne (Get-AzContext -Name $connectionContextName)) {
    Disconnect-AzAccount -ContextName $connectionContextName | Out-Null
  }
  if($null -ne (Get-PnPConnection)) {
    Disconnect-PnPOnline | Out-Null
  }
}

<#
.Synopsis
  Connects to the tenant's admin site via PnPOnline and sets up the connection script variable ($Script:connection), if not already set.
#>
Function Connect-TenantPnPOnline([string] $AdminSiteUrl) {
  Write-Log -Level INFO -Message "Trying to establish connection (PnPOnline)"
  try {
    Get-PnPConnection | Out-Null    
    Write-Log -Level INFO "Connection established"
  }
  catch {
    Connect-PnPOnline -Url $AdminSiteUrl -Interactive
    if ($null -eq (Get-PnPConnection)) { throw "✖︎ Connection failed!" }
    Write-Log -Level INFO "Connection established"
  }
}