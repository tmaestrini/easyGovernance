<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-Settings
#>
function Test-Settings {
  [CmdletBinding()]
  [Alias()]
  [OutputType([int])]
  Param
  (
    # Tenant settings
    [PSCustomObject]
    $tenantSettings,
 
    # Baseline
    [PSCustomObject]
    $baseline
  )

  Begin {
    $output = @{};
  }

  Process {
    foreach ($baselineSettingsGroup in $baseline.Configuration.Keys) {
      foreach ($key in $baseline.Configuration[$baselineSettingsGroup].Keys) {
        $setting = $baseline.Configuration[$baselineSettingsGroup]
        $test = $null -ne $tenantSettings.$key ? (Compare-Object -ReferenceObject $setting.$key -DifferenceObject $tenantSettings.$key -IncludeEqual) : $null
        
        try {
          $baselineResult
          if ($test) { 
            $output.Add("$baselineSettingsGroup$key", [PSCustomObject] @{
                Group   = $baselineSettingsGroup
                Setting = $key
                Result  = $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ [Should be '$($setting.$key -join ''' or ''')' but is '$($tenantSettings.$key)']"
                Status  = $test.SideIndicator -eq "==" ? "PASS" : "FAIL"
              })
          }
          else { 
            $output.Add("$baselineSettingsGroup$key", [PSCustomObject] @{
                Group   = $baselineSettingsGroup
                Setting = $key
                Result  = "--- [Should be '$($setting.$key -join ''' or ''')']"
                Status  = "CHECK NEEDED"
              })
            }
          }
          catch {
            <#Do this if a terminating exception happens#>
          }
        }
      }
    }
  
    End {
      $output = $output | Sort-Object -Property Key -Unique
      return $output.Values
    }
  }

  function Get-TestStatistics {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
      [Parameter(
        Mandatory = $true
      )][PSCustomObject] 
      $testResult
    )

    Process {
      $stats = @{
        Total  = $testResult.Count
        Passed = $testResult | Where-Object { $_.Status -eq "PASS" } | Measure-Object | Select-Object -ExpandProperty Count
        Failed = $testResult | Where-Object { $_.Status -eq "FAIL" } | Measure-Object | Select-Object -ExpandProperty Count
        Manual = $testResult | Where-Object { $_.Status -eq "CHECK NEEDED" } | Measure-Object | Select-Object -ExpandProperty Count
      }
    
      Write-Host "----------------------------"
      Write-Host $("{0,-21} {1,5}" -f "Total Checks:", $stats.Total)
      Write-Host $("{0,-21} {1,5}" -f "✔ Checks passed: ", $stats.Passed)
      Write-Host $("{0,-21} {1,5}" -f "✘ Checks failed:", $stats.Failed)
      Write-Host $("{0,-21} {1,5}" -f "manual check needed:", $stats.Manual)
      Write-Host "----------------------------"        
      return $stats
    }
  }
