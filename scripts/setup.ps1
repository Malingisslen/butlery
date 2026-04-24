# Butlery Development Environment Setup Script (Windows)
# Usage: .\scripts\setup.ps1

$ErrorActionPreference = "Stop"

$REQUIRED_FLUTTER = "3.32.4"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir

Write-Host "========================================"
Write-Host "  Butlery Development Setup"
Write-Host "========================================"
Write-Host ""

Set-Location $ProjectDir

# Check Flutter installation
try {
    $flutterVersion = (flutter --version 2>$null | Select-String -Pattern '\d+\.\d+\.\d+' | ForEach-Object { $_.Matches[0].Value } | Select-Object -First 1)
    if (-not $flutterVersion) {
        throw "Could not determine Flutter version"
    }
} catch {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Install Flutter from: https://flutter.dev/docs/get-started/install"
    exit 1
}

# Verify Flutter version
if ($flutterVersion -ne $REQUIRED_FLUTTER) {
    Write-Host "WARNING: Flutter version mismatch" -ForegroundColor Yellow
    Write-Host "  Expected: $REQUIRED_FLUTTER"
    Write-Host "  Found:    $flutterVersion"
    Write-Host "  CI uses Flutter $REQUIRED_FLUTTER - consider switching versions"
    Write-Host ""
} else {
    Write-Host "Flutter version: $flutterVersion" -ForegroundColor Green
}

# Environment file setup
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "Created .env from .env.example - fill in real credentials before running the app" -ForegroundColor Green
    } else {
        Write-Host "WARNING: No .env.example found, skipping .env creation" -ForegroundColor Yellow
    }
} else {
    Write-Host ".env already exists"
}

# Install Flutter dependencies
Write-Host ""
Write-Host "Installing dependencies..."
flutter pub get
Write-Host "Dependencies installed" -ForegroundColor Green

# Install Lefthook for pre-commit hooks
Write-Host ""
$lefthookPath = Get-Command lefthook -ErrorAction SilentlyContinue
if ($lefthookPath) {
    Write-Host "Installing pre-commit hooks..."
    lefthook install
    Write-Host "Pre-commit hooks installed" -ForegroundColor Green
} else {
    Write-Host "NOTE: Lefthook not found. Install it for pre-commit hooks:" -ForegroundColor Yellow
    Write-Host "  npm install -g lefthook"
    Write-Host "  Then run: lefthook install"
}

# Run Flutter analyze to verify setup
Write-Host ""
Write-Host "Verifying setup with Flutter analyze..."
$analyzeResult = flutter analyze --no-fatal-infos 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Analysis passed" -ForegroundColor Green
} else {
    Write-Host "WARNING: Some analysis issues found (non-fatal)" -ForegroundColor Yellow
}

# Check for Firebase CLI
Write-Host ""
$firebasePath = Get-Command firebase -ErrorAction SilentlyContinue
if ($firebasePath) {
    $firebaseVersion = firebase --version
    Write-Host "Firebase CLI: $firebaseVersion" -ForegroundColor Green
} else {
    Write-Host "NOTE: Firebase CLI not found. Install for integration tests:" -ForegroundColor Yellow
    Write-Host "  npm install -g firebase-tools"
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Run tests: flutter test"
Write-Host "  2. Start emulator and run: flutter run"
Write-Host "  3. For integration tests: firebase emulators:start"
Write-Host ""
