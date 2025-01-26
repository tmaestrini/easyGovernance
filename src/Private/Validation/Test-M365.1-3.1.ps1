using module .\Class\BaselineValidator.psm1

<#
.Synopsis
.DESCRIPTION
.EXAMPLE
   Test-M365.1-3.1
#>

Function Test-M365.1-3.1 {
  [CmdletBinding()]
  [Alias()]
  [OutputType([hashtable])]
  
  Param
  (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The baseline itself"
    )][PSCustomObject]$Baseline,
    [Parameter(
      Mandatory = $true,
      HelpMessage = "The id of the tenant (https://[tenantId].sharepoint.com)"
    )][string] $tenantId,
    [Parameter(
      Mandatory = $false
    )][switch] $ReturnAsObject
  )
 
  Begin {
    class PPLSettingsValidator : BaselineValidator {
      PPLSettingsValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) : base($Baseline, $TenantId, $ReturnAsObject) {}
      
      Connect() {}

      [PSCustomObject] Extract() {        

        function Get-EnvironmentSettings() {
          $tenantSettings = Request-PPLSettings -Properties DefaultEnvironment, Tenant

          $defaultEnvironment = [PSCustomObject] @{
            Id         = $tenantSettings.DefaultEnvironment.name ?? $null;
            Name       = $tenantSettings.DefaultEnvironment.properties.displayName ?? $null;
            Monitoring = "n/a"
          }

          $developmentEnvironments = [PSCustomObject] @{
            DisableEnvironmentCreationByNonAdminUsers = $tenantSettings.Tenant.powerPlatform.governance.disableDeveloperEnvironmentCreationByNonAdminUsers ?? $null;
            Monitoring                                = "n/a"
          }

          $trialEnvironments = [PSCustomObject] @{
            DisableEnvironmentCreationByNonAdminUsers = $tenantSettings.Tenant.disableTrialEnvironmentCreationByNonAdminUsers ?? $null;
            Monitoring                                = "n/a"
          }
          
          $productionEnvironments = [PSCustomObject] @{
            DisableEnvironmentCreationByNonAdminUsers = $tenantSettings.Tenant.disableEnvironmentCreationByNonAdminUsers ?? $null;
            Monitoring                                = "n/a"
          }
         
          $this.extractedParamsFromService | Add-Member -MemberType NoteProperty -Name Environments -Value @{
            DefaultEnvironment      = $defaultEnvironment;
            DevelopmentEnvironments = $developmentEnvironments;
            TrialEnvironments       = $trialEnvironments;
            ProductionEnvironments  = $productionEnvironments
          }
        }
        
        function Get-DataPoliciesSettings() {
          $policySettings = Request-PPLDataPoliciesSettings -Properties DefaultEnvironment, NonDefaultEnvironments `
            -DefaultEnvironmentId $this.extractedParamsFromService.Environments.DefaultEnvironment.Id

          # Default environment
          $confidentialConnectors = $policySettings.DefaultEnvironment.connectorGroups | Where-Object { $_.classification -eq "Confidential" } | Select-Object -ExpandProperty connectors
          $allowedConnectors = @("Approvals", "SharePoint", "Microsoft To-Do (Business)")
          $missingConnectors = $allowedConnectors | Where-Object {
            $allowedName = $_
            -not ($confidentialConnectors | Where-Object { $_.name -eq $allowedName })
          }
          
          $defaultEnvironment = [PSCustomObject] @{
            PolicyName        = $policySettings.DefaultEnvironment.displayName ?? "dedicated policy not found";
            PolicySettings    = $policySettings.DefaultEnvironment ?? $null
            AllowedConnectors = $allowedConnectors;
            MissingConnectors = $missingConnectors;
          }

          # Non-default environments
          $nonDefaultEnvironments = [PSCustomObject] @{
            PolicySettings = $policySettings.NonDefaultEnvironments
          }

          # return data
          $this.extractedParamsFromService | Add-Member -MemberType NoteProperty -Name DataPolicies -Value @{
            DefaultEnvironment     = $defaultEnvironment;
            NonDefaultEnvironments = $nonDefaultEnvironments
          }
        }
        
        function Get-SecuritySettings() {
          $securitySettings = Request-PPLSecuritySettings -Properties TenantIsolation, ContentSecurityPolicy
          
          $this.extractedParamsFromService | Add-Member -MemberType NoteProperty -Name SecuritySettings -Value @{
            TenantIsolation       = $securitySettings.TenantIsolation.properties ?? $null;
            ContentSecurityPolicy = $securitySettings.ContentSecurityPolicy ?? $null
          }
        }
        
        Get-EnvironmentSettings
        Get-DataPoliciesSettings
        Get-SecuritySettings

        return $this.extractedParamsFromService
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}

        # Environments
        $settings.DefaultEnvironment = $extractedSettings.Environments.DefaultEnvironment;
        $settings.ProductionEnvironments = $extractedSettings.Environments.ProductionEnvironments
        return $settings
      }
    }
  }
  Process {
    try {
      $validator = [PPLSettingsValidator]::new($Baseline, $tenantId, $ReturnAsObject)
      $validator.StartValidation()
      $result = $validator.GetValidationResult()
      
      if ($returnAsObject) {
        return $result
      }
    }
    catch {
      throw $_
    }
  }
}