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
    $output = @();
  }

  Process {
    foreach ($baselineSettingsGroup in $baseline.Configuration.Keys) {
      foreach ($key in $baseline.Configuration[$baselineSettingsGroup].Keys) {
        $setting = $baseline.Configuration[$baselineSettingsGroup]
        $test = $null -ne $tenantSettings.$key ? (Compare-Object -ReferenceObject $setting.$key -DifferenceObject $tenantSettings.$key -IncludeEqual) : $null
        if ($test) { 
          $output += [PSCustomObject]@{
            Group   = $baselineSettingsGroup
            Setting = $key
            Result  = $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ [Should be '$($setting.$key)' but is '$($tenantSettings.$key)']"
            Status  = $test.SideIndicator -eq "==" ? "PASS" : "FAIL"
          }
        }
        else { 
          $output += [PSCustomObject]@{
            Group   = $baselineSettingsGroup
            Setting = $key
            Result  = "---"
            Status  = "CHECK NEEDED"
          }
        } 
      }
    }
  }
  
  End {
    return $output
  }
}
