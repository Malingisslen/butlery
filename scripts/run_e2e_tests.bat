@echo off
REM E2E Test Execution Batch Script for Butlery Flutter Application (Windows)
REM
REM Simple Windows wrapper that calls the main bash script
REM All functionality is handled by the bash script for consistency

echo [INFO] Butlery E2E Test Runner - Windows
echo [INFO] Calling bash script with arguments: %*

REM Check if WSL is available
where wsl >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo [INFO] Using WSL bash to execute E2E tests...
    wsl bash -c "cd /mnt/c/Butlery/butlery && ./scripts/run_e2e_tests.sh %*"
) else (
    REM Check if Git Bash is available
    where bash >nul 2>&1
    if %ERRORLEVEL% == 0 (
        echo [INFO] Using Git Bash to execute E2E tests...
        bash ./scripts/run_e2e_tests.sh %*
    ) else (
        echo [ERROR] Neither WSL nor Git Bash found. Please install one of:
        echo   1. Windows Subsystem for Linux (WSL)
        echo   2. Git for Windows (includes Git Bash)
        echo.
        echo Or run the tests directly with Flutter:
        echo   flutter test test/e2e/flows/comprehensive_e2e_test.dart
        exit /b 1
    )
)

echo [INFO] E2E test execution completed.