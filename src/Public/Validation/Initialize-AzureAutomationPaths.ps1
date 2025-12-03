function Initialize-AzureAutomationPaths {
    <#
    .SYNOPSIS
        Initializes path resolution for Azure Automation environments.
    
    .DESCRIPTION
        This function sets a global variable to help locate tenant and baseline 
        configuration files in Azure Automation scenarios where $PSScriptRoot 
        doesn't resolve relative paths correctly.
        
        Call this ONCE at the beginning of your Azure Automation runbook, right
        after importing the easyGovernance module.
    
    .EXAMPLE
        Import-Module easyGovernance\src\Validation.psm1 -Force
        Initialize-AzureAutomationPaths
        Start-Validation -TemplateName "tenant.yml"
    
    .NOTES
        Only needed for Azure Automation. Local execution works without this function.
    #>
    
    [CmdletBinding()]
    param()
    
    try {
        # Find the Validation module
        $validationModule = Get-Module -Name "Validation"
        
        if (-not $validationModule) {
            throw "Validation module not loaded. Import easyGovernance module first."
        }
        
        # Get module base path
        $modulePath = Split-Path $validationModule.Path -Parent
        
        # Navigate to module root (one level up from src)
        if ($modulePath -match '[\\/]src$') {
            $moduleRoot = Split-Path $modulePath -Parent
        } else {
            # Already at src level or module was loaded differently
            $moduleRoot = Split-Path $modulePath -Parent
        }
        
        # Set global variable
        $Global:easyGovernanceModuleRoot = $moduleRoot
        
        # Verify paths
        $tenantsPath = Join-Path $moduleRoot "tenants"
        $baselinesPath = Join-Path $moduleRoot "baselines"
        
        if (-not (Test-Path $tenantsPath)) {
            Write-Warning "Tenants folder not found at: $tenantsPath"
        }
        
        if (-not (Test-Path $baselinesPath)) {
            Write-Warning "Baselines folder not found at: $baselinesPath"
        }
        
        Write-Output "Azure Automation paths initialized"
        Write-Output "  Module Root: $moduleRoot"
        Write-Output "  Tenants: $tenantsPath"
        Write-Output "  Baselines: $baselinesPath"
        
    } catch {
        Write-Error "Failed to initialize paths: $_"
        throw
    }
}
