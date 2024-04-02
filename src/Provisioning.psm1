$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\Provisioning\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\Provisioning\*.ps1 -ErrorAction SilentlyContinue )

Foreach ($import in @($Public + $Private)) {
  $import
  Try {
    . $import.fullname
  }
  Catch {
    Write-Log -Level ERROR -Message "[Provisioning] Failed to import function $( $import.fullname ): $_"
  }
}

Export-ModuleMember -Function $Public.Basename