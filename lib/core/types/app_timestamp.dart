/// Comprehensive timestamp abstraction implementing platform-agnostic time management for cross-platform data consistency.
///
/// This timestamp abstraction serves as the foundational time representation throughout the Butlery application,
/// providing domain-agnostic time handling that eliminates direct Firebase dependencies from model classes while
/// maintaining efficient serialization and cross-platform compatibility. It ensures consistent time operations
/// across all application layers while supporting multiple time formats and providing comprehensive conversion
/// utilities for Swedish cooking application's time-sensitive features like recipe creation, sharing, and
/// collaborative editing timestamps.
///
/// ## Core Architecture Features
/// 
/// **Platform Independence**
/// - Domain-agnostic design eliminates direct Firebase Timestamp dependencies from models
/// - Consistent DateTime operations across all application layers and platforms
/// - Multiple factory constructors for different time sources and formats
/// - Clean separation between domain logic and platform-specific implementations
/// 
/// **Comprehensive Time Operations**
/// - Full DateTime functionality through convenient wrapper methods
/// - Duration-based arithmetic operations with immutable timestamp creation
/// - Comparison operations for time-based logic and sorting requirements
/// - Time component access for display formatting and calendar operations
/// 
/// **Multi-Format Serialization Support**
/// - Firestore Timestamp conversion for efficient database operations
/// - ISO string serialization for JSON APIs and human-readable formats
/// - Milliseconds epoch support for cross-platform timestamp exchange
/// - JSON serialization integration for caching and data persistence
/// 
/// ## Usage Examples
/// 
/// **Recipe Creation Timestamps:**
/// ```dart
/// class Recipe {
///   final AppTimestamp createdAt;
///   final AppTimestamp? lastModified;
///   
///   Recipe({
///     required this.createdAt,
///     this.lastModified,
///   });
///   
///   // Factory for new recipe creation
///   factory Recipe.create() {
///     return Recipe(
///       createdAt: AppTimestamp.now(),
///     );
///   }
///   
///   // Update timestamp when recipe is modified
///   Recipe updateContent() {
///     return Recipe(
///       createdAt: createdAt,
///       lastModified: AppTimestamp.now(),
///     );
///   }
/// }
/// ```
/// 
/// **Firestore Integration (Repository Layer):**
/// ```dart
/// class RecipeRepository {
///   Future<void> saveRecipe(Recipe recipe) async {
///     final data = {
///       'created_at': recipe.createdAt.toFirestore(),
///       'last_modified': recipe.lastModified?.toFirestore(),
///       // other fields...
///     };
///     await _firestore.collection('recipes').add(data);
///   }
///   
///   Recipe fromFirestoreDoc(DocumentSnapshot doc) {
///     final data = doc.data() as Map<String, dynamic>;
///     return Recipe(
///       createdAt: AppTimestamp.fromFirestore(data['created_at']),
///       lastModified: data['last_modified'] != null 
///         ? AppTimestamp.fromFirestore(data['last_modified'])
///         : null,
///     );
///   }
/// }
/// ```
/// 
/// **Time-Based Operations:**
/// ```dart
/// // Recipe aging and freshness calculations
/// bool isRecipeRecent(Recipe recipe) {
///   final weekAgo = AppTimestamp.now().subtract(Duration(days: 7));
///   return recipe.createdAt.isAfter(weekAgo);
/// }
/// 
/// // Sort recipes by creation time
/// recipes.sort((a, b) => a.createdAt.dateTime.compareTo(b.createdAt.dateTime));
/// 
/// // Calculate time since last modification
/// Duration timeSinceUpdate(Recipe recipe) {
///   final lastModified = recipe.lastModified ?? recipe.createdAt;
///   return AppTimestamp.now().difference(lastModified);
/// }
/// ```
/// 
/// **Cross-Platform Serialization:**
/// ```dart
/// // JSON API communication
/// Map<String, dynamic> recipeToJson(Recipe recipe) {
///   return {
///     'created_at': recipe.createdAt.toIsoString(),
///     'last_modified': recipe.lastModified?.toIsoString(),
///     // other fields...
///   };
/// }
/// 
/// // Local caching with milliseconds
/// Map<String, dynamic> recipeToCacheJson(Recipe recipe) {
///   return {
///     'created_at_ms': recipe.createdAt.toMilliseconds(),
///     'last_modified_ms': recipe.lastModified?.toMilliseconds(),
///   };
/// }
/// ```
/// 
/// **Swedish Localization Integration:**
/// ```dart
/// // Display formatting for Swedish users
/// String formatForSwedishDisplay(AppTimestamp timestamp) {
///   final dateTime = timestamp.dateTime;
///   return DateFormat('yyyy-MM-dd HH:mm', 'sv_SE').format(dateTime);
/// }
/// 
/// // Time-based recipe suggestions
/// bool isGoodTimeForBaking(AppTimestamp now) {
///   return now.hour >= 14 && now.hour <= 18; // Afternoon baking
/// }
/// ```
/// 
/// ## Performance Characteristics
/// 
/// - **Memory Efficiency**: Immutable value object with minimal memory footprint
/// - **Conversion Speed**: Direct DateTime operations without unnecessary transformations
/// - **Serialization Performance**: Optimized conversion methods for different target formats
/// - **Platform Compatibility**: Consistent behavior across iOS, Android, and web platforms
/// 
/// ## Integration Patterns
/// 
/// - **Model Layer**: Primary timestamp representation for all domain models
/// - **Repository Pattern**: Clean conversion between domain and persistence formats
/// - **API Integration**: Standardized time format handling for external communications
/// - **UI Layer**: Consistent time display and formatting throughout the application
/// 
/// This timestamp abstraction is essential for maintaining clean architecture boundaries
/// while providing comprehensive time management capabilities throughout the Swedish cooking
/// application's data layers and cross-platform operations.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Domain-agnostic timestamp abstraction that wraps platform-specific implementations
/// 
/// This abstraction allows models to be independent of Firebase Timestamp while
/// still supporting efficient serialization to/from Firestore.
class AppTimestamp {
  final DateTime _dateTime;

