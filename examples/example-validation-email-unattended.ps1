# Validate tenant in unattended mode and send report via email (for automation scenarios)
# Email configuration is read from tenant YAML file (Email.Enabled: true, Email.To: [...])
Import-Module .\src\Validation.psm1 -Force

# Prepare unattended authentication
# 👉 Do not store credentials directly in this file; use a vault / credentials manager or ENV variables instead.
$username = "admin@[yourtenant].onmicrosoft.com"
$password = ConvertTo-SecureString "[password]" -AsPlainText -Force

# Optional: Specify Azure Subscription ID
$azureSubscriptionId = "[subscription-id]"  # Or use $null if not needed

# Set unattended mode
if ($azureSubscriptionId) {
   Set-UnattendedRun -username $username -password $password -azureSubscriptionId $azureSubscriptionId
   $result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject -AzureSubscriptionId $azureSubscriptionId
} else {
   Set-UnattendedRun -username $username -password $password
   $result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject
}

# Generate report and send via email
New-Report -ValidationResults $result -AsHTML -SendEmail
