/// P8-U01 hosts: recipe detail (two rows) and the recipe editor (three).
///
/// The service wiring is the one of
/// test/widget/views/recipe_detail/recipe_detail_conflict_test.dart and
/// test/widget/views/p5_error_views_test.dart.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/recipe/recipe_cooking_service.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/recipe_detail_view.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../state_harness.dart';
import '../state_host.dart';

const _me = 'test-user-123';

class _FakeCookSnaps extends Fake implements CookSnapService {
  @override
  Stream<List<CookSnap>> watchCookSnaps(String recipeId, {int limit = 20}) =>
      Stream.value(const <CookSnap>[]);
}

class _MockRealtime extends Mock implements RealtimeSyncService {}

class _MockOverwritten extends Mock implements OverwrittenVersionService {}

class _MockSuggestions extends Mock implements RecipeSuggestionService {}

/// A snapshot of one side of a conflict: the fields and who wrote them.
class _Side extends Fake implements RealtimeResource {
  _Side(this._fields, this.lastEditedByDisplayName);

  final Map<String, dynamic> _fields;

  @override
  final String lastEditedByDisplayName;

  @override
  Map<String, dynamic> toFirestore() => _fields;

  @override
  RealtimeResource copyWithMetadata({
    Map<String, ResourcePermission>? participants,
    List<String>? participantIds,
    DateTime? lastEditedAt,
    String? lastEditedBy,
    String? lastEditedByDisplayName,
    int? editCount,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) => _Side(
    _fields,
    lastEditedByDisplayName ?? this.lastEditedByDisplayName,
  );
}

Recipe _recipe() => RecipeFactory.build(
  id: 'recipe-linsgryta',
  title: 'Linsgryta med kokos och koriander',
  createdBy: _me,
  ingredients: [
    '3 dl röda linser',
    '1 burk kokosmjölk',
    '1 gul lök',
    '2 vitlöksklyftor',
    '1 kruka koriander',
  ],
  instructions: [
    'Fräs löken och vitlöken mjuk i olja.',
    'Tillsätt linser, kokosmjölk och två deciliter vatten.',
    'Låt puttra i tjugo minuter och toppa med koriander.',
  ],
);

StreamController<ConflictEvent> _realtime(HostContext ctx) {
  final conflicts = StreamController<ConflictEvent>.broadcast();
  ctx.disposers.add(() => unawaited(conflicts.close()));
  final realtime = _MockRealtime();
  when(() => realtime.conflictStream).thenAnswer((_) => conflicts.stream);
  TestServiceLocator.registerMock<RealtimeSyncService>(realtime);
  final overwritten = _MockOverwritten();
  when(
    () => overwritten.watch(
      entity: any(named: 'entity'),
      resourceId: any(named: 'resourceId'),
    ),
  ).thenAnswer((_) => Stream.value(const <OverwrittenVersion>[]));
  TestServiceLocator.registerMock<OverwrittenVersionService>(overwritten);
  final suggestions = _MockSuggestions();
  when(
    () => suggestions.watchMine(any()),
  ).thenAnswer((_) => Stream.value(const <RecipeSuggestion>[]));
  when(
    () => suggestions.watchPendingToMe(any()),
  ).thenAnswer((_) => Stream.value(const <RecipeSuggestion>[]));
  TestServiceLocator.registerMock<RecipeSuggestionService>(suggestions);
  return conflicts;
}

Widget _detail(HostContext ctx) {
  final recipe = _recipe();
  final recipes = MockUnifiedRecipeService()
    ..setRecipeState(recipes: [recipe], isInitialized: true);
  when(
    () => recipes.toggleFavorite(any(), any()),
  ).thenAnswer((_) async => true);
  TestServiceLocator.registerMock<UnifiedRecipeService>(recipes);
  TestServiceLocator.registerMock<RecipeCookingService>(
    MockFactory.createRecipeCookingService(),
  );
  final users = MockUserService();
  when(
    () => users.allergenPreferences,
  ).thenReturn(UserAllergenPreferences.defaults);
  when(() => users.addListener(any())).thenReturn(null);
  when(() => users.removeListener(any())).thenReturn(null);
  TestServiceLocator.registerMock<UserService>(users);
  final social = MockSocialRecipeViewModel();
  when(social.initialize).thenAnswer((_) async {});
  when(() => social.refreshComments(any())).thenAnswer((_) async {});
  when(() => social.topLevelComments).thenReturn(const <RecipeComment>[]);
  TestServiceLocator.registerMock<SocialRecipeViewModel>(social);
  TestServiceLocator.registerMock<CookSnapService>(_FakeCookSnaps());
  _realtime(ctx);
  return RecipeDetailView(recipe: recipe);
}

Widget _editor(HostContext ctx) {
  final auth = MockFactory.createAuthService(
    isAuthenticated: true,
    userId: _me,
  );
  TestServiceLocator.registerMock<AuthService>(auth);
  TestServiceLocator.registerMock<PermissionService>(
    MockFactory.createPermissionService(currentUserId: _me),
  );
  TestServiceLocator.registerMock<SocialRecipeService>(
    MockFactory.createSocialRecipeService(),
  );
  TestServiceLocator.registerFactory<CollaborativeStatusViewModel>(
    CollaborativeStatusViewModel.new,
  );
  TestServiceLocator.registerMock<ImageUploadService>(ImageUploadService());
  final tags = MockPersonalTagService();
  TestServiceLocator.registerMock<PersonalTagService>(tags);
  TestServiceLocator.registerFactory<PersonalTagViewModel>(
    () => PersonalTagViewModel(service: tags),
  );
  _conflicts[ctx] = _realtime(ctx);
  return EditRecipeView(recipe: _recipe());
}

/// The conflict stream each pumped editor listens to.
final _conflicts = Expando<StreamController<ConflictEvent>>();

ConflictEvent _ownConflict() => ConflictEvent(
  collectionPath: 'recipes',
  docId: 'recipe-linsgryta',
  localValue: _Side({
    'title': 'Linsgryta med kokos och koriander',
    'portions': 4,
  }, 'Malin'),
  remoteValue: _Side({
    'title': 'Linsgryta med kokos, lime och koriander',
    'portions': 6,
  }, 'Per'),
  chosenStrategy: ConflictResolutionStrategy.remoteWon,
  entity: ConflictEntity.recipeOwn,
  occurredAt: DateTime.utc(2026, 9, 23, 18),
);

final recipeHosts = <String, StateHost>{
  'receptdetalj::DEFAULT': StateHost(build: (ctx) async => _detail(ctx)),
  // BEVIS is RecipeManagementHandler, a handler with no screen of its own;
  // the recipe it acts on is shown by RecipeDetailView.
  'receptdetalj::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _detail(ctx),
  ),
  'recepteditor::DEFAULT': StateHost(build: (ctx) async => _editor(ctx)),
  'recepteditor::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _editor(ctx),
  ),
  // Own recipe: "Båda versionerna visas, användaren väljer"
  // (produktregler.md:102). The banner's Visa opens the two versions.
  'recepteditor::CONFLICT': StateHost(
    build: (ctx) async => _editor(ctx),
    reach: (tester, ctx) async {
      _conflicts[ctx]!.add(_ownConflict());
      await tester.pump();
      await tester.pump();
      final view = find.text(sv.commonView);
      if (view.evaluate().isNotEmpty) {
        await tester.ensureVisible(view.first);
        await tester.tap(view.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    },
  ),
};
