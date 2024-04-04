<#
.Synopsis
.DESCRIPTION
   Generates a report from validation results in Markdown format ().md)
.EXAMPLE
   New-Report
#>

function New-Report {
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
   }
   Process {
      # generate content
      $content = @()
      foreach ($resultSet in $ValidationResults.Validation) {
         $content += "`n## ► Baseline ``$($resultSet.Baseline)``"
         
         $content += "### Report Validation statistics"
         $content += "![total](https://img.shields.io/badge/Checks%20total-$($resultSet.Statistics.Total)-blue.svg?style=flat-square) "
         $content += "![passed](https://img.shields.io/badge/✔%20Checks%20passed-$($resultSet.Statistics.Passed)-green.svg?style=flat-square) "
         $content += "![failed](https://img.shields.io/badge/✘%20Checks%20failed-$($resultSet.Statistics.Failed)-red.svg?style=flat-square) "
         $content += "![failed](https://img.shields.io/badge/Manual%20check%20needed-$($resultSet.Statistics.Manual)-yellow.svg?style=flat-square)`n`n"
         
         $content += "### Report Details"
         $table = $resultSet.Result | Select-Object @{Name = "Topic (Group)"; Expression = { $_.Group } }, Setting, Result, Reference | ConvertTo-Html -Fragment
         $table = $table -replace "✔︎", "<img style='vertical-align: middle' src='https://img.shields.io/badge/PASS-✔︎-green.svg?style=flat-square'\>  "
         $table = $table -replace "✘", "<img style='vertical-align: middle' src='https://img.shields.io/badge/FAIL-✘-red.svg?style=flat-square'\>"
         $table = $table -replace "---", "<img style='vertical-align: middle' src='https://img.shields.io/badge/CHECK-MANUAL%20CHECK-yellow.svg?style=flat-square'\>"

         $content += $table
      }

      # generate report
      $reportTemplate = $reportTemplate -replace '%{Title}', $reportAtts.Title -replace '%{Date}', $reportAtts.Date -replace '%{Issuer}', $reportAtts.Issuer `
         -replace '%{Tenant}', $reportAtts.Tenant
      $reportTemplate = $reportTemplate -replace '%{Content}', ($content -join "`n")
   }
   End {
      # save report as Markdown
      [System.IO.Directory]::CreateDirectory($reportPath) # ensure directory exists
      $reportFilePath = "$($reportPath)/$($currentTimeStamp.toString("yyyyMMddHHmm"))-Report.md"
      $reportTemplate > $reportFilePath
      Write-Log -Level INFO -Message "Markdown report created: $($reportFilePath)"
      
      # convert report to HTML
      if ($AsHTML.IsPresent ) {
         $htmlOutput = Convert-MarkdownToHTML $reportFilePath -SiteDirectory $reportPath
         Copy-Item -Path (Join-Path $PSScriptRoot -ChildPath '../../../assets/Report-styles.css') -Destination "$reportPath/styles/md-styles.css"
         Write-Log -Level INFO -Message "HTML report created: $($htmlOutput)"
      }
   }}