// lib/models/social/reaction_type.dart

/// Enumeration of available reaction types for content interaction
/// 
/// This enum defines the complete set of emotional and functional reactions
/// users can express on various content types throughout the application.
/// Each reaction type has associated emoji representation and semantic meaning
/// optimized for food-related social interactions.
///
/// **Reaction Categories:**
/// - **Appreciation**: like, love, helpful - general positive feedback
/// - **Food-Specific**: delicious, easy, creative - culinary context reactions  
/// - **Social**: Designed for Swedish food culture and social cooking
///
/// **Usage Context:**
/// - Recipes: All reaction types appropriate for cooking feedback
/// - Comments: Appreciation and food-specific reactions for discussion
/// - Menus: Planning-focused reactions (helpful, easy, creative)
/// - Shopping Lists: Practical reactions (helpful, easy)
enum ReactionType {
  /// ❤️ Standard like reaction - universal positive feedback
  /// Replaces traditional thumbs-up for warmer social interaction
  like('like', '❤️', 'Gilla'),

  /// 😍 Love reaction - strong positive emotional response
  /// For content that generates excitement and admiration
  love('love', '😍', 'Älska'),

  /// 👍 Helpful reaction - practical value recognition
  /// For content that provides useful information or guidance
  helpful('helpful', '👍', 'Hjälpsam'),

  /// 😋 Delicious reaction - food-specific positive feedback
  /// For recipes and food content that looks appetizing
  delicious('delicious', '😋', 'Läcker'),

  /// ✨ Easy reaction - simplicity and accessibility appreciation
  /// For content that appears straightforward and manageable
  easy('easy', '✨', 'Enkel'),

  /// 💡 Creative reaction - innovation and originality recognition
  /// For content demonstrating unique ideas and creative approaches
  creative('creative', '💡', 'Kreativ');

  /// Internal identifier for database storage and API communication
  final String key;
  
  /// Emoji representation for UI display
  final String emoji;
  
  /// Swedish localized display name for user interface
  final String displayName;

  const ReactionType(this.key, this.emoji, this.displayName);

  /// Get ReactionType from database key
  static ReactionType fromKey(String key) {
    return ReactionType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => ReactionType.like, // Default fallback to like
    );
  }

  /// Get all reaction types as a list for UI iteration
  static List<ReactionType> get allTypes => ReactionType.values;

  /// Get food-specific reactions for culinary content
  static List<ReactionType> get foodReactions => [
    ReactionType.like,
    ReactionType.love,
    ReactionType.delicious,
    ReactionType.easy,
    ReactionType.creative,
  ];

  /// Get general reactions for non-food content
  static List<ReactionType> get generalReactions => [
    ReactionType.like,
    ReactionType.helpful,
    ReactionType.creative,
  ];

  /// Check if reaction is food-specific
  bool get isFoodSpecific => [
    ReactionType.delicious,
  ].contains(this);

  /// Get display text with emoji
  String get displayText => '$emoji $displayName';

  @override
  String toString() => key;
}