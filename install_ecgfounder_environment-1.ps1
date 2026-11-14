$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-Step($Message) {
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

try {
    Set-Location $PSScriptRoot
    Write-Host 'ECGFounder Offline Web - Environment Setup' -ForegroundColor Green
    Write-Host "Project folder: $PSScriptRoot"

    # 1) Find Python 3.11, or install it for the current Windows user.
    Write-Step 'Checking Python 3.11'
    $pythonExe = $null

    $launcher = Get-Command py -ErrorAction SilentlyContinue
    if ($launcher) {
        & py -3.11 --version *> $null
        if ($LASTEXITCODE -eq 0) {
            $pythonExe = 'py'
        }
    }

    if (-not $pythonExe) {
        $candidates = @(
            "$env:LocalAppData\Programs\Python\Python311\python.exe",
            "$env:ProgramFiles\Python311\python.exe",
            'C:\Python311\python.exe'
        )
        foreach ($candidate in $candidates) {
            if (Test-Path $candidate) {
                & $candidate --version *> $null
                if ($LASTEXITCODE -eq 0) { $pythonExe = $candidate; break }
            }
        }
    }

    if (-not $pythonExe) {
        Write-Host 'Python 3.11 was not found. Downloading the official Python 3.11.9 installer...' -ForegroundColor Yellow
        $installer = Join-Path $env:TEMP 'python-3.11.9-amd64.exe'
        $url = 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $installer

        Write-Host 'Installing Python 3.11.9 for the current Windows user...' -ForegroundColor Yellow
        $process = Start-Process -FilePath $installer -ArgumentList @('/quiet','InstallAllUsers=0','PrependPath=1','Include_launcher=1','Include_pip=1','Include_test=0') -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Python installer failed with exit code $($process.ExitCode)."
        }
        $pythonExe = "$env:LocalAppData\Programs\Python\Python311\python.exe"
        if (-not (Test-Path $pythonExe)) {
            throw 'Python installer completed, but python.exe was not found in the expected installation folder.'
        }
    }

    if ($pythonExe -eq 'py') {
        & py -3.11 --version
        $venvCommand = { & py -3.11 -m venv .venv }
    } else {
        & $pythonExe --version
        $venvCommand = { & $pythonExe -m venv .venv }
    }

    # 2) Create the virtual environment.
    Write-Step 'Creating virtual environment'
    if (Test-Path '.venv') {
        Write-Host 'Removing an incomplete or previous .venv...' -ForegroundColor Yellow
        Remove-Item '.venv' -Recurse -Force
    }
    & $venvCommand
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path '.venv\Scripts\python.exe')) {
        throw 'Could not create the virtual environment.'
    }

    $venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'

    # 3) Install PyTorch CPU and project dependencies.
    Write-Step 'Upgrading pip'
    & $venvPython -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw 'pip upgrade failed.' }

    Write-Step 'Installing PyTorch CPU build'
    & $venvPython -m pip install torch --index-url https://download.pytorch.org/whl/cpu
    if ($LASTEXITCODE -ne 0) { throw 'PyTorch installation failed. Check your internet connection and run this script again.' }

    Write-Step 'Installing project requirements'
    & $venvPython -m pip install -r (Join-Path $PSScriptRoot 'requirements.txt')
    if ($LASTEXITCODE -ne 0) { throw 'Project requirements installation failed.' }

    # 4) Verify core imports.
    Write-Step 'Verifying installation'
    & $venvPython -c "import torch, fastapi, uvicorn, numpy; print('PyTorch:', torch.__version__); print('CUDA available:', torch.cuda.is_available()); print('FastAPI:', fastapi.__version__); print('NumPy:', numpy.__version__)"
    if ($LASTEXITCODE -ne 0) { throw 'The final import verification failed.' }

    Write-Host "`nINSTALLATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host 'Now run: .\start_windows.bat' -ForegroundColor Green
    Write-Host 'Then open: http://127.0.0.1:8000' -ForegroundColor Green
}
catch {
    Write-Host "`nSETUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Keep this PowerShell window open and send me the error text.' -ForegroundColor Yellow
    exit 1
}
