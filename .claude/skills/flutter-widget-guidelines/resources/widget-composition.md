# Widget Composition

Guide to composing complex Flutter UIs using the facade pattern, single-responsibility widgets, and effective widget extraction.

## Overview

Widget composition in Butlery follows:
- **Facade Pattern**: Complex widgets split into focused sub-widgets
- **Single Responsibility**: Each widget has one clear purpose
- **< 200 Lines**: Individual widgets stay small and focused
- **Clear Naming**: Widget names describe their content/purpose
- **Reusability**: Extracted widgets can be reused

## Facade Pattern

Break large views into smaller, focused widgets:

```dart
// Main view (facade) - 50 lines
class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RecipeDetailAppBar(recipe: recipe),
      body: SingleChildScrollView(
        child: Column(
          children: [
            RecipeDetailHeader(recipe: recipe),
            RecipeIngredientsList(ingredients: recipe.ingredients),
            RecipeInstructionsList(instructions: recipe.instructions),
            RecipeNutritionalInfo(recipe: recipe),
            RecipeComments(recipeId: recipe.id),
          ],
        ),
      ),
      bottomNavigationBar: RecipeDetailActions(recipe: recipe),
    );
  }
}

// Each sub-widget is 30-100 lines, focused on single responsibility
```

## Widget Extraction Principles

### When to Extract

Extract widgets when:
- **File exceeds 200 lines**: Split into multiple widgets
- **Repeated code**: Create reusable widget
- **Clear boundaries**: Section has distinct purpose
- **Testing**: Need to test component independently
- **Complex logic**: Widget has significant complexity

### When NOT to Extract

Don't extract when:
- **< 50 lines total**: Over-engineering
- **Used once**: No reusability benefit
- **Tightly coupled**: Widget depends heavily on parent state
- **Simple layouts**: Basic Column/Row with few children

## Single-Responsibility Widgets

Each widget should have one clear purpose:

### Header Widget

```dart
class RecipeDetailHeader extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailHeader({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recipe.imageUrl != null)
          RecipeImage(imageUrl: recipe.imageUrl!),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 8),
              RecipeMetadata(recipe: recipe),
            ],
          ),
        ),
      ],
    );
  }
}
```

**Purpose**: Display recipe header (image, title, metadata)

### List Widget

```dart
class RecipeIngredientsList extends StatelessWidget {
  final List<Ingredient> ingredients;

  const RecipeIngredientsList({required this.ingredients});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingredienser',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            ...ingredients.map((ingredient) =>
              IngredientListItem(ingredient: ingredient),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Purpose**: Display list of ingredients

### Actions Widget

```dart
class RecipeDetailActions extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailActions({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(Icons.edit),
              label: Text('Redigera'),
              onPressed: () => _editRecipe(context),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: Icon(Icons.share),
              label: Text('Dela'),
              onPressed: () => _shareRecipe(context),
            ),
          ),
        ],
      ),
    );
  }

  void _editRecipe(BuildContext context) {
    Navigator.pushNamed(context, '/recipe/edit', arguments: recipe);
  }

  void _shareRecipe(BuildContext context) {
    context.read<RecipeViewModel>().shareRecipe(recipe.id);
  }
}
```

**Purpose**: Display action buttons for recipe

## Widget Organization

### File Structure

```
lib/views/
├── recipe_detail_view.dart          (Main facade - 50 lines)
└── recipe_detail/
    ├── recipe_detail_header.dart    (80 lines)
    ├── recipe_detail_appbar.dart    (60 lines)
    ├── recipe_ingredients_list.dart (90 lines)
    ├── recipe_instructions_list.dart (100 lines)
    ├── recipe_nutritional_info.dart (70 lines)
    ├── recipe_comments.dart         (120 lines)
    └── recipe_detail_actions.dart   (50 lines)
