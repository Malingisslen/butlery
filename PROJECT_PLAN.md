# 🚀 Butlery Projektplan - Status Juni 2025

## 🏗️ **Projektarkitektur**

### **Mappstruktur:**
```
butlery/
├── lib/
│   ├── core/                    # Kärnfunktionalitet
│   │   ├── error/               # Centraliserad felhantering
│   │   │   ├── error_handler.dart
│   │   │   └── failures.dart
│   │   ├── extensions/          # Dart extensions
│   │   │   └── future_extensions.dart
│   │   ├── utils/               # Verktyg och hjälpfunktioner
│   │   │   ├── connectivity_check.dart
│   │   │   └── logger.dart
│   │   ├── validators/          # Input-validering
│   │   │   └── form_validators.dart
│   │   ├── cache_config.dart   # Cache-konfiguration
│   │   └── injection.dart      # Dependency injection (get_it)
│   │
│   ├── data/                    # Data-lager
│   │   ├── archived_recipes.dart    # 20 arkivrecept
│   │   └── dummy_data.dart         # 10 standardrecept
│   │
│   ├── models/                  # Datamodeller
│   │   ├── recipe.dart          # Recipe-modell med sourceUrl
│   │   ├── recipe_summary.dart # Lätt modell för listor
│   │   └── shopping_item.dart  # Shopping item-modell
│   │
│   ├── services/                # Affärslogik & Firebase
│   │   ├── auth_service.dart   # Firebase Authentication
│   │   ├── menu_service.dart   # Menygeneration
│   │   ├── persistence_service.dart
│   │   ├── recipe_service.dart # Firebase Firestore CRUD
│   │   ├── search_service.dart # Sökfunktionalitet
│   │   └── shopping_list_service.dart
│   │
│   ├── theme/                   # Design-system
│   │   └── app_theme.dart      # Centraliserat tema
│   │
│   ├── utils/                   # Verktyg
│   │   ├── recipe_scraper.dart # Web scraping
│   │   └── text_utils.dart     # Textbearbetning
│   │
│   ├── viewmodels/              # MVVM ViewModels
│   │   ├── archive_import_viewmodel.dart
│   │   ├── auth_viewmodel.dart
│   │   ├── menu_viewmodel.dart
│   │   ├── photo_import_viewmodel.dart
│   │   ├── recipe_detail_viewmodel.dart
│   │   ├── recipe_form_viewmodel.dart
│   │   ├── recipe_list_viewmodel.dart
│   │   ├── shopping_list_viewmodel.dart
│   │   ├── text_import_viewmodel.dart
│   │   └── url_import_viewmodel.dart
│   │
│   ├── views/                   # UI-vyer
│   │   ├── auth_view.dart      # Inloggning
│   │   ├── edit_recipe_view.dart
│   │   ├── fran_sociala_medier_view.dart
│   │   ├── import_via_url_view.dart
│   │   ├── importera_fran_arkiv_view.dart
│   │   ├── inkopslista_view.dart
│   │   ├── lagg_till_recept_view.dart
│   │   ├── mina_recept_view.dart
│   │   ├── photo_import_view.dart
│   │   ├── recipe_detail_view.dart
│   │   ├── skriv_sjalv_recept_view.dart
│   │   └── veckomeny_view.dart
│   │
│   ├── widgets/                 # Återanvändbara komponenter
│   │   ├── action_button.dart
│   │   ├── cached_recipe_image.dart
│   │   ├── empty_state.dart
│   │   ├── instruction_editor.dart
│   │   ├── main_layout_menu.dart
│   │   ├── optimized_card.dart
│   │   ├── profile_dialog.dart
│   │   ├── recipe_card.dart
│   │   ├── recipe_service_widget.dart
│   │   └── search_bar.dart
│   │
│   ├── firebase_options.dart    # Firebase-konfiguration
│   └── main.dart               # App entry point
│
├── admin-scripts/               # Admin-verktyg
│   ├── archive-updater.js      # Uppdatera Firebase-arkiv
│   ├── package.json
│   ├── .gitignore
│   └── README.md
│
├── android/                     # Android-konfiguration
├── ios/                        # iOS-konfiguration
├── assets/                     # Bilder och resurser
├── test/                       # Tester
├── .github/                    # GitHub Actions
│   └── workflows/
│       ├── analyze.yml         # Kodkvalitet
│       └── build.yml          # Build pipeline
└── pubspec.yaml               # Dependencies
```

