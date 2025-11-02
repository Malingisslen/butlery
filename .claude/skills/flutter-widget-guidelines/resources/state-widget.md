# StateWidget Factory

Factory widget providing preset constructors for common UI states - loading, error, empty, and skeleton loaders with Swedish localization.

## Overview

StateWidget provides:
- **Factory Constructors**: Preset states (loading, error, empty)
- **Swedish Localization**: All text in Swedish
- **Preset Variants**: Common empty states (noRecipes, noFriends, etc.)
- **Skeleton Loaders**: Loading placeholders for lists
- **Consistent UX**: Same look/feel across app

**Usage**: Foundation for LoadingStateBuilder and direct use

## Factory Constructors

### StateWidget.loading()

```dart
// Basic loading indicator
StateWidget.loading()

// With custom message
StateWidget.loading(message: 'Laddar recept...')

// Custom indicator
StateWidget.loading(
  message: 'Synkroniserar...',
  indicator: CircularProgressIndicator(
    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
  ),
)
```

**Output**: Centered loading indicator with optional message below

### StateWidget.error()

```dart
// Basic error
StateWidget.error(message: 'Kunde inte ladda data')

// With retry action
StateWidget.error(
  message: 'Nätverksfel',
  onAction: () => retry(),
  actionLabel: 'Försök igen',
)

// Custom icon
StateWidget.error(
  message: 'Permanent fel',
  icon: Icons.warning,
  iconColor: Colors.orange,
)
```

**Output**: Centered error icon, message, and optional action button

### StateWidget.empty()

```dart
// Basic empty state
StateWidget.empty(
  title: 'Inget innehåll',
  message: 'Det finns inget att visa',
)

// With action
StateWidget.empty(
  title: 'Inga recept',
  message: 'Lägg till ditt första recept',
  icon: Icons.receipt_long,
  onAction: () => createRecipe(),
  actionLabel: 'Lägg till recept',
)

// Custom icon and colors
StateWidget.empty(
  title: 'Tom varukorg',
  message: 'Lägg till produkter',
  icon: Icons.shopping_cart,
  iconColor: Colors.grey,
  iconSize: 80,
)
```

**Output**: Centered icon, title, message, and optional action button

## Preset Empty State Variants

Butlery provides preset empty states for common scenarios:

### StateWidget.noRecipes()

```dart
StateWidget.noRecipes(
  onAction: () => Navigator.pushNamed(context, '/recipe/create'),
)
```

**Shows**:
- Icon: Icons.receipt_long
- Title: "Inga recept"
- Message: "Lägg till ditt första recept"
- Action: "Lägg till recept" (if onAction provided)

### StateWidget.noMenus()

```dart
StateWidget.noMenus(
  onAction: () => createMenu(),
)
```

**Shows**:
- Icon: Icons.calendar_today
- Title: "Inga menyer"
- Message: "Skapa din första meny"
- Action: "Skapa meny"

### StateWidget.noShoppingLists()

```dart
StateWidget.noShoppingLists(
  onAction: () => createList(),
)
```

**Shows**:
- Icon: Icons.shopping_bag
- Title: "Inga inköpslistor"
- Message: "Skapa din första inköpslista"
- Action: "Skapa lista"

### StateWidget.noFriends()

```dart
StateWidget.noFriends(
  onAction: () => searchFriends(),
)
```

**Shows**:
- Icon: Icons.people
- Title: "Inga vänner"
- Message: "Sök efter vänner att följa"
- Action: "Sök vänner"

### StateWidget.noFriendRequests()

```dart
StateWidget.noFriendRequests()
```

**Shows**:
- Icon: Icons.person_add
- Title: "Inga vänskapsförfrågningar"
- Message: "Du har inga väntande förfrågningar"

### StateWidget.noComments()

```dart
StateWidget.noComments()
```

**Shows**:
- Icon: Icons.comment
- Title: "Inga kommentarer"
- Message: "Var först att kommentera"

### StateWidget.noNotifications()

```dart
StateWidget.noNotifications()
```

