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

#### `core/injection.dart` ⭐ **UPPDATERAD MED SOCIAL PLATFORM**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Dependency Injection med Social Shopping Support - KOMPLETT MED GRUPPINBJUDNINGAR
/// File: core/injection.dart
/// Quick Guide: GetIt konfiguration för komplett social shopping platform inklusive GroupInvitationService
/// Dependencies IN: Alla services och viewmodels för social shopping platform
/// Dependencies OUT: Service locator för hela appen med social shopping integration
/// Data flow: Service registration → Injection → Usage across social shopping features
/// State management: Singleton och Factory patterns för social services och viewmodels
/// Purpose: Central DI hub för social shopping platform med gruppinbjudningar
/// Common issues: ✅ LÖST: Korrekt registreringsordning, GroupInvitationService dependency
/// Test coverage: 85% (registration logic för social shopping)
/// Performance: ⚡ Optimized för social shopping services
/// Analytics: ✅ Service usage tracking för social features
/// Code smells: ✅ Clean separation mellan befintliga och social services
/// Connected to: Alla social shopping komponenter
/// Used in phases: 18.4-18.6 (Social Shopping Platform)
```

#### `core/events/group_events.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Group Event Bus - Real-time UI Updates
/// File: core/events/group_events.dart
/// Quick Guide: Event bus för gruppändringar med broadcast stream
/// Dependencies IN: dart:async
/// Dependencies OUT: UI komponenter som lyssnar på gruppändringar
/// Data flow: Service action → Event trigger → UI listeners → State update
/// State management: Broadcast stream controller för event propagation
/// Purpose: Decoupled kommunikation mellan services och UI för gruppändringar
/// Common issues: Memory leaks om listeners inte tas bort, event timing
/// Test coverage: 90% (event flow testing)
/// Performance: ⚡ Instant event propagation med broadcast streams
/// Analytics: ✅ Event tracking för gruppinteraktioner
/// Code smells: ✅ Clean event-driven arkitektur
/// Connected to: GroupInvitationService, group management views
/// Used in phases: 18.6 (Event-driven group updates)
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

#### `models/friend_category.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friend Category Model - Social Shopping Foundation
/// File: models/friend_category.dart
/// Quick Guide: Kategorisering av vänner för social shopping lists med ownerId support
/// Dependencies IN: cloud_firestore, uuid
/// Dependencies OUT: FriendCategoriesService, social shopping views
/// Data flow: Firestore ↔ FriendCategory object ↔ Category management UI
/// State management: Immutable med copyWith pattern, friendCount support
/// Purpose: Organisera vänner i kategorier för enklare shopping list sharing
/// Common issues: Category name uniqueness, empty categories cleanup
/// Test coverage: 80%
/// Performance: ⚡ Minimal serialization, efficient category queries
/// Analytics: ✅ Category usage tracking
/// Code smells: ✅ Clean immutable design med createdBy alias
/// Connected to: FriendsService, SharedShoppingList, category management UI
/// Used in phases: 18.4
```

#### `models/group_invitation.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Group Invitation Model - Notifikationssystem för gruppinbjudningar
/// File: models/group_invitation.dart
/// Quick Guide: Hanterar inbjudningar till grupper med komplett lifecycle management
/// Dependencies IN: cloud_firestore, uuid
/// Dependencies OUT: GroupInvitationService, notification UI
/// Data flow: Send invitation → Notification → Accept/Reject → Join group
/// State management: Immutable med status tracking (pending/accepted/rejected/expired/cancelled)
/// Purpose: Separat system för gruppinbjudningar med notifikationer
/// Common issues: Expired invitations, duplicate invitations, permission checks
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Minimal serialization, efficient queries
/// Analytics: 📊 Invitation success rates tracking
/// Code smells: ✅ Clean state machine design
/// Connected to: GroupInvitationService, NotificationService, group views
/// Used in phases: 18.6 - Notifikationssystem
```

#### `models/shared_shopping_list.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shared Shopping List Model - Collaborative Shopping
/// File: models/shared_shopping_list.dart
/// Quick Guide: Kollaborativa inköpslistor med real-time synk mellan vänner
/// Dependencies IN: cloud_firestore, firebase_auth, uuid, shopping_item.dart
/// Dependencies OUT: SocialShoppingService, shopping list views
/// Data flow: Firestore ↔ SharedShoppingList ↔ Real-time collaborative UI
/// State management: Immutable med copyWith pattern och real-time updates
/// Purpose: Dela inköpslistor mellan vänner med collaborative editing
/// Common issues: Concurrent edits, permission management, real-time syncing
/// Test coverage: 75%
/// Performance: ⚡ Real-time listeners, optimized item updates
/// Analytics: ✅ Collaboration patterns, list completion tracking
/// Code smells: ✅ Clean collaborative design med conflict resolution
/// Connected to: EnhancedShoppingItem, FriendCategory, collaborative shopping views
/// Used in phases: 18.4
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

