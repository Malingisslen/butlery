# Test Data Factories

Test data factories provide consistent, realistic, and maintainable test data across your test suite. This guide covers Butlery's test factory patterns.

## Philosophy

Good test data factories:
- Generate realistic data that mirrors production
- Provide sensible defaults with easy customization
- Reduce test boilerplate and duplication
- Make tests more readable and maintainable
- Support both simple and complex scenarios

## Basic Factory Pattern

```dart
class RecipeFactory {
  static Recipe create({
    String? id,
    String? userId,
    String? title,
    int? portions,
    List<Ingredient>? ingredients,
    List<String>? instructions,
    DateTime? createdAt,
  }) {
    return Recipe(
      id: id ?? 'recipe_1',
      userId: userId ?? 'user_1',
      title: title ?? 'Test Recipe',
      portions: portions ?? 4,
      ingredients: ingredients ?? [
        Ingredient(name: 'Flour', amount: '2', unit: 'cups'),
        Ingredient(name: 'Sugar', amount: '1', unit: 'cup'),
      ],
      instructions: instructions ?? [
        'Mix ingredients',
        'Bake at 350°F',
      ],
      createdAt: createdAt ?? DateTime(2025, 1, 1),
    );
  }

  static List<Recipe> createList({
    int count = 3,
    String? userId,
  }) {
    return List.generate(
      count,
      (i) => create(
        id: 'recipe_$i',
        userId: userId,
        title: 'Test Recipe $i',
      ),
    );
  }
}

// Usage in tests
void main() {
  test('creates recipe with default values', () {
    final recipe = RecipeFactory.create();
    expect(recipe.title, 'Test Recipe');
    expect(recipe.portions, 4);
  });

  test('creates recipe with custom values', () {
    final recipe = RecipeFactory.create(
      title: 'Custom Recipe',
      portions: 8,
    );
    expect(recipe.title, 'Custom Recipe');
    expect(recipe.portions, 8);
  });

  test('creates list of recipes', () {
    final recipes = RecipeFactory.createList(count: 5);
    expect(recipes.length, 5);
    expect(recipes[0].id, 'recipe_0');
    expect(recipes[1].id, 'recipe_1');
  });
}
```

## User Factory

```dart
class UserFactory {
  static UserProfile create({
    String? userId,
    String? email,
    String? displayName,
    String? avatarUrl,
    UserSettings? settings,
    DateTime? createdAt,
  }) {
    return UserProfile(
      userId: userId ?? 'user_1',
      email: email ?? 'test@example.com',
      displayName: displayName ?? 'Test User',
      avatarUrl: avatarUrl,
      settings: settings ?? UserSettingsFactory.create(),
      createdAt: createdAt ?? DateTime(2025, 1, 1),
    );
  }

  static List<UserProfile> createFriends({
    int count = 3,
    String? forUserId,
  }) {
    return List.generate(
      count,
      (i) => create(
        userId: 'friend_$i',
        displayName: 'Friend $i',
        email: 'friend$i@example.com',
      ),
    );
  }
}

class UserSettingsFactory {
  static UserSettings create({
    bool? notificationsEnabled,
    String? theme,
    String? language,
  }) {
    return UserSettings(
      notificationsEnabled: notificationsEnabled ?? true,
      theme: theme ?? 'light',
      language: language ?? 'en',
    );
  }
}
```

## Ingredient Factory

