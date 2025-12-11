# Validate tenant in unattended mode and send report via email (for automation scenarios)
# Email configuration is read from tenant YAML file (Email.Enabled: true, Email.To: [...])
Import-Module .\src\Validation.psm1 -Force

# Connect with Managed Identity
Connect-MgGraph -Identity

# Prepare unattended authentication
# 👉 Do not store credentials directly in this file; use a vault / credentials manager or ENV variables instead.
$username = "admin@dako365labs.onmicrosoft.com"
$password = ConvertTo-SecureString "ebysRU&hN4uwA3@u" -AsPlainText -Force

# Optional: Specify Azure Subscription ID
$azureSubscriptionId = "3622ff9e-4063-47f7-b84a-c309f48652b5"  # Or use $null if not needed

# Set unattended mode
Set-UnattendedRun -username $username -password $password
$result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject -AzureSubscriptionId $azureSubscriptionId

# Generate report and send via email
New-Report -ValidationResults $result -AsHTML -SendEmail
