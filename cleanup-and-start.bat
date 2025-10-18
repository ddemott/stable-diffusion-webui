@echo off
setlocal enabledelayedexpansion

echo ===============================================
echo  Stable Diffusion WebUI Cleanup and Startup
echo ===============================================
echo.

REM Get the directory where this script is located
set "WEBUI_DIR=%~dp0"
cd /d "%WEBUI_DIR%"

REM Initialize cleanup counters
set /a "files_deleted=0"
set /a "dirs_deleted=0"
set /a "bytes_freed=0"

echo Starting cleanup process...
echo.

REM ===================================
REM Clean Python cache files
REM ===================================
echo [1/8] Cleaning Python cache files...
for /r . %%d in (__pycache__) do (
    if exist "%%d" (
        echo   Removing: %%d
        rmdir /s /q "%%d" 2>nul
        if not exist "%%d" set /a "dirs_deleted+=1"
    )
)

REM Clean .pyc files
for /r . %%f in (*.pyc) do (
    if exist "%%f" (
        echo   Removing: %%f
        del /q "%%f" 2>nul
        if not exist "%%f" set /a "files_deleted+=1"
    )
)

REM ===================================
REM Clean temporary files
REM ===================================
echo [2/8] Cleaning temporary files...
if exist "tmp" (
    for %%f in (tmp\*) do (
        echo   Removing: %%f
        del /q "%%f" 2>nul
        if not exist "%%f" set /a "files_deleted+=1"
    )
)

REM ===================================
REM Clean Gradio temp files
REM ===================================
echo [3/8] Cleaning Gradio temporary files...
if exist "%TEMP%\gradio" (
    echo   Removing Gradio temp directory...
    rmdir /s /q "%TEMP%\gradio" 2>nul
    set /a "dirs_deleted+=1"
)

REM ===================================
REM Clean old log files (keep recent ones)
REM ===================================
echo [4/8] Cleaning old log files...

REM Clean old stdout/stderr logs
for /f "tokens=*" %%f in ('dir /b /a-d tmp\*.txt 2^>nul') do (
    for %%g in (tmp\%%f) do (
        REM Delete files older than 7 days
        forfiles /p tmp /m %%f /d -7 /c "cmd /c echo   Removing old log: @path && del @path" 2>nul
    )
)

REM ===================================
REM Clean output directories (OPTIONAL - prompts user)
REM ===================================
echo [5/8] Checking output directories...

set "clean_outputs=n"
if exist "outputs" (
    echo.
    echo Found output directory with generated images.
    echo This may contain your generated artwork.
    echo.
    set /p "clean_outputs=Do you want to clean output directories? (y/N): "
)

if /i "!clean_outputs!"=="y" (
    echo   Cleaning output directories...
    if exist "outputs" (
        for /r outputs %%f in (*) do (
            echo   Removing: %%f
            del /q "%%f" 2>nul
            if not exist "%%f" set /a "files_deleted+=1"
        )
        for /r outputs %%d in (.) do (
            if "%%d" neq "outputs" (
                rmdir "%%d" 2>nul
                if not exist "%%d" set /a "dirs_deleted+=1"
            )
        )
    )
) else (
    echo   Skipping output directories (user choice)
)

REM ===================================
REM Clean extension caches (but preserve configs)
REM ===================================
echo [6/9] Cleaning extension caches...

for /d %%d in (extensions\*) do (
    if exist "%%d\__pycache__" (
        echo   Removing: %%d\__pycache__
        rmdir /s /q "%%d\__pycache__" 2>nul
        if not exist "%%d\__pycache__" set /a "dirs_deleted+=1"
    )
    
    REM Clean .git temp files but preserve .git repos
    if exist "%%d\.git\logs" (
        del /q "%%d\.git\logs\*" 2>nul
    )
    
    REM Clean CivitAI Aria2 temp files
    if exist "%%d\aria2\running" (
        echo   Removing: %%d\aria2\running
        del /q "%%d\aria2\running" 2>nul
        if not exist "%%d\aria2\running" set /a "files_deleted+=1"
    )
)

REM ===================================
REM Clean Aria2 download temp files
REM ===================================
echo [7/9] Cleaning Aria2 download temp files...

for /r . %%f in (*.aria2) do (
    if exist "%%f" (
        echo   Removing: %%f
        del /q "%%f" 2>nul
        if not exist "%%f" set /a "files_deleted+=1"
    )
)

for /r . %%f in (*.part) do (
    if exist "%%f" (
        echo   Removing: %%f
        del /q "%%f" 2>nul
        if not exist "%%f" set /a "files_deleted+=1"
    )
)

REM ===================================
REM Clean browser cache files
REM ===================================
echo [8/9] Cleaning UI cache files...

REM Clean any stale JavaScript cache or compiled files
for %%f in (*.css.map *.js.map) do (
    if exist "%%f" (
        echo   Removing: %%f
        del /q "%%f" 2>nul
        if not exist "%%f" set /a "files_deleted+=1"
    )
)

REM ===================================
REM Summary
REM ===================================
echo [9/9] Cleanup complete!
echo.
echo ===============================================
echo  Cleanup Summary
echo ===============================================
echo Files deleted: !files_deleted!
echo Directories deleted: !dirs_deleted!
echo.

REM ===================================
REM Preserve important caches
REM ===================================
echo The following caches were PRESERVED for performance:
echo   ✓ cache/hashes/ - Model file hashes
echo   ✓ cache/safetensors-metadata/ - Model metadata
echo   ✓ repositories/ - Git repositories
echo   ✓ venv/ - Python environment
echo   ✓ Extension configurations
echo   ✓ CivitAI settings and configurations
echo.

REM ===================================
REM Start WebUI
REM ===================================
echo ===============================================
echo  Starting Stable Diffusion WebUI
echo ===============================================
echo.

REM Check if webui-user.bat exists for custom settings
if exist "webui-user.bat" (
    echo Using custom settings from webui-user.bat...
    call webui-user.bat
) else (
    echo Starting with default settings...
    call webui.bat
)

REM ===================================
REM Cleanup on exit (optional)
REM ===================================
echo.
echo ===============================================
echo  WebUI has closed
echo ===============================================

set "clean_on_exit=n"
echo.
set /p "clean_on_exit=Clean temporary files on exit? (y/N): "

if /i "!clean_on_exit!"=="y" (
    echo Performing exit cleanup...
    
    REM Clean session temp files
    if exist "tmp" (
        for %%f in (tmp\*.txt tmp\*.log) do (
            if exist "%%f" del /q "%%f" 2>nul
        )
    )
    
    REM Clean any new gradio temp files
    if exist "%TEMP%\gradio" (
        rmdir /s /q "%TEMP%\gradio" 2>nul
    )
    
    echo Exit cleanup complete.
)

echo.
echo Press any key to exit...
pause >nul