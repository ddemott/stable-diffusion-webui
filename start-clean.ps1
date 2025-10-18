# Enhanced Cleanup and Startup Script with Configuration Support
# Reads settings from cleanup-config.txt

param(
    [switch]$Help = $false,
    [string]$ConfigPath = "cleanup-config.txt"
)

if ($Help) {
    Write-Host @"
Enhanced Stable Diffusion WebUI Cleanup and Startup Script

USAGE:
    .\start-clean.ps1 [OPTIONS]

OPTIONS:
    -ConfigPath      Path to configuration file (default: cleanup-config.txt)
    -Help            Show this help message

CONFIGURATION:
    Edit cleanup-config.txt to customize cleanup behavior.
    
EXAMPLES:
    .\start-clean.ps1                          # Use default config
    .\start-clean.ps1 -ConfigPath myconfig.txt # Use custom config
"@
    exit 0
}

# Set script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Default configuration
$Config = @{
    CLEAN_PYTHON_CACHE = $true
    CLEAN_TEMP_FILES = $true
    CLEAN_GRADIO_TEMP = $true
    CLEAN_OLD_LOGS = $true
    LOG_RETENTION_DAYS = 7
    AUTO_CLEAN_OUTPUTS = $false
    PROMPT_FOR_OUTPUT_CLEANUP = $true
    OUTPUT_DIRS = "outputs,log\images"
    CLEAN_EXTENSION_CACHE = $true
    CLEAN_EXTENSION_GIT_LOGS = $true
    CLEAN_CIVITAI_TEMP = $true
    CLEAN_ARIA2_TEMP = $true
    CLEAN_UI_CACHE = $true
    CLEAN_BROWSER_CACHE = $true
    CLEAN_ON_EXIT = $true
    SILENT_MODE = $false
    FORCE_CLEANUP = $false
    SHOW_PROGRESS = $true
    CUSTOM_CLEANUP_PATTERNS = ""
    EXCLUSION_PATTERNS = ""
}

# Function to read configuration file
function Read-Config {
    param([string]$ConfigFile)
    
    if (!(Test-Path $ConfigFile)) {
        Write-Host "Configuration file not found: $ConfigFile" -ForegroundColor Yellow
        Write-Host "Using default settings..." -ForegroundColor Yellow
        return
    }
    
    try {
        $content = Get-Content $ConfigFile
        foreach ($line in $content) {
            $line = $line.Trim()
            if ($line -and !$line.StartsWith('#') -and $line.Contains('=')) {
                $parts = $line.Split('=', 2)
                $key = $parts[0].Trim()
                $value = $parts[1].Trim()
                
                # Convert string values to appropriate types
                if ($value -eq 'true') { $value = $true }
                elseif ($value -eq 'false') { $value = $false }
                elseif ($value -match '^\d+$') { $value = [int]$value }
                elseif ($value.StartsWith('"') -and $value.EndsWith('"')) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                
                $script:Config[$key] = $value
            }
        }
        Write-Host "✓ Configuration loaded from: $ConfigFile" -ForegroundColor Green
    }
    catch {
        Write-Host "Error reading config file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Using default settings..." -ForegroundColor Yellow
    }
}

# Load configuration
Read-Config -ConfigFile $ConfigPath

# Initialize counters
$FilesDeleted = 0
$DirsDeleted = 0
$BytesFreed = 0

