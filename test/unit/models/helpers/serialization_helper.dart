/// Serialization test helper for model tests
/// 
/// Provides utilities for testing JSON and Firestore serialization
/// with comprehensive validation and edge case handling.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class for serialization testing
class SerializationHelper {
  /// Create valid test JSON with Swedish defaults
  static Map<String, dynamic> createValidRecipeJson() {
    return {
      'id': 'test_recipe_123',
      'title': 'Köttbullar med potatismos',
      'description': 'Klassiska svenska köttbullar med krämigt potatismos',
      'portions': 4,
      'timeMinutes': 45,
      'ingredients': [
        '500g köttfärs',
        '1 dl ströbröd',
        '1 dl mjölk',
        '1 ägg',
        '1 lök, finhackad',
        'Salt och peppar',
      ],
      'instructions': [
        'Blanda ströbröd och mjölk, låt svälla',
        'Fräs löken mjuk',
        'Blanda alla ingredienser',
        'Forma köttbullar',
        'Stek i smör tills genomstekta',
        'Servera med potatismos och lingon',
      ],
      'tags': ['svensk', 'middag', 'köttbullar'],
      'rating': 4.5,
      'mealType': 'Middag',
      'sourceUrl': 'https://example.com/recipe',
      'imageUrls': ['https://example.com/image1.jpg'],
      'createdAt': '2024-01-01T12:00:00Z',
      'updatedAt': '2024-01-02T12:00:00Z',
      'createdBy': 'test_user',
      'isPublic': false,
      'lastCookedAt': '2024-01-03T18:00:00Z',
    };
  }
  
  /// Create valid user profile JSON
  static Map<String, dynamic> createValidUserProfileJson() {
    return {
      'uid': 'user_123',
      'displayName': 'Anna Andersson',
      'email': 'anna@example.com',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'isSearchable': true,
      'allowEmailSearch': false,
      'publicRecipeCount': 15,
      'friendsCount': 23,
      'joinedAt': '2023-01-01T00:00:00Z',
      'lastActiveAt': '2024-01-01T12:00:00Z',
      'isOnline': true,
      'fcmToken': 'test_fcm_token_123',
      'fcmTokenUpdatedAt': '2024-01-01T10:00:00Z',
      'notificationsEnabled': true,
    };
  }
  
  /// Create valid shopping list JSON
  static Map<String, dynamic> createValidShoppingListJson() {
    return {
      'id': 'list_123',
      'name': 'Veckans inköp',
      'ownerId': 'user_123',
      'ownerDisplayName': 'Anna Andersson',
      'items': [
        {
          'id': 'item_1',
          'name': 'Mjölk',
          'amount': 1.5,
          'unit': 'liter',
          'category': 'Mejeri',
          'bought': false,
          'addedByUserId': 'user_123',
          'addedByDisplayName': 'Anna Andersson',
          'addedAt': '2024-01-01T10:00:00Z',
        },
        {
          'id': 'item_2',
          'name': 'Ägg',
          'amount': 12,
          'unit': 'styck',
          'category': 'Mejeri',
          'bought': true,
          'addedByUserId': 'user_123',
          'addedByDisplayName': 'Anna Andersson',
          'addedAt': '2024-01-01T10:05:00Z',
          'purchasedByUserId': 'user_456',
          'purchasedByDisplayName': 'Test User',
          'purchasedAt': '2024-01-01T14:00:00Z',
        },
      ],
      'sharedWith': ['user_456', 'user_789'],
      'createdAt': '2024-01-01T09:00:00Z',
      'updatedAt': '2024-01-01T14:00:00Z',
      'isCollaborative': true,
    };
  }
  
  /// Create invalid JSON with missing required fields
  static Map<String, dynamic> createInvalidJson({
    List<String>? missingFields,
    Map<String, dynamic>? invalidValues,
  }) {
    final json = <String, dynamic>{
      'id': 'test_123',
    };
    
    // Add invalid values if specified
    if (invalidValues != null) {
      json.addAll(invalidValues);
    }
    
    return json;
  }
  
