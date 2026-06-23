/// BUT-1207 widget gate for [CreateGroupDialog]'s draft restore + friend-id
/// resolution — the one beat the BUT-1203 pure codec test structurally cannot
/// reach. The codec proves encode/decode + the empty→remove-key rule; this
/// proves the *widget glue*: `_loadDraft` applying a decoded draft to the
/// controllers via setState, and resolving saved friend ids back to
/// UserProfiles through UnifiedFriendsService (dropping ids that no longer
/// resolve), plus save-on-keystroke under the byte-identical key.
///
/// Asserts data/persistence behaviour (field text + prefs values), not visual
/// appearance, so it needs no human visual verification.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/social/groups/create_group_dialog.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _MockFriendsService extends Mock implements UnifiedFriendsService {}

const _kDraftKey = 'group_creation_draft_v1';

UserProfile _profile(String uid, String displayName) {
  final now = DateTime(2026, 6, 4);
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: '$uid@example.com',
    joinedAt: now,
    lastActiveAt: now,
    isOnline: false,
  );
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

void main() {
  late _MockFriendsService mockFriends;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());

    mockFriends = _MockFriendsService();
    // Default: no friends. Overridden per-test where resolution matters.
    when(() => mockFriends.friendsList).thenReturn(const <UserProfile>[]);
    // The dialog's member-selector is a StreamBuilder over stateStream; it only
    // reads friendsList in its builder, so an empty stream is enough to render.
    when(
      () => mockFriends.stateStream,
    ).thenAnswer((_) => Stream<FriendsServiceState>.empty());
    TestServiceLocator.registerMock<UnifiedFriendsService>(mockFriends);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  testWidgets('restores name + description from a persisted draft on open', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _kDraftKey: jsonEncode({
        'name': 'Middagsklubben',
        'description': 'Tacos varje fredag',
        'emoji': '🌮',
        'friendIds': <String>[],
      }),
    });

    await tester.pumpWidget(_wrap(const CreateGroupDialog()));
    // _loadDraft is a post-frame async callback (SharedPreferences + setState).
    await tester.pumpAndSettle();

    expect(
      find.text('Middagsklubben'),
      findsOneWidget,
      reason: 'saved name must repopulate the name field on open',
    );
    expect(
      find.text('Tacos varje fredag'),
      findsOneWidget,
      reason: 'saved description must repopulate the description field',
    );
  });

  testWidgets('resolves saved friend ids to profiles, dropping unresolved ones', (
    tester,
  ) async {
    // Draft references two friends; only u1 is still in the friends list.
    when(
      () => mockFriends.friendsList,
    ).thenReturn([_profile('u1', 'Anna Andersson')]);
    SharedPreferences.setMockInitialValues({
      _kDraftKey: jsonEncode({
        'name': 'Bokklubben',
        'description': '',
        'emoji': '📚',
        'friendIds': ['u1', 'u_unfriended'],
      }),
    });

    await tester.pumpWidget(_wrap(const CreateGroupDialog()));
    await tester.pumpAndSettle();

    // The still-resolvable friend renders.
    expect(
      find.text('Anna Andersson'),
      findsWidgets,
      reason: 'a saved friend id that still resolves must be restored',
    );

    // Prove the DROP, not just the resolve: trigger a re-save (type a name) and
    // assert the persisted selection no longer carries the unresolved id. This
    // fails if _loadDraft retained 'u_unfriended' in _selectedFriendIds instead
    // of filtering it out — the assertion the resolve-positive check can't make.
    await tester.enterText(find.byType(TextField).first, 'Bokklubben 2');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final friendIds =
        (jsonDecode(prefs.getString(_kDraftKey)!) as Map)['friendIds'] as List;
    expect(
      friendIds,
      ['u1'],
      reason:
          'the unresolved id must be dropped from the selection, '
          'not silently retained',
    );
  });

  testWidgets('persists a draft to the byte-identical key on name keystroke', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(_wrap(const CreateGroupDialog()));
    await tester.pumpAndSettle();

    // The name field is the first text field in the dialog.
    await tester.enterText(find.byType(TextField).first, 'Löparklubben');
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDraftKey);
    expect(
      raw,
      isNotNull,
      reason: 'typing a name must persist the draft under the v1 key',
    );
    expect(jsonDecode(raw!)['name'], 'Löparklubben');
  });
}
