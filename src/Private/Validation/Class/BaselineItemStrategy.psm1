class BaselineItemStrategy {

  # Determine the appropriate strategy to get a VALUE from the object
  static [scriptblock] GetValueStrategy([object]$object) {
    if ($object -is [System.Enum] -or 
      $object -is [string] -or 
      $object -is [int] -or 
      $object -is [double] -or 
      $object -is [float] -or 
      $object -is [long] -or 
      $object -is [short] -or 
      $object -is [byte] -or 
      $object -is [bool]) {
      return { param($obj, $key) return $obj }
    }
    elseif ($object -is [array] -or $object -is [hashtable]) {
      return { param($obj, $key) return $obj[$key] }
    }
    else {
      return { param($obj, $key) return $obj.$key }
    }  
  }

  # Determine the appropriate strategy to get KEYS from the object
  static [scriptblock] GetKeysStrategy([object]$object) {
    if ($object -is [System.Enum] -or 
      $object -is [string] -or 
      $object -is [int] -or 
      $object -is [double] -or 
      $object -is [float] -or 
      $object -is [long] -or 
      $object -is [short] -or 
      $object -is [byte] -or 
      $object -is [bool]) {
      return { param($obj) return @($obj) }
    }
    elseif ($object -is [array] -or $object -is [hashtable]) {
      return { param($obj) return @($obj.Keys) }
    }
    else {
      return { param($obj) return @($obj.PSObject.Properties.Name) }
    }  
  }

  static [object] GetValue([object]$object, [string]$key) {
    $strategy = [BaselineItemStrategy]::GetValueStrategy($object)
    return & $strategy $object $key
  }

  static [array] GetKeys([object]$object) {
    $strategy = [BaselineItemStrategy]::GetKeysStrategy($object)
    return & $strategy $object
  }
}