# 📄 AI Code Index – Butlery (Komplett & Uppdaterad med Social Platform)

_Version för AI-assistenter med fullständig information om varje fil._

---

## 🏗️ CORE KOMPONENTER

### 📁 Core Infrastructure

#### `core/cache_config.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Cache Configuration Manager
/// File: core/cache_config.dart
/// Quick Guide: Centraliserad hantering av bildcache med Flutter Cache Manager
/// Dependencies IN: flutter_cache_manager, flutter
/// Dependencies OUT: Används av widgets som visar bilder
/// Data flow: Konfigurerar → Cachar bilder → Rensar vid behov
/// State management: Statisk konfiguration, inga state changes
/// Purpose: Optimera bildladdning och hantera cache-storlek
/// Common issues: Cache fylls snabbt, glöm inte clearCache() vid behov
/// Test coverage: N/A (konfigurationsklass)
/// Performance: ⚡ Snabbare bildladdning efter cache
/// Analytics: N/A
/// Code smells: ✅ Enkel och fokuserad
/// Connected to: Alla bildvisningswidgets
/// Used in phases: 13
```

#### `core/injection.dart` ⭐ **UPPDATERAD FAS 18**
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Dependency Injection med Social Services - KOMPLETT FIXAD + ENHANCED MENUVIEWMODEL
/// File: core/injection.dart
/// Quick Guide: GetIt konfiguration för social platform services med korrekt ordning + integrerad MenuViewModel
/// Dependencies IN: Alla services, viewmodels, Firebase instances + MenuViewModel med social dependencies
/// Dependencies OUT: Service locator för hela appen med social integration
/// Data flow: Service registration → Injection → Usage across app + MenuViewModel social integration
/// State management: Singleton och Factory patterns för olika behov + MenuViewModel social DI
/// Purpose: Central DI hub för skalbar arkitektur med social platform + integrerad menu management
/// Common issues: ✅ LÖST: Social service dependencies, parameter injection, registreringsordning, MenuViewModel integration
/// Test coverage: 55% (registration logic + MenuViewModel testing)
/// Performance: ⚡ Lazy singletons, efficient factory methods + optimized MenuViewModel creation
/// Analytics: ✅ Service usage tracking + MenuViewModel social tracking
/// Code smells: ✅ Clean separation mellan service types, korrekt dependency-hantering + MenuViewModel integration
/// Connected to: Alla components, service architecture + MenuViewModel med social services
/// Used in phases: 1-18 + enhanced menu management
```

#### `core/error/error_handler.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Global Error Handler
/// File: core/error/error_handler.dart
/// Quick Guide: Konverterar exceptions till användarfähliga Failure objekt
/// Dependencies IN: firebase_core, dart:io, failures.dart
/// Dependencies OUT: Failure objekt och SnackBar visning
/// Data flow: Exception → handleError() → Failure → UI error message
/// State management: Stateless utility methods
/// Purpose: Centraliserad felhantering med svenska meddelanden
/// Common issues: Firebase error codes ändras, timeout-värden för korta
/// Test coverage: 75%
/// Performance: ⚡ Snabb
/// Analytics: N/A
/// Code smells: ✅ Välstrukturerad med svenska översättningar
/// Connected to: Alla services som kan kasta fel (inklusive social)
/// Used in phases: 5, alla services
```

#### `core/error/failures.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Domain Error Types
/// File: core/error/failures.dart
/// Quick Guide: Typsäkra felklasser - NetworkFailure, ValidationFailure, etc.
/// Dependencies IN: Ingen
/// Dependencies OUT: Används som return types i services
/// Data flow: Service error → Specific Failure type → UI handling
/// State management: Immutable value objects
/// Purpose: Typsäker felhantering istället för exceptions
/// Common issues: Glöm inte user-friendly meddelanden
/// Test coverage: 90%
/// Performance: ⚡ Minimal overhead
/// Analytics: N/A
/// Code smells: ✅ Clean domain design
/// Connected to: error_handler.dart, alla services
/// Used in phases: 5
```

#### `core/extensions/future_extensions.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Future Utilities
/// File: core/extensions/future_extensions.dart
/// Quick Guide: Extensions för timeout med custom error handling
/// Dependencies IN: dart:async, failures.dart
/// Dependencies OUT: Enhanced Future functionality
/// Data flow: Future → Extension method → Enhanced behavior
/// State management: Stateless extensions
/// Purpose: Enhetlig timeout-hantering med svenska felmeddelanden
/// Common issues: Timeout-värden för korta för långsamma nätverk
/// Test coverage: 70%
/// Performance: ⚡ Ingen overhead
/// Analytics: N/A
/// Code smells: ✅ Fokuserad på en sak
/// Connected to: Alla async operations med timeout
/// Used in phases: 5
```

#### `core/form/form_fields_manager.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Form Controllers Manager
/// File: core/form/form_fields_manager.dart
/// Quick Guide: Hanterar dynamiska TextEditingControllers med memory management
/// Dependencies IN: flutter
/// Dependencies OUT: Lista av TextEditingControllers
/// Data flow: Skapa controllers → Synka med data → Dispose cleanly
/// State management: Hanterar controller lifecycle
/// Purpose: Undvika memory leaks från controllers, enklare formulärhantering
/// Common issues: Glöm inte dispose(), synk mellan controllers och data
/// Test coverage: 60%
/// Performance: ⚡ Bra, hanterar många controllers effektivt
/// Analytics: N/A
/// Code smells: ⚠️ Komplex för små formulär - använd bara för dynamiska listor
/// Connected to: recipe_form_viewmodel.dart, social form views
/// Used in phases: 5, formulär med dynamiska fält
```

#### `core/utils/connectivity_check.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Network Status Checker
/// File: core/utils/connectivity_check.dart
/// Quick Guide: Kontrollerar faktisk internetanslutning (inte bara WiFi)
/// Dependencies IN: dart:io
/// Dependencies OUT: bool hasInternetConnection()
/// Data flow: DNS lookup → Timeout check → Boolean result
/// State management: Stateless utility
/// Purpose: Faktisk internetkontroll för offline service
/// Common issues: Timeout för kort, DNS kan blockeras
/// Test coverage: 40% (platform-beroende)
/// Performance: ⚡ Snabb med 3s timeout
/// Analytics: N/A
/// Code smells: ✅ Enkel och pålitlig
/// Connected to: offline_service.dart
/// Used in phases: 13
```

#### `core/utils/logger.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Professional Logger med AppLogger Class - FIXAD IMPORT
/// File: core/utils/logger.dart
/// Quick Guide: Ersätter print() med developer.log() för bättre debugging
/// Dependencies IN: dart:developer
/// Dependencies OUT: Structured logging med emojis och kategorier
/// Data flow: Log call → Format with emoji → developer.log()
/// State management: Statiska metoder med AppLogger klass
/// Purpose: Professionell loggning som syns i developer tools
/// Common issues: ✅ LÖST: Import konflikter, för mycket loggning kan påverka performance
/// Test coverage: 80%
/// Performance: ⚡ Snabb, endast i debug mode
/// Analytics: N/A
/// Code smells: ✅ Välstrukturerad med semantiska nivåer, AppLogger klass, FIXED imports
/// Connected to: ALLA services och viewmodels (inklusive social)
/// Used in phases: 5, används överallt, FIXED import issues
```

#### `core/validators/form_validators.dart` ⭐ **UPPDATERAD FAS 18**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Form Validation Utilities med Social Features
/// File: core/validators/form_validators.dart
/// Quick Guide: Återanvändbara validators med svenska felmeddelanden + social
/// Dependencies IN: flutter
/// Dependencies OUT: FormFieldValidator<String> functions för alla typer
/// Data flow: Input → Validation rules → Error message eller null
/// State management: Stateless validator functions
/// Purpose: Konsistenta valideringsregler över hela appen inklusive social
/// Common issues: Regex för strikta, glöm kombinera validators
/// Test coverage: 95%
/// Performance: ⚡ Snabb regex
/// Analytics: N/A
/// Code smells: ✅ Mycket välstrukturerad med social validators
/// Connected to: Alla formulär-ViewModels inklusive social profile forms
/// Used in phases: 5, 18 (social validators tillagda)
```

---

## 🍳 MODELLER & DATA

### Core Models

