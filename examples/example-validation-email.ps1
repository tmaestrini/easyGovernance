# Validate tenant and send report via email
# Email configuration is read from tenant YAML file (Email.Enabled: true, Email.To: [...])
Import-Module .\src\Validation.psm1 -Force

# Connect to Microsoft Graph with Mail.Send permission
Connect-MgGraph -Scopes "Mail.Send" -NoWelcome

# Run validation and send email
$result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject -KeepConnectionsAlive
New-Report -ValidationResults $result -AsHTML -SendEmail

# Optional: Override recipients
# New-Report -ValidationResults $result -AsHTML -SendEmail -EmailTo "custom@contoso.com"

# For Azure Automation Runbook with Managed Identity:
# Connect-MgGraph -Identity -NoWelcome
# $result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject -AzureSubscriptionId "[subscription-id]"
# New-Report -ValidationResults $result -AsHTML -SendEmail

"@ -ForegroundColor Gray

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "All scenarios completed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

# Cleanup: Disconnect from Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
