# Validate a given tenant from settings file and store the result in a variable
Import-Module .\src\Validation.psm1 -Force
$result = Start-Validation -TemplateName "[tenantname].yml" -ReturnAsObject