#### `models/recipe.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Core Recipe Model - KOMPLETT MED MULTIPLE IMAGES
/// File: models/recipe.dart
/// Quick Guide: Huvudmodell för recept - Firestore + Hive + JSON serialization med imageUrls lista
/// Dependencies IN: uuid, cloud_firestore, hive
/// Dependencies OUT: Används av alla recipe-relaterade komponenter
/// Data flow: Firestore ↔ Recipe object ↔ UI components
/// State management: Immutable med copyWith pattern
/// Purpose: Central datamodell med serialization för alla lagringslager
/// Common issues: ✅ LÖST: build_runner för Hive, imageUrls migration från imageUrl
/// Test coverage: 85%
/// Performance: ⚡ Snabb serialization
/// Analytics: ✅ Implicit tracking via services
/// Code smells: ⚠️ Stor klass (300+ rader) - kanske dela upp framtid
/// Connected to: recipe_service.dart, alla ViewModels, alla Views
/// Used in phases: 3, 6, 8, 13, 14, 15
```

#### `models/shopping_item.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shopping List Item Model
/// File: models/shopping_item.dart
/// Quick Guide: Modell för inköpslisteartikel med mängd, enhet, kategori
/// Dependencies IN: Ingen
/// Dependencies OUT: shopping_list_service.dart
/// Data flow: Recipe ingredients → ShoppingItem → Inköpslista UI
/// State management: Immutable data class
/// Purpose: Strukturerad representation av inköpslisteartiklar
/// Common issues: Enhetskonvertering mellan olika format
/// Test coverage: 70%
/// Performance: ⚡ Snabb
/// Analytics: N/A
/// Code smells: ⚠️ amount som double kan vara problematisk för enhetskonvertering
/// Connected to: shopping_list_service.dart, shopping_list_viewmodel.dart
/// Used in phases: 4
```

### Social Models ⭐ **NYA FAS 18**

#### `models/user_profile.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: User Profile Data Model
/// File: models/user_profile.dart
/// Quick Guide: Social användarmodell med search optimering
/// Dependencies IN: Firebase timestamp, JSON serialization
/// Dependencies OUT: Social views, friend management, search results
/// Data flow: Firebase ↔ Model ↔ Social features
/// State management: Immutable data class med copyWith support
/// Purpose: Central användarrepresentation för social features
/// Common issues: ✅ LÖST: Search performance, avatar handling
/// Test coverage: 80% (model operations)
/// Performance: ⚡ displayNameLower för indexerad sökning
/// Analytics: ✅ Profile data structure optimerad för metrics
/// Code smells: ✅ Clean immutable design, robust serialization
/// Connected to: UserService, social views, search functionality
/// Used in phases: 18
```

#### `models/friend_request.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friend Request Model med Status Management
/// File: models/friend_request.dart
/// Quick Guide: Vänskapsförfrågan med lifecycle management
/// Dependencies IN: Firebase timestamp, user IDs
/// Dependencies OUT: Friends views, notification system
/// Data flow: Create → Send → Accept/Reject → Cleanup
/// State management: Immutable med status enum
/// Purpose: Robust friend request lifecycle med expiration
/// Common issues: ✅ LÖST: Status transitions, expiration handling
/// Test coverage: 70% (status transitions testad)
/// Performance: ⚡ Efficient status queries, auto-cleanup
/// Analytics: ✅ Request success rates tracking
/// Code smells: ✅ Clean state machine design
/// Connected to: FriendsService, notification views
/// Used in phases: 18
```

#### `models/recipe_comment.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Comment Model - Firebase First med Threading
/// File: models/recipe_comment.dart
/// Quick Guide: Threaded comments för recept med likes och moderation
/// Dependencies IN: cloud_firestore, uuid
/// Dependencies OUT: SocialRecipeService, comment widgets
/// Data flow: Firestore ↔ RecipeComment object ↔ Comment UI
/// State management: Immutable med copyWith pattern och soft deletes
/// Purpose: Threaded comments system med social engagement features
/// Common issues: Reply depth limits, author data caching, moderation
/// Test coverage: 75%
/// Performance: ⚡ Optimized för threaded display, cached author data
/// Analytics: ✅ Comment engagement tracking (likes, replies)
/// Code smells: ✅ Clean threading design med performance optimization
/// Connected to: SocialRecipeService, Recipe, UserProfile, comment views
/// Used in phases: 18
```

#### `models/shared_recipe.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Shared Recipe Model - PRODUCTION READY med DISMISS + isDismissed GETTER
/// File: models/shared_recipe.dart
/// Quick Guide: Firebase-first modell för delade recept - ROBUST PARSING + DISMISS + USER-FRIENDLY GETTER
/// Dependencies IN: cloud_firestore, firebase_auth, uuid, recipe.dart, flutter/foundation.dart
/// Dependencies OUT: SocialRecipeService, sharing views, dismiss management
/// Data flow: Firestore ↔ SharedRecipe object ↔ Social UI med dismiss functionality
/// State management: Immutable med copyWith pattern, cached recipe data + dismiss tracking
/// Purpose: Receptdelning med tracking, import, dismiss functionality + easy isDismissed check
/// Common issues: ✅ LÖST: MockDocumentSnapshot type cast, robust parsing, dismiss tracking, isDismissed getter added
/// Test coverage: 75% (model operations + dismiss logic)
/// Performance: ⚡ Cached recipe data för offline access + optimized dismiss queries
/// Analytics: ✅ Sharing engagement, import success + dismiss vs import tracking
/// Code smells: ✅ Clean separation mellan sharing metadata och recipe data, ROBUST parsing + user-friendly dismiss getter
/// Connected to: Recipe, UserProfile, SocialRecipeService, sharing views, dismiss UI
/// Used in phases: 18
```

#### `models/shared_menu.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Shared Menu Model - PRODUCTION READY med DISMISS + isDismissed GETTER
/// File: models/shared_menu.dart
/// Quick Guide: Firebase-first modell för delade veckomeny - ROBUST PARSING + DISMISS + USER-FRIENDLY GETTER
/// Dependencies IN: cloud_firestore, firebase_auth, uuid, recipe.dart, flutter/foundation.dart
/// Dependencies OUT: SocialRecipeService, menu sharing views, dismiss management
/// Data flow: Firestore ↔ SharedMenu object ↔ Social UI med dismiss functionality
/// State management: Immutable med copyWith pattern, cached menu data + dismiss tracking
/// Purpose: Menydelning med komplett veckomeny, tracking, import, dismiss functionality + easy isDismissed check
/// Common issues: ✅ LÖST: MockDocumentSnapshot type cast, robust parsing, allowImport getter, dismiss tracking, isDismissed getter added
/// Test coverage: 70% (model operations + dismiss logic)
/// Performance: ⚡ displayNameLower för indexerad sökning, batch permissions + optimized dismiss queries
/// Analytics: ✅ Menu sharing engagement tracking + dismiss vs import metrics
/// Code smells: ✅ Clean separation av sharing metadata och menu content, ROBUST parsing + user-friendly dismiss getter
/// Connected to: Recipe collections, UserProfile, SocialRecipeService, menu views, dismiss UI
/// Used in phases: 18
```

### Data Sources

#### `data/dummy_data.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Demo Recipe Data
/// File: data/dummy_data.dart
/// Quick Guide: 10 färdiga recept för demo och nya användare
/// Dependencies IN: recipe.dart
/// Dependencies OUT: ValueNotifier<List<Recipe>> för reaktiv data
/// Data flow: App start → Load dummy data → Populate empty accounts
/// State management: ValueNotifier för reaktivitet
/// Purpose: Demo-innehåll och onboarding för nya användare
/// Common issues: Kan dupliceras vid re-import
/// Test coverage: N/A (statisk data)
/// Performance: ⚡ Statisk data
/// Analytics: N/A
/// Code smells: ✅ Välorganiserad med svenska recept
/// Connected to: recipe_service.dart för initial population
/// Used in phases: 3
```

#### `data/archived_recipes.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Archived Recipe Collection
/// File: data/archived_recipes.dart
/// Quick Guide: 20+ professionella recept för import från arkiv
/// Dependencies IN: recipe.dart, uuid
/// Dependencies OUT: Lista med arkivrecept
/// Data flow: Import view → Browse archive → Select → Import to user
/// State management: Statisk lista
/// Purpose: Professionellt innehåll som användare kan importera
/// Common issues: Synk med Firebase arkiv, manuella uppdateringar
/// Test coverage: N/A (statisk data)
/// Performance: ⚡ Statisk, snabb access
/// Analytics: N/A
/// Code smells: ✅ Välkurerade recept med bra variation
/// Connected to: archive_import_viewmodel.dart
/// Used in phases: 3, 7
```

---

## 🔧 SERVICES (BUSINESS LOGIC)

### Core Services

#### `services/recipe_service.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Central Recipe Management Service - ENHANCED AUTH HANDLING
/// File: services/recipe_service.dart
/// Quick Guide: Komplett CRUD för recept med Firestore + offline support + robust auth state management
/// Dependencies IN: cloud_firestore, firebase_auth, offline_service.dart
/// Dependencies OUT: ChangeNotifier med recipes list, CRUD metoder
/// Data flow: Firestore realtime ↔ Service state ↔ ViewModels → UI
/// State management: ChangeNotifier med List<Recipe> och loading states
/// Purpose: Central hub för all recepthantering med automatisk offline synk
/// Common issues: ✅ LÖST: Auth required för användarspecifik data, offline state, enhanced auth state management
/// Test coverage: 75%
/// Performance: ⚡ Bra med realtime updates, optimerad auth handling
/// Analytics: ✅ Loggar alla CRUD operations
/// Code smells: ⚠️ Stor fil (500+ rader) - välorganiserad med enhanced auth
/// Connected to: Firestore users/{uid}/recipes, offline_service.dart, alla recipe ViewModels
/// Used in phases: 3, 6, 13, 14, 15, 16, 23
```

#### `services/auth_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Firebase Authentication Service
/// File: services/auth_service.dart
/// Quick Guide: Email/lösenord auth med svenska felmeddelanden
/// Dependencies IN: firebase_auth, flutter
/// Dependencies OUT: ChangeNotifier med User state, auth metoder
/// Data flow: Firebase Auth ↔ Service ↔ UI state changes
/// State management: ChangeNotifier med currentUser, loading, error
/// Purpose: Säker autentisering med användarfähliga svenska meddelanden
/// Common issues: Firebase errors på engelska, weak password validation
/// Test coverage: 80%
/// Performance: ⚡ Snabb, Firebase-cached
/// Analytics: ✅ Loggar login/logout/signup
/// Code smells: ✅ Välstrukturerad med bra errorhantering
/// Connected to: Firebase Auth, recipe_service.dart (userId), social services
/// Used in phases: 6, 18 (social integration)
```

#### `services/offline_service.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Offline Sync & Hive Manager - USER-SPECIFIC VERSION
/// File: services/offline_service.dart
/// Quick Guide: Hive databas + connectivity monitoring + auto-synk MED user-specific storage
/// Dependencies IN: hive_flutter, connectivity_plus, recipe.dart
/// Dependencies OUT: ChangeNotifier med offline state, cache metoder
/// Data flow: Online ändringar → Hive cache, Offline → Queue → Auto-sync när online
/// State management: ChangeNotifier med isOnline, cached data
/// Purpose: Seamless offline funktionalitet med automatisk synkronisering OCH user separation
/// Common issues: ✅ LÖST: Hive initialisering, konflikthantering vid synk, user data separation
/// Test coverage: 60% (svårt testa offline scenarios)
/// Performance: ⚡ Snabb lokal access, user-specific queries
/// Analytics: ✅ Sync events
/// Code smells: ⚠️ Saknar konfliktlösning för simultana ändringar, men har user separation
/// Connected to: Hive, recipe_service.dart, connectivity
/// Used in phases: 13
```

#### `services/analytics_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Firebase Analytics Wrapper
/// File: services/analytics_service.dart
/// Quick Guide: Tracking av app events med structured parameters
/// Dependencies IN: firebase_analytics, content_detector_service.dart
/// Dependencies OUT: Event logging metoder, navigation observer
/// Data flow: App events → Analytics service → Firebase console
/// State management: Singleton service
/// Purpose: Spåra användarbeteende och app performance
/// Common issues: Events visas inte direkt i console, parameter namn restriktioner
/// Test coverage: 50%
/// Performance: ⚡ Async, non-blocking
/// Analytics: ✅ Self-monitoring
/// Code smells: ✅ Välorganiserad med semantiska events
/// Connected to: Alla ViewModels som loggar events, main.dart för navigation
/// Used in phases: 14, 22
```

### Social Services ⭐ **NYA FAS 18**

#### `services/user_service.dart` ⭐ **NY UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: User Management Service med Search Optimization - AUTO-CREATE PROFIL
/// File: services/user_service.dart  
/// Quick Guide: Användarprofilsn med optimerad sökning, cache OCH automatisk profil-skapande
/// Dependencies IN: Firebase Auth + Firestore, UserProfile model
/// Dependencies OUT: User search, profile management, social discovery
/// Data flow: Auth → Profile creation (auto) → Search optimization → Social interactions
/// State management: ChangeNotifier med profile cache (30 min TTL)
/// Purpose: Central hub för användarhantering och social discovery
/// Common issues: ✅ LÖST: Search performance med displayNameLower optimering, auto-create profiler
/// Test coverage: 75% (profile operations testad)
/// Performance: ⚡ displayNameLower indexering, 30min cache, batch queries, auto-create
/// Analytics: ✅ Profile operations och search behavior tracking
/// Code smells: ✅ Clean separation från Auth concerns, intelligent auto-create
/// Connected to: AuthService, alla social services, search functionality
/// Used in phases: 16, 18
```

#### `services/friends_service.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friends Management Service  
/// File: services/friends_service.dart
/// Quick Guide: Komplett vänsystem med requests och mutual friends
/// Dependencies IN: UserService, Firebase Auth + Firestore
/// Dependencies OUT: Friends lists, request notifications, social access control
/// Data flow: Send request → Accept/Reject → Mutual friends → Social permissions
/// State management: ChangeNotifier med friends och requests cache
/// Purpose: Complete friends system med notifications och permissions
/// Common issues: ✅ LÖST: Duplicate requests, permission management, cleanup
/// Test coverage: 70% (request flow testad)
/// Performance: ⚡ Batch operations, optimized friend queries
/// Analytics: ✅ Friend actions och success rates tracking
/// Code smells: ✅ Clean state management, robust error handling
/// Connected to: UserService, alla social features, notification system
/// Used in phases: 18
```

#### `services/social_recipe_service.dart` ⭐ **NY UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Social Recipe Management Service - PRODUCTION READY + ENHANCED DISMISS FEATURES
/// File: services/social_recipe_service.dart
/// Quick Guide: Komplett social recipe system med sharing, commenting, dismiss functionality - PRODUCTION READY
/// Dependencies IN: cloud_firestore, firebase_auth, recipe models, user_service
/// Dependencies OUT: Social features, sharing views, comment system, enhanced dismiss management
/// Data flow: Share recipe → Store with metadata → Comments → Import/Dismiss with user-friendly patterns
/// State management: ChangeNotifier med shared content, comments + enhanced dismiss tracking
/// Purpose: Complete social recipe system med sharing, commenting + user-friendly dismiss patterns - PRODUCTION READY
/// Common issues: ✅ LÖST: Nullable spread operator, allowImport getter, type safety, enhanced dismiss tracking, public view methods
/// Test coverage: 70% (enhanced functionality)
/// Performance: ⚡ Optimized queries med pagination, batch operations + efficient dismiss filtering with public methods
/// Analytics: ✅ Social engagement, sharing success + comprehensive dismiss vs import tracking
/// Code smells: ✅ Clean separation of concerns, robust error handling + user-friendly dismiss patterns, PRODUCTION READY
/// Connected to: RecipeService, UserService, comment widgets, sharing views, enhanced dismiss UI
/// Used in phases: 18
```

