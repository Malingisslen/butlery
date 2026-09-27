/// P7-C3: social failures say what failed, never the exception's text.
///
/// The error contract (content-style-guide.md:87-97) puts the cause in the
/// user's words and the technical error in the log (:95). Before package 7
/// these handlers passed `'$e'` into keys such as groupCouldNotLeave
/// ("Kunde inte lämna grupp: {error}") and errorOccurredWithDetails, so a
/// Firestore or GetIt message reached the screen. They now show a
/// placeholder-free key through SnackBarUtils.showFailure, which always
/// carries "Stäng".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friends_list/search_result_card.dart';
import 'package:butlery/views/social/group_detail/group_detail_actions.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _rawText = 'permission-denied: RAW_EXCEPTION_TEXT';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  testWidgets(
    'search result: a throwing friend request shows the cause and Stäng, '
    'not the exception',
    (tester) async {
      final viewModel = MockFriendsViewModel();
      final person = UserProfile(
        uid: 'them-uid',
        email: 'them@example.com',
        displayName: 'Björn Ek',
        joinedAt: DateTime(2026),
        lastActiveAt: DateTime(2026),
      );
      viewModel.setFriendshipStatus(person.uid, FriendshipStatus.none);
      when(
        () => viewModel.sendFriendRequest(
          any(),
          message: any(named: 'message'),
        ),
      ).thenThrow(Exception(_rawText));

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) =>
                SearchResultCard.build(context, person, viewModel),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skicka vänförfrågan'));
      await tester.pumpAndSettle();

      expect(find.text('Kunde inte skicka vänförfrågan'), findsOneWidget);
      expect(find.text('Stäng'), findsOneWidget);
      expect(find.textContaining('RAW_EXCEPTION_TEXT'), findsNothing);
      expect(find.textContaining('Ett fel uppstod'), findsNothing);
    },
  );

  group('group detail: leaving fails', () {
    late MockUnifiedFriendsService friendsService;

    setUp(() {
      final categories = MockFriendsCategoriesOperations();
      when(
        () => categories.removeFriendFromCategory(any(), any()),
      ).thenThrow(Exception(_rawText));
      friendsService = MockUnifiedFriendsService()
        ..setFriendsState(categories: categories);
      TestServiceLocator.registerMock<UnifiedFriendsService>(friendsService);
      TestServiceLocator.registerMock<PermissionService>(
        FakePermissionService()..setPermissionState(currentUserId: 'me'),
      );
    });

    testWidgets('shows what failed and Stäng, not the exception', (
      tester,
    ) async {
      final group = FriendCategory(
        id: 'group-1',
        ownerId: 'owner',
        name: 'Grannarna',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => GroupDetailActions.leaveGroup(context, group),
              child: const Text('Öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Öppna'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lämna'));
      await tester.pumpAndSettle();

      expect(find.text('Det gick inte att lämna gruppen.'), findsOneWidget);
      expect(find.text('Stäng'), findsOneWidget);
      expect(find.textContaining('RAW_EXCEPTION_TEXT'), findsNothing);
      expect(find.textContaining('Kunde inte lämna grupp:'), findsNothing);
    });
  });
}
