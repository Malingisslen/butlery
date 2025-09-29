@echo off
REM 🔧 User Counter Migration Runner Script (Windows)
REM 
REM Convenience script for running the user counter migration
REM Handles Flutter environment setup and provides easy access to migration options

echo 🔧 User Counter Migration Runner
echo ================================

REM Check if Firebase is configured
if not exist "lib\firebase_options.dart" (
    echo ❌ Error: firebase_options.dart not found
    echo 💡 Run 'flutterfire configure' first to set up Firebase
    exit /b 1
)

REM Function to show available commands
if "%1"=="help" goto :show_help
if "%1"=="" goto :show_help

if "%1"=="dry-run" (
    echo 🔍 Running migration in DRY RUN mode ^(no changes will be applied^)
    echo.
    dart tools/migrate_user_counters.dart --dry-run
    goto :end
)

if "%1"=="apply" (
    echo ⚠️  WARNING: This will modify user data in production!
    echo Make sure you've tested with 'dry-run' first.
    echo.
    set /p confirm="Continue? (y/N): "
    if /i "%confirm%"=="y" (
        dart tools/migrate_user_counters.dart --apply
    ) else (
        echo Operation cancelled
    )
    goto :end
)

:show_help
echo.
echo USAGE:
echo   migrate_counters.bat [COMMAND]
echo.
echo COMMANDS:
echo   dry-run       Preview changes without applying ^(recommended first step^)
echo   apply         Apply changes to production database
echo   help          Show this help message
echo.
echo EXAMPLES:
echo   migrate_counters.bat dry-run       # Test migration safely
echo   migrate_counters.bat apply         # Apply changes to production
echo.
echo SAFETY:
echo   - Always run 'dry-run' first to preview changes
echo   - Script is idempotent ^(safe to run multiple times^)
echo   - Includes comprehensive error handling

:end
echo.
echo ✅ Migration runner completed
pause