```dart
class IngredientFactory {
  static Ingredient create({
    String? name,
    String? amount,
    String? unit,
    String? preparation,
  }) {
    return Ingredient(
      name: name ?? 'Test Ingredient',
      amount: amount ?? '1',
      unit: unit ?? 'cup',
      preparation: preparation,
    );
  }

  static List<Ingredient> createList({
    int count = 3,
  }) {
    final ingredients = [
      Ingredient(name: 'Flour', amount: '2', unit: 'cups'),
      Ingredient(name: 'Sugar', amount: '1', unit: 'cup'),
      Ingredient(name: 'Butter', amount: '1/2', unit: 'cup'),
      Ingredient(name: 'Eggs', amount: '2', unit: ''),
      Ingredient(name: 'Vanilla', amount: '1', unit: 'tsp'),
    ];
    return ingredients.take(count).toList();
  }

  static List<Ingredient> createBaking() {
    return [
      Ingredient(name: 'All-purpose flour', amount: '2', unit: 'cups'),
      Ingredient(name: 'Baking powder', amount: '2', unit: 'tsp'),
      Ingredient(name: 'Salt', amount: '1/2', unit: 'tsp'),
      Ingredient(name: 'Sugar', amount: '3/4', unit: 'cup'),
      Ingredient(name: 'Butter', amount: '1/2', unit: 'cup'),
      Ingredient(name: 'Eggs', amount: '2', unit: ''),
      Ingredient(name: 'Milk', amount: '3/4', unit: 'cup'),
    ];
  }

  static List<Ingredient> createSalad() {
    return [
      Ingredient(name: 'Lettuce', amount: '1', unit: 'head'),
      Ingredient(name: 'Tomatoes', amount: '2', unit: ''),
      Ingredient(name: 'Cucumber', amount: '1', unit: ''),
      Ingredient(name: 'Olive oil', amount: '2', unit: 'tbsp'),
      Ingredient(name: 'Lemon juice', amount: '1', unit: 'tbsp'),
    ];
  }
}
```

## Menu Factory

```dart
class MenuFactory {
  static Menu create({
    String? id,
    String? userId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    List<MenuDay>? days,
  }) {
    return Menu(
      id: id ?? 'menu_1',
      userId: userId ?? 'user_1',
      title: title ?? 'Test Menu',
      startDate: startDate ?? DateTime(2025, 1, 1),
      endDate: endDate ?? DateTime(2025, 1, 7),
      days: days ?? MenuDayFactory.createList(count: 7),
    );
  }
}

class MenuDayFactory {
  static MenuDay create({
    DateTime? date,
    String? breakfast,
    String? lunch,
    String? dinner,
  }) {
    final baseDate = DateTime(2025, 1, 1);
    return MenuDay(
      date: date ?? baseDate,
      breakfast: breakfast ?? 'recipe_breakfast',
      lunch: lunch ?? 'recipe_lunch',
      dinner: dinner ?? 'recipe_dinner',
    );
  }

  static List<MenuDay> createList({int count = 7}) {
    final baseDate = DateTime(2025, 1, 1);
    return List.generate(
      count,
      (i) => create(date: baseDate.add(Duration(days: i))),
    );
  }
}
```

## Shopping List Factory

```dart
class ShoppingListFactory {
  static ShoppingList create({
    String? id,
    String? userId,
    String? title,
    List<ShoppingItem>? items,
    DateTime? createdAt,
  }) {
    return ShoppingList(
      id: id ?? 'list_1',
      userId: userId ?? 'user_1',
      title: title ?? 'Test Shopping List',
      items: items ?? ShoppingItemFactory.createList(),
      createdAt: createdAt ?? DateTime(2025, 1, 1),
    );
  }
}

class ShoppingItemFactory {
  static ShoppingItem create({
    String? id,
    String? name,
    String? amount,
    String? unit,
    bool? checked,
    String? category,
  }) {
    return ShoppingItem(
      id: id ?? 'item_1',
      name: name ?? 'Test Item',
      amount: amount ?? '1',
      unit: unit ?? 'piece',
      checked: checked ?? false,
      category: category ?? 'Groceries',
    );
  }

  static List<ShoppingItem> createList({int count = 5}) {
    return List.generate(
      count,
      (i) => create(
        id: 'item_$i',
        name: 'Item $i',
      ),
    );
  }

  static List<ShoppingItem> createGroceries() {
    return [
      ShoppingItem(
        id: '1',
        name: 'Milk',
        amount: '1',
        unit: 'gallon',
        category: 'Dairy',
      ),
      ShoppingItem(
        id: '2',
        name: 'Bread',
        amount: '1',
        unit: 'loaf',
        category: 'Bakery',
      ),
      ShoppingItem(
        id: '3',
        name: 'Eggs',
        amount: '1',
        unit: 'dozen',
        category: 'Dairy',
      ),
    ];
  }
}
```

