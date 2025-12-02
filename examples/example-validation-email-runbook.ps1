# Azure Automation Runbook: Validate tenant and send report via email using Managed Identity
Import-Module easyGovernance -Force

# Connect with Managed Identity
Connect-MgGraph -Identity -NoWelcome

# Optional: Get Azure Subscription ID from Automation Variable
$subscriptionId = Get-AutomationVariable -Name 'AzureSubscriptionId' -ErrorAction SilentlyContinue

# Run validation with optional subscription parameter
if ($subscriptionId) {
    Write-Output "Using Azure Subscription: $subscriptionId"
    $result = Start-Validation -TemplateName "production.yml" -ReturnAsObject -AzureSubscriptionId $subscriptionId
} else {
    $result = Start-Validation -TemplateName "production.yml" -ReturnAsObject
}

# Generate report and send via email (configured in tenant YAML)
New-Report -ValidationResults $result -AsHTML -SendEmail

# Disconnect
Disconnect-MgGraph