```

### Naming Convention

- **Main View**: `<Feature>View` (RecipeDetailView)
- **Sub-widgets**: `<Feature><Component>` (RecipeDetailHeader)
- **Common widgets**: Descriptive name (IngredientListItem)

## Real-World Example: Friends View

### Main Facade (60 lines)

```dart
class FriendsListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<FriendsViewModel>(),
      child: Scaffold(
        appBar: FriendsAppBar(),
        body: Column(
          children: [
            FriendsSearchBar(),
            FriendsCategoryTabs(),
            Expanded(child: FriendsListContent()),
          ],
        ),
        floatingActionButton: AddFriendButton(),
      ),
    );
  }
}
```

### Search Bar Widget (80 lines)

```dart
class FriendsSearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsViewModel>(
      builder: (context, viewModel, _) {
        return Container(
          padding: EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Sök vänner...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () => viewModel.clearSearch(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (query) => viewModel.search(query),
          ),
        );
      },
    );
  }
}
```

### Category Tabs Widget (100 lines)

```dart
class FriendsCategoryTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsViewModel>(
      builder: (context, viewModel, _) {
        return Container(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: viewModel.categories.length,
            itemBuilder: (context, index) {
              final category = viewModel.categories[index];
              final isSelected =
                  viewModel.selectedCategory?.id == category.id;

              return Padding(
                padding: EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(category.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      viewModel.selectCategory(category);
                    } else {
                      viewModel.clearCategory();
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
```

### List Content Widget (120 lines)

```dart
class FriendsListContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FriendsViewModel>(
      builder: (context, viewModel, _) {
        return LoadingStateBuilder<List<UserProfile>>(
          isLoading: viewModel.isLoading,
          error: viewModel.error,
          data: viewModel.friends,
          emptyState: EmptyStateVariant.noFriends,
          onEmptyAction: () => viewModel.searchFriends(),
          builder: (context, friends) {
            return RefreshIndicator(
              onRefresh: () => viewModel.refresh(),
              child: ListView.separated(
                itemCount: friends.length,
                separatorBuilder: (context, index) => Divider(),
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return FriendListItem(
                    friend: friend,
                    isSelected: viewModel.selectedIds.contains(friend.userId),
                    onTap: () => viewModel.viewProfile(friend.userId),
                    onLongPress: () => viewModel.toggleSelection(friend.userId),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
```

## Composition Patterns

### Column-Based Composition

```dart
class RecipeDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          RecipeDetailHeader(),
          RecipeIngredientsList(),
          RecipeInstructionsList(),
          RecipeComments(),
        ],
      ),
    );
  }
}
```

### Stack-Based Composition

```dart
class RecipeCardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RecipeCardBackground(),
        RecipeCardContent(),
        Positioned(
          top: 8,
          right: 8,
          child: RecipeCardActions(),
        ),
      ],
    );
  }
}
```

### Nested Composition

```dart
class ComplexView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ViewHeader(),  // Contains sub-widgets
        Expanded(
          child: ViewContent(),  // Contains more sub-widgets
        ),
        ViewFooter(),  // Contains action buttons
      ],
    );
  }
}
```

## Builder Pattern

Flexible composition with builder functions:

```dart
class UserListWidget extends StatelessWidget {
  final List<User> users;
  final Widget Function(BuildContext, User) itemBuilder;
  final VoidCallback? onEmpty;

  const UserListWidget({
    required this.users,
    required this.itemBuilder,
    this.onEmpty,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return StateWidget.empty(
        title: 'Inga användare',
        onAction: onEmpty,
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        return itemBuilder(context, users[index]);
      },
    );
  }
}

// Usage with custom builder
UserListWidget(
  users: friends,
  itemBuilder: (context, user) {
    return ListTile(
      leading: Avatar(user.avatarUrl),
      title: Text(user.displayName),
      onTap: () => viewProfile(user),
    );
  },
)
```

## Passing Data to Child Widgets

### Constructor Parameters

```dart
class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onTap;
  final bool showActions;

  const RecipeCard({
    required this.recipe,
    this.onTap,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Column([
          RecipeCardImage(imageUrl: recipe.imageUrl),
          RecipeCardTitle(title: recipe.title),
          if (showActions) RecipeCardActions(recipe: recipe),
        ]),
      ),
    );
  }
}
```

### Provider

```dart
class RecipeDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeDetailViewModel(recipeId: id),
      child: Column([
        RecipeDetailHeader(),  // Accesses Provider
        RecipeIngredientsList(),  // Accesses Provider
        RecipeInstructionsList(),  // Accesses Provider
      ]),
    );
  }
}

