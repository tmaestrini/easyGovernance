# Validate a given tenant from settings file by running in unattended mode (in an automation scenario)
Import-Module .\src\Validation.psm1 -Force

# prepare unattended mode with your credentials to login as administrator
# 👉 Do not store credentials directly in this file; use a vault / credentials manager or ENV variables instead.
$username = "admin@[yourtenant].onmicrosoft.com"
$password = ConvertTo-SecureString "[password]" -AsPlainText -Force
$AzureSubscriptionId = "[Azure Subscription Id]"

Set-UnattendedRun -username $username -password $password

# start validation
# 👉 Make sure you always provide an Azure Subscription id
Start-Validation -TemplateName "tmaestrini.yml" -AzureSubscriptionId $AzureSubscriptionId > output.md