### **Arkitekturmönster:**
- **MVVM (Model-View-ViewModel)** - Separation mellan UI och logik
- **Repository Pattern** - Services agerar som repositories för data
- **Dependency Injection** - get_it för att hantera dependencies
- **Provider** - State management mellan ViewModels och Views
- **Singleton Services** - För app-wide state (Auth, Recipes)
- **Service-princip:** Varje service har MAX ett ansvarsområde

### **Firebase-struktur:**
```
Firestore Database:
├── users/
│   └── {userId}/
│       ├── recipes/              # Fullständiga recept
│       │   └── {recipeId}
│       └── recipe_summaries/     # Lätta dokument för listor
│           └── {recipeId}        # Bara titel, bild, datum
└── butlery_archive/
    ├── recipes/
    │   └── {recipeId}
    └── recipe_summaries/         # Arkiv-summaries
        └── {recipeId}
```

### **Kostnadsoptimering:**
- **Pagination:** Ladda max 20 recept åt gången
- **Summary documents:** Lätta dokument för listvyer
- **Select fields:** Hämta bara nödvändiga fält
- **Offline cache:** Minska upprepade reads

---

## ✅ **Fas 1: Grundläggande Setup (KLAR)**
- ✅ Flutter projekt initialiserat
- ✅ Mappstruktur etablerad  
- ✅ Navigation mellan views
- ✅ Grundläggande UI-komponenter

## ✅ **Fas 2: Theme-system (KLAR)**
- ✅ AppTheme centraliserat designsystem
- ✅ Konsistenta färger, typografi, spacing
- ✅ Semantiska widgets och styles
- ✅ Material 3 integration

## ✅ **Fas 3: RecipeService Integration (KLAR)**
- ✅ Singleton RecipeService med ChangeNotifier
- ✅ CRUD operationer (Create, Read, Update, Delete)
- ✅ Reaktiv UI med loading states
- ✅ Error handling med snackbars
- ✅ Type-safe operationer
- ✅ 10 förbättrade standardrecept (dummy_data.dart)
- ✅ 20 detaljerade arkivrecept för import

## ✅ **Fas 4: Grundfunktionalitet (KLAR)**
- ✅ Menygeneration från prompt
- ✅ Komplett recepthantering
- ✅ Inköpslista med checkboxar
- ✅ Flera import-metoder

## ✅ **Fas 5: Förbättringar & Stabilitet (KLAR)**
- ✅ Dependency Injection med get_it
- ✅ ViewModel Pattern implementerat
- ✅ Provider integration komplett
- ✅ Centraliserad error handling
- ✅ Form validators
- ✅ Connectivity check
- ✅ Optimerade widgets
- ✅ Empty states

## ✅ **Fas 6: Firebase Integration (KLAR)**
- ✅ Firebase Core initierad med duplicate-check
- ✅ Email/Password authentication aktiverad
- ✅ AuthService implementerad
- ✅ RecipeService migrerad till Firestore
- ✅ Realtids-synkronisering fungerar
- ✅ Security Rules konfigurerade
- ✅ Användar-specifik data (`users/{userId}/recipes`)
- ✅ Delat arkiv (`butlery_archive`)
- ✅ Test-användare skapad (test@example.com)

## ✅ **Fas 7: Admin Tools & Arkivhantering (KLAR)**
- ✅ `admin-scripts/` mapp skapad
- ✅ firebase-admin installerad
- ✅ Service account key konfigurerad
- ✅ archive-updater.js fungerar
- ✅ 20 recept i arkivet
- ✅ Debug-knappen borttagen från MinaReceptView
- ✅ .gitignore för admin-scripts
- ✅ README.md för dokumentation

