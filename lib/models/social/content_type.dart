/// Reportable content types in the moderation system.
///
/// `wireName` is the persisted Firestore string (must stay stable —
/// `reports/*` documents in production carry these values). `fromWire`
/// returns null for unknown strings so legacy reports with retired
/// contentTypes (`'rating'`, `'shopping_list'`) don't crash the
/// moderator dashboard — they just get filtered out.
library;

enum ContentType {
  recipe('recipe'),
  comment('comment'),
  message('message'),
  profile('profile'),
  cookSnap('cook_snap'),
  group('group');

  const ContentType(this.wireName);

  final String wireName;

  /// Parse a Firestore-persisted contentType string. Returns null for
  /// unknown / legacy / retired values so callers can skip rather than
  /// throw.
  static ContentType? fromWire(String? wire) {
    if (wire == null) return null;
    for (final type in ContentType.values) {
      if (type.wireName == wire) return type;
    }
    return null;
  }
}
