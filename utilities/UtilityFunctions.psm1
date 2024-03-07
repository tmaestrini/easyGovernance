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


function Test-Settings($tenantSettings, $baseline) {
    $output = @();
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
    return $output
}
