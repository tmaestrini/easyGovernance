<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Add-TenantVariables
#>
function Add-TenantVariables {
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
 
    )
 
    Begin {
 
        $root = ".\"
        $settings = Get-Content -Path "$($root)\.settings.yml" | ConvertFrom-Yaml
 
    }
    Process {
 
        Write-Host "Setting global variables..."
 
        Set-Variable -Scope global -Name tenant -Value $settings.tenant
        Set-Variable -Scope global -Name adminSiteUrl -Value "https://$($tenant)-admin.sharepoint.com"      
 
    }
    End {
 
    }
}

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
                    }
                }
                else { 
                    $output += [PSCustomObject]@{
                        Group   = $baselineSettingsGroup
                        Setting = $key
                        Result  = "---"
                    }
                } 
            }
        }
    
     }
     End {

        return $output
  
     }
  
}
