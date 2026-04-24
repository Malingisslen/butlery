# Setup — Butlery på Mac/iPhone

Guide för att köra Butlery lokalt på en Mac (+ valfritt: på iPhone via kabel). Samma Firebase-projekt som Malin kör mot, så allt fungerar out-of-the-box när filerna är på plats.

---

## 1. Installera verktygen (engångsjobb, ~1-2h)

```bash
# Flutter
brew install --cask flutter
flutter doctor
```

Installera **Xcode** från App Store (~40 GB, ta en kaffe).

När Xcode är klar:

```bash
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
sudo gem install cocoapods
```

Kör `flutter doctor` igen — alla rader ska ha grön bock. Om något saknas, följ dess instruktion.

---

## 2. Få tag på repo + hemliga filer

```bash
git clone <repo-url>
cd butlery
```

Be Malin skicka följande filer säkert (Signal, 1Password eller AirDrop — **aldrig** mail/Slack/git):

| Fil | Läggs på |
|---|---|
| `google-services.json` | `android/app/google-services.json` |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` |
| `.env` | Repo-roten (`butlery/.env`) |

---

## 3. Installera dependencies

```bash
flutter pub get
cd ios && pod install && cd ..
```

---

## 4. Kör appen

### A) Chrome (snabbast att komma igång)

```bash
flutter run -d chrome --dart-define-from-file=.env
```

### B) iOS-simulator på Mac

Starta simulatorn först:
```bash
open -a Simulator
```

Sen:
```bash
flutter run -d "iPhone 15" --dart-define-from-file=.env
```
(byt namn om du har annan simulator — lista dem med `flutter devices`)

### C) Din riktiga iPhone via kabel

1. Plugga in iPhone via USB-C/Lightning
2. Lås upp telefonen, godkänn "Lita på den här datorn"
3. Öppna projektet i Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
4. I Xcode: välj **Runner**-targeten → fliken **Signing & Capabilities**
   - Bocka i **Automatically manage signing**
   - **Team:** välj ditt Apple ID (logga in med Apple ID om tomt)
   - **Bundle Identifier:** om du får signing-fel, ändra till något unikt (t.ex. `com.dittnamn.butlery`)
5. Stäng Xcode
6. Kör:
   ```bash
   flutter run --dart-define-from-file=.env
   ```

**Första gången på iPhone:** telefonen kommer vägra öppna appen. Gå till:
**Inställningar → Allmänt → VPN och enhetshantering → Utvecklarapp → Lita på [ditt Apple ID]**

Sen fungerar den.

**Gotcha:** Med gratis Apple ID gäller signeringen bara 7 dagar. Efter en vecka måste du köra `flutter run` igen med kabel för att bygga om.

---

## 5. Vanliga problem

**`CocoaPods not installed`**
```bash
sudo gem install cocoapods
cd ios && pod install
```

**`No valid code signing certificates found`**
→ Xcode → Settings → Accounts → lägg till Apple ID → välj teamet i Signing-fliken.

**`Unable to install` på iPhone**
→ Troligen trust-issue. Gå till Inställningar → VPN och enhetshantering (steg ovan).

**Appen kraschar direkt vid start**
→ Firebase-filerna saknas eller ligger fel. Dubbelkolla sökvägarna i steg 2.

**Build failar med `Multiple commands produce...`**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter run --dart-define-from-file=.env
```

---

## Obs om datan

Du kör mot **samma Firebase-projekt** som Malin — dina test-recept, inköpslistor och användarkonto hamnar i samma databas som prod-testdatan. Det är medvetet (du ska kunna testa delning, vänner osv), men tänk på att inte skapa skräpdata i onödan.
