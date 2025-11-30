class ApiRequestDefinition {
    [ValidateNotNullOrEmpty()][string] $name
    [ValidateNotNullOrEmpty()][string] $path
    [string] $attr = ""
    [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")][string] $method = "GET"
    
    # Hidden parameterless constructor for hashtable syntax
    hidden ApiRequestDefinition() {}
    
    hidden [void] Initialize([string]$name, [string]$path, [string]$attr, [string]$method) {
        if ([string]::IsNullOrWhiteSpace($name)) { 
            throw [ArgumentException]::new("Parameter 'name' is required and cannot be null or empty", "name")
        }
        if ([string]::IsNullOrWhiteSpace($path)) { 
            throw [ArgumentException]::new("Parameter 'path' is required and cannot be null or empty", "path")
        }
        if (![string]::IsNullOrWhiteSpace($method) -and $method -notin @("GET", "POST", "PUT", "PATCH", "DELETE")) {
            throw [ArgumentException]::new("Parameter 'method' must be one of: GET, POST, PUT, PATCH, DELETE", "method")
        }
        
        $this.name = $name
        $this.path = $path
        $this.attr = $attr ?? ""
        $this.method = $method ?? "GET"
    }
    
    ApiRequestDefinition([string]$name, [string]$path) {
        $this.Initialize($name, $path, "", "GET")
    }
    
    ApiRequestDefinition([string]$name, [string]$path, [string]$attr) {
        $this.Initialize($name, $path, $attr, "GET")
    }
    
    ApiRequestDefinition([string]$name, [string]$path, [string]$attr, [string]$method) {
        $this.Initialize($name, $path, $attr, $method)
    }
    
    [string] ToString() {
        return "[$($this.method)] $($this.name): $($this.path)" + ($this.attr ? " -> $($this.attr)" : "")
    }
}