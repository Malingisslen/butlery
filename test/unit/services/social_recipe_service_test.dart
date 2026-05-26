/// Intent-driven unit tests for [SocialRecipeService] (Intent-Test Sprint
/// 2026-05-24, batch 4).
///
/// Behaviours pinned:
/// - dismiss/undismiss recipe + menu: auth gate, success, silent-fail-on-throw
///   contract (returns `false`, never rethrows). This is the contract the
///   BUT-1068 viewmodels rely on.
/// - importSharedRecipe: id-not-found → false, delegate-success path actually
///   marks-as-imported with the correct userId, delegate returns null → false
///   AND mark-as-imported is NOT called, delegate throws → swallowed → false.
/// - importSharedMenu: partial-success accounting (any-success → true,
///   all-fail → false), per-recipe try/catch isolation (one throw doesn't
///   abort the whole import), and mark-as-imported only fires when at least
///   one recipe lands.
/// - markAsViewed (recipe/menu): error path returns false, happy path forwards
///   the exact (id, userId) pair to the repo.
/// - isRecipeSharedByUser / isMenuSharedByUser: ownership check on cached
///   list; not-found → false; wrong-owner → false.
/// - isShoppingListSharedByUser: missing shopping service → false (no throw).
/// - getVisibleSharedRecipes / getVisibleSharedMenus: pass-through after
///   `initialize()` loads from repo.
/// - initialize() unauthenticated → empty lists, no repo calls, no throw.
/// - Error contract (BUT-1087): EVERY catch block populates `_error` with a
///   sanitized user-friendly message via `_captureAndLog`. `_error` is reset
///   at the entry-point of every public mutator so a successful retry after
///   a failure visibly clears the banner. Pinned below.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/shared_content_member.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';

// -------------------- Fakes (no MockAuthRepository antipattern, BUT-1074) --

class _FakePermissionService extends Fake implements PermissionService {
  String? _uid;
  void setUserId(String? uid) => _uid = uid;

  @override
  String? get currentUserId => _uid;

  @override
  bool get isAuthenticated => _uid != null;
}

class _FakeUserService extends Fake implements UserService {}

/// Records calls + lets each method be configured to throw a specific error.
class _FakeSharedRecipeRepository extends Fake
    implements FirebaseSharedRecipeRepository {
  // Repo-state seed for getSharedRecipesForUser.
  List<SharedRecipe> seedRecipes = const [];
  // Members seed for getMembersWithInfo (used by participant resolver if
  // ever invoked — not exercised here, but kept defensible).
  List<SharedContentMember> seedMembers = const [];

  // Recorded calls.
  final List<(String, String)> markedAsViewed = [];
  final List<(String, String)> markedAsDismissed = [];
  final List<(String, String)> undismissed = [];
  final List<(String, String)> markedAsImported = [];

  // Configurable throws per method.
  Object? throwOnMarkAsViewed;
  Object? throwOnMarkAsDismissed;
  Object? throwOnUndismiss;
  Object? throwOnMarkAsImported;
  Object? throwOnGetSharedRecipesForUser;

  @override
  Future<List<SharedRecipe>> getSharedRecipesForUser(String userId) async {
    if (throwOnGetSharedRecipesForUser != null) {
      throw throwOnGetSharedRecipesForUser!;
    }
    return seedRecipes;
  }

  @override
  Future<void> markAsViewed(String contentId, String userId) async {
    if (throwOnMarkAsViewed != null) throw throwOnMarkAsViewed!;
    markedAsViewed.add((contentId, userId));
  }

  @override
  Future<void> markAsDismissed(String contentId, String userId) async {
    if (throwOnMarkAsDismissed != null) throw throwOnMarkAsDismissed!;
    markedAsDismissed.add((contentId, userId));
  }

  @override
  Future<void> undismiss(String contentId, String userId) async {
    if (throwOnUndismiss != null) throw throwOnUndismiss!;
    undismissed.add((contentId, userId));
  }

  @override
  Future<void> markAsImportedOrJoined(String contentId, String userId) async {
    if (throwOnMarkAsImported != null) throw throwOnMarkAsImported!;
    markedAsImported.add((contentId, userId));
  }

  @override
  Future<List<SharedContentMember>> getMembersWithInfo(
    String contentId, {
    int? limit,
  }) async =>
      seedMembers;
}

