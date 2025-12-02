# Azure Automation Runbook: Validate tenant and send report via email
Import-Module easyGovernance -Force

# Get credentials and configuration from Automation Account
$credential = Get-AutomationPSCredential -Name 'M365AdminCredential'
$subscriptionId = Get-AutomationVariable -Name 'AzureSubscriptionId' -ErrorAction SilentlyContinue

# Set unattended mode
Set-UnattendedRun -username $credential.UserName -password $credential.Password -azureSubscriptionId $subscriptionId

# Run validation and send email
$result = Start-Validation -TemplateName "production.yml" -ReturnAsObject -AzureSubscriptionId $subscriptionId
New-Report -ValidationResults $result -AsHTML -SendEmail
