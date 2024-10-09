$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Utilities = @( Get-ChildItem -Path $PSScriptRoot\utilities\*.psm1 -ErrorAction SilentlyContinue )
$PublicCommon = @( Get-ChildItem -Path $PSScriptRoot\Public\*.psm1 -ErrorAction SilentlyContinue )

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

# Make the public functions available
Export-ModuleMember -Function $Public.Basename

# Import all modules and export the functions
foreach ($module in ($Utilities + $PublicCommon)) {
  Import-Module $module.FullName
  Export-ModuleMember -Function (Get-Command -Module $module.FullName -CommandType Function).Name
}

# Check module dependencies before staring the routine
Test-RequiredModules