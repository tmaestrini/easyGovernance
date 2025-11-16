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
    $testResults = @{};
    # Function to handle OR operator validation (||)
  }

  Process {
    foreach ($baselineSettingsGroup in $baseline.Configuration) {
      $groupName = $baselineSettingsGroup.enforces
      $settings = $baselineSettingsGroup.with
      foreach ($key in $settings.Keys) {
        try {
          $testRun = $null

          Write-Log -Level INFO -Message "Testing group: $groupName with key: $key"
          $testRun = Invoke-BaselineItemTests -BaselineConfigItem $settings.$key -TenantSettings $tenantSettings.$key
          
          # create a test result object
          if ($null -ne $testRun) { 
            $testResult = New-TestResult -GroupName $groupName -Key $key -BaselineSettingsGroup $baselineSettingsGroup -BaselineConfigItem $settings.$key `
              -TenantSettingsItem $tenantSettings.$key -TestDetails $testRun
            $testResults.Add("$groupName-$key", $testResult)
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
    $testResults = $testResults | Sort-Object -Property Key -Unique
    return $testResults.Values
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
    $TestResults
  )

  Process {
    $stats = @{
      Total  = $TestResults.Count
      Passed = $TestResults | Where-Object { $_.Status -eq "PASS" } | Measure-Object | Select-Object -ExpandProperty Count
      Failed = $TestResults | Where-Object { $_.Status -eq "FAIL" } | Measure-Object | Select-Object -ExpandProperty Count
      Manual = $TestResults | Where-Object { $_.Status -eq "CHECK NEEDED" } | Measure-Object | Select-Object -ExpandProperty Count
    }
    
    $output = [System.Text.StringBuilder]::new()
    $output.AppendLine("----------------------------")
    $output.AppendLine($("{0,-21} {1,5}" -f "Total Checks:", $stats.Total))
    $output.AppendLine("----------------------------")
    $output.AppendLine($("{0,-21} {1,5}" -f "✔ Checks passed: ", $stats.Passed))
    $output.AppendLine($("{0,-21} {1,5}" -f "✘ Checks failed:", $stats.Failed))
    $output.AppendLine($("{0,-21} {1,5}" -f "manual check needed:", $stats.Manual))
    $output.AppendLine("----------------------------")

    return  @{stats = $stats; asText = $output.ToString() } 
  }
}
