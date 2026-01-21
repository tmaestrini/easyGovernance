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
  Get-Preamble

  # Set things up
  try {
    Initialize-Logging
  }
  catch {
    Write-Host "✘ Initialization failed." -ForegroundColor Red
    throw "Terminating routine"
  }
}

Function Get-Preamble {
  $line = "─" * 58
  Write-Host "`n`n┌$line┐" -ForegroundColor White
  Write-Host "│  🚀 " -NoNewline -ForegroundColor White
  Write-Host "easyGovernance" -NoNewline -ForegroundColor Green
  Write-Host " · M365 Tenant Validation Tool         │" -ForegroundColor White
  Write-Host "│  👉 " -NoNewline -ForegroundColor White
  Write-Host "https://github.com/tmaestrini/easyGovernance" -NoNewline -ForegroundColor Blue
  Write-Host "         │" -ForegroundColor White
  Write-Host "└$line┘`n`n" -ForegroundColor White
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
    @{name = "PnP.PowerShell"; version = "3.1.0" }
    @{name = "Az.Accounts"; version = "5.3.2" }
    @{name = "Az.Resources"; version = "8.0.1" }
    @{name = "PSLogs"; version = "5.2.1" }
    @{name = "MarkdownPS"; version = "1.9" }
    @{name = "MarkdownToHTML"; version = "2.7.1" }  
    @{name = "EPS"; version = "1.0.0" }  
    @{name = "Pester"; version = "5.7.1" }  
  )
  $moduleCheckOk = $true

  # Check for required PowerShell version
  try {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
      throw "Test-RequiredModules PowerShell version must be 7.4.6 or higher. You are running $($PSVersionTable.PSVersion.ToString()).`nWe recommend you to upgrade to the latest version."
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
      
      $requiredVersion = [version]$module.version
      $currentVersion = [version]$m.Version
      if ($null -eq $m ) { 
        if ($null -eq $requiredVersion -or "" -eq $requiredVersion) {
          throw "[Test-RequiredModules] Module '$($module.name)' is not installed: Install-Module $($module.name) -Scope CurrentUser" 
        }
        throw "[Test-RequiredModules] Module '$($module.name)' is not installed: Install-Module $($module.name) -RequiredVersion $($requiredVersion) -Scope CurrentUser" 
      }
      elseif ($null -ne $requiredVersion -and $currentVersion -lt $requiredVersion) { 
        throw "[Test-RequiredModules] Module '$($module.name)' is version $($currentVersion) but must be at least version $($requiredVersion): Install-Module $($module.name) -RequiredVersion $($module.version) -Scope CurrentUser" 
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
      HelpMessage = "The name of the tenant")][string] $Tenant,
    [Parameter(
      Mandatory = $false
    )][switch]$KeepConnectionsAlive
  )

  Write-Host "Establishing connection to your Azure tenant '$($Tenant).onmicrosoft.com':"
  if (!$Global:UnattendedScriptParameters) {
    Write-Host "👉 Press any key to login as administrator..."
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
  }

  if ($KeepConnectionsAlive.IsPresent) { $Script:KeepConnectionsAlive = $true }
  
  try {
    Connect-TenantAzure -Tenant $Tenant
    
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
.SYNOPSIS
Establishes a connection to an Azure tenant.

.DESCRIPTION
The Connect-TenantAzure function attempts to establish a connection to an Azure tenant using the provided tenant name. 
It supports both interactive and unattended modes. In unattended mode, it uses provided credentials to connect.

.PARAMETER Tenant
The name of the tenant to connect to. This parameter is mandatory.

.EXAMPLE
PS C:\> Connect-TenantAzure -Tenant "exampletenant"
This command establishes a connection to the Azure tenant named "exampletenant.onmicrosoft.com".

.NOTES
If the connection context is not found and unattended script parameters are provided, it uses those credentials to connect.
If the connection context is not found and unattended script parameters are not provided, it prompts for interactive login.
The function logs the connection attempt and success or failure messages.

#>
Function Connect-TenantAzure {
  [CmdletBinding()]
  [OutputType([void])]
  
  Param
  (
    [Parameter(Mandatory = $true, 
      HelpMessage = "The name of the tenant")][string] $Tenant
  )

  Write-Log -Level INFO -Message "Trying to establish connection (Azure)"
  
  try {
    # Clear context only if we are not keeping connections alive
    if (!$Script:KeepConnectionsAlive) {
      Clear-AzContext -Force
    }
    
    $connectAzParams = @{
      Tenant      = "$Tenant.onmicrosoft.com"
      ContextName = $Global:connectionContextName
      AuthScope   = 'AadGraph'
      ErrorAction = 'Stop'
    }
    
    $isRemoteAccess = ($Host.Name -eq 'ServerRemoteHost') -or ($null -ne $PSSenderInfo) -or ($env:REMOTE_CONTAINERS -eq 'true')
    if($isRemoteAccess) {
      $connectAzParams.Add('UseDeviceAuthentication', $true)
      Write-Log -Level INFO -Message "Will authenticate using device authentication." 
    }
    
    if ($Global:UnattendedScriptParameters) { $connectAzParams.Add('Credential', $Global:UnattendedScriptParameters.Credentials) | Out-Null } 

    # Check if context already exists and connect if not
    $ctx = Get-AzContext -Name $Global:connectionContextName
    if ($null -eq $ctx) {
      Write-Log -Level INFO -Message "No existing context found. Establishing new connection."

      Connect-AzAccount @connectAzParams | Out-Null
      $ctx = Get-AzContext -Name $Global:connectionContextName
    }

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
        Connect-PnPOnline -Url $AdminSiteUrl @Global:UnattendedScriptParameters -ClientId $AppId
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