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
    
    Function Compare-ComplexSettings($tenantSettings, $configurationSettings) {
      Function Format-TenantSettings($tenantSettingsConfiguration) {
        $tenantResult = @{}
        $tenantSettingsConfiguration | Get-Member -MemberType *Property | ForEach-Object {
          $tenantResult[$_.Name] = $tenantSettingsConfiguration.$($_.Name)
        }
        return $tenantResult
      }

      # If the tenant settings are complex objects, we need to format them into a Hashtable in order to compare them
      $tenantSettingsFormatted = Format-TenantSettings -tenantSettings $tenantSettings

      # Compare the tenant settings with the configuration settings
      $result = Compare-Object $tenantSettingsFormatted.PSObject.Properties $configurationSettings.PSObject.Properties -IncludeEqual
      $output = [ordered]@{
        status = -not $result
        should = $configurationSettings;
        is     = $tenantSettingsFormatted;
      }
      return $output
    }
  }

  Process {
    foreach ($baselineConfiguration in $baseline.Configuration) {
      $configurationName = $baselineConfiguration.enforces
      $configurationSettings = $baselineConfiguration.with
      foreach ($key in $configurationSettings.Keys) {
        try {  
          # If the tenant settings are complex objects, we need to compare them differently
          if ($null -ne $tenantSettings.$configurationName.$key -and ($tenantSettings.$configurationName.$key.GetType() -in @("Hashtable", "PSCustomObject", "Object[]"))) {
            $test = Compare-ComplexSettings -tenantSettings $tenantSettings.$configurationName.$key -configurationSettings $configurationSettings.$key

            if ($test) { 
              $testResult.Add("$configurationName-$key", [PSCustomObject] @{
                  Group   = $configurationName
                  Setting = $key
                  Result  = $test.status ? "✔︎ [$($tenantSettings.$configurationName.$key)]" : "✘ Should be <pre>$($test.should | ConvertTo-Yaml)</pre> but is <pre>$($test.is | ConvertTo-Yaml)</pre>"
                  Status  = $test.status ? "PASS" : "FAIL"
                })
            }
          }
          # If the tenant settings are simple values, we can compare them directly
          elseif ($null -ne $tenantSettings.$configurationName.$key) {
            $test = Compare-Object -ReferenceObject $configurationSettings.$key -DifferenceObject $tenantSettings.$key -IncludeEqual
            
            if ($test) { 
              $testResult.Add("$configurationName-$key", [PSCustomObject] @{
                  Group   = $configurationName
                  Setting = $key
                  Result  = $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ Should be '$($configurationSettings.$key -join ''' or ''')' but is '$($tenantSettings.$key)'"
                  Status  = $test.SideIndicator -eq "==" ? "PASS" : "FAIL"
                })
            }  
          }
          else {
            $test = $null
            $referenceHint = $baselineConfiguration.references.$key ? $baselineConfiguration.references.$key : $null

            # Distinghuish between complex settings and simple settings and create the output object
            if($configurationSettings.$key.GetType() -in @("Hashtable", "PSCustomObject", "Object[]")) {
              $outputObject = [PSCustomObject] @{
                Group   = $configurationName
                Setting = $key
                Result  = "--- Should be <pre>$($configurationSettings.$key | ConvertTo-Yaml)</pre>"
                Status  = "CHECK NEEDED"
              }
            } else {
              $outputObject = [PSCustomObject] @{
                Group   = $configurationName
                Setting = $key
                Result  = "--- Should be '$($configurationSettings.$key -join ''' or ''')'"
                Status  = "CHECK NEEDED"
              }
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
