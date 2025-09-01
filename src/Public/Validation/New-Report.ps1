<#
.Synopsis
.DESCRIPTION
   Generates a report from validation results in Markdown format ().md)
.EXAMPLE
   New-Report
#>

Function New-Report {
   [CmdletBinding()]
   [OutputType([void])]

   Param
   (
      [Parameter(
         Mandatory = $true,
         HelpMessage = "Full name of the template, including .yml (aka <name>.yml)"
      )][hashtable]$ValidationResults,
      [Parameter()][switch]$AsHTML,
      [Parameter()][switch]$AsCSV,
      [Parameter()][switch]$AsJSON
   )
   
   Begin {
      $currentTimeStamp = Get-Date
      $reportPath = (Join-Path $PSScriptRoot -ChildPath '../../../output')
      $reportAtts = [PSCustomObject]@{
         Title  = "Tenant Validation Report"
         Tenant = $ValidationResults.Tenant
         Date   = $currentTimeStamp.ToString("dd.MM.yyyy HH:mm")
         Issuer = [Environment]::UserName
      }

      $reportStatistics = @{ Total = 0; Passed = 0; Failed = 0; Manual = 0 }
      $reportResultsPlain = [ordered]@{ Report = $reportAtts; Results = @() };

      Function Set-ReportStatistics($resultSet) {
         $reportStatistics.Total = $reportStatistics.Total + $resultSet.Statistics.stats.Total
         $reportStatistics.Passed = $reportStatistics.Passed + $resultSet.Statistics.stats.Passed
         $reportStatistics.Failed = $reportStatistics.Failed + $resultSet.Statistics.stats.Failed
         $reportStatistics.Manual = $reportStatistics.Manual + $resultSet.Statistics.stats.Manual
      }

      Function Add-MainContent([PSCustomObject]$resultSet, [PSCustomObject]$baseline) {
         $content = @()
         $content += "`n## ▶︎ $($baseline.Topic) [Baseline ``$($resultSet.Baseline)``, Version $($resultSet.Version)]"
         
         $content += "### Report Validation statistics"
         $content += "`n![total](https://img.shields.io/badge/Checks%20total-$($resultSet.Statistics.stats.Total)-blue.svg?style=flat-square)"
         $content += "![failed](https://img.shields.io/badge/✘%20Checks%20failed-$($resultSet.Statistics.stats.Failed)-red.svg?style=flat-square)"
         $content += "![passed](https://img.shields.io/badge/✔%20Checks%20passed-$($resultSet.Statistics.stats.Passed)-green.svg?style=flat-square)"
         $content += "![check](https://img.shields.io/badge/Manual%20check%20needed-$($resultSet.Statistics.stats.Manual)-yellow.svg?style=flat-square)`n"

         $content += "### Baseline Reference(s)`n"
         $content += $baseline.References | ForEach-Object { "- [$($_)]($($_))" } 
         $content += "`n"

         $content += "### Report Details"
         $table = $resultSet.Result | Select-Object @{Name = "Topic (Group)"; Expression = { $_.Group } }, `
         @{Name = "Setting"; Expression = { $_.ReferenceHint ? "$($_.Setting)<br>👉 $($_.ReferenceHint)" : $_.Setting } }, Result

         $table = $table | ConvertTo-Html -Fragment
         $table = $table -replace "&lt;br&gt;", "<br>"
         $table = $table -replace "<table>", "<table class='reportDetails'>"
         $table = $table -replace "✔︎", "<img style='vertical-align: middle' src='https://img.shields.io/badge/PASS-✔︎-green.svg?style=flat-square'\>"
         $table = $table -replace "✘", "<img style='vertical-align: middle' src='https://img.shields.io/badge/FAIL-✘-red.svg?style=flat-square'\>"
         $table = $table -replace "---", "<img style='vertical-align: middle' src='https://img.shields.io/badge/CHECK-MANUALLY-yellow.svg?style=flat-square'\>"

         $content += $table
         return $content
      }

      Function Add-HTMLMainContent([PSCustomObject]$resultSet, [PSCustomObject]$baseline) {

         Function Get-Status() {
            param($status)

            if ($status -like "✔︎*") { return "🟢 PASS" }
            elseif ($status -like "✘*") { return "🔴 FAIL" }
            else { return "🟡 CHECK" }
         }

         $htmlTemplate = Get-Content (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template-baseline.html') -Raw

         $referenceContent = "<ul>"
         $referenceContent += $baseline.References | ForEach-Object { "`n`t<li><a href=`"$($_)`" target=""_blank"" rel=""noopener noreferer"">$($_)</a>" } 
         $referenceContent += "</ul>"
         
         $tableData = $resultSet.Result | Select-Object `
         @{Name = "Topic (Group)"; Expression = { $_.Group } }, `
         @{Name = "Setting"; Expression = { $_.ReferenceHint ? "$($_.Setting)<br><small>👉 $($_.ReferenceHint)</small>" : $_.Setting } }, `
         @{Name = "Status"; Expression = { Get-Status $_.Result } }, `
            Result

         # Convert the table data to HTML and format it         
         $table = $tableData | ConvertTo-Html -Fragment
         $table = $table -replace "&lt;(/?(?:br|small|strong|em|pre|code|span))&gt;", "<`$1>"
         $table = $table -replace "&#39;", "'"
         $table = $table -replace "&apos;", "'"
         $table = $table -replace "'(?![s\s])([^']+)'", '<code>$1</code>'
         $table = $table -replace "<table>", "<table class=""report-details"">"
         $table = $table -replace "(✔︎|✘|---)\s", ""

         # Create content based on the template
         $binding = @{
            baseline            = $baseline.Topic
            baselineId          = $resultSet.Baseline
            baselineVersion     = $baseline.Version
            baseline_references = $referenceContent
            
            count_checks        = $resultSet.Statistics.stats.Total
            count_checks_passed = $resultSet.Statistics.stats.Passed
            count_checks_failed = $resultSet.Statistics.stats.Failed
            count_checks_needed = $resultSet.Statistics.stats.Manual
            
            report_details      = $table
         }

         $content = Invoke-EpsTemplate -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template-baseline.html') -Binding $binding -Safe
         return $content
      }

      Function Add-SummaryContent() {
         $passedQuota = [double] $($reportStatistics.Passed) / $($reportStatistics.Total)
         $content = @()
         $content += "This validation report contains **$([math]::Round($passedQuota * 100, 1))% successful checks**:`n"
         $content += "![total](https://img.shields.io/badge/Checks%20total-$($reportStatistics.Total)-blue.svg?style=flat-square) "
         $content += "![passed](https://img.shields.io/badge/✔%20Checks%20passed-$($reportStatistics.Passed)-green.svg?style=flat-square) "
         $content += "![failed](https://img.shields.io/badge/✘%20Checks%20failed-$($reportStatistics.Failed)-red.svg?style=flat-square) "
         $content += "![failed](https://img.shields.io/badge/Manual%20check%20needed-$($reportStatistics.Manual)-yellow.svg?style=flat-square)`n"
         $content += "**$($ValidationResults.Validation.Length) baseline(s)** have been validated against the tenant.`n"
         return $content
      }

      Function Add-HTMLSummaryContent() {
         $htmlTemplate = Get-Content (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template-stats.html') -Raw

         $content = $htmlTemplate -join "`n"
         $content = $content -replace '%{count_checks}', $reportStatistics.Total
         $content = $content -replace '%{tcount_checks_passed}', $reportStatistics.Passed
         $content = $content -replace '%{tcount_checks_failed}', $reportStatistics.Failed
         $content = $content -replace '%{tcount_checks_manual}', $reportStatistics.Manual
         
         $content = $content -replace '%{total_quote_checks_passed}', [decimal] [math]::Round(($reportStatistics.Passed / $reportStatistics.Total) * 100, 1)
         $content = $content -replace '%{total_quote_checks_failed}', [decimal] [math]::Round(($reportStatistics.Failed / $reportStatistics.Total) * 100, 1)
         $content = $content -replace '%{total_quote_checks_manual}', [decimal] [math]::Round(($reportStatistics.Manual / $reportStatistics.Total) * 100, 1)

         # Create content based on the template
         $binding = @{
            count_checks              = $reportStatistics.Total
            count_checks_passed       = $reportStatistics.Passed
            count_checks_failed       = $reportStatistics.Failed
            count_checks_manual       = $reportStatistics.Manual

            total_quote_checks_passed = [decimal] [math]::Round(($reportStatistics.Passed / $reportStatistics.Total) * 100, 1)
            total_quote_checks_failed = [decimal] [math]::Round(($reportStatistics.Failed / $reportStatistics.Total) * 100, 1)
            total_quote_checks_manual = [decimal] [math]::Round(($reportStatistics.Manual / $reportStatistics.Total) * 100, 1)
         }

         $content = Invoke-EpsTemplate -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template-stats.html') -Binding $binding -Safe
         return $content
      }

      Function New-MdReport() {
         $summaryContent = @()
         $mainContent = @()

         $reportTemplate = Get-Content (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template.md') -Raw
         # generate content
         foreach ($resultSet in $ValidationResults.Validation) {
            $baseline = Get-BaselineTemplate -BaselineId $resultSet.Baseline
            Set-ReportStatistics $resultSet
            $mainContent += Add-MainContent $resultSet -baseline $baseline
         }
         $summaryContent += Add-SummaryContent
      
         # generate report
         $output = $reportTemplate -replace '%{Title}', $reportAtts.Title -replace '%{Date}', $reportAtts.Date -replace '%{Issuer}', $reportAtts.Issuer `
            -replace '%{Tenant}', $reportAtts.Tenant
         $output = $output -replace '%{Summary}', ($summaryContent -join "`n")
         $output = $output -replace '%{Content}', ($mainContent -join "`n")

         return $output
      }

      Function New-HtmlReport() {
         
         foreach ($resultSet in $ValidationResults.Validation) {
            $baseline = Get-BaselineTemplate -BaselineId $resultSet.baseline
            $contentFragment = (Add-HTMLMainContent $resultSet -baseline $baseline)
            $mainContent += $contentFragment
         }

         $summaryContent += Add-HTMLSummaryContent 
         
         # Create content based on the template
         $binding = @{
            result_details = $mainContent
            summary_stats  = $summaryContent

            Date_generated = $reportAtts.Date
            Issuer         = $reportAtts.Issuer
            Tenant         = $reportAtts.Tenant
            Title          = $reportAtts.Title
         }
         
         $content = Invoke-EpsTemplate -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template.html') -Binding $binding -Safe
         return $content
      }
   }
   Process {
      $mdOutput = New-MdReport
      
      if ($AsHTML.IsPresent ) {
         $htmlReportOutput = New-HtmlReport
      }
   }
   End {
      # save report as Markdown
      [System.IO.Directory]::CreateDirectory($reportPath) # ensure directory exists
      $reportFilePath = "$($reportPath)/$($ValidationResults.Tenant)-$($currentTimeStamp.toString("yyyyMMddHHmm")) report"
      $mdOutput > "$reportFilePath.md"
      Write-Log -Level INFO -Message "Markdown report created: $($reportFilePath).md"
      
      # convert reports
      if ($AsHTML.IsPresent ) {
         [System.IO.Directory]::CreateDirectory("$reportPath/styles/") # ensure directory exists

         # Create a stylesheet for the HTML report
         Copy-Item -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-template-styles.css') -Destination "$reportPath/styles/report.css"

         $htmlReportOutput > "$($reportFilePath).html"
         Write-Log -Level INFO -Message "HTML report ready: $($reportFilePath).html"
      }
      
      if ($AsCSV.IsPresent) {
         Write-Log -Level INFO -Message "Creating CSV report"
         $reportResultsPlain.Results = $ValidationResults.Validation | ForEach-Object {
            $resultSet = $_
            $data = $resultSet.Result | Select-Object *, `
            @{ Name = 'Baseline'; Expression = { $resultSet.Baseline } }, `
            @{ Name = 'Version'; Expression = { $resultSet.Version } }
            return $data
         } 
      
         $fileOutputPath = "$reportFilePath.csv"
         $reportResultsPlain.Results | Export-Csv -Path $fileOutputPath -Encoding UTF8 -Delimiter ';'
         Write-Log -Level INFO -Message "CSV report created: $($fileOutputPath)"
      }

      if ($AsJSON.IsPresent) {
         Write-Log -Level INFO -Message "Creating JSON report"
         $reportResultsPlain.Results = $ValidationResults.Validation | ForEach-Object {
            return [ordered]@{
               Baseline   = $_.Baseline
               Version    = $_.Version
               Statistics = $_.Statistics.stats
               Result     = $_.Result
            }
         } 
      
         $fileOutputPath = "$reportFilePath.json"
         $reportResultsPlain | ConvertTo-Json -Depth 10 | Out-File -FilePath $fileOutputPath
         Write-Log -Level INFO -Message "JSON report created: $($fileOutputPath)"
      }
   }
}