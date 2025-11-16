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
    function Test-OrOperator {
      param(
        [string]$SettingValue,
        [string]$Key,
        [PSCustomObject]$TenantSettings
      )
      
      $referenceKeys = $SettingValue -split "\|\|"
      $test = $null
      
      foreach ($referenceKey in $referenceKeys) {
        $referenceKey = $referenceKey.Trim()
        $test = Compare-Object -ReferenceObject $referenceKey -DifferenceObject $TenantSettings.$Key -IncludeEqual
        # If one of the reference keys matches, we can stop checking
        if ($test.SideIndicator -eq "==") {
          break
        }
      }
      
      return $test
    }
    
    # Function to handle AND operator validation (&&)
    function Test-AndOperator {
      param(
        [string]$SettingValue,
        [string]$Key,
        [PSCustomObject]$TenantSettings
      )
      
      $referenceKeys = $SettingValue -split "\&\&"
      $test = $null
      
      foreach ($referenceKey in $referenceKeys) {
        $referenceKey = $referenceKey.Trim()
        $test = Compare-Object -ReferenceObject $referenceKey -DifferenceObject $TenantSettings.$Key -IncludeEqual
        # If one of the reference keys fails, we can stop checking
        if ($test.SideIndicator -ne "==") { 
          break
        }
      }
      
      return $test
    }
  }

  Process {
    foreach ($baselineSettingsGroup in $baseline.Configuration) {
      $groupName = $baselineSettingsGroup.enforces
      $settings = $baselineSettingsGroup.with
      foreach ($key in $settings.Keys) {
        try {
          $testRun = $null

          # Check if $settings.$key contains an OR operator (||)
          if ($settings.$key -is [string] -and $settings.$key -like "*||*") {
            $testRun = Test-OrOperator -SettingValue $settings.$key -Key $key -TenantSettings $tenantSettings
          }
          # Check if $settings.$key contains an AND operator (&&)
          elseif ($settings.$key -is [string] -and $settings.$key -like "*&&*") {
            $testRun = Test-AndOperator -SettingValue $settings.$key -Key $key -TenantSettings $tenantSettings
          }
          # Start running PESTER tests for a robust comparison
          else {
            Write-Log -Level INFO -Message "Testing group: $groupName with key: $key"
            $testRun = Invoke-BaselineItemTests -BaselineConfigItem $settings.$key -TenantSettings $tenantSettings.$key
          }
          
          # create a test result object
          if ($null -ne $testRun -and $null -ne $settings.$key) { 
            $testResult = New-TestResult -GroupName $groupName -Key $key -BaselineSettingsGroup $baselineSettingsGroup -BaselineConfigItem $settings.$key `
                            -TenantSettingsItem $tenantSettings.$key -TestDetails $testRun
            $testResults.Add("$groupName-$key", $testResult)

          }
          # If the tenant value or the test result is null, we have to report an issue
          else { 
            $testResult = [PSCustomObject] @{
              Group   = $groupName
              Setting = $key
              Result  = "--- [Should be '$($baselineValue -join ''' or ''')']"
              Status  = "CHECK NEEDED"
            }
            # Set-ReferenceHint -Key $key -BaselineSettingsGroup $baselineSettingsGroup -OutputObject $testResult
            
            $testResults.Add("$groupName-$key", $testResult);
            Write-Log -Level ERROR -Message "No test result for $($groupName) > $($key). Normally, this should not happen. Please check the baseline configuration and the tenant setting manually."
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
