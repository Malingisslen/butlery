/// Test Data Builders for creating test objects with the builder pattern
/// 
/// Provides flexible test data creation with Swedish defaults for the
/// Butlery application's recipe management system.
library;

import 'dart:math';

/// Base builder class with common functionality
abstract class TestDataBuilder<T> {
  /// Random generator for creating unique values
  static final Random _random = Random();
  
  /// Generate a unique ID
  static String generateId([String prefix = 'test']) {
    return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
  }
  
  /// Build the object
  T build();
  
  /// Build multiple objects with variations
  List<T> buildMany(int count) {
    final List<T> results = [];
    for (int i = 0; i < count; i++) {
      results.add(build());
      // Small delay to ensure unique timestamps in IDs
      if (i < count - 1) {
        // Don't delay on last iteration
        Future.delayed(Duration(microseconds: 1));
      }
    }
    return results;
  }
}

/// Recipe builder with Swedish defaults
class RecipeBuilder extends TestDataBuilder<TestRecipe> {
  String id = TestDataBuilder.generateId('recipe');
  String title = 'Köttbullar med gräddsås';
  String description = 'Klassiska svenska köttbullar med krämig gräddsås';
  String userId = 'test_user_123';
  String authorDisplayName = 'Test Kock';
  List<String> ingredients = [
    '500g köttfärs',
    '1 ägg',
    '1 dl ströbröd',
    '1 gul lök',
    '2 dl grädde',
    'Salt och peppar',
  ];
  List<String> instructions = [
    'Finhacka löken',
    'Blanda köttfärs, ägg, ströbröd och lök',
    'Forma till bollar',
    'Stek i smör tills gyllenbruna',
    'Tillaga gräddsåsen',
    'Servera med lingon och pressgurka',
  ];
  int timeMinutes = 45;
  int portions = 4;
  String category = 'Huvudrätt';
  List<String> tags = ['svensk', 'klassisk', 'kött'];
  String? imageUrl;
  bool isFavorite = false;
  double rating = 4.5;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  RecipeType recipeType = RecipeType.personal;
  
  /// Set recipe ID
  RecipeBuilder withId(String newId) {
    id = newId;
    return this;
  }
  
  /// Set recipe title
  RecipeBuilder withTitle(String newTitle) {
    title = newTitle;
    return this;
  }
  
  /// Set recipe description
  RecipeBuilder withDescription(String newDescription) {
    description = newDescription;
    return this;
  }
  
  /// Set recipe author
  RecipeBuilder withAuthor(String newUserId, String newDisplayName) {
    userId = newUserId;
    authorDisplayName = newDisplayName;
    return this;
  }
  
  /// Set recipe ingredients
  RecipeBuilder withIngredients(List<String> newIngredients) {
    ingredients = newIngredients;
    return this;
  }
  
  /// Add a single ingredient
  RecipeBuilder addIngredient(String ingredient) {
    ingredients.add(ingredient);
    return this;
  }
  
  /// Set recipe instructions
  RecipeBuilder withInstructions(List<String> newInstructions) {
    instructions = newInstructions;
    return this;
  }
  
  /// Set cooking time
  RecipeBuilder withTime(int minutes) {
    timeMinutes = minutes;
    return this;
  }
  
  /// Set portions
  RecipeBuilder withPortions(int newPortions) {
    portions = newPortions;
    return this;
  }
  
  /// Set category
  RecipeBuilder withCategory(String newCategory) {
    category = newCategory;
    return this;
  }
  
  /// Set tags
  RecipeBuilder withTags(List<String> newTags) {
    tags = newTags;
    return this;
  }
  
  /// Set as favorite
  RecipeBuilder asFavorite() {
    isFavorite = true;
    return this;
  }
  
  /// Set recipe type
  RecipeBuilder withType(RecipeType type) {
    recipeType = type;
    return this;
  }
  
  /// Use Swedish breakfast defaults
  RecipeBuilder asSwedishBreakfast() {
    title = 'Havregrynsgröt';
    description = 'Nyttig och mättande frukostgröt';
    ingredients = [
      '1 dl havregryn',
      '2.5 dl vatten',
      '0.5 tsk salt',
      'Mjölk till servering',
      'Lingonsylt',
    ];
    instructions = [
      'Koka upp vatten och salt',
      'Tillsätt havregryn under omrörning',
      'Låt sjuda 5 minuter',
      'Servera med mjölk och lingonsylt',
    ];
    timeMinutes = 10;
    category = 'Frukost';
    tags = ['frukost', 'svensk', 'gröt'];
    return this;
  }
  
