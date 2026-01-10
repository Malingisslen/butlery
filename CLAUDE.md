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
- ⚠️ **33 files intentionally >500 lines** - see `/docs/architecture/ACCEPTED_LARGE_FILES.md` for list with reasons. Don't refactor these without reviewing the rationale first.

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
See ADRs in `/docs/adr/` for complete architectural decisions.

## Critical Conventions

**Data Sources** (CRITICAL):
- `UserService.currentUserProfile` → complete user data (settings, avatar, social)
- `PermissionService.currentUser` → basic auth/permission checks only
- ❌ Never mix these - causes settings not persisting

**Syntax**:
- Color: `withValues(alpha: 0.8)` not `withOpacity(0.8)` (deprecated)
- Type safety: Use proper models, not Map-based data access

**Responsive Design**:
- Primary pattern: Center + ConstrainedBox with responsive max width
- Content widths: Narrow (500-600px), Medium (700-800px), Wide (900-1200px)

**Commenting**:
- WHY not WHAT - code shows what, comments explain intent
- No doc comments on simple getters/private methods
- No section dividers (`// ===== SECTION =====`)
- All comments in English (UI strings stay Swedish)

**Documentation Files**: Prefer minimal documentation. Code should be self-documenting.
- Before creating any `.md` file, ask: Is this genuinely necessary? Could it go in an existing file?
- Prefer updating existing docs over creating new ones
- Avoid: README files for every directory, V1/V2 versions (update in place), analysis reports that won't be acted upon
- Cleanup mindset: Delete implementation plans once implemented, remove debug docs when resolved

## Infrastructure

**Mixins & Utilities** (REQUIRED in new code):
| Tool | Purpose | Usage |
|------|---------|-------|
| ErrorHandlingMixin | Async error handling, retries | `with ErrorHandlingMixin` or extend BaseService |
| AsyncOperationMixin | Loading/error states | `with StateNotifierMixin, AsyncOperationMixin` |
| BaseService | Pre-flight checks, caching | `extends BaseService` |
| BaseFirebaseRepository | CRUD + audit logging | `extends BaseFirebaseRepository<T>` |
| **SerializationUtils** | Firestore parsing (100% adopted) | `SerializationUtils.safeString(data, 'field')` |
| ValidationUtils | Form validation | `ValidationUtils.validateRequired(value)` |
| Default Extensions | Null-safe defaults | `value.orEmpty()`, `value.hasItems` |

```dart
// Model serialization - ALWAYS use SerializationUtils for fromFirestore
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

See `.claude/skills/code-deduplication-utilities/` for deduplication patterns.

## Feature Status

| Feature | Status |
|---------|--------|
| Social (friends, sharing, comments, ratings, groups) | ✅ Complete |
| GDPR Compliance (Articles 7, 15, 17, 30) | ✅ Phase 1 Complete |
| Responsive Design (10 Tier 1 views) | ✅ Phase 3 Complete |
| Security (PermissionValidationMixin, audit logging) | ✅ Complete |
| FCM Notifications (Cloud Functions) | ✅ Complete |
| SerializationUtils Adoption | ✅ 100% (17 models) |
| ErrorHandlingMixin Adoption | ✅ 100% (all services) |

## Testing

- **Dashboard**: `/docs/testing/TESTING_DASHBOARD.md`
- **Strategy**: Bottom-up (repositories → services → viewmodels → integration)
- **Templates**: `/test/templates/` for test file templates

## CI/CD

- **Analysis**: `/docs/analysis/cicd-analysis/` (8-dimension assessment)
- **Flutter version**: Update `FLUTTER_VERSION` env var in all `.github/workflows/*.yml` files
- **Workflows**: `analyze.yml`, `test.yml`, `build-validation.yml`, `architecture-validation.yml`, `e2e_tests.yml`

## Critical Rules

1. **NEVER BE LAZY** - find root causes, fix properly
2. **500-line limit** - use facade pattern for complex files
3. **Security validation** - PermissionValidationMixin on all repositories
4. **Single data source** - don't mix UserService/PermissionService
5. **Ask before deviating** - from planned todos

## Stop Hook Response

När stop hook blockerar med en `reason`:
- **Fixa problemet OMEDELBART** - fråga INTE användaren
- Om reason nämner "uncommitted" → committa direkt
- Om reason nämner "analyze" → kör analyze och fixa fel
- Om reason nämner "tests" → kör tester och fixa fel
- Försök sedan stoppa igen

## Agent Usage Rules (MANDATORY)

### Tier 1: Always Use (Hook Enforced)

**debugger** - MUST use when encountering ANY:
- Bug reports (BUG-xxx pattern)
- Errors or exceptions
- Test failures
- Unexpected behavior
- "Not working" situations
- Runtime issues

**firebase-backend-security** - MUST use when modifying:
- Any file in lib/repositories/
- Any file containing Firebase, Firestore, or authentication logic
- User data operations

### Tier 2: Quality Gates (Commit Enforced)

When committing, these agents run automatically:
- **code-reviewer** - Reviews all staged .dart changes
- **testing-specialist** - Verifies test coverage for modified lib/ files

### Tier 3: On Request

Available when explicitly requested:
- **uiux-designer** - New views, UI changes, accessibility
- **performance-optimizer** - Performance concerns
- **flutter-developer** - Complex architecture questions