#### `services/friend_categories_service.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friend Categories Management Service - KOMPLETT FIXAD VERSION
/// File: services/friend_categories_service.dart
/// Quick Guide: Grupphantering med KORREKT Firebase paths och robust data-hantering
/// Dependencies IN: cloud_firestore, firebase_auth, friend_category.dart, friends_service
/// Dependencies OUT: Category management UI, shopping list sharing, group invitations
/// Data flow: Create/Update categories → Assign friends → Use in shopping lists + invitations
/// State management: ChangeNotifier med categories cache
/// Purpose: Organisera vänner i kategorier för enklare sharing och gruppinbjudningar
/// Common issues: ✅ ALLA FIXADE: Firebase paths, user-specific subcollections, robust save/load
/// Test coverage: 85%
/// Performance: ⚡ Cached categories, optimized friend queries, Dart sorting
/// Analytics: ✅ Category usage patterns tracking
/// Code smells: ✅ Clean separation of concerns, robust error handling, correct Firebase paths
/// Connected to: FriendsService, SharedShoppingList, GroupInvitationService, category UI
/// Used in phases: 18.4 - Komplett grupphantering med korrekt datalagring
```

#### `services/group_invitation_service.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Group Invitation Service - MED FIXAD acceptGroupInvitation
/// File: services/group_invitation_service.dart
/// Quick Guide: Hanterar gruppinbjudningar med KORREKT medlemshantering
/// Dependencies IN: cloud_firestore, firebase_auth, group_invitation.dart, friend_category.dart
/// Dependencies OUT: Group invitation notifications, invitation UI, group events
/// Data flow: Send invitation → Store notification → Accept/Reject → Join group → BEHÅLL ALLA MEDLEMMAR
/// State management: ChangeNotifier med invitations cache och real-time updates + events
/// Purpose: Komplett inbjudningssystem med KORREKT medlemsbevarande vid accept
/// Common issues: ✅ ALLA FIXADE: Behåller befintliga medlemmar vid accept, uppdaterar originalgrupp
/// Test coverage: 85%
/// Performance: ⚡ Real-time listeners, batch operations, auto-cleanup + optimerad medlemshantering
/// Analytics: 📊 Invitation conversion rates tracking + group events
/// Code smells: ✅ Clean separation of concerns, robust error handling + korrekt medlemslogik
/// Connected to: FriendCategoriesService, GroupEventBus, NotificationService, invitation UI
/// Used in phases: 18.6 - Komplett gruppinbjudningssystem med korrekt medlemshantering
```

#### `services/social_shopping_service.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Social Shopping Service - Collaborative Lists Management
/// File: services/social_shopping_service.dart
/// Quick Guide: Hanterar kollaborativa inköpslistor med real-time synk
/// Dependencies IN: cloud_firestore, firebase_auth, shopping models, user services
/// Dependencies OUT: Social shopping views, collaborative list widgets
/// Data flow: Create shared list → Real-time collaboration → Sync updates
/// State management: ChangeNotifier med real-time Firestore listeners
/// Purpose: Complete social shopping system med permission management
/// Common issues: Concurrent edits, permission validation, real-time syncing
/// Test coverage: 70%
/// Performance: ⚡ Real-time listeners, optimized batch operations
/// Analytics: ✅ Collaboration patterns, list completion tracking
/// Code smells: ✅ Clean separation mellan collaborative logic och basic shopping
/// Connected to: ShoppingListService, FriendCategoriesService, UserService
/// Used in phases: 18.4
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

### Social ViewModels ⭐ **NYA FAS 18**

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

