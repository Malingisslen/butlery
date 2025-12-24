# Commenting Standards

This document defines the gold standard commenting practices for the Butlery codebase.

## Core Principles

1. **WHY not WHAT** - Code shows what; comments explain intent
2. **Self-documenting first** - Good names > good comments
3. **Public API only** - Doc comments for public interfaces
4. **Minimal but meaningful** - Each comment earns its place
5. **English only** - All comments in English

## When to Comment

- Complex algorithms or non-obvious logic
- Business rules that aren't self-evident
- Workarounds with context (why the hack exists)
- Public API contracts (what callers need to know)
- Backward compatibility explanations
- Race condition prevention logic

## When NOT to Comment

- Simple getters/setters with clear names
- Code that restates the next line
- Private methods with descriptive names
- Every parameter in constructors
- Section boundaries (use code organization instead)
- Obvious conditional logic

## Examples

### Bad (remove these)

```dart
/// Recipe title.
String get title => _state.title;

/// Shopping items availability
bool get hasItems => items.isNotEmpty;

// Listen to authentication state changes and update UI accordingly
_authRepository.authStateChanges().listen(...);

// ===== PRIVATE METHODS =====
void _startMonitoring() { ... }
```

### Good (keep these)

```dart
// Backward compatibility: support both legacy and current format
final data = json['butlery_backup'] ?? json['butlery_export'];

// CRITICAL: Cancel uploads FIRST to prevent race condition crashes
await _cancelPendingUploads();
await _saveState();

// Filter out false-positive GMS errors that clutter user experience
if (!e.toString().contains('com.google.android.gms')) { ... }
```

## Comment Markers

Use sparingly when appropriate:

| Marker | Usage |
|--------|-------|
| `// CRITICAL:` | Race conditions, data loss prevention |
| `// HACK:` | Workarounds with explanation |
| `// TODO:` | Future improvements |
| `// FIXME:` | Known issues to address |

## Class-Level Documentation

Maximum 5 lines. Only include:
- What the class does (1 sentence)
- Key responsibilities if not obvious from name
- Important usage notes

```dart
/// Manages recipe form state and coordinates between specialized managers.
/// Uses facade pattern - delegates to ImageManager, PermissionManager, etc.
class RecipeFormViewModel extends ChangeNotifier { ... }
```

## Method Documentation

Only document public methods that:
- Have non-obvious behavior
- Have important preconditions or side effects
- Are part of a public API

Skip documentation for:
- Simple getters/setters
- Private methods with descriptive names
- Methods where the signature tells the story

## Language

All comments must be in English. This includes:
- Doc comments (`///`)
- Inline comments (`//`)
- TODO/FIXME markers
- Error messages in comments
