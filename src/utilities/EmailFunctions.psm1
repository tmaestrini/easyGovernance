<#
.SYNOPSIS
  Email utility functions for easyGovernance validation reports

.DESCRIPTION
  Provides helper functions for sending validation reports via Microsoft Graph Mail API.
  Includes permission checking, HTML body generation, and retry logic.

.NOTES
  Requires Microsoft Graph PowerShell SDK with Mail.Send permission
#>

Function Test-GraphMailPermission {
  <#
  .SYNOPSIS
    Validates if current Graph connection has Mail.Send permission
  
  .DESCRIPTION
    Checks the current Microsoft Graph context for required Mail.Send scope.
    Provides detailed guidance if permission is missing.
  
  .OUTPUTS
    Boolean - True if permission is granted, False otherwise
  
  .EXAMPLE
    Test-GraphMailPermission
  #>
  
  [CmdletBinding()]
  [OutputType([bool])]
  Param()
  
  try {
    $context = Get-MgContext
    if (!$context) {
      Write-Log -Level WARNING "No active Microsoft Graph connection"
      return $false
    }
    
    # Check if Mail.Send scope is granted
    $hasMailSend = $context.Scopes -contains "Mail.Send"
    
    if (!$hasMailSend) {
      Write-Log -Level WARNING @"
Missing Microsoft Graph permission: Mail.Send
Please grant this permission to send email reports.

For Azure Automation (Managed Identity):
  1. Go to Azure Portal → Automation Account → Identity
  2. Note the Object (principal) ID
  3. Go to Azure AD → Enterprise Applications
  4. Search for the Object ID
  5. API permissions → Add permission
  6. Microsoft Graph → Application permissions → Mail.Send
  7. Grant admin consent

For interactive use:
  Connect-MgGraph -Scopes "Mail.Send"
"@
    }
    
    return $hasMailSend
  }
  catch {
    Write-Log -Level ERROR "Failed to check Graph permissions: $_"
    return $false
  }
}

Function Test-GraphConnection {
  <#
  .SYNOPSIS
    Checks if Microsoft Graph connection is active
  
  .OUTPUTS
    Boolean - True if connected, False otherwise
  #>
  
  [CmdletBinding()]
  [OutputType([bool])]
  Param()
  
  try {
    $context = Get-MgContext
    return $null -ne $context
  }
  catch {
    return $false
  }
}