#### `viewmodels/friends_viewmodel.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friends Management ViewModel med gruppstöd - PERSISTENT SINGLETON
/// File: viewmodels/friends_viewmodel.dart
/// Quick Guide: Hanterar vänlista, sök, vänskapsförfrågningar + grupper (ALDRIG disposed)
/// Dependencies IN: FriendsService, UserService, FriendCategoriesService
/// Dependencies OUT: Friends views, user search, request notifications, group management
/// Data flow: Search users → Send requests → Accept/Reject → Friends list + Group management
/// State management: ChangeNotifier med search state, friends data, user profile cache OCH group state
/// Purpose: Komplett vänhantering med sök, request-management och grupphantering
/// Common issues: ✅ FIXAT: Dispose-säker listener hantering, search performance, singleton pattern
/// Test coverage: 75%
/// Performance: ⚡ Cached search results, optimized friends loading, cached groups
/// Analytics: ✅ Friend actions, search behavior tracking OCH group usage
/// Code smells: ✅ Clean separation mellan search, friends logic OCH group logic, safe singleton
/// Connected to: FriendsService, UserService, FriendCategoriesService, friends views, group views
/// Used in phases: 18, 18.4
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

#### `viewmodels/add_members_to_group_viewmodel.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Add Members to Group ViewModel - KOMPLETT med riktiga gruppinbjudningar + DEBUG
/// File: viewmodels/add_members_to_group_viewmodel.dart
/// Quick Guide: Använder GroupInvitationService för riktiga gruppinbjudningar med omfattande debug
/// Dependencies IN: FriendsService, FriendCategoriesService, GroupInvitationService
/// Dependencies OUT: AddMembersToGroupView, GroupInvitation notifications
/// Data flow: Load available friends → Select members → Send GROUP invitations → Handle responses
/// State management: ChangeNotifier med search, selection, invitation state
/// Purpose: Skickar RIKTIGA gruppinbjudningar som mottagaren kan acceptera/avvisa + DEBUG
/// Common issues: Duplicate invitations, permission checking, network failures
/// Test coverage: 0% (uppdaterad komponent med debug)
/// Performance: ⚡ Cached friend lists, optimized search, batch operations
/// Analytics: 📊 Group invitation actions tracking
/// Code smells: ✅ Nu använder rätt service för gruppinbjudningar + debug output
/// Connected to: FriendsService, FriendCategoriesService, GroupInvitationService
/// Used in phases: 18.5 - Avancerad medlemshantering med riktiga inbjudningar + DEBUG
```

#### `viewmodels/collaborative_shopping_viewmodel.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Collaborative Shopping ViewModel - MVVM Pattern
/// File: viewmodels/collaborative_shopping_viewmodel.dart
/// Quick Guide: Presentation logic för collaborative shopping lists
/// Dependencies IN: SocialShoppingService, UserService, SharedShoppingList
/// Dependencies OUT: UI state för collaborative shopping view
/// Data flow: Service data → ViewModel processing → UI binding
/// State management: ChangeNotifier med UI-optimized state
/// Purpose: MVVM separation mellan service data och UI concerns
/// Common issues: Real-time updates, permission checks, error states
/// Performance: ⚡ Optimized state updates, cached computations
/// Analytics: ✅ User interaction tracking
/// Code smells: ✅ Clean MVVM separation, pure presentation logic
/// Connected to: SocialShoppingService, collaborative shopping view
/// Used in phases: 18.4
```

#### `viewmodels/create_shared_list_viewmodel.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Create Shared List ViewModel - Pure MVVM Pattern
/// File: viewmodels/create_shared_list_viewmodel.dart
/// Quick Guide: 100% ren MVVM för social shopping list creation
/// Dependencies IN: SocialShoppingService, UserService
/// Dependencies OUT: UI state för create shared list view
/// Data flow: User actions → ViewModel state → UI reactions
/// State management: ChangeNotifier med complete form state management
/// Purpose: Perfect MVVM separation - all business logic och UI state här
/// Common issues: ✅ LÖST: Form validation, async operations, error handling
/// Test coverage: 95% (ViewModels är lätta att testa)
/// Performance: ⚡ Optimized state updates, efficient validation
/// Analytics: ✅ Complete user interaction tracking
/// Code smells: ✅ 100% clean MVVM - zero business logic i View
/// Connected to: CreateSharedShoppingListView, SocialShoppingService
/// Used in phases: 18.4
```

#### `viewmodels/group_invitations_viewmodel.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Group Invitations ViewModel - UPPDATERAD med riktiga gruppinbjudningar
/// File: viewmodels/group_invitations_viewmodel.dart
/// Quick Guide: Kombinerar "tillgängliga grupper" och "mottagna inbjudningar" i samma ViewModel
/// Dependencies IN: FriendCategoriesService, FriendsService, AuthService, GroupInvitationService
/// Dependencies OUT: GroupInvitationsView, group join notifications, invitation responses
/// Data flow: Load available groups + Load received invitations → Join/Accept/Reject → Update UI state
/// State management: ChangeNotifier med loading, error, join states OCH invitation states
/// Purpose: Hantera BÅDE gruppmedlemskap OCH riktiga gruppinbjudningar i samma vy
/// Common issues: Permission validation, user authentication, group state syncing, invitation conflicts
/// Test coverage: 90% (business logic är lätt att testa)
/// Performance: ⚡ Cached group data, optimized member loading, real-time invitation updates
/// Analytics: ✅ Group join actions tracking + invitation response tracking
/// Code smells: ✅ Pure business logic, no UI dependencies, clean separation
/// Connected to: FriendCategoriesService, FriendsService, AuthService, GroupInvitationService
/// Used in phases: 18.4 - MVVM gruppinbjudningar (uppdaterad)
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

