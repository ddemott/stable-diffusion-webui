# Stable Diffusion WebUI Cleanup and Startup Script
# PowerShell version with advanced features

param(
    [switch]$CleanOutputs = $false,
    [switch]$Silent = $false,
    [switch]$Force = $false,
    [string]$ConfigFile = "",
    [switch]$Help = $false
)

if ($Help) {
    Write-Host @"
Stable Diffusion WebUI Cleanup and Startup Script

USAGE:
    .\cleanup-and-start.ps1 [OPTIONS]

OPTIONS:
    -CleanOutputs    Clean generated images in output directories
    -Silent          Run cleanup without prompts  
    -Force           Force cleanup without confirmations
    -ConfigFile      Use specific webui config file
    -Help            Show this help message

EXAMPLES:
    .\cleanup-and-start.ps1                    # Interactive cleanup
    .\cleanup-and-start.ps1 -Silent            # Silent cleanup
    .\cleanup-and-start.ps1 -CleanOutputs      # Include output cleanup
    .\cleanup-and-start.ps1 -Force -Silent     # Force all cleanups
"@
    exit 0
}

# Set script location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# Initialize counters
$FilesDeleted = 0
$DirsDeleted = 0
$BytesFreed = 0

# Function to safely remove files/directories
function Remove-SafelyWithCount {
    param(
        [string]$Path,
        [string]$Description = "",
        [switch]$IsDirectory = $false
    )
    
    if (Test-Path $Path) {
        try {
            $size = 0
            if ($IsDirectory) {
                $size = (Get-ChildItem $Path -Recurse -File | Measure-Object -Property Length -Sum).Sum
                Remove-Item $Path -Recurse -Force
                $script:DirsDeleted++
            } else {
                $size = (Get-Item $Path).Length
                Remove-Item $Path -Force
                $script:FilesDeleted++
            }
            
            if ($size -gt 0) { $script:BytesFreed += $size }
            
            if (!$Silent -and $Description) {
                Write-Host "  ✓ Removed: $Description" -ForegroundColor Green
            }
            return $true
        }
        catch {
            if (!$Silent) {
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

if (!$Silent) {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Stable Diffusion WebUI Cleanup and Startup" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Starting cleanup process..." -ForegroundColor Yellow
    Write-Host ""
}

# 1. Clean Python cache files
if (!$Silent) { Write-Host "[1/8] Cleaning Python cache files..." -ForegroundColor Blue }

Get-ChildItem -Path . -Name __pycache__ -Recurse -Directory | ForEach-Object {
    Remove-SafelyWithCount -Path $_ -Description "__pycache__ directory" -IsDirectory
}

Get-ChildItem -Path . -Name "*.pyc" -Recurse -File | ForEach-Object {
    Remove-SafelyWithCount -Path $_ -Description "Python cache file: $(Split-Path $_ -Leaf)"
}

# 2. Clean temporary files
if (!$Silent) { Write-Host "[2/8] Cleaning temporary files..." -ForegroundColor Blue }

if (Test-Path "tmp") {
    Get-ChildItem "tmp" | ForEach-Object {
        Remove-SafelyWithCount -Path $_.FullName -Description "Temp file: $($_.Name)"
    }
}

# 3. Clean Gradio temp files
if (!$Silent) { Write-Host "[3/8] Cleaning Gradio temporary files..." -ForegroundColor Blue }

$GradioTempPath = Join-Path $env:TEMP "gradio"
if (Test-Path $GradioTempPath) {
    Remove-SafelyWithCount -Path $GradioTempPath -Description "Gradio temp directory" -IsDirectory
}

# Also clean any gradio temp files in system temp
Get-ChildItem $env:TEMP -Name "gradio*" | ForEach-Object {
    $fullPath = Join-Path $env:TEMP $_
    if (Test-Path $fullPath) {
        Remove-SafelyWithCount -Path $fullPath -Description "Gradio temp: $_" -IsDirectory
    }
}

# 4. Clean old log files
if (!$Silent) { Write-Host "[4/8] Cleaning old log files..." -ForegroundColor Blue }

$LogFiles = @("tmp\stdout.txt", "tmp\stderr.txt")
foreach ($LogFile in $LogFiles) {
    if (Test-Path $LogFile) {
        $FileAge = (Get-Date) - (Get-Item $LogFile).LastWriteTime
        if ($FileAge.Days -gt 7 -or $Force) {
            Remove-SafelyWithCount -Path $LogFile -Description "Old log file: $LogFile"
        }
    }
}

# 5. Clean output directories (with user confirmation)
if (!$Silent) { Write-Host "[5/8] Checking output directories..." -ForegroundColor Blue }

$OutputDirs = @("outputs", "log\images")
$HasOutputs = $false

foreach ($OutputDir in $OutputDirs) {
    if (Test-Path $OutputDir) {
        $HasOutputs = $true
        break
    }
}

if ($HasOutputs) {
    $ShouldCleanOutputs = $CleanOutputs
    
    if (!$Silent -and !$Force -and !$CleanOutputs) {
        Write-Host ""
        Write-Host "Found output directories with generated images." -ForegroundColor Yellow
        Write-Host "This may contain your generated artwork." -ForegroundColor Yellow
        Write-Host ""
        $Response = Read-Host "Do you want to clean output directories? (y/N)"
        $ShouldCleanOutputs = $Response -eq "y" -or $Response -eq "Y"
    }
    
    if ($ShouldCleanOutputs -or $Force) {
        foreach ($OutputDir in $OutputDirs) {
            if (Test-Path $OutputDir) {
                Get-ChildItem $OutputDir -Recurse | ForEach-Object {
                    if ($_.PSIsContainer) {
                        Remove-SafelyWithCount -Path $_.FullName -Description "Output directory: $($_.Name)" -IsDirectory
                    } else {
                        Remove-SafelyWithCount -Path $_.FullName -Description "Output file: $($_.Name)"
                    }
                }
            }
        }
    } else {
        if (!$Silent) { Write-Host "  ⏭ Skipping output directories (user choice)" -ForegroundColor Yellow }
    }
}

# 6. Clean extension caches
if (!$Silent) { Write-Host "[6/8] Cleaning extension caches..." -ForegroundColor Blue }

if (Test-Path "extensions") {
    Get-ChildItem "extensions" -Directory | ForEach-Object {
        $ExtPyCache = Join-Path $_.FullName "__pycache__"
        if (Test-Path $ExtPyCache) {
            Remove-SafelyWithCount -Path $ExtPyCache -Description "Extension cache: $($_.Name)" -IsDirectory
        }
        
        # Clean git logs but preserve repos
        $GitLogs = Join-Path $_.FullName ".git\logs"
        if (Test-Path $GitLogs) {
            Get-ChildItem $GitLogs -File | ForEach-Object {
                Remove-SafelyWithCount -Path $_.FullName -Description "Git log: $($_.Name)"
            }
        }
    }
}

# 7. Clean UI cache files
if (!$Silent) { Write-Host "[7/8] Cleaning UI cache files..." -ForegroundColor Blue }

$CacheExtensions = @("*.css.map", "*.js.map", "*.tmp")
foreach ($Extension in $CacheExtensions) {
    Get-ChildItem -Name $Extension | ForEach-Object {
        Remove-SafelyWithCount -Path $_ -Description "Cache file: $_"
    }
}

# 8. Summary
if (!$Silent) {
    Write-Host "[8/8] Cleanup complete!" -ForegroundColor Green
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
    Write-Host ""
}

# Start WebUI
if (!$Silent) {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " Starting Stable Diffusion WebUI" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host ""
}

# Determine which startup script to use
$StartupScript = ""
if ($ConfigFile -and (Test-Path $ConfigFile)) {
    $StartupScript = $ConfigFile
} elseif (Test-Path "webui-user.bat") {
    $StartupScript = "webui-user.bat"
    if (!$Silent) { Write-Host "Using custom settings from webui-user.bat..." -ForegroundColor Green }
} elseif (Test-Path "webui.bat") {
    $StartupScript = "webui.bat"
    if (!$Silent) { Write-Host "Starting with default settings..." -ForegroundColor Green }
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
if (!$Silent) {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host " WebUI has closed" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
}

$CleanOnExit = $Force
if (!$Silent -and !$Force) {
    Write-Host ""
    $Response = Read-Host "Clean temporary files on exit? (y/N)"
    $CleanOnExit = $Response -eq "y" -or $Response -eq "Y"
}

if ($CleanOnExit) {
    if (!$Silent) { Write-Host "Performing exit cleanup..." -ForegroundColor Yellow }
    
    # Clean session temp files
    $TempFiles = @("tmp\*.txt", "tmp\*.log")
    foreach ($Pattern in $TempFiles) {
        Get-ChildItem $Pattern -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-SafelyWithCount -Path $_.FullName -Description "Session temp: $($_.Name)"
        }
    }
    
    # Clean any new gradio temp files
    $GradioTempPath = Join-Path $env:TEMP "gradio"
    if (Test-Path $GradioTempPath) {
        Remove-SafelyWithCount -Path $GradioTempPath -Description "Gradio session temp" -IsDirectory
    }
    
    if (!$Silent) { Write-Host "Exit cleanup complete." -ForegroundColor Green }
}

if (!$Silent) {
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
}