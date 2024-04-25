#############################################
#### M365 ADMIN CENTER Settings (Call API)
#############################################

<#
.Synopsis 
    Handle M365 Admin Center (MAC) Settings
.DESCRIPTION
.EXAMPLE
   Get-M365TenantSettings
#>
Function Get-M365TenantSettings {
    param (
        [Parameter(Mandatory = $true)][string[]]$Properties
    )
    
    try {
        # Delete this line afterwords
        if (!$Global:connectionContextName) { throw "Get-M365TenantSettings > No connection context provided." }
        
        # $ctx = $Global:AzureContext
        Get-AzContext -Name $Global:connectionContextName | Out-Null
        $token = Get-AzAccessToken -ResourceUrl "https://admin.microsoft.com"
    }
    catch {
        throw $_
    }
    $headers = @{ Authorization = "Bearer $($token.Token)" }

    $propertiesValues = [PSCustomobject] @{}
    $Properties | ForEach-Object {
        $property = ($_ -split "/")[-1]
        try {
            $result = Invoke-RestMethod -Uri "https://admin.microsoft.com/admin/api/$_" -Headers $headers
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $property -Value $result           
        }
        catch {
            $_
        }
    }
    return $propertiesValues
}