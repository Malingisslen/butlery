# 📄 AI Code Index – Butlery (Komplett version)

_Version för AI-assistenter med fullständig information om varje fil._

## 🍳 RECEPTHANTERING

### Models
#### `models/recipe.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: model
/// File: models/recipe.dart
/// Purpose: Huvudmodell för recept med alla fält och serialisering
///
/// Quick Guide:
///   - Skapa: Recipe.fromJson(map)
///   - Serialisera: recipe.toJson()
///   - Kopiera med ändringar: recipe.copyWith(title: 'Ny titel')
///
/// Dependencies IN: 
///   - json_annotation (för @JsonSerializable)
///   - hive (för @HiveType)
/// Dependencies OUT: 
///   - Används av alla recipe-relaterade services och viewmodels
///
/// Data flow: Firestore JSON ↔ Recipe model ↔ UI
/// State management: Immutable med copyWith
///
/// Common issues:
///   - Glöm inte köra build_runner efter ändringar
///   - lastCookedAt och createdAt måste hanteras som Timestamp i Firestore
///
/// Test coverage: 85% (saknar test för Hive adapters)
/// Performance: ⚡ Snabb (serialisering < 1ms)
/// Analytics: ✅ Loggar recipe_created, recipe_updated
///
/// Code smells: 
///   - ⚠️ Klass blir stor (300+ rader), överväg uppdelning
///   - ⚠️ imageUrl deprecated - migrera till images array (Fas 15)
///
/// Connected to: recipe_service.dart, alla recipe viewmodels, recipe.g.dart
/// Used in phases: 3, 6, 8, 13, 14, 15
```

#### `models/recipe.g.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: model
/// File: models/recipe.g.dart
/// Purpose: Autogenererad kod för JSON och Hive serialisering
///
/// Quick Guide:
///   - ALDRIG redigera manuellt
///   - Genereras med: flutter pub run build_runner build
///
/// Dependencies IN: Genereras från recipe.dart
/// Dependencies OUT: Används av Hive för lokal lagring
///
/// Data flow: Hive binary ↔ Recipe object
///
/// Common issues:
///   - Om build_runner failar: --delete-conflicting-outputs
///
/// Test coverage: N/A (genererad kod)
/// Performance: ⚡ Snabb
/// Analytics: N/A
///
/// Connected to: recipe.dart, offline_service.dart
/// Used in phases: 13
```

#### `models/shopping_item.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: model
/// File: models/shopping_item.dart
/// Purpose: Modell för inköpslisteobjekt med checkstatus
///
/// Quick Guide:
///   - Skapa: ShoppingItem(ingredient: 'Mjölk', quantity: '1 liter')
///   - Toggle: item.copyWith(isChecked: !item.isChecked)
///
/// Dependencies IN: Ingen
/// Dependencies OUT: shopping_list_service.dart
///
/// Data flow: Recipe ingredients → ShoppingItem → UI checkboxes
///
/// Common issues:
///   - Quantity är fritext, svår att aggregera
///
/// Test coverage: 70%
/// Performance: ⚡ Snabb
/// Analytics: ❌ Saknas (bör logga shopping_list_completed)
///
/// Code smells:
///   - ⚠️ Saknar unit parsing för quantity
///
/// Connected to: shopping_list_service.dart, shopping_list_viewmodel.dart
/// Used in phases: 4
```

### Services
#### `services/recipe_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/recipe_service.dart
/// Purpose: Central service för all recepthantering med Firebase och offline-stöd
///
/// Quick Guide:
///   - Hämta stream: recipeService.recipesStream
///   - Skapa: await recipeService.createRecipe(recipe)
///   - Uppdatera: await recipeService.updateRecipe(id, recipe)
///   - Ta bort: await recipeService.deleteRecipe(id)
///   - Markera tillagad: await recipeService.markAsCooked(id)
///
/// Dependencies IN: 
///   - AuthService (för userId)
///   - OfflineService (för caching)
///   - AnalyticsService (för events)
/// Dependencies OUT: 
///   - recipesStream (Stream<List<Recipe>>)
///   - CRUD metoder
///
/// Data flow: 
///   Firestore ↔ RecipeService ↔ ViewModels → Views
///   ↓
///   Hive (offline cache)
///
/// State management: StreamController.broadcast för realtid
///
/// Common issues:
///   - Auth krävs: Kolla currentUser != null
///   - Offline: Ändringar köas automatiskt
///   - Memory leak: Glöm inte dispose streams
///
/// Test coverage: 75% (saknar integration tests)
/// Performance: ⚡ Bra (pagination saknas för stora listor)
/// Analytics: ✅ Loggar alla CRUD events
///
/// Code smells:
///   - ⚠️ Fil över 500 rader - dela upp i RecipeRepository + RecipeService
///   - ⚠️ Hårdkodade Firebase paths - använd constants
///
/// Connected to: Firestore, Hive, auth_service.dart, offline_service.dart, alla recipe viewmodels
/// Used in phases: 3, 6, 13, 14, 15, 16, 23
```

#### `services/offline_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/offline_service.dart
/// Purpose: Hanterar offline-funktionalitet med Hive och automatisk synkning
///
/// Quick Guide:
///   - Cache recept: await offlineService.cacheRecipe(recipe)
///   - Köa ändring: await offlineService.queueChange(change)
///   - Kolla status: offlineService.hasUnsyncedChanges
///   - Manuell synk: await offlineService.syncPendingChanges()
///
/// Dependencies IN:
///   - Hive (lokal databas)
///   - ConnectivityCheck (nätverksstatus)
/// Dependencies OUT:
///   - Offline cache för recept
///   - Synk-kö för ändringar
///
/// Data flow:
///   Offline ändringar → Hive queue → Auto-sync → Firestore
///
/// Common issues:
///   - Hive måste initieras i main.dart
///   - Konflikthantering vid synk saknas
///
/// Test coverage: 60% (svårt att testa offline scenarios)
/// Performance: ⚡ Snabb lokal access
/// Analytics: ✅ Loggar sync_started, sync_completed
///
/// Code smells:
///   - ⚠️ Saknar konfliktlösning för samtidiga ändringar
///   - ⚠️ Ingen retry-logik för misslyckad synk
///
/// Connected to: Hive, connectivity_check.dart, recipe_service.dart
/// Used in phases: 13
```

### ViewModels
#### `viewmodels/recipe_list_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/recipe_list_viewmodel.dart
/// Purpose: Hanterar receptlista med sök, filter och realtidsuppdateringar
///
/// Quick Guide:
///   - Filtrera: viewModel.toggleTimeFilter(TimeFilter.quick)
///   - Sök: viewModel.searchRecipes('pasta')
///   - Refresh: viewModel.refreshRecipes()
///   - State: viewModel.filteredRecipes, isLoading, error
///
/// Dependencies IN:
///   - RecipeService (receptdata)
///   - SearchService (sök och filter)
///   - AnalyticsService (loggning)
/// Dependencies OUT:
///   - filteredRecipes getter
///   - loading/error states
///   - notifyListeners() för UI updates
///
/// Data flow:
///   RecipeService.stream → filter/search → filteredRecipes → UI
///
/// Common issues:
///   - Memory leak: Dispose StreamSubscription
///   - Performance: Filter på stora listor
///
/// Test coverage: 80%
/// Performance: ⚠️ Filter kan vara långsam på 100+ recept
/// Analytics: ✅ Loggar search_performed, filter_applied
///
/// Code smells:
///   - ✅ Välstrukturerad separation of concerns
///
/// Connected to: mina_recept_view.dart, recipe_service.dart, search_service.dart
/// Used in phases: 3, 9, 10
```

#### `viewmodels/recipe_detail_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/recipe_detail_viewmodel.dart
/// Purpose: Hanterar receptdetaljer, delning och "markera som tillagad"
///
/// Quick Guide:
///   - Ladda: viewModel.loadRecipe(recipeId)
///   - Dela: viewModel.shareRecipe()
///   - Markera tillagad: viewModel.markAsCooked()
///   - Ta bort: viewModel.deleteRecipe()
///
/// Dependencies IN:
///   - RecipeService (CRUD operations)
///   - ShareService (delning)
///   - AnalyticsService (events)
/// Dependencies OUT:
///   - recipe getter (nullable)
///   - isLoading, error states
///
/// Data flow:
///   RecipeService → ViewModel state → UI updates
///
/// Common issues:
///   - Null recipe vid navigation timing
///   - Share kan faila på simulator
///
/// Test coverage: 70%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Loggar recipe_viewed, recipe_cooked, recipe_shared
///
/// Connected to: recipe_detail_view.dart, recipe_service.dart, share_service.dart
/// Used in phases: 11, 14
```

#### `viewmodels/recipe_form_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/recipe_form_viewmodel.dart
/// Purpose: Hanterar receptformulär för skapande och redigering
///
/// Quick Guide:
///   - Init för ny: viewModel.initializeForNew()
///   - Init för edit: viewModel.initializeForEdit(recipe)
///   - Spara: viewModel.saveRecipe()
///   - Validera: automatic on save
///
/// Dependencies IN:
///   - RecipeService (save operations)
///   - FormValidators (validering)
///   - ImagePickerService (kommande)
/// Dependencies OUT:
///   - 20+ TextEditingControllers
///   - formKey för validering
///   - isLoading, error states
///
/// Data flow:
///   UI input → Controllers → Validation → Recipe model → Save
///
/// Common issues:
///   - MÅSTE dispose() alla controllers
///   - Validation triggers för tidigt
///
/// Test coverage: 65%
/// Performance: ⚠️ Många controllers kan vara tungt
/// Analytics: ✅ Loggar recipe_form_submitted
///
/// Code smells:
///   - ⚠️ 20+ controllers är mycket - överväg FormFieldsManager
///   - ⚠️ Duplicerad logik mellan create/edit
///
/// Connected to: edit_recipe_view.dart, skriv_sjalv_recept_view.dart, recipe_service.dart
/// Used in phases: 4, 8, 15
```

### Views
#### `views/mina_recept_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/mina_recept_view.dart
/// Purpose: Huvudvy för receptlista med sök, filter och navigation
///
/// Quick Guide:
///   - Consumer<RecipeListViewModel> för state
///   - Pull-to-refresh implementerat
///   - FilterChips för snabbfilter
///   - SearchBar för realtidssök
///
/// Dependencies IN:
///   - RecipeListViewModel (state och logik)
///   - MainLayoutMenu (navigation wrapper)
/// Dependencies OUT:
///   - Navigerar till: recipe_detail, lagg_till_recept
///
/// Data flow:
///   User input → ViewModel → UI rebuild via Consumer
///
/// Common issues:
///   - Skeleton loader glöms ofta vid loading
///   - Empty state behövs när lista tom
///
/// Test coverage: 50% (mest UI, svårt att testa)
/// Performance: ⚡ Smooth med optimized widgets
/// Analytics: Auto via ViewModel
///
/// Connected to: recipe_list_viewmodel.dart, main_layout_menu.dart, recipe_card.dart
/// Used in phases: 1, 3, 9, 10
```

#### `views/recipe_detail_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view  
/// File: views/recipe_detail_view.dart
/// Purpose: Visar komplett recept med alla detaljer och actions
///
/// Quick Guide:
///   - Tar Recipe som argument i route
///   - Actions: dela, redigera, ta bort, markera tillagad
///   - Visar sourceUrl som klickbar länk
///   - "Senast tillagad" badge om relevant
///
/// Dependencies IN:
///   - RecipeDetailViewModel (actions och state)
///   - Recipe model (display data)
/// Dependencies OUT:
///   - Navigerar till: edit_recipe
///   - Öppnar: externa URLs
///
/// Data flow:
///   Route args → ViewModel → UI components
///
/// Common issues:
///   - Null recipe crashar - validera i route
///   - Långa instruktioner behöver scroll
///
/// Test coverage: 45%
/// Performance: ⚡ Snabb
/// Analytics: Auto via ViewModel
///
/// Connected to: recipe_detail_viewmodel.dart, edit_recipe_view.dart
/// Used in phases: 3, 8, 11, 14
```

#### `views/edit_recipe_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/edit_recipe_view.dart
/// Purpose: Formulär för att redigera befintligt recept
///
/// Quick Guide:
///   - Tar Recipe som route argument
///   - Förifyller alla fält med befintlig data
///   - Samma formulär som skriv_sjalv men med data
///
/// Dependencies IN:
///   - RecipeFormViewModel (formulärlogik)
///   - Recipe model (initial data)
/// Dependencies OUT:
///   - Uppdaterar recept via ViewModel
///   - Navigator.pop() vid save
///
/// Data flow:
///   Recipe → Pre-fill form → Edit → Save → Navigate back
///
/// Common issues:
///   - Form reset vid hot reload
///   - Validation på oförändrad data
///
/// Test coverage: 40%
/// Performance: ⚡ OK (form kan lagga med många fält)
/// Analytics: Via ViewModel
///
/// Connected to: recipe_form_viewmodel.dart, recipe_detail_view.dart
/// Used in phases: 4
```

#### `views/skriv_sjalv_recept_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/skriv_sjalv_recept_view.dart
/// Purpose: Manuell inmatning av nytt recept
///
/// Quick Guide:
///   - Komplett formulär med alla receptfält
///   - Steg: grundinfo → ingredienser → instruktioner
///   - InstructionEditor för numrerade steg
///   - Validering på submit
///
/// Dependencies IN:
///   - RecipeFormViewModel (form state)
///   - FormValidators (field validation)
/// Dependencies OUT:
///   - Skapar nytt recept
///   - Navigator.pop() efter save
///
/// Data flow:
///   Empty form → User input → Validation → Create → Navigate
///
/// Common issues:
///   - Långa formulär tappar data vid back
///   - Keyboard covers fields
///
/// Test coverage: 35% (UI-tungt)
/// Performance: ⚠️ Form med många fields
/// Analytics: Via ViewModel
///
/// Connected to: recipe_form_viewmodel.dart, lagg_till_recept_view.dart
/// Used in phases: 4, 8
```

## 🛒 INKÖPSLISTA

### Services
#### `services/shopping_list_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/shopping_list_service.dart
/// Purpose: Genererar och hanterar inköpslistor från recept
///
/// Quick Guide:
///   - Generera: generateFromRecipes(recipeIds)
///   - Lägg till: addCustomItem(item)
///   - Toggle: toggleItem(itemId)
///   - Rensa: clearCheckedItems()
///
/// Dependencies IN:
///   - RecipeService (hämta recept för ingredienser)
/// Dependencies OUT:
///   - ShoppingList med aggregerade items
///
/// Data flow:
///   Recipes → Extract ingredients → Merge duplicates → ShoppingList
///
/// Common issues:
///   - Svårt att merga "1 dl mjölk" + "200 ml mjölk"
///   - Enhetskonvertering saknas
///
/// Test coverage: 55%
/// Performance: ⚡ OK (O(n*m) för merging)
/// Analytics: ❌ Saknar events
///
/// Code smells:
///   - ⚠️ Naiv strängmatchning för ingredienser
///   - ⚠️ Borde använda NLP för parsing
///
/// Connected to: shopping_list_viewmodel.dart, menu_service.dart
/// Used in phases: 4
```

### ViewModels
#### `viewmodels/shopping_list_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/shopping_list_viewmodel.dart
/// Purpose: Hanterar inköpslistans state och interaktioner
///
/// Quick Guide:
///   - items getter för lista
///   - toggleItem(id) för checkbox
///   - addCustomItem('Mjölk')
///   - shareList() för delning
///
/// Dependencies IN:
///   - ShoppingListService (business logic)
///   - ShareService (export)
/// Dependencies OUT:
///   - items lista
///   - isLoading state
///   - notifyListeners()
///
/// Data flow:
///   Service → ViewModel state → UI checkboxes
///
/// Common issues:
///   - State reset vid navigation
///   - Checkbox performance på stora listor
///
/// Test coverage: 70%
/// Performance: ⚡ Bra
/// Analytics: ❌ Borde logga list_shared, item_checked
///
/// Connected to: inkopslista_view.dart, shopping_list_service.dart, share_service.dart
/// Used in phases: 4, 11
```

### Views
#### `views/inkopslista_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/inkopslista_view.dart
/// Purpose: Visar inköpslista med checkboxar och delning
///
/// Quick Guide:
///   - CheckboxListTile för varje item
///   - Swipe to delete (om implementerat)
///   - FAB för add custom item
///   - Share button i AppBar
///
/// Dependencies IN:
///   - ShoppingListViewModel (state)
///   - MainLayoutMenu (navigation)
/// Dependencies OUT:
///   - Delning via ShareService
///
/// Data flow:
///   ViewModel.items → ListView → User interaction → ViewModel
///
/// Common issues:
///   - Empty state glöms ofta
///   - Checkbox ripple effect laggar
///
/// Test coverage: 40%
/// Performance: ⚡ Smooth
/// Analytics: Via ViewModel
///
/// Connected to: shopping_list_viewmodel.dart, main_layout_menu.dart
/// Used in phases: 4, 11
```

## 📅 VECKOMENY

### Services
#### `services/menu_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/menu_service.dart
/// Purpose: Genererar veckomeny baserat på prompt och tillgängliga recept
///
/// Quick Guide:
///   - Generera: generateMenu(prompt, days)
///   - Algoritm: Fuzzy matching + random selection
///   - Output: Map<String, Recipe>
///
/// Dependencies IN:
///   - RecipeService (tillgängliga recept)
/// Dependencies OUT:
///   - Veckomeny som Map
///   - Automatisk inköpslista
///
/// Data flow:
///   Prompt → Parse keywords → Match recipes → Random select → Menu
///
/// Common issues:
///   - För få recept ger upprepning
///   - Fuzzy matching missar ibland
///
/// Test coverage: 65%
/// Performance: ⚡ Snabb (< 100ms)
/// Analytics: ✅ Loggar menu_generated
///
/// Code smells:
///   - ⚠️ Borde använda AI för bättre matching
///
/// Connected to: menu_viewmodel.dart, recipe_service.dart
/// Used in phases: 4
```

### ViewModels
#### `viewmodels/menu_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/menu_viewmodel.dart
/// Purpose: Hanterar menygeneration och delning
///
/// Quick Guide:
///   - generateMenu(prompt) från UI
///   - generatedMenu getter för resultat
///   - shareMenu() för textdelning
///   - regenerate() för ny meny
///
/// Dependencies IN:
///   - MenuService (generation logic)
///   - ShareService (delning)
///   - ShoppingListService (auto-generate)
/// Dependencies OUT:
///   - Menu Map och loading state
///
/// Data flow:
///   UI prompt → Service → Menu → Auto shopping list
///
/// Common issues:
///   - Tom prompt ger random meny
///   - Shopping list sync timing
///
/// Test coverage: 60%
/// Performance: ⚡ Bra
/// Analytics: Auto via MenuService
///
/// Connected to: veckomeny_view.dart, menu_service.dart
/// Used in phases: 4
```

### Views
#### `views/veckomeny_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/veckomeny_view.dart
/// Purpose: UI för att generera och visa veckomeny
///
/// Quick Guide:
///   - TextField för prompt
///   - Generate-knapp
///   - Lista med veckodagar och recept
///   - Share i AppBar
///
/// Dependencies IN:
///   - MenuViewModel (state och actions)
///   - MainLayoutMenu (nav wrapper)
/// Dependencies OUT:
///   - Navigerar till recipe_detail
///   - Genererar shopping list automatiskt
///
/// Data flow:
///   User prompt → ViewModel → Service → Display menu
///
/// Common issues:
///   - Långa recept-titlar overflow
///   - Loading state glöms
///
/// Test coverage: 35%
/// Performance: ⚡ Smooth
/// Analytics: Via ViewModel
///
/// Connected to: menu_viewmodel.dart, main_layout_menu.dart
/// Used in phases: 4, 11
```

## 🔐 AUTENTISERING

### Services
#### `services/auth_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/auth_service.dart
/// Purpose: Firebase Authentication wrapper med email/lösenord
///
/// Quick Guide:
///   - Login: signInWithEmailPassword(email, password)
///   - Register: registerWithEmailPassword(email, password)  
///   - Logout: signOut()
///   - Current: currentUser getter
///   - Stream: authStateChanges
///
/// Dependencies IN:
///   - Firebase Auth
/// Dependencies OUT:
///   - User object och auth state
///
/// Data flow:
///   Firebase Auth → AuthService → App-wide user state
///
/// Common issues:
///   - Weak password errors från Firebase
///   - Email already in use
///   - Network errors vid login
///
/// Test coverage: 80%
/// Performance: ⚡ Snabb (Firebase cached)
/// Analytics: ✅ Loggar login, logout, signup
///
/// Code smells:
///   - ✅ Välstrukturerad
///
/// Connected to: Firebase Auth, auth_viewmodel.dart, recipe_service.dart
/// Used in phases: 6
```

### ViewModels
#### `viewmodels/auth_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/auth_viewmodel.dart
/// Purpose: Hanterar login/registrering med validering
///
/// Quick Guide:
///   - switchMode() toggle login/register
///   - submit() validerar och skickar
///   - Controllers för email/password
///   - isLoading och error states
///
/// Dependencies IN:
///   - AuthService (Firebase operations)
///   - FormValidators (input validation)
/// Dependencies OUT:
///   - Auth state och form state
///
/// Data flow:
///   Form input → Validation → AuthService → Navigate
///
/// Common issues:
///   - Form reset vid mode switch
///   - Firebase errors på engelska
///
/// Test coverage: 75%
/// Performance: ⚡ Snabb
/// Analytics: Via AuthService
///
/// Connected to: auth_view.dart, auth_service.dart
/// Used in phases: 6
```

### Views
#### `views/auth_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/auth_view.dart
/// Purpose: Login och registreringsskärm med toggle
///
/// Quick Guide:
///   - Toggle mellan login/register
///   - Email och lösenord fields
///   - Submit button med loading
///   - Error display
///
/// Dependencies IN:
///   - AuthViewModel (all logic)
/// Dependencies OUT:
///   - Navigerar till MainLayout vid success
///
/// Data flow:
///   User input → ViewModel → Firebase → Navigation
///
/// Common issues:
///   - Keyboard covers fields
///   - Error messages truncated
///
/// Test coverage: 30% (UI)
/// Performance: ⚡ Snabb
/// Analytics: Via ViewModel
///
/// Connected to: auth_viewmodel.dart, main_layout_menu.dart
/// Used in phases: 6
```

## 📲 IMPORT-FUNKTIONER

### Import via URL
#### `viewmodels/url_import_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/url_import_viewmodel.dart
/// Purpose: Importerar recept från URL med web scraping
///
/// Quick Guide:
///   - importFromUrl(url) startar process
///   - scrapedRecipe håller resultat
///   - saveRecipe() sparar till Firebase
///   - Sparar sourceUrl automatiskt
///
/// Dependencies IN:
///   - RecipeScraper (web scraping)
///   - RecipeService (spara)
/// Dependencies OUT:
///   - Scraped recipe data
///   - Loading/error states
///
/// Data flow:
///   URL → HTTP GET → Parse HTML → Extract data → Recipe
///
/// Common issues:
///   - Site structure changes
///   - Anti-scraping measures
///   - Encoding issues (UTF-8)
///
/// Test coverage: 40% (externa beroenden)
/// Performance: ⚠️ 1-5s beroende på site
/// Analytics: N/A
///
/// Code smells:
///   - ⚠️ Hardkodade CSS selectors
///   - ⚠️ Borde cache parsed structures
///
/// Connected to: url_import_viewmodel.dart
/// Used in phases: 4
```

#### `utils/route_animations.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: util
/// File: utils/route_animations.dart
/// Purpose: Custom animationer för smidig navigation
///
/// Quick Guide:
///   - slideRoute(page): Slide från höger
///   - fadeRoute(page): Fade in
///   - scaleRoute(page): Scale + fade
///   - Duration: 150-200ms
///
/// Dependencies IN: Flutter animation APIs
/// Dependencies OUT: Route<T> objekt
///
/// Data flow:
///   Navigator.push → Animation → New page
///
/// Common issues:
///   - Kan kännas långsam på äldre enheter
///   - iOS har egen back gesture
///
/// Test coverage: 20% (svårt att testa animationer)
/// Performance: ⚡ 60fps på moderna enheter
/// Analytics: N/A
///
/// Connected to: main.dart, alla navigeringsanrop
/// Used in phases: 9
```

#### `utils/migrate_images.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: util
/// File: utils/migrate_images.dart
/// Purpose: Migration script för imageUrl → images array
///
/// Quick Guide:
///   - ONE TIME USE för Fas 15
///   - migrateAllRecipes(): Kör en gång
///   - Backup först!
///
/// Dependencies IN:
///   - RecipeService
///   - Firebase batch writes
/// Dependencies OUT:
///   - Uppdaterade recept med images[]
///
/// Data flow:
///   Old recipes → Transform → Batch update
///
/// Common issues:
///   - Kör inte två gånger
///   - Kan timeout på många recept
///
/// Test coverage: 0% (one-time script)
/// Performance: ⚠️ O(n) batch writes
/// Analytics: ✅ Loggar migration_completed
///
/// Connected to: recipe_service.dart
/// Used in phases: 15
```

### Core infrastructure
#### `core/injection.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/injection.dart
/// Purpose: Dependency injection setup med get_it
///
/// Quick Guide:
///   - configureDependencies() i main.dart
///   - Singletons: Services (en instans)
///   - Factories: ViewModels (ny per view)
///   - Användning: GetIt.I<Type>() eller sl<Type>()
///
/// Dependencies IN:
///   - get_it package
///   - Alla services och viewmodels
/// Dependencies OUT:
///   - Configured service locator
///
/// Data flow:
///   Register → Resolve → Inject
///
/// Common issues:
///   - Circular dependencies
///   - Forgot to register = crash
///   - Order matters för dependencies
///
/// Test coverage: 100% (kritisk fil)
/// Performance: ⚡ Snabb efter init
/// Analytics: N/A
///
/// Code smells:
///   - ✅ Välorganiserad
///   - ⚠️ Blir lång när appen växer
///
/// Connected to: main.dart, alla services/viewmodels
/// Used in phases: 5
```

#### `core/error/error_handler.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/error/error_handler.dart
/// Purpose: Global error handling och logging
///
/// Quick Guide:
///   - setupErrorHandling() i main()
///   - Fångar uncaught errors
///   - Loggar till konsol + (framtid) Crashlytics
///   - User-friendly error messages
///
/// Dependencies IN:
///   - Logger
///   - (Framtid) Firebase Crashlytics
/// Dependencies OUT:
///   - Error handling för hela appen
///
/// Data flow:
///   Error → Handler → Log → User message
///
/// Common issues:
///   - Vissa Flutter errors fångas inte
///   - Async errors behöver runZonedGuarded
///
/// Test coverage: 60%
/// Performance: ⚡ Minimal overhead
/// Analytics: ❌ Borde logga errors
///
/// Connected to: main.dart, logger.dart
/// Used in phases: 5
```

#### `core/error/failures.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/error/failures.dart
/// Purpose: Typsäkra felklasser för domänen
///
/// Quick Guide:
///   - ServerFailure: Firebase/API fel
///   - NetworkFailure: Ingen internet
///   - CacheFailure: Lokal storage fel
///   - ValidationFailure: Form input fel
///
/// Dependencies IN: Ingen
/// Dependencies OUT: Används av services
///
/// Data flow:
///   Service error → Specific Failure → UI handling
///
/// Common issues:
///   - Glöm inte user-friendly messages
///   - Översätt Firebase errors
///
/// Test coverage: 90%
/// Performance: ⚡ Snabb
/// Analytics: N/A
///
/// Connected to: Alla services, error_handler.dart
/// Used in phases: 5
```

#### `core/extensions/future_extensions.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/extensions/future_extensions.dart
/// Purpose: Hjälp-extensions för async operations
///
/// Quick Guide:
///   - future.withTimeout(duration)
///   - future.withRetry(attempts)
///   - future.ignoreErrors()
///
/// Dependencies IN: Dart async
/// Dependencies OUT: Extended Future functionality
///
/// Data flow:
///   Future → Extension → Enhanced behavior
///
/// Common issues:
///   - Timeout kan vara för kort
///   - Retry utan backoff
///
/// Test coverage: 70%
/// Performance: ⚡ No overhead
/// Analytics: N/A
///
/// Connected to: Alla async operations
/// Used in phases: 5
```

#### `core/utils/logger.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/utils/logger.dart
/// Purpose: Centraliserad loggning med nivåer
///
/// Quick Guide:
///   - logger.d('debug')
///   - logger.i('info')
///   - logger.w('warning')
///   - logger.e('error', error, stackTrace)
///
/// Dependencies IN: logger package
/// Dependencies OUT: Formatted console output
///
/// Data flow:
///   Log call → Format → Console/File
///
/// Common issues:
///   - För mycket logging i release
///   - Sensitive data i logs
///
/// Test coverage: 80%
/// Performance: ⚡ Snabb
/// Analytics: N/A
///
/// Code smells:
///   - ⚠️ Ingen log rotation
///
/// Connected to: Alla services och viewmodels
/// Used in phases: 5
```

#### `core/utils/connectivity_check.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/utils/connectivity_check.dart
/// Purpose: Kontrollera internetanslutning
///
/// Quick Guide:
///   - checkConnectivity(): bool
///   - onConnectivityChanged: Stream
///   - Actual internet test, inte bara WiFi
///
/// Dependencies IN: connectivity_plus
/// Dependencies OUT: Network status
///
/// Data flow:
///   System network → Check → Boolean/Stream
///
/// Common issues:
///   - False positives (WiFi utan internet)
///   - iOS simulator alltid "connected"
///
/// Test coverage: 40% (platform-beroende)
/// Performance: ⚡ Cached result
/// Analytics: N/A
///
/// Connected to: offline_service.dart, offline_indicator.dart
/// Used in phases: 13
```

#### `core/validators/form_validators.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/validators/form_validators.dart
/// Purpose: Återanvändbara formulärvaliderare
///
/// Quick Guide:
///   - validateRequired(value)
///   - validateEmail(value)
///   - validateUrl(value)
///   - validateNumber(value, min, max)
///
/// Dependencies IN: Ingen
/// Dependencies OUT: String? (error message)
///
/// Data flow:
///   Form input → Validator → Error or null
///
/// Common issues:
///   - Email regex för strikt
///   - Svenska error messages
///
/// Test coverage: 95%
/// Performance: ⚡ Snabb
/// Analytics: N/A
///
/// Connected to: Alla formulär-viewmodels
/// Used in phases: 5
```

#### `core/form/form_fields_manager.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/form/form_fields_manager.dart
/// Purpose: Hantera många form controllers
///
/// Quick Guide:
///   - addField(key, controller)
///   - getField(key): controller
///   - disposeAll(): cleanup
///   - values: Map of all values
///
/// Dependencies IN: Flutter forms
/// Dependencies OUT: Managed controllers
///
/// Data flow:
///   Create controllers → Manage → Dispose
///
/// Common issues:
///   - Memory leaks om ej disposed
///   - Key collisions
///
/// Test coverage: 60%
/// Performance: ⚡ Bra
/// Analytics: N/A
///
/// Code smells:
///   - ⚠️ Overengineered för små formulär
///
/// Connected to: recipe_form_viewmodel.dart
/// Used in phases: 5
```

#### `core/cache_config.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: core/cache_config.dart
/// Purpose: Konfiguration för bildcache
///
/// Quick Guide:
///   - maxAge: 30 dagar
///   - maxNrOfCacheObjects: 200
///   - Custom cache key generator
///
/// Dependencies IN: flutter_cache_manager
/// Dependencies OUT: Cache configuration
///
/// Data flow:
///   Config → CacheManager → Cached files
///
/// Common issues:
///   - Cache fylls på gamla enheter
///   - Clear cache vid stora ändringar
///
/// Test coverage: N/A (config only)
/// Performance: ⚡ Improves image load
/// Analytics: N/A
///
/// Connected to: cached_recipe_image.dart
/// Used in phases: 13
```

### Theme & Styling
#### `theme/app_theme.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: theme
/// File: theme/app_theme.dart
/// Purpose: Central design system med Material 3
///
/// Quick Guide:
///   - AppTheme.lightTheme: Ljust tema
///   - AppTheme.darkTheme: (Framtid)
///   - Semantic colors: primary, error, etc
///   - Spacing: 4, 8, 16, 24, 32
///   - Text styles: headline, body, caption
///
/// Dependencies IN: Material 3
/// Dependencies OUT: ThemeData för appen
///
/// Data flow:
///   Theme → MaterialApp → All widgets
///
/// Common issues:
///   - Custom colors behöver dark mode
///   - Text styles glöms i widgets
///
/// Test coverage: N/A (theme data)
/// Performance: ⚡ Statisk
/// Analytics: N/A
///
/// Code smells:
///   - ⚠️ Saknar dark mode (Fas 19)
///
/// Connected to: main.dart, alla UI komponenter
/// Used in phases: 2, 19
```

### Data files
#### `data/dummy_data.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: data
/// File: data/dummy_data.dart
/// Purpose: 10 start-recept för nya användare
///
/// Quick Guide:
///   - getDummyRecipes(): List<Recipe>
///   - Körs vid första app-start
///   - Varierade recept för demo
///
/// Dependencies IN: Recipe model
/// Dependencies OUT: Initial recipe data
///
/// Data flow:
///   First launch → Load dummy → Save to Firebase
///
/// Common issues:
///   - Dupliceras om user loggar ut/in
///
/// Test coverage: N/A (static data)
/// Performance: ⚡ En gång vid start
/// Analytics: ✅ Loggar dummy_data_loaded
///
/// Connected to: recipe_service.dart
/// Used in phases: 3
```

#### `data/archived_recipes.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: data
/// File: data/archived_recipes.dart
/// Purpose: Lokal backup av arkivrecept
///
/// Quick Guide:
///   - 20 detaljerade recept
///   - Fallback om Firebase offline
///   - Kategoriserade för browse
///
/// Dependencies IN: Recipe model
/// Dependencies OUT: Archive recipe list
///
/// Data flow:
///   Local data → Display in archive view
///
/// Common issues:
///   - Synk med Firebase-arkiv
///   - Uppdateringar manuella
///
/// Test coverage: N/A (static data)
/// Performance: ⚡ Instant
/// Analytics: N/A
///
/// Connected to: archive_import_viewmodel.dart
/// Used in phases: 3, 7
```

### Core app files
#### `main.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: main.dart
/// Purpose: App entry point och initialisering
///
/// Quick Guide:
///   - Firebase.initializeApp()
///   - Hive.initFlutter()
///   - configureDependencies()
///   - runApp(MyApp())
///   - Named routes setup
///
/// Dependencies IN:
///   - Alla core dependencies
///   - Firebase config
/// Dependencies OUT:
///   - Kör Flutter app
///
/// Data flow:
///   main() → Init services → Build app → Routes
///
/// Common issues:
///   - Firebase init före andra calls
///   - Async init i main()
///
/// Test coverage: 10% (svårt att testa main)
/// Performance: ⚡ Efter init
/// Analytics: ✅ App launch logged
///
/// Code smells:
///   - ⚠️ Mycket init-logik i main
///
/// Connected to: Alla core services, alla views
/// Used in phases: 1, 5, 6, 13
```

#### `firebase_options.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: core
/// File: firebase_options.dart
/// Purpose: Platform-specifik Firebase config
///
/// Quick Guide:
///   - AUTOGENERERAD - rör ej
///   - DefaultFirebaseOptions.currentPlatform
///   - Innehåller API keys
///
/// Dependencies IN: FlutterFire CLI
/// Dependencies OUT: Firebase configuration
///
/// Data flow:
///   Platform check → Return config → Firebase init
///
/// Common issues:
///   - Olika config per platform
///   - Regenerera vid nya Firebase features
///
/// Test coverage: N/A (generated)
/// Performance: ⚡ Once at startup
/// Analytics: N/A
///
/// Connected to: main.dart
/// Used in phases: 6
```

## 🔧 SUPPORTING SERVICES

### Analytics
#### `services/analytics_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/analytics_service.dart
/// Purpose: Firebase Analytics wrapper
///
/// Quick Guide:
///   - logEvent(name, parameters)
///   - setUserId(id)
///   - setUserProperty(name, value)
///   - Standard events: login, signup, etc
///
/// Dependencies IN: Firebase Analytics
/// Dependencies OUT: Analytics tracking
///
/// Data flow:
///   App events → Analytics → Firebase console
///
/// Common issues:
///   - Events inte synliga direkt
///   - Parameter namn restrictions
///
/// Test coverage: 50% (mock i tests)
/// Performance: ⚡ Async, non-blocking
/// Analytics: ✅ Self-tracking
///
/// Code smells:
///   - ✅ Välstrukturerad
///
/// Connected to: Alla viewmodels som loggar events
/// Used in phases: 14, 22
```

### Search
#### `services/search_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/search_service.dart
/// Purpose: Avancerad sök och filtrering
///
/// Quick Guide:
///   - searchRecipes(list, query, filters)
///   - Fuzzy matching på titel/ingredienser
///   - Filter: tid, typ, betyg
///   - Kombinera flera filter
///
/// Dependencies IN: Fuzzy matching algorithm
/// Dependencies OUT: Filtered recipe list
///
/// Data flow:
///   All recipes → Apply search → Apply filters → Results
///
/// Common issues:
///   - Performance på stora listor
///   - Svenska tecken (åäö) i fuzzy
///
/// Test coverage: 85%
/// Performance: ⚠️ O(n) kan vara långsam
/// Analytics: ✅ Loggar search terms
///
/// Code smells:
///   - ⚠️ Borde indexera för performance
///
/// Connected to: recipe_list_viewmodel.dart
/// Used in phases: 10
```

### Sharing
#### `services/share_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/share_service.dart
/// Purpose: Formatera och dela content
///
/// Quick Guide:
///   - shareRecipe(recipe): Text format
///   - shareShoppingList(items): Checkbox list
///   - shareMenu(menu): Veckoformat
///   - exportRecipesAsJson(): Backup
///
/// Dependencies IN:
///   - share_plus package
///   - RecipeService (för export)
/// Dependencies OUT:
///   - Native share sheet
///
/// Data flow:
///   Data → Format → Share sheet → External app
///
/// Common issues:
///   - Simulator share kan faila
///   - Text truncation i vissa appar
///
/// Test coverage: 60%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Loggar share events
///
/// Connected to: recipe_detail_view.dart, profile_dialog.dart
/// Used in phases: 11
```

### Backup
#### `services/backup_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/backup_service.dart
/// Purpose: Export/import av alla recept
///
/// Quick Guide:
///   - exportAllRecipes(): JSON string
///   - importRecipes(json): Restore
///   - Includes metadata and timestamps
///
/// Dependencies IN:
///   - RecipeService
///   - JSON encoding
/// Dependencies OUT:
///   - Backup data
///
/// Data flow:
///   Recipes → JSON → Share/Save → Import
///
/// Common issues:
///   - Large JSON strings
///   - Version compatibility
///
/// Test coverage: 70%
/// Performance: ⚠️ Slow for many recipes
/// Analytics: ✅ Loggar backup/restore
///
/// Connected to: profile_dialog.dart, share_service.dart
/// Used in phases: 11
```

### Content Detection
#### `services/content_detector_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/content_detector_service.dart
/// Purpose: Identifiera innehållstyp från text
///
/// Quick Guide:
///   - detectContentType(text): URL, Recipe, Text
///   - isRecipeUrl(url): bool
///   - isSocialMediaUrl(url): bool
///
/// Dependencies IN: URL patterns
/// Dependencies OUT: Content type enum
///
/// Data flow:
///   Shared text → Analyze → Route to import
///
/// Common issues:
///   - Nya social media format
///   - False positives
///
/// Test coverage: 75%
/// Performance: ⚡ Regex snabb
/// Analytics: ✅ Loggar detected types
///
/// Connected to: receive_share_view.dart
/// Used in phases: 12
```

### Social Media Extractors
#### `services/social_media_extractor_interface.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/social_media_extractor_interface.dart
/// Purpose: Abstrakt interface för platform-specific extractors
///
/// Quick Guide:
///   - extractRecipe(url): Future<String?>
///   - canHandle(url): bool
///
/// Dependencies IN: Ingen
/// Dependencies OUT: Contract för implementationer
///
/// Data flow:
///   Define contract → Implement per platform
///
/// Test coverage: N/A (interface)
/// Performance: N/A
/// Analytics: N/A
///
/// Connected to: social_media_extractor_mobile/web.dart
/// Used in phases: 12
```

#### `services/social_media_extractor_mobile.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/social_media_extractor_mobile.dart
/// Purpose: Mobil WebView för Instagram-extraktion
///
/// Quick Guide:
///   - Headless WebView för Instagram
///   - Klickar "mer" automatiskt
///   - Extraherar expanderad text
///
/// Dependencies IN:
///   - webview_flutter
///   - JavaScript injection
/// Dependencies OUT:
///   - Extraherad recepttext
///
/// Data flow:
///   URL → WebView → JS injection → Extract → Text
///
/// Common issues:
///   - Instagram ändrar struktur
///   - WebView memory leaks
///
/// Test coverage: 30% (svårt med WebView)
/// Performance: ⚠️ 2-5s för Instagram
/// Analytics: ✅ Loggar extraction success/fail
///
/// Connected to: receive_share_view.dart
/// Used in phases: 12
```

#### `services/social_media_extractor_web.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/social_media_extractor_web.dart
/// Purpose: Web fallback (begränsad pga CORS)
///
/// Quick Guide:
///   - Returnerar error för de flesta URLs
///   - CORS blockerar cross-origin
///
/// Dependencies IN: Ingen
/// Dependencies OUT: Error message
///
/// Data flow:
///   URL → Check CORS → Fail
///
/// Common issues:
///   - Kan inte lösa CORS i browser
///
/// Test coverage: 90%
/// Performance: ⚡ Fail fast
/// Analytics: ✅ Loggar platform limitation
///
/// Connected to: receive_share_view.dart
/// Used in phases: 12
```

#### `services/social_media_extractor.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/social_media_extractor.dart
/// Purpose: Conditional import för rätt platform
///
/// Quick Guide:
///   - Väljer mobile/web automatiskt
///   - Transparent för användaren
///
/// Dependencies IN: Platform detection
/// Dependencies OUT: Platform-specific implementation
///
/// Data flow:
///   Import → Platform check → Correct implementation
///
/// Test coverage: 100%
/// Performance: ⚡ Compile-time
/// Analytics: N/A
///
/// Connected to: receive_share_view.dart
/// Used in phases: 12
```

### Storage & Persistence
#### `services/persistence_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/persistence_service.dart
/// Purpose: Key-value storage för inställningar
///
/// Quick Guide:
///   - getString(key): String?
///   - setString(key, value)
///   - getBool, setBool, etc
///   - clear(): Remove all
///
/// Dependencies IN: shared_preferences
/// Dependencies OUT: Persistent storage
///
/// Data flow:
///   App state → Save → Disk → Load on restart
///
/// Common issues:
///   - Sync mellan enheter saknas
///   - Limited data types
///
/// Test coverage: 80%
/// Performance: ⚡ Cached efter första load
/// Analytics: N/A
///
/// Connected to: Theme settings, onboarding status
/// Used in phases: 19, 21
```

#### `services/storage_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/storage_service.dart
/// Purpose: Firebase Storage för bilder
///
/// Quick Guide:
///   - uploadImage(file): Future<String> url
///   - deleteImage(url)
///   - Komprimering innan upload
///   - Genererar unika filnamn
///
/// Dependencies IN:
///   - Firebase Storage
///   - image_picker
/// Dependencies OUT:
///   - Public URLs för bilder
///
/// Data flow:
///   Pick image → Compress → Upload → Get URL
///
/// Common issues:
///   - Stora bilder timeout
///   - iOS memory vid komprimering
///
/// Test coverage: 45%
/// Performance: ⚠️ Upload kan ta tid
/// Analytics: ✅ Loggar upload_success/fail
///
/// Code smells:
///   - ⚠️ Ingen retry vid fail
///
/// Connected to: recipe_form_viewmodel.dart, image_picker_service.dart
/// Used in phases: 15
```

#### `services/image_picker_service.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: service
/// File: services/image_picker_service.dart
/// Purpose: Wrapper för image_picker med permissions
///
/// Quick Guide:
///   - pickImage(source): Camera/Gallery
///   - pickMultiple(): För flera bilder
///   - Hanterar permissions automatiskt
///
/// Dependencies IN: image_picker
/// Dependencies OUT: Image files
///
/// Data flow:
///   User choice → Permission → Pick → File
///
/// Common issues:
///   - iOS permission strings i Info.plist
///   - Android cache växer
///
/// Test coverage: 30% (platform-beroende)
/// Performance: ⚡ Native picker
/// Analytics: ✅ Loggar image_picked
///
/// Connected to: photo_import_viewmodel.dart, recipe_form_viewmodel.dart
/// Used in phases: 15
```

## 🗂️ ADMIN SCRIPTS

#### `admin-scripts/archive-updater.js`
```
/// 🔍 AI INFO BLOCK:
/// Component: admin
/// File: admin-scripts/archive-updater.js
/// Purpose: Node.js script för att uppdatera receptarkivet
///
/// Quick Guide:
///   - npm install först
///   - node archive-updater.js
///   - Läser recipes.json
///   - Uppdaterar butlery_archive
///
/// Dependencies IN:
///   - firebase-admin
///   - service-account.json
/// Dependencies OUT:
///   - Uppdaterat Firebase arkiv
///
/// Data flow:
///   Local JSON → Parse → Batch write → Firestore
///
/// Common issues:
///   - Service account permissions
///   - Batch size limits (500)
///
/// Test coverage: 0% (admin tool)
/// Performance: ⚠️ Beror på antal recept
/// Analytics: Console logs only
///
/// Code smells:
///   - ⚠️ Hardkodade paths
///
/// Connected to: Firebase butlery_archive collection
/// Used in phases: 7
```

#### `admin-scripts/package.json`
```
/// 🔍 AI INFO BLOCK:
/// Component: admin
/// File: admin-scripts/package.json
/// Purpose: NPM dependencies för admin tools
///
/// Quick Guide:
///   - firebase-admin: ^11.0.0
///   - npm install för att installera
///
/// Dependencies IN: NPM
/// Dependencies OUT: Node modules
///
/// Test coverage: N/A
/// Performance: N/A
/// Analytics: N/A
///
/// Connected to: archive-updater.js
/// Used in phases: 7
```

## 🔄 SAMMANFATTNING AV DATAFLÖDEN

### Huvudflöden genom appen:
1. **Skapa recept**: View → ViewModel → RecipeService → Firestore/Hive
2. **Lista recept**: Firestore → Stream → ViewModel → View
3. **Offline sync**: Change → Queue → Network → Batch sync
4. **Import recept**: External source → Parse → Preview → Save
5. **Delning**: Format data → Share sheet → External app

### State management flöde:
```
User Action → ViewModel Method → Service Call → State Update 
    ↓                                               ↓
    View rebuilds ← ChangeNotifier.notify() ← New State
