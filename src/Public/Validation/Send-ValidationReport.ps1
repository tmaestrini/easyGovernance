<#
.SYNOPSIS
  Sends a validation report via Microsoft Graph Mail API

.DESCRIPTION
  Sends the generated HTML validation report as an email attachment.
  Requires an active Microsoft Graph connection with Mail.Send permission.
  Automatically reads email configuration from tenant settings file.
  
  Features:
  - Automatic email configuration from tenant YAML
  - Fancy HTML email body with statistics
  - Support for SendOnFailedOnly logic
  - Graph API permission validation
  - Retry logic with exponential backoff

.PARAMETER ValidationResults
  The validation results hashtable from Start-Validation -ReturnAsObject

.PARAMETER ReportPath
  Full path to the generated HTML report file

.PARAMETER TenantConfig
  The tenant configuration object containing Email settings

.PARAMETER EmailTo
  Override To recipients from tenant config (optional)

.PARAMETER Force
  Send email even if SendOnFailedOnly=true and no failures detected

.EXAMPLE
  Send-ValidationReport -ValidationResults $result -ReportPath "report.html" -TenantConfig $config

.EXAMPLE
  # Override recipients
  Send-ValidationReport -ValidationResults $result -ReportPath "report.html" -TenantConfig $config -EmailTo "admin@contoso.com"

.EXAMPLE
  # Force send even with no failures
  Send-ValidationReport -ValidationResults $result -ReportPath "report.html" -TenantConfig $config -Force

.NOTES
  Requires:
  - Microsoft.Graph PowerShell module
  - Active Graph connection with Mail.Send permission
  - Email.Enabled: true in tenant configuration (unless -Force)
#>

