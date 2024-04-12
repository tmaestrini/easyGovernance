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
      [Parameter()][switch]$AsHTML
   )
   
   Begin {
      $currentTimeStamp = Get-Date
      $reportPath = (Join-Path $PSScriptRoot -ChildPath '../../../output')
      $reportTemplate = Get-Content (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template.md') -Raw
      $reportAtts = [PSCustomObject]@{
         Title  = "Tenant Validation Report"
         Tenant = $ValidationResults.Tenant
         Date   = $currentTimeStamp.ToString("dd.MM.yyyy HH:mm")
         Issuer = [Environment]::UserName
      }

      $reportStatistics = @{ Total = 0; Passed = 0; Failed = 0; Manual = 0 }
      Function Set-ReportStatistics($resultSet) {
         $reportStatistics.Total += $resultSet.Statistics.Total
         $reportStatistics.Passed += $resultSet.Statistics.Passed
         $reportStatistics.Failed += $resultSet.Statistics.Failed
         $reportStatistics.Manual += $resultSet.Statistics.Manual
      }

      Function Add-MainContent($resultSet) {
         $content = @()
         $content += "`n## ► Baseline ``$($resultSet.Baseline)``"
         $content += "### Report Validation statistics"
         $content += "![total](https://img.shields.io/badge/Checks%20total-$($resultSet.Statistics.Total)-blue.svg?style=flat-square)"
         $content += "![passed](https://img.shields.io/badge/✔%20Checks%20passed-$($resultSet.Statistics.Passed)-green.svg?style=flat-square)"
         $content += "![failed](https://img.shields.io/badge/✘%20Checks%20failed-$($resultSet.Statistics.Failed)-red.svg?style=flat-square)"
         $content += "![check](https://img.shields.io/badge/Manual%20check%20needed-$($resultSet.Statistics.Manual)-yellow.svg?style=flat-square)`n"

         $content += "### Report Details"
         # $table = $resultSet.Result | Select-Object @{Name = "Topic (Group)"; Expression = { $_.Group } }, Setting, Result, Reference
         $table = $resultSet.Result | Select-Object @{Name = "Topic (Group)"; Expression = { $_.Group } }, `
         @{Name = "Setting"; Expression = { $_.Reference ? "$($_.Setting)<br>👉 $($_.Reference)" : $_.Setting } }, Result

         if (!$AsHTML.IsPresent) { 
            $table = $table | New-MDTable -Shrink
            $table = $table -replace "✔︎", "![passed](https://img.shields.io/badge/PASS-✔︎-green.svg?style=flat-square)"
            $table = $table -replace "✘", "![failed](https://img.shields.io/badge/FAIL-✘-red.svg?style=flat-square)"
            # $table = $table -replace "\?", "<img style='vertical-align: middle' src='https://img.shields.io/badge/CHECK-MANUALLY-yellow.svg?style=flat-square'\>"
         }
         else { 
            $table = $table | ConvertTo-Html -Fragment
            $table = $table -replace "&lt;br&gt;", "<br>"
            $table = $table -replace "<table>", "<table class='reportDetails'>"
            $table = $table -replace "✔︎", "<img style='vertical-align: middle' src='https://img.shields.io/badge/PASS-✔︎-green.svg?style=flat-square'\>"
            $table = $table -replace "✘", "<img style='vertical-align: middle' src='https://img.shields.io/badge/FAIL-✘-red.svg?style=flat-square'\>"
            $table = $table -replace "---", "<img style='vertical-align: middle' src='https://img.shields.io/badge/CHECK-MANUALLY-yellow.svg?style=flat-square'\>"
         }

         $content += $table
         return $content
      }

      Function Add-SummaryContent() {
         $passedQuota = [double] $($reportStatistics.Passed) / $($reportStatistics.Total)
         $content = @()
         $content += "## Report Summary"
         $content += "The validation report contains **$([math]::Round($passedQuota * 100, 1))% successful checks**:`n"
         $content += "![total](https://img.shields.io/badge/Checks%20total-$($reportStatistics.Total)-blue.svg?style=flat-square) "
         $content += "![passed](https://img.shields.io/badge/✔%20Checks%20passed-$($reportStatistics.Passed)-green.svg?style=flat-square) "
         $content += "![failed](https://img.shields.io/badge/✘%20Checks%20failed-$($reportStatistics.Failed)-red.svg?style=flat-square) "
         $content += "![failed](https://img.shields.io/badge/Manual%20check%20needed-$($reportStatistics.Manual)-yellow.svg?style=flat-square)`n"
         $content += "**$($ValidationResults.Validation.Length) baseline(s)** have been validated against the tenant.`n"
         return $content
      }
   }
   Process {
      $summaryContent = @()
      $mainContent = @()

      # generate content
      foreach ($resultSet in $ValidationResults.Validation) {
         Set-ReportStatistics $resultSet
         $mainContent += Add-MainContent $resultSet
      }
      $summaryContent += Add-SummaryContent
      
      # generate report
      $reportTemplate = $reportTemplate -replace '%{Title}', $reportAtts.Title -replace '%{Date}', $reportAtts.Date -replace '%{Issuer}', $reportAtts.Issuer `
         -replace '%{Tenant}', $reportAtts.Tenant
      $reportTemplate = $reportTemplate -replace '%{Summary}', ($summaryContent -join "`n")
      $reportTemplate = $reportTemplate -replace '%{Content}', ($mainContent -join "`n")
   }
   End {
      # save report as Markdown
      [System.IO.Directory]::CreateDirectory($reportPath) # ensure directory exists
      $reportFilePath = "$($reportPath)/$($ValidationResults.Tenant)-$($currentTimeStamp.toString("yyyyMMddHHmm")) report.md"
      $reportTemplate > $reportFilePath
      Write-Log -Level INFO -Message "Markdown report created: $($reportFilePath)"
      
      # convert report to HTML
      if ($AsHTML.IsPresent ) {
         $htmlOutput = Convert-MarkdownToHTML $reportFilePath -SiteDirectory $reportPath
         Copy-Item -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-styles.css') -Destination "$reportPath/styles/md-styles.css"
         Write-Log -Level INFO -Message "HTML report created: $($htmlOutput)"
      }
   }
}