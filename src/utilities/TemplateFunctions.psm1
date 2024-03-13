<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Get-TenantTemplate
#>
function Get-TenantTemplate {
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "Full name of the template, including .yml (aka <name>.yml)"
    )][string]$TemplateName
  )
 
  Begin {
    $ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ../../tenants/$TemplateName
  }

  Process {
    if (-not(Test-Path -Path $ConfigPath -PathType Leaf)) {
      Write-Error "No template found for '$Tenant'" -ErrorAction Stop
    }
    $settings = (Get-Content -Path $ConfigPath) -join "`n" | ConvertFrom-Yaml
  }
  
  End {
    return $settings
  }
}

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Get-BaselineTemplate
#>
function Get-BaselineTemplate {
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    [Parameter(
      Mandatory = $true
    )][string]$BaselineId,
    [Parameter(Mandatory = $true)]
    [string]$BaselinesFolder
  )
 
  Begin {
    $ConfigPath = Join-Path -Path $BaselinesFolder -ChildPath "$($BaselineId.Trim()).yml"
    
  }
  Process {
    if (-not(Test-Path -Path $ConfigPath -PathType Leaf)) {
      Write-Error "No template found for '$BaselineId'" -ErrorAction Stop
    }
    $fileContent = Get-Content $ConfigPath -Raw -ErrorAction Stop
    $baseline = ConvertFrom-Yaml $fileContent -AllDocuments
  }
  End {
    return $baseline
  }
}