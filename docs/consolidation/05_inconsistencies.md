# Inconsistencies Analysis

> Generated: 2025-12-27
> Scope: Places where shared components exist but aren't used consistently

---

## Shared Components Not Used Consistently

### 1. BaseDialog Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `BaseDialog<T>` (522 lines) | ConfirmationDialogs, DestructiveConfirmationDialog | MenuSelectionDialog, ShoppingListSelectionDialog, DraftRecoveryDialog, All Group dialogs |

**Details**:
- `BaseDialog` provides: consistent styling, header/footer, loading states, animations
- Non-adopters implement their own dialog structure
- Inconsistent dialog appearance and behavior

**Recommendation**: Migrate standalone dialogs to extend BaseDialog

---

### 2. BaseActionHandler Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `BaseActionHandler` (386 lines) | Limited adoption | Most view action handlers, RecipeDetailHandler, ChatActionHandler |

**Details**:
- `BaseActionHandler` provides: confirmation dialogs, delete operations, navigation helpers, loading feedback
- Many views implement their own action handling
- Inconsistent confirmation and feedback patterns

**Recommendation**: Audit action handlers in views for BaseActionHandler adoption

---

### 3. BaseService Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `BaseService` (459 lines) | Most major services | Some smaller services, utility services |

**Details**:
- `BaseService` provides: error handling, caching, batch operations, permission checks
- Some services implement standalone patterns
- Inconsistent error handling in edge cases

**Note**: High adoption rate, but verify 100% coverage for new services

---

### 4. FormScaffold Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `FormScaffold` | Some form views | Recipe edit partial, Profile edit partial, Group create partial |

**Details**:
- `FormScaffold` provides: form layout, validation display, save/cancel buttons
- Some forms use custom scaffolds
- Inconsistent form layout and behavior

**Recommendation**: Audit form views for FormScaffold adoption

---

### 5. EmptyStateBuilder Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `EmptyStateBuilder` + `EmptyStateVariant` | Most list views | Some custom empty states in older views |

**Details**:
- `EmptyStateBuilder` provides: variant-based empty state with icon, message, action
- Some views have inline empty state implementations
- Inconsistent empty state appearance

**Recommendation**: Search for inline empty state implementations and migrate

---

### 6. LoadingStateBuilder Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `LoadingStateBuilder` + `LoadingVariant` | Most views | Some custom loading implementations |

**Details**:
- `LoadingStateBuilder` provides: variant-based loading with skeleton, spinner, overlay
- Some views have inline loading implementations
- Minor inconsistency

**Recommendation**: Low priority - mostly adopted

---

### 7. ValidationUtils Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `ValidationUtils` (343 lines) | Services, most ViewModels | Some Views with inline validation, some form widgets |

**Details**:
- `ValidationUtils` provides: null/empty checks, format validation, business rules
- Some views have inline validation logic
- Potential for validation inconsistency

**Recommendation**: Audit form widgets for inline validation

---

### 8. SnackBarUtils Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `SnackBarUtils` (341 lines) | Most views | Some views using ScaffoldMessenger directly |

**Details**:
- `SnackBarUtils` provides: success/error/warning/info snackbars, consistent styling
- Some views call ScaffoldMessenger.of(context) directly
- Inconsistent snackbar appearance and behavior

**Recommendation**: Search for direct ScaffoldMessenger usage and migrate

---

### 9. ContentCard Facade Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `ContentCard` facade | Most content displays | Potential custom cards in some views |

**Details**:
- `ContentCard` provides: type-based card rendering with consistent styling
- ContentCardType enum covers: recipe, menu, shoppingList, friend, imagePreview, textDisplay
- Very high adoption

**Note**: Well-adopted, maintain going forward

---

### 10. SocialFacade Pattern

| Shared Component | Uses It | Could Use It But Doesn't |
|-----------------|---------|-------------------------|
| `SocialFacade` (515 lines) | Social components | Some direct API calls in older code |

**Details**:
- `SocialFacade` provides: avatar, group, invitation, helper methods
- Very high adoption in social components
- Some older code may bypass facade

**Note**: Well-adopted, verify new code uses facade

---

## Naming Inconsistencies

### 1. File Naming

| Pattern | Files Following | Files Not Following |
|---------|----------------|---------------------|
| `*_widget.dart` for widgets | Most widgets | Some use just `*.dart` |
| `*_view.dart` for views | All views | N/A |
| `*_viewmodel.dart` for VMs | All ViewModels | N/A |
| `*_service.dart` for services | Most services | Some use `*_manager.dart` |
| `*_repository.dart` for repos | All repositories | N/A |

**Specific Issues**:
- `comment_item_widget.dart` vs `comment_item_widgets.dart` - plural naming
- `category_widgets.dart` vs `friend_category_widgets.dart` - overlapping names
- `social_media_extractor.dart` vs `social_platform_content_extractor.dart` - similar purpose

---

### 2. Class Naming