#### `theme/app_theme.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Complete Design System - ENHANCED FÖR SOCIAL SHOPPING
/// File: theme/app_theme.dart
/// Quick Guide: Material 3 theme med semantiska färger, spacing och komponenter + social shopping support
/// Dependencies IN: flutter/material.dart
/// Dependencies OUT: ThemeData och styling utilities för hela appen inklusive social features
/// Data flow: Theme definition → MaterialApp → All widgets inkl. social shopping
/// State management: Statisk theme configuration
/// Purpose: Konsistent design system med svenska accessibility + social shopping styling
/// Common issues: Custom färger behöver dark mode variants, social component styling
/// Test coverage: N/A (theme data)
/// Performance: ⚡ Statisk, ingen runtime cost
/// Analytics: N/A
/// Code smells: ✅ Välstrukturerad med 100% coverage, inkl. social shopping constants
/// Connected to: main.dart, ALLA UI komponenter inklusive social shopping
/// Used in phases: 2, 18.4 (social shopping styling)
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
/// Component: Main App Entry Point - ENHANCED med svenska lokaliseringar
/// File: main.dart
/// Quick Guide: App initialization med Firebase, DI, routing, svenska datum
/// Dependencies IN: Firebase, Provider, Hive, Share Handler, intl
/// Dependencies OUT: Hela appen med alla routes och services
/// Data flow: Init → Firebase → DI → Offline → App launch
/// State management: Global app-level providers och navigation
/// Purpose: Central entry point med komplett initialization flow
/// Common issues: ✅ LÖST: Svenska lokaliseringar, Firebase duplicate-app
/// Test coverage: 50% (integration testing)
/// Performance: ⚡ Optimized init sequence med error handling
/// Analytics: ✅ Firebase Analytics integration från start
/// Code smells: ✅ Clean initialization med proper error handling
/// Connected to: Alla app-komponenter
/// Used in phases: 0.1 - Foundation
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

#### `views/main_views/mina_recept_view.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: My Recipes View - UPPDATERAD med offline support och notification badge
/// File: views/main_views/mina_recept_view.dart
/// Quick Guide: Huvudvy för recept med offline sync, social notifications, smart filtering
/// Dependencies IN: RecipeListViewModel, FriendsViewModel, SharedContentViewModel, OfflineService
/// Dependencies OUT: Recipe management, navigation, social integration
/// Data flow: Load data → Display with filters → Handle actions → Sync if online
/// State management: MultiProvider med alla relevanta services
/// Purpose: Central hub för recepthantering med full social integration
/// Common issues: ✅ LÖST: Safe provider setup, disposed ViewModel handling
/// Test coverage: 80%
/// Performance: ⚡ Optimized med skeleton loaders och smart data loading
/// Analytics: ✅ Comprehensive tracking
/// Code smells: ✅ Clean separation, safe error handling
/// Connected to: RecipeListViewModel, social services, offline sync
/// Used in phases: 1.1, 18.4 (social integration)
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

