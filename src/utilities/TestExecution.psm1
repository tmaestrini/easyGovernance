Function Invoke-BaselineItemTests {
  param(
    [PSCustomObject] $TenantSettings,
    [PSCustomObject] $BaselineConfigItem
  )

  # Extract keys BEFORE Describe block for test discovery
  $baselineKeys = if ($BaselineConfigItem -is [System.Enum] -or $BaselineConfigItem -is [string] -or $BaselineConfigItem -is [int] -or $BaselineConfigItem -is [double] -or $BaselineConfigItem -is [float] -or $BaselineConfigItem -is [long] -or $BaselineConfigItem -is [short] -or $BaselineConfigItem -is [byte] -or $BaselineConfigItem -is [bool]) {
    @($BaselineConfigItem)
  } 
  elseif ($BaselineConfigItem -is [array] -or $BaselineConfigItem -is [hashtable]) {
    @($BaselineConfigItem.Keys)
  }
  else {
    @($BaselineConfigItem.PSObject.Properties.Name)
  }

  $testDefinition = {
    Describe "Test Tenant settings $($TenantSettings) against Baseline item $($BaselineConfigItem)" {

      It "Tenant setting matches expected value in Baseline item '<_>'" -ForEach $baselineKeys {
        $itemAttribute = $_
      
        # Get expected value from baseline (object A)
        $expectedValue = if ($BaselineConfigItem -is [System.Enum] -or $BaselineConfigItem -is [string] -or $BaselineConfigItem -is [int] -or $BaselineConfigItem -is [double] -or $BaselineConfigItem -is [float] -or $BaselineConfigItem -is [long] -or $BaselineConfigItem -is [short] -or $BaselineConfigItem -is [byte] -or $BaselineConfigItem -is [bool]) {
          $BaselineConfigItem
        }
        elseif ($BaselineConfigItem -is [array] -or $BaselineConfigItem -is [hashtable]) {
          $BaselineConfigItem[$itemAttribute]
        }
        else {
          $BaselineConfigItem.$itemAttribute
        }
      
        # Get actual value from tenant settings (object B)
        $actualValue = if ($TenantSettings -is [System.Enum] -or $TenantSettings -is [string] -or $TenantSettings -is [int] -or $TenantSettings -is [double] -or $TenantSettings -is [float] -or $TenantSettings -is [long] -or $TenantSettings -is [short] -or $TenantSettings -is [byte] -or $TenantSettings -is [bool]) {
          $TenantSettings
        }
        elseif ($TenantSettings -is [array] -or $TenantSettings -is [hashtable]) {
          $TenantSettings[$itemAttribute]
        }
        else {
          $TenantSettings.$itemAttribute
        }
      
        # Compare values
        $actualValue | Should -Be $expectedValue
      }
    }
  }

  # Execute Pester and return results
  $container = New-PesterContainer -ScriptBlock $testDefinition -Data @{
    TenantSettings     = $TenantSettings
    BaselineConfigItem = $BaselineConfigItem
    baselineKeys       = $baselineKeys
  }

  return Invoke-Pester -Container $container -PassThru -Output None
}