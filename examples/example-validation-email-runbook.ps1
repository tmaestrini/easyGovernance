# Azure Automation Runbook: Validate tenant and send report via email

# Force clean module import
Get-Module Validation, CommonFunctions, EmailFunctions, ValidationFunctions, TemplateFunctions, M365AdminCenter, UnattendedScriptRun -ErrorAction SilentlyContinue | Remove-Module -Force

Import-Module easyGovernance\src\Validation.psm1 -Force

# Initialize paths for Azure Automation
Initialize-AzureAutomationPaths

# Debug: Check if Connect-Tenant has AzureSubscriptionId parameter
$connectTenantParams = (Get-Command Connect-Tenant).Parameters.Keys
Write-Output "Connect-Tenant parameters: $($connectTenantParams -join ', ')"
if ($connectTenantParams -contains 'AzureSubscriptionId') {
    Write-Output "✓ AzureSubscriptionId parameter exists"
} else {
    Write-Output "✗ AzureSubscriptionId parameter MISSING - module needs to be updated!"
}

# Get credentials and configuration from Automation Account
$credential = Get-AutomationPSCredential -Name 'Admin Dako'
$subscriptionId = '3622ff9e-4063-47f7-b84a-c309f48652b5'
# Set unattended mode
Set-UnattendedRun -username $credential.UserName -password $credential.Password -azureSubscriptionId $subscriptionId

# Verify unattended mode is set
if ($Global:UnattendedScriptParameters) {
    Write-Output "Unattended mode confirmed: Username = $($Global:UnattendedScriptParameters.Credentials.UserName)"
} else {
    Write-Output "WARNING: Unattended mode NOT set!"
}

# Run validation and send email
Write-Output "Starting validation..."

# Check if log file exists to see validation output
$logPath = "C:\usr\src\PSModules\easyGovernance\logs"
if (Test-Path $logPath) {
    Write-Output "Log folder found at: $logPath"
    $logFiles = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($logFiles) {
        Write-Output "Latest log file: $($logFiles.FullName)"
        Write-Output "Log file last modified: $($logFiles.LastWriteTime)"
    }
}

# Capture ALL output including errors
$output = @()
$errors = @()

try {
    $ErrorActionPreference = 'Continue'
    
    # Redirect all streams to capture everything
    $result = Start-Validation -TemplateName "dako365labs.yml" -ReturnAsObject -AzureSubscriptionId $subscriptionId -Verbose -ErrorVariable validationErrors 2>&1 | Tee-Object -Variable output
    
    $ErrorActionPreference = 'Stop'
    
    # Show all captured output
    if ($output) {
        Write-Output "=== Captured Output ==="
        $output | ForEach-Object { Write-Output $_ }
    }
    
    if ($validationErrors) {
        Write-Output "=== Validation Errors ==="
        $validationErrors | ForEach-Object { Write-Output $_.Exception.Message }
    }
    
    if ($result) {
        Write-Output "Validation completed successfully"
        Write-Output "Tenant: $($result.Tenant)"
        Write-Output "Validation count: $($result.Validation.Count)"
    } else {
        Write-Output "ERROR: Start-Validation returned null"
        
        # Check if log was updated
        if ($logFiles) {
            $logFiles = Get-ChildItem $logPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            Write-Output "Log file now modified: $($logFiles.LastWriteTime)"
            Write-Output "=== Last 50 lines of log ==="
            Get-Content $logFiles.FullName -Tail 50 | ForEach-Object { Write-Output $_ }
        }
    }
} catch {
    Write-Output "ERROR in Start-Validation: $($_.Exception.Message)"
    Write-Output "Stack trace: $($_.ScriptStackTrace)"
    throw
}

if (-not $result) {
    throw "Validation failed - no results returned"
}

Write-Output "Generating report and sending email..."
New-Report -ValidationResults $result -AsHTML -SendEmail