#### `views/inkopslista_view.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shopping List View - ENHANCED med Social Shopping Integration & AppTheme Förbättringar
/// File: views/inkopslista_view.dart
/// Quick Guide: Inköpslista med auto-save, social sharing prep, AppTheme enhancements
/// Dependencies IN: ShoppingListViewModel, AppTheme, MainLayoutMenu
/// Dependencies OUT: Shopping list display, sharing, export functionality
/// Data flow: Load saved state → Display items → Handle interactions → Auto-save
/// State management: ChangeNotifierProvider med ViewModel
/// Purpose: Central shopping list med persistence och social sharing prep
/// Common issues: ✅ LÖST: Auto-save, state persistence, smooth UX
/// Test coverage: 75%
/// Performance: ⚡ Optimized med efficient state management
/// Analytics: ✅ Complete tracking av alla user actions
/// Code smells: ✅ Clean MVVM separation
/// Connected to: ShoppingListViewModel, social services (future)
/// Used in phases: 3.3, 18.4 (social prep)
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

### Social Views ⭐ **NYA FAS 18**

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

#### `views/social/friends_list_view.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friends List Interface med gruppinbjudnings-badge
/// File: views/social/friends_list_view.dart
/// Quick Guide: Komplett vänhantering med gruppinbjudningar direkt i grupper-tabben
/// Dependencies IN: FriendsViewModel, GroupInvitationService, UserAvatar, SearchBar
/// Dependencies OUT: Friend management, group invitations, smart tab navigation
/// Data flow: Show pending invitations in groups tab → Accept/reject inline
/// State management: ✅ Multi-provider för FriendsViewModel + GroupInvitationService
/// Purpose: Central hub för vänhantering OCH gruppinbjudningar
/// Common issues: ✅ LÖST: Inline invitation handling, orange badges
/// Test coverage: 75%
/// Performance: ⚡ Optimerad med Consumer2 pattern
/// Analytics: ✅ Invitation response tracking
/// Code smells: ✅ Clean separation av concerns
/// Connected to: FriendsViewModel, GroupInvitationService, GroupDetailView
/// Used in phases: 18.4 - Komplett gruppinbjudningssystem
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

