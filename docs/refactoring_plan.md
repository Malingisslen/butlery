# Butlery Flutter App - Comprehensive Refactoring Plan

## Overview
This plan addresses all 200+ violations identified across the codebase. Follow phases sequentially as later phases depend on earlier work.

---

## PHASE 1: REMOVE AI INFO blocks (Week 1)

### Objective
Remove individual AI INFO blocks

### Implementation Steps

#### Step 1: Remove Existing AI INFO Blocks
```bash
# Remove all existing AI INFO blocks
find lib -name "*.dart" -exec sed -i '/\/\/\/ 🔍 AI INFO BLOCK:/,/\/\/\/ Used in phases:/d' {} \;
```
---

## PHASE 2: REPOSITORY LAYER IMPLEMENTATION (Week 2-3)

### Objective
Fix all 25+ architecture violations by implementing clean repository pattern.

### Implementation Steps

#### Step 2.1: Create Repository Structure
```bash
# Create repository directories
mkdir -p lib/repositories/{interfaces,firebase,hive,mock}
```

#### Step 2.2: Create Base Repository Interface
Create `lib/repositories/interfaces/repository.dart`:
```dart
abstract class Repository<T> {
  Future<T?> getById(String id);
  Future<List<T>> getAll();
  Future<String> create(T item);
  Future<void> update(T item);
  Future<void> delete(String id);
  Stream<T?> watchById(String id);
  Stream<List<T>> watchAll();
}
```

#### Step 2.3: Create Domain-Specific Repositories

Create these repository interfaces:
1. `lib/repositories/interfaces/recipe_repository.dart`
2. `lib/repositories/interfaces/user_repository.dart`
3. `lib/repositories/interfaces/shopping_repository.dart`
4. `lib/repositories/interfaces/friends_repository.dart`
5. `lib/repositories/interfaces/auth_repository.dart`

#### Step 2.4: Implement Firebase Repositories

For each interface, create Firebase implementation:
```dart
// lib/repositories/firebase/firebase_recipe_repository.dart
class FirebaseRecipeRepository implements RecipeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  
  FirebaseRecipeRepository(this._firestore, this._auth);
  
  // Move ALL Firebase logic from services here
}
```

#### Step 2.5: Update Dependency Injection

Modify `lib/core/injection.dart`:
```dart
// Add repository registrations
sl.registerLazySingleton<RecipeRepository>(
  () => FirebaseRecipeRepository(sl(), sl())
);
// ... register all repositories
```

#### Step 2.6: Refactor Services

For each service with Firebase:
1. Remove `FirebaseFirestore.instance` and `FirebaseAuth.instance`
2. Inject repository via constructor
3. Replace Firebase calls with repository calls

Example transformation:
```dart
// BEFORE
class RecipeService {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> saveRecipe(Recipe recipe) async {
    await _firestore.collection('recipes').add(recipe.toJson());
  }
}

// AFTER
class RecipeService {
  final RecipeRepository _repository;
  
  RecipeService(this._repository);
  
  Future<void> saveRecipe(Recipe recipe) async {
    await _repository.create(recipe);
  }
}
```

---

## PHASE 3: FIX SINGLE RESPONSIBILITY VIOLATIONS (Week 4)

### Objective
Separate concerns in all 15+ files violating SRP.

### Implementation Steps

#### Step 3.1: Fix Model UI Dependencies

**File: `lib/models/permissions/edit_mode.dart`**
1. Remove imports: `flutter/material.dart`, `app_theme.dart`
2. Delete methods: `getColor()`, `icon` getter
3. Create `lib/widgets/permissions/edit_mode_ui_helper.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/models/permissions/edit_mode.dart';

class EditModeUIHelper {
  static Color getColor(EditMode mode, BuildContext context) {
    // Move UI logic here
  }
  
  static IconData getIcon(EditMode mode) {
    // Move icon logic here
  }
}
```

#### Step 3.2: Extract UI from Services

