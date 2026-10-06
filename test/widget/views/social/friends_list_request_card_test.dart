// The incoming request under "Hitta vänner" says who sent it. The request
// carries only the sender's uid, so the card gets the name from the profiles
// the view model loads for its requests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friends_list/friends_list_cards.dart';
import 'package:butlery/views/social/friends_list/requests_tab.dart';

class _MockFriendsVm extends Mock implements FriendsViewModel {}

class _NotifyingFriendsVm extends Mock
    with ChangeNotifier
    implements FriendsViewModel {}

UserProfile _erik() {
  final now = DateTime.utc(2026, 10, 5, 9);
  return UserProfile(
    uid: 'erik',
    displayName: 'Erik Sandell',
    email: 'erik@example.com',
    joinedAt: now,
    lastActiveAt: now,
  );
}

FriendRequest _request() => FriendRequest(
  id: 'r1',
  fromUserId: 'erik',
  toUserId: 'me',
  sentAt: DateTime.utc(2026, 10, 5, 9),
);

Future<void> _pump(WidgetTester tester, UserProfile? sender) {
  final vm = _MockFriendsVm();
  when(() => vm.getUserProfile('erik')).thenReturn(sender);
  when(() => vm.getDisplayNameForUser(any())).thenReturn('Laddar…');
  final request = FriendRequest(
    id: 'r1',
    fromUserId: 'erik',
    toUserId: 'me',
    sentAt: DateTime.utc(2026, 10, 5, 9),
  );
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: Builder(
          builder: (context) => FriendRequestCard.build(context, request, vm),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the card names the sender from the profile the view model holds',
    (
      tester,
    ) async {
      final now = DateTime.utc(2026, 10, 5, 9);
      await _pump(
        tester,
        UserProfile(
          uid: 'erik',
          displayName: 'Erik Sandell',
          email: 'erik@example.com',
          joinedAt: now,
          lastActiveAt: now,
        ),
      );

      expect(find.text('Erik Sandell'), findsOneWidget);
    },
  );

  testWidgets(
    'before the profile loads it says "Vänförfrågan", not a placeholder name',
    (
      tester,
    ) async {
      await _pump(tester, null);

      expect(find.text('Vänförfrågan'), findsOneWidget);
      expect(find.text('Laddar…'), findsNothing);
    },
  );

  testWidgets('the request tab shows the name when it loads after the card', (
    tester,
  ) async {
    final vm = _NotifyingFriendsVm();
    UserProfile? sender;
    when(() => vm.incomingRequests).thenReturn([_request()]);
    when(() => vm.sentRequests).thenReturn(const <FriendRequest>[]);
    when(() => vm.getUserProfile('erik')).thenAnswer((_) => sender);
    when(() => vm.getDisplayNameForUser(any())).thenReturn('Laddar…');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: ChangeNotifierProvider<FriendsViewModel>.value(
            value: vm,
            child: const RequestsTab(),
          ),
        ),
      ),
    );
    expect(find.text('Vänförfrågan'), findsOneWidget);

    sender = _erik();
    vm.notifyListeners();
    await tester.pump();

    expect(find.text('Erik Sandell'), findsOneWidget);
  });
}
