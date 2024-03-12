# Validate a given tenant from settings file
Import-Module .\src\Validation.psm1 -Force
Start-Validation -TemplateName "tmaestrini.yml"
$test = Start-Validation -TemplateName "tmaestrini.yml" -ReturnAsObject
