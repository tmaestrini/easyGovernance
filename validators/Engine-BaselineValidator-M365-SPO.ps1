#Parameters
$AdminCenterURL = "https://tmaestrini-admin.sharepoint.com"
Connect-PnPOnline -Url $AdminCenterURL -Interactive

$fileContent = Get-Content "./baselines/M365.SPO-5.2.yml" -Raw
$baseline = ConvertFrom-Yaml $fileContent -AllDocuments

if ($baseline.Topic -eq "SharePoint Online") {
    $tenantSettings = Get-PnPTenant 
    Clear-Host
    Write-Host "`n------------------------------`n⭐︎ Baseline Validation Results`n------------------------------"
    Test-Settings $tenantSettings -Baseline $baseline | Sort-Object -Property Group, Key `
    | Format-Table -GroupBy Group -Wrap -Property Setting, Result
    
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
}