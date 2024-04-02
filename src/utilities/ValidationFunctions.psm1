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
  }

  Process {
    foreach ($baselineSettingsGroup in $baseline.Configuration) {
      $groupName = $baselineSettingsGroup.enforces
      $settings = $baselineSettingsGroup.with
      foreach ($key in $settings.Keys) {
        $test = $null -ne $tenantSettings.$key ? (Compare-Object -ReferenceObject $settings.$key -DifferenceObject $tenantSettings.$key -IncludeEqual) : $null
        
        try {
          if ($test) { 
            $testResult.Add("$groupName-$key", [PSCustomObject] @{
                Group   = $groupName
                Setting = $key
                Result  = $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ [Should be '$($settings.$key -join ''' or ''')' but is '$($tenantSettings.$key)']"
                Status  = $test.SideIndicator -eq "==" ? "PASS" : "FAIL"
              })
          }
          else { 
            $referenceHint = $baselineSettingsGroup.references.$key ? $baselineSettingsGroup.references.$key : $null
            $outputObject = [PSCustomObject] @{
              Group   = $groupName
              Setting = $key
              Result  = "--- [Should be '$($settings.$key -join ''' or ''')']"
              Status  = "CHECK NEEDED"
            }
            if ($null -ne $hint) { $outputObject | Add-Member -NotePropertyName Reference -NotePropertyValue $referenceHint }
            $testResult.Add("$groupName-$key", $outputObject);
          }
        }
        catch {
          throw $_
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
    
    Write-Host "----------------------------"
    Write-Host $("{0,-21} {1,5}" -f "Total Checks:", $stats.Total)
    Write-Host "----------------------------"
    Write-Host $("{0,-21} {1,5}" -f "✔ Checks passed: ", $stats.Passed)
    Write-Host $("{0,-21} {1,5}" -f "✘ Checks failed:", $stats.Failed)
    Write-Host $("{0,-21} {1,5}" -f "manual check needed:", $stats.Manual)
    Write-Host "----------------------------"        
      
    return $stats
  }
}