  const AppTimestamp._(this._dateTime);

  /// Create AppTimestamp from DateTime
  factory AppTimestamp.fromDateTime(DateTime dateTime) => 
      AppTimestamp._(dateTime);

  /// Create AppTimestamp from current time
  factory AppTimestamp.now() => 
      AppTimestamp._(DateTime.now());

  /// Create AppTimestamp from Firestore Timestamp (repository layer only)
  factory AppTimestamp.fromFirestore(Timestamp timestamp) => 
      AppTimestamp._(timestamp.toDate());

  /// Create AppTimestamp from milliseconds since epoch
  factory AppTimestamp.fromMilliseconds(int milliseconds) => 
      AppTimestamp._(DateTime.fromMillisecondsSinceEpoch(milliseconds));

  /// Create AppTimestamp from ISO string
  factory AppTimestamp.fromIsoString(String isoString) => 
      AppTimestamp._(DateTime.parse(isoString));

  /// Get underlying DateTime
  DateTime get dateTime => _dateTime;

  /// Convert to Firestore Timestamp (repository layer only)
  Timestamp toFirestore() => Timestamp.fromDate(_dateTime);

  /// Convert to milliseconds since epoch
  int toMilliseconds() => _dateTime.millisecondsSinceEpoch;

  /// Convert to ISO string
  String toIsoString() => _dateTime.toIso8601String();

  /// Convenience getters
  int get year => _dateTime.year;
  int get month => _dateTime.month;
  int get day => _dateTime.day;
  int get hour => _dateTime.hour;
  int get minute => _dateTime.minute;
  int get second => _dateTime.second;

  /// Comparison operators
  bool isBefore(AppTimestamp other) => _dateTime.isBefore(other._dateTime);
  bool isAfter(AppTimestamp other) => _dateTime.isAfter(other._dateTime);
  bool isAtSameMomentAs(AppTimestamp other) => _dateTime.isAtSameMomentAs(other._dateTime);

  /// Duration operations
  AppTimestamp add(Duration duration) => 
      AppTimestamp._(_dateTime.add(duration));
  
  AppTimestamp subtract(Duration duration) => 
      AppTimestamp._(_dateTime.subtract(duration));

  Duration difference(AppTimestamp other) => 
      _dateTime.difference(other._dateTime);

  /// Equality and hash
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppTimestamp && other._dateTime == _dateTime;
  }

  @override
  int get hashCode => _dateTime.hashCode;

  @override
  String toString() => _dateTime.toString();

  /// JSON serialization support
  Map<String, dynamic> toJson() => {
    'timestamp': _dateTime.millisecondsSinceEpoch,
  };

  /// JSON deserialization support
  factory AppTimestamp.fromJson(Map<String, dynamic> json) => 
      AppTimestamp.fromMilliseconds(json['timestamp'] as int);
}