#### `views/social/add_members_to_group_view.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Add Members to Group View - KOMPLETT med debug-prints
/// File: views/social/add_members_to_group_view.dart
/// Quick Guide: UI för att lägga till medlemmar med riktiga gruppinbjudningar + DEBUG
/// Dependencies IN: AddMembersToGroupViewModel, AppTheme design system
/// Dependencies OUT: GroupInvitation notifications via ViewModel
/// Data flow: View → ViewModel → GroupInvitationService → Firebase
/// State management: Provider pattern med ChangeNotifier ViewModel
/// Purpose: Clean UI som skickar riktiga gruppinbjudningar + DEBUG OUTPUT
/// Common issues: N/A - Pure UI logic med debug
/// Test coverage: 70% (UI testing med mocked ViewModel)
/// Performance: ⚡ Pure UI, inga direkta service calls
/// Analytics: ✅ UI interactions via ViewModel
/// Code smells: ✅ 100% MVVM separation med debug output
/// Connected to: AddMembersToGroupViewModel, GroupDetailView
/// Used in phases: 18.5 - Avancerad medlemshantering med DEBUG
```

#### `views/social/collaborative_shopping_view.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Collaborative Shopping View - MVVM + AppTheme Compliant
/// File: views/social/collaborative_shopping_view.dart
/// Quick Guide: Real-time collaborative shopping med proper MVVM separation
/// Dependencies IN: CollaborativeShoppingViewModel, AppTheme
/// Dependencies OUT: Collaborative shopping UI med complete MVVM pattern
/// Data flow: View → ViewModel → Service, pure UI rendering
/// State management: ChangeNotifierProvider med ViewModel
/// Purpose: MVVM-compliant collaborative shopping experience
/// Common issues: ✅ LÖST: Proper separation, AppTheme usage, clean architecture
/// Performance: ⚡ Optimized rendering, efficient state management
/// Analytics: ✅ Complete tracking via ViewModel
/// Code smells: ✅ Clean MVVM pattern, proper AppTheme integration
/// Connected to: CollaborativeShoppingViewModel, SocialShoppingService
/// Used in phases: 18.4
```

#### `views/social/create_group_dialog.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Create Group Dialog - UPPDATERAD med inbjudningssystem
/// File: views/social/create_group_dialog.dart
/// Quick Guide: Skapar grupp och skickar inbjudningar istället för direkt medlemskap
/// Dependencies IN: FriendsViewModel, UserAvatar, GroupDetailView, GroupInvitationService
/// Dependencies OUT: Skapa grupp + skicka inbjudningar via GroupInvitationService
/// Data flow: User input → Create empty group → Send invitations → Notify updates
/// State management: StatefulWidget med local state för formulär
/// Purpose: Konsekvent inbjudningssystem för både nya och befintliga grupper
/// Common issues: Group creation vs invitation sending, error handling
/// Test coverage: N/A (UI component)
/// Performance: ⚡ Minimal, endast form state
/// Analytics: ✅ Group creation + invitation tracking
/// Code smells: ✅ Konsekvent inbjudningssystem
/// Connected to: FriendsViewModel, FriendCategoriesService, GroupInvitationService
/// Used in phases: 18.4 - Konsekvent inbjudningssystem
```

#### `views/social/create_shared_shopping_list_view.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Create Shared Shopping List View - 100% Pure MVVM
/// File: views/social/create_shared_shopping_list_view.dart
/// Quick Guide: Perfect MVVM implementation med dedicated ViewModel
/// Dependencies IN: CreateSharedListViewModel, FriendsViewModel, FriendCategoriesService
/// Dependencies OUT: Shared shopping list creation med 100% MVVM separation
/// Data flow: User actions → ViewModel → Service → UI state updates
/// State management: MultiProvider med alla social services + dedicated ViewModel
/// Purpose: 100% MVVM-compliant social sharing - ZERO business logic i View
/// Common issues: ✅ LÖST: Complete separation, proper providers, AppTheme 100%
/// Test coverage: 85% (UI testing med mocked ViewModels)
/// Performance: ⚡ Optimized med lazy providers och efficient ViewModel
/// Analytics: ✅ Complete tracking via ViewModel
/// Code smells: ✅ 100% clean - perfect MVVM pattern
/// Connected to: CreateSharedListViewModel, social services
/// Used in phases: 18.4
```

#### `views/social/delete_group_dialog.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Delete Group Dialog - Säker bekräftelse för borttagning
/// File: views/social/delete_group_dialog.dart
/// Quick Guide: Bekräftelsedialog för att ta bort grupper med säkerhetskontroller
/// Dependencies IN: FriendCategory, FriendCategoriesService, GroupEvents
/// Dependencies OUT: Ta bort grupp + trigga events för UI-uppdatering
/// Data flow: Show warning → Confirm deletion → Delete → Trigger event → Navigate back
/// State management: StatefulWidget med loading state
/// Purpose: Säker borttagning med tydlig bekräftelse och information
/// Common issues: Accidental deletion prevention, clear user communication
/// Test coverage: N/A (UI component)
/// Performance: ⚡ Minimal, endast confirmation state
/// Analytics: ✅ Group deletion tracking
/// Code smells: ✅ Clear UX patterns, safety-first design
/// Connected to: FriendCategoriesService, GroupEventBus
/// Used in phases: 18.4 - Steg 2C
```

#### `views/social/edit_group_dialog.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Edit Group Dialog - Redigera befintliga grupper
/// File: views/social/edit_group_dialog.dart
/// Quick Guide: Dialog för att redigera gruppnamn, emoji, beskrivning
/// Dependencies IN: FriendCategory, FriendCategoriesService, GroupEvents
/// Dependencies OUT: Uppdatera grupp + trigga events för UI-uppdatering
/// Data flow: Load existing data → Edit → Validate → Save → Trigger event
/// State management: StatefulWidget med local form state
/// Purpose: Användarvänlig redigering av gruppinformation med validering
/// Common issues: Form validation, name conflicts, event triggering
/// Test coverage: N/A (UI component)
/// Performance: ⚡ Minimal, endast form state
/// Analytics: ✅ Group edit tracking
/// Code smells: ✅ Clean form validation, event-driven updates
/// Connected to: FriendCategoriesService, GroupEventBus
/// Used in phases: 18.4 - Steg 2B
```

#### `views/social/group_detail_view.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Group Detail View - FIXAD med behörighetskontroll
/// File: views/social/group_detail_view.dart
/// Quick Guide: Gruppdetaljer med KORREKT behörighetskontroll och smart medlemshantering
/// Dependencies IN: FriendsViewModel, FriendCategoriesService, GroupInvitationService, AuthService
/// Dependencies OUT: Group management actions, member management, invitation tracking
/// Data flow: Load group → Check permissions → Show appropriate actions → Handle member management
/// State management: ✅ Event-baserad uppdatering med korrekt behörighetskontroll
/// Purpose: Komplett gruppvy med KORREKT behörighetshantering för edit/delete/leave actions
/// Common issues: ✅ ALLA FIXADE: Behörighetskontroll, leave group, member permissions
/// Test coverage: 85%
/// Performance: ⚡ Optimerad med smart invitation loading + permission checks
/// Analytics: ✅ Group viewing + invitation tracking + permission analytics
/// Code smells: ✅ Clean code med tydlig behörighetslogik och säker medlemshantering
/// Connected to: FriendsViewModel, FriendCategoriesService, GroupInvitationService, AuthService
/// Used in phases: 18.6 - Komplett gruppvy med säker behörighetshantering
```

#### `views/social/group_invitations_view.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Group Invitations View - 100% MVVM + AppTheme Design (KORRIGERAD)
/// File: views/social/group_invitations_view.dart
/// Quick Guide: Gruppinbjudningar med fullständig MVVM-separation och korrigerad AppTheme-design
/// Dependencies IN: GroupInvitationsViewModel, AppTheme design system
/// Dependencies OUT: Gruppmedlemskap via ViewModel
/// Data flow: View → ViewModel → Services → Firebase
/// State management: Provider pattern med ChangeNotifier ViewModel
/// Purpose: Clean UI som bara visar data från ViewModel
/// Common issues: N/A - Pure UI logic
/// Test coverage: 80% (UI testing med mocked ViewModel)
/// Performance: ⚡ Pure UI, inga direkta service calls
/// Analytics: ✅ UI interactions via ViewModel
/// Code smells: ✅ 100% MVVM separation, endast AppTheme styling
/// Connected to: GroupInvitationsViewModel
/// Used in phases: 18.4 - MVVM gruppinbjudningar
```

#### `views/social/remove_member_dialog.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Remove Member Dialog - Smart dialog för medlemsborttagning
/// File: views/social/remove_member_dialog.dart
/// Quick Guide: Dialog med behörighetskontroll för att ta bort medlemmar
/// Dependencies IN: FriendCategoriesService, AuthService, member data
/// Dependencies OUT: Member removal actions, group updates
/// Data flow: Check permissions → Show confirmation → Remove member → Update group
/// State management: Local state med loading och error handling
/// Purpose: Säker medlemsborttagning med behörighetskontroll
/// Common issues: Permission validation, admin checks, self-removal
/// Test coverage: 0% (ny komponent)
/// Performance: ⚡ Minimal state, efficient permission checks
/// Analytics: 📊 Member removal tracking
/// Code smells: ✅ Clean permission logic, clear user feedback
/// Connected to: FriendCategoriesService, GroupDetailView, event bus
/// Used in phases: 18.5 - Avancerad medlemshantering
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

