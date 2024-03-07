# Set things up
Import-Module ./utilities/UtilityFunctions.psm1 -Force

Add-TenantVariables


#Parameters
Connect-PnPOnline -Url $adminSiteUrl -Interactive

$fileContent = Get-Content "./baselines/M365.SPO-5.2.yml" -Raw
$baseline = ConvertFrom-Yaml $fileContent -AllDocuments

if ($baseline.Topic -eq "SharePoint Online") {
    $tenantSettings = Get-PnPTenant 
    Clear-Host
    Write-Host "`n------------------------------`n⭐︎ Baseline Validation Results`n------------------------------"
    Test-Settings $tenantSettings -Baseline $baseline | Sort-Object -Property Group, Key `
    | Format-Table -GroupBy Group -Wrap -Property Setting, Result
    
}