/// BUT-1736 (AC1, third persister): the display name a collaborative recipe
/// writes must be the PROFILE name, never the Firebase Auth handle.
///
/// [RecipeCollaborativeManager] was outside BUT-1736's declared fileset
/// (`lib/services/realtime/*`) and was widened into it during the sprint, so it
/// shipped the fix with no test of its own — this file closes that. It is the
/// live writer of a realtime recipe's `ownerDisplayName` and of
/// `realtime_recipes/{id}/presence/{uid}.displayName`, which is rewritten every
/// 30 seconds and which every co-editor reads.
///
/// The Auth handle is the legal name on the user's Google/Apple account: never
/// chosen for display, and invisible to the systems that maintain such copies.
/// `on-profile-updated.ts` propagates the PROFILE name; the deletion cascade
/// removes only the `realtime_recipes` a user OWNS, and scrubs
/// `lastEditedByDisplayName` nowhere (BUT-1768). A profile-sourced name is
/// therefore reachable by at least one of those; an Auth-sourced one by
/// neither. The two sources are kept visibly distinct below: the fake
/// permission service carries `'Auth Handle'`, and any assertion seeing that
/// string has caught the regression.
library;

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_collaborative_manager.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// Keeps the two name sources apart so a test can prove WHICH one is persisted.
class _FakeUserService extends Fake implements UserService {
  _FakeUserService(this.profileName);

  String? profileName;

  @override
  String? get profileDisplayName => profileName;
}

/// Captures what the manager hands the repository, and keeps the realtime
/// listeners inert so the test observes the write rather than the sync loop.
class _CapturingCollaborativeRepository extends Fake
    implements CollaborativeRecipeRepository {
  RealtimeRecipe? created;
  final List<String> presenceNames = <String>[];

  @override
  Future<void> createRealtimeRecipe(RealtimeRecipe recipe) async {
    created = recipe;
  }

  @override
  Future<void> updateRealtimeRecipe(RealtimeRecipe recipe) async {}

  @override
  Stream<RealtimeRecipe?> getRealtimeRecipeStream(String id) =>
      const Stream<RealtimeRecipe?>.empty();

  @override
  Stream<List<LiveEditor>> getParticipantsStream(String id) =>
      const Stream<List<LiveEditor>>.empty();

  @override
  Future<void> updateUserPresence(
    String recipeId,
    String userId,
    String displayName,
  ) async {
    presenceNames.add(displayName);
  }

  @override
  Future<void> clearUserPresence(String recipeId, String userId) async {}
}

void main() {
  late RecipeCollaborativeManager manager;
  late _CapturingCollaborativeRepository repository;
  late FakePermissionService permissionService;
  late MockConnectivityMonitoringService connectivityService;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    // The persisted name resolves through the production ServiceLocator, so the
    // container has to exist before a UserService can be registered into it.
    production.ServiceLocator.initialize(DIContainer());

    repository = _CapturingCollaborativeRepository();

    permissionService = FakePermissionService();
    permissionService.setPermissionState(
      currentUserId: 'user-123',
      defaultHasPermission: true,
      userDisplayName: 'Auth Handle',
    );

    connectivityService = MockConnectivityMonitoringService();
    when(() => connectivityService.startMonitoring()).thenReturn(null);
    when(() => connectivityService.addListener(any())).thenReturn(null);
    when(() => connectivityService.removeListener(any())).thenReturn(null);
    when(() => connectivityService.isConnectedToFirebase).thenReturn(true);
    when(() => connectivityService.connectionStatusText).thenReturn('Ansluten');
  });

  tearDown(() async {
    manager.dispose();
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  void registerUserService(String? profileName) {
    if (GetIt.instance.isRegistered<UserService>()) {
      GetIt.instance.unregister<UserService>();
    }
    GetIt.instance.registerSingleton<UserService>(
      _FakeUserService(profileName),
    );
    manager = RecipeCollaborativeManager(
      permissionService: permissionService,
      collaborativeRepository: repository,
      connectivityService: connectivityService,
    );
  }

  test(
    'a resolved profile name is what gets persisted, not the Auth handle',
    () async {
      registerUserService('Profil Malin');

      await manager.enableCollaborativeMode(RecipeBuilder().build());

      expect(repository.created, isNotNull);
      expect(repository.created!.ownerDisplayName, equals('Profil Malin'));
      expect(
        repository.created!.ownerDisplayName,
        isNot(equals('Auth Handle')),
        reason:
            'The Auth handle is the unconsented, un-erasable source BUT-1736 '
            'removed from every persister.',
      );
    },
  );

  test('an EMPTY profile falls back to the localized unknown-user label, '
      'never to the Auth handle', () async {
    registerUserService(null);

    await manager.enableCollaborativeMode(RecipeBuilder().build());

    expect(repository.created, isNotNull);
    expect(
      repository.created!.ownerDisplayName,
      equals(AppLocale.current.displayUnknownUser),
    );
    expect(
      repository.created!.ownerDisplayName,
      isNot(equals('Auth Handle')),
      reason:
          'An unresolved profile name is exactly the case where the old code '
          'reached for the Auth handle — the fallback must not restore it.',
    );
  });

  /// The presence document is the OTHER writer, and the higher-frequency one:
  /// `realtime_recipes/{id}/presence/{uid}.displayName` is rewritten every 30
  /// seconds for as long as the form is open, and is what co-editors see live.
  /// It resolves the name independently of the create path, so proving the
  /// create stamp says nothing about it.
  ///
  /// The 30-second timer is not what is driven here: `_updatePresence` returns
  /// early while `_isCollaborative` is still false, so the enable-time call is
  /// a no-op by construction. `reconnectToFirebase()` re-runs the same presence
  /// start AFTER the flag is set — the real reconnection path, and the first
  /// moment presence is actually written.
  test('the presence heartbeat writes the profile name too', () async {
    registerUserService('Profil Malin');

    await manager.enableCollaborativeMode(RecipeBuilder().build());
    await manager.reconnectToFirebase();

    expect(
      repository.presenceNames,
      isNotEmpty,
      reason:
          'No presence write happened — the assertion below would be '
          'vacuous.',
    );
    expect(repository.presenceNames, everyElement(equals('Profil Malin')));
    expect(repository.presenceNames, isNot(contains('Auth Handle')));
  });
}