# Function to safely remove files/directories with exclusion checking
function Remove-SafelyWithCount {
    param(
        [string]$Path,
        [string]$Description = "",
        [switch]$IsDirectory = $false
    )
    
    # Check exclusion patterns
    if ($Config.EXCLUSION_PATTERNS) {
        $patterns = $Config.EXCLUSION_PATTERNS -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and !$_.StartsWith('#') }
        foreach ($pattern in $patterns) {
            if ($Path -like $pattern) {
                if ($Config.SHOW_PROGRESS) {
                    Write-Host "  ⏭ Excluded: $Description" -ForegroundColor Yellow
                }
                return $false
            }
        }
    }
    
    if (Test-Path $Path) {
        try {
            $size = 0
            if ($IsDirectory) {
                $size = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
                Remove-Item $Path -Recurse -Force
                $script:DirsDeleted++
            } else {
                $size = (Get-Item $Path).Length
                Remove-Item $Path -Force
                $script:FilesDeleted++
            }
            
            if ($size -gt 0) { $script:BytesFreed += $size }
            
            if ($Config.SHOW_PROGRESS -and $Description) {
                Write-Host "  ✓ Removed: $Description" -ForegroundColor Green
            }
            return $true
        }
        catch {
            if ($Config.SHOW_PROGRESS) {
                Write-Host "  ✗ Failed to remove: $Description - $($_.Exception.Message)" -ForegroundColor Red
            }
            return $false
        }
    }
    return $false
}

# Function to format bytes
function Format-Bytes {
    param([long]$bytes)
    
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    else { return "$bytes bytes" }
}

# Main cleanup process
if (!$Config.SILENT_MODE) {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Stable Diffusion WebUI Cleanup and Startup" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Starting cleanup process..." -ForegroundColor Yellow
    Write-Host ""
}

$step = 1
$totalSteps = 9

# 1. Clean Python cache files
if ($Config.CLEAN_PYTHON_CACHE) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning Python cache files..." -ForegroundColor Blue }
    
    Get-ChildItem -Path . -Name __pycache__ -Recurse -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-SafelyWithCount -Path $_ -Description "__pycache__ directory" -IsDirectory
    }
    
    Get-ChildItem -Path . -Name "*.pyc" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-SafelyWithCount -Path $_ -Description "Python cache file: $(Split-Path $_ -Leaf)"
    }
}
$step++

# 2. Clean temporary files
if ($Config.CLEAN_TEMP_FILES) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning temporary files..." -ForegroundColor Blue }
    
    if (Test-Path "tmp") {
        Get-ChildItem "tmp" -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithCount -Path $_.FullName -Description "Temp file: $($_.Name)"
        }
    }
}
$step++

# 3. Clean Gradio temp files
if ($Config.CLEAN_GRADIO_TEMP) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning Gradio temporary files..." -ForegroundColor Blue }
    
    $GradioTempPath = Join-Path $env:TEMP "gradio"
    if (Test-Path $GradioTempPath) {
        Remove-SafelyWithCount -Path $GradioTempPath -Description "Gradio temp directory" -IsDirectory
    }
    
    Get-ChildItem $env:TEMP -Name "gradio*" -ErrorAction SilentlyContinue | ForEach-Object {
        $fullPath = Join-Path $env:TEMP $_
        if (Test-Path $fullPath) {
            Remove-SafelyWithCount -Path $fullPath -Description "Gradio temp: $_" -IsDirectory
        }
    }
}
$step++

# 4. Clean old log files
if ($Config.CLEAN_OLD_LOGS) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning old log files..." -ForegroundColor Blue }
    
    $LogFiles = @("tmp\stdout.txt", "tmp\stderr.txt")
    foreach ($LogFile in $LogFiles) {
        if (Test-Path $LogFile) {
            $FileAge = (Get-Date) - (Get-Item $LogFile).LastWriteTime
            if ($FileAge.Days -gt $Config.LOG_RETENTION_DAYS -or $Config.FORCE_CLEANUP) {
                Remove-SafelyWithCount -Path $LogFile -Description "Old log file: $LogFile"
            }
        }
    }
}
$step++

# 5. Clean output directories
if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Checking output directories..." -ForegroundColor Blue }

$OutputDirs = $Config.OUTPUT_DIRS -split ',' | ForEach-Object { $_.Trim() }
$HasOutputs = $false

foreach ($OutputDir in $OutputDirs) {
    if (Test-Path $OutputDir) {
        $HasOutputs = $true
        break
    }
}

