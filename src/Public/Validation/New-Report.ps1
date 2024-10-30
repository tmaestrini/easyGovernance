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
      $reportTemplate = Get-Content (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-Template.md') -Raw
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
         $content += "`n## ► $($baseline.Topic) [Baseline ``$($resultSet.Baseline)``, Version $($resultSet.Version)]"
         $content += "### Report Validation statistics"
         $content += "![total](https://img.shields.io/badge/Checks%20total-$($resultSet.Statistics.stats.Total)-blue.svg?style=flat-square)"
         $content += "![passed](https://img.shields.io/badge/✔%20Checks%20passed-$($resultSet.Statistics.stats.Passed)-green.svg?style=flat-square)"
         $content += "![failed](https://img.shields.io/badge/✘%20Checks%20failed-$($resultSet.Statistics.stats.Failed)-red.svg?style=flat-square)"
         $content += "![check](https://img.shields.io/badge/Manual%20check%20needed-$($resultSet.Statistics.stats.Manual)-yellow.svg?style=flat-square)`n"

         $content += "### Baseline Reference(s)"
         $content += $baseline.References | ForEach-Object { "- [$($_)]($($_))" } 
         $content += "`n"

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
         $content += "This validation report contains **$([math]::Round($passedQuota * 100, 1))% successful checks**:`n"
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
         $baseline = Get-BaselineTemplate -BaselineId $resultSet.Baseline
         Set-ReportStatistics $resultSet
         $mainContent += Add-MainContent $resultSet -baseline $baseline
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
      $reportFilePath = "$($reportPath)/$($ValidationResults.Tenant)-$($currentTimeStamp.toString("yyyyMMddHHmm")) report"
      $reportTemplate > "$reportFilePath.md"
      Write-Log -Level INFO -Message "Markdown report created: $($reportFilePath).md"
      
      # convert reports
      if ($AsHTML.IsPresent ) {
         $htmlOutput = Convert-MarkdownToHTML "$reportFilePath.md" -SiteDirectory $reportPath
         Copy-Item -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-styles.css') -Destination "$reportPath/styles/md-styles.css"
         Write-Log -Level INFO -Message "HTML report created: $($htmlOutput)"
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