**File: `lib/services/image_picker_service.dart`**
1. Create `lib/widgets/image/image_picker_dialogs.dart`
2. Move all UI methods to new widget file
3. Service should only return:
   - `Future<File?> pickImage(ImageSource source)`
   - `Stream<double> uploadProgress`

#### Step 3.3: Remove Business Logic from Views

**File: `lib/widgets/common/universal_share_dialog.dart`**
1. Create `ShareDialogViewModel`
2. Move service injection to ViewModel
3. Pass ViewModel to widget via constructor

#### Step 3.4: Fix ViewModel UI Dependencies

**File: `lib/viewmodels/menu_viewmodel.dart`**
1. Remove `import 'package:flutter/material.dart'`
2. Replace `Icons.xyz` with enum or string constants
3. Let UI layer map constants to actual icons

#### Step 3.5: Secure API Keys

**File: `lib/viewmodels/photo_import_viewmodel.dart`**
1. Install flutter_dotenv package
2. Create `.env` file (add to .gitignore)
3. Load key: `await dotenv.load(); final key = dotenv.env['OCR_API_KEY'];`

---

## PHASE 4: CENTRALIZE STYLING (Week 5)

### Objective
Replace all 100+ hardcoded values with AppTheme constants.

### Implementation Steps

#### Step 4.1: Expand AppTheme
Add to `lib/theme/app_theme.dart`:
```dart
class AppTheme {
  // Dimensions
  static const double avatarSizeLarge = 80.0;
  static const double avatarSizeMedium = 40.0;
  static const double avatarSizeSmall = 24.0;
  
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing5 = 5.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  
  // Padding
  static const EdgeInsets padding4 = EdgeInsets.all(4.0);
  static const EdgeInsets padding8 = EdgeInsets.all(8.0);
  static const EdgeInsets padding12 = EdgeInsets.all(12.0);
  static const EdgeInsets padding16 = EdgeInsets.all(16.0);
  static const EdgeInsets padding20 = EdgeInsets.all(20.0);
  
  // Text sizes
  static const double textSizeXS = 10.0;
  static const double textSizeSM = 12.0;
  static const double textSizeMD = 14.0;
  static const double textSizeLG = 16.0;
  static const double textSizeXL = 18.0;
  static const double textSizeXXL = 24.0;
  
  // Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  static const Duration snackbarDuration = Duration(seconds: 4);
  
  // Border radius
  static const BorderRadius radiusSM = BorderRadius.all(Radius.circular(4));
  static const BorderRadius radiusMD = BorderRadius.all(Radius.circular(8));
  static const BorderRadius radiusLG = BorderRadius.all(Radius.circular(12));
  static const BorderRadius radiusXL = BorderRadius.all(Radius.circular(20));
  
  // Semantic colors (instead of Colors.xyz)
  static Color get neutralLight => Colors.white;
  static Color get neutralMedium => Colors.grey.shade600;
  static Color get neutralDark => Colors.grey.shade800;
}
```

#### Step 4.2: Global Search and Replace

Run these replacements:
```bash
# Replace common patterns
find lib -name "*.dart" -exec sed -i 's/width: 80/width: AppTheme.avatarSizeLarge/g' {} \;
find lib -name "*.dart" -exec sed -i 's/height: 80/height: AppTheme.avatarSizeLarge/g' {} \;
find lib -name "*.dart" -exec sed -i 's/EdgeInsets\.all(8)/AppTheme.padding8/g' {} \;
find lib -name "*.dart" -exec sed -i 's/EdgeInsets\.all(16)/AppTheme.padding16/g' {} \;
find lib -name "*.dart" -exec sed -i 's/EdgeInsets\.all(20)/AppTheme.padding20/g' {} \;
find lib -name "*.dart" -exec sed -i 's/Colors\.white/AppTheme.neutralLight/g' {} \;
find lib -name "*.dart" -exec sed -i 's/fontSize: 12/fontSize: AppTheme.textSizeSM/g' {} \;
```

#### Step 4.3: Manual Review
Review each file for context-specific replacements that automated search might miss.

---