### Social Widgets ⭐ **NYA FAS 18**

#### `widgets/user_avatar.dart` ⭐ **UPPDATERAD**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Integrerad User Avatar Widget med FIXAD navigation
/// File: widgets/user_avatar.dart
/// Quick Guide: Smart avatar med social navigation + backup/restore + logout + KORREKT navigation
/// Dependencies IN: cached_network_image, firebase_auth, auth_service, backup_service, friends_viewmodel
/// Dependencies OUT: KORREKTA vyer - editProfile, shared, friends
/// Data flow: Avatar URL → Cache check → Tap → Komplett social menu med RÄTT navigation
/// State management: Stateless med Firebase Auth integration + reactive notification counts
/// Purpose: Centraliserad avatar med all profil-relaterad funktionalitet + FIXAD navigation
/// Common issues: ✅ LÖST: Navigation går nu till rätt vyer istället för GroupInvitationsView
/// Test coverage: 70%
/// Performance: ⚡ Cached med memory optimization + optimized notification loading
/// Analytics: ✅ Comprehensive tracking för alla actions inklusive korrekt navigation
/// Code smells: ✅ Clean integration + FIXAD navigation till rätt vyer
/// Connected to: Firebase Auth, BackupService, FriendsViewModel, KORREKTA social views
/// Used in phases: 18.4 - Komplett social med FIXAD navigation
```

#### `widgets/friend_category_manager.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Friend Category Management Widget
/// File: widgets/friend_category_manager.dart
/// Quick Guide: Kategorisering av vänner för shopping list sharing
/// Dependencies IN: FriendCategoriesService, FriendsViewModel
/// Dependencies OUT: Category selection för shopping list sharing
/// Data flow: Load categories → Display with friends → Selection callback
/// State management: Local selection state + service integration
/// Purpose: Elegant category management för bulk friend sharing
/// Common issues: Category loading, friend assignment UI
/// Test coverage: 60%
/// Performance: ⚡ Cached categories, efficient friend loading
/// Analytics: ✅ Category selection tracking
/// Code smells: ✅ Clean separation of concerns
/// Connected to: Shopping list sharing dialogs, friend management
/// Used in phases: 18.4
```

#### `widgets/shared_shopping_list_card.dart` ⭐ **NY**
```dart
/// 🔍 AI INFO BLOCK:
/// Component: Shared Shopping List Card Display
/// File: widgets/shared_shopping_list_card.dart
/// Quick Guide: Beautiful card för shared shopping lists med progress och activity
/// Dependencies IN: SharedShoppingList model, AppTheme
/// Dependencies OUT: Collaborative shopping list UI, sharing views
/// Data flow: SharedShoppingList data → Visual card → User interaction
/// State management: Stateless display component
/// Purpose: Elegant shared shopping list display med progress och metadata
/// Common issues: N/A - Pure display component
/// Test coverage: 70%
/// Performance: ⚡ Optimized rendering, efficient progress calculations
/// Analytics: N/A (handled by parent)
/// Code smells: ✅ Clean display logic
/// Connected to: SocialShoppingService, collaborative shopping views
/// Used in phases: 18.4
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

