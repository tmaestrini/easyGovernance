using module "../Private/Validation/Class/ApiRequestDefinition.psm1"

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
$Script:TenantId = $null

Function Connect-TeamsAdminCenter {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "SpacesAPI", "TeamsAPI")] [string]$Scope = "Standard"
    )

    $Script:ScopeConfig = switch ($Scope) {
        "SpacesAPI" { 
            @{
                Resource = "https://api.spaces.skype.com"  # Microsoft Teams Policy Center
                BaseUrl  = "https://admin.microsoft.com/api"
            }
        }
        "TeamsAPI" { 
            @{
                Resource = "https://api.spaces.skype.com"  # Microsoft Teams Policy Center
                BaseUrl  = "https://teams.microsoft.com/api"
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
        
        $Script:TenantId = $ctx.Tenant.Id
        $Script:TeamsAdminCenterToken = Get-AzAccessToken -ResourceUrl $Script:ScopeConfig.Resource -TenantId $Script:TenantId
        Write-Log -Level DEBUG "Connection established to Teams Admin Center ($Scope)"
    }
    catch {
        Write-Log -Level ERROR $_.Exception
    }
}

Function Invoke-TeamsAdminCenterRequest {
    param (
        [Parameter(Mandatory = $false)]
        [ValidateSet("Standard", "SpacesAPI", "TeamsAPI")] [string]$Scope = "Standard",
        [Parameter(Mandatory = $true)][ApiRequestDefinition[]]$ApiRequests
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

    $headers = @{ 
        Authorization  = "Bearer $token" 
        "Content-Type" = "application/json"
    }

    $propertiesValues = [PSCustomobject] @{}
    $requests = $ApiRequests | Foreach-Object {
        $req = $_
        try {
            $url = [System.UriBuilder]::new($Script:ScopeConfig.BaseUrl)
            $url.Path = [System.IO.Path]::Combine($url.Path, ($req.path -replace "{{tenantId}}", $Script:TenantId))

            $method = $($req.method) ? $req.method : "GET"
            $result = Invoke-RestMethod -Uri $url.Uri -Headers $headers -Method "$($method)" -OperationTimeoutSeconds 30 -RetryIntervalSec 1 -MaximumRetryCount 3 -ConnectionTimeoutSeconds 10
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
        "ActivityFeed" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsNotificationAndFeedsPolicy/configuration/Global") }
        "TeamsTargetingPolicy" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsTargetingPolicy/configuration/Global") }
        "TeamsClientConfiguration" { 
            @(
                [ApiRequestDefinition]::new("TeamsClientConfiguration.Common", "Skype.Policy/configurations/TeamsClientConfiguration")
                [ApiRequestDefinition]::new("TeamsClientConfiguration.TenantSharedChannelsSettings", "mt/emea/beta/admin/tenantSharedChannelsSettings")
            )
        }
        "ExternalAccess" { 
            @(
                [ApiRequestDefinition]::new("ExternalAccess.TenantFederationSettings", "Skype.Policy/configurations/TenantFederationSettings/configuration/global")
                [ApiRequestDefinition]::new("ExternalAccess.TeamsExternalAccessConfiguration", "Skype.Policy/configurations/TeamsExternalAccessConfiguration/configuration/global")
            )
        }
        "GuestAccess" {
            @(
                [ApiRequestDefinition]::new("GuestAccess.TeamsClientConfiguration", "Skype.Policy/configurations/TeamsClientConfiguration")
                [ApiRequestDefinition]::new("GuestAccess.TeamsGuestCallingConfiguration", "Skype.Policy/configurations/TeamsGuestCallingConfiguration")
                [ApiRequestDefinition]::new("GuestAccess.TeamsGuestMeetingConfiguration", "Skype.Policy/configurations/TeamsGuestMeetingConfiguration")
                [ApiRequestDefinition]::new("GuestAccess.TeamsGuestMessagingConfiguration", "Skype.Policy/configurations/TeamsGuestMessagingConfiguration")
            )
        }
    }

    # Only make the API call if we have requests to make
    if ($apiSelection.Count -gt 0) {
        try {
            $result = Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection 
           
            # Merge TeamsClientConfiguration properties into a single object
            $teamsClientConfigProperties = $result.PSObject.Properties | Where-Object { $_.Name -like "TeamsClientConfiguration.*" }
            if ($teamsClientConfigProperties) {

            }
            $result | Add-Member -MemberType NoteProperty -Name "TeamsClientConfiguration" -Value $globalTeamsClientConfigurations

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
        "OrgWideTeamsPolicy" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsChannelsPolicy/configuration/Global") }
        "OrgWideAppPolicy" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsAppSetupPolicy/configuration/Global") }
        "OrgWideCallingPolicy" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsCallingPolicy/configuration/Global") }
        "OrgWideMeetingPolicy" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsMeetingPolicy/configuration/Global") }
        "OrgWideLiveEventsPolicy" { [ApiRequestDefinition]::new($_, "Skype.Policy/configurations/TeamsMeetingBroadcastPolicy/configuration/Global") }

        Default { Write-Log -Level WARNING "No matching API requests found for the specified property: $_"; continue }
    }

    try {
        return Invoke-TeamsAdminCenterRequest -ApiRequests $apiSelection
    }
    catch { 
        throw $_
    }
}