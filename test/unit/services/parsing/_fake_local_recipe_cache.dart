/// Test-only fake for [LocalRecipeCache] (BUT-1141).
///
/// Subclasses the production class so it can be passed via the
/// `RecipeParserService(cache: ...)` ctor seam shipped in BUT-1063, while
/// overriding the three Drift-touching methods (`init`, `get`, `set`) to
/// bypass the database layer entirely.
///
/// Why subclass instead of `implements`: `LocalRecipeCache` has internal
/// state (`_initialized`) and several public helpers (`generateCacheKey`,
/// `hashContent`, `clear`, `getStats`, `close`) we don't want to re-stub.
/// The ctor requires a `CacheDao`, but as long as our overrides never
/// delegate to `super`, the underlying `_cacheDao` is never touched —
/// so a never-called mock satisfies the type contract.
library;

import 'package:butlery/core/cache/cache_dao_interface.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/services/parsing/cache/local_recipe_cache.dart';
import 'package:mocktail/mocktail.dart';

/// A never-used [CacheDao] mock — only here to satisfy the ctor.
/// Any method call on this would indicate the fake leaked through to the
/// real DB path, which would be a bug in the fake's overrides.
class _NoopCacheDao extends Mock implements CacheDao {}

/// Behaviour-recording fake. See file header for design rationale.
class FakeLocalRecipeCache extends LocalRecipeCache {
  int initCallCount = 0;
  int getCallCount = 0;
  int setCallCount = 0;
  ParsedRecipe? lastSetRecipe;

  /// Recipe returned from [get] (subject to [storedVersion] gating).
  /// Defaults to null (cache miss).
  ParsedRecipe? storedRecipe;

  /// When true, [get] throws to drive the circuit-breaker.
  bool throwOnGet = false;

  /// When true, [set] throws.
  bool throwOnSet = false;

  /// When non-null AND != [parserVersion], [get] returns null (models the
  /// production version-mismatch invalidation in `LocalRecipeCache.get`).
  String? storedVersion;

  FakeLocalRecipeCache({
    super.parserVersion = '2.0.0',
    String userId = 'fake-user',
  }) : super(
         getCurrentUserId: () => userId,
         cacheDao: _NoopCacheDao(),
       );

  @override
  Future<void> init() async {
    initCallCount++;
    // Deliberately skip super — avoids touching _cacheDao.cleanupParseCache*.
  }

  @override
  Future<ParsedRecipe?> get({
    required String? urlHash,
    required String contentHash,
    required ImportSource source,
  }) async {
    getCallCount++;
    if (throwOnGet) {
      throw Exception('cache get failure');
    }
    if (storedVersion != null && storedVersion != parserVersion) {
      // Version mismatch — production cache invalidates and returns null.
      return null;
    }
    return storedRecipe;
  }

  @override
  Future<void> set({
    required String? urlHash,
    required String contentHash,
    required ImportSource source,
    required ParsedRecipe recipe,
  }) async {
    setCallCount++;
    lastSetRecipe = recipe;
    if (throwOnSet) {
      throw Exception('cache set failure');
    }
  }
}
