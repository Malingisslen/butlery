/// The search result card's action button, for someone who is BLOCKED.
///
/// BUT-2022. The card used to pick its button off `getFriendshipStatus`,
/// which answers `friends` / `requestSent` / `requestReceived` BEFORE it
/// answers `blocked`. A block whose cleanup has not finished — or failed —
/// therefore drew "Vänner" for a person who is blocked, and offered the
/// ordinary friend actions with them. Blocked is now asked first, on its own.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friends_list/search_result_card.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late MockFriendsViewModel friendsViewModel;

  const them = 'them-uid';
  final themProfile = UserProfile(
    uid: them,
    email: 'them@example.com',
    displayName: 'Björn Ek',
    joinedAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    friendsViewModel = MockFriendsViewModel();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) =>
              SearchResultCard.build(context, themProfile, friendsViewModel),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a blocked person gets the unblock action', (tester) async {
    friendsViewModel.setBlockedUsers({them});

    await pump(tester);

    expect(find.text('Avblockera'), findsOneWidget);
  });

  testWidgets(
    'blocked WINS over a friendship the cleanup has not cleared yet',
    (tester) async {
      // The state the reorder makes reachable: the block row is written, the
      // friendship removal has not landed. `getFriendshipStatus` answers
      // `friends` here — asking it first is the defect.
      friendsViewModel.setBlockedUsers({them});
      friendsViewModel.setFriendshipStatus(them, FriendshipStatus.friends);

      await pump(tester);

      expect(find.text('Avblockera'), findsOneWidget);
      expect(
        find.text('Vänner'),
        findsNothing,
        reason: 'a blocked person must not be offered the friend actions',
      );
    },
  );

  testWidgets('an ordinary friend still gets the friend button', (
    tester,
  ) async {
    // Control. Without it, a card that answered "Avblockera" for everyone
    // would satisfy both assertions above.
    friendsViewModel.setFriendshipStatus(them, FriendshipStatus.friends);

    await pump(tester);

    expect(find.text('Vänner'), findsOneWidget);
    expect(find.text('Avblockera'), findsNothing);
  });
}