## Social Feature Factories

```dart
class CommentFactory {
  static Comment create({
    String? id,
    String? recipeId,
    String? userId,
    String? userName,
    String? text,
    DateTime? createdAt,
  }) {
    return Comment(
      id: id ?? 'comment_1',
      recipeId: recipeId ?? 'recipe_1',
      userId: userId ?? 'user_1',
      userName: userName ?? 'Test User',
      text: text ?? 'Great recipe!',
      createdAt: createdAt ?? DateTime(2025, 1, 1),
    );
  }

  static List<Comment> createList({
    int count = 3,
    String? recipeId,
  }) {
    return List.generate(
      count,
      (i) => create(
        id: 'comment_$i',
        recipeId: recipeId,
        userId: 'user_$i',
        userName: 'User $i',
        text: 'Comment $i',
      ),
    );
  }
}

class RatingFactory {
  static RecipeRating create({
    String? id,
    String? recipeId,
    String? userId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return RecipeRating(
      id: id ?? 'rating_1',
      recipeId: recipeId ?? 'recipe_1',
      userId: userId ?? 'user_1',
      rating: rating ?? 5,
      comment: comment,
      createdAt: createdAt ?? DateTime(2025, 1, 1),
    );
  }

  static List<RecipeRating> createList({
    int count = 3,
    String? recipeId,
  }) {
    return List.generate(
      count,
      (i) => create(
        id: 'rating_$i',
        recipeId: recipeId,
        userId: 'user_$i',
        rating: 4 + (i % 2), // Alternates between 4 and 5
      ),
    );
  }
}

class SharedRecipeFactory {
  static SharedRecipe create({
    String? id,
    String? recipeId,
    String? ownerId,
    String? ownerName,
    List<String>? sharedWith,
    DateTime? sharedAt,
  }) {
    return SharedRecipe(
      id: id ?? 'shared_1',
      recipeId: recipeId ?? 'recipe_1',
      ownerId: ownerId ?? 'user_1',
      ownerName: ownerName ?? 'Test User',
      sharedWith: sharedWith ?? ['user_2', 'user_3'],
      sharedAt: sharedAt ?? DateTime(2025, 1, 1),
    );
  }
}
```

## Builder Pattern for Complex Objects

For very complex objects, use builder pattern:

```dart
class RecipeBuilder {
  String _id = 'recipe_1';
  String _userId = 'user_1';
  String _title = 'Test Recipe';
  int _portions = 4;
  List<Ingredient> _ingredients = [];
  List<String> _instructions = [];
  DateTime _createdAt = DateTime(2025, 1, 1);
  List<String> _tags = [];
  String? _imageUrl;
  RecipeVisibility _visibility = RecipeVisibility.private;

  RecipeBuilder withId(String id) {
    _id = id;
    return this;
  }

  RecipeBuilder withUserId(String userId) {
    _userId = userId;
    return this;
  }

  RecipeBuilder withTitle(String title) {
    _title = title;
    return this;
  }

  RecipeBuilder withPortions(int portions) {
    _portions = portions;
    return this;
  }

  RecipeBuilder withIngredients(List<Ingredient> ingredients) {
    _ingredients = ingredients;
    return this;
  }

  RecipeBuilder withInstructions(List<String> instructions) {
    _instructions = instructions;
    return this;
  }

  RecipeBuilder withTags(List<String> tags) {
    _tags = tags;
    return this;
  }

  RecipeBuilder withImage(String url) {
    _imageUrl = url;
    return this;
  }

  RecipeBuilder asPublic() {
    _visibility = RecipeVisibility.public;
    return this;
  }

  RecipeBuilder asPrivate() {
    _visibility = RecipeVisibility.private;
    return this;
  }

  Recipe build() {
    return Recipe(
      id: _id,
      userId: _userId,
      title: _title,
      portions: _portions,
      ingredients: _ingredients,
      instructions: _instructions,
      createdAt: _createdAt,
      tags: _tags,
      imageUrl: _imageUrl,
      visibility: _visibility,
    );
  }
}

// Usage
void main() {
  test('creates complex recipe with builder', () {
    final recipe = RecipeBuilder()
        .withTitle('Chocolate Cake')
        .withPortions(8)
        .withIngredients(IngredientFactory.createBaking())
        .withInstructions([
          'Preheat oven to 350°F',
          'Mix dry ingredients',
          'Mix wet ingredients',
          'Combine and bake',
        ])
        .withTags(['dessert', 'chocolate', 'cake'])
        .asPublic()
        .build();

    expect(recipe.title, 'Chocolate Cake');
    expect(recipe.visibility, RecipeVisibility.public);
  });
}
```