```

### Offline/Online flöde:
```
Online: View → ViewModel → Service → Firestore → Stream update
Offline: View → ViewModel → Service → Hive → Queue → Later sync
``` Scraper → Parse HTML → Recipe model → Save
///
/// Common issues:
///   - CORS errors på web
///   - Vissa siter blockerar scraping
///   - Struktur varierar mycket
///
/// Test coverage: 50% (svårt med externa URLs)
/// Performance: ⚠️ Beror på site (1-5s)
/// Analytics: ✅ Loggar import_from_url
///
/// Code smells:
///   - ⚠️ Hardkodade selectors för vissa siter
///
/// Connected to: import_via_url_view.dart, recipe_scraper.dart
/// Used in phases: 4, 8
```

#### `views/import_via_url_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/import_via_url_view.dart
/// Purpose: UI för URL-import med förhandsvisning
///
/// Quick Guide:
///   - TextField för URL
///   - Import button
///   - Preview av scrapat recept
///   - Edit innan save
///
/// Dependencies IN:
///   - UrlImportViewModel (scraping logic)
/// Dependencies OUT:
///   - Navigerar till fran_sociala_medier med data
///
/// Common issues:
///   - URL validation glöms
///   - Loading kan ta lång tid
///
/// Test coverage: 30%
/// Performance: UI snabb, scraping långsam
/// Analytics: Via ViewModel
///
/// Connected to: url_import_viewmodel.dart, fran_sociala_medier_view.dart
/// Used in phases: 4, 8
```

### Import från text
#### `viewmodels/text_import_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/text_import_viewmodel.dart
/// Purpose: Parsar recept från fritext med intelligent tolkning
///
/// Quick Guide:
///   - parseText(text) analyserar input
///   - Intelligent detection av ingredienser/instruktioner
///   - parsedRecipe håller resultat
///   - Inkluderar sourceUrl om given
///
/// Dependencies IN:
///   - TextUtils (parsing helpers)
///   - RecipeService (save)
/// Dependencies OUT:
///   - Parsed recipe från text
///
/// Data flow:
///   Free text → Smart parsing → Recipe model → Save
///
/// Common issues:
///   - Svårt skilja ingredienser/instruktioner
///   - Enheter på svenska/engelska mix
///
/// Test coverage: 65%
/// Performance: ⚡ Snabb (< 100ms)
/// Analytics: ✅ Loggar text_import_success
///
/// Code smells:
///   - ⚠️ Regex-helvete för parsing
///   - ⚠️ Borde använda NLP
///
/// Connected to: fran_sociala_medier_view.dart, text_utils.dart
/// Used in phases: 4, 8
```

#### `views/fran_sociala_medier_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/fran_sociala_medier_view.dart
/// Purpose: Textimport från kopierad text (social media etc)
///
/// Quick Guide:
///   - Large TextField för paste
///   - Parse button
///   - Visar tolkat recept
///   - Kan redigera innan save
///
/// Dependencies IN:
///   - TextImportViewModel (parsing)
///   - Tar sourceUrl som route arg
/// Dependencies OUT:
///   - Skapar recept med sourceUrl
///
/// Data flow:
///   Paste text → Parse → Preview → Edit → Save
///
/// Common issues:
///   - Långa texter scrollar konstigt
///   - Parse missar ibland struktur
///
/// Test coverage: 25%
/// Performance: ⚡ Snabb
/// Analytics: Via ViewModel
///
/// Connected to: text_import_viewmodel.dart, lagg_till_recept_view.dart
/// Used in phases: 4, 8
```

### Import från arkiv
#### `viewmodels/archive_import_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/archive_import_viewmodel.dart
/// Purpose: Importerar från Butlerys centrala receptarkiv
///
/// Quick Guide:
///   - loadArchiveRecipes() hämtar från Firebase
///   - filterByCategory(category) filtrerar
///   - importRecipe(recipe) kopierar till user
///   - Sätter "Från Butlerys arkiv" som source
///
/// Dependencies IN:
///   - Firebase (butlery_archive collection)
///   - RecipeService (för import)
/// Dependencies OUT:
///   - Lista med arkivrecept
///   - Kategorier
///
/// Data flow:
///   Firebase archive → Filter → Preview → Import to user
///
/// Common issues:
///   - Arkivet kan vara tomt
///   - Network latency vid första load
///
/// Test coverage: 55%
/// Performance: ⚡ Bra (Firebase cached)
/// Analytics: ✅ Loggar archive_import
///
/// Connected to: importera_fran_arkiv_view.dart, recipe_service.dart
/// Used in phases: 7
```

#### `views/importera_fran_arkiv_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/importera_fran_arkiv_view.dart
/// Purpose: Bläddra och importera från receptarkivet
///
/// Quick Guide:
///   - Kategori-filter överst
///   - Grid/List view av recept
///   - Tap för preview
///   - Import button
///
/// Dependencies IN:
///   - ArchiveImportViewModel (arkivdata)
/// Dependencies OUT:
///   - Importerar till användarens recept
///
/// Data flow:
///   Load archive → Browse → Select → Import
///
/// Common issues:
///   - Bilder kan vara stora
///   - Many items = scroll performance
///
/// Test coverage: 30%
/// Performance: ⚡ OK (bilder kan lagga)
/// Analytics: Via ViewModel
///
/// Connected to: archive_import_viewmodel.dart, lagg_till_recept_view.dart
/// Used in phases: 7
```

### Import från foto
#### `viewmodels/photo_import_viewmodel.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: viewmodel
/// File: viewmodels/photo_import_viewmodel.dart
/// Purpose: Förbereder för bildimport (OCR kommer i framtiden)
///
/// Quick Guide:
///   - pickImage(fromCamera: bool) väljer bild
///   - selectedImage håller vald bild
///   - Future: OCR-funktionalitet
///
/// Dependencies IN:
///   - ImagePickerService (bildval)
/// Dependencies OUT:
///   - Vald bild för vidare process
///
/// Data flow:
///   Camera/Gallery → Image → (Future: OCR) → Recipe
///
/// Common issues:
///   - Permissions på iOS
///   - Stora bilder kraschar
///
/// Test coverage: 40%
/// Performance: ⚡ Snabb (ingen processing än)
/// Analytics: ❌ Väntar på implementation
///
/// Code smells:
///   - ⚠️ Placeholder för OCR
///
/// Connected to: photo_import_view.dart, image_picker_service.dart
/// Used in phases: 15
```

#### `views/photo_import_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/photo_import_view.dart
/// Purpose: Val mellan kamera/galleri för framtida OCR
///
/// Quick Guide:
///   - Två stora knappar: Kamera/Galleri
///   - Visar vald bild
///   - Placeholder för OCR UI
///
/// Dependencies IN:
///   - PhotoImportViewModel (bildhantering)
/// Dependencies OUT:
///   - (Framtid) Navigerar till text import
///
/// Data flow:
///   Select source → Pick image → (Future: OCR)
///
/// Common issues:
///   - UI känns tom utan OCR
///
/// Test coverage: 20%
/// Performance: ⚡ Snabb
/// Analytics: Kommer med OCR
///
/// Connected to: photo_import_viewmodel.dart, lagg_till_recept_view.dart
/// Used in phases: 15
```

### Receive share
#### `views/receive_share_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/receive_share_view.dart
/// Purpose: Tar emot delningar från andra appar
///
/// Quick Guide:
///   - Öppnas via Android intent filter
///   - Detekterar content type automatiskt
///   - Dirigerar till rätt import-vy
///   - Hanterar Instagram/TikTok länkar
///
/// Dependencies IN:
///   - ContentDetectorService (typ-detection)
///   - SocialMediaExtractor (Instagram etc)
/// Dependencies OUT:
///   - Navigerar till lämplig import-vy
///
/// Data flow:
///   Share intent → Detect type → Extract → Route
///
/// Common issues:
///   - Instagram kräver WebView
///   - CORS på web platform
///
/// Test coverage: 45%
/// Performance: ⚠️ Instagram kan vara långsam
/// Analytics: ✅ Loggar share_received
///
/// Connected to: content_detector_service.dart, social_media_extractor.dart
/// Used in phases: 12
```

### Val av importmetod
#### `views/lagg_till_recept_view.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: view
/// File: views/lagg_till_recept_view.dart
/// Purpose: Hub för alla sätt att lägga till recept
///
/// Quick Guide:
///   - Grid med import-alternativ
///   - Ikoner och beskrivningar
///   - Navigerar till specifik import
///
/// Dependencies IN:
///   - Ingen (ren navigation)
/// Dependencies OUT:
///   - Routes till alla import-views
///
/// Data flow:
///   User selection → Navigate to specific import
///
/// Common issues:
///   - Grid overflow på små skärmar
///
/// Test coverage: 25%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Loggar import_method_selected
///
/// Connected to: Alla import-views, mina_recept_view.dart
/// Used in phases: 4
```

## 🎨 UI-KOMPONENTER

### Widgets
#### `widgets/recipe_card.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/recipe_card.dart
/// Purpose: Kort för recept i listor med bild och metadata
///
/// Quick Guide:
///   - Input: Recipe objekt
///   - Visar: Bild, titel, tid, betyg
///   - Badges: sourceUrl-ikon, "tillagad idag"
///   - Tap: Navigerar till detaljer
///
/// Dependencies IN:
///   - Recipe model
///   - CachedRecipeImage
/// Dependencies OUT:
///   - Navigator.push till recipe_detail
///
/// Data flow:
///   Recipe data → Visual representation → Tap handling
///
/// Common issues:
///   - Långa titlar overflow
///   - Bilder olika aspect ratio
///
/// Test coverage: 60%
/// Performance: ⚡ Optimized med const
/// Analytics: ❌ (handled i detail view)
///
/// Code smells:
///   - ✅ Välstrukturerad widget
///
/// Connected to: recipe_list_viewmodel.dart, cached_recipe_image.dart
/// Used in phases: 3, 8, 10, 14
```

#### `widgets/filter_chips.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/filter_chips.dart
/// Purpose: Interaktiva filter för receptlistan
///
/// Quick Guide:
///   - Shows: Tid, Måltidstyp, Betyg filters
///   - Multi-select möjligt
///   - Callbacks till ViewModel
///
/// Dependencies IN:
///   - Filter enums från SearchService
/// Dependencies OUT:
///   - onFilterChanged callbacks
///
/// Data flow:
///   User tap → Callback → ViewModel → Filtered list
///
/// Common issues:
///   - Chips wrap på små skärmar
///   - Selected state inte obvious
///
/// Test coverage: 50%
/// Performance: ⚡ Snabb
/// Analytics: Via ViewModel
///
/// Connected to: mina_recept_view.dart, recipe_list_viewmodel.dart
/// Used in phases: 10
```

#### `widgets/skeleton_loader.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/skeleton_loader.dart
/// Purpose: Shimmer loading effect för bättre UX
///
/// Quick Guide:
///   - Ersätter spinners
///   - Visar content structure
///   - Smooth animation
///
/// Dependencies IN:
///   - shimmer package
/// Dependencies OUT:
///   - Visual loading state
///
/// Data flow:
///   isLoading true → Show skeleton → Fade to content
///
/// Common issues:
///   - Glöms i nya vyer
///   - Fel höjd ger hopp
///
/// Test coverage: 30%
/// Performance: ⚡ Smooth 60fps
/// Analytics: N/A
///
/// Connected to: mina_recept_view.dart, importera_fran_arkiv_view.dart
/// Used in phases: 9
```

#### `widgets/cached_recipe_image.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/cached_recipe_image.dart
/// Purpose: Intelligent bildcaching för offline
///
/// Quick Guide:
///   - Auto-cache från URL
///   - Placeholder vid laddning
///   - Error fallback
///   - Memory + disk cache
///
/// Dependencies IN:
///   - flutter_cache_manager
///   - CacheConfig
/// Dependencies OUT:
///   - Cached image widget
///
/// Data flow:
///   URL → Check cache → Download if needed → Display
///
/// Common issues:
///   - Cache limit fylls
///   - CORS på web
///
/// Test coverage: 40%
/// Performance: ⚡ Efter första load
/// Analytics: N/A
///
/// Connected to: recipe_card.dart, recipe_detail_view.dart
/// Used in phases: 13
```

#### `widgets/action_button.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/action_button.dart
/// Purpose: Konsistent knapp med loading state
///
/// Quick Guide:
///   - onPressed: async callback
///   - isLoading: bool för spinner
///   - icon: optional leading icon
///   - variants: primary, secondary
///
/// Dependencies IN:
///   - Theme för styling
/// Dependencies OUT:
///   - Standardized button
///
/// Data flow:
///   Tap → Show loading → Await callback → Reset
///
/// Common issues:
///   - Glöm inte disable under loading
///   - Text overflow på små skärmar
///
/// Test coverage: 70%
/// Performance: ⚡ Snabb
/// Analytics: N/A (i callbacks)
///
/// Connected to: Alla formulär och action-views
/// Used in phases: 2, 4
```

#### `widgets/empty_state.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/empty_state.dart
/// Purpose: Vänlig tom-state med action
///
/// Quick Guide:
///   - icon: Visuell representation
///   - title: Huvudmeddelande
///   - message: Förklaring
///   - actionButton: Optional CTA
///
/// Dependencies IN:
///   - Theme för konsistent stil
/// Dependencies OUT:
///   - Empty state UI
///
/// Data flow:
///   No data → Show empty → User taps action
///
/// Common issues:
///   - Glöms i nya list views
///   - För generiska meddelanden
///
/// Test coverage: 80%
/// Performance: ⚡ Statisk
/// Analytics: N/A
///
/// Connected to: Alla list views
/// Used in phases: 5
```

#### `widgets/instruction_editor.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/instruction_editor.dart
/// Purpose: Specialeditor för numrerade instruktioner
///
/// Quick Guide:
///   - Auto-numrering av steg
///   - Reorder med drag
///   - Add/remove steg
///   - Multiline input
///
/// Dependencies IN:
///   - TextEditingController lista
/// Dependencies OUT:
///   - Formatted instructions
///
/// Data flow:
///   User input → Format with numbers → Save as list
///
/// Common issues:
///   - Reorder UX inte obvious
///   - Long text scrolling
///
/// Test coverage: 45%
/// Performance: ⚡ OK (många controllers)
/// Analytics: N/A
///
/// Connected to: recipe_form_viewmodel.dart, edit_recipe_view.dart
/// Used in phases: 4
```

#### `widgets/main_layout_menu.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/main_layout_menu.dart
/// Purpose: App shell med bottom navigation
///
/// Quick Guide:
///   - BottomNavigationBar med 3 tabs
///   - Bevarar state mellan tabs
///   - Profile button i AppBar
///   - Offline indicator
///
/// Dependencies IN:
///   - Current route för active tab
/// Dependencies OUT:
///   - Navigation mellan huvudvyer
///
/// Data flow:
///   Tab tap → Navigate → Update active index
///
/// Common issues:
///   - State loss mellan tabs
///   - Back button behavior
///
/// Test coverage: 50%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Loggar tab_switched
///
/// Connected to: main.dart, alla huvudvyer
/// Used in phases: 1
```

#### `widgets/offline_indicator.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/offline_indicator.dart
/// Purpose: Visar offline-status med sync info
///
/// Quick Guide:
///   - Visas automatiskt offline
///   - Visar pending changes count
///   - Sync progress när online igen
///
/// Dependencies IN:
///   - OfflineService (status)
///   - ConnectivityCheck
/// Dependencies OUT:
///   - Visual offline state
///
/// Data flow:
///   Network state → Show/hide → Sync status
///
/// Common issues:
///   - Flicker vid snabb network change
///
/// Test coverage: 35%
/// Performance: ⚡ Lightweight
/// Analytics: N/A
///
/// Connected to: offline_service.dart, main_layout_menu.dart
/// Used in phases: 13
```

#### `widgets/profile_dialog.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/profile_dialog.dart
/// Purpose: Användarprofil med backup/logout
///
/// Quick Guide:
///   - Visar email
///   - Export/Import JSON
///   - Logout button
///   - Version info
///
/// Dependencies IN:
///   - AuthService (user info)
///   - ShareService (backup)
/// Dependencies OUT:
///   - Logout → Auth view
///   - Export → Share sheet
///
/// Data flow:
///   Show dialog → User action → Service call
///
/// Common issues:
///   - Long email overflow
///   - Import error handling
///
/// Test coverage: 40%
/// Performance: ⚡ Snabb
/// Analytics: ✅ Via services
///
/// Connected to: auth_service.dart, share_service.dart
/// Used in phases: 6, 11
```

#### `widgets/optimized_card.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/optimized_card.dart
/// Purpose: Performance-optimerad Card
///
/// Quick Guide:
///   - Const constructor när möjligt
///   - Undviker onödig rebuild
///   - Drop-in Card replacement
///
/// Dependencies IN:
///   - Flutter Material
/// Dependencies OUT:
///   - Optimized Card widget
///
/// Data flow:
///   Same as Card but optimized
///
/// Common issues:
///   - Ingen, drop-in replacement
///
/// Test coverage: 90%
/// Performance: ⚡⚡ 20% snabbare
/// Analytics: N/A
///
/// Connected to: recipe_card.dart, alla cards
/// Used in phases: 5
```

#### `widgets/search_bar.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: widget
/// File: widgets/search_bar.dart
/// Purpose: Realtidssök med debouncing
///
/// Quick Guide:
///   - onChanged: Debounced callback
///   - clearButton: X när text finns
///   - hintText: Placeholder
///   - autofocus: Optional
///
/// Dependencies IN:
///   - Debouncer utility
/// Dependencies OUT:
///   - Search query string
///
/// Data flow:
///   Type → Debounce 300ms → Callback → Filter
///
/// Common issues:
///   - Keyboard dismiss on scroll
///   - Clear button touch target
///
/// Test coverage: 60%
/// Performance: ⚡ Debounced
/// Analytics: Via ViewModel
///
/// Connected to: recipe_list_viewmodel.dart
/// Used in phases: 10
```

## 🛠️ UTILITIES & HELPERS

### Core utilities
#### `utils/text_utils.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: util
/// File: utils/text_utils.dart
/// Purpose: Text parsing för receptimport
///
/// Quick Guide:
///   - parseIngredients(text): Lista med rader
///   - parseInstructions(text): Numrerade steg
///   - extractTitle(text): Första raden oftast
///   - cleanupText(text): Remove extra whitespace
///
/// Dependencies IN: Ingen
/// Dependencies OUT: Parsed text strukturer
///
/// Data flow:
///   Raw text → Parsing rules → Structured data
///
/// Common issues:
///   - Svenska/engelska mix
///   - Olika numreringsformat
///
/// Test coverage: 75%
/// Performance: ⚡ Snabb regex
/// Analytics: N/A
///
/// Connected to: text_import_viewmodel.dart
/// Used in phases: 4
```

#### `utils/recipe_scraper.dart`
```
/// 🔍 AI INFO BLOCK:
/// Component: util
/// File: utils/recipe_scraper.dart
/// Purpose: Web scraping för receptimport
///
/// Quick Guide:
///   - scrapeRecipe(url): Returns Recipe?
///   - Site-specific parsers
///   - Fallback generic parser
///   - Schema.org support
///
/// Dependencies IN:
///   - http package
///   - html parser
/// Dependencies OUT:
///   - Scraped Recipe objekt
///
/// Data flow:
///   URL →