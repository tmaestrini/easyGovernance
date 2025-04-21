####################################################
#### POWER PLATFORM ADMIN CENTER Settings (Call API)
####################################################

<#
.Synopsis 
    Handle Power Platform (PPL) Admin Center Settings
.DESCRIPTION
.EXAMPLE
   
#>

Function Invoke-PPLAdminCenterRequest {
    param (
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
    
    if (!$Global:connectionContextName) { throw "Invoke-PPLAdminCenterRequest > No connection context provided." }
    $ctx = Get-AzContext -Name $Global:connectionContextName
    $tenantId = $ctx.Tenant.Id

    $token = Get-AzAccessToken -ResourceUrl "https://service.powerapps.com"
    $headers = @{ Authorization = "Bearer $($token.Token)" }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $path = "https://api.bap.microsoft.com/providers/$($req.path -replace "{{tenantId}}", $tenantId)"
            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -RetryIntervalSec 1 -MaximumRetryCount 10 -ConnectionTimeoutSeconds 10
            
            # Handle the attr parameter - if it contains dots, it's a nested path
            if ($req.attr) {
                $value = $result
                # Split the attribute path by dots and traverse the object
                $req.attr.Split('.') | ForEach-Object {
                    if ($null -ne $value -and $value.PSObject.Properties[$_]) {
                        $value = $value.$_
                    }
                    else {
                        $value = $null
                        Write-Log -Level WARNING "Property path '$($req.attr)' not found in result for $($req.name)"
                    }
                }
                $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value $value
            }
            else {
                $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value $result
            }
        }
        catch {
            Write-Log -Level ERROR "PPL Admin Center: $($req.name) / $_"
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

Function Request-PPLSettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("DefaultEnvironment", "Tenant"
        )][string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "DefaultEnvironment" { @{name = $_; path = "Microsoft.BusinessAppPlatform/scopes/admin/environments/?api-version=2024-05-01&`$filter=properties/environmentSku eq 'Default'"; attr = "value" } }  
        
        Default { @{name = $_; method = "POST"; path = "Microsoft.BusinessAppPlatform/listTenantSettings?api-version=2024-05-01" } }
    }

    try {
        $response = Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection
        
        $settings = [PSCustomObject] @{
            DefaultEnvironment = ($response.DefaultEnvironment[0] ?? $null);
            Tenant             = ($response.Tenant ?? $null)
        }
        
        return $settings
    }
    catch {
        Write-Error $_
    }
}

Function Request-PPLDataPoliciesSettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("DefaultEnvironment", "NonDefaultEnvironments"
        )][string[]]$Properties,
        [Parameter(Mandatory = $true)][string]$DefaultEnvironmentId
    )
    
    $apiSelection = switch ($Properties) {
        Default { @{name = $_; path = "PowerPlatform.Governance/v1/policies?`$top=100"; attr = "value" } }
    }
    try {
        $apiSelection += @{name = "DefaultEnvironment"; path = "PowerPlatform.Governance/v1/policies?`$top=100"; attr = "value" }
        $response = Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection

        $defaultEnvironment = $response.DefaultEnvironment | Where-Object { 
            $_.environments | Where-Object { $_.name -eq $DefaultEnvironmentId }
        }

        $nonDefaultEnvironments = $response.NonDefaultEnvironments | Where-Object { 
            $policy = $_
            -not ($policy.environments | Where-Object { $_.name -eq $DefaultEnvironmentId })
        }

        $settings = [PSCustomObject] @{
            DefaultEnvironment     = $defaultEnvironment
            NonDefaultEnvironments = $nonDefaultEnvironments
        }

        return $settings
    }        

    catch {
        throw $_
    }
}

Function Request-PPLSecuritySettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("TenantIsolation", "ContentSecurityPolicy"
        )][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "TenantIsolation" { @{name = $_; path = "PowerPlatform.Governance/v1/tenants/{{tenantId}}/tenantIsolationPolicy" } }
        
        Default {}
    }
    try {
        return Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}

Function Request-PPLPowerAutomateSettings {
    param (
        [Parameter(Mandatory = $true)][ValidateSet("GeneralSettings"
        )][string[]]$Properties
    )
    
    $apiSelection = switch ($Properties) {
        "GeneralSettings" { @{name = $_; method = "POST"; path = "Microsoft.BusinessAppPlatform/listTenantSettings?api-version=2024-05-01"; attr = "powerPlatform.powerAutomate" } }
        
        Default {}
    }
    
    try {
        return Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}