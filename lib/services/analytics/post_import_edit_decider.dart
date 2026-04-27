/// Pure decision logic for the BUT-569 `post_import_edit` analytics event.
///
/// Extracted from [RecipePersistenceManager] so the rules — window check,
/// fromImport gate, tier_used inclusion — can be unit-tested without
/// spinning up the full form-viewmodel stack.
///
/// This helper makes no analytics calls and has no I/O; the caller emits the
/// event when [build] returns a non-null payload.
library;

/// Window length in days; mirrors [kPostImportEditWindowDays] but kept
/// independent so the helper has no upstream import.
const int _defaultWindowDays = 30;

class PostImportEditDecider {
  /// Returns event parameters for `post_import_edit`, or null if the event
  /// should NOT fire.
  ///
  /// Fires when ALL of the following hold:
  ///   - [fieldsChanged] is non-empty (a real edit happened)
  ///   - [sourceUrl] is non-empty (the recipe was imported)
  ///   - [now] - [importedAt] is in [0, windowDays]
  ///
  /// [tierUsed] is included only when non-empty — we don't pollute analytics
  /// with empty strings when the parse tier wasn't captured.
  static Map<String, Object>? build({
    required String recipeId,
    required List<String> fieldsChanged,
    required String? sourceUrl,
    required DateTime importedAt,
    required DateTime now,
    String? tierUsed,
    int windowDays = _defaultWindowDays,
  }) {
    if (fieldsChanged.isEmpty) return null;
    if (sourceUrl == null || sourceUrl.isEmpty) return null;

    final hoursSinceImport = now.difference(importedAt).inHours;
    if (hoursSinceImport < 0) return null; // Clock skew — ignore.
    if (hoursSinceImport > windowDays * 24) return null;

    return <String, Object>{
      'recipe_id': recipeId,
      'fields_changed': fieldsChanged.join(','),
      'hours_since_import': hoursSinceImport,
      if (tierUsed != null && tierUsed.isNotEmpty) 'tier_used': tierUsed,
    };
  }
}
