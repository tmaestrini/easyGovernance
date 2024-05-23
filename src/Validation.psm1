$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Utilities = @( Get-ChildItem -Path $PSScriptRoot\utilities\*.psm1 -ErrorAction SilentlyContinue )

# Import all script resources
Foreach ($import in @($Public + $Private)) {
  $import
  Try {
    . $import.fullname
  }
  Catch {
    Write-Error -Message "[Validation] Failed to import function $( $import.fullname ): $_"
    Exit
  }
}

Export-ModuleMember -Function $Public.Basename

# Import all modules
foreach ($module in $Utilities) {
  Import-Module $module.FullName
}

# Check module dependencies before staring the routine
Test-RequiredModules