if ($HasOutputs) {
    $ShouldCleanOutputs = $Config.AUTO_CLEAN_OUTPUTS
    
    if (!$Config.SILENT_MODE -and !$Config.FORCE_CLEANUP -and !$Config.AUTO_CLEAN_OUTPUTS -and $Config.PROMPT_FOR_OUTPUT_CLEANUP) {
        Write-Host ""
        Write-Host "Found output directories with generated images." -ForegroundColor Yellow
        Write-Host "This may contain your generated artwork." -ForegroundColor Yellow
        Write-Host ""
        $Response = Read-Host "Do you want to clean output directories? (y/N)"
        $ShouldCleanOutputs = $Response -eq "y" -or $Response -eq "Y"
    }
    
    if ($ShouldCleanOutputs -or $Config.FORCE_CLEANUP) {
        foreach ($OutputDir in $OutputDirs) {
            if (Test-Path $OutputDir) {
                Get-ChildItem $OutputDir -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.PSIsContainer) {
                        Remove-SafelyWithCount -Path $_.FullName -Description "Output directory: $($_.Name)" -IsDirectory
                    } else {
                        Remove-SafelyWithCount -Path $_.FullName -Description "Output file: $($_.Name)"
                    }
                }
            }
        }
    } else {
        if (!$Config.SILENT_MODE) { Write-Host "  ⏭ Skipping output directories" -ForegroundColor Yellow }
    }
}
$step++

# 6. Clean extension caches
if ($Config.CLEAN_EXTENSION_CACHE) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning extension caches..." -ForegroundColor Blue }
    
    if (Test-Path "extensions") {
        Get-ChildItem "extensions" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $ExtPyCache = Join-Path $_.FullName "__pycache__"
            if (Test-Path $ExtPyCache) {
                Remove-SafelyWithCount -Path $ExtPyCache -Description "Extension cache: $($_.Name)" -IsDirectory
            }
            
            if ($Config.CLEAN_EXTENSION_GIT_LOGS) {
                $GitLogs = Join-Path $_.FullName ".git\logs"
                if (Test-Path $GitLogs) {
                    Get-ChildItem $GitLogs -File -ErrorAction SilentlyContinue | ForEach-Object {
                        Remove-SafelyWithCount -Path $_.FullName -Description "Git log: $($_.Name)"
                    }
                }
            }
            
            # Clean CivitAI extension specific temp files
            if ($Config.CLEAN_CIVITAI_TEMP -and $_.Name -like "*civitai*") {
                # Clean Aria2 temp files but preserve configuration
                $Aria2Dir = Join-Path $_.FullName "aria2"
                if (Test-Path $Aria2Dir) {
                    # Remove 'running' file but preserve other config
                    $RunningFile = Join-Path $Aria2Dir "running"
                    if (Test-Path $RunningFile) {
                        Remove-SafelyWithCount -Path $RunningFile -Description "CivitAI Aria2 running state"
                    }
                    
                    # Clean any Aria2 log files
                    Get-ChildItem $Aria2Dir -Name "*.log" -ErrorAction SilentlyContinue | ForEach-Object {
                        $LogPath = Join-Path $Aria2Dir $_
                        Remove-SafelyWithCount -Path $LogPath -Description "CivitAI Aria2 log: $_"
                    }
                }
            }
        }
    }
}
$step++

# 7. Clean Aria2 download temp files (from CivitAI and other extensions)
if ($Config.CLEAN_ARIA2_TEMP) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning Aria2 download temp files..." -ForegroundColor Blue }
    
    # Clean .aria2 partial download files
    Get-ChildItem -Name "*.aria2" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-SafelyWithCount -Path $_ -Description "Aria2 partial download: $_"
    }
    
    # Clean .part files (partial downloads)
    Get-ChildItem -Name "*.part" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-SafelyWithCount -Path $_ -Description "Partial download: $_"
    }
}
$step++