**Shows**:
- Icon: Icons.notifications_none
- Title: "Inga aviseringar"
- Message: "Du har inga nya aviseringar"

### StateWidget.noSearchResults()

```dart
StateWidget.noSearchResults(
  searchQuery: 'pasta',
  onAction: () => clearSearch(),
)
```

**Shows**:
- Icon: Icons.search_off
- Title: "Inga resultat"
- Message: "Inga resultat för 'pasta'"
- Action: "Rensa sökning"

### StateWidget.noContent()

```dart
StateWidget.noContent(
  contentType: 'recept',
)
```

**Shows**:
- Icon: Icons.inbox
- Title: "Inget innehåll"
- Message: "Det finns inga recept att visa"

## Skeleton Loading States

Placeholder widgets shown during loading:

### StateWidget.skeletonRecipeList()

```dart
StateWidget.skeletonRecipeList(itemCount: 5)
```

**Shows**: 5 skeleton recipe cards with animated shimmer effect

### StateWidget.skeletonRecipeCard()

```dart
StateWidget.skeletonRecipeCard()
```

**Shows**: Single skeleton recipe card (image, title, subtitle placeholders)

### StateWidget.skeletonList()

```dart
StateWidget.skeletonList(
  itemCount: 10,
  itemBuilder: (context, index) => SkeletonListTile(),
)
```

**Shows**: Generic skeleton list with custom item builder

### StateWidget.skeletonGrid()

```dart
StateWidget.skeletonGrid(
  itemCount: 6,
  crossAxisCount: 2,
)
```

**Shows**: Skeleton grid layout (for recipe grid view)

## Usage Examples

### In LoadingStateBuilder

```dart
LoadingStateBuilder<List<Recipe>>(
  isLoading: viewModel.isLoading,
  loadingWidget: StateWidget.skeletonRecipeList(itemCount: 5),
  error: viewModel.error,
  onErrorAction: () => viewModel.retry(),
  data: viewModel.recipes,
  emptyState: EmptyStateVariant.noRecipes,
  onEmptyAction: () => createRecipe(),
  builder: (context, recipes) => RecipeList(recipes),
)
```

### Direct Use in Widget

```dart
class EmptyRecipeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mina Recept')),
      body: StateWidget.noRecipes(
        onAction: () {
          Navigator.pushNamed(context, '/recipe/create');
        },
      ),
    );
  }
}
```

### Custom Empty State

```dart
class CustomEmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StateWidget.empty(
      title: 'Ingen aktivitet',
      message: 'Det har inte hänt något än',
      icon: Icons.timeline,
      iconColor: Colors.blue,
      iconSize: 72,
      onAction: () => refresh(),
      actionLabel: 'Uppdatera',
    );
  }
}
```

### Loading with Message

```dart
class LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StateWidget.loading(
        message: 'Synkroniserar recept...',
      ),
    );
  }
}
```

### Error with Retry

```dart
class ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return StateWidget.error(
      message: error,
      onAction: onRetry,
      actionLabel: 'Försök igen',
    );
  }
}
```

## Customization

### Custom Colors

```dart
StateWidget.empty(
  title: 'Anpassat tema',
  icon: Icons.star,
  iconColor: Theme.of(context).primaryColor,
  titleStyle: TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  ),
  messageStyle: TextStyle(
    fontSize: 16,
    color: Colors.black54,
  ),
)
```

### Custom Button Style

```dart
StateWidget.error(
  message: 'Fel uppstod',
  onAction: () => retry(),
  actionLabel: 'Försök igen',
  actionButtonStyle: ElevatedButton.styleFrom(
    backgroundColor: Colors.red,
    foregroundColor: Colors.white,
  ),
)
```

### Custom Icon Size

```dart
StateWidget.empty(
  title: 'Stor ikon',
  icon: Icons.inbox,
  iconSize: 120,  // Default is 64
  iconColor: Colors.grey,
)
```

## Swedish Localization

All preset states use Swedish text:

