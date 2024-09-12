Function Set-UnattendedRun {
    param (
        [Parameter(Mandatory = $true)][string]$username,
        [Parameter(Mandatory = $true)][SecureString]$password
    )

    [pscredential]$creds = New-Object System.Management.Automation.PSCredential ($username, $password)

    $Global:UnattendedScriptParameters = @{
        Credentials = $creds;
    }
}

Function Reset-UnattendedRun {
    $Global:UnattendedScriptParameters = $null
}