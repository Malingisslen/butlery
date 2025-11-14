# Secrets Management Guide

## Overview

Butlery uses environment-based configuration to manage sensitive credentials securely. All API keys, Firebase credentials, and other secrets are stored in `.env` files that are **never committed to version control**.

**Security Status**: ✅ Production-ready (Issue #003 resolved - January 2025)

## Quick Start for Developers

### Initial Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env.development
   ```

2. **Request credentials:**
   - Contact the team lead for development Firebase credentials
   - Or use your own Firebase project for local development

3. **Verify setup:**
   ```bash
   flutter run
   ```
   App should launch without errors. If you see Firebase initialization errors, check your `.env` file.

### Environment Files

| File | Purpose | Committed to Git? |
|------|---------|-------------------|
| `.env.example` | Template showing required variables | ✅ Yes (no real values) |
| `.env.development` | Local development credentials | ❌ No (.gitignored) |
| `.env.staging` | Staging environment credentials | ❌ No (.gitignored) |
| `.env.production` | Production credentials | ❌ No (.gitignored) |

## Required Environment Variables

### Firebase Configuration (Platform-Specific)

```bash
# Web Platform
FIREBASE_API_KEY_WEB=your_web_api_key
FIREBASE_APP_ID_WEB=your_web_app_id
FIREBASE_MESSAGING_SENDER_ID_WEB=your_messaging_sender_id

# Android Platform
FIREBASE_API_KEY_ANDROID=your_android_api_key
FIREBASE_APP_ID_ANDROID=your_android_app_id
FIREBASE_MESSAGING_SENDER_ID_ANDROID=your_messaging_sender_id

# iOS Platform
FIREBASE_API_KEY_IOS=your_ios_api_key
FIREBASE_APP_ID_IOS=your_ios_app_id
FIREBASE_MESSAGING_SENDER_ID_IOS=your_messaging_sender_id
FIREBASE_IOS_BUNDLE_ID=your_ios_bundle_id

# macOS Platform
FIREBASE_API_KEY_MACOS=your_macos_api_key
FIREBASE_APP_ID_MACOS=your_macos_app_id
FIREBASE_MESSAGING_SENDER_ID_MACOS=your_messaging_sender_id
FIREBASE_MACOS_BUNDLE_ID=your_macos_bundle_id

# Windows Platform
FIREBASE_API_KEY_WINDOWS=your_windows_api_key
FIREBASE_APP_ID_WINDOWS=your_windows_app_id
FIREBASE_MESSAGING_SENDER_ID_WINDOWS=your_messaging_sender_id

# Shared Firebase Configuration
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_STORAGE_BUCKET=your_storage_bucket
FIREBASE_AUTH_DOMAIN=your_auth_domain
```

### Other Services

```bash
# OCR Service (Image text extraction)
OCR_API_KEY=your_ocr_api_key

# Add other service credentials as needed
```

## How It Works

### 1. Environment Loading (`lib/main.dart`)

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Load environment variables from .env file
  await dotenv.load(fileName: '.env.development');

  // Initialize Firebase with environment-based config
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
```

### 2. Firebase Configuration (`lib/firebase_options.dart`)

```dart
// Reads platform-specific credentials from environment
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Platform detection and environment variable reading...
  }
}
```

### 3. Environment Variable Access

```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Read environment variable
final apiKey = dotenv.env['OCR_API_KEY'] ?? '';
```

## Security Best Practices

### ✅ DO

- ✅ **Use .env files** for all sensitive credentials
- ✅ **Keep .env files locally** - never commit them
- ✅ **Use .env.example** as a template for required variables
- ✅ **Rotate credentials** immediately if exposed
- ✅ **Use different credentials** for each environment (dev, staging, prod)
- ✅ **Request credentials** from team lead for official environments
- ✅ **Verify .gitignore** includes all .env patterns before committing

### ❌ DON'T

- ❌ **Never hardcode credentials** in source code
- ❌ **Never commit .env files** to version control
- ❌ **Never share credentials** in chat, email, or docs
- ❌ **Never use production credentials** in development
- ❌ **Never create files like `firebase_options_real.dart`** with hardcoded keys
- ❌ **Never push credentials** to public repositories

## CI/CD Configuration

### GitHub Actions Setup

For CI/CD pipelines, inject environment variables as repository secrets:

1. **Go to Repository Settings** → Secrets and variables → Actions
2. **Add secrets** for each environment variable:
   - `FIREBASE_API_KEY_WEB`
   - `FIREBASE_API_KEY_ANDROID`
   - (etc.)

3. **Inject in workflow** (`.github/workflows/test.yml`):
   ```yaml
   - name: Create .env file
     run: |
       echo "FIREBASE_API_KEY_WEB=${{ secrets.FIREBASE_API_KEY_WEB }}" >> .env.development
       echo "FIREBASE_API_KEY_ANDROID=${{ secrets.FIREBASE_API_KEY_ANDROID }}" >> .env.development
       # ... (add all required variables)

   - name: Run tests
     run: flutter test
   ```

## Credential Rotation Procedure

If credentials are exposed (committed to git, shared publicly, etc.):

### 1. Immediate Actions (< 1 hour)

1. **Revoke exposed credentials** in Firebase Console:
   - Go to Project Settings → General
   - Regenerate API keys
   - Update OAuth 2.0 credentials if needed

2. **Generate new credentials** for all platforms

3. **Update all environments:**
   ```bash
   # Update local development
   nano .env.development

   # Update CI/CD secrets (GitHub, etc.)
   # Update staging and production environments
   ```

### 2. Verification (< 30 minutes)

1. **Test locally:**
   ```bash
   flutter run
   # Verify authentication, Firestore, Storage work
   ```

2. **Test CI/CD pipeline:**
   - Trigger test workflow
   - Verify tests pass with new credentials

3. **Deploy to staging:**
   - Verify app functionality
   - Test critical flows (auth, data sync)

### 3. Cleanup

1. **Remove from git history** (if committed):
   ```bash
   # WARNING: Rewrites history - coordinate with team
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch lib/firebase_options_real.dart" \
     --prune-empty --tag-name-filter cat -- --all

   git push origin --force --all
   ```

2. **Update .gitignore** to prevent future exposure
3. **Document incident** in security log

## Git Protections

### Pre-commit Hook

The repository includes a pre-commit hook that prevents committing sensitive files:

```bash
# .git/hooks/pre-commit (auto-installed)
# Blocks commits containing:
# - .env files
# - firebase_options_real.dart
# - service-account-key.json
```

### .gitignore Patterns

```bash
# Environment variables - DO NOT COMMIT API KEYS
.env
.env.*
*.env
*.env.*

# Firebase config files - DO NOT COMMIT API KEYS
google-services.json
GoogleService-Info.plist
service-account-key.json
*firebase-adminsdk*.json

# Firebase options with hardcoded credentials - REDUNDANT PROTECTION
lib/firebase_options_real.dart
lib/**/firebase_options_real*.dart
```

## Troubleshooting

### "Firebase initialization failed"

**Cause**: Missing or invalid .env file

**Solution**:
1. Verify `.env.development` exists
2. Check all required Firebase variables are present
3. Verify API keys are valid (no typos, extra spaces)

### "Environment variable not found"

**Cause**: Variable not defined in .env file or typo in variable name

**Solution**:
1. Check variable name matches `.env.example`
2. Verify `.env` file is being loaded (check `main.dart`)
3. Restart app after changing .env file

### "Pre-commit hook blocks my commit"

**Cause**: Attempting to commit a .env file or hardcoded credentials

**Solution**:
1. Remove the file from staging: `git reset HEAD .env`
2. Verify .gitignore includes the file pattern
3. Never commit credentials - use environment variables

## Migration History

### January 2025 - Issue #003 Resolution

**Problem**: Production Firebase credentials exposed in public GitHub repository for 6 months via `lib/firebase_options_real.dart`.

**Solution**:
- ✅ Migrated to .env-based configuration system
- ✅ Removed hardcoded `firebase_options_real.dart`
- ✅ Added redundant .gitignore protections
- ✅ Verified pre-commit hooks prevent future exposure
- ✅ Documented secrets management process

**Impact**: Blocks production deployment vulnerability, enables secure multi-environment configuration.

## References

- **Flutter dotenv**: https://pub.dev/packages/flutter_dotenv
- **Firebase Setup**: https://firebase.google.com/docs/flutter/setup
- **OWASP Secrets Management**: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
- **Issue #003**: `docs/ultimate/MASTERPLAN.md`

## Support

For questions or issues with secrets management:
- **Development**: Contact team lead for credentials
- **CI/CD Issues**: Check GitHub Actions secrets configuration
- **Security Concerns**: Report immediately to team lead
