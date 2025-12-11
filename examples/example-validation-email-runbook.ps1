# Azure Automation Runbook: Validate tenant and send report via email
Import-Module easyGovernance\src\Validation.psm1 -Force

# Initialize paths for Azure Automation
Initialize-AzureAutomationPaths

# Connect to Microsoft Graph with Managed Identity
Write-Output "Connecting to Microsoft Graph with Managed Identity..."
Connect-MgGraph -Identity
Write-Output "Graph connection established"

# Get credentials and configuration from Automation Account
$credential = Get-AutomationPSCredential -Name 'Admin Dako'
$azureSubscriptionId = '3622ff9e-4063-47f7-b84a-c309f48652b5'

Write-Output "Setting unattended mode with user: $($credential.UserName)"
Set-UnattendedRun -username $credential.UserName -password $credential.Password

# Run validation
Write-Output "Starting validation for tenant: dako365labs.yml with subscription: $azureSubscriptionId"
$result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject -AzureSubscriptionId $azureSubscriptionId

# Debug output
Write-Output "Validation completed. Result type: $($result.GetType().FullName)"
Write-Output "Result is null: $($null -eq $result)"
if ($result) {
    Write-Output "Result keys: $($result.Keys -join ', ')"
    Write-Output "Validation count: $($result.Validation.Count)"
}

# Send email if results exist
if ($result) {
    Write-Output "Generating report and sending email..."
    New-Report -ValidationResults $result -AsHTML -SendEmail
    Write-Output "Email sent successfully"
} else {
    Write-Error "Validation returned null results. Check logs for errors."
}
