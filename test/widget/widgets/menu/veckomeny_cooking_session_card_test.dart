/// Widget tests for [VeckomenyCookingSessionCard] (BUT-1302).
///
/// The card is a presence indicator that merges per-group cooking-session
/// streams and HIDES ITSELF (`SizedBox.shrink`) whenever there's nothing to
/// show. `build` short-circuits through its guard clauses before it ever
/// renders the live `StreamBuilder`:
///   1. the `CookingSessionModule` isn't registered (`tryGet` → null), OR the
///      user isn't signed in (`currentUserId` → null),
///   2. the signed-in user belongs to no friend groups (`groups.isEmpty`),
///   3. (the happy path) at least one group exists → the `StreamBuilder`
///      delivers sessions and a [CookingSessionCard] renders (which itself
///      hides when the only live session is the current user's own).
///
/// Intent: these tests pin the hide-on-nothing contract (so the Veckomeny
/// header never shows empty presence chrome) AND prove the populated path
/// actually wires a friend's live session through to a rendered card.
///
/// Harness: the widget resolves `UnifiedFriendsService` (always) and
/// `CookingSessionModule` (optionally) from the PRODUCTION `ServiceLocator`,
/// which the real `DIContainer` reads off `GetIt.instance`. So we register
/// controllable fakes into GetIt, then bridge the production locator to it —
/// the established pattern from `shared_recipes_by_friend_view_test.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/unified/operations/cooking/cooking_session_module.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

/// Friends-service fake exposing only the surface the card reads:
/// `currentUserId` (the auth gate) and `categoriesList` (the group filter).
class _FakeFriendsService extends Fake implements UnifiedFriendsService {
  _FakeFriendsService({
    required this.userId,
    this.groups = const [],
  });

  final String? userId;
  final List<FriendCategory> groups;

  @override
  String? get currentUserId => userId;

  @override
  List<FriendCategory> get categoriesList => groups;
}

/// Cooking-session module fake. `watchGroupSessions` replays whatever sessions
/// the test seeds for each group id; the rest of the contract is unused by the
/// widget and intentionally left unimplemented.
class _FakeCookingSessionModule extends Fake implements CookingSessionModule {
  _FakeCookingSessionModule(this._sessionsByGroup);

  final Map<String, List<CookingSession>> _sessionsByGroup;

  @override
  Stream<List<CookingSession>> watchGroupSessions(String groupId) =>
      Stream<List<CookingSession>>.value(
        _sessionsByGroup[groupId] ?? const [],
      );
}

