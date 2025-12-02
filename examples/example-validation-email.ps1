<#
.SYNOPSIS
  Example: Automated validation with email delivery via Microsoft Graph

.DESCRIPTION
  Demonstrates how to run easyGovernance validation in unattended mode
  and automatically send the HTML report via email using Microsoft Graph API.
  
  This example shows various scenarios for email delivery configuration.

.NOTES
  Prerequisites:
  - Microsoft.Graph PowerShell module installed
  - Email.Enabled: true in tenant YAML configuration
  - Microsoft Graph connection with Mail.Send permission
  - Valid recipient email addresses configured in tenant YAML

.EXAMPLE
  # Basic usage with email configured in tenant YAML
  .\example-validation-email.ps1

.EXAMPLE
  # Override recipients from command line
  $result = Start-Validation -TemplateName "tenant.yml" -ReturnAsObject
  New-Report -ValidationResults $result -AsHTML -SendEmail -EmailTo "custom@contoso.com"
#>

# Import the validation module
Import-Module .\src\Validation.psm1 -Force

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "easyGovernance - Validation with Email Delivery" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# SCENARIO 1: Interactive mode with Graph authentication
# ============================================================
Write-Host "SCENARIO 1: Interactive validation with email" -ForegroundColor Yellow
Write-Host "This scenario uses interactive Graph authentication" -ForegroundColor Gray
Write-Host ""

# Connect to Microsoft Graph with Mail.Send permission
# This will open a browser for authentication
Connect-MgGraph -Scopes "Mail.Send" -NoWelcome

# Run validation and generate report with email delivery
# Email settings are automatically read from tenants/[tenant].yml
$result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject -KeepConnectionsAlive

# Generate HTML report and send via email
# Email configuration is read from the tenant YAML file
New-Report -ValidationResults $result -AsHTML -SendEmail

Write-Host "✅ Scenario 1 completed" -ForegroundColor Green
Write-Host ""

# ============================================================
# SCENARIO 2: Unattended mode for Azure Automation
# ============================================================
Write-Host "SCENARIO 2: Unattended mode with credentials" -ForegroundColor Yellow
Write-Host "This scenario demonstrates automation-friendly execution" -ForegroundColor Gray
Write-Host ""

# Prepare unattended authentication
# 👉 IMPORTANT: Do not store credentials directly in scripts!
# Use Azure Key Vault, environment variables, or secure credential management
$username = $env:M365_ADMIN_USER
$password = ConvertTo-SecureString $env:M365_ADMIN_PASSWORD -AsPlainText -Force

if ($username -and $password) {
   Set-UnattendedRun -username $username -password $password

   # Run validation
   $result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject -KeepConnectionsAlive

   # Generate report and send email
   # The unattended credentials will be used for Graph authentication if needed
   New-Report -ValidationResults $result -AsHTML -SendEmail

   Write-Host "✅ Scenario 2 completed" -ForegroundColor Green
} else {
   Write-Host "⚠️ Skipping Scenario 2: Environment variables M365_ADMIN_USER and M365_ADMIN_PASSWORD not set" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# SCENARIO 3: Override email recipients
# ============================================================
Write-Host "SCENARIO 3: Override email recipients" -ForegroundColor Yellow
Write-Host "Send report to different recipients than configured in YAML" -ForegroundColor Gray
Write-Host ""

$result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject -KeepConnectionsAlive

# Override recipients with -EmailTo parameter
# This ignores the 'To' setting in tenant YAML
New-Report -ValidationResults $result -AsHTML -SendEmail -EmailTo @("custom-recipient@contoso.com", "another@contoso.com")

Write-Host "✅ Scenario 3 completed" -ForegroundColor Green
Write-Host ""

# ============================================================
# SCENARIO 4: Force email even without failures
# ============================================================
Write-Host "SCENARIO 4: Send email regardless of validation results" -ForegroundColor Yellow
Write-Host "Useful when SendOnFailedOnly=true but you want to send anyway" -ForegroundColor Gray
Write-Host ""

# Note: In the actual Send-ValidationReport function, you can add -Force parameter
# This is for demonstration - the Force parameter would need to be passed through New-Report
$result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject

New-Report -ValidationResults $result -AsHTML -SendEmail

Write-Host "✅ Scenario 4 completed" -ForegroundColor Green
Write-Host ""

# ============================================================
# Azure Automation Runbook Example
# ============================================================
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Azure Automation Runbook Example Code" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host @"
# Azure Automation Runbook Script
# ---------------------------------

# Connect with Managed Identity
Connect-MgGraph -Identity -NoWelcome

# Import module (ensure it's available in Automation Account)
Import-Module easyGovernance -Force

# Run validation with email delivery
`$result = Start-Validation -TemplateName "production.yml" -ReturnAsObject
New-Report -ValidationResults `$result -AsHTML -SendEmail

# Disconnect
Disconnect-MgGraph

# Managed Identity Configuration Required:
# 1. Azure Portal → Automation Account → Identity → System assigned: On
# 2. Note the Object (principal) ID
# 3. Azure AD → Enterprise Applications → Search for Object ID
# 4. API permissions → Add permission → Microsoft Graph
# 5. Application permissions → Mail.Send
# 6. Grant admin consent
"@ -ForegroundColor Gray

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "All scenarios completed successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

# Cleanup: Disconnect from Graph
Disconnect-MgGraph -ErrorAction SilentlyContinue
