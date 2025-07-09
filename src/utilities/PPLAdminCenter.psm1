####################################################
#### POWER PLATFORM ADMIN CENTER Settings (Call API)
####################################################

<#
.Synopsis 
    Handle Power Platform (PPL) Admin Center Settings
.DESCRIPTION
.EXAMPLE
   
#>

Function Invoke-PPLOrganizationRequestForEnvironment {
    param (
        [Parameter(Mandatory = $true)][object]$ApiRequest
    )
    
    if (!$Global:connectionContextName) { throw "Invoke-PPLOrganizationRequest > No connection context provided." }
    $ctx = Get-AzContext -Name $Global:connectionContextName
    $tenantId = $ctx.Tenant.Id

    $token = Get-AzAccessToken -ResourceUrl $ApiRequest.scope
    $plainTextToken = ConvertFrom-SecureString $token.Token -AsPlainText

    $headers = @{ Authorization = "Bearer $($plainTextToken)" }
    try {
        $path = "$($ApiRequest.path)/api/data/v9.0/organizations"
        $method = $($ApiRequest.method) ? $ApiRequest.method : "GET"

        # Try organization endpoint first
        try {
            $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -RetryIntervalSec 1 -MaximumRetryCount 10 -ConnectionTimeoutSeconds 3
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 403) {
                Write-Log -Level WARNING "Organization endpoint access denied, no sufficient permissions with the provided credentials; we need to have 'System Administrator' rights on the environment '$($ApiRequest.name)'."
                
                return
            }
            else {
                throw $_
            }
        }

        $propertiesValues = [PSCustomobject] @{}
    
        # Call the API endpoint to get the environment details
        $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -RetryIntervalSec 1 -MaximumRetryCount 10 -ConnectionTimeoutSeconds 10
        
        # Handle the attr parameter - if it contains dots, it's a nested path
        if ($ApiRequest.attr) {
            $requestData = $result
            # Split the attribute path by dots and traverse the object
            $ApiRequest.attr.Split('.') | ForEach-Object {
                if ($null -ne $requestData.$_) {
                    $requestData = $requestData.$_
                }
                else {
                    $requestData = $null
                    Write-Log -Level WARNING "Property path '$($ApiRequest.attr)' not found in result"
                }
            }
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $ApiRequest.attr -Value $requestData[0]
        }
        else {
            $propertiesValues | Add-Member -MemberType NoteProperty -Name "value" -Value $requestData
        }
    }
    catch {
        Write-Log -Level ERROR "PPL Admin Center: $($req.name) / $_"
    }
    
    return $propertiesValues
}

Function Invoke-PPLAdminCenterRequest {
    param (
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
    
    if (!$Global:connectionContextName) { throw "Invoke-PPLAdminCenterRequest > No connection context provided." }
    $ctx = Get-AzContext -Name $Global:connectionContextName
    $tenantId = $ctx.Tenant.Id

    $token = Get-AzAccessToken -ResourceUrl "https://service.powerapps.com"
    $plainTextToken = ConvertFrom-SecureString $token.Token -AsPlainText

    $headers = @{ Authorization = "Bearer $($plainTextToken)" }

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
        "ContentSecurityPolicy" { @{name = $_; path = "Microsoft.BusinessAppPlatform/scopes/admin/environments/?api-version=2024-05-01&`$select=location,name,properties.createdBy,properties.createdTime,properties.displayName,properties.environmentSku,properties.provisioningState,properties.retentionPeriod,properties.linkedEnvironmentMetadata,properties.clientUris,properties.states,properties.softDeletedTime,properties.lifecycleOperationsEnforcement,properties.connectedGroups,properties.ongoingOperation,properties.expirationTime,properties.maxAllowedExpirationTime,properties.scheduledLifecycleOperations,properties.governanceConfiguration,properties.protectionStatus,properties/lastActivity/lastActivity/lastActivityTime,properties.parentEnvironmentGroup,properties.runtimeEndpoints,properties.cluster.category,properties.finOpsMetadata&`$expand=properties/scheduledLifecycleOperations"; attr = "value" } }
        
        Default {}
    }
    try {
        $request = Invoke-PPLAdminCenterRequest -ApiRequests $apiSelection

        if($Properties -contains "ContentSecurityPolicy") {
            $csp = @()
            $request.ContentSecurityPolicy | ForEach-Object {
                try {
                    $env = Request-PPLEnvironmentDetails -Environment $_
                    $csp += @{
                        environmentName = $env.name;
                        iscontentsecuritypolicyenabled = $env.value.iscontentsecuritypolicyenabled;
                        iscontentsecuritypolicyenabledforcanvas = $env.value.iscontentsecuritypolicyenabledforcanvas;
                    }
                }
                catch {
                    Write-Log -Level ERROR $_
                } 
            } 

            # Filter out null values
            $request.ContentSecurityPolicy = $csp | Where-Object { $_ -ne $null }
        } 
        
        return $request
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

Function Request-PPLEnvironmentDetails {
    param (
        [Parameter(Mandatory = $true)][pscustomobject] $Environment
    )
    $url = $Environment.properties.linkedEnvironmentMetadata.instanceApiUrl
    $Environment.properties.linkedEnvironmentMetadata.resourceId

    $result = Invoke-PPLOrganizationRequestForEnvironment -ApiRequest @(
        @{
            name = $Environment.properties.linkedEnvironmentMetadata.friendlyName
            path = $Environment.properties.linkedEnvironmentMetadata.instanceApiUrl
            scope = $Environment.properties.linkedEnvironmentMetadata.instanceUrl
            method = "GET"
            attr = "value"
        }
    )

    $result | Add-Member -MemberType NoteProperty -Name "name" -Value $Environment.properties.linkedEnvironmentMetadata.friendlyName -Force
    return $result
}