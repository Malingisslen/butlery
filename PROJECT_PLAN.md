# 🚀 Butlery Projektplan - Status Juni 2025

## 📋 **Snabbstart för nästa session:**
```
Välkommen tillbaka! Snabbstart-check:
✅ Mappstruktur mottagen
✅ Projektplan-status: Fas 12 - Ta emot delningar från andra appar
✅ Git status: Check needed
✅ Redo att börja!
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
│   │   ├── share_service.dart # Delningsfunktionalitet (✅ Komplett med JSON export/import)
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
│   │   ├── importera_fran_arkiv_view.dart # ✅ Overflow-problem fixat
│   │   ├── inkopslista_view.dart # ✅ PopScope uppdaterat
│   │   ├── lagg_till_recept_view.dart # ✅ PopScope uppdaterat
│   │   ├── main_views/
│   │   │   └── mina_recept_view.dart # ✅ PopScope uppdaterat
│   │   ├── photo_import_view.dart
│   │   ├── recipe_detail_view.dart
│   │   ├── skriv_sjalv_recept_view.dart
│   │   └── veckomeny_view.dart # ✅ PopScope uppdaterat, overflow fixat
│   │
│   ├── widgets/                 # Återanvändbara komponenter
│   │   ├── action_button.dart # ✅ Overflow-problem fixat
│   │   ├── cached_recipe_image.dart
│   │   ├── empty_state.dart # ✅ Keyboard overflow fixat
│   │   ├── filter_chips.dart   # ✅ Filter widget implementerad och integrerad
│   │   ├── instruction_editor.dart
│   │   ├── main_layout_menu.dart
│   │   ├── optimized_card.dart
│   │   ├── profile_dialog.dart # ✅ Komplett med JSON export/import
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

## ✅ **Fas 11: Delning & Export (KLAR)**
### **11.1 Text-export för enskilt recept (KLAR)**
- ✅ Dela-knapp i RecipeDetailView
- ✅ Formatering av recepttext
- ✅ ShareService implementerad
- ✅ Native share sheet integration
- ✅ Feedback till användaren

### **11.2 Text-export för inköpslista (KLAR)**
- ✅ Uppdaterad ShoppingListViewModel
- ✅ Smart gruppering av items
- ✅ Native share sheet
- ✅ Formatering med checkboxar

### **11.3 Text-export för veckomeny (KLAR)**
- ✅ Dela-knapp i VeckomenyView
- ✅ Formatering med emojis
- ✅ Metadata för varje rätt
- ✅ Native share sheet

### **11.4 Bild-export för veckomeny (SKIPPAD)**
- ⏭️ Skjuts upp till senare version

### **11.5 JSON Backup/Export (KLAR)**
- ✅ ShareService uppdaterad med JSON export/import-logik
- ✅ ProfileDialog använder ShareService för all delning
- ✅ Modularitet bevarad
- ✅ RecipeService har getAllRecipes() metod
- ✅ Komplett flöde implementerat

### **11.6 Delning från receptlistan (SKIPPAD)**
- ⏭️ Snabbdelning från RecipeCard
- ⏭️ Long-press eller swipe-action
- ⏭️ Använd samma format som 11.1

---

## 🚧 **Fas 12: Ta emot delningar från andra appar (NÄSTA!)**

### **🎯 Mål**
Användare ska kunna dela recept från sociala medier (Instagram, TikTok, Facebook) direkt till Butlery. Appen tar emot URL, extraherar recepttext via headless WebView, och använder befintlig TextImportViewModel för parsing.

### **📋 Implementation steg-för-steg**

#### **12.1 Android Intent Filter & Share Handler (45 min)**
- [ ] Uppdatera AndroidManifest.xml med intent filters
- [ ] Installera share_handler package
- [ ] Konfigurera för text/plain och text/html
- [ ] Test med olika appar

#### **12.2 ContentDetectorService (30 min)**
- [ ] Återanvänd recipe detection-logik från TextImportViewModel
- [ ] URL-pattern matching
- [ ] Platform-identifiering (Instagram/TikTok/Facebook)

#### **12.3 SocialMediaExtractor Service (1.5 timmar)**
- [ ] HeadlessInAppWebView implementation
- [ ] Platform-specifika selektorer
- [ ] Retry-logik och error handling
- [ ] Timeout-hantering (max 5 sekunder)

#### **12.4 ReceiveShareView (45 min)**
- [ ] Använd befintliga AppTheme styles
- [ ] Loading state med SkeletonLoader
- [ ] Content preview
- [ ] Routing till rätt import-flow
- [ ] Error handling med fallback

#### **12.5 Integration i main.dart (30 min)**
- [ ] ShareHandler setup
- [ ] Navigation till ReceiveShareView
- [ ] Hantera app i bakgrund vs förgrund

#### **12.6 Error Tracking & Monitoring (30 min)**
- [ ] Logga misslyckade extraktioner
- [ ] Firebase Analytics integration

**⏱️ Tidsuppskattning: 4-5 timmar**

---

## 💾 **Fas 13: Offline-stöd (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Hive implementation för lokal cache
- [ ] Synk-strategi mellan Hive och Firebase
- [ ] Offline/online-indikator
- [ ] flutter_cache_manager för bilder

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
- [ ] Kamera-integration
- [ ] Bildkarusell i RecipeDetailView
- [ ] Optimering och Firebase Storage

---

## 🥄 **Fas 16: Portionshantering & Enhetskonvertering (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Portionsskalning UI
- [ ] Smart parsing med super_measurement
- [ ] Enhetskonvertering (dl ↔ ml, etc.)

---

## 🎥 **Fas 17: Video-import (6-8 timmar)**

### **🎯 Implementation:**
- [ ] YouTube URL-import
- [ ] Smart API-användning
- [ ] Parser för beskrivningstext
- [ ] Copyright disclaimer

---

## 🤝 **Fas 18: Grundläggande social (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Offentliga receptlänkar
- [ ] "Kopiera recept" funktion
- [ ] Betygsystem (1-5 stjärnor)
- [ ] Delningsstatistik

---

## 🔍 **Fas 19: Dark Mode (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Utöka AppTheme med dark mode
- [ ] ThemeMode.system
- [ ] Manuell toggle
- [ ] Testa alla vyer

---

## ♿ **Fas 20: Accessibility (Löpande)**

### **🎯 Implementation:**
- [ ] semanticsLabel på alla ikoner
- [ ] Kontrasttest
- [ ] WCAG AA-standard
- [ ] Touch targets minst 48x48

---

## 🚀 **Fas 21: Onboarding & Tutorial (2-3 timmar)**

### **🎯 Implementation:**
- [ ] Välkomstskärm
- [ ] 3-4 slides med kärnfunktioner
- [ ] Skip-möjlighet
- [ ] SharedPreferences

---

## 📊 **Fas 22: Analytics & Monitoring (3-4 timmar)**

### **🎯 Implementation:**
- [ ] Firebase Analytics
- [ ] Crashlytics
- [ ] Performance Monitoring
- [ ] Budget-varningar

---

## 🔍 **Fas 23: Kostnadsoptimering & Performance (3-4 timmar)**

### **🎯 Implementation:**
- [ ] Recipe summaries
- [ ] Pagination
- [ ] Selektiva queries
- [ ] Kostnadskalkyl

---

## 🏗️ **Fas 24: Kodkvalitet & Refaktorering (6-8 timmar)**

### **🎯 Implementation:**
- [ ] Linter-regler
- [ ] Service-uppdelning
- [ ] Performance-optimering
- [ ] Modularitet
- [ ] Error handling

---

## 🧪 **Fas 25: Unit Tests (2-3 timmar)**

### **🎯 Implementation:**
- [ ] Validators
- [ ] Text parsing
- [ ] Model serialization
- [ ] 50% coverage

---

## 📱 **Fas 26: Store Listings & Release Prep (5-6 timmar)**

### **🎯 Implementation:**
- [ ] iOS Privacy Manifest
- [ ] Play Integrity API
- [ ] Legal dokument
- [ ] Grafiskt material
- [ ] Store metadata

---

## 🤖 **Fas 27: AI-Integration (5-8 timmar)**

### **🎯 Implementation:**
- [ ] Auto-kategorisering
- [ ] Smart menygeneration
- [ ] Intelligent parsing
- [ ] Användarförslag

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
- ✅ Komplett delningsfunktionalitet

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
12. **Komplett delningsfunktionalitet** ⭐ **(NY!)**

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
- ✅ **Komplett delningsfunktionalitet (100%)** **(UPPDATERAT!)**

---

## 📊 **Realistiska tidsestimat**

### **Till MVP (solo-testning):**
- Fas 12 (Ta emot delningar): 4-5 timmar ⭐ **(NÄSTA!)**
- Fas 13 (Offline-stöd): 4-5 timmar ⭐
- Fas 14 ("Senast tillagad"): 1 timme
- Fas 15 (Flera bilder): 8-10 timmar
- Fas 16 (Portions/Enheter): 4-5 timmar
- Fas 17 (Video-import): 6-8 timmar
- Fas 18 (Grundläggande social): 4-5 timmar

**Återstående tid till grundläggande MVP: ~32-38 timmar**

### **Kvalitetssäkring & Release:**
- Fas 19-26: ~30-35 timmar

**Total återstående tid till release-ready: ~62-73 timmar**

---

## 🎯 **Prioritering framåt:**

### **Kritiska för MVP:**
1. **Ta emot delningar (Fas 12)** → 4-5 timmar ⭐ **(NÄSTA!)**
2. **Offline-stöd (Fas 13)** → 4-5 timmar ⭐
3. **"Senast tillagad" (Fas 14)** → 1 timme

### **Nice-to-have för v1.0:**
4. **Flera bilder (Fas 15)** → 8-10 timmar
5. **Dark Mode (Fas 19)** → 4-5 timmar
6. **Portions/Enheter (Fas 16)** → 4-5 timmar

### **Post-launch:**
7. **Video-import (Fas 17)** → 6-8 timmar
8. **AI-integration (Fas 27)** → 5-8 timmar
9. **Onboarding (Fas 21)** → 2-3 timmar
10. **Analytics (Fas 22)** → 3-4 timmar

---

## 🚦 **Git Branch Status:**

**Aktiva branches:**
- `main` - Senaste stabila version
- Rekommendation: Gör en git commit för alla overflow-fixar!

---

## ⚖️ **Legal & Säkerhet:**

- **Copyright disclaimer** i alla import-flöden
- **"Fair use" policy** i användarvillkor
- **Source URL** alltid synlig
- **Backup/Export** för användarkontroll
- **GDPR-compliance** från start

---

## 🎯 **Nästa session börjar med:**
1. Git commit för overflow-fixar
2. Påbörja Fas 12 - Ta emot delningar från andra appar
3. Fokus på Android Intent Filter implementation först