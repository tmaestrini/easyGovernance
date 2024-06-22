Function Set-UnattendedRun {
    param (
        [Parameter(Mandatory = $true)][string]$username,
        [Parameter(Mandatory = $true)][string]$password,
        [Parameter(Mandatory = $false)][string]$clientId = "31359c7f-bd7e-475c-86db-fdb8c937548e" # the (standard) client id of PnP Management Shell
    )

    [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
    [pscredential]$creds = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)

    $Global:UnattendedScriptParameters = @{
        Credentials = $creds;
        ClientId    = $clientId;
    }
}

Function Reset-UnattendedRun {
    $Global:UnattendedScriptParameters = $null
}