## Firestore Document Factories

For testing repositories with FakeFirebaseFirestore:

```dart
class FirestoreDocumentFactory {
  static Map<String, dynamic> recipeDocument({
    String? id,
    String? userId,
    String? title,
    int? portions,
  }) {
    return {
      'id': id ?? 'recipe_1',
      'userId': userId ?? 'user_1',
      'title': title ?? 'Test Recipe',
      'portions': portions ?? 4,
      'ingredients': [
        {
          'name': 'Flour',
          'amount': '2',
          'unit': 'cups',
        },
      ],
      'instructions': ['Mix ingredients', 'Bake'],
      'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
    };
  }

  static Map<String, dynamic> userDocument({
    String? userId,
    String? email,
    String? displayName,
  }) {
    return {
      'userId': userId ?? 'user_1',
      'email': email ?? 'test@example.com',
      'displayName': displayName ?? 'Test User',
      'settings': {
        'notificationsEnabled': true,
        'theme': 'light',
        'language': 'en',
      },
      'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
    };
  }

  static Future<void> seedRecipes(
    FirebaseFirestore firestore, {
    required String userId,
    int count = 3,
  }) async {
    final batch = firestore.batch();
    for (var i = 0; i < count; i++) {
      final docRef = firestore
          .collection('users')
          .doc(userId)
          .collection('recipes')
          .doc('recipe_$i');
      batch.set(docRef, recipeDocument(
        id: 'recipe_$i',
        userId: userId,
        title: 'Recipe $i',
      ));
    }
    await batch.commit();
  }
}

// Usage in repository tests
void main() {
  late FirebaseFirestore fakeFirestore;
  late RecipeRepository repository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = FirebaseRecipeRepository(firestore: fakeFirestore);
  });

  test('loads user recipes', () async {
    // Seed test data
    await FirestoreDocumentFactory.seedRecipes(
      fakeFirestore,
      userId: 'user_1',
      count: 5,
    );

    final recipes = await repository.getUserRecipes('user_1');

    expect(recipes.length, 5);
    expect(recipes[0].title, 'Recipe 0');
  });
}
```

## Test State Factories

For testing ViewModels with various states:

```dart
class ViewModelStateFactory {
  static RecipeViewModel loadingState() {
    final viewModel = RecipeViewModel();
    viewModel.setLoading(true);
    return viewModel;
  }

  static RecipeViewModel errorState({String? message}) {
    final viewModel = RecipeViewModel();
    viewModel.setError(message ?? 'An error occurred');
    return viewModel;
  }

  static RecipeViewModel successState({List<Recipe>? recipes}) {
    final viewModel = RecipeViewModel();
    viewModel.setRecipes(recipes ?? RecipeFactory.createList());
    return viewModel;
  }

  static RecipeViewModel emptyState() {
    final viewModel = RecipeViewModel();
    viewModel.setRecipes([]);
    return viewModel;
  }
}

// Usage in widget tests
testWidgets('displays loading indicator', (tester) async {
  final viewModel = ViewModelStateFactory.loadingState();

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider.value(
        value: viewModel,
        child: RecipeListView(),
      ),
    ),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

## Realistic Data Generators

For generating more realistic test data:

```dart
class RealisticDataGenerator {
  static final _random = Random(42); // Seeded for consistent tests

