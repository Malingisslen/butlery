# 🚀 Butlery Projektplan - Uppdaterad Status (Juni 2025)

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
└── pubspec.yaml               # Dependencies

```

### **Arkitekturmönster:**
- **MVVM (Model-View-ViewModel)** - Separation mellan UI och logik
- **Repository Pattern** - Services agerar som repositories för data
- **Dependency Injection** - get_it för att hantera dependencies
- **Provider** - State management mellan ViewModels och Views
- **Singleton Services** - För app-wide state (Auth, Recipes)

### **Firebase-struktur:**
```
Firestore Database:
├── users/
│   └── {userId}/
│       └── recipes/
│           └── {recipeId}
└── butlery_archive/
    └── recipes/
        └── {recipeId}
```

## 🎥 **Fas 9.5: Video-import (4-5 timmar)**

### **🎯 Implementation:**
- [ ] YouTube URL-import i ImportViaUrlView
- [ ] Extrahera videobeskrivning och kommentarer
- [ ] Parser för att hitta recept i beskrivningstext
- [ ] Skicka till FranSocialaMedierView för manuell justering
- [ ] Spara video-URL som sourceUrl
- [ ] Visa "Importerat från video" med länk i RecipeDetailView

## 🧪 **Fas 20.5: Beta-teststruktur (2-3 timmar)**

### **🎯 8-veckors beta-plan:**
- [ ] **Vecka 1-2:** Intern test med 5-10 nära vänner
- [ ] **Vecka 3-6:** Utökad beta med 40-60 användare
- [ ] **Vecka 7-8:** Iteration baserat på feedback

### **🎯 Distribution:**
- [ ] TestFlight setup för iOS
- [ ] Firebase App Distribution för Android
- [ ] Separata Firebase-projekt för beta vs produktion
- [ ] Instruktioner för beta-testare

### **🎯 Feedback-struktur:**
- [ ] Veckovis feedback-enkät
- [ ] In-app feedback-knapp
- [ ] NPS-mätning vecka 4 och 8
- [ ] Strukturerad bug-rapportering

---

## ✅ **Fas 1-8: KLARA!** 

### **✅ Fas 1: Grundläggande Setup (KLAR)**
- ✅ Flutter projekt initialiserat
- ✅ Mappstruktur etablerad  
- ✅ Navigation mellan views
- ✅ Grundläggande UI-komponenter

### **✅ Fas 2: Theme-system (KLAR)**
- ✅ AppTheme centraliserat designsystem
- ✅ Konsistenta färger, typografi, spacing
- ✅ Semantiska widgets och styles
- ✅ Material 3 integration

### **✅ Fas 3: RecipeService Integration (KLAR)**
- ✅ Singleton RecipeService med ChangeNotifier
- ✅ CRUD operationer (Create, Read, Update, Delete)
- ✅ Reaktiv UI med loading states
- ✅ Error handling med snackbars
- ✅ Type-safe operationer
- ✅ 10 förbättrade standardrecept (dummy_data.dart)
- ✅ 20 detaljerade arkivrecept för import

### **✅ Fas 4: Grundfunktionalitet (KLAR)**
- ✅ Menygeneration från prompt
- ✅ Komplett recepthantering
- ✅ Inköpslista med checkboxar
- ✅ Flera import-metoder

### **✅ Fas 5: Förbättringar & Stabilitet (KLAR)**
- ✅ **Dependency Injection med get_it** 
- ✅ **ViewModel Pattern implementerat**
- ✅ **Provider integration komplett**
- ✅ **Centraliserad error handling**
- ✅ **Form validators**
- ✅ **Connectivity check**
- ✅ **Optimerade widgets**
- ✅ **Empty states**

### **✅ Fas 6: Firebase Integration (KLAR!)**
- ✅ Firebase Core initierad med duplicate-check
- ✅ Email/Password authentication aktiverad
- ✅ AuthService implementerad
- ✅ RecipeService migrerad till Firestore
- ✅ Realtids-synkronisering fungerar
- ✅ Security Rules konfigurerade
- ✅ Användar-specifik data (`users/{userId}/recipes`)
- ✅ Delat arkiv (`butlery_archive`)
- ✅ Test-användare skapad (test@example.com)

### **✅ Fas 7: Admin Tools & Arkivhantering (KLAR!)**
- ✅ `admin-scripts/` mapp skapad
- ✅ firebase-admin installerad
- ✅ Service account key konfigurerad
- ✅ archive-updater.js fungerar
- ✅ 20 recept i arkivet
- ✅ Debug-knappen borttagen från MinaReceptView
- ✅ .gitignore för admin-scripts
- ✅ README.md för dokumentation

### **✅ Fas 8: Source URL Implementation (KLAR!)**
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

## 🎨 **Fas 9: Core UX (NÄSTA STEG - 2-3 timmar)**

### **🎯 Essentiella UX-förbättringar:**
- [ ] Pull-to-refresh i receptlistan
- [ ] Swipe-to-delete på recept (med undo)
- [ ] Smooth animations mellan views
- [ ] Loading skeletons istället för spinners

---

## 🔍 **Fas 10: Sortering & Filter (2-3 timmar)**

### **🎯 Implementation:**
- [ ] Sortera efter: Nyast, A-Ö, Senast använd
- [ ] Förbättra textsökning med realtidsfiltrering
- [ ] Responsiv sökning medan användaren skriver

---

## 📤 **Fas 11: Delning & Export (3-4 timmar)**

### **🎯 Steg 1: Analysera alternativ (1 timme)**
- [ ] **Text-delning:** Formaterad text för kopiering (enklast)
- [ ] **Bild-export:** Veckomeny som bild för sociala medier
- [ ] **PDF-export:** För utskrift (mer komplex)
- [ ] **Länkdelning:** Kräver public API endpoints
- [ ] **QR-kod:** Modern men krånglig implementation

### **🎯 Steg 2: Beslutskriterier**
- [ ] Användarvänlighet och värde
- [ ] Teknisk komplexitet vs nytta
- [ ] Fungerar offline?

### **🎯 Steg 3: Implementation (2-3 timmar)**
**Rekommendation: Börja med:**
- [ ] Text-export - kopiera som formaterad text
- [ ] Bild-export - för veckomeny (Instagram/SMS-vänlig)

---

## 💾 **Fas 12: Offline-stöd (3-4 timmar)**

### **🎯 Implementation:**
- [ ] **Hive implementation:**
  - Lokal cache för användarens recept
  - Separata boxes för recept, bilder, inställningar
  - TTL (Time To Live) per box-typ
- [ ] Fungera utan internetuppkoppling
- [ ] Synka ändringar när online
- [ ] Tydlig offline/online-indikator
- [ ] flutter_cache_manager för bildcache

---

## 📅 **Fas 13: "Senast tillagad" tracking (1 timme)**

### **🎯 Implementation:**
- [ ] Spara datum när recept använts
- [ ] Visa "senast tillagad" i receptlistan
- [ ] Använd för smart sortering

---

## 📸 **Fas 14: Flera bilder per recept (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Uppdatera Recipe-modellen för array av bilder
- [ ] UI för att lägga till flera bilder
- [ ] Kamera-integration för direktfotografering
- [ ] Filväljare för att ladda upp från galleri
- [ ] Bildkarusell i RecipeDetailView
- [ ] Thumbnail-hantering för snabb laddning
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

## 🔐 **Fas 16: Säkerhet & Analytics (8-9 timmar)**

### **🎯 Implementation:**
- [ ] **Firebase Analytics:**
  - Spåra mest använda features
  - Förstå användarbeteende
  - Konvertering från import till sparade recept
- [ ] **Specifika receptapp-KPIs:**
  - DAU/MAU ratio (mål: 20%+)
  - Dag 1/7/30 retention (mål: 40%/20%/10%)
  - Receptfullförandegrad (mål: 60%+)
  - Söksuccégrad
  - Video-import succégrad
- [ ] **Beta-specifika events:**
  - video_import_started/success/fail
  - recipe_cooked
  - menu_generated
  - shopping_list_completed
- [ ] **Firebase Crashlytics:**
  - Automatisk kraschrapportering
  - Detaljerad fellogging
- [ ] **Remote Config:**
  - Feature flags för beta-features
  - videoImportEnabled toggle
  - maxRecipesPerUser limit
  - API-rate limits
- [ ] **Secrets-hantering:**
  - Flytta service-account.json från repo
  - Använd GitHub Secrets eller git-crypt
  - Environment-variabler för API-nycklar
- [ ] **Firebase Budget:**
  - Sätt budget-varning på $30/månad
  - Monitoring dashboard
- [ ] **Backup/Export funktionalitet:**
  - Exportera alla recept som JSON
  - Ladda ner som fil
  - Importera från backup med konflikthantering
- [ ] **Receptvalidering:**
  - Kräv minst titel
  - Minst en instruktion eller ingrediens
  - Varna för ovanliga värden
- [ ] **GDPR Compliance:**
  - "Radera mitt konto"-funktion
  - Ta bort all användardata från Firestore
  - Ta bort alla bilder från Storage
  - Implementera i AuthService

---

## 🥄 **Fas 17: Portionshantering & Enhetskonvertering (3-4 timmar)**

### **🎯 Portionsskalning:**
- [ ] UI-element för att ändra antal portioner
- [ ] Automatisk omskalning av alla ingredienser
- [ ] Spara originalmängder
- [ ] Tydlig indikation när recept är skalat

### **🎯 Enhetskonvertering:**
- [ ] Vanliga konverteringar:
  - dl ↔ ml ↔ l
  - tsk ↔ msk ↔ dl
  - g ↔ kg
  - °C ↔ °F
- [ ] Konverteringsknapp vid varje ingrediens
- [ ] Hjälptext med konverteringstabeller
- [ ] Spara användarens enhetsval

---

## 🔍 **Fas 18: Dark Mode (2-3 timmar)**

### **🎯 Implementation:**
- [ ] Utöka AppTheme med dark mode-palett
- [ ] ThemeMode.system för att följa enhetsinställningar
- [ ] Manuell toggle i profil/inställningar
- [ ] Testa alla vyer i både ljust och mörkt tema
- [ ] Anpassa färger för god kontrast i båda lägena
- [ ] Särskild hänsyn till bilder och ikoner

---

## ♿ **Fas 19: Accessibility / Tillgänglighet (3-4 timmar)**

### **🎯 Implementation:**
- [ ] **Skärmläsarstöd:**
  - semanticsLabel på alla ikoner
  - Meningsfulla beskrivningar för interaktiva element
- [ ] **Visuell tillgänglighet:**
  - Kontrasttest med flutter_a11y
  - Minst WCAG AA-standard
  - Tydliga fokusindikatorer
- [ ] **Interaktion:**
  - Större touch-targets (minst 48x48)
  - Tangentbordsnavigering där relevant
- [ ] **Extra features:**
  - "Läs upp recept"-knapp med TTS
  - Textstorlek följer systeminställningar

---

## 🔍 **Fas 20: Design-Genomgång**

### **Innan release, genomför omfattande design-check:**
- [ ] Sök igenom ALLA .dart filer efter hårdkodade värden
- [ ] Kontrollera att inga Colors.* används direkt (förutom Colors.black26 för overlays)
- [ ] Verifiera att alla padding/margin använder AppTheme
- [ ] Säkerställ att alla text styles kommer från AppTheme
- [ ] Kontrollera att alla BorderRadius använder AppTheme
- [ ] Granska att alla ikonstorlekar använder AppTheme.iconSize*
- [ ] Validera att alla decorations använder AppTheme-metoder

**Verktyg för genomgång:**
```bash
# Sök efter potentiella hårdkodade värden
grep -r "EdgeInsets\." lib/ --include="*.dart" | grep -v "AppTheme"
grep -r "Color(0x" lib/ --include="*.dart" | grep -v "app_theme.dart"
grep -r "BorderRadius\." lib/ --include="*.dart" | grep -v "AppTheme"
grep -r "TextStyle(" lib/ --include="*.dart" | grep -v "app_theme.dart"
```

---

## 🏗️ **Fas 21: Kodkvalitet & Refaktorering (6-8 timmar)**

### **🎯 Professionell kodgranskning:**
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

## 🧪 **Fas 22: Unit Tests (4-5 timmar)**

### **🎯 Testa kärnfunktionalitet:**
- [ ] **Service-tester:**
  - MenuService (generering, validering)
  - ShoppingListService (merge, sortering)
  - RecipeService (CRUD-operationer)
- [ ] **Validator-tester:**
  - Form validators (email, recept)
  - URL validation för import
- [ ] **Model-tester:**
  - Recipe serialization/deserialization
  - ShoppingItem aggregering
- [ ] **Utilities-tester:**
  - Text parsing funktioner
  - Enhetskonvertering
- [ ] **Setup:**
  - Minst 70% code coverage
  - CI körs automatiskt vid push

---

## 📱 **Fas 24: Store Listings & Release Prep (5-6 timmar)**

### **🎯 App Store/Google Play förberedelser:**
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
- [ ] **iOS Privacy Manifest (NYTT KRAV!):**
  - Skapa PrivacyInfo.xcprivacy
  - Deklarera kamera-användning
  - Deklarera fotobibliotek-access
  - Deklarera nätverksanvändning
- [ ] **Play Integrity API (NYTT KRAV!):**
  - Implementera com.google.android.play:integrity
  - Server-side token verifiering
  - Fallback för äldre enheter

---

## 🤝 **Fas 25: Grundläggande social (4-5 timmar)**

### **🎯 Implementation:**
- [ ] Offentliga receptlänkar (read-only webb-vy)
- [ ] "Kopiera recept" från delad länk till egen samling
- [ ] Grundläggande betygsystem (1-5 stjärnor)
- [ ] Visa genomsnittsbetyg på recept
- [ ] Förbered datastruktur för framtida community-features
- [ ] Delningsstatistik i Analytics

---

## 🚀 **Fas 26: CI/CD Setup (3-4 timmar)**

### **🎯 Implementation:**
- [ ] GitHub Actions workflow
- [ ] Automatisk Flutter analyze
- [ ] Test-körning vid varje push
- [ ] Build APK/IPA automatiskt
- [ ] Deploy till Firebase App Distribution

---

## 🤖 **Fas 27: AI-Integration (FRAMTIDA)**

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
7. **Source URL komplett** ⭐ ✅
8. **Komplett MVVM-arkitektur** ⭐

---

## 📈 **Projektets hälsa: UTMÄRKT**

Appen är nu i mycket bra skick:
- ✅ Molnbaserad med realtids-synk
- ✅ Professionell arkitektur fullt dokumenterad
- ✅ Admin-verktyg för innehållshantering
- ✅ Säker med Firebase Auth
- ✅ Source URL-implementation KLAR
- ✅ Skalbar och underhållbar kodbas
- ✅ Redo för UX-förbättringar och power-features

**Nästa fokus:** UX-förbättringar för en fantastisk användarupplevelse!

---

## 🎯 **Prioritering framåt:**

### **Essentiella features (Fas 9-17):**
1. **Core UX** → 2-3 timmar ⭐
2. **Video-import (utökad)** → 5-6 timmar ⭐ 
3. **Sortering & Filter** → 2-3 timmar
4. **Delning & Export** → 3-4 timmar ⭐
5. **Offline-stöd (med Hive)** → 3-4 timmar
6. **"Senast tillagad"** → 1 timme
7. **Flera bilder per recept** → 4-5 timmar ⭐
8. **Onboarding** → 2-3 timmar
9. **Säkerhet & Analytics (utökad)** → 8-9 timmar ⭐
10. **Portions & Enhetshantering** → 3-4 timmar ⭐

**Total tid för essentiella features: ~36-43 timmar**

### **Kvalitetssäkring & Release:**
11. **Dark Mode** → 2-3 timmar ⭐
12. **Accessibility** → 3-4 timmar ⭐
13. **Design-genomgång** → 1 timme
14. **Kodkvalitet & Refaktorering** → 6-8 timmar ⭐⭐
15. **Beta-teststruktur** → 2-3 timmar ⭐ 
16. **Unit Tests** → 4-5 timmar ⭐
17. **Store Listings (utökad)** → 5-6 timmar ⭐

**Total tid för kvalitet & release: ~23-30 timmar**

### **Framtida utveckling:**
18. **Grundläggande social** → 4-5 timmar
19. **CI/CD Setup** → 3-4 timmar
20. **AI-Integration** → 5-8 timmar (inkl. avancerad video-import)

**Total tid till komplett app: ~70-87 timmar**

---

## 📝 **Uppdateringar i denna version:**
- Utökat Fas 9.5: YouTube API kvothantering + upphovsrätts-disclaimer (+1 timme)
- Specificerat Fas 12: Hive cache implementation
- Utökat Fas 16: Remote Config, Secrets-hantering, Beta-events, Budget (+3 timmar)
- Utökat Fas 24: iOS Privacy Manifest + Play Integrity API (+2 timmar)
- Säkerhetskritiska tillägg för 2025-krav
- Total ökning: ~8 timmar för kritiska säkerhetskrav