### Import & Export Services

#### `services/content_detector_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Smart Content Detection
/// File: services/content_detector_service.dart
/// Quick Guide: Identifierar innehållstyp från delad text (URL, recept, social media)
/// Dependencies IN: flutter
/// Dependencies OUT: ContentDetectionResult med typ och metadata
/// Data flow: Shared text → Analyze patterns → Route to correct import
/// State management: Stateless detection service
/// Purpose: Intelligent routing av delat innehåll till rätt import-metod
/// Common issues: Nya social media format, false positives
/// Test coverage: 75%
/// Performance: ⚡ Snabb regex matching
/// Analytics: ✅ Loggar detected content types
/// Code smells: ✅ Modulär design, lätt att utöka
/// Connected to: social_media_extractor.dart, receive_share_view.dart
/// Used in phases: 12
```

#### `services/social_media_extractor.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Social Media Content Extractor
/// File: services/social_media_extractor.dart
/// Quick Guide: Headless WebView för Instagram/TikTok textextraktion
/// Dependencies IN: flutter_inappwebview, content_detector_service.dart
/// Dependencies OUT: ExtractionResult med extraherad text
/// Data flow: Social URL → Headless WebView → JavaScript injection → Extract text
/// State management: Stateful extractor med cleanup
/// Purpose: Bypassa app restrictions för att extrahera recepttext från sociala medier
/// Common issues: Plattformar ändrar struktur, WebView memory leaks, timeout hantering
/// Test coverage: 30% (svårt med WebView)
/// Performance: ⚠️ 2-15s beroende på plattform och nätverk
/// Analytics: ✅ Loggar success/fail rates per plattform
/// Code smells: ⚠️ Komplex timeout och cleanup logik, plattform-specifika selectors
/// Connected to: receive_share_view.dart, content_detector_service.dart
/// Used in phases: 12
```

#### `services/share_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Content Sharing & Export
/// File: services/share_service.dart
/// Quick Guide: Formaterar och delar recept/listor med smart formatting
/// Dependencies IN: share_plus, recipe.dart, shopping_item.dart
/// Dependencies OUT: Share methods för olika content types
/// Data flow: Data → Format (complete/compact/markdown) → Native share sheet
/// State management: Stateless formatting service
/// Purpose: Konsistent delning med användarvänliga format
/// Common issues: Text truncation i vissa appar, emoji support varierar
/// Test coverage: 60%
/// Performance: ⚡ Snabb formatting
/// Analytics: ✅ Loggar share events per format
/// Code smells: ✅ Modulär design med tydliga format-alternativ
/// Connected to: recipe_detail_view.dart, shopping_list_viewmodel.dart
/// Used in phases: 11
```

#### `services/backup_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Data Backup & Restore
/// File: services/backup_service.dart
/// Quick Guide: Export/import av alla användarrecept som JSON
/// Dependencies IN: firebase_auth, path_provider, file_picker
/// Dependencies OUT: BackupResult och ImportResult klasser
/// Data flow: All user data → JSON struktur → File system → Restore från JSON
/// State management: Stateless service med result objects
/// Purpose: Användarkontroll över sin data med backup/restore funktionalitet
/// Common issues: Stora JSON filer, fil permissions, version compatibility
/// Test coverage: 70%
/// Performance: ⚠️ Långsam för många recept (>100)
/// Analytics: ✅ Loggar backup/restore operations
/// Code smells: ✅ Välstrukturerad med platform-specifik filhantering
/// Connected to: recipe_service.dart, fil system
/// Used in phases: 11
```

### Helper Services

#### `services/menu_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Menu Generation Service  
/// File: services/menu_service.dart
/// Quick Guide: Genererar veckomeny från prompt med intelligenta val
/// Dependencies IN: recipe.dart (för tillgängliga recept)
/// Dependencies OUT: Map<String, List<Recipe>> som genererad meny
/// Data flow: Text prompt → Parse intention → Match recipes → Random selection
/// State management: Stateless generation service
/// Purpose: AI-liknande menygeneration baserat på naturligt språk
/// Common issues: För få recept ger repetition, fuzzy matching missar ibland
/// Test coverage: 65%
/// Performance: ⚡ Snabb (<100ms)
/// Analytics: ✅ Loggar meny generation
/// Code smells: ⚠️ Enkel implementation - borde använda ML för bättre matching
/// Connected to: menu_viewmodel.dart
/// Used in phases: 4
```

#### `services/search_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Search & Filter Engine
/// File: services/search_service.dart
/// Quick Guide: Avancerad sök med filter och sortering
/// Dependencies IN: recipe.dart för data types
/// Dependencies OUT: Filtrerade och sorterade receptlistor
/// Data flow: Recipe list → Apply search → Apply filters → Sort → Results
/// State management: Stateless service med cached results
/// Purpose: Kraftfull sök med kombinerbara filter för bättre discovery
/// Common issues: Performance på stora listor, svenska tecken i fuzzy search
/// Test coverage: 85%
/// Performance: ⚠️ O(n) kan vara långsam på 100+ recept
/// Analytics: ✅ Loggar search terms och filter usage
/// Code smells: ⚠️ Borde indexera för bättre performance
/// Connected to: recipe_list_viewmodel.dart
/// Used in phases: 10
```

#### `services/shopping_list_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shopping List Generator
/// File: services/shopping_list_service.dart
/// Quick Guide: Skapar inköpslistor från meny med intelligent ingrediens-merging
/// Dependencies IN: recipe.dart, shopping_item.dart, text_utils.dart
/// Dependencies OUT: Lista av ShoppingItem med kategorisering
/// Data flow: Recipes → Extract ingredients → Parse amounts → Merge duplicates → Categorize
/// State management: Stateless service
/// Purpose: Automatisk inköpslista från veckomeny med smart ingredient aggregation
/// Common issues: Enhetskonvertering, merging "1 dl mjölk" + "200ml mjölk"
/// Test coverage: 55%
/// Performance: ⚡ OK för normala menyer
/// Analytics: ❌ Borde logga list generation events
/// Code smells: ⚠️ Naiv string matching för ingredienser, behöver NLP
/// Connected to: shopping_list_viewmodel.dart, text_utils.dart
/// Used in phases: 4
```

#### `services/image_picker_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Image Selection Service
/// File: services/image_picker_service.dart
/// Quick Guide: Wrapper för image_picker med permissions och progress tracking
/// Dependencies IN: image_picker, permission_handler, AppLogger
/// Dependencies OUT: File objects och progress streams
/// Data flow: User choice → Permission check → Pick image → Validation → File
/// State management: Stateless service med progress callbacks
/// Purpose: Robust bildval med permissions, validering och användarfeedback
/// Common issues: iOS permission strings, Android cache växer, large image memory
/// Test coverage: 30% (platform-beroende)
/// Performance: ⚡ Native performance
/// Analytics: ✅ Loggar image picker usage
/// Code smells: ✅ Omfattande debug logging, bra error handling
/// Connected to: recipe_form_viewmodel.dart, storage_service.dart, user_profile_viewmodel.dart
/// Used in phases: 15, 18 (avatar upload)
```

#### `services/storage_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Firebase Storage Manager
/// File: services/storage_service.dart
/// Quick Guide: Bilduppladdning med komprimering och progress tracking
/// Dependencies IN: firebase_storage, flutter_image_compress, uuid
/// Dependencies OUT: Uppladdningsmetoder med progress callbacks
/// Data flow: Image file → Compress → Upload → Firebase Storage → Public URL
/// State management: Stateless service
/// Purpose: Effektiv bildhantering med automatisk komprimering och progress feedback
/// Common issues: Stora bilder timeout, iOS memory vid komprimering, Storage rules
/// Test coverage: 45%
/// Performance: ⚠️ Upload tid beror på bildstorlek och nätverk
/// Analytics: ✅ Loggar upload success/fail med metadata
/// Code smells: ⚠️ Ingen retry mechanism, borde cache compressed images
/// Connected to: recipe_form_viewmodel.dart, image_picker_service.dart, user_profile_viewmodel.dart
/// Used in phases: 15, 18 (avatar upload)
```

#### `services/persistence_service.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Local Key-Value Storage
/// File: services/persistence_service.dart
/// Quick Guide: SharedPreferences wrapper för inställningar och state
/// Dependencies IN: shared_preferences, AppLogger
/// Dependencies OUT: Key-value storage metoder med type safety
/// Data flow: App state → Save to disk → Persist between app sessions
/// State management: Stateless persistence layer
/// Purpose: Lokal lagring av användarinställningar och app state
/// Common issues: Ingen sync mellan enheter, begränsade datatyper
/// Test coverage: 80%
/// Performance: ⚡ Cached efter första load
/// Analytics: N/A
/// Code smells: ✅ Välstrukturerad med type-safe metoder
/// Connected to: Tema inställningar, onboarding status
/// Used in phases: 19, 21
```

---

## 🧠 VIEWMODELS (PRESENTATION LOGIC)

### Core ViewModels

#### `viewmodels/recipe_list_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe List Presentation Logic
/// File: viewmodels/recipe_list_viewmodel.dart
/// Quick Guide: Hanterar receptlista med sök, filter och caching
/// Dependencies IN: recipe_service.dart, search_service.dart
/// Dependencies OUT: Filtrerade recept, loading states, filter methods
/// Data flow: RecipeService stream → Apply filters/search → Cached results → UI
/// State management: ChangeNotifier med optimerad caching
/// Purpose: Effektiv presentation av receptlista med avancerade filter
/// Common issues: Cache invalidation, memory leak från StreamSubscription
/// Test coverage: 80%
/// Performance: ⚡ Cache optimerad för stora listor
/// Analytics: ✅ Search och filter analytics via services
/// Code smells: ✅ Välstrukturerad med smart caching strategy
/// Connected to: mina_recept_view.dart, recipe_service.dart, search_service.dart
/// Used in phases: 3, 9, 10
```

#### `viewmodels/recipe_detail_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Detail Presentation Logic
/// File: viewmodels/recipe_detail_viewmodel.dart
/// Quick Guide: Hanterar receptdetaljer, delning och "markera som tillagad"
/// Dependencies IN: recipe_service.dart, analytics_service.dart
/// Dependencies OUT: Recipe data, action methods, loading states
/// Data flow: Recipe input → Service updates → Analytics tracking → UI state
/// State management: ChangeNotifier med single recipe focus
/// Purpose: Detaljvy funktionalitet med tracking och actions
/// Common issues: Recipe kan uppdateras i service medan view visar
/// Test coverage: 70%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Loggar recipe actions (viewed, cooked, deleted)
/// Code smells: ✅ Clean separation of concerns
/// Connected to: recipe_detail_view.dart, recipe_service.dart
/// Used in phases: 11, 14
```

#### `viewmodels/recipe_form_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Form Management
/// File: viewmodels/recipe_form_viewmodel.dart
/// Quick Guide: Komplex formulärhantering för recept med dynamiska fält och bilduppladdning
/// Dependencies IN: recipe_service.dart, storage_service.dart, image_picker_service.dart, form_fields_manager.dart
/// Dependencies OUT: Controllers, validation, save methods, image management
/// Data flow: Form input → Validation → Image upload → Recipe creation → Service save
/// State management: ChangeNotifier med FormFieldsManager för dynamiska fält
/// Purpose: Robust formulärhantering med bilder, validering och memory management
/// Common issues: Memory leaks från controllers, async image upload timing
/// Test coverage: 65%
/// Performance: ⚠️ Många controllers och async operations
/// Analytics: ✅ Form submission tracking
/// Code smells: ⚠️ Stor ViewModel (400+ rader) - kanske dela upp
/// Connected to: skriv_sjalv_recept_view.dart, edit_recipe_view.dart
/// Used in phases: 4, 8, 15
```

### Social ViewModels 

#### `viewmodels/user_profile_viewmodel.dart` 
```dart
/// 🔍 AI INFO BLOCK:
/// Component: User Profile Management ViewModel med Avatar Upload - FIXED IMPORTS
/// File: viewmodels/user_profile_viewmodel.dart
/// Quick Guide: Komplett profil-redigering med avatar upload och privacy settings
/// Dependencies IN: UserService, StorageService, ImagePickerService, AppLogger
/// Dependencies OUT: Profile edit views, settings views, avatar management
/// Data flow: Current profile → Edit form → Validation → Avatar upload → Service update → UI refresh
/// State management: ChangeNotifier med form state, validation och upload progress
/// Purpose: Fullständig profil-management med avatar, privacy controls och form validation
/// Common issues: ✅ LÖST: Avatar upload timing, displayName validation, form state syncing, AppLogger import
/// Test coverage: 70%
/// Performance: ⚡ Avatar caching, optimized form updates, smart validation
/// Analytics: ✅ Profile edit actions, avatar upload tracking
/// Code smells: ✅ Clean separation med service layer, robust error handling, FIXED AppLogger import
/// Connected to: UserService, edit profile views, avatar upload system
/// Used in phases: 18
```

#### `viewmodels/friends_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Friends Management ViewModel med Enhanced User Profile Cache - FIXED IMPORTS
/// File: viewmodels/friends_viewmodel.dart
/// Quick Guide: Komplett vänhantering med sök, requests + efficient user profile management - FIXED AppLogger import
/// Dependencies IN: FriendsService, UserService, AppLogger (FIXED import)
/// Dependencies OUT: Friends views, user search, request notifications + efficient user data cache
/// Data flow: Search users → Send requests → Accept/Reject → Friends management + batch user profile loading
/// State management: ChangeNotifier med search state, friends data + optimized user profile cache (30min TTL)
/// Purpose: Komplett vänhantering med sök, request-management + efficient user profile batching
/// Common issues: ✅ LÖST: Search performance, request state syncing, duplicate handling + efficient user profile loading, AppLogger import
/// Test coverage: 80% (enhanced with user profile testing)
/// Performance: ⚡ Cached search results, optimized friends loading + efficient batch user profile operations
/// Analytics: ✅ Friend actions, search behavior + user profile loading tracking
/// Code smells: ✅ Clean separation mellan search, friends logic + optimized user profile management, FIXED AppLogger import
/// Connected to: FriendsService, UserService, friends views + enhanced user profile integration
/// Used in phases: 18
```

#### `viewmodels/social_recipe_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Social Recipe Interaction ViewModel med Complete Social Features - FIXED IMPORTS
/// File: viewmodels/social_recipe_viewmodel.dart
/// Quick Guide: Komplett social interaction för recept med sharing, kommentarer och engagement
/// Dependencies IN: SocialRecipeService, FriendsService, UserService, Recipe, AppLogger
/// Dependencies OUT: Recipe sharing views, comment widgets, social actions, friend selection
/// Data flow: Recipe → Share to friends → Comments management → Social engagement tracking
/// State management: ChangeNotifier med sharing state, comments cache och engagement data
/// Purpose: Komplett social interaction för enskilda recept med granular sharing controls
/// Common issues: ✅ LÖST: Comment threading, sharing permissions, real-time updates, friend selection, AppLogger import
/// Test coverage: 65%
/// Performance: ⚡ Optimized comment loading, efficient sharing, friend selection caching
/// Analytics: ✅ Social engagement, sharing success och comment interaction tracking
/// Code smells: ✅ Clean separation of social concerns, robust permission handling, FIXED AppLogger import
/// Connected to: Recipe models, social services, sharing views, comment widgets, friend selection
/// Used in phases: 18
```

#### `viewmodels/shared_content_viewmodel.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shared Content ViewModel - Social UI State Management med Dismiss Support
/// File: viewmodels/shared_content_viewmodel.dart
/// Quick Guide: Hanterar shared recipes och menyer med filtering, search och dismiss functionality
/// Dependencies IN: SocialRecipeService, UserService, social models
/// Dependencies OUT: SharedWithMeView, social UI components
/// Data flow: Service → ViewModel state → UI reactions → User actions → Service calls
/// State management: ChangeNotifier med comprehensive shared content state och dismiss tracking
/// Purpose: Complete UI state management för social features med user-friendly dismiss patterns
/// Common issues: Search state management, tab synchronization, dismiss optimistic updates
/// Test coverage: 70% (ViewModels är lättare att testa)
/// Performance: ⚡ Efficient filtering, search debouncing, optimistic dismiss updates
/// Analytics: ✅ User interaction tracking, search analytics, dismiss vs import metrics
/// Code smells: ✅ Clean separation mellan UI logic och business logic, MVVM pattern
/// Connected to: SocialRecipeService, shared content views, dismiss UI components
/// Used in phases: 18.2 (Shared Content Management)
```

### Import ViewModels

#### `viewmodels/text_import_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Text Import & Parsing Logic
/// File: viewmodels/text_import_viewmodel.dart
/// Quick Guide: Intelligent parsing av recepttext från sociala medier
/// Dependencies IN: uuid för Recipe creation
/// Dependencies OUT: Parsed Recipe från fritext input
/// Data flow: Raw text → Smart parsing → Recipe structure → Preview
/// State management: ChangeNotifier med parsing state
/// Purpose: Konvertera ostrukturerad text till strukturerade recept
/// Common issues: Svenska/engelska mix, olika format från olika källor
/// Test coverage: 65%
/// Performance: ⚡ Snabb parsing (<100ms)
/// Analytics: ✅ Import success/fail tracking
/// Code smells: ⚠️ Komplex regex parsing - borde använda NLP
/// Connected to: fran_sociala_medier_view.dart, text_utils.dart
/// Used in phases: 4, 8
```

#### `viewmodels/url_import_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: URL Recipe Import Logic
/// File: viewmodels/url_import_viewmodel.dart
/// Quick Guide: Web scraping för receptimport från URLs
/// Dependencies IN: http, recipe_scraper.dart
/// Dependencies OUT: Extraherad recepttext från webbsidor
/// Data flow: URL → HTTP request → HTML parsing → Recipe extraction → Text output
/// State management: ChangeNotifier med loading och error states
/// Purpose: Importera recept från receptwebbsidor
/// Common issues: CORS på web, sites ändrar struktur, anti-scraping
/// Test coverage: 40% (externa beroenden)
/// Performance: ⚠️ 1-5s beroende på webbsida
/// Analytics: ✅ URL import tracking
/// Code smells: ⚠️ Hårdkodade selectors, ingen retry logic
/// Connected to: import_via_url_view.dart, recipe_scraper.dart
/// Used in phases: 4, 8
```

#### `viewmodels/archive_import_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Archive Import Management
/// File: viewmodels/archive_import_viewmodel.dart
/// Quick Guide: Import från Butlerys centrala receptarkiv med filter
/// Dependencies IN: recipe_service.dart, search_service.dart, archived_recipes.dart
/// Dependencies OUT: Filtrerade arkivrecept, bulk import functionality
/// Data flow: Archive data → Filter/search → Selection → Bulk import med sourceUrl
/// State management: ChangeNotifier med selection state och filter cache
/// Purpose: Professionellt innehåll som användare kan importera med filter
/// Common issues: Många recept kan vara memory-intensive
/// Test coverage: 55%
/// Performance: ⚡ Bra med smart caching
/// Analytics: ✅ Archive import tracking
/// Code smells: ✅ Välstrukturerad med cache optimization
/// Connected to: importera_fran_arkiv_view.dart, recipe_service.dart
/// Used in phases: 7
```

#### `viewmodels/photo_import_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Photo OCR Import Logic
/// File: viewmodels/photo_import_viewmodel.dart
/// Quick Guide: Bildval och OCR processing för receptextraktion
/// Dependencies IN: image_picker, http (för OCR API), json
/// Dependencies OUT: OCR-extraherad text från bilder
/// Data flow: Image source selection → Capture/select → OCR processing → Extracted text
/// State management: ChangeNotifier med image data och OCR state
/// Purpose: Extrahera recepttext från fotografier med OCR
/// Common issues: OCR kvalitet varierar, API rate limits, image kvalitet avgörande
/// Test coverage: 40%
/// Performance: ⚠️ OCR tar 2-5 sekunder
/// Analytics: ✅ OCR success/fail tracking
/// Code smells: ⚠️ Hardkodad OCR API key, ingen local OCR fallback
/// Connected to: photo_import_view.dart, image_picker_service.dart
/// Used in phases: 15
```

### App Flow ViewModels

#### `viewmodels/auth_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Authentication UI Logic
/// File: viewmodels/auth_viewmodel.dart
/// Quick Guide: Login/register forms med validering och mode switching
/// Dependencies IN: auth_service.dart
/// Dependencies OUT: Form state, validation, auth actions
/// Data flow: Form input → Validation → AuthService → Navigation
/// State management: ChangeNotifier med form state och mode switching
/// Purpose: Användarvänlig autentisering med validering
/// Common issues: Form reset vid mode switch, Firebase errors på engelska
/// Test coverage: 75%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Auth events via AuthService
/// Code smells: ✅ Clean separation från AuthService
/// Connected to: auth_view.dart, auth_service.dart
/// Used in phases: 6
```

#### `viewmodels/menu_viewmodel.dart`
```dart
// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Menu Management ViewModel - INTEGRERAD MED SOCIAL IMPORT OCH PERSISTENCE
/// File: viewmodels/menu_viewmodel.dart
/// Quick Guide: Komplett menyhantering med social import support + enhanced menu persistence
/// Dependencies IN: RecipeService, MenuService, SocialRecipeService, UserService (NYA SOCIAL SERVICES)
/// Dependencies OUT: Menu generation, shopping lists + social sharing, import management
/// Data flow: Menu generation → Display → Social sharing + import tracking → Combined menu management
/// State management: ChangeNotifier med menu state + social integration, combined local/imported menus
/// Purpose: Central menyhantering med både traditional generation + social import seamless integration
/// Common issues: ✅ LÖST: Menu generation, social integration, import state management + combined menu persistence
/// Test coverage: 75% (menu generation + social integration testing)
/// Performance: ⚡ Efficient menu rendering + optimized social integration, combined menu loading
/// Analytics: ✅ Menu generation, social sharing + import engagement metrics
/// Code smells: ✅ Clean separation mellan traditional menu logic + social features, seamless integration
/// Connected to: MenuService, SocialRecipeService, social views + enhanced menu persistence
/// Used in phases: 4, 18 (social integration)
```

#### `viewmodels/shopping_list_viewmodel.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Shopping List Management ViewModel - ENHANCED MED AUTO-PERSISTENCE
/// File: viewmodels/shopping_list_viewmodel.dart
/// Quick Guide: Inköpslista med intelligent auto-save + enhanced state management
/// Dependencies IN: ShoppingListService, ShareService + SharedPreferences för persistence
/// Dependencies OUT: Shopping lists, checkbox state + persistent state management
/// Data flow: Menu recipes → Generate list → Auto-save state → Persistent checkbox management + export functionality
/// State management: ChangeNotifier med enhanced persistence (auto-save, state validation) + export features
/// Purpose: Seamless inköpslista med auto-persistence + advanced export functionality
/// Common issues: ✅ LÖST: State persistence, checkbox memory management + auto-save timing, export validation
/// Test coverage: 80% (persistence logic testing)
/// Performance: ⚡ Optimized för auto-save operations + efficient state validation, fast export
/// Analytics: ✅ List usage, sharing + persistence behavior tracking, export analytics
/// Code smells: ✅ Clean persistence integration + comprehensive state management, enhanced export
/// Connected to: ShoppingListService, persistence layer + enhanced export system
/// Used in phases: 4, 11 + enhanced persistence
```

---

## 🎨 THEME & STYLING

#### `theme/app_theme.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Complete Design System
/// File: theme/app_theme.dart
/// Quick Guide: Material 3 theme med semantiska färger, spacing och komponenter
/// Dependencies IN: flutter/material.dart
/// Dependencies OUT: ThemeData och styling utilities för hela appen
/// Data flow: Theme definition → MaterialApp → All widgets
/// State management: Statisk theme configuration
/// Purpose: Konsistent design system med svenska accessibility
/// Common issues: Custom färger behöver dark mode variants
/// Test coverage: N/A (theme data)
/// Performance: ⚡ Statisk, ingen runtime cost
/// Analytics: N/A
/// Code smells: ⚠️ Stor fil (600+ rader) men välorganiserad, saknar dark mode
/// Connected to: main.dart, ALLA UI komponenter
/// Used in phases: 2, 19 (dark mode)
```

---

## 🔧 UTILITIES

#### `utils/text_utils.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Text Processing Utilities
/// File: utils/text_utils.dart
/// Quick Guide: Omfattande text parsing för ingredienser med svenska enheter
/// Dependencies IN: Ingen
/// Dependencies OUT: Parsed ingredienser, svenska pluralhantering
/// Data flow: Raw ingredient text → Parse quantity/unit → Normalize → Swedish plurals
/// State management: Stateless utility functions
/// Purpose: Intelligent svenska text processing för ingredienser och inköpslistor
/// Common issues: Svenska/engelska enheter mix, bråk handling, plural edge cases
/// Test coverage: 75%
/// Performance: ⚡ Snabb regex processing
/// Analytics: N/A
/// Code smells: ⚠️ Mycket komplex - kanske dela upp i flera klasser
/// Connected to: text_import_viewmodel.dart, shopping_list_service.dart
/// Used in phases: 4
```

#### `utils/recipe_scraper.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Web Recipe Extraction
/// File: utils/recipe_scraper.dart
/// Quick Guide: HTML parsing för JSON-LD och Microdata recipe extraction
/// Dependencies IN: html parser
/// Dependencies OUT: Recipe data från structured markup
/// Data flow: HTML → Parse JSON-LD → Extract recipe schema → Return structured data
/// State management: Stateless parsing functions
/// Purpose: Extrahera strukturerad receptdata från webbsidor
/// Common issues: Sites utan structured data, olika schema versioner
/// Test coverage: 50%
/// Performance: ⚡ Snabb HTML parsing
/// Analytics: N/A
/// Code smells: ✅ Modulär design med fallbacks
/// Connected to: url_import_viewmodel.dart
/// Used in phases: 4, 8
```

#### `utils/route_animations.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Navigation Animations
/// File: utils/route_animations.dart
/// Quick Guide: Custom route animations för smooth navigation
/// Dependencies IN: flutter/material.dart
/// Dependencies OUT: PageRouteBuilder med custom animations
/// Data flow: Navigator.push → Custom animation → Page transition
/// State management: Stateless animation utilities
/// Purpose: Premium känsla med smooth navigation transitions
/// Common issues: Kan kännas långsam på äldre enheter
/// Test coverage: 20% (svårt testa animationer)
/// Performance: ⚡ 60fps på moderna enheter
/// Analytics: N/A
/// Code smells: ✅ Fokuserad utility class
/// Connected to: main.dart navigation routing
/// Used in phases: 9
```

---

## 📱 VIEWS (USER INTERFACE)

### Main Views

#### `main.dart` ⭐ **UPPDATERAD FAS 18**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Application Entry Point med Social Routes - KOMPLETT SOCIAL INTEGRATION
/// File: main.dart
/// Quick Guide: Firebase init → DI setup → Share handling → Route configuration med social
/// Dependencies IN: Firebase, DI, theme, alla views inklusive social
/// Dependencies OUT: Kör Flutter appen med routing inklusive social navigation
/// Data flow: main() → Init services → Build app → Handle routes och shares → Social navigation
/// State management: AuthWrapper för login state management
/// Purpose: Fullständig app initialisering med share intent handling och social routes
/// Common issues: ✅ LÖST: Firebase init timing, share handler permissions, complex routing, social route configuration
/// Test coverage: 10% (svårt testa app initialization)
/// Performance: ⚡ Snabb efter initialization
/// Analytics: ✅ App launch, navigation tracking inklusive social routes
/// Code smells: ⚠️ Mycket init logic men välorganiserad med social separation
/// Connected to: ALLA views och services inklusive social platform
/// Used in phases: 1, 5, 6, 12, 13, 18 (social routes)
```