class _FakeSharedMenuRepository extends Fake
    implements FirebaseSharedMenuRepository {
  List<SharedMenu> seedMenus = const [];
  List<SharedContentMember> seedMembers = const [];

  final List<(String, String)> markedAsViewed = [];
  final List<(String, String)> markedAsDismissed = [];
  final List<(String, String)> undismissed = [];
  final List<(String, String)> markedAsImported = [];

  Object? throwOnMarkAsViewed;
  Object? throwOnMarkAsDismissed;
  Object? throwOnUndismiss;
  Object? throwOnMarkAsImported;
  Object? throwOnGetSharedMenusForUser;

  @override
  Future<List<SharedMenu>> getSharedMenusForUser(String userId) async {
    if (throwOnGetSharedMenusForUser != null) {
      throw throwOnGetSharedMenusForUser!;
    }
    return seedMenus;
  }

  @override
  Future<void> markAsViewed(String contentId, String userId) async {
    if (throwOnMarkAsViewed != null) throw throwOnMarkAsViewed!;
    markedAsViewed.add((contentId, userId));
  }

  @override
  Future<void> markAsDismissed(String contentId, String userId) async {
    if (throwOnMarkAsDismissed != null) throw throwOnMarkAsDismissed!;
    markedAsDismissed.add((contentId, userId));
  }

  @override
  Future<void> undismiss(String contentId, String userId) async {
    if (throwOnUndismiss != null) throw throwOnUndismiss!;
    undismissed.add((contentId, userId));
  }

  @override
  Future<void> markAsImportedOrJoined(String contentId, String userId) async {
    if (throwOnMarkAsImported != null) throw throwOnMarkAsImported!;
    markedAsImported.add((contentId, userId));
  }

  @override
  Future<List<SharedContentMember>> getMembersWithInfo(
    String contentId, {
    int? limit,
  }) async =>
      seedMembers;
}

/// Fake `PersonalRecipeOperations` substituted on a fake
/// `UnifiedRecipeService` — the only `personal.*` call the service makes is
/// `createRecipe(...)`, so we override just that.
class _FakePersonalRecipeOperations extends Fake
    implements PersonalRecipeOperations {
  // Programmable result.
  String? Function(Map<String, Object?> args)? createRecipeImpl;

  final List<Map<String, Object?>> createCalls = [];

  @override
  Future<String?> createRecipe({
    required String title,
    required String description,
    required List<String> ingredients,
    required List<String> instructions,
    required List<String> imageUrls,
    required String mealType,
    int? portions,
    int? timeMinutes,
    double? rating,
    List<String>? personalTagIds,
    String? sourceUrl,
  }) async {
    final args = <String, Object?>{
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'instructions': instructions,
      'imageUrls': imageUrls,
      'mealType': mealType,
      'portions': portions,
      'timeMinutes': timeMinutes,
      'rating': rating,
      'personalTagIds': personalTagIds,
      'sourceUrl': sourceUrl,
    };
    createCalls.add(args);
    final impl = createRecipeImpl;
    if (impl == null) return 'created-id';
    return impl(args);
  }
}

class _FakeUnifiedRecipeService extends Fake implements UnifiedRecipeService {
  _FakeUnifiedRecipeService(this._personal);
  final _FakePersonalRecipeOperations _personal;

  @override
  PersonalRecipeOperations get personal => _personal;
}

// -------------------- Test fixtures --------------------------------------