## ✅ **Fas 8: Source URL Implementation (KLAR)**
- ✅ sourceUrl fält i Recipe-modellen
- ✅ UrlImportViewModel sparar sourceUrl
- ✅ ImportViaUrlView skickar med sourceUrl
- ✅ main.dart routing uppdaterad
- ✅ FranSocialaMedierView tar emot sourceUrl
- ✅ TextImportViewModel inkluderar sourceUrl
- ✅ RecipeDetailView visar sourceUrl som klickbar länk
- ✅ RecipeFormViewModel hanterar sourceUrl
- ✅ sourceUrl-fält i EditRecipeView
- ✅ sourceUrl-fält i SkrivSjalvReceptView
- ✅ "Från Butlerys arkiv" i ArchiveImportViewModel
- ✅ Ikon (🔗) i RecipeCard om recept har sourceUrl
- ✅ url_launcher package installerad

---

## 🔧 **Fas 8.5: CI/CD Setup (3-4 timmar)**

### **🎯 GitHub Actions implementation:**
- [ ] **Basic pipeline (.github/workflows/analyze.yml):**
  ```yaml
  - flutter analyze
  - flutter format --set-exit-if-changed
  - flutter test (när tester finns)
  ```
- [ ] **Build pipeline (.github/workflows/build.yml):**
  ```yaml
  - Bygg APK på tags
  - Spara artifacts
  ```
- [ ] **Branch-strategi:**
  - `main` = produktion
  - `develop` = nästa release  
  - `feature/*` = aktiv utveckling

---

## 🎨 **Fas 9: Core UX (4-6 timmar)**

### **🎯 Essentiella UX-förbättringar:**
- [ ] Pull-to-refresh i receptlistan
- [ ] Swipe-to-delete på recept (med undo)
- [ ] Smooth animations mellan views
- [ ] Loading skeletons istället för spinners
- [ ] Grundläggande accessibility-check

---

## 🎥 **Fas 9.5: Video-import (6-8 timmar)**

### **🎯 Implementation:**
- [ ] YouTube URL-import i ImportViaUrlView
- [ ] **Smart API-användning:**
  - Hämta bara snippet först
  - "Ladda fullständig beskrivning" on-demand
  - Hantera rate limits gracefully
- [ ] Parser för att hitta recept i beskrivningstext
- [ ] Skicka till FranSocialaMedierView för manuell justering
- [ ] Spara video-URL som sourceUrl
- [ ] Visa "Importerat från video" med länk i RecipeDetailView
- [ ] **Copyright disclaimer:** "Spara endast recept du har rätt att använda privat"

---

## 🔍 **Fas 10: Sortering & Filter (2-3 timmar)**

### **🎯 Implementation:**
- [ ] Sortera efter: Nyast, A-Ö, Senast använd
- [ ] Förbättra textsökning med realtidsfiltrering
- [ ] Responsiv sökning medan användaren skriver
- [ ] Implementera med recipe_summaries för prestanda

---

## 📤 **Fas 11: Delning & Export (3-4 timmar)**

### **🎯 Implementation:**
- [ ] **Text-export** - kopiera som formaterad text
- [ ] **Bild-export** - för veckomeny (Instagram/SMS-vänlig)
- [ ] **Backup/Export JSON** - återanvänd för delning
- [ ] PDF kan vänta till senare version

---

## 💾 **Fas 12: Offline-stöd (4-5 timmar)**

### **🎯 Implementation med tydlig synk-strategi:**
- [ ] **Hive implementation:**
  - Lokal cache för användarens recept
  - Separata boxes för recept, bilder, inställningar
  - TTL (Time To Live) per box-typ
- [ ] **Synk-flöde:**
  ```
  Offline: Ändring → Hive → Flag: "pending_sync"
  Online: Check pending → Firebase → Clear flag
  Conflict: Server wins, visa varning
  ```
- [ ] Fungera utan internetuppkoppling
- [ ] Tydlig offline/online-indikator
- [ ] flutter_cache_manager för bildcache

---

## 📅 **Fas 13: "Senast tillagad" tracking (1 timme)**

### **🎯 Implementation:**
- [ ] Spara datum när recept använts
- [ ] Visa "senast tillagad" i receptlistan
- [ ] Använd för smart sortering

---

## 📸 **Fas 14: Flera bilder per recept (8-10 timmar)**

### **🎯 Implementation:**
- [ ] Uppdatera Recipe-modellen för array av bilder
- [ ] UI för att lägga till flera bilder
- [ ] Kamera-integration för direktfotografering
- [ ] Filväljare för att ladda upp från galleri
- [ ] Bildkarusell i RecipeDetailView
- [ ] **Optimering:**
  - Thumbnail-generering
  - Progressiv uppladdning
  - Bandbreddshantering
