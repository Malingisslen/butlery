# CI/CD Quick Wins Checklist

**Priority Actions (1-2 weeks)**

---

## Critical (Must Do Before Release)

### 1. Configure Production Android Signing
- [ ] Generate production keystore:
  ```bash
  keytool -genkey -v -keystore butlery-release-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias butlery-release
  ```
- [ ] Create `android/key.properties`:
  ```properties
  storePassword=<password>
  keyPassword=<password>
  keyAlias=butlery-release
  storeFile=../butlery-release-key.jks
  ```
- [ ] Update `android/app/build.gradle.kts` for release signing
- [ ] Store keystore securely (NOT in git)
- [ ] Backup keystore and credentials

### 2. Change Package Name
- [ ] Replace `com.example.butlery` with unique identifier
- [ ] Update `android/app/build.gradle.kts` namespace
- [ ] Update `android/app/src/main/AndroidManifest.xml` package
- [ ] Update Firebase configuration
- [ ] Regenerate `google-services.json`

### 3. Enable Minification
- [ ] In `android/app/build.gradle.kts`, set for release:
  ```kotlin
  isMinifyEnabled = true
  isShrinkResources = true
  ```
- [ ] Test ProGuard rules don't break Firebase/app
- [ ] Verify APK size reduction

---

## High Priority (This Sprint)

### 4. Archive Legacy Workflow
- [ ] Delete or rename `.github/workflows/flutter_ci.yml` to `.flutter_ci.yml.disabled`
- [ ] Document reason in commit message

### 5. Add .gitignore Entries
- [ ] Add `google-services.json` to `.gitignore` (use template)
- [ ] Ensure `key.properties` is in `.gitignore`
- [ ] Ensure `*.keystore` and `*.jks` are in `.gitignore`

### 6. Create Release Build Job
- [ ] Add release build step to `build-validation.yml`:
  ```yaml
  - name: Build Release APK
    run: flutter build apk --release
  ```
- [ ] Upload release APK as artifact

---

## Medium Priority (Next Sprint)

### 7. Add Pre-commit Hooks
- [ ] Install lefthook: `dart pub global activate lefthook`
- [ ] Create `lefthook.yml`:
  ```yaml
  pre-commit:
    commands:
      format:
        run: dart format --set-exit-if-changed lib test
      analyze:
        run: flutter analyze --no-fatal-infos
  ```

### 8. Create Setup Script
- [ ] Create `scripts/setup.sh`:
  ```bash
  #!/bin/bash
  flutter pub get
  firebase emulators:start --only auth,firestore,storage &
  echo "Setup complete!"
  ```

### 9. Add Gradle Caching
- [ ] Add to CI workflows:
  ```yaml
  - uses: actions/cache@v4
    with:
      path: |
        ~/.gradle/caches
        ~/.gradle/wrapper
      key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*') }}
  ```

---

## Low Priority (Backlog)

- [ ] Add Slack notifications for build failures
- [ ] Create CI metrics tracking
- [ ] Document developer onboarding
- [ ] Add iOS build support (requires macOS runner)
- [ ] Set up performance benchmarking

---

## Verification Checklist

After completing quick wins:
- [ ] `flutter analyze` passes
- [ ] `flutter build apk --release` succeeds
- [ ] Release APK is signed with production key
- [ ] Package name is unique
- [ ] APK size is reduced (minification working)
- [ ] All CI workflows pass
- [ ] No secrets exposed in git history
