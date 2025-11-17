# ADR-005: Enforce 500-Line File Size Limit

**Status**: Accepted
**Date**: 2024-Q4 (Retroactive documentation 2025-11-17)
**Deciders**: Core development team
**Technical Story**: Prevent monolithic files, enforce Single Responsibility Principle

---

## Context

As Butlery grew from prototype to production (669 Dart files), we observed:

**Problems with Large Files** (pre-limit):
- **recipe_form_viewmodel.dart**: Originally 1,200+ lines (too complex to maintain)
- **Cognitive Overload**: Developers spend 5-10 minutes understanding large files
- **Merge Conflicts**: Large files = higher conflict probability
- **Testing Difficulty**: 1,200-line file = dozens of test scenarios
- **Single Responsibility Violation**: Large files do too many things
- **Slow IDE Performance**: Large files slow autocomplete and analysis

**What Defines "Too Large"?**
- **Code Smell**: File requires scrolling more than 2-3 screens (600-900 lines)
- **SRP Violation**: File has multiple reasons to change
- **Review Difficulty**: PR reviewers struggle to understand changes
- **Test Complexity**: Unit tests exceed 500 lines themselves

**Goals**:
- **Maintainability**: Files small enough to understand in 5 minutes
- **Single Responsibility**: Each file does ONE thing well
- **Testability**: Small files = focused, simple tests
- **Review Quality**: PR reviewers can thoroughly review changes
- **IDE Performance**: Fast autocomplete and analysis

---

## Decision

**We will enforce a 500-line target for all Dart files, with facade pattern for complex features.**

### Rule

**500-line Target**:
- **Target**: Files should stay under 500 lines
- **Hard Limit**: 700 lines (must refactor if exceeded)
- **Exceptions**: Generated files, test files (different rules apply)

**Facade Pattern for Complex Features**:
When a feature needs >500 lines:
1. Create a **facade file** (< 500 lines) that delegates to focused modules
2. Extract focused **manager modules** (each < 500 lines)
3. Each manager handles ONE aspect of the feature

### Example: RecipeFormViewModel (Exemplary Implementation)

**Before** (1,200 lines - monolithic):
```dart
// lib/viewmodels/recipe_form_viewmodel.dart (1,200 lines)
class RecipeFormViewModel {
  // Image upload logic (400 lines)
  Future<void> uploadImage() { ... }
  void validateImage() { ... }
  void compressImage() { ... }
  void trackUploadProgress() { ... }

  // Form validation (300 lines)
  void validateRecipeForm() { ... }
  void validateIngredients() { ... }
  void validateInstructions() { ... }

  // Auto-save logic (200 lines)
  void autoSaveRecipe() { ... }
  void scheduleAutoSave() { ... }

  // Collaborative editing (300 lines)
  void handleRealtimeUpdates() { ... }
  void resolveConflicts() { ... }
}
```

**After** (250 lines facade + 6 focused managers):
```
lib/viewmodels/recipe_form/
├── recipe_form_viewmodel.dart (250 lines) ← FACADE
├── managers/
│   ├── image_upload_coordinator.dart (448 lines)
│   ├── image_upload_notification_manager.dart (185 lines)
│   ├── image_upload_validator.dart (173 lines)
│   ├── recipe_persistence_manager.dart (431 lines)
│   ├── recipe_auto_save_manager.dart (431 lines)
│   └── recipe_collaborative_manager.dart (365 lines)
```

**Facade** (recipe_form_viewmodel.dart):
```dart
class RecipeFormViewModel extends ChangeNotifier {
  // Focused managers (dependency injection)
  final ImageUploadCoordinator _imageUpload;
  final RecipePersistenceManager _persistence;
  final RecipeAutoSaveManager _autoSave;
  final RecipeCollaborativeManager _collaborative;

  // Facade delegates to managers
  Future<void> uploadImage(File file) =>
      _imageUpload.uploadImage(file);

  Future<void> saveRecipe() =>
      _persistence.saveRecipe();

  void enableAutoSave() =>
      _autoSave.enable();

  void connectCollaboration(String recipeId) =>
      _collaborative.connect(recipeId);
}
```

