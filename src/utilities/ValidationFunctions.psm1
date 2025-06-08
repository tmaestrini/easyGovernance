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
    $testResult = @{};

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
          $test = $null

          # Check if $settings.$key contains an OR operator (||)
          if ($settings.$key -is [string] -and $settings.$key -like "*||*") {
            $test = Test-OrOperator -SettingValue $settings.$key -Key $key -TenantSettings $tenantSettings
          }
          # Check if $settings.$key contains an AND operator (&&)
          elseif ($settings.$key -is [string] -and $settings.$key -like "*&&*") {
            $test = Test-AndOperator -SettingValue $settings.$key -Key $key -TenantSettings $tenantSettings
          }
          # If $settings.$key is an array, we compare it with the tenant settings
          elseif ($settings.$key -is [array]) {
            $test = Compare-Object -ReferenceObject $settings.$key -DifferenceObject $tenantSettings.$key -IncludeEqual
          }
          # Standard comparison for single values
          else {
            $test = $null -ne $tenantSettings.$key ? (Compare-Object -ReferenceObject $settings.$key -DifferenceObject $tenantSettings.$key -IncludeEqual) : $null
          }
        
          # If the test result is not null, we have a result to report
          if ($test) { 
            $testResult.Add("$groupName-$key", [PSCustomObject] @{
                Group   = $groupName
                Setting = $key
                Result  = $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ [Should be '$($settings.$key -join ''' or ''')' but is '$($tenantSettings.$key)']"
                Status  = $test.SideIndicator -eq "==" ? "PASS" : "FAIL"
              })
          }
          # If the test result is null, we have to report an issue

          else { 
            $referenceHint = $baselineSettingsGroup.references.$key ? $baselineSettingsGroup.references.$key : $null
            $outputObject = [PSCustomObject] @{
              Group   = $groupName
              Setting = $key
              Result  = "--- [Should be '$($settings.$key -join ''' or ''')']"
              Status  = "CHECK NEEDED"
            }
            if ($null -ne $referenceHint) { $outputObject | Add-Member -NotePropertyName Reference -NotePropertyValue $referenceHint }
            $testResult.Add("$groupName-$key", $outputObject);
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
