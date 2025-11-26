# Claude Code Project Configuration

## Commands
- **Analysis**: `flutter analyze`
- **Run**: `flutter run`
- **Tests**: `flutter test test/unit/file_test.dart`
- **Path rule**: Always use forward slashes in test paths ✅

## Architecture

**Pattern**: MVVM + Repository (Views → ViewModels → Services → Repositories → Firebase)

**File Size**: 500 lines max. Use facade pattern for larger files.
- ✅ Exemplary: `recipe_form_viewmodel.dart` - delegates to 6 focused managers

**Service Access**: `ServiceLocator.get<T>()` for all services
```dart
final service = ServiceLocator.get<UnifiedRecipeService>();
```

**DI Modules**: Core, Content, Social, Messaging, Collaboration, Performance, UI
- Constructor injection in DI modules, ServiceLocator in widgets/ViewModels
- ❌ Never use `FirebaseFirestore.instance` directly - inject FirestoreRepository

## Service Layers

Unified services use layered architecture: `.personal`, `.social`, `.realtime`, `.share`
```dart
await recipeService.personal.createRecipe(...);  // User's content
await recipeService.social.shareWithFriends(...);  // Sharing
final stream = recipeService.realtime.watchRecipe(...);  // Live sync
```
See `/docs/architecture/` for complete patterns.

## Critical Conventions

**Data Sources** (CRITICAL):
- `UserService.currentUserProfile` → complete user data (settings, avatar, social)
- `PermissionService.currentUser` → basic auth/permission checks only
- ❌ Never mix these - causes settings not persisting

**Syntax**:
- Color: `withValues(alpha: 0.8)` not `withOpacity(0.8)` (deprecated)
- Type safety: Use proper models, not Map-based data access

**Responsive Design**: See `/docs/RESPONSIVE_DESIGN_GUIDE.md`
- Primary pattern: Center + ConstrainedBox with responsive max width
- Content widths: Narrow (500-600px), Medium (700-800px), Wide (900-1200px)

## Infrastructure

**Mixins & Utilities** (use in new code):
| Tool | Purpose | Usage |
|------|---------|-------|
| ErrorHandlingMixin | Async error handling, retries | `with ErrorHandlingMixin` or extend BaseService |
| AsyncOperationMixin | Loading/error states | `with StateNotifierMixin, AsyncOperationMixin` |
| BaseService | Pre-flight checks, caching | `extends BaseService` |
| BaseFirebaseRepository | CRUD + audit logging | `extends BaseFirebaseRepository<T>` |
| SerializationUtils | Firestore parsing | `SerializationUtils.safeString(data, 'field')` |
| ValidationUtils | Form validation | `ValidationUtils.validateRequired(value)` |
| Default Extensions | Null-safe defaults | `value.orEmpty()`, `value.hasItems` |

```dart
// Model serialization example
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
  );
}
```

See `/docs/architecture/DEDUPLICATION_PATTERNS.md` for full documentation.

## Feature Status

| Feature | Status |
|---------|--------|
| Social (friends, sharing, comments, ratings, groups) | ✅ Complete |
| GDPR Compliance (Articles 7, 15, 17, 30) | ✅ Phase 1 Complete |
| Responsive Design (10 Tier 1 views) | ✅ Phase 3 Complete |
| Security (PermissionValidationMixin, audit logging) | ✅ Complete |
| FCM Notifications | ✅ Complete |

## Testing

- **Guide**: `/docs/testing/TESTING_COMPLETE_GUIDE.md`
- **Dashboard**: `/docs/testing/TESTING_DASHBOARD.md`
- **Strategy**: Bottom-up (repositories → services → viewmodels → integration)

## Critical Rules

1. **NEVER BE LAZY** - find root causes, fix properly
2. **500-line limit** - use facade pattern for complex files
3. **Security validation** - PermissionValidationMixin on all repositories
4. **Single data source** - don't mix UserService/PermissionService
5. **Ask before deviating** - from planned todos
