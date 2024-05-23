using module ..\..\..\utilities\ValidationFunctions.psm1

class ValidationSettings {
    [PSCustomObject] $Baseline = $null
    [string] $TenantId = $null
    [switch] $ReturnAsObject = $false
}

class BaselineValidator {
    [ValidationSettings] $ValidationSettings = @{
        Baseline       = [PSCustomObject] $null
        TenantId       = [string] $null
        ReturnAsObject = [switch] $false
    }
    # [PSCustomObject]$Baseline
    # [string] $TenantId
    # [switch] $ReturnAsObject

    hidden [PSCustomObject] $validationResult = $null
    hidden [PSCustomObject] $validationResultGrouped = $null
    hidden [PSCustomObject] $validationResultStatistics = $null

    BaselineValidator([PSCustomObject] $Baseline, [string] $TenantId, [switch] $ReturnAsObject = $false) {
        $this.ValidationSettings.Baseline = $Baseline
        $this.ValidationSettings.TenantId = $TenantId
        $this.ValidationSettings.ReturnAsObject = $ReturnAsObject
    }

    Connect() {
        throw "Connect must be implemented"
    }
    
    [PSCustomObject] Extract() {
        throw "Extract must be implemented – extract settings from M365 service or tenant and return object"
    }
    
    [PSCustomObject] Transform([PSCustomObject] $extractedSettings) {
        throw "Transform must be implemented – transform extracted settings to make them ready for validation and return object"
    }
    
    hidden [void] Validate([PSCustomObject] $tenantSettings) {
        $this.validationResult = Test-Settings $tenantSettings -Baseline $this.ValidationSettings.Baseline | Sort-Object -Property Group, Setting
    }

    [void] StartValidation() {
        try {
            $this.Connect()
            $extracted = $this.Extract()
        }
        catch {
            Write-Log -Level CRITICAL "Baseline extraction failed: $_" 
            throw $_
        } 
        try {
            $transformed = $this.Transform($extracted)
        }
        catch {
            Write-Log -Level CRITICAL "Baseline transformation failed: $_" 
            throw $_
        } 
        try {
            $this.Validate($transformed)
        }
        catch {
            Write-Log -Level CRITICAL "Baseline validation failed: $_" 
            throw $_
        }
    }

    [PSCustomObject] GetValidationResult() {
        try {
            if ($null -eq $this.validationResult) {
                $this.StartValidation()
            }
            
            $this.validationResultGrouped = ($this.validationResult | Format-Table -GroupBy Group -Wrap -Property Setting, Result) 
            if (!$this.ValidationSettings.ReturnAsObject) { $this.validationResultGrouped | Out-Host }
    
            $this.validationResultStatistics = Get-TestStatistics $this.validationResult
            ($this.validationResultStatistics.asText) | Out-Host

            if ($this.ValidationSettings.ReturnAsObject) {
                return @{
                    Baseline          = $this.ValidationSettings.Baseline.Id;
                    Version           = $this.ValidationSettings.Baseline.Version;
                    Result            = $this.validationResult; 
                    ResultGroupedText = $this.validationResultGrouped;
                    Statistics        = $this.validationResultStatistics;
                    StatisticsAsText  = $this.validationResultStatistics.asText;
                } 
            }
            else {
                return $this.validationResult
            }
        }
        catch {
            throw $_
        }    
    }
}