- [ ] Firebase Storage för flera bilder per recept
- [ ] Möjlighet att ta bort/ordna om bilder

---

## 🚀 **Fas 15: Onboarding & Tutorial (2-3 timmar)**

### **🎯 Implementation:**
- [ ] Välkomstskärm vid första start
- [ ] 3-4 slides som visar kärnfunktioner:
  - Importera recept enkelt
  - Generera veckomeny smart
  - Automatisk inköpslista
- [ ] "Skip" möjlighet
- [ ] Visa endast första gången (SharedPreferences)
- [ ] Enkel och visuell design
- [ ] Ev. mini-tutorial för svårare funktioner

---

## 📊 **Fas 16: Analytics & Monitoring (3-4 timmar)**

### **🎯 Grundläggande implementation för solo-utvecklare:**
- [ ] **Firebase Analytics (basics):**
  - Screen views automatiskt
  - Key events: recipe_created, menu_generated, recipe_imported
  - Enkel funnel: Import → Save → Use
- [ ] **Firebase Crashlytics:**
  - Automatisk kraschrapportering
  - Basic error logging
- [ ] **Performance Monitoring:**
  - Firestore query performance
  - Bilduppladdningstider
- [ ] **Budget-varning:**
  - Firebase alert vid $20/månad
  - Monitoring dashboard

---

## 🥄 **Fas 17: Portionshantering & Enhetskonvertering (4-5 timmar)**

### **🎯 Implementation:**
- [ ] **Portionsskalning:** UI för antal portioner
- [ ] **Smart parsing:** Använd `super_measurement` package
- [ ] **Enhetskonvertering:** dl ↔ ml, tsk ↔ msk, etc.
- [ ] **Robust hantering av "1½ dl" format**

---

## 🔍 **Fas 18: Dark Mode (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Utöka AppTheme med dark mode-palett
- [ ] ThemeMode.system för att följa enhetsinställningar
- [ ] Manuell toggle i profil/inställningar
- [ ] Testa alla vyer i båda teman
- [ ] Särskild hänsyn till bilder och ikoner
- [ ] Regression-test för färgändringar

---

## ♿ **Fas 19: Accessibility / Tillgänglighet (Löpande)**

### **🎯 Implementation integrerad i varje fas:**
- [ ] Automatisk kontroll efter varje UI-ändring
- [ ] semanticsLabel på alla ikoner
- [ ] Kontrasttest med flutter_a11y
- [ ] Minst WCAG AA-standard
- [ ] Touch targets minst 48x48

---

## 🔍 **Fas 20: Kostnadsoptimering & Performance (3-4 timmar)**

### **🎯 Firestore-optimeringar:**
- [ ] **Recipe summaries implementation:**
  - Skapa `recipe_summaries` collection
  - Migration script för befintliga recept
  - Uppdatera RecipeService
- [ ] **Pagination i alla listvyer:**
  - 20 recept per "sida"
  - Infinite scroll
- [ ] **Selektiva queries:**
  - `.select(['field1', 'field2'])`
- [ ] **Kostnadskalkyl:**
  - Beräkna reads per användarsession
  - Optimera de dyraste queries

---

## 🏗️ **Fas 21: Kodkvalitet & Refaktorering (6-8 timmar)**

### **🎯 Implementation:**
- [ ] **Linter-regler (analysis_options.yaml):**
  ```yaml
  - prefer_const_constructors
  - avoid_print
  - prefer_single_quotes
  ```
- [ ] **Service-uppdelning:** Max ett ansvarsområde per service
- [ ] **Branch cleanup:** Ta bort gamla feature branches
- [ ] **TODO-genomgång:** Fixa eller ta bort
- [ ] **Performance-optimering:**
  - Widget rebuilds minimering
  - Lazy loading implementation
  - Memory leaks kontroll
  - Build context användning
- [ ] **Modularitet:**
  - Bryt ut stora widgets till mindre komponenter
  - Skapa återanvändbara utility-funktioner
  - Implementera barrel exports för enklare imports
  - Separera business logic från UI ännu mer
