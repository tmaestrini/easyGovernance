$Global:connectionContextName = "easyGovernance"

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Initialize-EasyGovernance
#>
Function Initialize-EasyGovernance {    
  Function Initialize-Logging() {
    Set-LoggingDefaultLevel -Level 'INFO'
    Set-LoggingDefaultFormat -Format '%{timestamp:+yyyy-MM-dd HH:mm:ss:12} %{level:-7} %{message} %{body}'

    Add-LoggingTarget -Name Console -Configuration @{ Level = 'DEBUG'; Format = '%{timestamp:+yyyy-MM-dd HH:mm:ss:12} %{level:-7} [%{caller}] %{message} %{body}' }
    Add-LoggingTarget -Name File -Configuration @{Path = (Join-Path -Path $PSScriptRoot -ChildPath '../../logs/easyGovernance_%{+%Y%m%d}.log'); }  
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
Function Test-RequiredModules {
  $requiredModules = @(
    @{name = "powershell-yaml" }
    @{name = "PnP.PowerShell"; version = "2.12.0" }
    @{name = "Microsoft.Graph"; version = "2.15.0" }
    @{name = "Az.Accounts"; version = "2.19.0" }
    @{name = "Az.Resources"; version = "6.4.0" }
    @{name = "PSLogs"; version = "5.2.1" }
    @{name = "MarkdownPS"; version = "1.9" }
    @{name = "MarkdownToHTML"; version = "2.7.1" }  
  )
  $moduleCheckOk = $true

  # Check for required PowerShell version
  try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
      throw "Test-RequiredModules PowerShell version must be 7.0 or higher. You are running $($PSVersionTable.PSVersion.ToString()).`nWe recommend you to upgrade to the latest version."
    }
  }
  catch {
    $moduleCheckOk = $false
    Write-Host "$($_)" -ForegroundColor Red
    throw $_
  }
  
  # Check for required modules
  foreach ($module in $requiredModules) {
    try {
      $m = Get-Module -ListAvailable -Name $module.name | Sort-Object Version -Descending | Select-Object -First 1
      if ($null -eq $m ) { 
        if ($null -eq $module.version -or "" -eq $module.version) {
          throw "Test-RequiredModules Module '$($module.name)' is not installed: Install-Module $($module.name) -Scope CurrentUser" 
        }
        throw "Test-RequiredModules Module '$($module.name)' is not installed: Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" 
      }
      elseif ($null -ne $module.version -and $module.version -notin @($m.Version.ToString(), "")) { 
        throw "Test-RequiredModules Module '$($module.name)' must refer to version $($module.version): Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" 
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
  if (!$Global:UnattendedScriptParameters) {
    Write-Host "👉 Press any key to login as administrator..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
  }
  
  try {
    Connect-TenantAzure
    
    $appId = Get-OrCreateEasyGovernanceAppRegistration -Tenant $Tenant
    Connect-TenantPnPOnline -AdminSiteUrl "https://$Tenant-admin.sharepoint.com" -AppId $appId
  }
  catch {
    Write-Log -Level ERROR -Message "failed: $_"
    throw "Terminating routine due to erronous connection attempt."
  }
}

Function Disconnect-Tenant {
  Write-Log -Message "Disconnecting from tenant"

  try {
    if ($null -ne (Get-AzContext -Name $Global:connectionContextName)) {
      Disconnect-AzAccount -ContextName $Global:connectionContextName | Out-Null
    }
    if ($Script:PnPConnection) {
      try { if ($null -ne (Get-PnPConnection)) { Disconnect-PnPOnline | Out-Null } }
      finally {
        $Script:PnPConnection = $null
      }
    }
  }
  catch {
    throw "Disconnect-Tenant > $_"
  }
  finally {
    if ($Global:UnattendedScriptParameters) { Reset-UnattendedRun }
  }
}

<#
.Synopsis
  Connects to the Azure tenant and sets up the connection.
#>
Function Connect-TenantAzure {
  Write-Log -Level INFO -Message "Trying to establish connection (Azure)"
  try {
    $ctx = Get-AzContext -Name $Global:connectionContextName

    if ($null -eq $ctx -and $Global:UnattendedScriptParameters) {
      Write-Log -Level INFO -Message "Unattended mode: Using provided credentials"
      Connect-AzAccount -Credential $Global:UnattendedScriptParameters.Credentials -Tenant "$Tenant.onmicrosoft.com" `
        -ContextName $Global:connectionContextName -AuthScope AadGraph -ErrorAction Stop | Out-Null
    }
    elseif ($null -eq $ctx -and !$Global:UnattendedScriptParameters) {
      Connect-AzAccount -Tenant "$($Tenant).onmicrosoft.com" -ContextName $Global:connectionContextName -AuthScope AadGraph -ErrorAction Stop | Out-Null
    }

    $ctx = Get-AzContext -Name $Global:connectionContextName
    $Global:AzureContext = $ctx
    Write-Log -Level INFO -Message "Connection established"
  }
  catch {
    throw "Connect-TenantAzure > $_"
  }
}

<#
.Synopsis
  Connects to the tenant's admin site via PnPOnline and sets up the connection.
#>
Function Connect-TenantPnPOnline {
  [CmdletBinding()]
  [OutputType([void])]

  Param
  (
    [Parameter(Mandatory = $true)][string] $AdminSiteUrl,
    [Parameter(Mandatory = $true)][string] $AppId
  )

  Write-Log -Level INFO -Message "Trying to establish connection (PnPOnline)"
  try {
    $Script:PnPConnection = Get-PnPConnection
    Write-Log -Level INFO "Connection established"
  }
  catch {
    if ($Global:UnattendedScriptParameters) {
      Write-Log -Level INFO -Message "Unattended mode: Using provided credentials"
      try {
        Connect-PnPOnline -Url "https://tmaestrini-admin.sharepoint.com" @Global:UnattendedScriptParameters -ClientId $AppId
      }
      catch {
        Write-Log -Level ERROR $_
        throw $_      
      }
    }
    else {
      Connect-PnPOnline -Url $AdminSiteUrl -Interactive -ClientId $AppId
    }

    if ($null -eq (Get-PnPConnection)) { throw "✖︎ Connection failed: $_" }    
    $Script:PnPConnection = Get-PnPConnection 
    Write-Log -Level INFO "Connection established"
  }
}

<#
.Synopsis 
  Testing if the EasyGovernance app that makes use of PnP.PowerShell is already installed in $Tenant.onmicrosoft.com.
  If it is not installed, it will be created with standard permissions.
  👉 Make sure that you have established an Azure connection before calling this function.
  .OUTPUTS
  This function will return the appropriate AppId that will be used for login purposes.
#>
Function Get-OrCreateEasyGovernanceAppRegistration {
  [CmdletBinding()]
  [OutputType([void])]

  Param
  (
    [Parameter(Mandatory = $true, 
      HelpMessage = "The name of the tenant")][string] $Tenant
  )

  $ctx = Get-AzContext -Name $Global:connectionContextName
  $testAppIsInstalled = Get-AzADApplication -DisplayNameStartWith "easyGovernance"
  
  if (!$testAppIsInstalled) {
    Write-Log -Message "Registering EasyGovernance application in Entra ID that will work with PnP.PowerShell"
    $newApp = Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "easyGovernance" -Tenant "$Tenant.onmicrosoft.com" -Interactive

    Write-Host "Please consent the app in the browser before you proceed to login."
    Write-Host "Proceeding without consent will cause authentication failure."
    Write-Host "👉 Press any key to continue after you have given consent to the 'easyGovernance' app..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
  
    $testAppIsInstalled = Get-AzADApplication -DisplayNameStartWith "easyGovernance"
  } 
  
  return $testAppIsInstalled.AppId
}