  /// Use Swedish dinner defaults
  RecipeBuilder asSwedishDinner() {
    title = 'Laxpudding';
    description = 'Klassisk svensk laxpudding med dill';
    ingredients = [
      '600g potatis',
      '300g gravlax',
      '2 ägg',
      '3 dl mjölk',
      '1 knippa dill',
      'Smör till formen',
    ];
    instructions = [
      'Skiva potatis och lax',
      'Varva i smord form',
      'Vispa ihop ägg och mjölk',
      'Häll över äggstanningen',
      'Grädda i 200° i 45 minuter',
    ];
    timeMinutes = 60;
    category = 'Middag';
    tags = ['middag', 'svensk', 'fisk'];
    return this;
  }
  
  /// Use Swedish fika defaults
  RecipeBuilder asSwedishFika() {
    title = 'Kanelbullar';
    description = 'Saftiga kanelbullar perfekta till fikat';
    ingredients = [
      '5 dl mjölk',
      '50g jäst',
      '1.5 dl socker',
      '150g smör',
      '1 tsk salt',
      '1 kg vetemjöl',
      'Kanel och socker till fyllning',
      'Pärlsocker',
    ];
    instructions = [
      'Värm mjölken till 37°',
      'Lös upp jästen i mjölken',
      'Tillsätt socker, salt och smält smör',
      'Arbeta in mjölet till smidig deg',
      'Låt jäsa 40 minuter',
      'Kavla ut och bred på fyllning',
      'Rulla ihop och skär i bitar',
      'Låt jäsa 30 minuter',
      'Grädda i 225° i 10 minuter',
    ];
    timeMinutes = 120;
    category = 'Bakverk';
    tags = ['fika', 'svensk', 'bullar'];
    return this;
  }
  
  @override
  TestRecipe build() {
    return TestRecipe(
      id: id,
      title: title,
      description: description,
      userId: userId,
      authorDisplayName: authorDisplayName,
      ingredients: ingredients,
      instructions: instructions,
      timeMinutes: timeMinutes,
      portions: portions,
      category: category,
      tags: tags,
      imageUrl: imageUrl,
      isFavorite: isFavorite,
      rating: rating,
      createdAt: createdAt,
      updatedAt: updatedAt,
      recipeType: recipeType,
    );
  }
}

/// User builder for test users
class UserBuilder extends TestDataBuilder<TestUser> {
  String uid = TestDataBuilder.generateId('user');
  String email = 'test@example.com';
  String displayName = 'Test Användare';
  String? photoURL;
  bool emailVerified = true;
  String? phoneNumber;
  Map<String, dynamic> customClaims = {};
  
  UserBuilder withId(String newUid) {
    uid = newUid;
    return this;
  }
  
  UserBuilder withEmail(String newEmail) {
    email = newEmail;
    return this;
  }
  
  UserBuilder withDisplayName(String newDisplayName) {
    displayName = newDisplayName;
    return this;
  }
  
  UserBuilder withPhotoURL(String newPhotoURL) {
    photoURL = newPhotoURL;
    return this;
  }
  
  UserBuilder asUnverified() {
    emailVerified = false;
    return this;
  }
  
  UserBuilder withPhoneNumber(String newPhoneNumber) {
    phoneNumber = newPhoneNumber;
    return this;
  }
  
  UserBuilder withCustomClaim(String key, dynamic value) {
    customClaims[key] = value;
    return this;
  }
  
  UserBuilder asSwedishUser() {
    displayName = 'Sven Svensson';
    email = 'sven@exempel.se';
    return this;
  }
  
  @override
  TestUser build() {
    return TestUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      emailVerified: emailVerified,
      phoneNumber: phoneNumber,
      customClaims: customClaims,
    );
  }
}

/// Shopping list item builder
class ShoppingItemBuilder extends TestDataBuilder<TestShoppingItem> {
  String id = TestDataBuilder.generateId('item');
  String name = 'Mjölk';
  double quantity = 1.0;
  String unit = 'liter';
  String category = 'Mejeri';
  bool isChecked = false;
  String? recipeId;
  String? notes;
  
  ShoppingItemBuilder withId(String newId) {
    id = newId;
    return this;
  }
  
  ShoppingItemBuilder withName(String newName) {
    name = newName;
    return this;
  }
  
  ShoppingItemBuilder withQuantity(double newQuantity, String newUnit) {
    quantity = newQuantity;
    unit = newUnit;
    return this;
  }
  
  ShoppingItemBuilder inCategory(String newCategory) {
    category = newCategory;
    return this;
  }
  
  ShoppingItemBuilder asChecked() {
    isChecked = true;
    return this;
  }
  
  ShoppingItemBuilder fromRecipe(String newRecipeId) {
    recipeId = newRecipeId;
    return this;
  }
  
  ShoppingItemBuilder withNotes(String newNotes) {
    notes = newNotes;
    return this;
  }
  
