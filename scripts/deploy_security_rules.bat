@echo off
REM Firebase Security Rules Deployment Script for Butlery
REM This script deploys Firestore and Storage security rules to production

echo ========================================
echo Firebase Security Rules Deployment
echo ========================================
echo.

REM Check if Firebase CLI is installed
where firebase >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Firebase CLI is not installed.
    echo Please install it with: npm install -g firebase-tools
    echo.
    exit /b 1
)

REM Check if user is logged in
firebase projects:list >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Not logged in to Firebase.
    echo Please run: firebase login
    echo.
    exit /b 1
)

echo Current Firebase project:
firebase use
echo.

REM Confirm deployment
set /p CONFIRM="Deploy security rules to PRODUCTION? (yes/no): "
if /i not "%CONFIRM%"=="yes" (
    echo Deployment cancelled.
    exit /b 0
)

echo.
echo Deploying Firestore security rules...
firebase deploy --only firestore:rules

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Firestore rules deployment failed!
    exit /b 1
)

echo.
echo Deploying Storage security rules...
firebase deploy --only storage:rules

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Storage rules deployment failed!
    exit /b 1
)

echo.
echo ========================================
echo Deployment completed successfully!
echo ========================================
echo.
echo IMPORTANT: Security rules are now active in production.
echo Please verify the deployment:
echo 1. Check Firebase Console ^> Firestore ^> Rules
echo 2. Check Firebase Console ^> Storage ^> Rules
echo 3. Run integration tests to verify functionality
echo.

pause