Function Send-ValidationReport {
  [CmdletBinding()]
  [OutputType([void])]
  
  Param(
    [Parameter(Mandatory=$true)]
    [hashtable]$ValidationResults,
    
    [Parameter(Mandatory=$true)]
    [string]$ReportPath,
    
    [Parameter(Mandatory=$true)]
    [PSCustomObject]$TenantConfig,
    
    [Parameter(Mandatory=$false)]
    [string[]]$EmailTo,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
  )
  
  Begin {
    Write-Log "📧 Preparing email delivery..."
    
    # Validate email configuration exists
    if (!$TenantConfig.Email) {
      Write-Log -Level WARNING "No Email configuration found in tenant settings"
      if (!$Force) { return }
    }
    
    # Check if email is enabled
    if (!$TenantConfig.Email.Enabled -and !$Force) {
      Write-Log -Level WARNING "Email delivery is not enabled in tenant configuration (Email.Enabled: false)"
      Write-Log "To enable: Set 'Email.Enabled: true' in your tenant YAML file or use -Force parameter"
      return
    }
    
    # Determine recipients (override or from config)
    $recipients = if ($EmailTo) { 
      $EmailTo 
    } elseif ($TenantConfig.Email.To) { 
      $TenantConfig.Email.To 
    } else { 
      $null 
    }
    
    if (!$recipients -or $recipients.Count -eq 0) {
      throw "No email recipients specified. Configure 'Email.To' in tenant YAML or use -EmailTo parameter"
    }
    
    Write-Log "Recipients: $($recipients -join ', ')"
  }
  
  Process {
    try {
      # Calculate statistics from validation results
      $stats = @{
        Total = 0
        Passed = 0
        Failed = 0
        Manual = 0
      }
      
      $baselineNames = @()
      
      foreach ($result in $ValidationResults.Validation) {
        if ($result.Statistics -and $result.Statistics.stats) {
          $stats.Total += $result.Statistics.stats.Total
          $stats.Passed += $result.Statistics.stats.Passed
          $stats.Failed += $result.Statistics.stats.Failed
          $stats.Manual += $result.Statistics.stats.Manual
        }
        if ($result.Baseline -and $result.Baseline.Id) {
          $baselineNames += "$($result.Baseline.Id) v$($result.Baseline.Version)"
        }
      }
      
      Write-Log "Validation statistics: Passed=$($stats.Passed), Failed=$($stats.Failed), Manual=$($stats.Manual)"
      
      # Check if should send based on SendOnFailedOnly logic
      if ($TenantConfig.Email.SendOnFailedOnly -and $stats.Failed -eq 0 -and !$Force) {
        Write-Log "No validation failures detected and SendOnFailedOnly=true, skipping email delivery"
        Write-Log "Use -Force parameter to send email regardless of validation results"
        return
      }
      
      # Validate report file exists
      if (!(Test-Path $ReportPath)) {
        throw "Report file not found: $ReportPath"
      }
      
      Write-Log "Report file: $ReportPath"
      
      # Validate Graph connection
      if (!(Test-GraphConnection)) {
        Write-Log -Level WARNING "No active Microsoft Graph connection detected"
        
        # Try to connect if in unattended mode
        if ($Global:UnattendedScriptParameters -and $Global:UnattendedScriptParameters.Credentials) {
          Write-Log "Attempting Graph connection with unattended credentials..."
          $creds = $Global:UnattendedScriptParameters.Credentials
          Connect-MgGraph -Scopes "Mail.Send" -Credential $creds -ErrorAction Stop
        } else {
          throw "No Graph connection. Please run Connect-MgGraph -Scopes 'Mail.Send' first"
        }
      }
      
      # Validate Mail.Send permission
      if (!(Test-GraphMailPermission)) {
        throw "Missing required Microsoft Graph permission: Mail.Send. See log for details."
      }
      
      Write-Log "Graph connection validated, Mail.Send permission confirmed"
      
      # Compose subject with template variable replacement
      $subject = if ($TenantConfig.Email.Subject) { 
        $TenantConfig.Email.Subject 
      } else { 
        "easyGovernance Report: {Tenant} - {Date}" 
      }
      
      $subject = $subject `
        -replace '\{Tenant\}', $ValidationResults.Tenant `
        -replace '\{Date\}', (Get-Date -Format 'yyyy-MM-dd') `
        -replace '\{Time\}', (Get-Date -Format 'HH:mm') `
        -replace '\{PassedCount\}', $stats.Passed `
        -replace '\{FailedCount\}', $stats.Failed
      
      Write-Log "Email subject: $subject"
      
      # Generate email body
      $bodyParams = @{
        ReportStats        = $stats
        TenantName         = $ValidationResults.Tenant
        BodyStyle          = if ($TenantConfig.Email.BodyStyle) { $TenantConfig.Email.BodyStyle } else { 'Fancy' }
        IncludeStatistics  = if ($null -ne $TenantConfig.Email.IncludeStatistics) { $TenantConfig.Email.IncludeStatistics } else { $true }
        BaselineNames      = $baselineNames
      }
      
      $body = New-EmailBody @bodyParams
      
      # Convert HTML report to inline CSS for email compatibility
      Write-Log "Converting HTML report to email-compatible format (inline CSS)..."
      $emailOptimizedHtml = ConvertTo-InlineCssHtml -HtmlPath $ReportPath
      
      # Create temporary file with inlined CSS (similar name for clarity)
      $reportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
      $tempReportPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "$reportName-email.html")
      $emailOptimizedHtml | Out-File -FilePath $tempReportPath -Encoding UTF8
      Write-Log "Email-optimized report created: $tempReportPath"
      
      # Send email with retry logic using the email-optimized report
      $mailParams = @{
        To             = $recipients
        Subject        = $subject
        Body           = $body
        AttachmentPath = $tempReportPath  # Use email-optimized version
        MaxRetries     = 3
      }
      
      # Add optional CC recipients
      if ($TenantConfig.Email.Cc -and $TenantConfig.Email.Cc.Count -gt 0) {
        $mailParams.Cc = $TenantConfig.Email.Cc
        Write-Log "CC recipients: $($TenantConfig.Email.Cc -join ', ')"
      }
      
      # Add optional From address
      if ($TenantConfig.Email.From) {
        $mailParams.From = $TenantConfig.Email.From
        Write-Log "Sender: $($TenantConfig.Email.From)"
      }
      
      Send-GraphMail @mailParams
      
      # Cleanup temporary email-optimized report
      if (Test-Path $tempReportPath) {
        Remove-Item $tempReportPath -Force -ErrorAction SilentlyContinue
        Write-Log "Temporary email-optimized report cleaned up"
      }
      
      Write-Log "✅ Validation report delivered successfully via email"
    }
    catch {
      Write-Log -Level ERROR "Failed to send validation report via email: $($_.Exception.Message)"
      Write-Log -Level ERROR "Stack trace: $($_.ScriptStackTrace)"
      throw
    }
  }
}
