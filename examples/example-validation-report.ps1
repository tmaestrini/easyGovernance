# Validate a given tenant from settings file
Import-Module .\src\Validation.psm1 -Force
$result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject

# Generate a report in directory ./output (optionally as HTML)
New-Report -ValidationResults $result -AsHTML