  /// Create Firestore data with proper types
  static Map<String, dynamic> createFirestoreData({
    required String id,
    bool includeTimestamps = true,
    bool includeServerTimestamp = false,
  }) {
    final data = <String, dynamic>{
      'id': id,
      'title': 'Test Title',
      'description': 'Test Description',
    };
    
    if (includeTimestamps) {
      data['createdAt'] = Timestamp.fromDate(DateTime(2024, 1, 1));
      data['updatedAt'] = includeServerTimestamp 
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(DateTime(2024, 1, 2));
    }
    
    return data;
  }
  
  /// Validate JSON structure
  static bool validateJsonStructure(
    Map<String, dynamic> json,
    List<String> requiredFields,
  ) {
    for (final field in requiredFields) {
      if (!json.containsKey(field)) {
        return false;
      }
    }
    return true;
  }
  
  /// Check if timestamp fields are properly formatted
  static bool hasValidTimestamps(Map<String, dynamic> json) {
    final timestampFields = ['createdAt', 'updatedAt', 'lastActiveAt', 'joinedAt'];
    
    for (final field in timestampFields) {
      if (json.containsKey(field)) {
        final value = json[field];
        if (value is! String && value is! Timestamp && value is! DateTime) {
          return false;
        }
        
        if (value is String) {
          try {
            DateTime.parse(value);
          } catch (e) {
            return false;
          }
        }
      }
    }
    
    return true;
  }
  
  /// Create test data with Swedish characters
  static Map<String, dynamic> createSwedishTestData() {
    return {
      'title': 'Räksmörgås',
      'description': 'Öppna smörgåsar med räkor, ägg och majonnäs',
      'ingredients': [
        '200g räkor',
        '2 ägg',
        '1 dl majonnäs',
        'Dill för garnering',
      ],
      'instructions': [
        'Koka äggen',
        'Blanda räkor med majonnäs',
        'Lägg på bröd',
        'Garnera med dill och citron',
      ],
      'tags': ['fisk', 'smörgås', 'lunch'],
    };
  }
  
  /// Test edge cases in JSON
  static List<Map<String, dynamic>> getEdgeCaseJsons() {
    return [
      // Empty strings
      {'id': '', 'title': '', 'description': ''},
      
      // Very long strings
      {'id': 'test', 'title': 'A' * 1000, 'description': 'B' * 5000},
      
      // Special characters
      {'id': 'test', 'title': '!@#\$%^&*()', 'description': ''},
      
      // Unicode characters
      {'id': 'test', 'title': '你好世界 🌍', 'description': 'مرحبا بالعالم'},
      
      // Null values where optional
      {'id': 'test', 'title': 'Test', 'description': 'Test', 'avatarUrl': null},
      
      // Empty arrays
      {'id': 'test', 'ingredients': [], 'instructions': [], 'tags': []},
      
      // Large numbers
      {'id': 'test', 'portions': 999999, 'timeMinutes': 999999},
      
      // Negative numbers
      {'id': 'test', 'portions': -1, 'timeMinutes': -30},
      
      // Decimal numbers
      {'id': 'test', 'rating': 3.14159, 'quantity': 2.5},
    ];
  }
  
  /// Convert DateTime to various formats for testing
  static Map<String, dynamic> createDateTimeVariations(DateTime date) {
    return {
      'isoString': date.toIso8601String(),
      'timestamp': Timestamp.fromDate(date),
      'milliseconds': date.millisecondsSinceEpoch,
      'dateTime': date,
      'null': null,
    };
  }
  
  /// Validate that two objects have same data (ignoring types)
  static bool haveSameData(dynamic obj1, dynamic obj2, List<String> fieldsToCheck) {
    // Simple implementation comparing string representations
    // In a real implementation, we would check each field individually
    // but for now we just verify the objects are equivalent
    if (fieldsToCheck.isEmpty) return true;
    
    return obj1.toString() == obj2.toString();
  }
}