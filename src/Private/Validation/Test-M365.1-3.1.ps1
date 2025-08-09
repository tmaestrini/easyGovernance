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
        
        function Get-EnvironmentSettings([BaselineValidator] $validator) {
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
         
            $validator.AddExtractedProperty("Environments", @{
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
        
        function Get-DataPoliciesSettings([BaselineValidator] $validator) {
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
            $validator.AddExtractedProperty("DataPolicies", @{
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
        
        function Get-SecuritySettings([BaselineValidator] $validator) {
          Write-Log -Level INFO "Extracting security settings"

          try {
            $securitySettings = Request-PPLSecuritySettings -Properties TenantIsolation, ContentSecurityPolicy
          
            $validator.AddExtractedProperty("SecuritySettings", @{
                TenantIsolation       = $securitySettings.TenantIsolation.properties ?? $null;
                ContentSecurityPolicy = $securitySettings.ContentSecurityPolicy ?? $null
              })
          }
          catch {
            Write-Log -Level ERROR "Failed to extract security settings: $_"
            throw $_
          }  
        }

        function Get-PowerAutomateSettings([BaselineValidator] $validator) {
          Write-Log -Level INFO "Extracting Power Automate settings"

          try {
            $powerAutomateSettings = Request-PPLPowerAutomateSettings -Properties GeneralSettings
            
            $validator.AddExtractedProperty("PowerAutomate", @{
                GeneralSettings = $powerAutomateSettings.GeneralSettings ?? $null
              })
            
            Write-Log -Level INFO "Successfully extracted Power Automate settings"
          }
          catch {
            Write-Log -Level ERROR "Failed to extract Power Automate settings: $_"
            throw $_
          }
        }
  
        try {
          Get-EnvironmentSettings -Validator $this
          Get-DataPoliciesSettings -Validator $this
          Get-SecuritySettings -Validator $this
          Get-PowerAutomateSettings -Validator $this
  
          return $this.GetExtractedParams()          
        }
        catch {
          Write-Log -Level ERROR "Error during extraction: $_"
          throw $_
        }
      }

      [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        Write-Log -Level INFO "Transforming extracted settings for validation"

        try {
          $settings = @{}
        
          # Environments
          $defaultEnvironmentId = $extractedSettings.Environments.DefaultEnvironment.Id
          $extractedSettings.Environments.DefaultEnvironment.PSObject.Properties.Remove('Id')

          $settings.Environments = $extractedSettings.Environments;

          # Data Policies
          $settings.DataPolicies = @{
            DefaultEnvironment     = @{
              PolicyName            = $extractedSettings.DataPolicies.DefaultEnvironment.PolicyName;
              AllowedCoreConnectors = $extractedSettings.DataPolicies.DefaultEnvironment.MissingCoreConnectors.Length -eq 0 ? 
              $extractedSettings.DataPolicies.DefaultEnvironment.CoreConnectorsFromTemplate : 
              $extractedSettings.DataPolicies.DefaultEnvironment.AllowedCoreConnectors
            };

            NonDefaultEnvironments = @{
              AtLeastOneActivePolicy = $extractedSettings.DataPolicies.NonDefaultEnvironments.PolicySettings.Length -ne 0;
            }
          }

          # Security Settings
          $settings.SecuritySettings = @{
            TenantIsolation       = @{
              IsolationControl = $extractedSettings.SecuritySettings.TenantIsolation.isolationSettings?.isolationPolicy ?? "Off"
            }

            # TODO: Read Content Security Policy settings and aggregate the results
            ContentSecurityPolicy = @{
              CanvasApps                         = $extractedSettings.SecuritySettings.ContentSecurityPolicy.canvasApps ?? $false;
              ModelDrivenApps                    = $extractedSettings.SecuritySettings.ContentSecurityPolicy.modelDrivenApps ?? $false;
              EnableReportingViolations          = $extractedSettings.SecuritySettings.ContentSecurityPolicy.enableReportingViolations ?? $false;
              EnableForDefaultEnvironment        = $extractedSettings.SecuritySettings.ContentSecurityPolicy.enableForDefaultEnvironment ?? $false;
              EnableForDevelopmentEnvironments   = $extractedSettings.SecuritySettings.ContentSecurityPolicy.enableForDevelopmentEnvironments ?? $false;
              EnableForProductionEnvironments    = $extractedSettings.SecuritySettings.ContentSecurityPolicy.enableForProductionEnvironments ?? $false;
            }
          }
                              
          # Power Automate Settings
          $settings.PowerAutomate = @{
            EnableFlowRunResubmission = !$extractedSettings.PowerAutomate.GeneralSettings.disableFlowRunResubmission
          }
                              
          Write-Log -Level INFO "Successfully transformed settings for validation"
          return $settings
        }
        catch {
          Write-Log -Level ERROR "Failed to transform settings: $_"
          throw $_
        }
      }
    }
  }
  Process {
    try {
      $validator = [PPLSettingsValidator]::new($Baseline, $tenantId, $ReturnAsObject)

      Write-Log -Level INFO "Starting validation process"
      $validator.StartValidation()

      Write-Log -Level INFO "Retrieving validation results"
      $result = $validator.GetValidationResult()
      
      if ($returnAsObject) {
        return $result
      }
    }
    catch {
      Write-Log -Level ERROR "Validation failed: $_"
      throw $_
    }
  }
}