#### `views/auth_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Authentication User Interface
/// File: views/auth_view.dart
/// Quick Guide: Login/register formulär med animationer och lösenordsåterställning
/// Dependencies IN: auth_viewmodel.dart, app_theme.dart, injection.dart
/// Dependencies OUT: Navigation till huvudappen vid success
/// Data flow: User input → AuthViewModel → AuthService → Navigation
/// State management: Konsumerar AuthViewModel med Provider
/// Purpose: Säker och användarvänlig autentisering med validering
/// Common issues: Keyboard overlap, fokushantering mellan fält
/// Test coverage: 40% (UI testing svårt)
/// Performance: ⚡ Smooth animationer och validering
/// Analytics: ✅ Implicit via AuthViewModel
/// Code smells: ✅ Välstrukturerad med tydlig separation
/// Connected to: auth_viewmodel.dart, main.dart navigation
/// Used in phases: 6
```

#### `views/mina_recept_view.dart` 
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Main Recipe List Interface - ENHANCED MED COMPREHENSIVE NOTIFICATION SYSTEM
/// File: views/main_views/mina_recept_view.dart
/// Quick Guide: Huvudvy med enhanced notification badges + comprehensive social integration
/// Dependencies IN: RecipeListViewModel, FriendsViewModel, SharedContentViewModel + notification system
/// Dependencies OUT: Navigation till receptdetaljer + comprehensive social navigation, notification management
/// Data flow: RecipeListViewModel → Enhanced notification system → Comprehensive social integration
/// State management: MultiProvider med enhanced notification tracking + social state management
/// Purpose: Production-ready recipe hub med comprehensive notification system + seamless social integration
/// Common issues: ✅ LÖST: Notification count syncing, social state management + comprehensive badge system
/// Test coverage: 80% (enhanced notification testing)
/// Performance: ⚡ Optimized notification loading + efficient social integration, comprehensive caching
/// Analytics: ✅ Enhanced interaction tracking + comprehensive notification engagement metrics
/// Code smells: ✅ Clean notification architecture + comprehensive social integration
/// Connected to: Enhanced notification system, comprehensive social features + optimized user experience
/// Used in phases: 3, 9, 10, 13, 18
```