- [ ] **Framtidssäkring:**
  - Abstrakta externa dependencies
  - Skapa interfaces för services
  - Förbereda för testning (unit/widget tests)
  - Dokumentera komplexa funktioner
- [ ] **Kodstandarder:**
  - Dart analyzer striktare regler
  - Konsekvent namngivning
  - Remove alla TODOs och FIXMEs
  - Uppdatera deprecated metoder
- [ ] **Error handling:**
  - Konsekvent error-hantering överallt
  - Användaravänliga felmeddelanden
  - Crash-säker kod
  - Logging för debugging

### **🎯 Verktyg för kodkvalitet:**
```bash
# Kör Flutter analyze med striktare regler
flutter analyze --no-pub

# Leta efter oanvända dependencies
flutter pub deps

# Kör formatter på all kod
dart format lib/ --fix

# Hitta potentiella problem
grep -r "TODO\|FIXME\|XXX" lib/
```

---

## 🧪 **Fas 22: Unit Tests för kärnfunktionalitet (2-3 timmar)**

### **🎯 Fokus på kritiska delar:**
- [ ] **Validators:** Email, URL, recept-validering
- [ ] **Text parsing:** Recipe scraper grundtest
- [ ] **Model serialization:** Recipe to/from JSON
- [ ] Mål: 50% coverage på services

---

## 📱 **Fas 23: Store Listings & Release Prep (5-6 timmar)**

### **🎯 Implementation (inkl. 2025-krav):**
- [ ] **iOS Privacy Manifest:**
  - PrivacyInfo.xcprivacy
  - Deklarera all dataanvändning
- [ ] **Play Integrity API:**
  - Implementation med fallback
- [ ] **Legal:**
  - Terms of Service
  - Privacy Policy  
  - Copyright disclaimer
- [ ] **Grafiskt material:**
  - App-ikon 1024x1024
  - 5 skärmdumpar per enhet (telefon/surfplatta)
  - Feature graphic för Play Store
  - Eventuell promo-video (30 sek)
- [ ] **Texter:**
  - Kort beskrivning (80 tecken)
  - Lång beskrivning (4000 tecken)
  - Nyckelord för sökning
  - Versionsinformation
- [ ] **Metadata:**
  - Kategori och underkategori
  - Innehållsklassificering
  - Sekretess-policy URL
  - Support-kontakt
- [ ] **Tekniskt:**
  - App signing konfiguration
  - ProGuard rules (Android)
  - iOS entitlements

---

## 🤝 **Fas 24: Grundläggande social (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Offentliga receptlänkar (read-only webb-vy)
- [ ] "Kopiera recept" från delad länk till egen samling
- [ ] Grundläggande betygsystem (1-5 stjärnor)
- [ ] Visa genomsnittsbetyg på recept
- [ ] Förbered datastruktur för framtida community-features
- [ ] Delningsstatistik i Analytics

---

## 🤖 **Fas 25: AI-Integration (5-8 timmar)**

### **När all grundfunktionalitet är perfekt:**
- [ ] Auto-kategorisering av recept
- [ ] Smart menygeneration med AI
- [ ] Intelligent parsing av recepttext från olika källor
- [ ] Förslag baserat på användarhistorik
- [ ] För- och nackdelar med olika AI-lösningar:
  - **OpenAI API:** Kraftfull men kostar per anrop
  - **Gemini/Claude API:** Alternativ med olika prissättning
  - **Lokal AI:** Gratis men kräver mer utveckling
- [ ] Implementation i TextImportViewModel och FranSocialaMedierView
- [ ] Fallback om AI-parsing misslyckas

---

## 📊 **Teknisk Status**

### **🏗️ Arkitektur:**
- ✅ MVVM Pattern fullt implementerat
- ✅ Dependency Injection etablerat
- ✅ Separation of Concerns uppnått
- ✅ Firebase Cloud-baserad arkitektur
- ✅ Admin-verktyg för arkivhantering
- ✅ Skalbar kodstruktur
- ✅ Source URL implementation komplett

### **📱 Plattformar:**
- ✅ Android fullt fungerande
- ⚠️ iOS otestat (bör fungera)
- ⚠️ Web delvis fungerande (localStorage begränsningar)

