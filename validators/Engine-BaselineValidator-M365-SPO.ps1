#Parameters
$AdminCenterURL = "https://[tenant]-admin.sharepoint.com"
Connect-PnPOnline -Url $AdminCenterURL -Interactive

$fileContent = Get-Content "./baselines/M365.SPO-5.2.yml" -Raw
$baseline = ConvertFrom-Yaml $fileContent -AllDocuments
# ConvertTo-Yaml -JsonCompatible $baseline

if ($baseline.Topic -eq "SharePoint Online") {
    $tenantSettings = Get-PnPTenant | Select ($baseline.Configuration.ExternalSharing.Keys)
    $baselineSettings = $baseline.Configuration.ExternalSharing

    $output = [System.Collections.SortedList]::new()
    foreach ($key in $baselineSettings.Keys) {
        Write-Host $key
        $test = $null -ne $tenantSettings.$key ? (Compare-Object -ReferenceObject $baselineSettings.$key -DifferenceObject $tenantSettings.$key -IncludeEqual) : $null
        if ($test) { $output.Add($key, $test.SideIndicator -eq "==" ? "✔︎ [$($tenantSettings.$key)]" : "✘ [Should be '$($baselineSettings.$key)' but is '$($tenantSettings.$key)']") | Out-Null }
        else { $output.Add($key, "---") | Out-Null }
    }
    Write-Output ($output | Sort-Object -Property Key)
}