Function New-EmailBody {
  <#
  .SYNOPSIS
    Generates email body for validation report
  
  .DESCRIPTION
    Creates HTML or plain text email body with validation statistics
  
  .PARAMETER ReportStats
    Hashtable containing validation statistics (Total, Passed, Failed, Manual)
  
  .PARAMETER TenantName
    Name of the validated tenant
  
  .PARAMETER BodyStyle
    Email body style: 'Fancy' (HTML) or 'Plain' (Text)
  
  .PARAMETER IncludeStatistics
    Whether to include statistics in email body
  
  .PARAMETER BaselineNames
    Array of baseline names that were validated
  
  .OUTPUTS
    String - HTML or plain text email body
  
  .EXAMPLE
    New-EmailBody -ReportStats $stats -TenantName "contoso" -BodyStyle "Fancy"
  #>
  
  [CmdletBinding()]
  [OutputType([string])]
  Param(
    [Parameter(Mandatory=$true)]
    [hashtable]$ReportStats,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Fancy', 'Plain')]
    [string]$BodyStyle = 'Fancy',
    
    [Parameter(Mandatory=$false)]
    [bool]$IncludeStatistics = $true,
    
    [Parameter(Mandatory=$false)]
    [string[]]$BaselineNames = @()
  )
  
  $currentDate = Get-Date -Format "yyyy-MM-dd"
  $currentTime = Get-Date -Format "HH:mm"
  
  if ($BodyStyle -eq 'Plain') {
    # Plain text email body
    $body = @"
easyGovernance Validation Report

Tenant: $TenantName
Date: $currentDate $currentTime
Tested Baselines: $($BaselineNames.Count)

"@
    
    if ($IncludeStatistics) {
      $body += @"
Statistics:
✅ Passed: $($ReportStats.Passed)
❌ Failed: $($ReportStats.Failed)
⚠️ Manual Review: $($ReportStats.Manual)
Total Checks: $($ReportStats.Total)

"@
    }
    
    if ($BaselineNames.Count -gt 0) {
      $body += "Baselines:`n"
      foreach ($baseline in $BaselineNames) {
        $body += "  - $baseline`n"
      }
      $body += "`n"
    }
    
    $body += "Please find the detailed validation report attached to this email."
    
    return $body
  }
  else {
    # Fancy HTML email body
    $baselineListHtml = ""
    if ($BaselineNames.Count -gt 0) {
      $baselineListHtml = ($BaselineNames | ForEach-Object { "<li>$_</li>" }) -join "`n"
    }
    
    $statsHtml = ""
    if ($IncludeStatistics) {
      $statsHtml = @"
  <div class="stats">
    <div class="stat-box passed">
      <div class="stat-number">$($ReportStats.Passed)</div>
      <div class="stat-label">✅ Passed</div>
    </div>
    <div class="stat-box failed">
      <div class="stat-number">$($ReportStats.Failed)</div>
      <div class="stat-label">❌ Failed</div>
    </div>
    <div class="stat-box manual">
      <div class="stat-number">$($ReportStats.Manual)</div>
      <div class="stat-label">⚠️ Manual Review</div>
    </div>
  </div>
"@
    }
    
    $body = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
      color: #333;
      line-height: 1.6;
      margin: 0;
      padding: 0;
      background-color: #f4f4f4;
    }
    .container {
      max-width: 600px;
      margin: 20px auto;
      background: white;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 10px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 30px;
      text-align: center;
    }
    .header h1 {
      margin: 0 0 10px 0;
      font-size: 28px;
      font-weight: 600;
    }
    .header p {
      margin: 5px 0;
      font-size: 14px;
      opacity: 0.9;
    }
    .stats {
      display: flex;
      justify-content: space-around;
      padding: 30px 20px;
      background: #f8f9fa;
    }
    .stat-box {
      text-align: center;
      padding: 20px;
      border-radius: 8px;
      flex: 1;
      margin: 0 10px;
    }
    .passed {
      background: #d4edda;
      border: 2px solid #c3e6cb;
    }
    .passed .stat-number {
      color: #155724;
    }
    .failed {
      background: #f8d7da;
      border: 2px solid #f5c6cb;
    }
    .failed .stat-number {
      color: #721c24;
    }
    .manual {
      background: #fff3cd;
      border: 2px solid #ffeaa7;
    }
    .manual .stat-number {
      color: #856404;
    }
    .stat-number {
      font-size: 42px;
      font-weight: bold;
      margin: 0;
    }
    .stat-label {
      font-size: 14px;
      margin-top: 8px;
      font-weight: 500;
    }
    .content {
      padding: 30px;
    }
    .content h2 {
      color: #667eea;
      font-size: 20px;
      margin-top: 0;
    }
    .content p {
      margin: 10px 0;
    }
    .baseline-list {
      background: #f8f9fa;
      padding: 15px 20px;
      border-radius: 6px;
      margin: 15px 0;
    }
    .baseline-list ul {
      margin: 10px 0;
      padding-left: 20px;
    }
    .baseline-list li {
      margin: 5px 0;
      color: #495057;
    }
    .footer {
      background: #f8f9fa;
      padding: 20px;
      text-align: center;
      font-size: 12px;
      color: #6c757d;
      border-top: 1px solid #dee2e6;
    }
    .footer a {
      color: #667eea;
      text-decoration: none;
    }
    .footer a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header" style="background-color: #667eea; color: #ffffff; padding: 30px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0 0 10px 0; font-size: 28px;">🔐 easyGovernance Validation Report</h1>
      <p style="color: #ffffff; margin: 5px 0; font-size: 14px;"><strong style="color: #ffffff;">Tenant:</strong> <span style="color: #ffffff;">$TenantName</span></p>
      <p style="color: #ffffff; margin: 5px 0; font-size: 14px;"><strong style="color: #ffffff;">Date:</strong> <span style="color: #ffffff;">$currentDate at $currentTime</span></p>
    </div>
    
$statsHtml
    
    <div class="content">
      <h2>Summary</h2>
      <p>The validation report has been generated and is attached to this email as an HTML file.</p>
      
      <div class="baseline-list">
        <p><strong>Tested Baselines:</strong> $($BaselineNames.Count)</p>
        <ul>
$baselineListHtml
        </ul>
      </div>
      
      <p>Please review the attached report for detailed validation results and recommendations.</p>
    </div>
    
    <div class="footer">
      <p>Generated by <strong>easyGovernance</strong></p>
      <p><a href="https://github.com/tmaestrini/easyGovernance" target="_blank">View on GitHub</a></p>
    </div>
  </div>
</body>
</html>
"@
    
    return $body
  }
}

