# Duplicate Logic Analysis

> Generated: 2025-12-27
> Scope: All business logic in lib/

---

## Copy-Pasted Business Logic Patterns

### HIGH PRIORITY - Significant Duplication

| Logic Pattern | Found In | Lines Affected | Impact | Notes |
|--------------|----------|----------------|--------|-------|
| Import ViewModel state management | 7 import ViewModels | ~700 lines | HIGH | 70% shared code across import VMs |
| Extraction service logic | 5+ extraction files | ~400 lines | HIGH | `social_media_extractor.dart` + `extraction/` overlap |
| Account deletion operations | 4 operation modules | ~300 lines | MEDIUM | Over-modularized micro-files |
| Account export operations | 5 export managers | ~400 lines | MEDIUM | Similar pattern to deletion |
| Shared content ViewModel logic | 6 shared content VMs | ~350 lines | MEDIUM | Base class underutilized |
| Permission checking patterns | 3 permission modules | ~200 lines | MEDIUM | Could be single parameterized module |
| Realtime sync coordination | 7+ realtime modules | ~500 lines | MEDIUM | Scattered across unified/ and realtime/ |

### MEDIUM PRIORITY - Partial Duplication

| Logic Pattern | Found In | Lines Affected | Impact | Notes |
|--------------|----------|----------------|--------|-------|
| Recipe operations helpers | `recipe/` + `realtime/` dirs | ~200 lines | MEDIUM | Parallel hierarchies |
| Serialization helpers | Multiple model dirs | ~150 lines | LOW | SerializationUtils exists but some custom code |
| Message operations | 3 messaging operation files | ~250 lines | LOW | Could be 2 files |

---

## Detailed Analysis

### 1. Import ViewModel Duplication (HIGHEST IMPACT)

#### Current State
7 ViewModels handling different import sources:

```
lib/viewmodels/
├── photo_import_viewmodel.dart     # Camera/OCR import
├── archive_import_viewmodel.dart   # Archive restore
├── url_import_viewmodel.dart       # URL parsing
├── text_import_viewmodel.dart      # Manual text entry
├── smart_import_viewmodel.dart     # Unified entry point
├── assisted_import_viewmodel.dart  # Fallback
└── import_base_viewmodel.dart      # Base class
```

#### Shared Logic (~70% overlap)
All import ViewModels share:
```dart
// Common state
bool isLoading = false;
String? errorMessage;
ParsedRecipe? parsedRecipe;
ImportProgress progress;

// Common methods
Future<void> startImport();
void updateProgress(ImportProgress progress);
Future<void> validateAndFinalize();
void handleImportError(Exception e);
void reset();
```

#### What's Different (~30%)
- **PhotoImport**: Camera/gallery selection, OCR processing
- **UrlImport**: URL validation, HTTP fetching
- **ArchiveImport**: Archive listing, batch selection
- **TextImport**: Text parsing, manual correction

#### Proposed Consolidation
```dart
// Single ImportContentViewModel with strategy pattern
class ImportContentViewModel extends ImportBaseViewModel {
  final ImportStrategy strategy;

  factory ImportContentViewModel.photo() => ImportContentViewModel(PhotoImportStrategy());
  factory ImportContentViewModel.url() => ImportContentViewModel(UrlImportStrategy());
  factory ImportContentViewModel.archive() => ImportContentViewModel(ArchiveImportStrategy());
  factory ImportContentViewModel.text() => ImportContentViewModel(TextImportStrategy());
}

abstract class ImportStrategy {
  Future<RawContent> acquireContent();
  Future<ParsedRecipe> parseContent(RawContent content);
}
```

#### Estimated Impact
- **Files**: 7 → 2-3 files
- **Lines saved**: ~500-700
- **Maintenance**: Single codebase for import flow

---

### 2. Extraction Service Fragmentation

#### Current State
Extraction logic scattered across locations:

```
lib/services/
├── social_media_extractor.dart              # TOP-LEVEL (unclear scope)
└── extraction/
    ├── extractors/
    │   ├── instagram_content_extractor.dart
    │   ├── recipe_site_content_extractor.dart
    │   └── social_platform_content_extractor.dart
    ├── platform_detector.dart
    └── site_parsers/
        ├── arla_recipe_parser.dart
        ├── ica_recipe_parser.dart
        ├── koket_recipe_parser.dart
        ├── recept_recipe_parser.dart
        ├── recipe_quality_scorer.dart
        ├── recipe_site_parser.dart
        └── site_parser_registry.dart
```