## PHASE 5: SERVICE CONSOLIDATION (Week 6-7)

### Objective
Merge 4+ duplicate services into unified implementations.

### Implementation Steps

#### Step 5.1: Create Unified Recipe Service

Create `lib/services/unified_recipe_service.dart`:
```dart
class UnifiedRecipeService extends ChangeNotifier {
  final RecipeRepository _repository;
  final AuthRepository _authRepository;
  
  // Feature interfaces
  late final PersonalRecipeOperations personal;
  late final SocialRecipeOperations social;
  late final RealtimeRecipeOperations realtime;
  
  UnifiedRecipeService(this._repository, this._authRepository) {
    personal = PersonalRecipeOperations(this);
    social = SocialRecipeOperations(this);
    realtime = RealtimeRecipeOperations(this);
  }
  
  // Core operations used by all features
  Future<Recipe> createRecipe({
    required RecipeType type,
    required RecipeData data,
  }) async {
    // Unified creation logic
  }
}

// Feature-specific operations
class PersonalRecipeOperations {
  final UnifiedRecipeService _parent;
  PersonalRecipeOperations(this._parent);
  
  // Personal recipe specific methods
}

class SocialRecipeOperations {
  final UnifiedRecipeService _parent;
  SocialRecipeOperations(this._parent);
  
  // Social recipe specific methods
}
```

#### Step 5.2: Migrate ViewModels

Update all ViewModels to use unified service:
```dart
// Update imports
// FROM: import 'package:butlery/services/recipe_service.dart';
// TO: import 'package:butlery/services/unified_recipe_service.dart';

// Update service usage
// FROM: _recipeService.addRecipe(recipe);
// TO: _unifiedRecipeService.personal.addRecipe(recipe);
```

#### Step 5.3: Delete Old Services

After confirming all functionality works:
```bash
# Remove old services
rm lib/services/recipe_service.dart
rm lib/services/social_recipe_service.dart
rm lib/services/realtime_recipe_service.dart
```

---

## PHASE 6: ELIMINATE CODE DUPLICATION PATTERNS (Week 8)

### Objective
Create reusable patterns for the 200+ duplications.

### Implementation Steps

#### Step 6.1: Create Firebase Sync Mixin

Create `lib/mixins/firebase_sync_mixin.dart`:
```dart
mixin FirebaseSyncMixin<T> on ChangeNotifier {
  StreamSubscription<QuerySnapshot>? _subscription;
  Timer? _syncDebounceTimer;
  static const Duration _syncDebounce = Duration(seconds: 2);
  final Set<String> _pendingSyncIds = {};
  
  void scheduleSyncForItem(String itemId) {
    _pendingSyncIds.add(itemId);
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(_syncDebounce, () {
      syncPendingItems();
    });
  }
  
  Future<void> syncPendingItems();
  
  @override
  void dispose() {
    _subscription?.cancel();
    _syncDebounceTimer?.cancel();
    super.dispose();
  }
}
```

Apply to all services with sync pattern.

#### Step 6.2: Create Loading State Handler

Create `lib/widgets/common/loading_state_builder.dart`:
```dart
class LoadingStateBuilder<T> extends StatelessWidget {
  final Future<T>? future;
  final Stream<T>? stream;
  final Widget Function(BuildContext, T) builder;
  final Widget? loading;
  final Widget Function(String error)? errorBuilder;
  final Widget? empty;
  
  @override
  Widget build(BuildContext context) {
    // Unified loading/error/empty handling
  }
}
```

#### Step 6.3: Create Permission Service

Create `lib/services/permission_service.dart`:
```dart
class PermissionService {
  static bool canEdit(String? userId, PermissionEntity entity) {
    if (userId == null) return false;
    return entity.canBeEditedBy(userId);
  }
  
  static Future<bool> checkWithError(
    String? userId, 
    PermissionEntity entity,
    Function(String) onError,
  ) async {
    if (userId == null) {
      onError('Du måste vara inloggad');
      return false;
    }
    if (!entity.canBeEditedBy(userId)) {
      onError('Du har inte behörighet');
      return false;
    }
    return true;
  }
}
```

