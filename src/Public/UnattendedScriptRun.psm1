Function Set-UnattendedRun {
    param (
        [Parameter(Mandatory = $true)][string]$username,
        [Parameter(Mandatory = $true)][SecureString]$password,
        [Parameter(Mandatory = $false)][string]$azureSubscriptionId
    )

    [pscredential]$creds = New-Object System.Management.Automation.PSCredential ($username, $password)

    $Global:UnattendedScriptParameters = @{
        Credentials = $creds;
        AzureSubscriptionId = $azureSubscriptionId ?? $null
    }
}

Function Reset-UnattendedRun {
    $Global:UnattendedScriptParameters = $null
}