$ErrorActionPreference = "Stop"
Write-Host "Creating virtual environment..." -ForegroundColor Cyan
py -3.11 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
Write-Host "Installing PyTorch CPU build (offline inference after installation)..." -ForegroundColor Cyan
.\.venv\Scripts\python.exe -m pip install torch --index-url https://download.pytorch.org/whl/cpu
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
Write-Host "Installation complete. Run: .\.venv\Scripts\python.exe run.py" -ForegroundColor Green