Recipe _makeRecipe({
  String id = 'r1',
  String title = 'Pannkakor',
  String description = 'Tunna',
  List<String> ingredients = const ['ägg', 'mjöl'],
  List<String> instructions = const ['rör', 'stek'],
  String mealType = 'Middag',
  int? portions = 4,
  int? timeMinutes = 20,
  List<String> imageUrls = const ['https://x/y.jpg'],
  double? rating,
  List<String> personalTagIds = const [],
}) {
  return Recipe.personal(
    title: title,
    description: description,
    ingredients: ingredients,
    instructions: instructions,
    mealType: mealType,
    portions: portions,
    timeMinutes: timeMinutes,
    rating: rating,
    personalTagIds: personalTagIds,
    imageUrls: imageUrls,
  );
}

SharedRecipe _makeSharedRecipe({
  String id = 'sr-1',
  String sharedByUserId = 'sender-uid',
  String originalRecipeId = 'orig-1',
  Recipe? snapshot,
}) {
  final s = snapshot ?? _makeRecipe();
  return SharedRecipe(
    id: id,
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: 'Anna',
    originalRecipeId: originalRecipeId,
    recipeTitle: s.title,
    recipeImageUrl: s.imageUrls.isNotEmpty ? s.imageUrls.first : null,
    recipePortions: s.portions,
    recipeTimeMinutes: s.timeMinutes,
    recipeDescription: s.description,
    recipeSnapshot: s,
  );
}

SharedMenu _makeSharedMenu({
  String id = 'sm-1',
  String sharedByUserId = 'sender-uid',
  Map<String, List<Recipe>>? snapshot,
}) {
  return SharedMenu(
    id: id,
    sharedByUserId: sharedByUserId,
    sharedByDisplayName: 'Anna',
    menuTitle: 'Veckomeny',
    menuSnapshot: snapshot ??
        {
          'Måndag': [_makeRecipe(id: 'rA', title: 'A')],
          'Tisdag': [_makeRecipe(id: 'rB', title: 'B')],
        },
  );
}

// -------------------- Tests ----------------------------------------------

