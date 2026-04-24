# Secrets Management Guide

## Overview

Butlery uses environment-based configuration to manage sensitive credentials. All API keys and third-party service credentials are stored in `.env` files that are **never committed to version control**, and injected into the build at compile time via `--dart-define-from-file`.

Firebase config files (`google-services.json`, `GoogleService-Info.plist`) are handled separately — they live in their native locations under `android/app/` and `ios/Runner/` and are also gitignored.

## Quick Start for Developers

### Initial Setup

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```
   (or run `./scripts/setup.sh` / `.\scripts\setup.ps1` which does this automatically)

2. **Request credentials:**
   - Contact the team lead for the real values
   - Fill them into `.env`

3. **Get Firebase platform configs:**
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`
   - Shared out-of-band (Signal, 1Password, AirDrop) — never via git/email/Slack

4. **Verify setup:**
   ```bash
   flutter run --dart-define-from-file=.env
   ```
   App should launch without errors.

### Environment Files

| File | Purpose | Committed to Git? |
|------|---------|-------------------|
| `.env.example` | Template showing required variables with placeholder values | ✅ Yes (no real values) |
| `.env` | Local dev + default build credentials | ❌ No (.gitignored) |
| `.env.staging` | Staging E2E test credentials (used by `main_e2e_staging.dart`) | ❌ No (.gitignored) |

## Required Environment Variables

See `.env.example` for the current authoritative list. Typical contents:

```bash
# OCR Service (photo import feature)
OCR_API_KEY=your_ocr_space_key

# Algolia Search (optional)
ALGOLIA_APP_ID=your_algolia_app_id
ALGOLIA_API_KEY=your_algolia_search_key

# Google Vision API (optional, fallback OCR)
GOOGLE_VISION_API_KEY=your_vision_key
```

Firebase platform credentials (API keys, app IDs) are **not** in `.env` — they come from `firebase_options.dart` (committed, client-safe keys) and the native `google-services.json` / `GoogleService-Info.plist` files.

## How It Works

### Compile-Time Injection

The app reads env vars via Dart's `String.fromEnvironment()`, which is resolved at **compile time** — the values are baked into the build artifact. They're passed via Flutter's `--dart-define-from-file` flag pointing at the `.env` file.

```dart
// lib/services/ocr_extraction_service.dart
return const String.fromEnvironment('OCR_SPACE_API_KEY');
```

### Build Commands

Local dev:
```bash
flutter run --dart-define-from-file=.env
```

CI builds (see `.github/workflows/build-validation.yml`):
```bash
flutter build appbundle --release --dart-define-from-file=.env
flutter build web --release --dart-define-from-file=.env
flutter build ipa --release --dart-define-from-file=.env --export-options-plist=ios/exportOptions.plist
```

E2E staging tests:
```bash
flutter test test/e2e/main_e2e_staging.dart --dart-define-from-file=.env.staging
```

## Security Best Practices

### ✅ DO

- Use `.env` files for all sensitive credentials
- Keep `.env` files locally — never commit them
- Use `.env.example` as the template for required variables
- Rotate credentials immediately if exposed
- Share credentials out-of-band (Signal, 1Password, AirDrop)

### ❌ DON'T

- Never hardcode credentials in source code
- Never commit `.env` files to version control
- Never share credentials in chat, email, or unencrypted channels
- Never create files like `firebase_options_real.dart` with hardcoded keys
- Never push credentials to public repositories

## CI/CD Configuration

GitHub Actions composes `.env` at build time from repository secrets:

1. **Go to Repository Settings** → Secrets and variables → Actions
2. **Add each required secret** (mirror the keys in `.env.example`)
3. **Inject into the workflow:**
   ```yaml
   - name: Create .env file
     run: |
       echo "OCR_API_KEY=${{ secrets.OCR_API_KEY }}" >> .env
       echo "ALGOLIA_APP_ID=${{ secrets.ALGOLIA_APP_ID }}" >> .env
       # ... add all required variables
   - name: Build
     run: flutter build appbundle --release --dart-define-from-file=.env
   ```

## Credential Rotation

If credentials are exposed (committed to git, shared publicly, etc.):

1. **Revoke exposed credentials** at the provider (Firebase Console, OCR.space, Algolia dashboard, etc.)
2. **Generate new credentials**
3. **Update locally:** edit `.env` with the new values
4. **Update CI:** update the corresponding GitHub Actions secrets
5. **Verify locally:** `flutter run --dart-define-from-file=.env`
6. **If committed accidentally:** rewrite git history with `git filter-repo` (coordinate before force-pushing)

## Git Protections

### .gitignore Patterns

```bash
# Env files - never commit
.env
.env.*
*.env
*.env.*

# Firebase native configs - never commit
google-services.json
GoogleService-Info.plist
android/app/google-services.json
ios/Runner/GoogleService-Info.plist

# Legacy hardcoded-credentials escape hatch - never create
lib/firebase_options_real.dart
lib/**/firebase_options_real*.dart
```

### Pre-commit Hook (lefthook)

The repo's lefthook config blocks commits containing `.env` files or files matching `firebase_options_real*.dart`.

## Troubleshooting

### "Environment variable not found" / OCR key is empty

**Cause**: `--dart-define-from-file=.env` flag was omitted, or the variable name in `.env` doesn't match the `String.fromEnvironment()` key in code.

**Solution**:
1. Verify you launched with `flutter run --dart-define-from-file=.env`
2. Check variable name matches (case-sensitive) what `String.fromEnvironment()` expects
3. Rebuild — `String.fromEnvironment` is compile-time, so hot reload won't pick up `.env` changes

### "Firebase initialization failed"

**Cause**: Missing `google-services.json` or `GoogleService-Info.plist`.

**Solution**:
1. Verify files exist at `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
2. Ask team lead to re-share them if missing

### "Pre-commit hook blocks my commit"

**Cause**: Attempting to commit a `.env` file or a `firebase_options_real*.dart` file.

**Solution**:
1. Remove the file from staging: `git reset HEAD .env`
2. Verify `.gitignore` includes the pattern
3. Never commit credentials — use env vars

## References

- **Flutter dart-define**: https://docs.flutter.dev/deployment/flavors#using-flutter-define
- **Firebase Setup**: https://firebase.google.com/docs/flutter/setup
- **OWASP Secrets Management**: https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html
