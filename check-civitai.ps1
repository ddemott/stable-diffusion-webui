# CivitAI Extension Status and Cleanup Check
# This script helps analyze what the CivitAI extension is caching

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " CivitAI Extension Analysis" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$CivitAIExtPath = "extensions\sd-civitai-browser-plus"
$ConfigPath = "config_states\civitai_subfolders.json"

if (Test-Path $CivitAIExtPath) {
    Write-Host "✓ CivitAI Browser Plus extension found" -ForegroundColor Green
    
    # Check Aria2 status
    $Aria2Path = Join-Path $CivitAIExtPath "aria2"
    if (Test-Path $Aria2Path) {
        Write-Host "✓ Aria2 download manager found" -ForegroundColor Green
        
        $RunningFile = Join-Path $Aria2Path "running"
        if (Test-Path $RunningFile) {
            Write-Host "  ⚡ Aria2 is currently running" -ForegroundColor Yellow
        } else {
            Write-Host "  ⏸ Aria2 is not running" -ForegroundColor Gray
        }
        
        # Check for log files
        $LogFiles = Get-ChildItem $Aria2Path -Name "*.log" -ErrorAction SilentlyContinue
        if ($LogFiles) {
            Write-Host "  📝 Found $($LogFiles.Count) Aria2 log file(s)" -ForegroundColor Yellow
        }
    }
    
    # Check cache files
    $CacheFiles = Get-ChildItem $CivitAIExtPath -Recurse -Name "*.cache" -ErrorAction SilentlyContinue
    if ($CacheFiles) {
        Write-Host "  💾 Found $($CacheFiles.Count) cache file(s)" -ForegroundColor Yellow
    }
    
    # Check temp files
    $TempFiles = @()
    $TempFiles += Get-ChildItem $CivitAIExtPath -Recurse -Name "*.tmp" -ErrorAction SilentlyContinue
    $TempFiles += Get-ChildItem $CivitAIExtPath -Recurse -Name "*.temp" -ErrorAction SilentlyContinue
    $TempFiles += Get-ChildItem $CivitAIExtPath -Recurse -Name "*.aria2" -ErrorAction SilentlyContinue
    $TempFiles += Get-ChildItem $CivitAIExtPath -Recurse -Name "*.part" -ErrorAction SilentlyContinue
    
    if ($TempFiles) {
        Write-Host "  🗑️ Found $($TempFiles.Count) temporary file(s)" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "✗ CivitAI Browser Plus extension not found" -ForegroundColor Red
}

Write-Host ""

# Check configuration files
if (Test-Path $ConfigPath) {
    Write-Host "✓ CivitAI configuration found: $ConfigPath" -ForegroundColor Green
    try {
        $ConfigContent = Get-Content $ConfigPath | ConvertFrom-Json
        $SubfolderCount = $ConfigContent.PSObject.Properties.Count
        Write-Host "  📁 Configured subfolders: $SubfolderCount" -ForegroundColor Gray
    } catch {
        Write-Host "  ⚠️ Could not read configuration file" -ForegroundColor Yellow
    }
} else {
    Write-Host "ℹ️ No CivitAI configuration file found" -ForegroundColor Gray
}

Write-Host ""

# Check for download artifacts in models directory
Write-Host "Checking for download artifacts..." -ForegroundColor Blue

$DownloadArtifacts = @()
if (Test-Path "models") {
    $DownloadArtifacts += Get-ChildItem "models" -Recurse -Name "*.aria2" -ErrorAction SilentlyContinue
    $DownloadArtifacts += Get-ChildItem "models" -Recurse -Name "*.part" -ErrorAction SilentlyContinue
    $DownloadArtifacts += Get-ChildItem "models" -Recurse -Name "*.tmp" -ErrorAction SilentlyContinue
}

if ($DownloadArtifacts) {
    Write-Host "⚠️ Found $($DownloadArtifacts.Count) download artifact(s) in models directory" -ForegroundColor Yellow
    foreach ($artifact in $DownloadArtifacts) {
        Write-Host "  - $artifact" -ForegroundColor Gray
    }
} else {
    Write-Host "✓ No download artifacts found in models directory" -ForegroundColor Green
}

Write-Host ""

# Summary
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host " Cleanup Recommendations" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Host "Safe to clean:" -ForegroundColor Green
Write-Host "  ✓ Aria2 log files" -ForegroundColor Green
Write-Host "  ✓ Temporary download files (*.aria2, *.part)" -ForegroundColor Green
Write-Host "  ✓ Extension cache files" -ForegroundColor Green
Write-Host ""

Write-Host "PRESERVE (important for functionality):" -ForegroundColor Yellow
Write-Host "  ⚠️ civitai_subfolders.json (your folder configurations)" -ForegroundColor Yellow
Write-Host "  ⚠️ Downloaded model files" -ForegroundColor Yellow
Write-Host "  ⚠️ Extension settings and configurations" -ForegroundColor Yellow
Write-Host ""

Write-Host "Press any key to continue..." -ForegroundColor Gray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null