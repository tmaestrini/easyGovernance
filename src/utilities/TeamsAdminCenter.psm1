#############################################
#### TEAMS Admin Center Settings (Call API)
#############################################

<#
.Synopsis
    Handle TEAMS Admin Center (TAC) Settings.
    Don't forget to call Connect-TeamsAdminCenter before using any other functions.
.DESCRIPTION
.EXAMPLE
   Connect-TeamsAdminCenter
#>

$Script:TeamsAdminCenterToken = $null
$Script:ScopeConfig = @{}

Function Connect-TeamsAdminCenter {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "Scope1")] [string]$Scope = "Standard"
    )

    $Script:ScopeConfig = switch ($Scope) {
        "Scope1" { 
            @{
                Resource = "https://api.spaces.skype.com"  # Microsoft Teams Policy Center
                BaseUrl  = "https://admin.microsoft.com/api"
            }
        }
        Default { 
            @{
                Resource = "48ac35b8-9aa8-4d74-927d-1f4a14a0b239"  # Microsoft Teams Admin Portal Service
                BaseUrl  = "https://api.interfaces.records.teams.microsoft.com"
            }
        }
    }    
    
    try {
        if (!$Global:connectionContextName) { throw "No valid access provided." }
        $ctx = Get-AzContext -Name $Global:connectionContextName

        $Script:TeamsAdminCenterToken = Get-AzAccessToken -ResourceUrl $Script:ScopeConfig.Resource -TenantId $ctx.Tenant.Id
        Write-Log -Level DEBUG "Connection established to Teams Admin Center ($Scope)"
    }
    catch {
        Write-Log -Level ERROR $_.Exception
    }
}

Function Invoke-TeamsAdminCenterRequest {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "Scope1")] [string]$Scope = "Standard",
        [Parameter(Mandatory = $true)][object[]]$ApiRequests
    )
        
    if ($Scope -ne "Standard") {
        Connect-TeamsAdminCenter -Scope $Scope
    }

    try {
        if (!$Global:connectionContextName) { throw "No connection context provided." }
        if ($null -eq $Script:TeamsAdminCenterToken) { throw "No token available, please connect first." }

        $token = ConvertFrom-SecureString $Script:TeamsAdminCenterToken.Token -AsPlainText
    }
    catch {
        Write-Log -Level WARNING "Failed to invoke request(s): $_"
        throw $_
    }

    $headers = @{ Authorization = "Bearer $token" }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $path = "$($Script:ScopeConfig.BaseUrl)/$($req.path -replace "{{tenantId}}", $tenantId)"
            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $path -Headers $headers -Method "$($method)" -OperationTimeoutSeconds 30 -RetryIntervalSec 1 -MaximumRetryCount 3 -ConnectionTimeoutSeconds 10
            $propertiesValues | Add-Member -MemberType NoteProperty -Name $req.name -Value ($req.attr ? $result.$($req.attr) : $result)
        }
        catch {
            Write-Log -Level ERROR "$($req.name) / Error: $_"
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

Function Get-TeamsSettings {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("ActivityFeed", "TeamsTargetingPolicy", "TeamsClientConfiguration", "ExternalAccess", "GuestAccess")]
        [string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "ActivityFeed" { @{name = $_; path = "Skype.Policy/configurations/TeamsNotificationAndFeedsPolicy/configuration/Global"; attr = "" } }
        "TeamsTargetingPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsTargetingPolicy/configuration/Global" } }
        "TeamsClientConfiguration" { @{name = $_; path = "Skype.Policy/configurations/TeamsClientConfiguration/configuration/Global" } }
        "ExternalAccess" { 
            @(
                @{name = "ExternalAccess.TenantFederationSettings"; path = "Skype.Policy/configurations/TenantFederationSettings/configuration/global" }
                @{name = "ExternalAccess.TeamsExternalAccessConfiguration"; path = "Skype.Policy/configurations/TeamsExternalAccessConfiguration/configuration/global" }
            )
        }
        "GuestAccess" {
            @(
                @{name = "GuestAccess.TeamsClientConfiguration"; path = "Skype.Policy/configurations/TeamsClientConfiguration" } 
                @{name = "GuestAccess.TeamsGuestCallingConfiguration"; path = "Skype.Policy/configurations/TeamsGuestCallingConfiguration" } 
                @{name = "GuestAccess.TeamsGuestMeetingConfiguration"; path = "Skype.Policy/configurations/TeamsGuestMeetingConfiguration" } 
                @{name = "GuestAccess.TeamsGuestMessagingConfiguration"; path = "Skype.Policy/configurations/TeamsGuestMessagingConfiguration" } 
            )
        }
    }

    # Only make the API call if we have requests to make
    if ($apiSelection.Count -gt 0) {
        try {
            $result = Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
           
            # Merge ExternalAcces properties into a single object
            $externalAccessProperties = $result.PSObject.Properties | Where-Object { $_.Name -like "*ExternalAccess*" }
            if ($externalAccessProperties) {
                $globalExternalAccessConfigurations = [PSCustomObject]@{}
                foreach ($prop in $externalAccessProperties) {
                    if ($prop.Value -and $prop.Value[0].Identity -eq "Global") {
                        $prop.Value[0].PSObject.Properties | ForEach-Object {
                            $globalExternalAccessConfigurations | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                    # Remove individual GuestAccess properties from the result
                    $result.PSObject.Properties.Remove($prop.Name)
                }
            }
            $result | Add-Member -MemberType NoteProperty -Name "ExternalAccess" -Value $globalExternalAccessConfigurations

            # Merge GuestAccess properties into a single object
            $guestAccessProperties = $result.PSObject.Properties | Where-Object { $_.Name -like "*GuestAccess*" }
            if ($guestAccessProperties) {
                $globalGuestConfigurations = [PSCustomObject]@{}
                foreach ($prop in $guestAccessProperties) {
                    if ($prop.Value -and $prop.Value[0].Identity -eq "Global") {
                        $prop.Value[0].PSObject.Properties | ForEach-Object {
                            $globalGuestConfigurations | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
                        }
                    }
                    # Remove individual GuestAccess properties from the result
                    $result.PSObject.Properties.Remove($prop.Name)
                }
            }
            $result | Add-Member -MemberType NoteProperty -Name "GuestAccess" -Value $globalGuestConfigurations
            
            return $result
        }
        catch { 
            throw $_
        }
    }
    else {
        Write-Log -Level WARNING "No matching API requests found for the specified properties"
        return @{}
    }
}

Function Get-Policies {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("OrgWideTeamsPolicy", "OrgWideAppPolicy", "OrgWideCallingPolicy", "OrgWideMeetingPolicy", "OrgWideLiveEventsPolicy")]
        [string[]]$Properties
    )

    $apiSelection = switch ($Properties) {
        "OrgWideTeamsPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsChannelsPolicy/configuration/Global" } }
        "OrgWideAppPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsAppSetupPolicy/configuration/Global" } }
        "OrgWideCallingPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsCallingPolicy/configuration/Global" } }
        "OrgWideMeetingPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsMeetingPolicy/configuration/Global" } }
        "OrgWideLiveEventsPolicy" { @{name = $_; path = "Skype.Policy/configurations/TeamsMeetingBroadcastPolicy/configuration/Global" } }

        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
    }

    try {
        return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}