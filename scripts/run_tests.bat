@echo off
REM Script to run tests on Windows with proper separation of unit and integration tests
REM Usage: scripts\run_tests.bat [unit|integration|all]

setlocal enabledelayedexpansion

REM Colors not easily supported in batch, using plain text
set TEST_TYPE=%1
if "%TEST_TYPE%"=="" set TEST_TYPE=all

echo ========================================
echo Flutter Test Runner
echo ========================================
echo.

if "%TEST_TYPE%"=="unit" goto :run_unit_tests
if "%TEST_TYPE%"=="integration" goto :run_integration_tests
if "%TEST_TYPE%"=="all" goto :run_all_tests
goto :invalid_type

:run_unit_tests
echo [INFO] Running unit tests (excluding integration tests)...
flutter test --exclude-tags=integration
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Unit tests failed!
    exit /b %ERRORLEVEL%
)
echo [INFO] Unit tests passed!
goto :end

:run_integration_tests
echo [INFO] Running integration tests...

REM Check if Firebase CLI is installed
where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Firebase CLI not found. Please install it with: npm install -g firebase-tools
    exit /b 1
)

echo [INFO] Starting Firebase emulator...

REM Create minimal firebase.json if it doesn't exist
if not exist firebase.json (
    echo [INFO] Creating minimal firebase.json...
    (
        echo {
        echo   "emulators": {
        echo     "auth": {
        echo       "port": 9099
        echo     },
        echo     "firestore": {
        echo       "port": 8080
        echo     },
        echo     "storage": {
        echo       "port": 9199
        echo     },
        echo     "ui": {
        echo       "enabled": true,
        echo       "port": 4000
        echo     }
        echo   }
        echo }
    ) > firebase.json
)

REM Start emulator in new window
start /b firebase emulators:start --only auth,firestore,storage

REM Wait for emulator to be ready
echo [INFO] Waiting for emulator to be ready...
timeout /t 10 /nobreak >nul

REM Run integration tests
flutter test --tags=integration
set TEST_EXIT_CODE=%ERRORLEVEL%

REM Stop emulator
echo [INFO] Stopping Firebase emulator...
taskkill /f /im firebase.exe >nul 2>nul
taskkill /f /im node.exe /fi "WINDOWTITLE eq Firebase Emulator*" >nul 2>nul

if %TEST_EXIT_CODE% NEQ 0 (
    echo [ERROR] Integration tests failed!
    exit /b %TEST_EXIT_CODE%
)
echo [INFO] Integration tests passed!
goto :end

:run_all_tests
echo [INFO] Running all tests...
echo.
echo === UNIT TESTS ===
call :run_unit_tests_sub
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo.
echo === INTEGRATION TESTS ===
call :run_integration_tests_sub
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo.
echo [INFO] All tests passed!
goto :end

:run_unit_tests_sub
echo [INFO] Running unit tests (excluding integration tests)...
flutter test --exclude-tags=integration
exit /b %ERRORLEVEL%

:run_integration_tests_sub
echo [INFO] Running integration tests...

where firebase >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [WARNING] Firebase CLI not found. Please install it with: npm install -g firebase-tools
    exit /b 1
)

if not exist firebase.json (
    echo [INFO] Creating minimal firebase.json...
    (
        echo {
        echo   "emulators": {
        echo     "auth": {
        echo       "port": 9099
        echo     },
        echo     "firestore": {
        echo       "port": 8080
        echo     },
        echo     "storage": {
        echo       "port": 9199
        echo     },
        echo     "ui": {
        echo       "enabled": true,
        echo       "port": 4000
        echo     }
        echo   }
        echo }
    ) > firebase.json
)

start /b firebase emulators:start --only auth,firestore,storage
timeout /t 10 /nobreak >nul

flutter test --tags=integration
set TEST_EXIT_CODE=%ERRORLEVEL%

taskkill /f /im firebase.exe >nul 2>nul
taskkill /f /im node.exe /fi "WINDOWTITLE eq Firebase Emulator*" >nul 2>nul

exit /b %TEST_EXIT_CODE%

:invalid_type
echo [ERROR] Invalid test type: %TEST_TYPE%
echo Usage: %0 [unit^|integration^|all]
exit /b 1

:end
endlocal