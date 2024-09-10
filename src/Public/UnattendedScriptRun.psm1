Function Set-UnattendedRun {
    param (
        [Parameter(Mandatory = $true)][string]$username,
        [Parameter(Mandatory = $true)][string]$password
    )

    [securestring]$secStringPassword = ConvertTo-SecureString $password -AsPlainText -Force
    [pscredential]$creds = New-Object System.Management.Automation.PSCredential ($username, $secStringPassword)

    $Global:UnattendedScriptParameters = @{
        Credentials = $creds;
    }
}

Function Reset-UnattendedRun {
    $Global:UnattendedScriptParameters = $null
}