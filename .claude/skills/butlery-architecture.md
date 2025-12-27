# Butlery Architecture

> Använd denna skill för alla kodändringar i Butlery. Grundläggande arkitekturmönster.

## MVVM + Repository Pattern

```
Views → ViewModels → Services → Repositories → Firebase
```

| Lager | Ansvar | Exempel |
|-------|--------|---------|
| Views | UI, widgets | `recipe_detail_view.dart` |
| ViewModels | State, UI-logik | `RecipeFormViewModel` |
| Services | Affärslogik, orkestrering | `UnifiedRecipeService` |
| Repositories | Data-access, Firebase | `FirebaseRecipeRepository` |

## Service Access

```dart
// ✅ ALLTID ServiceLocator
final service = ServiceLocator.get<UnifiedRecipeService>();

// ❌ ALDRIG direktinstansiering
final service = UnifiedRecipeService(); // FEL
```

## Unified Services - Moduler

Stora services har `.personal`, `.social`, `.realtime` moduler:

```dart
final service = ServiceLocator.get<UnifiedRecipeService>();

await service.personal.createRecipe(...);   // Användarens egna
await service.social.shareWithFriends(...); // Dela med andra
final stream = service.realtime.watchRecipe(...); // Live-sync
```

## Kritiska Regler

### 1. Data Source Rule (KRITISK)

```dart
// ✅ UserService för komplett användardata
final profile = UserService.currentUserProfile;  // Settings, avatar, social

// ✅ PermissionService ENDAST för auth/permission
final canEdit = await PermissionService.canEditRecipe(id);

// ❌ BLANDAR ALDRIG dessa
if (PermissionService.currentUser.settings...) // FEL - settings är i UserService
```

### 2. Firebase Access

```dart
// ✅ Inject FirebaseFirestore
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe> {
  FirebaseRecipeRepository({FirebaseFirestore? firestore, ...})
    : _firestore = firestore ?? FirebaseFirestore.instance;
}

// ❌ ALDRIG direkt instance i repositories
FirebaseFirestore.instance.collection('recipes')... // FEL
```

### 3. 500-raders gräns

- Max 500 rader per fil
- Använd **Facade Pattern** för större filer
- Se `ACCEPTED_LARGE_FILES.md` för undantag

## BaseService Pattern

```dart
class MyService extends BaseService with ErrorHandlingMixin {
  @override
  String get serviceName => 'MyService';

  Future<T> doSomething() => executeServiceOperation(
    () => _actualWork(),
    operationName: 'doSomething',
    requiresAuth: true,
  );
}
```

## BaseFirebaseRepository Pattern

```dart
class FirebaseRecipeRepository extends BaseFirebaseRepository<Recipe>
    with StreamManagementMixin, UserScopedFirebaseRepository<Recipe>
    implements RecipeRepository {

  FirebaseRecipeRepository({
    required AuthRepository authRepository,
    FirebaseAuditRepository? auditRepository,
  }) : super(authRepository: authRepository, auditRepository: auditRepository);

  @override
  String get collectionName => 'recipes';

  @override
  Recipe fromFirestore(DocumentSnapshot doc) => Recipe.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Recipe entity) => entity.toFirestore();
}
```

## Mixin-kombinationer

| Typ | Mixins |
|-----|--------|
| Standard Service | `ErrorHandlingMixin` |
| Firebase Service | `ErrorHandlingMixin, FirebaseServiceMixin` |
| Realtime Service | `ErrorHandlingMixin, StreamManagementMixin` |
| ViewModel | `ChangeNotifier` + `ErrorHandlingMixin` |
| Large ViewModel | `+ ErrorCoordinatorMixin` + manager-delegation |

## ViewModel Pattern

```dart
class RecipeFormViewModel extends ChangeNotifier
    with ErrorHandlingMixin, ErrorCoordinatorMixin {

  // Delegera till managers för stora ViewModels
  late final RecipeFormState _state;
  late final RecipeImageManager _imageManager;
  late final RecipePersistenceManager _persistenceManager;

  RecipeFormState get state => _state;
}
```

## DI Modules (7 st)

```
CoreModule        - Auth, logging, core utilities
ContentModule     - Recipes, menus, shopping
SocialModule      - Friends, groups, sharing
MessagingModule   - Conversations, notifications
CollaborationModule - Realtime, presence
PerformanceModule - Caching, optimization
UIModule          - Widgets, responsive builders
```

## SerializationUtils (100% adoption)

```dart
// ✅ ALLTID för fromFirestore
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeRequiredDateTime(data, 'createdAt'),
    imageUrl: SerializationUtils.safeNullableString(data, 'imageUrl'),
  );
}
```

## Nyckelfilar

- `lib/core/base/base_service.dart` - Service base class
- `lib/repositories/firebase/base_firebase_repository.dart` - Repository base
- `lib/core/di/di_container.dart` - DI container
- `lib/core/providers/application_provider.dart` - ServiceLocator
- `lib/services/unified/unified_recipe_service.dart` - Unified service exempel
- `CLAUDE.md` - Projektregler

## När triggas denna skill?

- Skapar ny service, repository, eller viewmodel
- Modifierar DI-registrering
- Använder ServiceLocator
- Lägger till Firebase-access
- Bygger ut MVVM-strukturen
