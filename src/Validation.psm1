$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Utilities = @( Get-ChildItem -Path $PSScriptRoot\utilities\*.psm1 -ErrorAction SilentlyContinue )

Foreach ($import in @($Public + $Private + $Utilities)) {
  $import
  Try {
    . $import.fullname
  }
  Catch {
    Write-Error -Message "[Validation] Failed to import function $( $import.fullname ): $_"
  }
}

Export-ModuleMember -Function $Public.Basename
Export-ModuleMember -Function $Utilities.Basename

# Check module dependencies before staring the routine
Test-RequiredModules