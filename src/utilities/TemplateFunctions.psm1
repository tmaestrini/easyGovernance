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
    [Parameter(
    )][string]$BaselinesPath = 'baselines',
    [Parameter(
      HelpMessage = "Force reload of baselines (overwrites already loaded baselines in memory by reading from file system)"
    )][Switch]$Force = $false
  )
 
  Begin {
    # Load all existing baselines
    $ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ..\..\$BaselinesPath
    
    $isConfigPathValid = Test-Path -Path $ConfigPath
    if (!$isConfigPathValid) {
      throw "Invalid Baselines Path: '$BaselinesPath', execution stopped.`nPlease make sure the 'BaselinesPath' attribute in your tenant configuration file is set up correctly."
    }

    if ($null -eq $Script:baselines -or $Force.IsPresent) {
      try {
        $BaselinesFiles = @( Get-ChildItem -Path $ConfigPath\*.yml -ErrorAction SilentlyContinue )
      }
      catch {
        <#Do this if a terminating exception happens#>
      }

      $Script:baselines = @()
      foreach ($BaselineFile in $BaselinesFiles) {
        $fileContent = Get-Content $BaselineFile.FullName -Raw -ErrorAction Stop
        try {
          $baseline = ConvertFrom-Yaml $fileContent -AllDocuments
          $baseline.Filename = $BaselineFile.BaseName
          $Script:baselines += $baseline
        }
        catch {
          Write-Log -Level ERROR "Invalid baseline content definition for $($baseline.Id) on '$($BaselineFile.FullName)'`n$($_)"
        }
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

function Get-ConfigurationFromBaselineTemplate {
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    [Parameter(
      Mandatory = $true
    )][PSCustomObject]$Baseline,
    [Parameter(
      Mandatory = $true
    )][string]$ConfigurationName
  )
 
  Begin {
    $selectedBaseline = $Baseline
  }
  Process {
    $selectedConfiguration = $selectedBaseline.Configuration | Where-Object { $ConfigurationName -eq $_.enforces }
    if (0 -eq $selectedConfiguration.Count) {
      Write-Log -Level WARNING "$($ConfigurationName): No matching configuration found with '$ConfigurationName' in baseline" -ErrorAction Stop
      throw "Configuration Error (see above)"
      return
    }
  }
  End {
    return $selectedConfiguration.with
  }
}