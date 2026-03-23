# ViewModels Layer

Extend `BaseViewModel` (from `lib/viewmodels/base_viewmodel.dart`) for built-in loading/error state:

```dart
class XxxViewModel extends BaseViewModel {
```

## Rules
- Use `executeAsync<T>()` / `executeAsyncVoid()` for async ops — handles loading/error lifecycle
- Guard async gaps with `if (isDisposed) return` in any method not using `executeAsync`
- Never call `setState()` — that belongs to the view layer
- Business logic belongs in services, not viewmodels — VMs orchestrate, services execute
- When >500 lines: delegate to manager classes in a same-name subdirectory

## State management
- `setLoading(bool)`, `setError(String?)`, `clearError()` — all guard against disposed state
- `notifyListeners()` is overridden to guard disposed state

## Available mixins
- `AsyncOperationMixin` — adds `executeWithRetry()` with exponential backoff
- `ValidationMixin` — field-level `setValidationError()`, `clearValidationError()`, `isValid`

## Testing
- Debounced methods need `fakeAsync` + `async.elapse(Duration(milliseconds: 300))`
- Use production ServiceLocator bridge in `setUpAll`
- `MockUnifiedRecipeService.setRecipeState()` defaults `isInitialized: false` — always pass explicitly
