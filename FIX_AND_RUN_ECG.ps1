
# ECGFounder - Complete Windows Repair & Run
$ErrorActionPreference = "Stop"

$Project = "D:\AI\ECGFounder_Offline_Web"
$Venv = Join-Path $Project ".venv"
$Req = Join-Path $Project "requirements.txt"
$Model = Join-Path $Project "models\best_ecgfounder_ptbxl.pth"

function Stop-Setup($msg) {
    Write-Host "`nFAILED: $msg" -ForegroundColor Red
    Read-Host "Press Enter"
    exit 1
}

try {
    Write-Host "`n[1/8] Preparing project..." -ForegroundColor Cyan

    if (!(Test-Path $Project)) { Stop-Setup "Project not found" }
    if (!(Test-Path $Req)) { Stop-Setup "requirements.txt missing" }
    if (!(Test-Path $Model)) { Stop-Setup "Model checkpoint missing" }

    Set-Location $Project

    Write-Host "`n[2/8] Locating Python 3.11..." -ForegroundColor Cyan

    $Base = (& py -3.11 -c "import sys;print(sys.executable)" | Select-Object -Last 1).Trim()

    if (!(Test-Path $Base)) { Stop-Setup "Python 3.11 not found" }

    $PythonRoot = Split-Path $Base

    Write-Host "Using: $Base" -ForegroundColor Green

    # Remove Python and pip environment contamination
    Get-ChildItem Env: |
        Where-Object { $_.Name -like "PIP_*" } |
        ForEach-Object { Remove-Item "Env:$($_.Name)" }

    Remove-Item Env:PYTHONHOME -ErrorAction SilentlyContinue
    Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue

    # Use only trusted Python 3.11 and Windows directories
    $env:PATH = @(
        "$Venv\Scripts",
        "$PythonRoot",
        "$PythonRoot\Scripts",
        "$env:SystemRoot\System32",
        "$env:SystemRoot",
        "$env:SystemRoot\System32\Wbem"
    ) -join ";"

    # Disable old pip configuration and stale G: package locations
    $env:PIP_CONFIG_FILE = "NUL"
    $env:PIP_DISABLE_PIP_VERSION_CHECK = "1"

    Write-Host "`n[3/8] Testing Python DLL compatibility..." -ForegroundColor Cyan

    & $Base -c "import socket,ssl,sqlite3; print('Python DLL test OK')"
    if ($LASTEXITCODE -ne 0) { Stop-Setup "Python 3.11 DLL conflict remains" }

    # Ensure no conflicting Python 3.13 DLL in project root
    if (Test-Path (Join-Path $Project "python313.dll")) {
        Stop-Setup "python313.dll found in project root. Move it out before continuing."
    }

    Write-Host "`n[4/8] Recreating clean virtual environment..." -ForegroundColor Cyan

    if (Test-Path $Venv) {
        Remove-Item $Venv -Recurse -Force
    }

    & $Base -m venv $Venv
    if ($LASTEXITCODE -ne 0) { Stop-Setup "venv creation failed" }

    $Python = Join-Path $Venv "Scripts\python.exe"

    & $Python -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) { Stop-Setup "ensurepip failed" }

    Write-Host "`n[5/8] Installing pip and project dependencies..." -ForegroundColor Cyan

    & $Python -m pip --isolated install --no-cache-dir --upgrade pip setuptools wheel --index-url https://pypi.org/simple

    if ($LASTEXITCODE -ne 0) { Stop-Setup "pip installation failed" }

    & $Python -m pip --isolated install --no-cache-dir -r $Req --index-url https://pypi.org/simple

    if ($LASTEXITCODE -ne 0) { Stop-Setup "Project dependencies failed" }

    Write-Host "`n[6/8] Installing PyTorch CPU..." -ForegroundColor Cyan

    & $Python -m pip --isolated install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

    if ($LASTEXITCODE -ne 0) { Stop-Setup "PyTorch installation failed" }

    Write-Host "`n[7/8] Testing PyTorch and project..." -ForegroundColor Cyan

    & $Python -c "import torch; print('PyTorch:',torch.__version__); print('CUDA:',torch.cuda.is_available()); print('CPU:',torch.get_num_threads())"

    if ($LASTEXITCODE -ne 0) { Stop-Setup "PyTorch test failed" }

    & $Python -c "import backend.main; print('Backend import OK')"

    if ($LASTEXITCODE -ne 0) { Stop-Setup "Backend import failed. Check the missing module above." }

    Write-Host "`n[8/8] Starting ECGFounder..." -ForegroundColor Green

    Write-Host "Opening http://127.0.0.1:8000" -ForegroundColor Green

    Start-Process "http://127.0.0.1:8000"

    & $Python run.py

}
catch {
    Write-Host "`nERROR: $_" -ForegroundColor Red
    Read-Host "Press Enter"
    exit 1
}