---

## Alternatives Considered

### 1. **No Limit (Allow Any File Size)**
- ❌ **Rejected**: Leads to 1,000-2,000 line "god classes"
- ❌ Unmaintainable
- ❌ SRP violations throughout codebase
- ❌ Slow IDE performance
- **Verdict**: Results in technical debt

### 2. **300-Line Limit**
- ❌ **Rejected**: Too strict
- ❌ Even simple ViewModels would need splitting
- ❌ Creates excessive file count (1,000+ files)
- ❌ Navigation overhead
- ⚠️ Good for microservices, but overkill for Flutter
- **Verdict**: Over-engineering

### 3. **1,000-Line Limit**
- ❌ **Rejected**: Too permissive
- ❌ Doesn't prevent bloated files
- ❌ Still violates SRP
- ⚠️ Better than no limit, but not enough
- **Verdict**: Not effective enough

### 4. **Cyclomatic Complexity Metric Instead of Lines**
- ❌ **Rejected**: More accurate but harder to enforce
- ❌ Requires static analysis tools
- ❌ Difficult to explain to junior developers
- ⚠️ Theoretically better, but impractical
- **Verdict**: Lines-of-code is simpler proxy metric

### 5. **Class/Function Line Limits (No File Limit)**
- ❌ **Rejected**: File can still be large (100 small methods)
- ❌ Doesn't enforce file-level SRP
- ⚠️ Complementary to file limit, not replacement
- **Verdict**: Should enforce BOTH (we do)

---

## Consequences

### Positive

✅ **Enforces Single Responsibility Principle**:
- Small files naturally do ONE thing
- Easy to name files (clear responsibility)
- Violations become obvious

✅ **Improved Maintainability**:
- Understand file in 5 minutes (vs. 30 minutes for 1,000-line file)
- Easy to locate bugs
- Clear mental model

✅ **Better Code Reviews**:
- Reviewers can thoroughly review small files
- Easier to spot issues
- Faster review cycles

✅ **Easier Testing**:
- Small files = focused tests
- Less mocking required
- Clearer test scenarios

✅ **Faster IDE Performance**:
- Autocomplete responds faster
- Analysis completes quicker
- Less memory usage

✅ **Reduced Merge Conflicts**:
- Smaller files = less conflict probability
- Changes isolated to specific files

✅ **Onboarding Friendly**:
- New developers understand small files quickly
- Clear examples (recipe_form_viewmodel pattern)

✅ **Scalability**:
- Codebase can grow without becoming unmaintainable
- Currently 669 files, all manageable

### Negative

⚠️ **More Files**:
- 500-line limit can create 2-3x more files
- More navigation between files
- **Mitigation**: Clear directory structure
- **Mitigation**: IDE navigation (Cmd+P, Cmd+Click)

⚠️ **Facade Pattern Overhead**:
- Must create facade + managers (vs. single file)
- Additional DI wiring
- **Mitigation**: One-time cost, long-term benefit
- **Mitigation**: Recipe form is exemplary pattern to copy

⚠️ **Risk of Over-Engineering**:
- Simple features might get split unnecessarily
- **Mitigation**: 500 is TARGET, not HARD LIMIT
- **Mitigation**: Use judgment (simple screens can be 600 lines)

⚠️ **Boilerplate for Manager Pattern**:
- Must create manager classes
- DI registration overhead
- **Mitigation**: Accepted trade-off for maintainability

⚠️ **Directory Structure Complexity**:
- Must organize managers in subdirectories
- Example: `lib/viewmodels/recipe_form/managers/`
- **Mitigation**: Clear naming conventions

---

## Implementation Guidelines