// Child widget accesses provider
class RecipeDetailHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recipe = context.watch<RecipeDetailViewModel>().recipe;
    return Text(recipe?.title ?? 'Loading...');
  }
}
```

### InheritedWidget

```dart
class RecipeProvider extends InheritedWidget {
  final Recipe recipe;

  const RecipeProvider({
    required this.recipe,
    required Widget child,
  }) : super(child: child);

  static Recipe of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RecipeProvider>()!
        .recipe;
  }

  @override
  bool updateShouldNotify(RecipeProvider oldWidget) {
    return recipe != oldWidget.recipe;
  }
}

// Usage
RecipeProvider(
  recipe: recipe,
  child: Column([
    RecipeHeader(),  // Uses RecipeProvider.of(context)
    RecipeBody(),
  ]),
)
```

## Testing Composite Widgets

### Test Main Facade

```dart
testWidgets('displays all sections', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RecipeDetailView(recipe: testRecipe),
    ),
  );

  // Verify all sub-widgets present
  expect(find.byType(RecipeDetailHeader), findsOneWidget);
  expect(find.byType(RecipeIngredientsList), findsOneWidget);
  expect(find.byType(RecipeInstructionsList), findsOneWidget);
});
```

### Test Individual Widgets

```dart
testWidgets('header displays title', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RecipeDetailHeader(recipe: testRecipe),
      ),
    ),
  );

  expect(find.text(testRecipe.title), findsOneWidget);
});
```

### Test with Provider

```dart
testWidgets('displays data from provider', (tester) async {
  final mockViewModel = MockRecipeDetailViewModel();
  when(() => mockViewModel.recipe).thenReturn(testRecipe);

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<RecipeDetailViewModel>.value(
        value: mockViewModel,
        child: RecipeDetailHeader(),
      ),
    ),
  );

  expect(find.text(testRecipe.title), findsOneWidget);
});
```

## Best Practices

1. **Keep Widgets Small**: Under 200 lines per widget
2. **Single Responsibility**: One purpose per widget
3. **Reusable Components**: Extract common patterns
4. **Clear Naming**: Descriptive widget names
5. **const Constructors**: Use const when possible
6. **Organize by Feature**: Group related widgets
7. **Test Independently**: Test widgets in isolation
8. **Document Complex Widgets**: Add comments for clarity

## Common Patterns

**Header + Content + Actions**:
```dart
Column([
  ViewHeader(),
  Expanded(child: ViewContent()),
  ViewActions(),
])
```

**Tabs + Content**:
```dart
Column([
  TabBar(),
  Expanded(child: TabBarView()),
])
```

**Search + List**:
```dart
Column([
  SearchBar(),
  Expanded(child: ListView()),
])
```

**Grid Layout**:
```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
  ),
  itemBuilder: (context, index) => GridItem(),
)
```

## Anti-Patterns

**1. Monolithic Widgets (🔥 HIGH)**:
```dart
// ❌ WRONG - 800 lines in one widget
class RecipeDetailView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column([
      // 200 lines of header code
      // 300 lines of ingredients
      // 200 lines of instructions
      // 100 lines of actions
    ]);
  }
}
```

**2. Over-Extraction (⚠️)**:
```dart
// ❌ WRONG - Extracting trivial widgets
class MyPadding extends StatelessWidget {
  Widget build(BuildContext context) => Padding(...);
}

class MySizedBox extends StatelessWidget {
  Widget build(BuildContext context) => SizedBox(...);
}
```

**3. Tight Coupling (⚠️)**:
```dart
// ❌ WRONG - Child widget depends on parent's private state
class ChildWidget extends StatelessWidget {
  final ParentWidgetState parentState;  // Tight coupling!
}
```

## Related Resources

- [LoadingStateBuilder](loading-state-builder.md) - State management in widgets
- [StateWidget](state-widget.md) - Common state displays
- [Common Widgets](common-widgets.md) - Reusable component library
- state-management-patterns skill - ViewModel usage in widgets