  /// Create common Swedish grocery items
  ShoppingItemBuilder asSwedishStaple(SwedishStaple staple) {
    switch (staple) {
      case SwedishStaple.milk:
        name = 'Mjölk';
        quantity = 1;
        unit = 'liter';
        category = 'Mejeri';
        break;
      case SwedishStaple.bread:
        name = 'Rågbröd';
        quantity = 1;
        unit = 'limpa';
        category = 'Bröd';
        break;
      case SwedishStaple.butter:
        name = 'Smör';
        quantity = 500;
        unit = 'gram';
        category = 'Mejeri';
        break;
      case SwedishStaple.coffee:
        name = 'Kaffe';
        quantity = 500;
        unit = 'gram';
        category = 'Torrvaror';
        break;
      case SwedishStaple.potatoes:
        name = 'Potatis';
        quantity = 2;
        unit = 'kg';
        category = 'Frukt & Grönt';
        break;
    }
    return this;
  }
  
  @override
  TestShoppingItem build() {
    return TestShoppingItem(
      id: id,
      name: name,
      quantity: quantity,
      unit: unit,
      category: category,
      isChecked: isChecked,
      recipeId: recipeId,
      notes: notes,
    );
  }
}

/// Menu builder for meal planning
class MenuBuilder extends TestDataBuilder<TestMenu> {
  String id = TestDataBuilder.generateId('menu');
  String name = 'Veckans meny';
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  Map<String, List<String>> meals = {};
  String ownerId = 'test_user_123';
  bool isShared = false;
  
  MenuBuilder withId(String newId) {
    id = newId;
    return this;
  }
  
  MenuBuilder withName(String newName) {
    name = newName;
    return this;
  }
  
  MenuBuilder forDateRange(DateTime start, DateTime end) {
    startDate = start;
    endDate = end;
    return this;
  }
  
  MenuBuilder withMeal(String day, String meal, String recipeId) {
    if (!meals.containsKey(day)) {
      meals[day] = [];
    }
    meals[day]!.add('$meal:$recipeId');
    return this;
  }
  
  MenuBuilder asShared() {
    isShared = true;
    return this;
  }
  
  MenuBuilder withSwedishWeekMenu() {
    meals = {
      'Måndag': ['Frukost:recipe_1', 'Lunch:recipe_2', 'Middag:recipe_3'],
      'Tisdag': ['Frukost:recipe_4', 'Lunch:recipe_5', 'Middag:recipe_6'],
      'Onsdag': ['Frukost:recipe_7', 'Lunch:recipe_8', 'Middag:recipe_9'],
      'Torsdag': ['Frukost:recipe_10', 'Lunch:recipe_11', 'Middag:recipe_12'],
      'Fredag': ['Frukost:recipe_13', 'Lunch:recipe_14', 'Middag:recipe_15'],
      'Lördag': ['Frukost:recipe_16', 'Lunch:recipe_17', 'Middag:recipe_18'],
      'Söndag': ['Frukost:recipe_19', 'Lunch:recipe_20', 'Middag:recipe_21'],
    };
    return this;
  }
  
  @override
  TestMenu build() {
    return TestMenu(
      id: id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      meals: meals,
      ownerId: ownerId,
      isShared: isShared,
    );
  }
}

// ============= TEST DATA MODELS =============
// These are simplified models for testing

class TestRecipe {
  final String id;
  final String title;
  final String description;
  final String userId;
  final String authorDisplayName;
  final List<String> ingredients;
  final List<String> instructions;
  final int timeMinutes;
  final int portions;
  final String category;
  final List<String> tags;
  final String? imageUrl;
  final bool isFavorite;
  final double rating;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RecipeType recipeType;
  
  TestRecipe({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.authorDisplayName,
    required this.ingredients,
    required this.instructions,
    required this.timeMinutes,
    required this.portions,
    required this.category,
    required this.tags,
    this.imageUrl,
    required this.isFavorite,
    required this.rating,
    required this.createdAt,
    required this.updatedAt,
    required this.recipeType,
  });
}

class TestUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final bool emailVerified;
  final String? phoneNumber;
  final Map<String, dynamic> customClaims;
  
  TestUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.emailVerified,
    this.phoneNumber,
    required this.customClaims,
  });
}

class TestShoppingItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final bool isChecked;
  final String? recipeId;
  final String? notes;
  
  TestShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.isChecked,
    this.recipeId,
    this.notes,
  });
}

class TestMenu {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, List<String>> meals;
  final String ownerId;
  final bool isShared;
  
  TestMenu({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.meals,
    required this.ownerId,
    required this.isShared,
  });
}

/// Recipe types
enum RecipeType {
  personal,
  collaborative,
  shared,
  public,
}

/// Common Swedish grocery staples
enum SwedishStaple {
  milk,
  bread,
  butter,
  coffee,
  potatoes,
}