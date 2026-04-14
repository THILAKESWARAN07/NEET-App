param(
    [switch]$RunServer,
    [switch]$RunSmokeTest
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $repoRoot "backend"
$venvPython = Join-Path $backendDir ".venv\Scripts\python.exe"
$envFile = Join-Path $backendDir ".env"
$envExampleFile = Join-Path $backendDir ".env.example"

if (-not (Test-Path $venvPython)) {
    Write-Host "Creating backend virtual environment..."
    Set-Location $backendDir
    python -m venv .venv
}

if (-not (Test-Path $envFile)) {
    Write-Host "Creating backend .env from .env.example..."
    Copy-Item $envExampleFile $envFile -Force
}

Write-Host "Installing backend dependencies..."
Set-Location $backendDir
& $venvPython -m pip install -r requirements.txt

Write-Host "Applying migrations..."
& $venvPython -m alembic upgrade head

Write-Host "Running backend tests..."
& $venvPython -m pytest

if ($RunSmokeTest) {
    Write-Host "Running API smoke test script..."
    Set-Location $repoRoot
    & $venvPython test_api.py
}

if ($RunServer) {
    Write-Host "Starting backend server on port 8000..."
    Set-Location $backendDir
    & $venvPython -m uvicorn app.main:app --host 0.0.0.0 --port 8000
}

Write-Host "Bootstrap completed successfully."
