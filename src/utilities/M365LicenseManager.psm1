#############################################
#### M365 Licenses (Call API)
#############################################

<#
.Synopsis 
    Handle M365 Licenses through the License Manager
.DESCRIPTION
.EXAMPLE
   Connect-M365LicenseManager -Credential (Get-Credential) -Tenant "mytenant.onmicrosoft.com"
   Get-M365LicensingConfiguration

.EXAMPLE
   # When running the script in "unattended" mode, use the following in order to suppress the password prompt:
   Connect-M365LicenseManager -Credential $Global:UnattendedScriptParameters.Credentials -Tenant "mytenant.onmicrosoft.com"
   # Get the result of the 'SelfServiePurchase' baseline item from M365.LIC.1-1.2 (Licensing Basic Configuration):
   Get-M365LicensingConfiguration -Properties "SelfServicePurchase"
#>

$Script:LicenseManagerToken = $null

Function Connect-M365LicenseManager {
    param (
        [Parameter(Mandatory = $true)][pscredential]$Credential,
        [Parameter(Mandatory = $true)][string]$Tenant,
        [Parameter(Mandatory = $false)][string]$resource = "aeb86249-8ea3-49e2-900b-54cc8e308f85", # Licensemanager API
        [Parameter(Mandatory = $false)][string]$clientId = "3d5cffa9-04da-4657-8cab-c7f074657cad" # client id
    )
  
    $tokenUrl = "https://login.microsoftonline.com/$Tenant.onmicrosoft.com/oauth2/token"
    $grantType = "password"
    $contentType = 'application/x-www-form-urlencoded' 
    
    $body = @{
        grant_type = $grantType
        client_id  = $clientId
        resource   = $resource
        username   = $Credential.UserName
        password   = $Credential.GetNetworkCredential().Password
    }

    try {
        $result = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $body -ContentType $contentType
        $Script:LicenseManagerToken = $result.access_token        
    }
    catch {
        Write-Log -Level ERROR "Connect-M365LicenseManager > $($_.Exception)"
    }
}
    
Function Invoke-M365LicenseManagerRequest {
    param (
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
    
    if (!$Script:LicenseManagerToken) { throw "Invoke-M365LicenseManagerRequest > No valid access provided." }
    
    $token = $Script:LicenseManagerToken
    $headers = @{ Authorization = "Bearer $($token)" }

    $apiBaseUrl = "https://licensing.m365.microsoft.com/v1.0"
    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $path = ($req.path) -replace "{{tenantId}}", $tenantId
            $result = Invoke-RestMethod -Uri "$apiBaseUrl/$path" -ContentType "application/json" -Headers $headers -Method ($($req.method) ? $req.method : "GET")
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value ($req.attr ? $result.$($req.attr) : $result)
        }
        catch {
            Write-Log -Level ERROR "M365 License Manager: $($req.name) / $_"
        }
    }
    
    $requests | Foreach-Object -Parallel {
        try {
            $_
        }
        catch {
            Write-Log -Level ERROR $_
        } 
    } -ThrottleLimit 5
    return $propertiesValues
}

Function Get-M365LicensingConfiguration {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("SelfServicePurchase", "LicenseError", "OnlyGroupBasedLicenseAssignment" )][string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "LicenseError" { @{name = $_; path = "policies/AllowSelfServicePurchase/products"; attr = "" } }
        "OnlyGroupBasedLicenseAssignment" { @{name = $_; path = "policies/AllowSelfServicePurchase/products"; attr = "" } }
        "SelfServicePurchase" { @{name = $_; path = "policies/AllowSelfServicePurchase/products"; attr = "items" } }

        Default {}
    }

    try {
        return Invoke-M365LicenseManagerRequest -ApiRequests $apiSelection
    }
    catch { }
}