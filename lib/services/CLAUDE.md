# Services Layer

Every service must extend `BaseService` from `lib/core/base/base_service.dart`:

```dart
class XxxService extends BaseService {
  @override
  String get serviceName => 'XxxService';
```

## Rules
- Use `executeServiceOperation()` for all async operations — no manual try/catch
- Override `onInitialize()` for stream subscriptions and cache loading
- Override `onDispose()` to cancel subscriptions and clear caches
- Cross-service dependencies: `ServiceLocator.get<XxxService>()`, not constructor injection (constructor injection is only in DI modules)
- Built-in caching: `getCachedOrExecute('key', () => fetch(), cacheDuration: Duration(minutes: 5))`
- When >500 lines: use facade pattern — delegate to focused sub-services, re-export via `export` directives

## Available mixins
- `UserContextMixin` — adds `getCurrentUserId()`, `executeAsUser()`
- `NotificationMixin` — adds `sendNotification()`, `notifySuccess()`, `notifyError()`
