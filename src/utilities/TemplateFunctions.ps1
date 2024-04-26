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
    )][string]$BaselineId
  )
 
  Begin {
    if ($null -eq $Script:baselines) {
      $ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ..\..\baselines
      $BaselinesFiles = @( Get-ChildItem -Path $ConfigPath\*.yml -ErrorAction SilentlyContinue )

      $Script:baselines = @()
      foreach ($BaselineFile in $BaselinesFiles) {
        $fileContent = Get-Content $BaselineFile.FullName -Raw -ErrorAction Stop
        $baseline = ConvertFrom-Yaml $fileContent -AllDocuments
        $baseline.Filename = $BaselineFile.BaseName
        $Script:baselines += $baseline
      }
    }
    $($BaselineId.Trim()).yml    
  }
  Process {
    $selectedBaseline = $Script:baselines | Where-Object { $BaselineId -eq $_.Filename -or $BaselineId -eq $_.Id }
    if (0 -eq $selectedBaseline.Count) {
      Write-Log -Level WARNING "$($BaselineId): No matching baseline found with id or name '$BaselineId'" -ErrorAction Stop
      throw "Baseline Error (see above)"
      return
    }
  }
  End {
    return $selectedBaseline
  }
}