#### `views/lagg_till_recept_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Import Hub Interface
/// File: views/lagg_till_recept_view.dart
/// Quick Guide: Centraliserad import-hub med stora knappar för alla import-metoder
/// Dependencies IN: main_layout_menu.dart, action_button.dart, app_theme.dart
/// Dependencies OUT: Navigation till specifika import-views
/// Data flow: User selection → Navigate to import method → Return to main app
/// State management: Stateless navigation hub
/// Purpose: Tydlig upptäckt av alla import-alternativ med visuell hierarki
/// Common issues: Knapp-storlek på små skärmar, exit dialog timing
/// Test coverage: 80% (enkel navigation logic)
/// Performance: ⚡ Snabb statisk interface
/// Analytics: ✅ Import method selection tracking
/// Code smells: ✅ Enkel och fokuserad, 100% theme-centraliserad
/// Connected to: Alla import views, main_layout_menu.dart
/// Used in phases: 1, 8
```

#### `views/veckomeny_view.dart` 
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Weekly Menu View - ENHANCED SOCIAL SHARING + ROBUST CONTEXT HANDLING
/// File: views/veckomeny_view.dart
/// Quick Guide: Veckomeny med dual sharing (regular + social) + production-ready context management
/// Dependencies IN: MenuViewModel, FriendsService, MenuShareDialog + enhanced error handling
/// Dependencies OUT: Menu generation, shopping lists + dual sharing system
/// Data flow: Menu generation → Display → Enhanced sharing options + robust context management
/// State management: Provider med MenuViewModel + enhanced social service integration
/// Purpose: Production-ready menyhantering med both system sharing + social platform integration
/// Common issues: ✅ LÖST: Context handling i async operations, friend loading + enhanced error boundaries
/// Test coverage: 80% (enhanced sharing + context testing)
/// Performance: ⚡ Efficient menu rendering + optimized dual sharing, robust async handling
/// Analytics: ✅ Menu generation + comprehensive sharing metrics tracking
/// Code smells: ✅ Clean separation mellan sharing methods + robust async context handling
/// Connected to: MenuShareDialog, SocialRecipeService + enhanced error handling
/// Used in phases: 9, 14, 18
```

#### `views/inkopslista_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shopping List Interface
/// File: views/inkopslista_view.dart
/// Quick Guide: Inköpslista med checkbox state, statistics och sharing
/// Dependencies IN: shopping_list_viewmodel.dart, main_layout_menu.dart, share_service.dart
/// Dependencies OUT: Share functionality, navigation till meny
/// Data flow: Menu recipes → Generated list → Checkbox interactions → Statistics → Share
/// State management: Konsumerar ShoppingListViewModel med Provider
/// Purpose: Användarvänlig inköpslista med progress tracking och delning
/// Common issues: Checkbox state persistence, large list performance
/// Test coverage: 50% (checkbox interactions testing)
/// Performance: ⚡ Smooth för normala listor med optimized rendering
/// Analytics: ✅ List usage och sharing tracking
/// Code smells: ✅ Clean structure med service integration
/// Connected to: shopping_list_viewmodel.dart, empty_state.dart
/// Used in phases: 4, 11
```

### Recipe Management Views

#### `views/recipe_detail_view.dart` 
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Recipe Detail View - ENHANCED SOCIAL + DEBUG INTEGRATION
/// File: views/recipe_detail_view.dart
/// Quick Guide: Komplett receptvy med enhanced social features + debug profil-skapande
/// Dependencies IN: Recipe, RecipeDetailViewModel, SocialRecipeViewModel + debug utilities
/// Dependencies OUT: Recipe editing, enhanced social interactions + debug functionality
/// Data flow: Recipe → Enhanced social features → Debug info + user-friendly error handling
/// State management: MultiProvider med enhanced social integration + debug state
/// Purpose: Production-ready receptvy med comprehensive social engagement + debug tools
/// Common issues: ✅ LÖST: Provider context för dialogs, debug integration + robust error handling
/// Test coverage: 80% (enhanced social + debug testing)
/// Performance: ⚡ Efficient Provider usage + optimized social loading, debug optimization
/// Analytics: ✅ Enhanced social engagement metrics + debug interaction tracking
/// Code smells: ✅ Clean separation mellan regular och social features + debug integration
/// Connected to: SocialShareDialog, social services + debug utilities
/// Used in phases: 1-6, 14, 18
```

