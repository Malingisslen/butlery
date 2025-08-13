/// Test data builder for Recipe objects
/// 
/// Provides fluent API for creating test recipes with Swedish-themed defaults
/// and various preset configurations for different test scenarios.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:uuid/uuid.dart';

/// Builder pattern for creating test Recipe instances
class RecipeBuilder {
  String id = const Uuid().v4();
  String title = 'Test Recipe';
  String description = 'A test recipe description';
  List<String> ingredients = ['Ingredient 1', 'Ingredient 2'];
  List<String> instructions = ['Step 1', 'Step 2'];
  List<String> imageUrls = [];
  String mealType = 'Middag';
  int portions = 4;
  int timeMinutes = 30;
  double rating = 4.5;
  List<String> tags = ['test'];
  String? sourceUrl;
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  DateTime? lastCookedAt;
  RecipeType type = RecipeType.personal;
  String? createdBy = 'test_user_123';
  
  /// Creates a Swedish dinner recipe preset
  RecipeBuilder asSwedishDinner() {
    title = 'Köttbullar med potatismos';
    description = 'Klassiska svenska köttbullar med krämig potatismos och lingonsylt';
    ingredients = [
      '500g köttfärs',
      '1 ägg',
      '1 dl ströbröd',
      '1 lök, finhackad',
      '2 msk smör',
      '3 dl grädde',
      '1 kg potatis',
      'Lingonsylt för servering',
    ];
    instructions = [
      'Blanda köttfärs, ägg, ströbröd och lök',
      'Forma till köttbullar',
      'Stek köttbullarna i smör',
      'Koka potatisen och mosa',
      'Servera med lingonsylt',
    ];
    mealType = 'Middag';
    portions = 4;
    timeMinutes = 45;
    rating = 4.8;
    tags = ['svensk', 'kött', 'traditionell'];
    return this;
  }
  
  /// Creates an Italian pasta recipe preset
  RecipeBuilder asItalianPasta() {
    title = 'Pasta Carbonara';
    description = 'Klassisk italiensk pasta carbonara med guanciale och pecorino';
    ingredients = [
      '400g spaghetti',
      '200g guanciale',
      '4 äggulor',
      '100g pecorino romano',
      'Svartpeppar',
    ];
    instructions = [
      'Koka pastan al dente',
      'Stek guanciale tills krispigt',
      'Blanda äggulor och riven ost',
      'Blanda pasta med guanciale',
      'Rör i äggblandningen utanför värme',
      'Servera med svartpeppar',
    ];
    mealType = 'Middag';
    portions = 4;
    timeMinutes = 20;
    rating = 4.9;
    tags = ['italiensk', 'pasta', 'snabb'];
    return this;
  }
  
  /// Creates a Swedish breakfast recipe preset
  RecipeBuilder asSwedishBreakfast() {
    title = 'Havregrynsgröt med bär';
    description = 'Näringsrik havregrynsgröt toppad med färska bär och honung';
    ingredients = [
      '1 dl havregryn',
      '2.5 dl mjölk',
      '1 nypa salt',
      'Blåbär',
      'Hallon',
      'Honung',
    ];
    instructions = [
      'Koka upp mjölk med salt',
      'Tillsätt havregryn och låt koka 5 minuter',
      'Rör om regelbundet',
      'Toppa med bär och honung',
    ];
    mealType = 'Frukost';
    portions = 2;
    timeMinutes = 10;
    rating = 4.2;
    tags = ['frukost', 'vegetarisk', 'snabb'];
    return this;
  }
  
  /// Creates a Swedish dessert recipe preset
  RecipeBuilder asSwedishDessert() {
    title = 'Kladdkaka';
    description = 'Klassisk svensk kladdkaka med seg mitt och krispig kant';
    ingredients = [
      '100g smör',
      '2 ägg',
      '2.5 dl socker',
      '1.5 dl vetemjöl',
      '3 msk kakao',
      '1 tsk vaniljsocker',
      '1 nypa salt',
    ];
    instructions = [
      'Sätt ugnen på 175 grader',
      'Smält smöret',
      'Blanda ägg och socker',
      'Tillsätt mjöl, kakao, vaniljsocker och salt',
      'Rör i det smälta smöret',
      'Grädda i 15 minuter',
    ];
    mealType = 'Efterrätt';
    portions = 8;
    timeMinutes = 25;
    rating = 4.9;
    tags = ['dessert', 'choklad', 'svensk'];
    return this;
  }
  
  /// Set custom title
  RecipeBuilder withTitle(String title) {
    this.title = title;
    return this;
  }
  
  /// Set custom creator ID
  RecipeBuilder withCreatedBy(String createdBy) {
    this.createdBy = createdBy;
    return this;
  }
  
  /// Set custom ID
  RecipeBuilder withId(String id) {
    this.id = id;
    return this;
  }
  
  /// Set custom ingredients
  RecipeBuilder withIngredients(List<String> ingredients) {
    this.ingredients = ingredients;
    return this;
  }
  
  /// Set custom instructions
  RecipeBuilder withInstructions(List<String> instructions) {
    this.instructions = instructions;
    return this;
  }
  
  /// Set custom meal type
  RecipeBuilder withMealType(String mealType) {
    this.mealType = mealType;
    return this;
  }
  
  /// Set custom portions
  RecipeBuilder withPortions(int portions) {
    this.portions = portions;
    return this;
  }
  
  /// Set custom time in minutes
  RecipeBuilder withTimeMinutes(int timeMinutes) {
    this.timeMinutes = timeMinutes;
    return this;
  }
  
  /// Set custom rating
  RecipeBuilder withRating(double rating) {
    this.rating = rating;
    return this;
  }
  
  /// Set custom tags
  RecipeBuilder withTags(List<String> tags) {
    this.tags = tags;
    return this;
  }
  
  /// Set recipe type
  RecipeBuilder withType(RecipeType type) {
    this.type = type;
    return this;
  }
  
  /// Set as shared recipe
  RecipeBuilder asShared() {
    type = RecipeType.shared;
    return this;
  }
  
  /// Set as collaborative recipe
  RecipeBuilder asCollaborative() {
    type = RecipeType.collaborative;
    return this;
  }
  
  /// Set as realtime recipe
  RecipeBuilder asRealtime() {
    type = RecipeType.realtime;
    return this;
  }
  
  /// Set image URLs
  RecipeBuilder withImageUrls(List<String> imageUrls) {
    this.imageUrls = imageUrls;
    return this;
  }
  
  /// Set source URL
  RecipeBuilder withSourceUrl(String sourceUrl) {
    this.sourceUrl = sourceUrl;
    return this;
  }
  
  /// Build the Recipe instance
  Recipe build() {
    return Recipe(
      core: RecipeCore(
        id: id,
        title: title,
        description: description,
        ingredients: ingredients,
        instructions: instructions,
        imageUrls: imageUrls,
        mealType: mealType,
        portions: portions,
        timeMinutes: timeMinutes,
        rating: rating,
        tags: tags,
        sourceUrl: sourceUrl,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastCookedAt: lastCookedAt,
        createdBy: createdBy,
      ),
      type: type,
    );
  }
}