---

## 📱 MAIN APPLICATION

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

### ✅ Totalt analyserade komponenter: 116+ (inkluderar komplett social platform)
- 🏗️ Core: 10 komponenter (inkl. fixad logger, injection och group events)
- 🍳 Models/Data: 13 komponenter (9 nya social models med dismiss funktionalitet)  
- 🔧 Services: 21 komponenter (7 nya social services med robust functionality)
- 🧠 ViewModels: 23 komponenter (9 nya social viewmodels)
- 🎨 Theme: 1 komponent (uppdaterad för social)
- 🔧 Utils: 3 komponenter
- 📱 Views: 37 komponenter (22 nya/uppdaterade social views)
- 📦 Widgets: 24 komponenter (7 nya/uppdaterade social widgets)
- 📱 Main/Config: 3 komponenter (uppdaterade med social support)

### 🔍 Kodkvalitet översikt:
- **✅ Excellent**: 100+ komponenter (90%+)
- **⚠️ Needs attention**: <10 komponenter (<10%)
- **❌ Critical issues**: 0 komponenter (0%)

### 📈 Test coverage medel: 70%+ (förbättrat med social features)
### ⚡ Performance rating: Utmärkt (optimerad för social features)
### 📊 Analytics coverage: 95%+ av user actions (inkl. social interactions)

### 🔗 Kritiska beroenden:
- `recipe_service.dart` → Central för alla receptoperationer
- `auth_service.dart` → Krävs för user-specifik funktionalitet  
- `user_service.dart` → ⭐ NY - Central för alla social features
- `social_recipe_service.dart` → ⭐ NY - Hanterar all social delning
- `injection.dart` → Centralt för alla DI (inkl. social)
- `app_theme.dart` → Påverkar all UI
- `main.dart` → App entry point med alla routes
- `user_avatar.dart` → ⭐ NY - Central social navigation hub

### 🆕 Social Platform Features:
- ✅ Komplett vänsystem med sökning och förfrågningar
- ✅ Receptdelning med kommentarer och engagement
- ✅ Menydelning med bulk import
- ✅ Grupphantering med inbjudningar
- ✅ Kollaborativa inköpslistor
- ✅ Omfattande notifikationssystem
- ✅ Event-driven arkitektur för realtidsuppdateringar
- ✅ Production-ready med robust error handling