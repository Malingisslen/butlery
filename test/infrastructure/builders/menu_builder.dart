/// Test data builder for SharedMenu objects
/// 
/// Provides fluent API for creating test menu instances with Swedish defaults.
library;

// ignore_for_file: prefer_final_fields

import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import '../builders/recipe_builder.dart';

class MenuBuilder {
  String _id = 'menu_${DateTime.now().millisecondsSinceEpoch}';
  String _menuTitle = 'Veckomeny';
  String _sharedByUserId = 'test_user_123';
  String _sharedByDisplayName = 'Test User';
  List<String> _sharedToUserIds = [];
  DateTime _sharedAt = DateTime.now();
  String? _shareMessage = 'Här är min veckomeny!';
  Map<String, List<Recipe>> _menuSnapshot = {};
  List<String> _viewedByUserIds = [];
  List<String> _importedByUserIds = [];
  List<String> _dismissedByUserIds = [];
  bool _allowCollaboration = false;
  
  MenuBuilder();
  
  /// Set menu ID
  MenuBuilder withId(String id) {
    _id = id;
    return this;
  }
  
  /// Set menu title
  MenuBuilder withTitle(String title) {
    _menuTitle = title;
    return this;
  }
  
  /// Set shared by user info
  MenuBuilder sharedBy(String userId, String displayName) {
    _sharedByUserId = userId;
    _sharedByDisplayName = displayName;
    return this;
  }
  
  /// Set shared to user IDs
  MenuBuilder sharedTo(List<String> userIds) {
    _sharedToUserIds = userIds;
    return this;
  }
  
  /// Set share message
  MenuBuilder withMessage(String? message) {
    _shareMessage = message;
    return this;
  }
  
  /// Set menu snapshot
  MenuBuilder withSnapshot(Map<String, List<Recipe>> snapshot) {
    _menuSnapshot = snapshot;
    return this;
  }
  
  /// Add recipes for a category
  MenuBuilder addCategory(String category, List<Recipe> recipes) {
    _menuSnapshot[category] = recipes;
    return this;
  }
  
  /// Set collaboration allowed
  MenuBuilder allowCollaboration(bool allow) {
    _allowCollaboration = allow;
    return this;
  }
  
  /// Configure as Swedish week menu
  MenuBuilder asSwedishWeekMenu() {
    _menuTitle = 'Veckans meny';
    _shareMessage = 'Här är min veckomeny för nästa vecka!';
    
    // Create recipes for different meal categories
    _menuSnapshot = {
      'Middag': [
        RecipeBuilder().withTitle('Köttbullar med gräddsås').withId('recipe_kottbullar').build(),
        RecipeBuilder().withTitle('Ärtsoppa med pannkakor').withId('recipe_artsoppa').build(),
        RecipeBuilder().withTitle('Fredagstacos').withId('recipe_tacos').build(),
        RecipeBuilder().withTitle('Söndagsstek').withId('recipe_stek').build(),
      ],
      'Lunch': [
        RecipeBuilder().withTitle('Räksmörgås').withId('recipe_raksmorgas').build(),
        RecipeBuilder().withTitle('Caesar sallad').withId('recipe_caesar').build(),
      ],
      'Fika': [
        RecipeBuilder().withTitle('Kanelbullar').withId('recipe_kanelbullar').build(),
        RecipeBuilder().withTitle('Kladdkaka').withId('recipe_kladdkaka').build(),
      ],
    };
    
    return this;
  }
  
  /// Configure as holiday menu
  MenuBuilder asHolidayMenu() {
    _menuTitle = 'Julbord';
    _shareMessage = 'Vårt traditionella julbord!';
    
    _menuSnapshot = {
      'Huvudrätter': [
        RecipeBuilder().withTitle('Julskinka').withId('recipe_julskinka').build(),
        RecipeBuilder().withTitle('Janssons frestelse').withId('recipe_janssons').build(),
        RecipeBuilder().withTitle('Köttbullar').withId('recipe_jul_kottbullar').build(),
      ],
      'Sill och fisk': [
        RecipeBuilder().withTitle('Inlagd sill').withId('recipe_sill').build(),
        RecipeBuilder().withTitle('Gravlax').withId('recipe_gravlax').build(),
      ],
      'Desserter': [
        RecipeBuilder().withTitle('Pepparkakor').withId('recipe_pepparkakor').build(),
        RecipeBuilder().withTitle('Saffransbullar').withId('recipe_saffran').build(),
      ],
    };
    
    return this;
  }
  
  /// Configure as breakfast menu
  MenuBuilder asBreakfastMenu() {
    _menuTitle = 'Frukostmeny';
    _shareMessage = 'Min frukostplanering för veckan';
    
    _menuSnapshot = {
      'Frukost': [
        RecipeBuilder().withTitle('Havregrynsgröt').withId('recipe_grot').build(),
        RecipeBuilder().withTitle('Filmjölk med müsli').withId('recipe_filmjolk').build(),
        RecipeBuilder().withTitle('Äggmacka').withId('recipe_aggmacka').build(),
        RecipeBuilder().withTitle('Yoghurt med granola').withId('recipe_yoghurt').build(),
        RecipeBuilder().withTitle('Smoothie bowl').withId('recipe_smoothie').build(),
        RecipeBuilder().withTitle('Pannkakor').withId('recipe_pannkakor').build(),
        RecipeBuilder().withTitle('Äggröra med bacon').withId('recipe_aggrora').build(),
      ],
    };
    
    return this;
  }
  
  /// Build the SharedMenu instance
  SharedMenu build() {
    // Ensure we have some default content if nothing was set
    if (_menuSnapshot.isEmpty) {
      _menuSnapshot = {
        'Allmänt': [
          RecipeBuilder().asSwedishDinner().build(),
        ],
      };
    }
    
    return SharedMenu(
      id: _id,
      sharedByUserId: _sharedByUserId,
      sharedByDisplayName: _sharedByDisplayName,
      sharedToUserIds: _sharedToUserIds,
      sharedAt: _sharedAt,
      shareMessage: _shareMessage,
      menuTitle: _menuTitle,
      menuSnapshot: _menuSnapshot,
      viewedByUserIds: _viewedByUserIds,
      engagedByUserIds: _importedByUserIds,
      dismissedByUserIds: _dismissedByUserIds,
      allowCollaboration: _allowCollaboration,
    );
  }
}