  static String recipeName() {
    final dishes = [
      'Pasta Carbonara',
      'Chicken Tikka Masala',
      'Beef Tacos',
      'Caesar Salad',
      'Chocolate Chip Cookies',
      'Vegetable Stir Fry',
      'Margherita Pizza',
    ];
    return dishes[_random.nextInt(dishes.length)];
  }

  static int portions() {
    return 2 + _random.nextInt(7); // 2-8 portions
  }

  static DateTime recentDate({int maxDaysAgo = 30}) {
    final daysAgo = _random.nextInt(maxDaysAgo);
    return DateTime.now().subtract(Duration(days: daysAgo));
  }

  static String email(String name) {
    return '${name.toLowerCase().replaceAll(' ', '.')}@example.com';
  }

  static Recipe randomRecipe({String? userId}) {
    return RecipeFactory.create(
      id: 'recipe_${_random.nextInt(10000)}',
      userId: userId ?? 'user_${_random.nextInt(100)}',
      title: recipeName(),
      portions: portions(),
      createdAt: recentDate(),
    );
  }
}

// Usage
test('sorts recipes by date', () {
  final recipes = List.generate(
    10,
    (_) => RealisticDataGenerator.randomRecipe(userId: 'user_1'),
  );

  final sorted = sortByDate(recipes);

  // Verify sorting logic
  for (var i = 0; i < sorted.length - 1; i++) {
    expect(
      sorted[i].createdAt.isAfter(sorted[i + 1].createdAt),
      isTrue,
    );
  }
});
```

## Factory Best Practices

1. **Provide Sensible Defaults**: Every factory should work with zero arguments
2. **Allow Customization**: Every field should be overridable via named parameters
3. **Use Consistent IDs**: Use predictable IDs like 'recipe_1', 'user_1' for easier debugging
4. **Create Specialized Factories**: Provide domain-specific factories (createBaking, createSalad)
5. **Use Builders for Complexity**: Use builder pattern when objects have many optional fields
6. **Seed Realistic Data**: For integration tests, create realistic scenarios
7. **Keep Factories DRY**: Reuse lower-level factories in higher-level ones

## Common Patterns

**Factory Composition:**
```dart
class RecipeFactory {
  static Recipe create({
    List<Ingredient>? ingredients,
  }) {
    return Recipe(
      // ... other fields
      ingredients: ingredients ?? IngredientFactory.createList(),
    );
  }
}
```

**Scenario-Based Factories:**
```dart
class RecipeFactory {
  static Recipe createPublic() {
    return create(visibility: RecipeVisibility.public);
  }

  static Recipe createPrivate() {
    return create(visibility: RecipeVisibility.private);
  }

  static Recipe createShared({required List<String> sharedWith}) {
    return create(
      visibility: RecipeVisibility.shared,
      sharedWith: sharedWith,
    );
  }
}
```

**Related Entities:**
```dart
class RecipeFactory {
  static Recipe createWithComments({int commentCount = 3}) {
    final recipe = create();
    final comments = CommentFactory.createList(
      count: commentCount,
      recipeId: recipe.id,
    );
    return recipe.copyWith(comments: comments);
  }

  static Recipe createWithRatings({int ratingCount = 5}) {
    final recipe = create();
    final ratings = RatingFactory.createList(
      count: ratingCount,
      recipeId: recipe.id,
    );
    return recipe.copyWith(ratings: ratings);
  }
}
```

## Related Resources

- [Repository Testing](repository-testing.md) - Using factories in repository tests
- [Service Testing](service-testing.md) - Using factories in service tests
- [ViewModel Testing](viewmodel-testing.md) - Using factories in ViewModel tests
- [Integration Testing](integration-testing.md) - Using factories for E2E scenarios