# Debug Logging Guide

**Last Updated**: October 30, 2025
**Status**: Production Best Practice
**Audience**: All Developers

---

## Overview

This guide establishes best practices for logging and debug output in the Butlery app to prevent production logging issues and maintain clean, professional output.

## The Problem

During the October 2025 audit, we identified:
- **358 print/debugPrint statements** across 65 files
- **Critical issue**: debugPrint statements executing in production code
- **Inconsistent logging**: Mix of print(), debugPrint(), and proper logging

## The Solution

### 1. Use AppLogger for Production Logging ✅ PREFERRED

```dart
import 'package:butlery/core/utils/logger.dart';

// Success messages
AppLogger.success('Recipe created successfully');

// Informational messages
AppLogger.info('Loading user preferences');

// Warnings
AppLogger.warning('Network connection unstable');

// Errors with context
AppLogger.error('Failed to save recipe', error);

// Debug-only messages (automatically excluded from production)
AppLogger.debug('Cache hit ratio: 85%');

// Contextual logging
AppLogger.service('Authentication service initialized');
AppLogger.viewModel('Recipe list updated');
AppLogger.persistence('Data synchronized');
```

**Why AppLogger?**
- Uses `developer.log()` instead of print (production-safe)
- Proper log levels for filtering (700-1000)
- Automatic debug-mode filtering
- Structured output for monitoring tools
- Emoji-based visual identification

### 2. Wrap debugPrint in kDebugMode ⚠️ ACCEPTABLE

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  debugPrint('🔍 Detailed debug trace: $data');
}
```

**When to use:**
- Temporary debugging during development
- Very verbose output not suitable for production logs
- Performance-sensitive code paths

### 3. Avoid print() Entirely ❌ NOT ALLOWED

```dart
// ❌ WRONG - Lint error
print('User logged in: $email');

// ✅ CORRECT
AppLogger.info('User logged in');
```

**Why?**
- `avoid_print` lint rule is enabled
- print() always executes in production
- No log levels or filtering
- Not compatible with monitoring tools

## Migration Status

### Completed ✅
- **main.dart**: Fixed critical production debugPrint
- **shared_menu.dart**: Removed 1 trace, wrapped 4 statements
- **shared_recipe.dart**: Wrapped 2 error logging statements
- **DI modules & bootstrap**: All properly wrapped in kDebugMode
- **E2E test files**: Acceptable for test infrastructure

### Remaining Work
- **~350 debugPrint statements** across service/model/viewmodel files
- Most are already wrapped or in test files
- **Strategy**: Gradual migration to AppLogger during regular development

## Best Practices

### DO ✅
- Use AppLogger for all production-relevant logging
- Wrap debugPrint in `if (kDebugMode)` guards
- Delete unnecessary debug traces before committing
- Use appropriate log levels (success/info/warning/error/debug)
- Include context in error messages
- Remove debug code after fixing bugs

### DON'T ❌
- Use print() statements (lint will error)
- Put debugPrint in production code paths without kDebugMode
- Log sensitive user data (passwords, tokens, PII)
- Over-log (every function call, every state change)
- Use debug logs as a substitute for proper error handling

## Examples by Context

### Service Layer
```dart
class RecipeService extends BaseService {
  Future<Recipe?> getRecipe(String id) async {
    AppLogger.service('Fetching recipe: $id');

    try {
      final recipe = await _repository.getById(id);
      AppLogger.success('Recipe loaded successfully');
      return recipe;
    } catch (e) {
      AppLogger.error('Failed to load recipe', e);
      return null;
    }
  }
}
```

### ViewModel Layer
```dart
class RecipeListViewModel extends ChangeNotifier {
  Future<void> loadRecipes() async {
    AppLogger.viewModel('Loading recipe list');

    if (kDebugMode) {
      debugPrint('🔍 Detailed state: $_internalState');
    }

    try {
      _recipes = await _service.fetchRecipes();
      AppLogger.success('Loaded ${_recipes.length} recipes');
    } catch (e) {
      AppLogger.error('Failed to load recipes', e);
    }

    notifyListeners();
  }
}
```

### Model Layer (Parsing)
```dart
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  try {
    final data = doc.data() as Map<String, dynamic>;
    return Recipe(/* ... */);
  } catch (e) {
    if (kDebugMode) {
      debugPrint('❌ Error parsing Recipe: $e');
    }
    rethrow;
  }
}
```

### Bootstrap/Initialization
```dart
Future<void> initialize() async {
  if (kDebugMode) {
    debugPrint('🔧 Initializing app services...');
  }

  // ... initialization code ...

  AppLogger.success('Application initialized successfully');
}
```

## Pre-Commit Checklist

Before committing code, verify:
- [ ] No unwrapped print() statements (lint will catch this)
- [ ] All debugPrint wrapped in `if (kDebugMode)` or replaced with AppLogger
- [ ] No sensitive data in log messages
- [ ] Temporary debug traces removed
- [ ] Error logging uses AppLogger.error() with context

## Related Documentation

- **AppLogger Implementation**: `/lib/core/utils/logger.dart`
- **Lint Rules**: `/analysis_options.yaml` (line 51: `avoid_print: true`)
- **Audit Report**: October 2025 Production Readiness Audit

---

**Questions?** Contact the Architecture Team or refer to `/lib/core/utils/logger.dart` for AppLogger API documentation.
