
# ==========================================================
# ECGFounder Offline Web
# Windows 11 - Python 3.11.9
# Automatic Environment Repair, Installation and Startup
# ==========================================================

$ErrorActionPreference = "Stop"

$Project = "D:\AI\ECGFounder_Offline_Web"
$Venv = Join-Path $Project ".venv"
$Requirements = Join-Path $Project "requirements.txt"
$Model = Join-Path $Project "models\best_ecgfounder_ptbxl.pth"
$StartFile = Join-Path $Project "start_windows.bat"

function Step($Message) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Fail($Message) {
    Write-Host "`nERROR: $Message" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    # 1. Check project files
    Step "1. Checking project files"

    if (!(Test-Path $Project)) {
        Fail "Project folder not found: $Project"
    }

    if (!(Test-Path $Requirements)) {
        Fail "requirements.txt not found"
    }

    if (!(Test-Path $Model)) {
        Fail "Trained ECGFounder model not found"
    }

    if (!(Test-Path $StartFile)) {
        Fail "start_windows.bat not found"
    }

    Set-Location $Project

    Write-Host "Project files found." -ForegroundColor Green

    # 2. Clean Python environment variables
    Step "2. Cleaning Python environment conflicts"

    Remove-Item Env:PYTHONHOME -ErrorAction SilentlyContinue
    Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue

    # Remove Python 3.13 directories from this process PATH
    $env:Path = (($env:Path -split ';') |
        Where-Object {
            $_ -and $_ -notmatch 'Python313|Python3\.13'
        }) -join ';'

    # 3. Locate Python 3.11
    Step "3. Locating Python 3.11"

    $Launcher = Get-Command py.exe -ErrorAction SilentlyContinue

    if (!$Launcher) {
        Fail "Python Launcher py.exe not found"
    }

    $BasePython = (& $Launcher.Source -3.11 -c `
        "import sys; print(sys.executable)" 2>&1 |
        Select-Object -Last 1).ToString().Trim()

    if (!(Test-Path $BasePython)) {
        Fail "Python 3.11 executable not found: $BasePython"
    }

    Write-Host "Python executable: $BasePython" -ForegroundColor Green

    # 4. Test base Python before deleting existing environment
    Step "4. Testing Python installation"

    & $BasePython -c "import sys, socket, ssl, sqlite3; print(sys.version); print('Python standard libraries OK')"

    if ($LASTEXITCODE -ne 0) {
        Fail "Base Python has a DLL conflict. Repair Python 3.11 installation first."
    }

    # 5. Rebuild virtual environment
    Step "5. Rebuilding virtual environment"

    if (Test-Path $Venv) {
        Write-Host "Removing old virtual environment..."
        Remove-Item $Venv -Recurse -Force
    }

    & $BasePython -m venv $Venv

    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to create virtual environment"
    }

    $Python = Join-Path $Venv "Scripts\python.exe"

    if (!(Test-Path $Python)) {
        Fail "Virtual environment Python was not created"
    }

    # 6. Initialize pip
    Step "6. Initializing pip"

    & $Python -m ensurepip --upgrade

    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to initialize pip"
    }

    & $Python -m pip install --upgrade pip setuptools wheel

    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to upgrade pip"
    }

    # 7. Install project requirements
    Step "7. Installing project dependencies"

    Write-Host "Internet connection may be required for first installation." -ForegroundColor Yellow

    & $Python -m pip install -r $Requirements

    if ($LASTEXITCODE -ne 0) {
        Fail "Dependency installation failed. Check the pip error above."
    }

    # 8. Verify Python and pip
    Step "8. Verifying environment"

    & $Python -c "import sys, pip; print('Python:', sys.version); print('Executable:', sys.executable); print('Pip:', pip.__version__)"

    if ($LASTEXITCODE -ne 0) {
        Fail "Environment verification failed"
    }

    # 9. Verify project dependencies
    Step "9. Checking installed dependencies"

    & $Python -m pip check

    if ($LASTEXITCODE -ne 0) {
        Fail "Dependency conflicts detected"
    }

    # 10. Start the application
    Step "10. Starting ECGFounder Web"

    Write-Host "Starting application..." -ForegroundColor Green
    Write-Host "URL: http://127.0.0.1:8000" -ForegroundColor Green

    Write-Host "`nPress CTRL+C to stop the server." -ForegroundColor Yellow

    cmd.exe /c "start_windows.bat"

}
catch {
    Write-Host "`nUnexpected error:" -ForegroundColor Red
    Write-Host $_ -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
