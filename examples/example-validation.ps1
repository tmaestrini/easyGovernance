# Validate a given tenant from settings file
Import-Module .\src\Validation.psm1 -Force
Start-Validation -TemplateName "[tenantname].yml"