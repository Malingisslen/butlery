# Dependency Injection Architecture

## Overview

Butlery uses a **modular dependency injection system** built on GetIt service locator. The architecture follows domain-driven design principles with clear separation of concerns.

## Architecture Components

### 1. Domain Modules

The system is organized into 5 domain modules:

```
lib/core/di/modules/
├── core_module.dart        # Authentication, Storage, Analytics
├── content_module.dart     # Recipes, Menus, Import, Search
├── social_module.dart      # Friends, Sharing, Comments
├── messaging_module.dart   # Direct Messages, Notifications
└── collaboration_module.dart # Real-time, Shopping, Permissions
```

### 2. Application Bootstrap

The bootstrap system orchestrates initialization:

```
lib/core/bootstrap/
├── application_bootstrap.dart  # Main orchestrator
└── stages/
    ├── platform_stage.dart    # Flutter setup
    ├── core_stage.dart        # Firebase & core services
    ├── content_stage.dart     # Recipe services
    ├── social_stage.dart      # Social features
    └── messaging_stage.dart   # Messaging setup
```

### 3. Service Provider

Service access is provided through:

```
lib/core/providers/
└── application_provider.dart  # ServiceLocator access
```

## Usage Guide

### Accessing Services

```dart
// Import the provider
import 'package:butlery/core/providers/application_provider.dart';

// Get services
final recipeService = ServiceLocator.get<UnifiedRecipeService>();
final authService = ServiceLocator.get<AuthService>();
```

### Adding New Services

1. **Identify the domain** - Which module does your service belong to?
2. **Add to module** - Register in the appropriate module's `configure` method
3. **Access via ServiceLocator** - Use the standard access pattern

Example:
```dart
// In social_module.dart
class SocialModule extends DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // Add your new service
    container.registerLazySingleton<NewSocialService>(
      () => NewSocialService(),
    );
  }
}
```

### Testing with DI

```dart
// In your test file
setUpAll(() async {
  // Reset container
  DIContainer.reset();
  
  // Configure required modules
  await CoreModule().configure(DIContainer.instance);
  
  // Register mocks
  DIContainer.instance.registerSingleton<AuthService>(
    MockAuthService(),
  );
});
```

## Module Dependencies

### Core Module
- **Depends on**: Nothing (base module)
- **Provides**: Auth, Storage, Analytics, Config
- **Used by**: All other modules

### Content Module
- **Depends on**: Core Module
- **Provides**: Recipe services, Import, Search
- **Used by**: Social, Collaboration

### Social Module
- **Depends on**: Core, Content
- **Provides**: Friends, Sharing, Comments
- **Used by**: Messaging, Collaboration

### Messaging Module
- **Depends on**: Core, Social
- **Provides**: Chat, Notifications, FCM
- **Used by**: Collaboration

### Collaboration Module
- **Depends on**: All modules
- **Provides**: Real-time, Shopping, Permissions
- **Used by**: UI layer

## Best Practices

### 1. Service Registration

✅ **DO:**
- Register services as lazy singletons
- Use interfaces when possible
- Keep registrations in appropriate modules

❌ **DON'T:**
- Register UI components
- Create circular dependencies
- Access DI container directly

### 2. Service Access

✅ **DO:**
```dart
// In ViewModels
class RecipeViewModel {
  final _recipeService = ServiceLocator.get<UnifiedRecipeService>();
}

// In Services
class SocialService {
  final _authService = ServiceLocator.get<AuthService>();
}
```

❌ **DON'T:**
```dart
// Don't use old pattern
final service = sl<Service>(); // ❌ Legacy

// Don't access container directly
GetIt.instance.get<Service>(); // ❌ Use ServiceLocator
```

### 3. Module Organization

✅ **DO:**
- Keep modules focused on single domain
- Document service dependencies
- Test modules independently

❌ **DON'T:**
- Mix unrelated services in modules
- Create mega-modules
- Skip dependency documentation

## Migration from Legacy

The legacy `sl<T>()` pattern has been completely removed. All code now uses:

```dart
ServiceLocator.get<T>()
```

If you encounter any `sl<>` usage, replace it immediately with the new pattern.

## Troubleshooting

### Common Issues

1. **Service not found**
   - Check service is registered in correct module
   - Verify module is initialized in bootstrap
   - Ensure proper import statements

2. **Circular dependency**
   - Review service dependencies
   - Consider using lazy initialization
   - Refactor to break circular reference

3. **Test failures**
   - Reset DI container in setUp
   - Register all required mocks
   - Check module initialization order

### Debug Commands

```dart
// List all registered services
DIContainer.instance.getRegisteredTypes();

// Check if service is registered
DIContainer.instance.isRegistered<ServiceType>();

// Reset container (tests only)
DIContainer.reset();
```

## Architecture Decisions

### Why GetIt?
- Compile-time type safety
- No code generation required
- Excellent performance
- Simple API
- Wide Flutter adoption

### Why Domain Modules?
- Clear separation of concerns
- Independent development
- Easy testing
- Scalable architecture
- Team-friendly structure

### Why ServiceLocator wrapper?
- Consistent access pattern
- Easy to mock in tests
- Future migration path
- Additional functionality

## Future Considerations

### Potential Enhancements
1. **Scoped injection** - For request-scoped services
2. **Module lazy loading** - Load modules on demand
3. **Service health checks** - Monitor service status
4. **Dependency graph visualization** - Auto-generate diagrams

### Migration Path
If moving away from GetIt in future:
1. All access goes through ServiceLocator
2. Only need to change implementation
3. No changes to service code
4. Minimal migration effort