FriendCategory _group(String id, String ownerId) => FriendCategory(
      id: id,
      ownerId: ownerId,
      name: id,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

CookingSession _session({
  required String userId,
  required String userName,
  String recipeId = 'r1',
  String recipeTitle = 'Köttbullar',
}) =>
    CookingSession(
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      startedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      userId: userId,
      userName: userName,
    );

/// Register the fakes into GetIt and bridge the production locator. Pass
/// [module] = null to exercise the "module not registered" hide-branch.
void _wire({
  required UnifiedFriendsService friends,
  CookingSessionModule? module,
}) {
  GetIt.instance.registerSingleton<UnifiedFriendsService>(friends);
  if (module != null) {
    GetIt.instance.registerSingleton<CookingSessionModule>(module);
  }
  production.ServiceLocator.initialize(DIContainer());
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  tearDown(() async {
    await GetIt.instance.reset();
    production.ServiceLocator.reset();
  });

  group('VeckomenyCookingSessionCard hide-branches', () {
    testWidgets('hides itself when no CookingSessionModule is registered',
        (tester) async {
      _wire(
        friends: _FakeFriendsService(
          userId: 'me',
          groups: [_group('g1', 'me')],
        ),
        // module omitted → tryGet returns null → first guard fires.
      );

      await tester.pumpWidget(
        createLocalizedTestApp(child: const VeckomenyCookingSessionCard()),
      );
      await tester.pump();

      expect(find.byType(CookingSessionCard), findsNothing,
          reason: 'a missing CookingSessionModule must hide the card');
      expect(find.byType(StreamBuilder<List<CookingSession>>), findsNothing);
    });

    testWidgets('hides itself when there is no signed-in user', (tester) async {
      _wire(
        friends: _FakeFriendsService(userId: null),
        module: _FakeCookingSessionModule(const {}),
      );

      await tester.pumpWidget(
        createLocalizedTestApp(child: const VeckomenyCookingSessionCard()),
      );
      await tester.pump();

      expect(find.byType(CookingSessionCard), findsNothing,
          reason: 'a null currentUserId must hide the card');
      expect(find.byType(StreamBuilder<List<CookingSession>>), findsNothing);
    });

    testWidgets('hides itself when the user belongs to no friend groups',
        (tester) async {
      _wire(
        friends: _FakeFriendsService(
          userId: 'me',
          // A group owned by — and containing — someone else: the
          // owner/member filter excludes it, so groups resolves empty.
          groups: [_group('g1', 'someone-else')],
        ),
        module: _FakeCookingSessionModule(const {}),
      );

      await tester.pumpWidget(
        createLocalizedTestApp(child: const VeckomenyCookingSessionCard()),
      );
      await tester.pump();

      expect(find.byType(CookingSessionCard), findsNothing,
          reason: 'no matching groups must hide the card');
      expect(find.byType(StreamBuilder<List<CookingSession>>), findsNothing);
    });

    testWidgets(
        'builds the StreamBuilder but the inner card hides when the only '
        'live session is the current user', (tester) async {
      // The merged stream filters out the current user's own session, so the
      // StreamBuilder DOES build but hands an empty list to CookingSessionCard,
      // which collapses to SizedBox.shrink. Proves the live path renders
      // nothing when the only cook is you.
      _wire(
        friends: _FakeFriendsService(
          userId: 'me',
          groups: [_group('g1', 'me')],
        ),
        module: _FakeCookingSessionModule({
          'g1': [_session(userId: 'me', userName: 'Jag')],
        }),
      );

      await tester.pumpWidget(
        createLocalizedTestApp(child: const VeckomenyCookingSessionCard()),
      );
      await tester.pumpAndSettle();

      // The StreamBuilder is built (groups non-empty, stream non-null) ...
      expect(find.byType(StreamBuilder<List<CookingSession>>), findsOneWidget);
      // ... and the card widget exists but renders nothing (no presence line).
      expect(find.byType(CookingSessionCard), findsOneWidget);
      expect(find.textContaining('lagar'), findsNothing,
          reason: 'no peer session means no "<name> lagar <recipe>" line');
    });
  });

  group('VeckomenyCookingSessionCard populated StreamBuilder path', () {
    testWidgets(
        "renders a friend's live cooking session through the StreamBuilder",
        (tester) async {
      _wire(
        friends: _FakeFriendsService(
          userId: 'me',
          groups: [_group('g1', 'me')],
        ),
        module: _FakeCookingSessionModule({
          'g1': [_session(userId: 'erik', userName: 'Erik')],
        }),
      );

      await tester.pumpWidget(
        createLocalizedTestApp(child: const VeckomenyCookingSessionCard()),
      );
      // Two pumps drain the single-value stream into the StreamBuilder; we
      // deliberately avoid pumpAndSettle here — the rendered card carries a
      // looping PulseDot animation that never settles.
      await tester.pump();
      await tester.pump();

      expect(find.byType(StreamBuilder<List<CookingSession>>), findsOneWidget,
          reason: 'a non-empty group list builds the live StreamBuilder');
      expect(find.byType(CookingSessionCard), findsOneWidget,
          reason: 'the friend session flows into a rendered presence card');
      // The card composes "<name> lagar <recipe>" — assert Erik surfaces so we
      // know the friend session (not our own) reached the UI.
      expect(find.textContaining('Erik'), findsOneWidget,
          reason: "the friend's name must appear in the presence line");
    });
  });
}
