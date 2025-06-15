# 🚀 Butlery Projektplan - Status Juni 2025

## 📋 **Snabbstart för nästa session:**
```
Välkommen tillbaka! Snabbstart-check:
✅ Mappstruktur mottagen
✅ Projektplan-status: Fas 11.5 - JSON Backup/Export implementation väntar
✅ Git status: On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   PROJECT_PLAN.md
        modified:   linux/flutter/generated_plugin_registrant.cc
        modified:   linux/flutter/generated_plugin_registrant.h
        modified:   linux/flutter/generated_plugins.cmake
        modified:   macos/Flutter/GeneratedPluginRegistrant.swift
        modified:   windows/flutter/generated_plugin_registrant.cc
        modified:   windows/flutter/generated_plugin_registrant.h
        modified:   windows/flutter/generated_plugins.cmake

no changes added to commit (use "git add" and/or "git commit -a")
✅ Nästa steg: Bugfix
```

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
│   │   └── shopping_item.dart  # Shopping item-modell
│   │
│   ├── services/                # Affärslogik & Firebase
│   │   ├── auth_service.dart   # Firebase Authentication
│   │   ├── backup_service.dart  
│   │   ├── menu_service.dart   # Menygeneration
│   │   ├── persistence_service.dart
│   │   ├── recipe_service.dart # Firebase Firestore CRUD
│   │   ├── search_service.dart # Sökfunktionalitet
│   │   ├── share_service.dart # Delningsfunktionalitet (✅ Uppdaterad med JSON export/import)
│   │   └── shopping_list_service.dart
│   │
│   ├── theme/                   # Design-system
│   │   └── app_theme.dart      # Centraliserat tema
│   │
│   ├── utils/                   # Verktyg
│   │   ├── recipe_scraper.dart # Web scraping
│   │   └── route_animations.dart 
│   │   └── text_utils.dart     # Textbearbetning
│   │
│   ├── viewmodels/              # MVVM ViewModels
│   │   ├── archive_import_viewmodel.dart
│   │   ├── auth_viewmodel.dart
│   │   ├── menu_viewmodel.dart
│   │   ├── photo_import_viewmodel.dart
│   │   ├── recipe_detail_viewmodel.dart
│   │   ├── recipe_form_viewmodel.dart
│   │   ├── recipe_list_viewmodel.dart  # ✅ Uppdaterad med filter-logik
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
│   │   ├── mina_recept_view.dart       # ✅ Filter chips UI implementerat
│   │   ├── photo_import_view.dart
│   │   ├── recipe_detail_view.dart
│   │   ├── skriv_sjalv_recept_view.dart
│   │   └── veckomeny_view.dart
│   │
│   ├── widgets/                 # Återanvändbara komponenter
│   │   ├── action_button.dart
│   │   ├── cached_recipe_image.dart
│   │   ├── empty_state.dart
│   │   ├── filter_chips.dart   # ✅ Filter widget implementerad och integrerad
│   │   ├── instruction_editor.dart
│   │   ├── main_layout_menu.dart
│   │   ├── optimized_card.dart
│   │   ├── profile_dialog.dart # ✅ Uppdaterad med JSON export/import
│   │   ├── recipe_card.dart
│   │   ├── recipe_service_widget.dart
│   │   ├── search_bar.dart
│   │   └── skeleton_loader.dart # ✅ Widget för loading states
│   │
│   ├── firebase_options.dart    # Firebase-konfiguration
│   └── main.dart               # App entry point ✅ Med smooth animations
│
├── admin-scripts/               # Admin-verktyg
│   ├── archive-updater.js      # Uppdatera Firebase-arkiv
│   ├── package.json
│   ├── .gitignore
│   └── README.md
│   └── BUGS_TO_FIX.md
│
├── android/                     # Android-konfiguration
├── ios/                        # iOS-konfiguration
├── assets/                     # Bilder och resurser
├── test/                       # Tester
├── .github/                    # GitHub Actions
│   └── workflows/
│       ├── analyze.yml         # ✅ Kodkvalitet (Flutter 3.32.0)
│       └── test.yml           # Test workflow
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
TODO

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

