# Navigation & Routing Skill

**Purpose**: Master navigation patterns and routing strategies in Butlery Flutter app

**Domain**: Flutter navigation, named routes, deep linking, navigation guards

**Value**: LOW (standard Flutter patterns, well-documented)

---

## Quick Reference

### Named Routes

```dart
// Navigate to recipe detail
Navigator.pushNamed(
  context,
  '/recipe-detail',
  arguments: {'recipeId': recipe.id},
);

// Navigate and replace
Navigator.pushReplacementNamed(context, '/home');

// Navigate and clear stack
Navigator.pushNamedAndRemoveUntil(
  context,
  '/welcome',
  (route) => false,
);

// Pop back
Navigator.pop(context, result);
```

### Route Arguments

```dart
// Pass arguments
Navigator.pushNamed(
  context,
  '/edit-recipe',
  arguments: {
    'recipe': recipe,
    'mode': 'edit',
  },
);

// Receive arguments
class EditRecipeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>;
    final recipe = args['recipe'] as Recipe;
    final mode = args['mode'] as String;

    return EditRecipeScreen(recipe: recipe, mode: mode);
  }
}
```

---

## Common Routes

### Authentication Flow

```dart
// Login screen
Navigator.pushReplacementNamed(context, '/login');

// After successful login
Navigator.pushReplacementNamed(context, '/home');

// Logout
await authService.signOut();
Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
```

### Recipe Management

```dart
// View recipe
Navigator.pushNamed(context, '/recipe-detail', arguments: {'recipeId': id});

// Edit recipe
Navigator.pushNamed(context, '/edit-recipe', arguments: {'recipe': recipe});

// Create recipe
Navigator.pushNamed(context, '/create-recipe');

// Share recipe
Navigator.pushNamed(context, '/share-recipe', arguments: {'recipe': recipe});
```

### Social Features

```dart
// Friends list
Navigator.pushNamed(context, '/friends');

// Friend requests
Navigator.pushNamed(context, '/friend-requests');

// User profile
Navigator.pushNamed(context, '/profile', arguments: {'userId': userId});

// Chat/messaging
Navigator.pushNamed(context, '/messages', arguments: {'conversationId': id});
```

---

## Deep Linking

### Handle Deep Links

```dart
class DeepLinkService {
  Future<void> handleDeepLink(Uri link) async {
    // Parse URL: butlery://recipe/123
    if (link.pathSegments.first == 'recipe') {
      final recipeId = link.pathSegments[1];

      // Navigate to recipe
      navigatorKey.currentState?.pushNamed(
        '/recipe-detail',
        arguments: {'recipeId': recipeId},
      );
    }

    // Parse URL: butlery://share/menu/456
    if (link.pathSegments.first == 'share' &&
        link.pathSegments[1] == 'menu') {
      final menuId = link.pathSegments[2];

      navigatorKey.currentState?.pushNamed(
        '/shared-menu',
        arguments: {'menuId': menuId, 'source': 'deep-link'},
      );
    }
  }
}
```

### Firebase Dynamic Links

```dart
Future<void> initDynamicLinks() async {
  // Handle initial link (app opened from link)
  final initialLink = await FirebaseDynamicLinks.instance.getInitialLink();
  if (initialLink != null) {
    _handleDeepLink(initialLink.link);
  }

  // Handle links while app is running
  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) {
    _handleDeepLink(dynamicLinkData.link);
  });
}
```

---

## Navigation Guards

### Authentication Guard

```dart
class AuthGuard {
  static Future<bool> canActivate(BuildContext context) async {
    final authService = ServiceLocator.get<AuthService>();

    if (!authService.isAuthenticated) {
      // Redirect to login
      Navigator.pushReplacementNamed(context, '/login');
      return false;
    }

    return true;
  }
}

// Usage in route
class ProtectedView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthGuard.canActivate(context),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!) {
          return LoadingScreen();
        }

        return ActualContent();
      },
    );
  }
}
```

### Permission Guard

```dart
Future<bool> canViewRecipe(String recipeId) async {
  final permissionService = ServiceLocator.get<PermissionService>();
  return await permissionService.canViewRecipe(recipeId);
}

// Usage
class RecipeDetailView extends StatelessWidget {
  final String recipeId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: canViewRecipe(recipeId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoadingScreen();
        if (!snapshot.data!) return PermissionDeniedScreen();

        return RecipeContent(recipeId: recipeId);
      },
    );
  }
}
```

---

## Modal Navigation

### Bottom Sheets

```dart
// Show bottom sheet
void showRecipeActions(Recipe recipe) {
  showModalBottomSheet(
    context: context,
    builder: (_) => RecipeActionsSheet(recipe: recipe),
  );
}

// Bottom sheet widget
class RecipeActionsSheet extends StatelessWidget {
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.edit),
          title: Text('Redigera'),
          onTap: () {
            Navigator.pop(context);  // Close sheet
            Navigator.pushNamed(
              context,
              '/edit-recipe',
              arguments: {'recipe': recipe},
            );
          },
        ),
        ListTile(
          leading: Icon(Icons.share),
          title: Text('Dela'),
          onTap: () {
            Navigator.pop(context);
            _shareRecipe(recipe);
          },
        ),
      ],
    );
  }
}
```

### Dialogs

```dart
// Show confirmation dialog
Future<bool> confirmDelete() async {
  return await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Ta bort recept?'),
      content: Text('Detta går inte att ångra'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Avbryt'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Ta bort'),
        ),
      ],
    ),
  ) ?? false;
}

// Usage
if (await confirmDelete()) {
  await _deleteRecipe();
}
```

---

## Tab Navigation

```dart
class HomeView extends StatefulWidget {
  @override
  _HomeViewState createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    RecipesView(),
    MenusView(),
    ShoppingView(),
    ProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.restaurant),
            label: 'Recept',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Menyer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Handla',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
```

---

## Best Practices

1. **Use named routes** - Easier to manage, testable
2. **Pass typed arguments** - Cast arguments properly
3. **Handle deep links** - Use FirebaseDynamicLinks or uni_links
4. **Guard protected routes** - Check auth/permissions
5. **Clean navigation stack** - Use pushNamedAndRemoveUntil when appropriate
6. **Return values from routes** - Use Navigator.pop(context, result)

---

## Common Patterns

### Navigate with Result

```dart
// Navigate and wait for result
final result = await Navigator.pushNamed(
  context,
  '/select-recipe',
) as Recipe?;

if (result != null) {
  setState(() => _selectedRecipe = result);
}

// Return result
Navigator.pop(context, selectedRecipe);
```

### Conditional Navigation

```dart
Future<void> navigateToRecipe(Recipe recipe) async {
  if (recipe.isCollaborative) {
    // Navigate to collaborative view
    Navigator.pushNamed(
      context,
      '/collaborative-recipe',
      arguments: {'recipeId': recipe.id},
    );
  } else {
    // Navigate to personal view
    Navigator.pushNamed(
      context,
      '/recipe-detail',
      arguments: {'recipeId': recipe.id},
    );
  }
}
```

### Back Button Override

```dart
class MyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Confirm before leaving
        return await confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Edit Recipe')),
        body: EditRecipeForm(),
      ),
    );
  }
}
```

---

## Related Skills

- **dependency-injection-patterns** - Service access in navigation
- **offline-first-patterns** - Handle offline navigation
- **realtime-collaboration** - Navigate to shared content

---

**Status**: ✅ Standard Flutter patterns
**Complexity**: LOW (well-documented framework features)
**Coverage**: Named routes, deep linking, guards, modals
