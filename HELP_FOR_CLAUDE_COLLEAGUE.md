# Help for Claude Code Colleague - DI System & ViewModels

## Issue: DiscoveryDashboardViewModel Not Found in DI

I see you're trying to understand why `ServiceLocator.get<DiscoveryDashboardViewModel>()` is failing. Let me explain the architecture and provide the solution.

## The Modular DI System

Our new dependency injection system has **5 domain modules**:

1. **Core Module** (`lib/core/di/modules/core_module.dart`)
   - Auth, Storage, Analytics, Config services

2. **Content Module** (`lib/core/di/modules/content_module.dart`)
   - Recipe, Menu, Import, Search services

3. **Social Module** (`lib/core/di/modules/social_module.dart`)
   - Friends, Sharing, Comments, Ratings services

4. **Messaging Module** (`lib/core/di/modules/messaging_module.dart`)
   - Direct Messages, Notifications, FCM services

5. **Collaboration Module** (`lib/core/di/modules/collaboration_module.dart`)
   - Real-time, Shopping, Permissions services

## Important: ViewModels Are NOT Registered in DI

**Key Architecture Decision**: ViewModels are NOT registered in the DI container because:

1. **Different Lifecycle** - ViewModels are created per-view instance, not singletons
2. **MVVM Pattern** - Views create their own ViewModel instances
3. **State Management** - Each view manages its own ViewModel lifecycle

## How to Fix DiscoveryDashboardView

### ❌ WRONG - Don't do this:
```dart
class _DiscoveryDashboardViewState extends State<DiscoveryDashboardView> {
  late final DiscoveryDashboardViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    // This will FAIL - ViewModels aren't in DI
    _viewModel = ServiceLocator.get<DiscoveryDashboardViewModel>();
  }
}
```

### ✅ CORRECT - Create ViewModel directly:
```dart
class _DiscoveryDashboardViewState extends State<DiscoveryDashboardView> {
  late final DiscoveryDashboardViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    // Create ViewModel instance directly
    _viewModel = DiscoveryDashboardViewModel();
  }
  
  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
```

## What IS Registered in DI?

Only **SERVICES** and **REPOSITORIES** are registered:

```dart
// ✅ Services are in DI
final recipeService = ServiceLocator.get<UnifiedRecipeService>();
final authService = ServiceLocator.get<AuthService>();
final friendsService = ServiceLocator.get<UnifiedFriendsService>();

// ❌ ViewModels are NOT in DI
// final viewModel = ServiceLocator.get<SomeViewModel>(); // FAILS
```

## ViewModels Get Services from DI

ViewModels themselves use DI to get services:

```dart
class DiscoveryDashboardViewModel extends BaseViewModel {
  // Services are obtained from DI
  final _recipeService = ServiceLocator.get<UnifiedRecipeService>();
  final _friendsService = ServiceLocator.get<UnifiedFriendsService>();
  final _activityService = ServiceLocator.get<ActivityService>();
  
  // ViewModel constructor doesn't need parameters
  DiscoveryDashboardViewModel() {
    // Initialize with services from DI
    _loadDashboardData();
  }
}
```

## Common Pattern in This Codebase

Most views follow this pattern:

```dart
// 1. View creates ViewModel
class SomeView extends StatefulWidget {
  @override
  State<SomeView> createState() => _SomeViewState();
}

class _SomeViewState extends State<SomeView> {
  late final SomeViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    _viewModel = SomeViewModel(); // Direct creation
  }
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: // ... UI widgets
    );
  }
  
  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}

// 2. ViewModel gets services from DI
class SomeViewModel extends BaseViewModel {
  final _service = ServiceLocator.get<SomeService>();
  
  SomeViewModel() {
    // Initialize
  }
}
```

## Quick Reference

### To Access Services (Registered in DI):
```dart
import 'package:butlery/core/providers/application_provider.dart';

final service = ServiceLocator.get<ServiceType>();
```

### To Create ViewModels (NOT in DI):
```dart
final viewModel = MyViewModel(); // Direct instantiation
```

### Service Examples in DI:
- `UnifiedRecipeService`
- `UnifiedFriendsService`
- `UnifiedShoppingService`
- `MessagingService`
- `AuthService`
- `PermissionService`
- `ActivityService`
- `ReactionsService`

### ViewModel Examples (NOT in DI):
- `DiscoveryDashboardViewModel`
- `RecipeListViewModel`
- `FriendsViewModel`
- `ChatViewModel`
- All other ViewModels

## Summary

1. **Services/Repositories** → Registered in DI modules → Use `ServiceLocator.get<T>()`
2. **ViewModels** → NOT in DI → Create directly with `new ViewModel()`
3. **ViewModels use DI** → To get services they need

The DiscoveryDashboardView should create its ViewModel directly, not try to get it from DI. The ViewModel will then use DI to get the services it needs.

Hope this helps! The modular DI system is working great for services, we just need to remember that ViewModels have a different lifecycle pattern.