#### Step 6.4: Create Form Validators

Create `lib/utils/form_validators.dart`:
```dart
class FormValidators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Namnet kan inte vara tomt';
    }
    return null;
  }
  
  static String? validateEmail(String? value) {
    if (value == null || !value.contains('@')) {
      return 'Ogiltig e-postadress';
    }
    return null;
  }
  
  // Add all other validators
}
```

#### Step 6.5: Create Cache Manager

Create `lib/services/cache_manager.dart`:
```dart
class CacheManager<T> {
  final String boxName;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  
  Future<void> save(String key, T item) async {
    try {
      final box = await Hive.openBox<String>(boxName);
      final json = jsonEncode(toJson(item));
      await box.put(key, json);
    } catch (e) {
      AppLogger.error('Cache save error', e);
    }
  }
  
  Future<T?> load(String key) async {
    // Unified loading logic
  }
}
```

---

## PHASE 7: REORGANIZE WIDGET STRUCTURE (Week 9)

### Objective
Break up 5000+ lines across oversized widget files.

### Implementation Steps

#### Step 7.1: Create New Widget Structure
```bash
# Create feature-based widget directories
mkdir -p lib/widgets/{recipe,social,shopping,menu,friends,common}/{display,input,state,layout}
```

#### Step 7.2: Split social_components.dart (2389 lines)

Move widgets to:
- `lib/widgets/social/display/friend_card.dart`
- `lib/widgets/social/display/invitation_tile.dart`
- `lib/widgets/social/input/friend_search.dart`
- `lib/widgets/social/input/invitation_form.dart`
- `lib/widgets/social/state/friends_empty.dart`
- `lib/widgets/social/layout/friends_grid.dart`

#### Step 7.3: Split input_components.dart (1990 lines)

Move widgets to:
- `lib/widgets/common/input/text_fields.dart` (max 300 lines)
- `lib/widgets/common/input/dropdowns.dart` (max 300 lines)
- `lib/widgets/common/input/date_pickers.dart` (max 300 lines)
- `lib/widgets/recipe/input/ingredient_input.dart`
- `lib/widgets/recipe/input/instruction_input.dart`

#### Step 7.4: Split layout_components.dart (2013 lines)

Move widgets to:
- `lib/widgets/common/layout/app_bars.dart`
- `lib/widgets/common/layout/cards.dart`
- `lib/widgets/common/layout/lists.dart`
- `lib/widgets/common/layout/grids.dart`
- `lib/widgets/common/layout/spacers.dart`

#### Step 7.5: Update All Imports

Create import mapping script:
```dart
// tools/update_imports.dart
const importMappings = {
  'social_components.dart': {
    'FriendCard': 'social/display/friend_card.dart',
    'InvitationTile': 'social/display/invitation_tile.dart',
    // ... all mappings
  }
};
```

Run the script to update all imports automatically.

---

## PHASE 8: ADVANCED SRP REFACTORING (Week 10-11)

### Objective
✅ **COMPLETED**: Split 8 files (4,347 lines) into 38 focused components using facade patterns.

### Completed Implementation

#### ✅ Step 8.1: High Priority Files Split
- **archived_recipes.dart** (771→9 lines, 99% reduction)
- **social_components.dart** (761→40 lines, 95% reduction)  
- **social_media_extractor.dart** (611→30 lines, 95% reduction)

#### ✅ Step 8.2: Medium Priority Files Split
- **universal_image_manager.dart** (already refactored)
- **permission_validators.dart** (599→24 lines, 96% reduction)
- **edit_recipe_view.dart** (591→124 lines, 79% reduction)
- **offline_service.dart** (587→200 lines, 66% reduction)

#### ✅ Step 8.3: Architecture Patterns Applied
- **Facade Pattern**: 100% backward compatibility maintained
- **Single Responsibility**: Each component has one clear purpose
- **Focused Modules**: 38 new components with clear boundaries
- **Clean Dependencies**: Proper separation between concerns