| Pattern | Examples Following | Examples Not Following |
|---------|-------------------|------------------------|
| Manager suffix for managers | `RecipeImageManager`, `MenuStateManager` | Some use `Coordinator`, `Handler` |
| Module suffix for DI modules | `CoreModule`, `UIModule` | Consistent |
| Handler suffix for handlers | `RecipeDetailHandler`, `ChatActionHandler` | Some use `Coordinator` |

**Note**: Minor inconsistency, mostly follows conventions.

---

### 3. Directory Structure

| Pattern | Consistent | Inconsistent |
|---------|-----------|--------------|
| Views have component subdirs | `recipe_detail/`, `unified_shopping/` | Some views lack subdirs |
| ViewModels have manager subdirs | `recipe_form/`, `menu/` | Some VMs lack managers |
| Services have module subdirs | `unified/modules/`, `extraction/` | `social_media_extractor.dart` at top level |

**Specific Issues**:
- `social_media_extractor.dart` should be in `extraction/extractors/`
- `realtime_sync_service.dart` at top level but has `realtime/` subdirectory

---

## API Inconsistencies

### 1. Factory Methods

| Pattern | Files Using | Files Not Using |
|---------|-------------|-----------------|
| Named constructors for variants | `Recipe.fromFirestore()` | Some older models use static methods |
| Factory pattern for complex creation | `ImageFactory` | Some create widgets directly |

**Recommendation**: Standardize on factory pattern for complex widget creation

---

### 2. Method Naming

| Pattern | Consistent Usage | Inconsistent Usage |
|---------|-----------------|-------------------|
| `load*()` for data loading | Most services | Some use `fetch*()`, `get*()` |
| `save*()` for persistence | Most services | Some use `persist*()`, `store*()` |
| `delete*()` for removal | Most services | Some use `remove*()` |

**Note**: Minor inconsistency, doesn't affect functionality.

---

### 3. Async Patterns

| Pattern | Files Using | Files Not Using |
|---------|-------------|-----------------|
| `safeExecute()` from ErrorHandlingMixin | Most services | Some use try/catch directly |
| `withLoadingState()` from StateNotifierMixin | Most ViewModels | Some manage state manually |

**Recommendation**: Verify 100% adoption of mixin methods

---

## State Management Inconsistencies

### 1. Loading State

| Pattern | ViewModels Using | ViewModels Not Using |
|---------|-----------------|---------------------|
| `StateNotifierMixin.isLoading` | Most ViewModels | Some custom loading bool |
| `AsyncOperationMixin.withLoadingState()` | Advanced ViewModels | Some manual state management |

**Recommendation**: Audit for custom loading implementations

---

### 2. Error State

| Pattern | ViewModels Using | ViewModels Not Using |
|---------|-----------------|---------------------|
| `StateNotifierMixin.errorMessage` | Most ViewModels | Some custom error handling |
| `ErrorHandlingMixin.safeExecute()` | Services | Some try/catch directly |

**Recommendation**: Audit for custom error implementations

---

## Infrastructure Adoption Gaps

### Underutilized Infrastructure

| Infrastructure | Purpose | Current Adoption | Should Be Used By |
|----------------|---------|------------------|-------------------|
| `BaseActionHandler` | Action handling | ~20% | All view action handlers |
| `RateLimiter` | Rate limiting | Unclear | API-heavy services |
| `CircuitBreaker` | Failure protection | Unclear | External API services |
| `RetryHelper` specialized strategies | Retry with backoff | Some services | All network services |

---

### Well-Adopted Infrastructure

| Infrastructure | Purpose | Adoption |
|----------------|---------|----------|
| `ErrorHandlingMixin` | Error patterns | ~100% services |
| `SerializationUtils` | Data parsing | 100% models |
| `ValidationUtils` | Validation | High in services/VMs |
| `StateNotifierMixin` | State management | ~100% ViewModels |
| `AsyncOperationMixin` | Async operations | Growing adoption |
| `BaseFirebaseRepository` | Repository base | 100% repositories |

---

## Summary Table

| Component | Expected Adoption | Actual Adoption | Gap |
|-----------|-------------------|-----------------|-----|
| `BaseDialog` | All dialogs | ~60% | 40% (6-8 dialogs) |
| `BaseActionHandler` | All action handlers | ~20% | 80% (significant) |
| `BaseService` | All services | ~90% | 10% (minor) |
| `FormScaffold` | All form views | ~70% | 30% (several forms) |
| `EmptyStateBuilder` | All list views | ~90% | 10% (minor) |
| `ValidationUtils` | All validation | ~85% | 15% (some inline) |
| `SnackBarUtils` | All snackbars | ~80% | 20% (some direct calls) |
| `ContentCard` | All content cards | ~95% | 5% (minimal) |
| `SocialFacade` | All social UI | ~95% | 5% (minimal) |

### Priority for Consistency Improvement
1. **BaseActionHandler** - Significant adoption gap
2. **BaseDialog** - Moderate adoption gap
3. **FormScaffold** - Moderate adoption gap
4. **ValidationUtils in views** - Some inline validation
5. **SnackBarUtils** - Some direct ScaffoldMessenger usage