### **✅ Firebase-status:**
- ✅ Core fungerar utan duplicate errors
- ✅ Authentication implementerad och testad
- ✅ Firestore databas fullt fungerande
- ✅ Security rules konfigurerade
- ✅ Arkivhantering via admin-verktyg
- ✅ 20 recept i delat arkiv
- ✅ Realtids-synk mellan enheter

---

## 🎉 **Milstolpar uppnådda:**

1. **Professionell app-arkitektur** ⭐
2. **Fullt fungerande Firebase-backend** ⭐
3. **Skalbar arkivhantering med admin-verktyg** ⭐
4. **Redo för produktion** (grundfunktionalitet) ⭐
5. **Multi-device sync** via Firestore ⭐
6. **Professionell development workflow** ⭐
7. **Source URL komplett** ⭐
8. **Komplett MVVM-arkitektur** ⭐

---

## 📈 **Projektets hälsa: UTMÄRKT**

Appen är nu i mycket bra skick:
- ✅ Molnbaserad med realtids-synk
- ✅ Professionell arkitektur fullt dokumenterad
- ✅ Admin-verktyg för innehållshantering
- ✅ Säker med Firebase Auth
- ✅ Source URL-implementation klar
- ✅ Skalbar och underhållbar kodbas
- ✅ Redo för UX-förbättringar och power-features

---

## 📊 **Realistiska tidsestimat**

### **Till MVP (solo-testning):**
- Fas 8.5 (CI/CD): 3-4 timmar ⭐
- Fas 9 (Core UX): 4-6 timmar
- Fas 9.5 (Video): 6-8 timmar
- Fas 10-15: ~28 timmar
- Fas 16 (Analytics basic): 3-4 timmar
- Fas 17-19: ~12 timmar
- Fas 20 (Optimering): 3-4 timmar ⭐
- Fas 21-22: ~9 timmar
- Fas 23: 5-6 timmar

**Total realistisk tid: ~80-95 timmar**

---

## 🎯 **Prioritering framåt:**

### **Essentiella features:**
1. **CI/CD Setup** → 3-4 timmar ⭐
2. **Core UX** → 4-6 timmar ⭐
3. **Video-import** → 6-8 timmar ⭐ 
4. **Sortering & Filter** → 2-3 timmar
5. **Delning & Export** → 3-4 timmar ⭐
6. **Offline-stöd** → 4-5 timmar
7. **"Senast tillagad"** → 1 timme
8. **Flera bilder per recept** → 8-10 timmar ⭐
9. **Onboarding** → 2-3 timmar
10. **Analytics & Monitoring** → 3-4 timmar ⭐
11. **Portions & Enhetshantering** → 4-5 timmar ⭐

**Total tid för essentiella features: ~40-50 timmar**

### **Kvalitetssäkring & Release:**
12. **Dark Mode** → 4-5 timmar ⭐
13. **Accessibility** → Löpande ⭐
14. **Kostnadsoptimering** → 3-4 timmar ⭐⭐
15. **Kodkvalitet & Refaktorering** → 6-8 timmar ⭐⭐
16. **Unit Tests** → 2-3 timmar ⭐
17. **Store Listings** → 5-6 timmar ⭐

**Total tid för kvalitet & release: ~20-26 timmar**

### **Framtida utveckling:**
18. **Grundläggande social** → 4-5 timmar
19. **AI-Integration** → 5-8 timmar

---

## 🚦 **Branch-strategi:**

```bash
git checkout -b develop  # Från main
git checkout -b feature/core-ux  # Från develop

# Efter varje feature:
git checkout develop
git merge feature/core-ux
git branch -d feature/core-ux

# När redo för release:
git checkout main
git merge develop
git tag v1.0.0
```

---

## ⚖️ **Legal & Säkerhet:**

- **Copyright disclaimer** i alla import-flöden
- **"Fair use" policy** i användarvillkor
- **Source URL** alltid synlig
- **Backup/Export** för användarkontroll
- **GDPR-compliance** från start

---

## 🎯 **Nästa konkreta steg:**

1. **Sätt upp GitHub Actions** (30 min)
2. **Implementera Pull-to-refresh** (1-2 timmar)
3. **Lägg till recipe_summaries struktur** (2 timmar)