### Results Achieved
- **85% average code reduction** in main facade files
- **38 focused components** created with excellent SRP adherence
- **100% backward compatibility** maintained across all splits
- **All compilation errors resolved** and import warnings fixed

---

## PHASE 9: LARGE FILE SRP REFACTORING (Week 12-13)

### Objective
Split the remaining 16 largest files (300+ lines) that violate Single Responsibility Principle.

### Priority Files Identified

#### 🔴 High Priority (800+ lines)
1. **`lib/models/realtime/realtime_menu.dart`** - **960 lines**
   - Split into: Data model + Business logic + Sync manager + Utilities
   - **Issues**: Menu data + participants + Firebase sync + business operations

2. **`lib/services/unified/unified_recipe_service.dart`** - **900 lines**
   - Split into: Personal operations + Social operations + Realtime operations + Cache manager
   - **Issues**: Multiple domain responsibilities in single service

3. **`lib/models/realtime/realtime_recipe.dart`** - **750 lines**
   - Split into: Data model + Collaboration manager + Conflict resolver
   - **Issues**: Recipe data + realtime logic + permission management

#### 🟡 Medium-High Priority (650-750 lines)
4. **`lib/models/unified/unified_recipe.dart`** - **691 lines**
5. **`lib/viewmodels/realtime_menu_viewmodel.dart`** - **690 lines**
6. **`lib/viewmodels/unified_recipe_viewmodel.dart`** - **661 lines**
7. **`lib/widgets/user/user_display_widgets.dart`** - **653 lines**
8. **`lib/viewmodels/shared_content_viewmodel.dart`** - **653 lines**

#### 🟢 Medium Priority (550-650 lines)
9. **`lib/viewmodels/menu_viewmodel.dart`** - **644 lines**
10. **`lib/services/realtime/realtime_menu_service.dart`** - **632 lines**
11. **`lib/core/dialogs/dialog_factory.dart`** - **630 lines**
12. **`lib/services/unified/unified_friends_service.dart`** - **585 lines**
13. **`lib/views/social/collaborative_shopping_view.dart`** - **572 lines**
14. **`lib/widgets/common/content_card.dart`** - **556 lines**
15. **`lib/views/social/user_profile_edit_view.dart`** - **552 lines**
16. **`lib/viewmodels/recipe_form_viewmodel.dart`** - **550 lines**

### Implementation Steps

#### Step 9.1: Split RealtimeMenu Model (960 lines)
```dart
// lib/models/realtime/realtime_menu_data.dart
class RealtimeMenuData {
  // Pure data representation
}

// lib/models/realtime/realtime_menu_operations.dart  
class RealtimeMenuOperations {
  // Business logic operations
}

// lib/models/realtime/realtime_menu_sync.dart
class RealtimeMenuSync {
  // Firebase synchronization
}

// lib/models/realtime/realtime_menu.dart (facade)
class RealtimeMenu {
  // Backward compatible facade
}
```

#### Step 9.2: Split UnifiedRecipeService (900 lines)
```dart
// lib/services/unified/modules/personal_recipe_operations.dart
// lib/services/unified/modules/social_recipe_operations.dart
// lib/services/unified/modules/realtime_recipe_operations.dart
// lib/services/unified/modules/recipe_cache_manager.dart
// lib/services/unified/unified_recipe_service.dart (facade)
```

#### Step 9.3: Split RealtimeRecipe Model (750 lines)
```dart
// lib/models/realtime/realtime_recipe_data.dart
// lib/models/realtime/realtime_recipe_collaboration.dart
// lib/models/realtime/realtime_recipe_conflicts.dart
// lib/models/realtime/realtime_recipe.dart (facade)
```

#### Step 9.4: Continue with Remaining Files
Apply same facade pattern to all 16 identified files, creating focused components while maintaining backward compatibility.

### Expected Results
- **16 large files** split into **80+ focused components**
- **~3,000 lines** of complex code reorganized
- **70% average reduction** in main file sizes
- **Improved maintainability** through clear separation of concerns

