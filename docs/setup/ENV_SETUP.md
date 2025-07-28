# Environment Configuration Setup

## Overview
Firebase API keys and sensitive configuration values are now stored in environment files instead of being hardcoded in the source code. This improves security by keeping sensitive information out of version control.

## Environment Files
The project uses three environment files:
- `.env.development` - Development environment configuration
- `.env.staging` - Staging environment configuration  
- `.env.production` - Production environment configuration

**⚠️ IMPORTANT: These files contain sensitive API keys and should NEVER be committed to version control!**

## Setup Instructions

### 1. Environment Files
The environment files have been created with your current Firebase configuration. Each file contains:
- Platform-specific API keys (Web, Android, iOS, macOS, Windows)
- Firebase project configuration
- Environment identifier

### 2. Running the App

#### Development (default)
```bash
flutter run
```

#### Staging
```bash
flutter run --dart-define=ENV=staging
```

#### Production
```bash
flutter run --dart-define=ENV=production
```

### 3. Building for Release

#### Android
```bash
# Development
flutter build apk --dart-define=ENV=development

# Staging
flutter build apk --dart-define=ENV=staging

# Production
flutter build apk --release --dart-define=ENV=production
```

#### iOS
```bash
# Development
flutter build ios --dart-define=ENV=development

# Staging
flutter build ios --dart-define=ENV=staging

# Production
flutter build ios --release --dart-define=ENV=production
```

## Firebase Console Configuration

### API Key Restrictions (REQUIRED for Production)
You must add restrictions to your API keys in the Firebase Console:

1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Select your Firebase project
3. For each API key, click on it and add restrictions:

#### Android API Key
- Application restrictions: Android apps
- Add your app's SHA-1 fingerprint
- Package name: `com.example.butlery`

#### iOS API Key  
- Application restrictions: iOS apps
- Bundle ID: `com.example.butlery`

#### Web API Key
- Application restrictions: HTTP referrers
- Add your allowed domains:
  - `localhost:*` (for development)
  - `yourdomain.com/*` (for production)

## Security Best Practices

1. **Never commit .env files** - Already added to .gitignore
2. **Use different Firebase projects** for dev/staging/production
3. **Rotate API keys regularly**
4. **Monitor API usage** in Firebase Console
5. **Enable App Check** for additional security

## Troubleshooting

### Missing Environment Variables Error
If you see "Missing required environment variable" errors:
1. Ensure the .env files exist in the project root
2. Check that all required variables are defined
3. Verify the file is included in pubspec.yaml assets

### Environment Not Loading
If the wrong environment loads:
1. Check the --dart-define=ENV parameter
2. Ensure you've run `flutter clean` after changing environments
3. Verify the .env.{environment} file exists

## CI/CD Configuration

For CI/CD pipelines, store environment variables as secrets:

### GitHub Actions
```yaml
env:
  FIREBASE_API_KEY_ANDROID: ${{ secrets.FIREBASE_API_KEY_ANDROID }}
  FIREBASE_API_KEY_IOS: ${{ secrets.FIREBASE_API_KEY_IOS }}
  # ... other secrets
```

### Local Development
For team members, share .env files securely via:
- Encrypted password manager
- Secure file sharing service
- NOT via email, Slack, or version control

## Migration Notes
The Firebase configuration has been migrated from hardcoded values in `firebase_options.dart` to environment-based configuration. The original values are preserved in the .env files for reference.