### 1. When to Split a File

**Split when**:
- File exceeds 500 lines
- File has multiple responsibilities (violations)
- File is difficult to understand
- File is difficult to test
- PR reviewers request refactoring

**Don't split when**:
- File is 520 lines but cohesive (close to target is OK)
- Splitting would create artificial separation
- File is test file (different rules apply)

### 2. How to Split (Facade Pattern)

**Step 1**: Identify responsibilities
```
RecipeFormViewModel has 5 responsibilities:
1. Image upload (400 lines)
2. Form validation (200 lines)
3. Auto-save (200 lines)
4. Persistence (200 lines)
5. Collaboration (200 lines)
```

**Step 2**: Extract focused managers
```
Create:
- ImageUploadCoordinator (image upload logic)
- RecipeFormValidator (validation logic)
- RecipeAutoSaveManager (auto-save logic)
- RecipePersistenceManager (save/load logic)
- RecipeCollaborativeManager (realtime logic)
```

**Step 3**: Create facade
```dart
class RecipeFormViewModel {
  final ImageUploadCoordinator _upload;
  final RecipePersistenceManager _persistence;
  // ... etc

  // Facade delegates
  Future<void> uploadImage(File file) =>
      _upload.uploadImage(file);
}
```

**Step 4**: Register in DI
```dart
// Register managers
container.registerLazySingleton<ImageUploadCoordinator>(...);
container.registerLazySingleton<RecipePersistenceManager>(...);

// Register facade
container.registerLazySingleton<RecipeFormViewModel>(
  () => RecipeFormViewModel(
    upload: container<ImageUploadCoordinator>(),
    persistence: container<RecipePersistenceManager>(),
  ),
);
```

### 3. Enforcement

**Code Review**:
- PR reviewers flag files >500 lines
- Suggest refactoring strategy
- Reference recipe_form_viewmodel as exemplary pattern

**Static Analysis** (Future):
- Add custom lint rule (file size check)
- CI/CD pipeline fails if files >700 lines

**Documentation**:
- CLAUDE.md documents 500-line target
- This ADR explains rationale and patterns

---

## Exceptions

**Allowed Exceptions**:
1. **Generated Files** (e.g., `*.g.dart`) - no limit
2. **Test Files** - different rules (tests can be verbose)
3. **Migration Files** - temporary, will be deleted
4. **Legacy Files** - refactor opportunistically (when touching file)

**Temporary Exceptions** (with plan to refactor):
- File is 520 lines and cohesive → OK (close to target)
- File is 650 lines → Refactor when next touched
- File is 900 lines → Refactor immediately (hard limit exceeded)

---

## Metrics

**Current Codebase Status** (as of 2025-11-17):
- **669 Dart files**
- **Average file size**: ~220 lines
- **Files >500 lines**: ~12 files (1.8%)
- **Files >700 lines**: ~3 files (0.4%) - need refactoring
- **Largest file**: firebase_ratings_repository.dart (~800 lines) - will refactor

**Exemplary Files** (follow this pattern):
- recipe_form_viewmodel.dart (250 lines facade + 6 managers)
- account_deletion_service.dart (100 lines facade + 4 operation modules)

---

## References

- **Example**: [lib/viewmodels/recipe_form/recipe_form_viewmodel.dart](../../lib/viewmodels/recipe_form/recipe_form_viewmodel.dart)
- **Project Guidelines**: [CLAUDE.md](../../CLAUDE.md#L19-L24)
- **Architecture**: [ADR-001: Use MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md)
- **External**: [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882) (Chapter 10: Classes)
- **External**: [Single Responsibility Principle](https://en.wikipedia.org/wiki/Single_responsibility_principle)

---

## Related ADRs

- [ADR-001: Use MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md) - Architecture that benefits from small files
- [ADR-004: Organize DI into 7 Domain Modules](ADR-004-seven-domain-modules.md) - Modules prevent large registration files