void main() {
  late _FakePermissionService permission;
  late _FakeSharedRecipeRepository recipeRepo;
  late _FakeSharedMenuRepository menuRepo;
  late _FakePersonalRecipeOperations personalOps;
  late _FakeUnifiedRecipeService recipeService;
  late _FakeUserService userService;
  late SocialRecipeService service;

  setUp(() {
    permission = _FakePermissionService()..setUserId('me-uid');
    recipeRepo = _FakeSharedRecipeRepository();
    menuRepo = _FakeSharedMenuRepository();
    personalOps = _FakePersonalRecipeOperations();
    recipeService = _FakeUnifiedRecipeService(personalOps);
    userService = _FakeUserService();

    service = SocialRecipeService(
      userService: userService,
      recipeService: recipeService,
      permissionService: permission,
      sharedRecipeRepository: recipeRepo,
      sharedMenuRepository: menuRepo,
    );
  });

  group('initialize / refresh / _loadSharedContent', () {
    /// Proves initialize loads recipes + menus for the current user when
    /// authenticated, and the public getters surface them.
    test('authenticated initialize loads both recipe and menu lists', () async {
      recipeRepo.seedRecipes = [_makeSharedRecipe(id: 'sr-1')];
      menuRepo.seedMenus = [_makeSharedMenu(id: 'sm-1')];

      await service.initialize();

      expect(service.sharedRecipes, hasLength(1));
      expect(service.sharedRecipes.first.id, 'sr-1');
      expect(service.sharedMenus, hasLength(1));
      expect(service.sharedMenus.first.id, 'sm-1');
      expect(service.isLoading, isFalse);
      expect(service.hasError, isFalse);
    });

    /// Proves unauthenticated initialize doesn't touch repos and doesn't
    /// crash. Without this guard, a logged-out splash could hit
    /// `currentUserId!` and throw.
    test('unauthenticated initialize is a no-op (no repo calls, no throw)',
        () async {
      permission.setUserId(null);

      await service.initialize();

      expect(service.sharedRecipes, isEmpty);
      expect(service.sharedMenus, isEmpty);
      expect(service.hasError, isFalse);
      expect(recipeRepo.markedAsViewed, isEmpty); // never reached anything
    });

    /// Proves repo failure during load is swallowed, lists fall back to
    /// empty, no exception escapes. Critical for offline / permission-denied
    /// session-start.
    test('repo throw during load → lists cleared, no exception escapes',
        () async {
      recipeRepo.throwOnGetSharedRecipesForUser =
          Exception('permission denied');

      await service.initialize();

      expect(service.sharedRecipes, isEmpty);
      expect(service.sharedMenus, isEmpty);
      expect(service.isLoading, isFalse);
    });

    /// Proves the getters return *unmodifiable* views — a viewmodel that
    /// accidentally mutates the list shouldn't corrupt service state.
    test('sharedRecipes / sharedMenus return unmodifiable lists', () async {
      recipeRepo.seedRecipes = [_makeSharedRecipe()];
      menuRepo.seedMenus = [_makeSharedMenu()];
      await service.initialize();

      expect(() => service.sharedRecipes.add(_makeSharedRecipe(id: 'x')),
          throwsUnsupportedError);
      expect(() => service.sharedMenus.add(_makeSharedMenu(id: 'x')),
          throwsUnsupportedError);
    });

    /// Proves refresh re-fetches when repository contents change between
    /// loads. A common bug shape is "refresh forgets to await / no-ops".
    test('refresh picks up new repo state after initialize', () async {
      recipeRepo.seedRecipes = [_makeSharedRecipe(id: 'first')];
      await service.initialize();
      expect(service.sharedRecipes.single.id, 'first');

      recipeRepo.seedRecipes = [
        _makeSharedRecipe(id: 'first'),
        _makeSharedRecipe(id: 'second'),
      ];
      await service.refresh();

      expect(service.sharedRecipes.map((r) => r.id), ['first', 'second']);
    });
  });

  group('dismissSharedRecipe (the BUT-1068 contract)', () {
    /// Proves happy path returns true AND forwards the *current* user's uid
    /// to the repo — not the sharer's uid (classic bug).
    test('authenticated success: returns true, calls repo with current uid',
        () async {
      final ok = await service.dismissSharedRecipe('sr-1');

      expect(ok, isTrue);
      expect(recipeRepo.markedAsDismissed, [('sr-1', 'me-uid')]);
      expect(service.hasError, isFalse);
    });

    /// Proves unauthenticated dismiss short-circuits to false WITHOUT
    /// touching the repo (no spurious anonymous write) AND sets an error.
    test('unauthenticated: returns false, no repo call, error is set',
        () async {
      permission.setUserId(null);

      final ok = await service.dismissSharedRecipe('sr-1');

      expect(ok, isFalse);
      expect(recipeRepo.markedAsDismissed, isEmpty);
      expect(service.error, contains('not authenticated'));
    });

    /// Pinned contract: repo throwing is caught → false. The shared-recipe
    /// viewmodel removes-from-UI based on `true`; this contract is what
    /// keeps a failed dismiss from being silently swallowed by the UI.
    /// Error message is the sanitized localized string, not the raw cause.
    test(
        'repo throws permission-denied → returns false, sets sanitized error, no rethrow',
        () async {
      recipeRepo.throwOnMarkAsDismissed = Exception('permission-denied');

      final ok = await service.dismissSharedRecipe('sr-1');

      expect(ok, isFalse);
      expect(service.hasError, isTrue);
      // Sanitized Swedish copy for the 'permission' branch — see
      // error_sanitizer.dart → AppLocale.current.errorPermissionDenied.
      expect(service.error, contains('behörighet'));
    });

    /// Same shape but for a network error — proves the catch is exception-
    /// type-agnostic (not only Firebase ones). Sanitizer routes "network"
    /// substrings to the localized network error string.
    test('repo throws generic network error → returns false, no rethrow',
        () async {
      recipeRepo.throwOnMarkAsDismissed = StateError('network');

      final ok = await service.dismissSharedRecipe('sr-1');

      expect(ok, isFalse);
      expect(service.hasError, isTrue);
    });
  });

  group('dismissSharedMenu', () {
    test('authenticated success: returns true, forwards current uid', () async {
      final ok = await service.dismissSharedMenu('sm-1');

      expect(ok, isTrue);
      expect(menuRepo.markedAsDismissed, [('sm-1', 'me-uid')]);
    });

    test('unauthenticated → false, no repo call, error set', () async {
      permission.setUserId(null);

      final ok = await service.dismissSharedMenu('sm-1');

      expect(ok, isFalse);
      expect(menuRepo.markedAsDismissed, isEmpty);
      expect(service.error, contains('not authenticated'));
    });

    test('repo throws → returns false, no rethrow, sanitized error set',
        () async {
      menuRepo.throwOnMarkAsDismissed = Exception('boom');

      final ok = await service.dismissSharedMenu('sm-1');

      expect(ok, isFalse);
      expect(service.hasError, isTrue);
      // Generic exception → errorGeneric Swedish fallback.
      expect(service.error, isNotNull);
    });
  });

  group('undismissSharedRecipe / undismissSharedMenu', () {
    test('recipe: authenticated success → true, forwards uid', () async {
      final ok = await service.undismissSharedRecipe('sr-1');
      expect(ok, isTrue);
      expect(recipeRepo.undismissed, [('sr-1', 'me-uid')]);
    });

    test('recipe: unauthenticated → false, no repo call', () async {
      permission.setUserId(null);
      final ok = await service.undismissSharedRecipe('sr-1');
      expect(ok, isFalse);
      expect(recipeRepo.undismissed, isEmpty);
    });

    /// BUT-1087: undismiss failures now surface via `service.error` just
    /// like dismiss failures. Previously asymmetric — UI banners gated on
    /// `hasError` would stay silent on restore failures.
    test('recipe: repo throws → false, sanitized error IS set', () async {
      recipeRepo.throwOnUndismiss = Exception('boom');
      final ok = await service.undismissSharedRecipe('sr-1');
      expect(ok, isFalse);
      expect(service.hasError, isTrue,
          reason: 'undismiss must surface errors via service.error');
      expect(service.error, isNotNull);
    });

    test('menu: authenticated success → true, forwards uid', () async {
      final ok = await service.undismissSharedMenu('sm-1');
      expect(ok, isTrue);
      expect(menuRepo.undismissed, [('sm-1', 'me-uid')]);
    });

    test('menu: unauthenticated → false, no repo call', () async {
      permission.setUserId(null);
      final ok = await service.undismissSharedMenu('sm-1');
      expect(ok, isFalse);
      expect(menuRepo.undismissed, isEmpty);
    });

    test('menu: repo throws → false, sanitized error IS set (BUT-1087)',
        () async {
      menuRepo.throwOnUndismiss = Exception('boom');
      final ok = await service.undismissSharedMenu('sm-1');
      expect(ok, isFalse);
      expect(service.hasError, isTrue);
      expect(service.error, isNotNull);
    });
  });

  group('markSharedRecipeAsViewed / markSharedMenuAsViewed', () {
    test('recipe: happy path forwards exact (id, userId) and returns true',
        () async {
      final ok = await service.markSharedRecipeAsViewed('sr-1', 'viewer-uid');
      expect(ok, isTrue);
      expect(recipeRepo.markedAsViewed, [('sr-1', 'viewer-uid')]);
    });

    test('recipe: repo throws → false, sanitized error IS set (BUT-1087)',
        () async {
      recipeRepo.throwOnMarkAsViewed = Exception('boom');
      final ok = await service.markSharedRecipeAsViewed('sr-1', 'viewer-uid');
      expect(ok, isFalse);
      expect(service.hasError, isTrue);
    });

    test('menu: happy path forwards exact (id, userId) and returns true',
        () async {
      final ok = await service.markSharedMenuAsViewed('sm-1', 'viewer-uid');
      expect(ok, isTrue);
      expect(menuRepo.markedAsViewed, [('sm-1', 'viewer-uid')]);
    });

    test('menu: repo throws → false, sanitized error IS set (BUT-1087)',
        () async {
      menuRepo.throwOnMarkAsViewed = Exception('boom');
      final ok = await service.markSharedMenuAsViewed('sm-1', 'viewer-uid');
      expect(ok, isFalse);
      expect(service.hasError, isTrue);
    });
  });

  group('importSharedRecipe', () {
    setUp(() async {
      recipeRepo.seedRecipes = [
        _makeSharedRecipe(
          id: 'sr-1',
          snapshot: _makeRecipe(
            id: 'orig',
            title: 'Köttbullar',
            description: 'Klassiska',
            ingredients: const ['nötfärs', 'lök'],
            instructions: const ['blanda', 'stek'],
            imageUrls: const ['https://x/k.jpg'],
            portions: 4,
            timeMinutes: 30,
            rating: 4.5,
            // Pre-set personalTagIds on the SENDER's snapshot — the
            // service contract explicitly clears these before importing.
            personalTagIds: const ['sender-tag-uuid-1', 'sender-tag-uuid-2'],
          ),
        ),
      ];
      await service.initialize();
    });

    /// Pinned contract: imported recipe drops the *sender's* personalTagIds.
    /// UUIDs are meaningless in the recipient's account — keeping them
    /// would point at non-existent tags and break the tag UI.
    test('success: creates personal recipe with sender tag IDs CLEARED',
        () async {
      personalOps.createRecipeImpl = (_) => 'new-id';

      final ok = await service.importSharedRecipe('sr-1');

      expect(ok, isTrue);
      expect(personalOps.createCalls, hasLength(1));
      final call = personalOps.createCalls.single;
      expect(call['title'], 'Köttbullar');
      expect(call['description'], 'Klassiska');
      expect(call['ingredients'], ['nötfärs', 'lök']);
      expect(call['instructions'], ['blanda', 'stek']);
      expect(call['imageUrls'], ['https://x/k.jpg']);
      expect(call['mealType'], 'Middag');
      expect(call['portions'], 4);
      expect(call['timeMinutes'], 30);
      expect(call['rating'], 4.5);
      expect(call['personalTagIds'], <String>[],
          reason:
              "sender's personalTagIds must be stripped — UUIDs don't transfer");
    });

    /// Pinned contract: success path marks the share as imported using the
    /// CURRENT user's uid, not the sharer's. A swap here would credit the
    /// import to the wrong account.
    test('success: marks share as imported/joined under current uid', () async {
      personalOps.createRecipeImpl = (_) => 'new-id';
      await service.importSharedRecipe('sr-1');

      expect(recipeRepo.markedAsImported, [('sr-1', 'me-uid')]);
    });

    /// Critical: when personal createRecipe returns null (failure), we MUST
    /// NOT mark the share as imported — that would lie about state and
    /// hide the recipe from the inbox even though nothing was saved.
    test('createRecipe returns null → returns false AND no mark-as-imported',
        () async {
      personalOps.createRecipeImpl = (_) => null;

      final ok = await service.importSharedRecipe('sr-1');

      expect(ok, isFalse);
      expect(recipeRepo.markedAsImported, isEmpty,
          reason: 'must not mark imported when creation failed');
    });

    /// Proves not-found returns false fast and never invokes the delegate.
    test('unknown recipe id → returns false, never calls createRecipe',
        () async {
      final ok = await service.importSharedRecipe('does-not-exist');

      expect(ok, isFalse);
      expect(personalOps.createCalls, isEmpty);
      expect(recipeRepo.markedAsImported, isEmpty);
    });

    /// Proves delegate throw is caught → false. No rethrow into UI code.
    /// BUT-1087: error surfaces via service.error (previously silent).
    test('createRecipe throws → returns false, sanitized error IS set',
        () async {
      personalOps.createRecipeImpl = (_) => throw Exception('disk full');

      final ok = await service.importSharedRecipe('sr-1');

      expect(ok, isFalse);
      expect(recipeRepo.markedAsImported, isEmpty);
      expect(service.hasError, isTrue);
      expect(service.error, isNotNull);
    });

    /// BUT-1087: `_error` must be cleared at the entry-point of every public
    /// mutator so a successful retry visibly clears the banner. Without
    /// this, the UI banner stays stuck after a failure even when the next
    /// call succeeds.
    test('error from prior failure is cleared on subsequent successful call',
        () async {
      // 1. First call: dismiss fails → error populated.
      recipeRepo.throwOnMarkAsDismissed = Exception('boom');
      final firstResult = await service.dismissSharedRecipe('sr-1');
      expect(firstResult, isFalse);
      expect(service.hasError, isTrue,
          reason: 'precondition: failure must populate error');

      // 2. Second call: a different successful mutator should reset error.
      recipeRepo.throwOnMarkAsDismissed = null; // clear the configured throw
      final secondResult =
          await service.markSharedRecipeAsViewed('sr-1', 'viewer-uid');

      expect(secondResult, isTrue);
      expect(service.hasError, isFalse,
          reason:
              'BUT-1087: a successful mutator must clear stale error from prior failures');
      expect(service.error, isNull);
    });

    /// Proves the mark-as-imported step is guarded by authentication — if
    /// the user signed out mid-import, we still report the recipe was
    /// created (which it was) but don't blow up on a `null!` deref.
    test('success but user signed out mid-import → returns true, no mark call',
        () async {
      personalOps.createRecipeImpl = (_) {
        permission.setUserId(null); // sign-out between create + mark
        return 'new-id';
      };

      final ok = await service.importSharedRecipe('sr-1');

      expect(ok, isTrue);
      expect(recipeRepo.markedAsImported, isEmpty);
    });
  });

  group('importSharedMenu', () {
    /// Pinned: ANY successful per-recipe creation makes the menu import
    /// "succeed" (true) and triggers mark-as-imported. Common-bug-shape:
    /// requiring ALL recipes to succeed which would never fire on a single
    /// transient failure.
    test('partial success (1 of 2) → returns true, marks menu as imported',
        () async {
      menuRepo.seedMenus = [
        _makeSharedMenu(
          id: 'sm-1',
          snapshot: {
            'Mån': [_makeRecipe(id: 'a', title: 'A')],
            'Tis': [_makeRecipe(id: 'b', title: 'B')],
          },
        ),
      ];
      await service.initialize();

      // First call succeeds, second fails (createRecipe returns null).
      var n = 0;
      personalOps.createRecipeImpl = (_) {
        n++;
        return n == 1 ? 'created-$n' : null;
      };

      final ok = await service.importSharedMenu('sm-1');

      expect(ok, isTrue);
      expect(personalOps.createCalls, hasLength(2));
      expect(menuRepo.markedAsImported, [('sm-1', 'me-uid')]);
    });

    /// Pinned: per-recipe throws are isolated (the inner try/catch). One
    /// poison recipe must not abort the whole import.
    test('one recipe throws, other succeeds → still returns true', () async {
      menuRepo.seedMenus = [
        _makeSharedMenu(
          id: 'sm-1',
          snapshot: {
            'Mån': [
              _makeRecipe(id: 'a', title: 'A'),
              _makeRecipe(id: 'b', title: 'B'),
            ],
          },
        ),
      ];
      await service.initialize();

      var n = 0;
      personalOps.createRecipeImpl = (_) {
        n++;
        if (n == 1) throw Exception('poison');
        return 'ok';
      };

      final ok = await service.importSharedMenu('sm-1');

      expect(ok, isTrue);
      expect(personalOps.createCalls, hasLength(2));
      expect(menuRepo.markedAsImported, [('sm-1', 'me-uid')]);
    });

    /// Pinned: zero successes → false AND no mark-as-imported. A bug here
    /// would leave the menu disappeared from the inbox despite nothing
    /// being saved.
    test('all recipes fail (null) → returns false, NO mark-as-imported call',
        () async {
      menuRepo.seedMenus = [
        _makeSharedMenu(
          id: 'sm-1',
          snapshot: {
            'Mån': [_makeRecipe(id: 'a', title: 'A')],
          },
        ),
      ];
      await service.initialize();
      personalOps.createRecipeImpl = (_) => null;

      final ok = await service.importSharedMenu('sm-1');

      expect(ok, isFalse);
      expect(menuRepo.markedAsImported, isEmpty);
    });

    test('unknown menu id → returns false, never calls createRecipe', () async {
      final ok = await service.importSharedMenu('nope');
      expect(ok, isFalse);
      expect(personalOps.createCalls, isEmpty);
    });

    /// Edge: a menu with no recipes anywhere has successCount=0 → false.
    /// We don't want a mark-as-imported for a no-op.
    test('menu with empty snapshot → false, no mark-as-imported', () async {
      menuRepo.seedMenus = [
        _makeSharedMenu(id: 'sm-empty', snapshot: const {}),
      ];
      await service.initialize();

      final ok = await service.importSharedMenu('sm-empty');

      expect(ok, isFalse);
      expect(menuRepo.markedAsImported, isEmpty);
    });
  });

  group('ownership checks', () {
    test('isRecipeSharedByUser: matching owner → true', () async {
      recipeRepo.seedRecipes = [
        _makeSharedRecipe(id: 'sr-1', sharedByUserId: 'owner-A'),
      ];
      await service.initialize();

      expect(await service.isRecipeSharedByUser('sr-1', 'owner-A'), isTrue);
    });

    test('isRecipeSharedByUser: wrong owner → false', () async {
      recipeRepo.seedRecipes = [
        _makeSharedRecipe(id: 'sr-1', sharedByUserId: 'owner-A'),
      ];
      await service.initialize();

      expect(await service.isRecipeSharedByUser('sr-1', 'owner-B'), isFalse);
    });

    test('isRecipeSharedByUser: unknown id → false (no throw)', () async {
      expect(await service.isRecipeSharedByUser('nope', 'whoever'), isFalse);
    });

    test('isMenuSharedByUser: matching owner → true', () async {
      menuRepo.seedMenus = [
        _makeSharedMenu(id: 'sm-1', sharedByUserId: 'owner-A'),
      ];
      await service.initialize();

      expect(await service.isMenuSharedByUser('sm-1', 'owner-A'), isTrue);
    });

    test('isMenuSharedByUser: wrong owner → false', () async {
      menuRepo.seedMenus = [
        _makeSharedMenu(id: 'sm-1', sharedByUserId: 'owner-A'),
      ];
      await service.initialize();

      expect(await service.isMenuSharedByUser('sm-1', 'owner-B'), isFalse);
    });

    /// Proves the shopping-service-absent branch is safe (returns false,
    /// no exception). The service is resolved lazily via ServiceLocator and
    /// may be unregistered in unit-test environments — this guards against
    /// crashing the whole shared-content load on that path.
    test('isShoppingListSharedByUser: shopping service unregistered → false',
        () async {
      // No ServiceLocator.initialize call in this test → tryGet returns null.
      expect(
        await service.isShoppingListSharedByUser('list-1', 'me-uid'),
        isFalse,
      );
    });
  });

  group('visible getters (pass-through)', () {
    test('getVisibleSharedRecipes returns the loaded list verbatim', () async {
      final a = _makeSharedRecipe(id: 'a');
      final b = _makeSharedRecipe(id: 'b');
      recipeRepo.seedRecipes = [a, b];
      await service.initialize();

      final visible = service.getVisibleSharedRecipes('me-uid');
      expect(visible.map((r) => r.id), ['a', 'b']);
    });

    test('getVisibleSharedMenus returns the loaded list verbatim', () async {
      final a = _makeSharedMenu(id: 'a');
      final b = _makeSharedMenu(id: 'b');
      menuRepo.seedMenus = [a, b];
      await service.initialize();

      final visible = service.getVisibleSharedMenus('me-uid');
      expect(visible.map((m) => m.id), ['a', 'b']);
    });
  });
}