Function Send-GraphMail {
  <#
  .SYNOPSIS
    Sends an email via Microsoft Graph API with retry logic
  
  .DESCRIPTION
    Sends an email message with optional attachments using Microsoft Graph.
    Implements exponential backoff retry logic for transient failures.
  
  .PARAMETER To
    Array of recipient email addresses (required)
  
  .PARAMETER Cc
    Array of CC recipient email addresses (optional)
  
  .PARAMETER From
    Sender email address (optional, uses authenticated user if not specified)
  
  .PARAMETER Subject
    Email subject line
  
  .PARAMETER Body
    Email body content (HTML or plain text)
  
  .PARAMETER AttachmentPath
    Full path to file to attach
  
  .PARAMETER MaxRetries
    Maximum number of send attempts (default: 3)
  
  .EXAMPLE
    Send-GraphMail -To "admin@contoso.com" -Subject "Report" -Body "<html>...</html>" -AttachmentPath "report.html"
  #>
  
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory=$true)]
    [string[]]$To,
    
    [Parameter(Mandatory=$false)]
    [string[]]$Cc,
    
    [Parameter(Mandatory=$false)]
    [string]$From,
    
    [Parameter(Mandatory=$true)]
    [string]$Subject,
    
    [Parameter(Mandatory=$true)]
    [string]$Body,
    
    [Parameter(Mandatory=$false)]
    [string]$AttachmentPath,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxRetries = 3
  )
  
  $attempt = 0
  $success = $false
  $lastError = $null
  
  while (!$success -and $attempt -lt $MaxRetries) {
    $attempt++
    
    try {
      Write-Log "Sending email (attempt $attempt/$MaxRetries)..."
      
      # Compose message
      $message = @{
        subject = $Subject
        body = @{
          contentType = "HTML"
          content = $Body
        }
        toRecipients = @($To | ForEach-Object { 
          @{ emailAddress = @{ address = $_ } } 
        })
      }
      
      # Add CC recipients if specified
      if ($Cc -and $Cc.Count -gt 0) {
        $message.ccRecipients = @($Cc | ForEach-Object { 
          @{ emailAddress = @{ address = $_ } } 
        })
      }
      
      # Add attachment if specified
      if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
        $attachmentBytes = [System.IO.File]::ReadAllBytes($AttachmentPath)
        $attachmentBase64 = [Convert]::ToBase64String($attachmentBytes)
        $attachmentName = Split-Path $AttachmentPath -Leaf
        
        $message.attachments = @(
          @{
            "@odata.type" = "#microsoft.graph.fileAttachment"
            name = $attachmentName
            contentType = "text/html"
            contentBytes = $attachmentBase64
          }
        )
      }
      
      # Determine sender
      if ($From) {
        # Send from specific mailbox (requires additional permissions)
        Send-MgUserMail -UserId $From -Message $message -ErrorAction Stop
        Write-Log "Email sent from: $From"
      } else {
        # Send as authenticated user
        $context = Get-MgContext
        if ($context -and $context.Account) {
          $userId = $context.Account
          Send-MgUserMail -UserId $userId -Message $message -ErrorAction Stop
          Write-Log "Email sent from authenticated user: $userId"
        } else {
          throw "No authenticated user context found. Please connect to Microsoft Graph first."
        }
      }
      
      $success = $true
      Write-Log "✅ Email sent successfully to: $($To -join ', ')"
    }
    catch {
      $lastError = $_
      $waitSeconds = [math]::Pow(2, $attempt)  # 2, 4, 8 seconds exponential backoff
      
      if ($attempt -lt $MaxRetries) {
        Write-Log -Level WARNING "Email send failed (attempt $attempt): $($_.Exception.Message)"
        Write-Log "Retrying in $waitSeconds seconds..."
        Start-Sleep -Seconds $waitSeconds
      }
    }
  }
  
  if (!$success) {
    throw "Failed to send email after $MaxRetries attempts. Last error: $lastError"
  }
}

