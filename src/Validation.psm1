$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\Validation\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\Validation\*.ps1 -ErrorAction SilentlyContinue )

Foreach ($import in @($Public + $Private)) {
  $import
  Try {
    . $import.fullname
  }
  Catch {
    Write-Log -Level ERROR -Message "[Validation] Failed to import function $( $import.fullname ): $_"
  }
}

Export-ModuleMember -Function $Public.Basename