---

## PHASE 10: UNIFY DATA MODELS (Week 14)

### Objective
Consolidate 4+ recipe model variants into one unified model.

### Implementation Steps

#### Step 10.1: Create Unified Recipe Model

Create `lib/models/recipe.dart`:
```dart
class Recipe {
  final String id;
  final String title;
  final String? description;
  final List<Ingredient> ingredients;
  final List<String> instructions;
  final RecipeMetadata metadata;
  
  // Feature-specific data
  final SocialData? socialData;
  final RealtimeData? realtimeData;
  final PersonalData? personalData;
}

class RecipeMetadata {
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final RecipeType type;
}

enum RecipeType { personal, shared, collaborative, realtime }
```

#### Step 10.2: Create Model Adapters

Create adapters for migration:
```dart
class RecipeAdapter {
  static Recipe fromLegacy(LegacyRecipe legacy) { }
  static Recipe fromUnified(UnifiedRecipe unified) { }
  static Recipe fromRealtime(RealtimeRecipe realtime) { }
}
```

#### Step 10.3: Update All Services and ViewModels

Systematically update all references to use new unified model.

---

## PHASE 11: FINAL CLEANUP AND VALIDATION (Week 15-16)

### Objective
Ensure all changes work correctly and no regressions.

### Implementation Steps

#### Step 11.1: Create Architecture Validation Script

Create `tools/validate_architecture.dart`:
```dart
void main() async {
  // Check no direct Firebase usage outside repositories
  final violations = await findFirebaseViolations();
  
  // Check no hardcoded values
  final hardcodedValues = await findHardcodedValues();
  
  // Check file sizes
  final oversizedFiles = await findOversizedFiles();
  
  // Generate report
  generateReport(violations, hardcodedValues, oversizedFiles);
}
```

#### Step 11.2: Comprehensive Testing

1. Unit tests for all repositories
2. Integration tests for services
3. Widget tests for UI components
4. E2E tests for critical user flows

#### Step 11.3: Performance Validation

1. Profile app startup time
2. Measure screen transition performance
3. Check memory usage patterns
4. Validate offline sync performance

#### Step 11.4: Documentation Update

Update all documentation:
- README.md with new architecture
- Migration guide for other developers
- API documentation for repositories
- Pattern usage examples

---

## MIGRATION CHECKLIST

- [ ] Phase 1: Central documentation system created
- [ ] Phase 2: All 25+ Firebase violations fixed
- [ ] Phase 3: All 15+ SRP violations resolved
- [ ] Phase 4: All 100+ hardcoded values replaced
- [ ] Phase 5: Services consolidated from 10+ to 4
- [ ] Phase 6: Duplication patterns eliminated
- [ ] Phase 7: Widget files under 500 lines each
- [x] Phase 8: Advanced SRP refactoring completed (8 files → 38 components)
- [ ] Phase 9: Large file SRP refactoring (16 files → 80+ components)
- [ ] Phase 10: Single unified data model
- [ ] Phase 11: All tests passing and performance validated

## SUCCESS METRICS

| Metric | Before | After | Improvement |
|--------|---------|--------|------------|
| Firebase Violations | 25+ | 0 | 100% |
| SRP Violations | 15+ | 0 | 100% |
| Hardcoded Values | 100+ | 0 | 100% |
| Duplicate Services | 10+ | 4 | 60% reduction |
| Oversized Files | 10+ | 0 | 100% |
| Code Duplication | 200+ | <20 | 90% reduction |
| Test Coverage | ~20% | >80% | 300% increase |

## RISK MITIGATION

1. **Feature Flags**: Implement feature flags to toggle between old/new code
2. **Incremental Rollout**: Deploy changes incrementally
3. **Rollback Plan**: Keep old code in separate branch for 30 days
4. **Monitoring**: Add analytics to track any regression
5. **User Communication**: Inform users about improvements

This comprehensive plan will transform the Butlery codebase into a maintainable, testable, and scalable architecture.