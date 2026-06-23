import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

/// BUT-202: Cooking-mode ingredient substitution suggestions.
///
/// Deterministic (no LLM): normalizes input through [IngredientLookupService]
/// to obtain a canonical ingredient ID, then fetches substitutes from
/// `ingredient_substitutions/{canonicalIngredientId}`. Returns up to 3 rows,
/// empty list when no lookup match or no doc.
class SubstitutionSuggestionService extends BaseService {
  final FirestoreRepository _firestoreRepository;
  final IngredientLookupService _lookupService;

  /// Upper bound on suggestions returned to the UI (sheet renders max 3 rows).
  static const int _maxResults = 3;

  /// LRU cache for hot ingredients; 50 entries is plenty for a single session
  /// (typical recipe has <20 ingredients). Uses LinkedHashMap insertion order
  /// — no timestamp dependency, so tests don't need fake clocks for the cache.
  static const int _cacheMaxSize = 50;
  final Map<String, List<IngredientSubstitution>> _cache = {};

  static const String _firestoreCollection = 'ingredient_substitutions';

  SubstitutionSuggestionService({
    required FirestoreRepository firestoreRepository,
    required IngredientLookupService lookupService,
  }) : _firestoreRepository = firestoreRepository,
       _lookupService = lookupService;

  @override
  String get serviceName => 'SubstitutionSuggestionService';

  /// Returns up to 3 substitutes for [ingredientName]. Never throws — a
  /// missing lookup, missing doc, or Firestore failure all resolve to `[]`.
  Future<List<IngredientSubstitution>> suggestFor(String ingredientName) async {
    final key = ingredientName.trim().toLowerCase();
    if (key.isEmpty) return const [];

    if (_cache.containsKey(key)) {
      // Promote to MRU position (remove + re-insert keeps insertion order).
      final value = _cache.remove(key)!;
      _cache[key] = value;
      return value;
    }

    final result = await _fetch(ingredientName);
    _store(key, result);
    return result;
  }

  /// Test helper — not part of the public contract. Exposed so fakes can
  /// assert "2nd call hit the cache" by inspecting cache presence.
  int get cacheSize => _cache.length;

  /// Clears the in-memory LRU cache (e.g. on logout).
  void clearSuggestionCache() {
    _cache.clear();
  }

  Future<List<IngredientSubstitution>> _fetch(String ingredientName) async {
    try {
      // The ingredient lookup itself touches Firestore (it lazily loads the
      // global ingredient cache via a one-shot `.get()`), and on a cold offline
      // cache that read can throw `unavailable` instead of returning data. This
      // call sits INSIDE the try so a lookup failure resolves to `[]` like every
      // other failure — otherwise the exception escapes `suggestFor` (violating
      // its "never throws" contract) and crashes the cooking-mode substitution
      // tap, which has no try/catch of its own.
      final lookup = await _lookupService.lookupFromRaw([ingredientName]);
      if (lookup.matched.isEmpty) return const [];

      final canonicalId = lookup.matched.first.id;

      final doc = await _firestoreRepository.firestore
          .collection(_firestoreCollection)
          .doc(canonicalId)
          .get();

      if (!doc.exists) return const [];

      final data = doc.data();
      if (data == null) return const [];

      final raw = data['substitutes'];
      if (raw is! List) return const [];

      final parsed = <IngredientSubstitution>[];
      for (final entry in raw) {
        if (entry is Map<String, dynamic>) {
          parsed.add(IngredientSubstitution.fromMap(entry));
        } else if (entry is Map) {
          // Firestore sometimes returns Map<Object?, Object?> on web builds.
          parsed.add(
            IngredientSubstitution.fromMap(
              entry.map((k, v) => MapEntry(k.toString(), v)),
            ),
          );
        }
        if (parsed.length >= _maxResults) break;
      }
      return List.unmodifiable(parsed);
    } catch (e) {
      AppLogger.warning(
        'BUT-202: substitution fetch failed for "$ingredientName" '
        '(offline cold cache or Firestore error): $e',
        serviceName,
      );
      return const [];
    }
  }

  void _store(String key, List<IngredientSubstitution> value) {
    _cache.remove(key);
    while (_cache.length >= _cacheMaxSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }
}