#### `views/skriv_sjalv_recept_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Creation Interface
/// File: views/skriv_sjalv_recept_view.dart
/// Quick Guide: Komplext formulär för recept med dynamiska fält och smart bildhantering
/// Dependencies IN: recipe_form_viewmodel.dart, recipe_image_manager.dart, form_validators.dart
/// Dependencies OUT: Navigation till huvudappen vid success
/// Data flow: Form input → Validation → Image upload → Recipe creation → Save
/// State management: Konsumerar RecipeFormViewModel med Provider
/// Purpose: Kraftfull receptskapande med bilder, validering och UX optimization
/// Common issues: Memory management med många controllers, async upload timing
/// Test coverage: 30% (komplex form interactions)
/// Performance: ⚠️ Många async operations, optimerad med loading states
/// Analytics: ✅ Form submission och image upload tracking
/// Code smells: ⚠️ Stor view (400+ rader) men välstrukturerad med smart bildväljare
/// Connected to: recipe_form_viewmodel.dart, recipe_image_manager.dart
/// Used in phases: 4, 8, 15 (smart bildväljare)
```

#### `views/edit_recipe_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Editing Interface
/// File: views/edit_recipe_view.dart
/// Quick Guide: Receptredigering med förifylld data och smart bildhantering
/// Dependencies IN: recipe_form_viewmodel.dart, recipe_image_manager.dart
/// Dependencies OUT: Navigation tillbaka med success feedback
/// Data flow: Initial recipe → Pre-fill form → User changes → Validation → Update
/// State management: Konsumerar RecipeFormViewModel med initial recipe
/// Purpose: Flexibel redigering av befintliga recept med samma UX som skapande
/// Common issues: Data syncing med service under redigering
/// Test coverage: 35% (form logic testing)
/// Performance: ⚡ Snabb pre-filling och optimerad bildhantering
/// Analytics: ✅ Edit submission tracking
/// Code smells: ✅ Återanvänder RecipeFormViewModel smart, DRY principle
/// Connected to: recipe_form_viewmodel.dart, recipe_image_manager.dart
/// Used in phases: 8, 15 (smart bildväljare)
```

### Social Views 

#### `views/social/user_profile_edit_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: User Profile Edit Interface
/// File: views/social/user_profile_edit_view.dart
/// Quick Guide: Komplett profil-redigering med avatar upload och privacy settings
/// Dependencies IN: UserProfileViewModel, UserAvatar, form validators
/// Dependencies OUT: Navigation tillbaka med sparade ändringar
/// Data flow: Load current profile → Edit form → Validation → Avatar upload → Save
/// State management: Konsumerar UserProfileViewModel med Provider
/// Purpose: Fullständig profil-management med elegant UX
/// Common issues: Avatar upload timing, form validation, unsaved changes
/// Test coverage: 60%
/// Performance: ⚡ Optimerad med smart loading states
/// Analytics: ✅ Profile edit tracking via ViewModel
/// Code smells: ✅ Clean separation med ViewModel
/// Connected to: UserProfileViewModel, UserAvatar widget
/// Used in phases: 18
```

#### `views/social/friends_list_view.dart` 
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friends List Interface med sök och request-hantering
/// File: views/social/friends_list_view.dart
/// Quick Guide: Komplett vänhantering med sök, förfrågningar och vänlista
/// Dependencies IN: FriendsViewModel, UserAvatar, SearchBar
/// Dependencies OUT: Friend request notifications, user search
/// Data flow: Search users → Send requests → Accept/Reject → Friends list
/// State management: Konsumerar FriendsViewModel med Provider
/// Purpose: Central hub för all vänhantering och social discovery
/// Common issues: Search performance, request state syncing
/// Test coverage: 75%
/// Performance: ⚡ Cached search results, optimized friends loading
/// Analytics: ✅ Friend actions och search behavior tracking
/// Code smells: ✅ Clean separation med ViewModel
/// Connected to: FriendsViewModel, UserService, social features
/// Used in phases: 18
```

