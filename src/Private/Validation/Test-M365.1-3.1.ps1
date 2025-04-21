# Use full path for module import to improve class resolution
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
        Write-Log -Level INFO "Extracting PowerPlatform settings from tenant $($this.ValidationSettings.TenantId)"
        
        function Get-EnvironmentSettings() {
          Write-Log -Level INFO "Extracting environment settings"

          try {
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
         
            $this.AddExtractedProperty("Environments", @{
                DefaultEnvironment      = $defaultEnvironment;
                DevelopmentEnvironments = $developmentEnvironments;
                TrialEnvironments       = $trialEnvironments;
                ProductionEnvironments  = $productionEnvironments
              })

            Write-Log -Level INFO "Successfully extracted environment settings"
          }
          catch {
            Write-Log -Level ERROR "Failed to extract environment settings: $_"
            throw $_
          }
        }
        
        function Get-DataPoliciesSettings() {
          Write-Log -Level INFO "Extracting data policy settings"

          try {
            $extractedParams = $this.GetExtractedParams()
            $policySettings = Request-PPLDataPoliciesSettings -Properties DefaultEnvironment, NonDefaultEnvironments `
              -DefaultEnvironmentId $extractedParams.Environments.DefaultEnvironment.Id

            # Default environment
            $confidentialConnectors = $policySettings.DefaultEnvironment.connectorGroups | Where-Object { $_.classification -eq "Confidential" } | Select-Object -ExpandProperty connectors
          
            $dataPoliciesTemplate = Get-ConfigurationFromBaselineTemplate -Baseline $Baseline -ConfigurationName "DataPolicies"
            $missingCoreConnectors = $dataPoliciesTemplate.DefaultEnvironment.AllowedCoreConnectors | Where-Object {
              $allowedName = $_
              -not ($confidentialConnectors | Where-Object { $_.id -eq $allowedName })
            }

            $defaultEnvironment = [PSCustomObject] @{
              PolicyName                 = $policySettings.DefaultEnvironment.displayName ?? "dedicated policy not found";
              PolicySettings             = $policySettings.DefaultEnvironment ?? $null;
              CoreConnectorsFromTemplate = $dataPoliciesTemplate.DefaultEnvironment.AllowedCoreConnectors;
              AllowedCoreConnectors      = $confidentialConnectors.id ?? @();
              MissingCoreConnectors      = $missingCoreConnectors;
            }

            # Non-default environments
            $nonDefaultEnvironments = [PSCustomObject] @{
              PolicySettings = $policySettings.NonDefaultEnvironments
            }

            # return data
            $this.AddExtractedProperty("DataPolicies", @{
                DefaultEnvironment     = $defaultEnvironment;
                NonDefaultEnvironments = $nonDefaultEnvironments
              })
            Write-Log -Level INFO "Successfully extracted data policy settings"
          }
          catch {
            Write-Log -Level ERROR "Failed to extract data policy settings: $_"
            throw $_
          }  
        }
        
        function Get-SecuritySettings() {
          Write-Log -Level INFO "Extracting security settings"

          try {
            $securitySettings = Request-PPLSecuritySettings -Properties TenantIsolation, ContentSecurityPolicy
          
            $this.AddExtractedProperty("SecuritySettings", @{
                TenantIsolation       = $securitySettings.TenantIsolation.properties ?? $null;
                ContentSecurityPolicy = $securitySettings.ContentSecurityPolicy ?? $null
              })
          }
          catch {
            Write-Log -Level ERROR "Failed to extract security settings: $_"
            throw $_
          }  
        }

        function Get-PowerAutomateSettings() {
          Write-Log -Level INFO "Extracting Power Automate settings"
          try {
            # Note: This is a placeholder for actual implementation
            # In a real implementation, you would call the appropriate API to get these settings
            $this.AddExtractedProperty("PowerAutomate", @{
                DisableFlowRunResubmission = $false # Default value, should be replaced with actual API call
              })
                      
            Write-Log -Level INFO "Successfully extracted Power Automate settings"
          }
          catch {
            Write-Log -Level ERROR "Failed to extract Power Automate settings: $_"
            throw $_
          }
        }
  
        try {
          Get-EnvironmentSettings
          Get-DataPoliciesSettings
          Get-SecuritySettings
          Get-PowerAutomateSettings
  
          return $this.GetExtractedParams()          
        }
        catch {
          Write-Log -Level ERROR "Error during extraction: $_"
          throw $_
        }
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        $settings = @{}
        
        # Environments
        $defaultEnvironmentId = $extractedSettings.Environments.DefaultEnvironment.Id
        $extractedSettings.Environments.DefaultEnvironment.PSObject.Properties.Remove('Id')

        $settings.Environments = $extractedSettings.Environments;

        # Data Policies
        $settings.DataPolicies = @{
          DefaultEnvironment     = @{
            PolicyName            = $extractedSettings.DataPolicies.DefaultEnvironment.PolicyName;
            AllowedCoreConnectors = $extractedSettings.DataPolicies.DefaultEnvironment.MissingCoreConnectors.Length -ne 0 ? $extractedSettings.DataPolicies.DefaultEnvironment.AllowedCoreConnectors : $extractedSettings.DataPolicies.DefaultEnvironment.CoreConnectorsFromTemplate;
          };

          NonDefaultEnvironments = @{
            AtLeastOneActivePolicy = $extractedSettings.DataPolicies.NonDefaultEnvironments.PolicySettings.Length -ne 0;
          }
        }
        
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