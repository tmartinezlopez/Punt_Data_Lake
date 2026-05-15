Param(
    [string]$PythonExe = "python"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating .venv..."
& $PythonExe -m venv .venv

Write-Host "Upgrading pip..."
& .\.venv\Scripts\python.exe -m pip install --upgrade pip

Write-Host "Installing requirements..."
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt

Write-Host "Installing local package..."
& .\.venv\Scripts\python.exe -m pip install -e . --no-deps

Write-Host "Done. Use .\.venv\Scripts\Activate.ps1"