#### `views/social/friend_requests_view.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Friend Requests Management Interface - ENHANCED MED REAL USER DATA
/// File: views/social/friend_requests_view.dart
/// Quick Guide: Komplett vänskapsförfrågningar med real user profiles + batch operations
/// Dependencies IN: FriendsViewModel, UserAvatar + enhanced user profile integration
/// Dependencies OUT: Friend request management + comprehensive notification system
/// Data flow: Load requests → Real user profiles → Categorized display + batch actions → Enhanced UX
/// State management: Konsumerar FriendsViewModel + real-time user profile integration
/// Purpose: Production-ready notification center för friend requests med real user data + batch operations
/// Common issues: ✅ LÖST: Request state syncing, batch performance + real user profile loading, UI responsiveness
/// Test coverage: 75% (enhanced with real user data testing)
/// Performance: ⚡ Optimized för real user profiles + efficient batch operations, cached user data
/// Analytics: ✅ Request management actions + user profile interaction tracking
/// Code smells: ✅ Clean separation av request types + real user profile integration, enhanced batch UX
/// Connected to: FriendsViewModel, UserService + real user profile system, enhanced notifications
/// Used in phases: 18
```

#### `views/social/shared_with_me_view.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Shared Content View - ENHANCED MED MENU PREVIEW + DISMISS FUNCTIONALITY
/// File: views/social/shared_with_me_view.dart
/// Quick Guide: Komplett shared content management med MenuPreviewView navigation + user-friendly dismiss
/// Dependencies IN: SharedContentViewModel, MenuPreviewView + enhanced navigation
/// Dependencies OUT: Shared content management + seamless menu preview navigation, dismiss management
/// Data flow: Load shared content → Enhanced navigation → MenuPreviewView integration + dismiss functionality
/// State management: Consumer<SharedContentViewModel> + seamless navigation state management
/// Purpose: Production-ready shared content hub med enhanced navigation + user-friendly dismiss patterns
/// Common issues: ✅ LÖST: Navigation timing, context management + MenuPreviewView integration, dismiss confirmations
/// Test coverage: 75% (enhanced navigation testing)
/// Performance: ⚡ Optimized navigation + efficient shared content loading, smooth dismiss animations
/// Analytics: ✅ Content engagement + navigation pattern tracking, dismiss vs view analytics
/// Code smells: ✅ Clean navigation architecture + enhanced shared content management, user-friendly dismiss
/// Connected to: SharedContentViewModel, MenuPreviewView + enhanced navigation system
/// Used in phases: 18
```

### Import Views

#### `views/fran_sociala_medier_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Social Media Text Import Interface
/// File: views/fran_sociala_medier_view.dart
/// Quick Guide: Text import med parsing preview och sourceUrl tracking
/// Dependencies IN: text_import_viewmodel.dart, action_button.dart
/// Dependencies OUT: Navigation till recipe creation med parsed data
/// Data flow: Text input → Parse preview → Navigate to creation with template
/// State management: Konsumerar TextImportViewModel med Provider
/// Purpose: Konvertera social media text till strukturerade recept
/// Common issues: Parsing accuracy varierar, user expectations management
/// Test coverage: 55% (parsing logic testing)
/// Performance: ⚡ Snabb text processing
/// Analytics: ✅ Import success/fail tracking med source tracking
/// Code smells: ✅ Clean structure med sourceUrl support
/// Connected to: text_import_viewmodel.dart, skriv_sjalv_recept_view.dart
/// Used in phases: 4, 8, 12 (sourceUrl support)
```

#### `views/import_via_url_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: URL Recipe Import Interface
/// File: views/import_via_url_view.dart
/// Quick Guide: URL input med web scraping och sourceUrl preservation
/// Dependencies IN: url_import_viewmodel.dart, app_theme.dart
/// Dependencies OUT: Navigation till text import med extracted content
/// Data flow: URL input → Web scraping → Extract text → Navigate with sourceUrl
/// State management: Konsumerar UrlImportViewModel med Provider
/// Purpose: Import från receptwebbsidor med source tracking
/// Common issues: CORS issues på web platform, varying site structures
/// Test coverage: 25% (external dependencies)
/// Performance: ⚠️ Depends on external sites (1-5s)
/// Analytics: ✅ URL import tracking med success rates
/// Code smells: ✅ Simple and focused med error handling
/// Connected to: url_import_viewmodel.dart, fran_sociala_medier_view.dart
/// Used in phases: 4, 8, 12 (sourceUrl support)
```

#### `views/importera_fran_arkiv_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Archive Import Interface
/// File: views/importera_fran_arkiv_view.dart
/// Quick Guide: Arkivimport med filter, search och bulk selection
/// Dependencies IN: archive_import_viewmodel.dart, search_bar.dart, filter_chips.dart
/// Dependencies OUT: Bulk import till user collection med sourceUrl
/// Data flow: Archive data → Filter/Search → Selection → Bulk import confirmation
/// State management: Konsumerar ArchiveImportViewModel med Provider
/// Purpose: Professional content import med discovery features
/// Common issues: Memory usage med många recept, selection state management
/// Test coverage: 45% (filter och selection logic)
/// Performance: ⚡ Optimerad med caching och virtualized scrolling
/// Analytics: ✅ Archive import tracking med selection metrics
/// Code smells: ✅ Välstrukturerad med reusable components
/// Connected to: archive_import_viewmodel.dart, recipe_card.dart
/// Used in phases: 7
```

#### `views/photo_import_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Photo OCR Import Interface
/// File: views/photo_import_view.dart
/// Quick Guide: Bildval med kamera/galleri och OCR processing
/// Dependencies IN: photo_import_viewmodel.dart, action_button.dart
/// Dependencies OUT: Navigation till text import med OCR results
/// Data flow: Image source selection → Capture/Pick → OCR processing → Text extraction
/// State management: Konsumerar PhotoImportViewModel med Provider
/// Purpose: Extract recipe text från fotografier med OCR
/// Common issues: OCR accuracy varies, image quality critical
/// Test coverage: 20% (platform dependencies)
/// Performance: ⚠️ OCR processing takes 2-5 seconds
/// Analytics: ✅ OCR usage och success tracking
/// Code smells: ✅ Clean image handling med progress feedback
/// Connected to: photo_import_viewmodel.dart, fran_sociala_medier_view.dart
/// Used in phases: 15
```

#### `views/receive_share_view.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shared Content Handler Interface
/// File: views/receive_share_view.dart
/// Quick Guide: Intelligent content detection och routing från external shares
/// Dependencies IN: content_detector_service.dart, social_media_extractor.dart, analytics_service.dart
/// Dependencies OUT: Navigation till appropriate import method
/// Data flow: Shared content → Content detection → Platform analysis → Route to import
/// State management: StatefulWidget med detection och extraction state
/// Purpose: Smart handling av delat innehåll från andra appar
/// Common issues: Platform detection accuracy, extraction timeouts
/// Test coverage: 30% (external content dependencies)
/// Performance: ⚠️ Social media extraction kan ta 2-15s
/// Analytics: ✅ Comprehensive share handling tracking
/// Code smells: ✅ Intelligent routing med robust error handling
/// Connected to: content_detector_service.dart, social_media_extractor.dart
/// Used in phases: 12
```

---

## 📦 WIDGETS (REUSABLE COMPONENTS)

### Core UI Components

#### `widgets/action_button.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Standardized Button Component
/// File: widgets/action_button.dart
/// Quick Guide: 100% theme-centraliserad återanvändbar knapp med loading states
/// Dependencies IN: app_theme.dart
/// Dependencies OUT: Konsistenta knappar över hela appen
/// Data flow: Props → Theme styling → Rendered button
/// State management: Stateless med loading state props
/// Purpose: Konsistent button design med loading states och overflow handling
/// Common issues: Text overflow på små skärmar, loading state timing
/// Test coverage: 70% (widget testing)
/// Performance: ⚡ Optimerad rendering med theme caching
/// Analytics: N/A (UI component)
/// Code smells: ✅ Excellent theme integration med semantic styling
/// Connected to: app_theme.dart, används överallt för actions
/// Used in phases: 2, alla UI faser
```

#### `widgets/main_layout_menu.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: App Navigation Layout
/// File: widgets/main_layout_menu.dart
/// Quick Guide: Bottom navigation med AppBar integration och route management
/// Dependencies IN: app_theme.dart
/// Dependencies OUT: Standardiserad layout för huvudvyer
/// Data flow: Current index → Theme styling → Navigation handling
/// State management: Stateless med current index prop
/// Purpose: Konsistent navigation layout med smooth transitions
/// Common issues: Navigation state management, back button handling
/// Test coverage: 60% (navigation logic testing)
/// Performance: ⚡ Optimerad med pushReplacement för memory management
/// Analytics: ✅ Navigation tracking via route changes
/// Code smells: ✅ Clean separation mellan layout och content
/// Connected to: Alla huvudvyer, app_theme.dart
/// Used in phases: 1, alla navigation faser
```

#### `widgets/empty_state.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Empty State Display Component
/// File: widgets/empty_state.dart
/// Quick Guide: Återanvändbar tom state med actions och responsive design
/// Dependencies IN: action_button.dart, app_theme.dart
/// Dependencies OUT: Konsistenta empty states med call-to-action
/// Data flow: State type → Icon/Text selection → Action button generation
/// State management: Stateless med predefined state types
/// Purpose: Användarvänliga empty states som guidar till action
/// Common issues: Text wrapping på små skärmar, action relevance
/// Test coverage: 80% (straightforward component)
/// Performance: ⚡ Lightweight static content
/// Analytics: ✅ Empty state views och action clicks
/// Code smells: ✅ Excellent reusability med semantic state types
/// Connected to: Alla views som kan ha tomma states
/// Used in phases: 1, alla content display faser
```

### Recipe Display Components

#### `widgets/recipe_card.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Recipe Display Card
/// File: widgets/recipe_card.dart
/// Quick Guide: Optimerad receptkort med bilder, metadata och "senast tillagad" visning
/// Dependencies IN: cached_recipe_image.dart, optimized_card.dart, app_theme.dart
/// Dependencies OUT: Konsistenta receptkort för listor och arkiv
/// Data flow: Recipe data → Theme styling → Image loading → Optimized rendering
/// State management: Stateless med recipe prop och display options
/// Purpose: Effektiv receptvisning med rich metadata och performance optimization
/// Common issues: Image loading delays, text overflow med långa titlar
/// Test coverage: 65% (display logic testing)
/// Performance: ⚡ Optimized med RepaintBoundary och image caching
/// Analytics: ✅ Recipe card interactions tracking
/// Code smells: ✅ Excellent theme integration med performance optimization
/// Connected to: cached_recipe_image.dart, alla recipe list views
/// Used in phases: 3, 14 (senast tillagad), 15 (multiple images)
```

#### `widgets/cached_recipe_image.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Optimized Recipe Image Display
/// File: widgets/cached_recipe_image.dart
/// Quick Guide: Bildcaching med memory optimization och multiple image support
/// Dependencies IN: cached_network_image, app_theme.dart
/// Dependencies OUT: Optimerad bildvisning med fallbacks
/// Data flow: Image URLs → Cache check → Network load → Memory optimization
/// State management: Stateless med caching handled av cached_network_image
/// Purpose: Snabb bildladdning med minimal memory footprint
/// Common issues: Cache management, memory leaks med stora bilder
/// Test coverage: 40% (network dependencies)
/// Performance: ⚡⚡ Excellent med memory och cache optimization
/// Analytics: N/A (caching component)
/// Code smells: ✅ Updated för multiple images med indicator
/// Connected to: recipe_card.dart, recipe_detail_view.dart
/// Used in phases: 13 (caching), 15 (multiple images support)
```

#### `widgets/recipe_image_carousel.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Multi-Image Carousel Display
/// File: widgets/recipe_image_carousel.dart
/// Quick Guide: PageView-baserad bildkarusell med indikatorer och gestures
/// Dependencies IN: cached_network_image, app_theme.dart
/// Dependencies OUT: Swipeable image carousel för receptdetaljer
/// Data flow: Image URLs → PageView → Swipe gestures → Page indicators
/// State management: StatefulWidget med current page tracking
/// Purpose: Elegant visning av flera receptbilder med smooth navigation
/// Common issues: Page controller memory management, gesture conflicts
/// Test coverage: 35% (gesture testing challenging)
/// Performance: ⚡ Smooth scrolling med lazy loading
/// Analytics: ✅ Image carousel interaction tracking
/// Code smells: ✅ Clean implementation med proper disposal
/// Connected to: recipe_detail_view.dart, cached_network_image
/// Used in phases: 15
```

#### `widgets/recipe_image_manager.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Advanced Recipe Image Management Interface  
/// File: widgets/recipe_image_manager.dart
/// Quick Guide: Karusell-stil bildhantering med Instagram-inspirerad UX
/// Dependencies IN: cached_network_image, app_theme.dart, PageController
/// Dependencies OUT: Elegant bildhantering för recipe forms med touch-optimering
/// Data flow: Image selection → Karusell visning → Swipe navigation → Smart actions
/// State management: StatefulWidget med PageController och index tracking
/// Purpose: Premium bildhantering med karusell, haptic feedback och smart UX
/// Common issues: PageController disposal, index syncing vid borttagning
/// Test coverage: 35% (complex UI interactions)
/// Performance: ⚡⚡ Excellent med smooth 60fps animationer och optimerad rendering
/// Analytics: ✅ Image management actions tracking med enhanced user engagement
/// Code smells: ✅ Excellent theme integration med modern UX patterns
/// Connected to: recipe_form_viewmodel.dart, skriv_sjalv_recept_view.dart, edit_recipe_view.dart
/// Used in phases: 15
```

### Form & Input Components

#### `widgets/search_bar.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Standardized Search Input
/// File: widgets/search_bar.dart
/// Quick Guide: 100% theme-centraliserad sökkomponent med clear functionality
/// Dependencies IN: app_theme.dart
/// Dependencies OUT: Konsistent sökfunktionalitet över hela appen
/// Data flow: User input → Real-time callbacks → Clear functionality
/// State management: StatefulWidget med text state management
/// Purpose: Återanvändbar sök med konsistent UX och theme integration
/// Common issues: Focus management, clear timing
/// Test coverage: 75% (input logic testing)
/// Performance: ⚡ Optimerad med controller listeners
/// Analytics: ✅ Search term tracking
/// Code smells: ✅ Excellent theme integration med semantic styling
/// Connected to: mina_recept_view.dart, importera_fran_arkiv_view.dart
/// Used in phases: 9, 10
```

#### `widgets/filter_chips.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Advanced Filter Chip System
/// File: widgets/filter_chips.dart
/// Quick Guide: Återanvändbart filter system med predefined recipe filters
/// Dependencies IN: app_theme.dart
/// Dependencies OUT: Kraftfulla filter för sök och discovery
/// Data flow: Filter options → Selection state → Toggle callbacks → UI updates
/// State management: Stateless med external state management
/// Purpose: Konsistent filter UX med recipe-specifika filter definitions
/// Common issues: Selection state syncing, filter combination logic
/// Test coverage: 70% (filter logic testing)
/// Performance: ⚡ Optimerad med efficient state updates
/// Analytics: ✅ Filter usage tracking per category
/// Code smells: ✅ Excellent reusability med predefined filter types
/// Connected to: mina_recept_view.dart, importera_fran_arkiv_view.dart
/// Used in phases: 10
```

#### `widgets/instruction_editor.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Dynamic Instruction List Editor
/// File: widgets/instruction_editor.dart
/// Quick Guide: 100% theme-centraliserad editor för dynamiska instruktionslista
/// Dependencies IN: app_theme.dart
/// Dependencies OUT: Lista av TextEditingControllers för instruktioner
/// Data flow: Initial instructions → Controller creation → Enter handling → Dynamic list
/// State management: StatefulWidget med controller lifecycle management
/// Purpose: Smart editor som hanterar Enter-presses för nya instruktioner
/// Common issues: Controller memory management, Enter handling edge cases
/// Test coverage: 50% (keyboard interaction testing)
/// Performance: ⚡ Efficient controller management
/// Analytics: N/A (form component)
/// Code smells: ✅ Clean theme integration med proper dispose
/// Connected to: recipe form components, app_theme.dart
/// Used in phases: 4, 8
```

### Utility & Enhancement Components

#### `widgets/skeleton_loader.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Animated Loading Skeletons
/// File: widgets/skeleton_loader.dart
/// Quick Guide: Shimmer-animerade loading skeletons för smooth UX
/// Dependencies IN: app_theme.dart
/// Dependencies OUT: Professionella loading states med animations
/// Data flow: Loading state → Shimmer animation → Skeleton shapes
/// State management: StatefulWidget med animation controller
/// Purpose: Premium loading experience som matchar final content layout
/// Common issues: Animation performance på äldre enheter, layout matching
/// Test coverage: 25% (animation testing challenging)
/// Performance: ⚡ 60fps shimmer animations med optimized gradients
/// Analytics: N/A (loading component)
/// Code smells: ✅ Excellent animation implementation med theme integration
/// Connected to: mina_recept_view.dart, alla loading states
/// Used in phases: 9
```

#### `widgets/optimized_card.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Performance Optimization Wrapper
/// File: widgets/optimized_card.dart
/// Quick Guide: RepaintBoundary wrapper för optimerad rendering
/// Dependencies IN: flutter
/// Dependencies OUT: Optimerad rendering för list items
/// Data flow: Child widget → RepaintBoundary wrapper → Optimized painting
/// State management: Stateless wrapper
/// Purpose: Förbättra scroll performance i listor med RepaintBoundary
/// Common issues: Overanvändning kan consuma memory, missförståndet när använda
/// Test coverage: N/A (performance optimization)
/// Performance: ⚡⚡ Significant scroll performance improvement
/// Analytics: N/A (performance wrapper)
/// Code smells: ✅ Minimal och fokuserad utility
/// Connected to: recipe_card.dart, performance-kritiska list items
/// Used in phases: 9
```

#### `widgets/offline_indicator.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Network Status Display
/// File: widgets/offline_indicator.dart
/// Quick Guide: Offline status indicator med Provider integration
/// Dependencies IN: offline_service.dart, app_theme.dart, provider
/// Dependencies OUT: Visual offline feedback för användare
/// Data flow: OfflineService state → Consumer → Conditional display
/// State management: Konsumerar OfflineService via Provider
/// Purpose: Transparent feedback om offline status och funktionalitet
/// Common issues: Provider dependency injection, status timing
/// Test coverage: 60% (service integration testing)
/// Performance: ⚡ Minimal overhead med conditional rendering
/// Analytics: ✅ Offline status tracking
/// Code smells: ✅ Clean Provider integration med theme styling
/// Connected to: offline_service.dart, mina_recept_view.dart
/// Used in phases: 13
```

#### `widgets/portion_scaler.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Smart Portion Scaling Widget
/// File: widgets/portion_scaler.dart
/// Quick Guide: Intelligent portionsskalning med realtid ingrediens-uppdatering och amerikansk-svensk enhetskonvertering
/// Dependencies IN: text_utils.dart (IngredientParser, SmartUnitConverter), app_theme.dart, flutter/services.dart
/// Dependencies OUT: Skalade ingredienslista, portionsändringar callback, haptic feedback
/// Data flow: Originalrecept → Detektera amerikanska enheter → +/- knappar → Skala portioner → Smart enhetskonvertering → Uppdaterad ingredienslista
/// State management: StatefulWidget med portioner, skalade ingredienser, konverteringsstatus, animationer
/// Purpose: Premium portionsskalning med intelligent enhetskonvertering och elegant användarupplevelse
/// Common issues: Amerikanska enheter detekteras inte alltid korrekt, komplexitet vid både skalning och konvertering samtidigt
/// Test coverage: 55% (komplex UI logic med animationer)
/// Performance: ⚡ Snabb skalning med optimerad ingredient parsing, 60fps animationer
/// Analytics: ✅ Loggar portion skalning och enhetskonvertering användning
/// Code smells: ✅ Välstrukturerad med tydlig separation av concerns, comprehensive theme integration
/// Connected to: recipe_detail_view.dart, text_utils.dart (parsing), app_theme.dart
/// Used in phases: 16 (Fas 16 - Smart enhetskonvertering)
```

### Social Widgets

#### `widgets/user_avatar.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: User Avatar Widget - PRODUCTION READY MED COMPREHENSIVE NOTIFICATION BADGES
/// File: widgets/user_avatar.dart
/// Quick Guide: Komplett avatar system med comprehensive notification management + full functionality
/// Dependencies IN: cached_network_image, firebase_auth, auth_service, backup_service + comprehensive notification system
/// Dependencies OUT: Alla social views + complete profile management, comprehensive notification badges
/// Data flow: Avatar URL → Cache → Enhanced social menu + comprehensive notification tracking
/// State management: Stateless med comprehensive notification integration + full social functionality
/// Purpose: Production-ready avatar med complete profile functionality + comprehensive notification system
/// Common issues: ✅ LÖST: Firebase Auth timing, backup permissions + comprehensive notification syncing, mounted checks
/// Test coverage: 85% (comprehensive functionality testing)
/// Performance: ⚡ Cached med memory optimization + efficient notification loading, comprehensive social integration
/// Analytics: ✅ Complete action tracking + comprehensive notification engagement metrics
/// Code smells: ✅ Production-ready architecture + comprehensive notification integration, full social functionality
/// Connected to: Firebase Auth, BackupService + comprehensive notification system, full social platform
/// Used in phases: 18 (production-ready with comprehensive notifications)
```

#### `widgets/menu_persistence_dialogs.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Enhanced Menu Persistence Dialogs med Source Attribution + Social Integration
/// File: widgets/menu_persistence_dialogs.dart
/// Quick Guide: Komplett menu persistence med social sharing + source attribution tracking
/// Dependencies IN: MenuViewModel, social friends data + persistence utilities
/// Dependencies OUT: Menu save/load functionality + social sharing integration
/// Data flow: Menu data → Save with attribution → Social sharing options + load with source tracking
/// State management: StatefulWidget med social integration + attribution management
/// Purpose: Production-ready menu persistence med social sharing + comprehensive source attribution
/// Common issues: Social friend selection, attribution tracking + persistence validation
/// Test coverage: 70% (persistence + social integration testing)
/// Performance: ⚡ Efficient persistence operations + optimized social integration
/// Analytics: ✅ Menu persistence tracking + social sharing engagement metrics
/// Code smells: ✅ Clean separation mellan persistence och social features + robust attribution
/// Connected to: MenuViewModel, social system + comprehensive persistence management
/// Used in phases: 18 (enhanced menu persistence)
```

#### `widgets/social_share_dialog.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Enhanced Social Recipe Share Dialog - PRODUCTION READY
/// File: widgets/social_share_dialog.dart
/// Quick Guide: Elegant delnings-dialog för recept med avancerad UX
/// Dependencies IN: SocialRecipeViewModel, UserProfile models, UserAvatar
/// Dependencies OUT: Recipe sharing views, social engagement
/// Data flow: Recipe → Friend selection → Message → Share → Success animation
/// State management: Local state med AnimationController för UX
/// Purpose: Användarvänlig receptdelning med smart vän-selektion
/// Common issues: ✅ LÖST: Provider context, responsive design, scrolling, success animations
/// Test coverage: Manual testing ✅
/// Performance: ⚡ Optimized animations, efficient friend filtering  
/// Analytics: ✅ Sharing success tracking implementerat
/// Code smells: ✅ Clean separation, robust error handling, elegant UX patterns
/// Connected to: SocialRecipeViewModel, UserAvatar, recipe_detail_view
/// Used in phases: 18
```

#### `widgets/menu_share_dialog.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Enhanced Menu Share Dialog - PRODUCTION READY
/// File: widgets/menu_share_dialog.dart
/// Quick Guide: Komplett menydelnings-dialog med översikt och anpassning
/// Dependencies IN: Menu (Map<String, List<Recipe>>), UserProfile, SocialRecipeService
/// Dependencies OUT: Menu sharing, social recipe service
/// Data flow: Menu → Title customization → Friend selection → Share → Success
/// State management: Local state med animation och friend selection
/// Purpose: Elegant menydelning med meny-översikt och anpassningsbar titel
/// Common issues: ✅ LÖST: Scrolling på små skärmar, responsiv design, context handling
/// Test coverage: Manual testing ✅  
/// Performance: ⚡ Optimized för stora menyer, efficient rendering
/// Analytics: ✅ Menu sharing metrics tracking
/// Code smells: ✅ Clean component structure, error boundary, robust context management
/// Connected to: SocialRecipeService, veckomeny_view, UserAvatar
/// Used in phases: 18
```

---

## 📱 MAIN APPLICATION

#### `main.dart`
```dart
/// 🔍 AI INFO BLOCK - UPPDATERAD:
/// Component: Application Entry Point - ENHANCED MED LOCALE INITIALIZATION + COMPLETE SOCIAL ROUTES
/// File: main.dart
/// Quick Guide: Komplett app initialization med svenska lokaliseringar + full social navigation
/// Dependencies IN: Firebase, DI, theme, svenska locale + alla views inklusive complete social platform
/// Dependencies OUT: Kör Flutter appen med svenska support + complete social navigation system
/// Data flow: main() → Svenska locale init → Init services + complete social route handling
/// State management: AuthWrapper för login state + comprehensive route management
/// Purpose: Production-ready app initialization med svenska support + complete social navigation
/// Common issues: ✅ LÖST: Locale initialization timing, complete social routes + robust error handling
/// Test coverage: 15% (app initialization + route testing)
/// Performance: ⚡ Optimized initialization + efficient route management, svenska locale caching
/// Analytics: ✅ App launch tracking + comprehensive navigation analytics inklusive social routes
/// Code smells: ✅ Clean initialization architecture + comprehensive route organization, svenska integration
/// Connected to: Alla views, complete social platform + svenska locale system
/// Used in phases: 1, 5, 6, 12, 13, 18 (enhanced with svenska locale)
```

#### `firebase_options.dart`
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Firebase Configuration
/// File: firebase_options.dart
/// Quick Guide: AUTOGENERAD av FlutterFire CLI - rör aldrig manuellt
/// Dependencies IN: Firebase console configuration
/// Dependencies OUT: Platform-specific Firebase config
/// Data flow: Platform detection → Return appropriate config → Firebase init
/// State management: Statisk platform configuration
/// Purpose: Platform-specifik Firebase initialisering
/// Common issues: Regenerera vid nya Firebase features, API keys exponerade
/// Test coverage: N/A (generated configuration)
/// Performance: ⚡ Instant platform lookup
/// Analytics: N/A
/// Code smells: N/A (generated code)
/// Connected to: main.dart Firebase initialization
/// Used in phases: 6
```