| State | Swedish Text | English Translation |
|-------|-------------|---------------------|
| Loading | "Laddar..." | Loading... |
| Error action | "Försök igen" | Try again |
| No recipes | "Inga recept" | No recipes |
| No friends | "Inga vänner" | No friends |
| No results | "Inga resultat" | No results |
| No notifications | "Inga aviseringar" | No notifications |
| Add recipe | "Lägg till recept" | Add recipe |
| Create menu | "Skapa meny" | Create menu |
| Search friends | "Sök vänner" | Search friends |

### Overriding Swedish Text

```dart
StateWidget.empty(
  title: 'Custom English Title',  // Override preset Swedish
  message: 'Custom English message',
  onAction: () => action(),
  actionLabel: 'Custom Action',
)
```

## Testing StateWidget

```dart
testWidgets('displays loading state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StateWidget.loading(message: 'Laddar...'),
    ),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
  expect(find.text('Laddar...'), findsOneWidget);
});

testWidgets('displays error with action', (tester) async {
  var actionCalled = false;

  await tester.pumpWidget(
    MaterialApp(
      home: StateWidget.error(
        message: 'Test error',
        onAction: () => actionCalled = true,
      ),
    ),
  );

  expect(find.text('Test error'), findsOneWidget);
  expect(find.text('Försök igen'), findsOneWidget);

  await tester.tap(find.text('Försök igen'));
  expect(actionCalled, isTrue);
});

testWidgets('displays preset empty state', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StateWidget.noRecipes(),
    ),
  );

  expect(find.text('Inga recept'), findsOneWidget);
  expect(find.byIcon(Icons.receipt_long), findsOneWidget);
});

testWidgets('calls action on empty state button', (tester) async {
  var actionCalled = false;

  await tester.pumpWidget(
    MaterialApp(
      home: StateWidget.noRecipes(
        onAction: () => actionCalled = true,
      ),
    ),
  );

  await tester.tap(find.text('Lägg till recept'));
  expect(actionCalled, isTrue);
});
```

## Implementation Details

### StateWidget Structure

```dart
class StateWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final IconData? icon;
  final Color? iconColor;
  final double iconSize;
  final VoidCallback? onAction;
  final String? actionLabel;
  final Widget? customWidget;

  // Factory constructors
  factory StateWidget.loading({String? message}) { ... }
  factory StateWidget.error({required String message, ...}) { ... }
  factory StateWidget.empty({String? title, ...}) { ... }
  factory StateWidget.noRecipes({VoidCallback? onAction}) { ... }
  // ... other factory constructors

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) Icon(icon, size: iconSize, color: iconColor),
            if (title != null) Text(title, style: titleStyle),
            if (message != null) Text(message, style: messageStyle),
            if (onAction != null)
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel ?? 'OK'),
              ),
          ],
        ),
      ),
    );
  }
}
```

## Best Practices

1. **Use Preset States**: Consistent UX across app
2. **Swedish First**: All user-facing text in Swedish
3. **Provide Actions**: Empty/error states should offer next steps
4. **Skeleton Loaders**: Better UX than spinners for lists
5. **Customize Sparingly**: Override only when necessary
6. **Test All States**: Verify loading, error, empty, and data

## Common Use Cases

**Recipe List Empty**:
```dart
StateWidget.noRecipes(onAction: () => createRecipe())
```

**Network Error**:
```dart
StateWidget.error(
  message: 'Nätverksfel. Kontrollera din anslutning.',
  onAction: () => retry(),
)
```

**Search No Results**:
```dart
StateWidget.noSearchResults(
  searchQuery: query,
  onAction: () => clearSearch(),
)
```

**Loading List**:
```dart
StateWidget.skeletonRecipeList(itemCount: 5)
```

**Permission Error**:
```dart
StateWidget.error(
  message: 'Du har inte behörighet att visa detta',
  icon: Icons.lock,
)
```

## Related Resources

- [LoadingStateBuilder](loading-state-builder.md) - Primary usage of StateWidget
- [Widget Composition](widget-composition.md) - Composing state widgets
- [Common Widgets](common-widgets.md) - Other reusable components