#### Issues
1. `social_media_extractor.dart` at top level overlaps with `extraction/extractors/`
2. Unclear which file handles what platform
3. No unified extraction facade

#### Proposed Consolidation
```dart
// extraction/extraction_service.dart - Single entry point
class ExtractionService {
  final PlatformDetector _detector;
  final ExtractorRegistry _extractors;

  Future<ExtractedContent> extract(String url) async {
    final platform = await _detector.detect(url);
    final extractor = _extractors.getFor(platform);
    return extractor.extract(url);
  }
}

// Move social_media_extractor.dart INTO extraction/ hierarchy
// Rename to extraction/extractors/social_media_extractor.dart
```

#### Estimated Impact
- **Clarity**: Single extraction entry point
- **Files**: Move 1 file, possibly consolidate 2-3
- **Lines saved**: ~100-200 through deduplication

---

### 3. Account Operations Over-Modularization

#### Current State: Deletion Operations
```
lib/services/account/
├── account_deletion_service.dart           # Orchestrator
└── account_deletion/
    ├── content_deletion_operations.dart    # ~80 lines
    ├── social_deletion_operations.dart     # ~80 lines
    ├── profile_deletion_operations.dart    # ~60 lines
    └── storage_deletion_operations.dart    # ~60 lines
```

#### Current State: Export Operations
```
lib/services/account/
├── data_export_service.dart               # Orchestrator
└── export/
    ├── content_export_manager.dart        # ~100 lines
    ├── social_export_manager.dart         # ~100 lines
    ├── activity_export_manager.dart       # ~80 lines
    ├── compliance_export_manager.dart     # ~60 lines
    └── preferences_export_manager.dart    # ~60 lines
```

#### Issue
9 micro-files that are each only 60-100 lines. This violates the "don't over-modularize" principle.

#### Proposed Consolidation
```dart
// Deletion: 4 files → 2 files
// content_and_social_deletion.dart (content + social)
// profile_and_storage_deletion.dart (profile + storage)

// Export: 5 files → 3 files
// content_and_social_export.dart (content + social)
// activity_and_preferences_export.dart (activity + preferences)
// compliance_export.dart (keep separate - regulatory concern)
```

#### Estimated Impact
- **Files**: 9 → 5 files
- **Lines saved**: ~50-100 (reduced boilerplate)
- **Maintenance**: Fewer files to navigate

---

### 4. Shared Content ViewModel Underutilization

#### Current State
```
lib/viewmodels/shared_content/
├── base_shared_content_viewmodel.dart        # Abstract base
├── shared_recipe_viewmodel.dart              # Recipe-specific
├── shared_menu_viewmodel.dart                # Menu-specific
├── shared_shopping_viewmodel.dart            # Shopping-specific
├── shared_content_coordinator_viewmodel.dart # Master coordinator
└── shared_content_search_viewmodel.dart      # Search (redundant?)
```

#### Issue
- `shared_content_search_viewmodel.dart` appears redundant - search should be in coordinator
- `shared_menu_viewmodel.dart` and `shared_shopping_viewmodel.dart` may only override 2-3 methods

#### Analysis Required
Verify if specialized ViewModels are truly necessary:
- If they override <5 methods: Consider folding into base with type parameter
- If `shared_content_search_viewmodel.dart` is only used by coordinator: Merge

#### Proposed Consolidation
```dart
// Option A: Keep hierarchy but remove search VM
// 6 files → 5 files

// Option B: Parameterize base class
class SharedContentViewModel<T extends BaseSharedContent> extends BaseViewModel {
  // Type-specific behavior via generics + factory methods
}
```

#### Estimated Impact
- **Files**: 6 → 4-5 files
- **Lines saved**: ~100-150
- **Clarity**: Clearer responsibility

---

### 5. Permission Module Duplication

#### Current State
```
lib/services/permissions/
├── recipe_permission_module.dart     # Recipe permissions
├── shopping_permission_module.dart   # Shopping permissions
└── group_permission_module.dart      # Group permissions
```

#### Shared Logic
All modules implement similar patterns:
```dart
Future<bool> canRead(String userId, String resourceId);
Future<bool> canWrite(String userId, String resourceId);
Future<bool> canDelete(String userId, String resourceId);
Future<bool> canShare(String userId, String resourceId);
```

#### Proposed Consolidation
```dart
// Single parameterized module
class ResourcePermissionModule<T extends PermissionedResource> {
  final PermissionRepository _repo;

  Future<bool> canPerform(
    String userId,
    String resourceId,
    PermissionAction action,
  );
}

enum PermissionAction { read, write, delete, share }
```

