# Provision a given tenant from settings file
Import-Module .\src\Provisioning.psm1 -Force
Start-Provisioning -TemplateName "[tenantname].yml"