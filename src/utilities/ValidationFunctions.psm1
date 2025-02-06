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
    # The actual settings from the tenant
    [PSCustomObject]
    $tenantSettings,
 
    # Baseline
    [PSCustomObject]
    $baseline
  )

  Begin {
    $testResult = @{};
  }

  Process {
    foreach ($baselineConfiguration in $baseline.Configuration) {
      $configurationName = $baselineConfiguration.enforces
      $configurationSettings = $baselineConfiguration.with
      foreach ($key in $configurationSettings.Keys) {
        try {
          $test = $null -ne $tenantSettings.$key ? (Compare-Object -ReferenceObject $configurationSettings.$key -DifferenceObject $tenantSettings.$key -IncludeEqual) : $null
        
          if ($test) { 
            $testResult.Add("$configurationName-$key", [PSCustomObject] @{
                Group   = $configurationName
                Setting = $key
                Result  = $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ [Should be '$($configurationSettings.$key -join ''' or ''')' but is '$($tenantSettings.$key)']"
                Status  = $test.SideIndicator -eq "==" ? "PASS" : "FAIL"
              })
          }
          else { 
            $referenceHint = $baselineConfiguration.references.$key ? $baselineConfiguration.references.$key : $null
            $outputObject = [PSCustomObject] @{
              Group   = $configurationName
              Setting = $key
              Result  = "--- [Should be '$($configurationSettings.$key -join ''' or ''')']"
              Status  = "CHECK NEEDED"
            }
            if ($null -ne $referenceHint) { $outputObject | Add-Member -NotePropertyName Reference -NotePropertyValue $referenceHint }
            $testResult.Add("$configurationName-$key", $outputObject);
          }
        }
        catch {
          Write-Log -Level ERROR -Message "$($key): $($_)"
          # throw $_
        }
      }
    }
  }
  
  End {
    $testResult = $testResult | Sort-Object -Property Key -Unique
    return $testResult.Values
  }
}

function Get-TestStatistics {
  [CmdletBinding()]
  [Alias()]
  [OutputType([hashtable])]
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
    
    $output = [System.Text.StringBuilder]::new()
    $output.AppendLine("----------------------------")
    $output.AppendLine($("{0,-21} {1,5}" -f "Total Checks:", $stats.Total))
    $output.AppendLine("----------------------------")
    $output.AppendLine($("{0,-21} {1,5}" -f "✔ Checks passed: ", $stats.Passed))
    $output.AppendLine($("{0,-21} {1,5}" -f "✘ Checks failed:", $stats.Failed))
    $output.AppendLine($("{0,-21} {1,5}" -f "manual check needed:", $stats.Manual))
    $output.AppendLine("----------------------------")

    return @{stats = $stats; asText = $output.ToString() } 
  }
}
