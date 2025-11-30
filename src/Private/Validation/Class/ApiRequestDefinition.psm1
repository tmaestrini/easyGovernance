class ApiRequestDefinition {
    [ValidateNotNullOrEmpty()][string] $name
    [ValidateNotNullOrEmpty()][string] $path
    [ValidateNotNull()][string] $attr = ""
    [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")][string] $method = "GET"
    
    ApiRequestDefinition() {
        # Parameterless constructor for hashtable-style instantiation
        # Validation happens automatically via property attributes
    }
    
    ApiRequestDefinition([string]$name, [string]$path) {
        if ([string]::IsNullOrWhiteSpace($name)) { 
            throw [ArgumentException]::new("Parameter 'name' is required and cannot be null or empty", "name")
        }
        if ([string]::IsNullOrWhiteSpace($path)) { 
            throw [ArgumentException]::new("Parameter 'path' is required and cannot be null or empty", "path")
        }
        $this.name = $name
        $this.path = $path
    }
    
    ApiRequestDefinition([string]$name, [string]$path, [string]$attr) {
        if ([string]::IsNullOrWhiteSpace($name)) { 
            throw [ArgumentException]::new("Parameter 'name' is required and cannot be null or empty", "name")
        }
        if ([string]::IsNullOrWhiteSpace($path)) { 
            throw [ArgumentException]::new("Parameter 'path' is required and cannot be null or empty", "path")
        }
        $this.name = $name
        $this.path = $path
        $this.attr = $attr ?? ""
    }
    
    ApiRequestDefinition([string]$name, [string]$path, [string]$attr, [string]$method) {
        if ([string]::IsNullOrWhiteSpace($name)) { 
            throw [ArgumentException]::new("Parameter 'name' is required and cannot be null or empty", "name")
        }
        if ([string]::IsNullOrWhiteSpace($path)) { 
            throw [ArgumentException]::new("Parameter 'path' is required and cannot be null or empty", "path")
        }
        if ($method -and $method -notin @("GET", "POST", "PUT", "PATCH", "DELETE")) {
            throw [ArgumentException]::new("Parameter 'method' must be one of: GET, POST, PUT, PATCH, DELETE", "method")
        }
        $this.name = $name
        $this.path = $path
        $this.attr = $attr ?? ""
        $this.method = $method ?? "GET"
    }
    
    [string] ToString() {
        return "[$($this.method)] $($this.name): $($this.path)" + ($this.attr ? " -> $($this.attr)" : "")
    }
}