#### Estimated Impact
- **Files**: 3 → 1-2 files
- **Lines saved**: ~100-150
- **Consistency**: Unified permission API

---

### 6. Realtime Sync Coordination Scatter

#### Current State
Realtime logic scattered across:
```
lib/services/
├── realtime_sync_service.dart              # Top-level service
├── realtime/
│   ├── conflict_resolution_module.dart
│   ├── connection_state_module.dart
│   ├── realtime_menu_module.dart
│   ├── realtime_recipe_module.dart
│   └── resource_parser_module.dart
└── unified/modules/
    ├── realtime_recipe_module.dart         # DUPLICATE NAME?
    └── realtime_menu_module.dart           # DUPLICATE NAME?
```

#### Issue
- Two `realtime_recipe_module.dart` files in different locations?
- Unclear which takes precedence
- Logic split between `realtime/` and `unified/modules/`

#### Investigation Required
Verify if these are truly duplicates or serve different purposes:
- If duplicates: Consolidate to single location
- If different: Rename for clarity

#### Proposed Consolidation
```dart
// All realtime logic under unified/
lib/services/unified/
├── modules/
│   └── realtime/
│       ├── realtime_recipe_module.dart
│       ├── realtime_menu_module.dart
│       ├── conflict_resolution.dart
│       └── connection_state.dart

// Remove top-level realtime_sync_service.dart if redundant
```

---

### 7. Recipe Operations Parallel Hierarchies

#### Current State
```
lib/models/recipe/
├── recipe_operations.dart       # Recipe operations
├── recipe_serialization.dart    # Serialization
└── recipe_factory.dart          # Factory methods

lib/models/realtime/
├── recipe_operations.dart       # SAME NAME - realtime operations
├── recipe_serialization.dart    # SAME NAME - realtime serialization
└── ...
```

#### Issue
Parallel file structures with same names but different contexts:
- `recipe/recipe_operations.dart` - Personal recipe operations
- `realtime/recipe_operations.dart` - Collaborative recipe operations

#### Analysis
This may be intentional separation (personal vs realtime), but naming is confusing.

#### Proposed Resolution
```dart
// Option A: Rename for clarity
lib/models/recipe/
├── personal_recipe_operations.dart
└── personal_recipe_serialization.dart

lib/models/realtime/
├── realtime_recipe_operations.dart
└── realtime_recipe_serialization.dart

// Option B: Consolidate if overlap is high
// Single recipe_operations.dart with mode parameter
```

---

## Infrastructure Already Consolidated (POSITIVE EXAMPLES)

### ErrorHandlingMixin ✅
- **Eliminates**: ~1,400 lines of duplicate error patterns
- **Used by**: 184+ files
- **Status**: Fully adopted

### SerializationUtils ✅
- **Eliminates**: Type conversion errors
- **Used by**: All 17 models (100% adoption)
- **Status**: Complete

### ValidationUtils ✅
- **Eliminates**: ~2,000 lines of validation code
- **Used by**: 321+ files (null checks), 156+ files (format), 67+ files (business rules)
- **Status**: Good adoption, could expand in Views

### StateNotifierMixin ✅
- **Eliminates**: Loading/error state boilerplate
- **Used by**: All ViewModels
- **Status**: Fully adopted

---

## Summary

| Category | Current Files | Proposed Files | Lines Saved |
|----------|---------------|----------------|-------------|
| Import ViewModels | 7 | 2-3 | ~600 |
| Extraction Services | 5+ scattered | Unified hierarchy | ~200 |
| Account Operations | 9 | 5 | ~100 |
| Shared Content VMs | 6 | 4-5 | ~150 |
| Permission Modules | 3 | 1-2 | ~150 |
| Realtime Coordination | 7+ scattered | Unified location | ~100 |
| Recipe Operations | 6 (parallel) | Clarified naming | 0 |
| **TOTAL** | ~43 files | ~20-25 files | ~1,300 lines |

### Priority Order
1. **Import ViewModels** - Highest impact, clear consolidation path
2. **Extraction Services** - Clarity improvement, moderate savings
3. **Account Operations** - Over-modularization fix
4. **Permission Modules** - Pattern consolidation
5. **Shared Content VMs** - Evaluate necessity first
6. **Realtime Coordination** - Needs investigation first
7. **Recipe Operations** - Naming clarification only
