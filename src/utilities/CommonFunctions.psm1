<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Get-TenantTemplate
#>
Function Initialize-Logging() {
  Set-LoggingDefaultLevel -Level 'INFO'
  Add-LoggingTarget -Name Console
  Add-LoggingTarget -Name File -Configuration @{Path = (Join-Path -Path $PSScriptRoot -ChildPath '../../logs/Provisioning_%{+%Y%m%d}.log') }
}