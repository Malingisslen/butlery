/// BUT-2249 (R8-6 = A, R8-7 = A): the public profile's friend button.
///
/// It draws "+ Lägg till vän" for someone with no relationship to you, and
/// otherwise the search result card's states. R8-7: that first state is only
/// offered when the profile is findable in search, and nothing is drawn
/// before the friends lists have loaded or on your own profile.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/social/public_profile_friend_button.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late MockFriendsViewModel friends;

  const them = 'them-uid';
  final themProfile = UserProfile(
    uid: them,
    email: 'them@example.com',
    displayName: 'Lovisa Renberg',
    joinedAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
  );

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    friends = MockFriendsViewModel();
    when(() => friends.currentUserId).thenReturn('me-uid');
  });

  Future<void> pump(
    WidgetTester tester, {
    bool isSearchable = true,
    bool friendsLoaded = true,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PublicProfileFriendButton(
          profile: themProfile,
          isSearchable: isSearchable,
          friends: friends,
          friendsLoaded: friendsLoaded,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('states, as the search result card', () {
    for (final (status, label) in [
      (FriendshipStatus.none, 'Lägg till vän'),
      (FriendshipStatus.requestSent, 'Skickad'),
      (FriendshipStatus.friends, 'Vänner'),
      (FriendshipStatus.requestReceived, 'Acceptera'),
      (FriendshipStatus.blocked, 'Avblockera'),
    ]) {
      testWidgets('$status draws "$label"', (tester) async {
        friends.setFriendshipStatus(them, status);

        await pump(tester);

        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('a block wins over a friendship not yet cleared (BUT-2022)', (
      tester,
    ) async {
      friends.setBlockedUsers({them});
      friends.setFriendshipStatus(them, FriendshipStatus.friends);

      await pump(tester);

      expect(find.text('Avblockera'), findsOneWidget);
      expect(find.text('Vänner'), findsNothing);
    });
  });

  group('R8-7: no relationship and not findable in search', () {
    testWidgets('draws no button', (tester) async {
      friends.setFriendshipStatus(them, FriendshipStatus.none);

      await pump(tester, isSearchable: false);

      expect(find.text('Lägg till vän'), findsNothing);
    });

    testWidgets('an existing relationship still shows, unsearchable or not', (
      tester,
    ) async {
      friends.setFriendshipStatus(them, FriendshipStatus.requestReceived);

      await pump(tester, isSearchable: false);

      expect(find.text('Acceptera'), findsOneWidget);
    });
  });

  testWidgets('nothing before the friends lists have loaded', (tester) async {
    friends.setFriendshipStatus(them, FriendshipStatus.none);

    await pump(tester, friendsLoaded: false);

    expect(find.text('Lägg till vän'), findsNothing);
  });

  testWidgets('nothing on your own profile', (tester) async {
    when(() => friends.currentUserId).thenReturn(them);
    friends.setFriendshipStatus(them, FriendshipStatus.none);

    await pump(tester);

    expect(find.text('Lägg till vän'), findsNothing);
  });

  testWidgets('"+ Lägg till vän" sends the request to this person', (
    tester,
  ) async {
    friends.setFriendshipStatus(them, FriendshipStatus.none);
    when(
      () => friends.sendFriendRequest(them, message: any(named: 'message')),
    ).thenAnswer((_) async => true);

    await pump(tester);
    await tester.tap(find.text('Lägg till vän'));
    await tester.pumpAndSettle();

    verify(
      () => friends.sendFriendRequest(them, message: any(named: 'message')),
    ).called(1);
  });

  testWidgets('Acceptera accepts the request from this person', (tester) async {
    friends.setFriendshipStatus(them, FriendshipStatus.requestReceived);
    when(() => friends.incomingRequests).thenReturn([
      FriendRequest(id: 'req-1', fromUserId: them, toUserId: 'me-uid'),
    ]);
    when(
      () => friends.acceptFriendRequest(any()),
    ).thenAnswer((_) async => true);

    await pump(tester);
    await tester.tap(find.text('Acceptera'));
    await tester.pumpAndSettle();

    verify(() => friends.acceptFriendRequest('req-1')).called(1);
  });

  testWidgets('Avblockera unblocks this person after the confirmation', (
    tester,
  ) async {
    friends.setBlockedUsers({them});
    when(() => friends.unblockUser(any())).thenAnswer((_) async => true);

    await pump(tester);
    await tester.tap(find.text('Avblockera'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avblockera').last);
    await tester.pumpAndSettle();

    verify(() => friends.unblockUser(them)).called(1);
  });
}