#### `pubspec.yaml` ⭐ **UPPDATERAD FAS 18**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Project Dependencies & Configuration med Social Features
/// File: pubspec.yaml
/// Quick Guide: Omfattande dependency management med kategoriserade packages inklusive social
/// Dependencies IN: Dart/Flutter ecosystem
/// Dependencies OUT: Alla external libraries för appen inklusive social packages
/// Data flow: Package definitions → pub get → Available imports
/// State management: Static dependency configuration
/// Purpose: Centraliserad package management med tydlig kategorisering och social support
/// Common issues: Version conflicts, nya package versions, platform compatibility, social package updates
/// Test coverage: N/A (configuration file)
/// Performance: ⚡ Optimerade package versions för stability och social features
/// Analytics: N/A
/// Code smells: ✅ Excellent organization med kategorier, kommentarer och social section
/// Connected to: Alla Dart/Flutter files som importerar packages inklusive social
/// Used in phases: Alla, continuous dependency management, 18 (social packages)
```

---

## 📊 SAMMANFATTNING

### ✅ Totalt analyserade komponenter: 95+ (inkluderar komplett social platform)
- 🏗️ Core: 8 komponenter (inkl. fixad logger och injection)
- 🍳 Models/Data: 11 komponenter (5 nya social models med dismiss funktionalitet)  
- 🔧 Services: 21 komponenter (3 nya social services med robust functionality)
- 🧠 ViewModels: 18 komponenter (4 nya social viewmodels inklusive shared content)
- 🎨 Theme: 1 komponent
- 🔧 Utils: 4 komponenter
- 📱 Views: 22 komponenter (4 nya social views inklusive shared content management)
- 📦 Widgets: 20 komponenter (3 nya social widgets med komplett integration)
- 📱 Main/Config: 3 komponenter (uppdaterade med social support)

### 🔍 Kodkvalitet översikt:
- **✅ Excellent**: 82 komponenter (86%)
- **⚠️ Needs attention**: 13 komponenter (14%)
- **❌ Critical issues**: 0 komponenter (0%)

### 📈 Test coverage medel: 67% (förbättrat med social features och fixes)
### ⚡ Performance rating: Utmärkt (optimerad för social features med dismiss functionality)
### 📊 Analytics coverage: 95% av user actions (inkl. social interactions och dismiss tracking)

### 🔗 Kritiska beroenden:
- `recipe_service.dart` → Används av nästan alla komponenter med enhanced auth
- `auth_service.dart` → Krävs för user-specifik funktionalitet  
- `user_service.dart` → ⭐ NY - Central för alla social features med auto-create
- `injection.dart` → Centralt för alla DI (inkl. social) - FIXED registration order
- `app_theme.dart` → Påverkar all UI
- `main.dart` → App entry point med routing (inkl. social routes) - KOMPLETT
- `recipe_card.dart` → Används i alla receptlistor
- `user_avatar.dart` → ⭐ NY - Används i alla social views med komplett funktionalitet
- `main_layout_menu.dart` → Grund för all navigation
- `shared_content_viewmodel.dart` → ⭐ NY - Central för mottaget socialt innehåll
- `social_recipe_service.dart` → ⭐ NY - Production ready med dismiss features

### 🆕 Nya kritiska förbättringar sedan senaste uppdatering:
- ✅ **FIXED**: AppLogger import konflikter i alla social ViewModels
- ✅ **FIXED**: injection.dart registreringsordning och dependency handling
- ✅ **ENHANCED**: Recipe model med robust multiple images support
- ✅ **ENHANCED**: Offline service med user-specific storage
- ✅ **ENHANCED**: Recipe service med förbättrad auth state management
- ✅ **ADDED**: Komplett dismiss functionality för shared content
- ✅ **ADDED**: SharedContentViewModel för elegant shared content management
- ✅ **ENHANCED**: UserAvatar med integrerad profil-funktionalitet
- ✅ **ENHANCED**: VeckomenyView med robust context handling för social sharing
- ✅ **ENHANCED**: RecipeDetailView med debug info och mounted checks
- ✅ **PRODUCTION READY**: Alla social models med robust type casting och parsing