# 8. Clean UI cache files
if ($Config.CLEAN_UI_CACHE) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning UI cache files..." -ForegroundColor Blue }
    
    $CacheExtensions = @("*.css.map", "*.js.map", "*.tmp")
    foreach ($Extension in $CacheExtensions) {
        Get-ChildItem -Name $Extension -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithCount -Path $_ -Description "Cache file: $_"
        }
    }
}
$step++

# 9. Custom cleanup patterns
if ($Config.CUSTOM_CLEANUP_PATTERNS) {
    if (!$Config.SILENT_MODE) { Write-Host "[$step/$totalSteps] Cleaning custom patterns..." -ForegroundColor Blue }
    
    $patterns = $Config.CUSTOM_CLEANUP_PATTERNS -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and !$_.StartsWith('#') }
    foreach ($pattern in $patterns) {
        Get-ChildItem -Name $pattern -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithCount -Path $_ -Description "Custom pattern: $_"
        }
    }
}

# Summary
if (!$Config.SILENT_MODE) {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Cleanup Summary" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "Files deleted: $FilesDeleted" -ForegroundColor Green
    Write-Host "Directories deleted: $DirsDeleted" -ForegroundColor Green
    Write-Host "Space freed: $(Format-Bytes $BytesFreed)" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "The following caches were PRESERVED for performance:" -ForegroundColor Yellow
    Write-Host "  ✓ cache/hashes/ - Model file hashes" -ForegroundColor Green
    Write-Host "  ✓ cache/safetensors-metadata/ - Model metadata" -ForegroundColor Green
    Write-Host "  ✓ repositories/ - Git repositories" -ForegroundColor Green
    Write-Host "  ✓ venv/ - Python environment" -ForegroundColor Green
    Write-Host "  ✓ Extension configurations" -ForegroundColor Green
    Write-Host "  ✓ CivitAI settings and subfolders config" -ForegroundColor Green
    Write-Host "  ✓ Model files and checkpoints" -ForegroundColor Green
    Write-Host ""
}

# Start WebUI
if (!$Config.SILENT_MODE) {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Starting Stable Diffusion WebUI" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
}

# Determine startup script
$StartupScript = ""
if (Test-Path "webui-user.bat") {
    $StartupScript = "webui-user.bat"
    if (!$Config.SILENT_MODE) { Write-Host "Using custom settings from webui-user.bat..." -ForegroundColor Green }
} elseif (Test-Path "webui.bat") {
    $StartupScript = "webui.bat"
    if (!$Config.SILENT_MODE) { Write-Host "Starting with default settings..." -ForegroundColor Green }
} else {
    Write-Host "Error: No suitable startup script found!" -ForegroundColor Red
    exit 1
}

# Start the WebUI
try {
    & cmd.exe /c $StartupScript
}
catch {
    Write-Host "Error starting WebUI: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Cleanup on exit
if ($Config.CLEAN_ON_EXIT) {
    if (!$Config.SILENT_MODE) {
        Write-Host ""
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host " WebUI has closed" -ForegroundColor Cyan
        Write-Host "===============================================" -ForegroundColor Cyan
        Write-Host "Performing exit cleanup..." -ForegroundColor Yellow
    }
    
    # Clean session temp files
    $TempFiles = @("tmp\*.txt", "tmp\*.log")
    foreach ($Pattern in $TempFiles) {
        Get-ChildItem $Pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithCount -Path $_.FullName -Description "Session temp: $($_.Name)"
        }
    }
    
    $GradioTempPath = Join-Path $env:TEMP "gradio"
    if (Test-Path $GradioTempPath) {
        Remove-SafelyWithCount -Path $GradioTempPath -Description "Gradio session temp" -IsDirectory
    }
    
    if (!$Config.SILENT_MODE) { Write-Host "Exit cleanup complete." -ForegroundColor Green }
}

if (!$Config.SILENT_MODE) {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}