Function ConvertTo-InlineCssHtml {
  <#
  .SYNOPSIS
    Converts HTML with external CSS to inline CSS for email compatibility
  
  .DESCRIPTION
    Reads external CSS files referenced in HTML and inlines them into <style> tags.
    This is necessary because email clients don't support external CSS files.
  
  .PARAMETER HtmlPath
    Full path to the HTML file to convert
  
  .OUTPUTS
    String - HTML content with inlined CSS
  
  .EXAMPLE
    ConvertTo-InlineCssHtml -HtmlPath "report.html"
  #>
  
  [CmdletBinding()]
  [OutputType([string])]
  Param(
    [Parameter(Mandatory=$true)]
    [string]$HtmlPath
  )
  
  try {
    if (!(Test-Path $HtmlPath)) {
      throw "HTML file not found: $HtmlPath"
    }
    
    $htmlContent = Get-Content $HtmlPath -Raw
    $htmlDir = Split-Path $HtmlPath -Parent
    
    # Find all external CSS references
    $cssPattern = '<link\s+rel="stylesheet"\s+href="([^"]+)"[^>]*>'
    $cssMatches = [regex]::Matches($htmlContent, $cssPattern)
    
    if ($cssMatches.Count -eq 0) {
      Write-Log "No external CSS references found, returning original HTML"
      return $htmlContent
    }
    
    Write-Log "Found $($cssMatches.Count) external CSS reference(s), inlining..."
    
    # Collect all CSS content
    $allCss = ""
    foreach ($match in $cssMatches) {
      $cssHref = $match.Groups[1].Value
      
      # Resolve relative path
      $cssPath = if ([System.IO.Path]::IsPathRooted($cssHref)) {
        $cssHref
      } else {
        # Handle relative paths like "./styles/report.css"
        $cssHref = $cssHref -replace '^\./', ''
        Join-Path $htmlDir $cssHref
      }
      
      if (Test-Path $cssPath) {
        Write-Log "Reading CSS from: $cssPath"
        $cssContent = Get-Content $cssPath -Raw
        $allCss += "`n$cssContent`n"
      } else {
        Write-Log -Level WARNING "CSS file not found: $cssPath"
      }
    }
    
    # Remove all external CSS links
    $htmlContent = [regex]::Replace($htmlContent, $cssPattern, '')
    
    # Insert inline CSS in <head>
    if ($allCss -ne "") {
      $styleTag = "<style>`n$allCss`n</style>"
      
      if ($htmlContent -match '</head>') {
        # Insert before </head>
        $htmlContent = $htmlContent -replace '</head>', "$styleTag`n</head>"
      } else {
        # No </head> found, insert at beginning
        $htmlContent = "$styleTag`n$htmlContent"
      }
      
      Write-Log "✅ CSS successfully inlined into HTML"
    }
    
    return $htmlContent
  }
  catch {
    Write-Log -Level ERROR "Failed to inline CSS: $($_.Exception.Message)"
    # Return original content as fallback
    return Get-Content $HtmlPath -Raw
  }
}

# Export functions
Export-ModuleMember -Function Test-GraphMailPermission, Test-GraphConnection, New-EmailBody, Send-GraphMail, ConvertTo-InlineCssHtml