## ✅ **Fas 8.5: CI/CD Setup (KLAR)**
- ✅ GitHub Actions workflow för kodkvalitet
- ✅ Flutter analyze på varje push
- ✅ Flutter 3.32.0 i CI miljö
- ✅ Branch-strategi etablerad (main/develop/feature/*)

## ✅ **Fas 9: Core UX (KLAR)**
- ✅ Pull-to-refresh implementerat i receptlistan
- ❌ Swipe-to-delete (medvetet skippad - inte intuitivt för alla användare)
- ✅ Smooth animations mellan views (150-200ms, olika för olika typer)
- ✅ Loading skeletons med shimmer-effekt istället för spinners

## ✅ **Fas 10: Sortering & Filter (KLAR)**
- ✅ SearchService med avancerad sök- och filterfunktionalitet
- ✅ RecipeListViewModel uppdaterad med filter-logik
- ✅ Filter chips widget skapad
- ✅ Toggle-funktioner för tid, måltidstyp och betyg
- ✅ Filter chips UI integrerat i MinaReceptView
- ✅ Filter-funktionalitet testad och fungerar

---

✅ Fas 11: Delning & Export (KLAR)
✅ Implementerat:
11.1 Text-export för enskilt recept (KLAR)

✅ Dela-knapp i RecipeDetailView
✅ Formatering av recepttext
✅ ShareService implementerad
✅ Native share sheet integration
✅ Feedback till användaren

11.2 Text-export för inköpslista (KLAR)

✅ Uppdaterad ShoppingListViewModel
✅ Smart gruppering av items
✅ Native share sheet
✅ Formatering med checkboxar

11.3 Text-export för veckomeny (KLAR)

✅ Dela-knapp i VeckomenyView
✅ Formatering med emojis
✅ Metadata för varje rätt
✅ Native share sheet

11.4 Bild-export för veckomeny (SKIPPAD)

⏭️ Skjuts upp till senare version

11.5 JSON Backup/Export (KLAR)

✅ ShareService uppdaterad med JSON export/import-logik
✅ ProfileDialog använder ShareService för all delning
✅ Modularitet bevarad
✅ RecipeService har getAllRecipes() metod
✅ Komplett flöde implementerat

11.6 Delning från receptlistan (SKIPPAD)

⏭️ Snabbdelning från RecipeCard
⏭️ Long-press eller swipe-action
⏭️ Använd samma format som 11.1
---

## 🐛 **EXTRA: Åtgärda befintliga kända buggar**

### **Information:**
Innan vi fortsätter med nya funktioner ska vi se över och åtgärda alla kända buggar som finns dokumenterade i projektet. Detta inkluderar:
- Genomgång av BUGS_TO_FIX.md
- Kontroll av GitHub Issues
- Användarrapporterade problem
- Prestandaproblem eller kraschrapporter

Detta är en viktig kvalitetssäkringsåtgärd för att säkerställa en stabil grund innan vi lägger till mer funktionalitet.
---

# 📥 Fas 12: Ta emot delningar från andra appar (4-5 timmar)

## 🎯 **Mål**
Användare ska kunna dela recept från sociala medier (Instagram, TikTok, Facebook) direkt till Butlery. Appen tar emot URL, extraherar recepttext via headless WebView, och använder befintlig TextImportViewModel för parsing.

## 🏗️ **Arkitektur - Modulär design**

```
1. ShareReceiver (main.dart) → Tar emot delning
2. ContentDetectorService → Identifierar typ av innehåll  
3. SocialMediaExtractor → Platform-specifik textextraktion
4. ReceiveShareView → Preview och användarval
5. Befintliga import-flöden → Återanvändning av all parsing-logik
```

## 📋 **Implementation steg-för-steg**

### **12.1 Android Intent Filter & Share Handler (45 min)**
- [ ] Uppdatera AndroidManifest.xml med intent filters
- [ ] Installera share_handler package (ersätter receive_sharing_intent)
- [ ] Konfigurera för text/plain och text/html
- [ ] Test med olika appar

### **12.2 ContentDetectorService (30 min)**
```dart
// lib/services/content_detector_service.dart
// Modulär service för innehållsidentifiering
class ContentDetectorService {
  static ContentType detectType(String content);
  static String? extractUrl(String content);
  static SourcePlatform? identifyPlatform(String url);
}
```
- [ ] Återanvänd recipe detection-logik från TextImportViewModel
- [ ] URL-pattern matching
- [ ] Platform-identifiering (Instagram/TikTok/Facebook)

### **12.3 SocialMediaExtractor Service (1.5 timmar)**
```dart
// lib/services/social_media_extractor.dart
// Modulär WebView-baserad extraktion
class SocialMediaExtractor {
  // Platform-agnostisk interface
  Future<ExtractionResult> extractFromUrl(String url);
  
  // Platform-specifika implementationer (privata)
  Future<String?> _extractInstagram(controller);
  Future<String?> _extractTikTok(controller);
  Future<String?> _extractFacebook(controller);
}

// Selector-konfiguration i separat fil för enkel uppdatering
// lib/config/social_media_selectors.dart
class SocialMediaSelectors {
  static const instagramSelectors = [...];
  static const tiktokSelectors = [...];
}
```
- [ ] HeadlessInAppWebView implementation
- [ ] Platform-specifika selektorer (lätt att uppdatera)
- [ ] Retry-logik och error handling
- [ ] Timeout-hantering (max 5 sekunder)

### **12.4 ReceiveShareView (45 min)**
- [ ] Använd befintliga AppTheme styles
- [ ] Loading state med SkeletonLoader
- [ ] Content preview
- [ ] Routing till rätt import-flow
- [ ] Error handling med fallback till manuell kopiering

### **12.5 Integration i main.dart (30 min)**
- [ ] ShareHandler setup
- [ ] Navigation till ReceiveShareView
- [ ] Hantera app i bakgrund vs förgrund

### **12.6 Error Tracking & Monitoring (30 min)**
```dart
// Automatisk rapportering för underhåll
class ExtractionAnalytics {
  static void logSuccess(platform, selectors);
  static void logFailure(platform, selectors, error);
  static void generateMonthlyReport();
}
```
- [ ] Logga misslyckade extraktioner
- [ ] Spara vilka selektorer som användes
- [ ] Firebase Analytics integration

## 🛡️ **Strategier för minimal underhåll**

### **1. Selector Configuration**
```dart
// Enkelt att uppdatera utan att ändra logik
const platformSelectors = {
  'instagram': {
    'primary': ['span[dir="auto"]'],
    'fallback': ['article div span', '[role="main"] span'],
    'updated': '2025-06-15' // Spåra när vi senast verifierade
  }
};
```

### **2. Graceful Degradation**
```dart
// Alltid ha en plan B
if (extractedText == null) {
  return ManualCopyGuide(); // Aldrig lämna användaren stuck
}
```

### **3. A/B Testing av selektorer**
```dart
// Testa nya selektorer på subset av användare
if (FeatureFlags.testNewSelectors) {
  tryExperimentalSelectors();
}
```

## 📱 **User Experience**

### **Lyckad extraktion (80% av fallen)**
1. Dela från Instagram → Butlery
2. "Hämtar recept..." (2-3 sek)
3. Preview av extraherat recept
4. "Fortsätt" → SkrivSjalvReceptView

### **Misslyckad extraktion (20% av fallen)**
1. Dela från Instagram → Butlery
2. "Hämtar recept..." (2-3 sek)
3. "Kunde inte hämta automatiskt"
4. Guide: "Kopiera recepttexten från inlägget"
5. Manuell inklistring → TextImportViewModel

## 🔧 **Underhållsplan**

### **Månatlig rutin (2 timmar)**
1. Kör ExtractionAnalytics rapport
2. Identifiera trasiga selektorer
3. Uppdatera selector-konfiguration
4. Pusha fix (ingen app-uppdatering krävs om vi gör selektorer server-driven)

### **Kvartalsvis (4 timmar)**
1. Större genomgång av alla plattformar
2. Uppdatera WebView strategier om nödvändigt
3. Evaluera om backend-lösning behövs

## ✅ **Definition of Done**
- [ ] Användare kan dela från Instagram/TikTok/Facebook
- [ ] 80%+ success rate för publika inlägg
- [ ] Graceful fallback för misslyckanden
- [ ] Analytics för framtida underhåll
- [ ] Modulär kod som är lätt att uppdatera
- [ ] Använder AppTheme för all styling
- [ ] Återanvänder befintlig parsing-logik

## 🚀 **Framtida förbättringar**
- Server-driven selectors (uppdatera utan app release)
- Backend fallback för svåra fall
- AI-powered text extraction
- Caching av extraherade recept

## ⏱️ **Tidsuppskattning**
- Implementation: 4-5 timmar
- Testing: 1 timme
- Totalt: 5-6 timmar för komplett implementation

---

## 💾 **Fas 13: Offline-stöd (4-5 timmar)**

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

## 📅 **Fas 14: "Senast tillagad" tracking (1 timme)**

### **🎯 Implementation:**
- [ ] Spara datum när recept använts
- [ ] Visa "senast tillagad" i receptlistan
- [ ] Använd för smart sortering

---

## 📸 **Fas 15: Flera bilder per recept (8-10 timmar)**

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

## 🥄 **Fas 16: Portionshantering & Enhetskonvertering (4-5 timmar)**

### **🎯 Implementation:**
- [ ] **Portionsskalning:** UI för antal portioner
- [ ] **Smart parsing:** Använd `super_measurement` package
- [ ] **Enhetskonvertering:** dl ↔ ml, tsk ↔ msk, etc.
- [ ] **Robust hantering av "1½ dl" format**

---

## 🎥 **Fas 17: Video-import (6-8 timmar)**

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

## 🤝 **Fas 18: Grundläggande social (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Offentliga receptlänkar (read-only webb-vy)
- [ ] "Kopiera recept" från delad länk till egen samling
- [ ] Grundläggande betygsystem (1-5 stjärnor)
- [ ] Visa genomsnittsbetyg på recept
- [ ] Förbered datastruktur för framtida community-features
- [ ] Delningsstatistik i Analytics

---

## 🔍 **Fas 19: Dark Mode (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Utöka AppTheme med dark mode-palett
- [ ] ThemeMode.system för att följa enhetsinställningar
- [ ] Manuell toggle i profil/inställningar
- [ ] Testa alla vyer i båda teman
- [ ] Särskild hänsyn till bilder och ikoner
- [ ] Regression-test för färgändringar

---

## ♿ **Fas 20: Accessibility / Tillgänglighet (Löpande)**

### **🎯 Implementation integrerad i varje fas:**
- [ ] Automatisk kontroll efter varje UI-ändring
- [ ] semanticsLabel på alla ikoner
- [ ] Kontrasttest med flutter_a11y
- [ ] Minst WCAG AA-standard
- [ ] Touch targets minst 48x48

---

## 🚀 **Fas 21: Onboarding & Tutorial (2-3 timmar)**

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

## 📊 **Fas 22: Analytics & Monitoring (3-4 timmar)**

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

## 🔍 **Fas 23: Kostnadsoptimering & Performance (3-4 timmar)**

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

## 🏗️ **Fas 24: Kodkvalitet & Refaktorering (6-8 timmar)**

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

---

## 🧪 **Fas 25: Unit Tests för kärnfunktionalitet (2-3 timmar)**

### **🎯 Fokus på kritiska delar:**
- [ ] **Validators:** Email, URL, recept-validering
- [ ] **Text parsing:** Recipe scraper grundtest
- [ ] **Model serialization:** Recipe to/from JSON
- [ ] Mål: 50% coverage på services

---

## 📱 **Fas 26: Store Listings & Release Prep (5-6 timmar)**

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

## 🤖 **Fas 27: AI-Integration (5-8 timmar)**

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
- ✅ CI/CD pipeline etablerad
- ✅ Smooth animations genom hela appen
- ✅ Skeleton loaders för bättre perceived performance
- ✅ Avancerad sök- och filterfunktionalitet

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
9. **CI/CD pipeline med GitHub Actions** ⭐
10. **Modern UX med animations och skeletons** ⭐
11. **Avancerad sök- och filterfunktionalitet** ⭐
12. **Delningsfunktioner för recept, menyer och listor** ⭐

---

## 📈 **Projektets hälsa: UTMÄRKT**

Appen är nu i mycket bra skick:
- ✅ Molnbaserad med realtids-synk
- ✅ Professionell arkitektur fullt dokumenterad
- ✅ Admin-verktyg för innehållshantering
- ✅ Säker med Firebase Auth
- ✅ Source URL-implementation klar
- ✅ Skalbar och underhållbar kodbas
- ✅ CI/CD för kvalitetssäkring
- ✅ Modern UX med smooth animations
- ✅ Avancerad sök- och filterfunktionalitet
- ✅ Delningsfunktioner nästan kompletta (90%)

---

## 📊 **Realistiska tidsestimat**

### **Till MVP (solo-testning):**
- Fas 11.5 (Slutföra JSON Export): 30-45 min ⏳
- Fas 11.6 (Delning från receptlistan): 30 min
- Fas 12 (Ta emot delningar): 4-5 timmar
- Fas 13 (Offline-stöd): 4-5 timmar
- Fas 14 ("Senast tillagad"): 1 timme
- Fas 15 (Flera bilder): 8-10 timmar
- Fas 16 (Portions/Enheter): 4-5 timmar
- Fas 17 (Video-import): 6-8 timmar
- Fas 18 (Grundläggande social): 4-5 timmar

**Återstående tid till grundläggande MVP: ~37-48 timmar**

### **Kvalitetssäkring & Release:**
- Fas 19-26: ~30-35 timmar

**Total återstående tid till release-ready: ~67-83 timmar**

---

## 🎯 **Prioritering framåt:**

### **Kritiska för MVP:**
1. **Slutföra Fas 11.5** → 30-45 min ⭐ (NÄSTA!)
2. **Offline-stöd** → 4-5 timmar ⭐
3. **Ta emot delningar** → 4-5 timmar

### **Nice-to-have för v1.0:**
4. **Flera bilder** → 8-10 timmar
5. **Dark Mode** → 4-5 timmar
6. **Portions/Enheter** → 4-5 timmar

### **Post-launch:**
7. **Video-import** → 6-8 timmar
8. **AI-integration** → 5-8 timmar
9. **Onboarding** → 2-3 timmar
10. **Analytics** → 3-4 timmar

---

## 🚦 **Git Branch Status:**

**Aktiva branches:**
- `main` - Senaste stabila version
- Ostadgade ändringar: share_service.dart, pubspec.lock, pubspec.yaml

---

## ⚖️ **Legal & Säkerhet:**

- **Copyright disclaimer** i alla import-flöden
- **"Fair use" policy** i användarvillkor
- **Source URL** alltid synlig
- **Backup/Export** för användarkontroll
- **GDPR-compliance** från start

---