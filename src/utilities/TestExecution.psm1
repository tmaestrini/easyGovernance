using module ..\Private\Validation\Class\BaselineItemStrategy.psm1

Function Invoke-BaselineItemTests {
  param(
    [PSCustomObject] $TenantSettings,
    [PSCustomObject] $BaselineConfigItem
  )

  Function New-PesterTestForBaselineItem {
    $BaselineItemKeys = [BaselineItemStrategy]::GetKeys($BaselineConfigItem)

    $testDefinition = [scriptblock] {
      param($TenantSettings, $BaselineConfigItem, $BaselineItemKeys)

      Describe "Test Tenant settings $($TenantSettings) against Baseline item $($BaselineConfigItem)" {

        It "Tenant setting matches expected value in Baseline item '<_>'" -ForEach $BaselineItemKeys {
          $itemAttribute = $_
        
          $expectedValue = [BaselineItemStrategy]::GetValue($BaselineConfigItem, $itemAttribute)
          $actualValue = [BaselineItemStrategy]::GetValue($TenantSettings, $itemAttribute)
        
          $actualValue | Should -Be $expectedValue
        }
      }
    }

    return New-PesterContainer -ScriptBlock $testDefinition -Data @{
      TenantSettings     = $TenantSettings
      BaselineConfigItem = $BaselineConfigItem
      BaselineItemKeys   = $BaselineItemKeys
    }
  }

  Function New-PesterTestOrOperatorInBaselineItem {
    $baselineItems = $BaselineConfigItem -split "\|\|" | ForEach-Object { $_.Trim() }

    $testDefinition = [scriptblock] {
      param($TenantSettings, $baselineItems)
      

      Describe "Test baseline item with AND operator" {

        It "Baseline item '<_>' expected to be in tenant setting" {
          $expectedValues = $baselineItems
          $actualValue = $TenantSettings
        
          # Check if actual value matches ANY of the expected values
          $actualValue | Should -BeIn $expectedValues
        }
      }
    }

    return New-PesterContainer -ScriptBlock $testDefinition -Data @{
      TenantSettings = $TenantSettings
      BaselineItems  = $baselineItems
    }
  }

  Function New-PesterTestAndOperatorInBaselineItem {
    $baselineItems = $BaselineConfigItem -split "\&\&" | ForEach-Object { $_.Trim() }

    $testDefinition = [scriptblock] {
      param($TenantSettings, $BaselineItems)
      

      Describe "Test baseline item with AND operator" {

        It "Baseline item '<_>' expected to be in tenant setting" -ForEach $BaselineItems {
          $expectedValue = $_
          $actualValue = $TenantSettings
        
          # ALL items must match
          $actualValue | Should -Be $expectedValue
        }
      }
    }

    return New-PesterContainer -ScriptBlock $testDefinition -Data @{
      TenantSettings     = $TenantSettings
      BaselineItems      = $baselineItems
    }
  }

  # 
  $container = Switch ($true) {
    ($BaselineConfigItem -is [string] -and $BaselineConfigItem -like "*||*") { New-PesterTestOrOperatorInBaselineItem -TenantSettings $TenantSettings -BaselineConfigItem $BaselineConfigItem }
    ($BaselineConfigItem -is [string] -and $BaselineConfigItem -like "*&&*") { New-PesterTestAndOperatorInBaselineItem -TenantSettings $TenantSettings -BaselineConfigItem $BaselineConfigItem }
    Default { New-PesterTestForBaselineItem -TenantSettings $TenantSettings -BaselineConfigItem $BaselineConfigItem } 
  }

  return Invoke-Pester -Container $container -PassThru -Output None
}

Function New-TestResult {
  param(
    [string]$GroupName,
    [string]$Key,
    [PSCustomObject]$BaselineSettingsGroup,
    [PSCustomObject]$BaselineConfigItem,
    [PSCustomObject]$TenantSettingsItem,
    [PSCustomObject]$TestDetails
  )

  $baselineConfigItemValue = ConvertTo-SerializableValue -Value $BaselineConfigItem
  $TenantSettingsValue = ConvertTo-SerializableValue -Value $TenantSettingsItem

  $outputObject = [PSCustomObject] @{}

  # If the test result is not null, we have a result to report
  if ($null -ne $TestDetails -and $null -ne $TenantSettingsItem) { 

    $totalFailed = ($TestDetails | Measure-Object -Property FailedCount -Sum).Sum
    $errorHint = ($totalFailed -gt 0) ? ($TestDetails.Tests | Where-Object { $_.Result -eq 'Failed' } | ForEach-Object { "→ [$($_.Data)] $($_.ErrorRecord[0]?.ToString() ?? 'No additional error details')" }) : ""

    $outputObject | Add-Member -MemberType NoteProperty -Name Group -Value $GroupName
    $outputObject | Add-Member -MemberType NoteProperty -Name Setting -Value $Key
    $outputObject | Add-Member -MemberType NoteProperty -Name Result -Value (($totalFailed -eq 0) ? "✔︎ [$TenantSettingsValue]" : "✘ [Should be '$($baselineConfigItemValue -join ''' or ''')' but is '$TenantSettingsValue']")
    $outputObject | Add-Member -MemberType NoteProperty -Name ResultDetails -Value $errorHint
    $outputObject | Add-Member -MemberType NoteProperty -Name Status -Value (($totalFailed -eq 0) ? "PASS" : "FAIL")
    $outputObject | Add-Member -MemberType NoteProperty -Name TotalTests -Value ($TestDetails | Measure-Object -Property TotalCount -Sum).Sum
            
    if ($outputObject.Status -eq "FAIL") {
      $outputObject | Add-Member -MemberType NoteProperty -Name "ReferenceHint" -Value $BaselineSettingsGroup.references.$Key
    }
  }
  # If the tenant value or the test result is null, we have to report an issue
  else { 
    $outputObject | Add-Member -MemberType NoteProperty -Name Group -Value $GroupName
    $outputObject | Add-Member -MemberType NoteProperty -Name Setting -Value $Key
    $outputObject | Add-Member -MemberType NoteProperty -Name Result -Value "--- [Should be '$($baselineConfigItemValue -join ''' or ''')']"
    $outputObject | Add-Member -MemberType NoteProperty -Name Status -Value "CHECK NEEDED"
    $outputObject | Add-Member -MemberType NoteProperty -Name "ReferenceHint" -Value $BaselineSettingsGroup.references.$Key
            
    Write-Log -Level ERROR -Message "No test result for $($GroupName) > $($Key). Normally, this should not happen. Please check the baseline configuration and the tenant setting manually."
  }

  return $outputObject
}

# Helper function to serialize complex objects for comparison
function ConvertTo-SerializableValue {
  param([object]$Value)
      
  # Only serialize if it's not a simple type (string, number, boolean)
  if ($Value -is [System.Enum] -or $Value -is [string] -or $Value -is [int] -or $Value -is [double] -or $Value -is [float] -or $Value -is [long] -or $Value -is [short] -or $Value -is [byte] -or $Value -is [bool]) {
    return $Value
  }
  else {
    return $Value | ConvertTo-Json -Depth 10 -Compress
  }
}
