// The incoming request under "Vänförfrågningar" says who sent it. The request
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
import 'package:butlery/views/social/friend_requests/friend_request_card.dart';
import 'package:butlery/views/social/friend_requests/friend_request_builders.dart';

class _MockFriendsVm extends Mock implements FriendsViewModel {}

late _MockFriendsVm _lastVm;

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

Future<void> _pump(
  WidgetTester tester,
  UserProfile? sender, {
  bool accepting = false,
}) {
  final vm = _lastVm = _MockFriendsVm();
  when(() => vm.getUserProfile('erik')).thenReturn(sender);
  when(() => vm.getDisplayNameForUser(any())).thenReturn('Laddar…');
  when(() => vm.isLoading).thenReturn(false);
  when(() => vm.isAccepting(any())).thenReturn(false);
  when(() => vm.isAccepting('r1')).thenReturn(accepting);
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
        body: SingleChildScrollView(
          child: Builder(
            builder: (context) => FriendRequestCard.buildIncomingCard(
              context,
              request,
              vm,
              false,
              (_) {},
            ),
          ),
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

  testWidgets('a sent card without a loaded recipient profile says '
      '"Vänförfrågan", not a placeholder name', (tester) async {
    final vm = _MockFriendsVm();
    when(() => vm.getUserProfile('recipient')).thenReturn(null);
    when(() => vm.getDisplayNameForUser(any())).thenReturn('Laddar…');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => FriendRequestCard.buildSentCard(
                context,
                FriendRequest(
                  id: 's1',
                  fromUserId: 'me',
                  toUserId: 'recipient',
                  sentAt: DateTime.utc(2026, 10, 5, 9),
                ),
                vm,
                false,
                (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vänförfrågan'), findsOneWidget);
    expect(find.text('Laddar…'), findsNothing);
  });

  testWidgets('while the accept runs the card says so and takes no tap', (
    tester,
  ) async {
    await _pump(tester, _erik(), accepting: true);

    expect(find.text('Accepterar …'), findsOneWidget);
    expect(find.text('Acceptera'), findsNothing);
    await tester.tap(find.text('Accepterar …'));
    await tester.pump();
    verifyNever(() => _lastVm.acceptFriendRequest(any()));
  });

  testWidgets('before the accept runs, both actions take a tap', (
    tester,
  ) async {
    await _pump(tester, _erik());

    expect(find.text('Acceptera'), findsOneWidget);
    expect(find.text('Avböj'), findsOneWidget);
    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(buttons, hasLength(2));
    expect(buttons.every((b) => b.onPressed != null), isTrue);
  });

  testWidgets('the incoming tab shows the name when it loads after the card', (
    tester,
  ) async {
    final vm = _NotifyingFriendsVm();
    UserProfile? sender;
    when(() => vm.incomingRequests).thenReturn([_request()]);
    when(() => vm.sentRequests).thenReturn(const <FriendRequest>[]);
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.getUserProfile('erik')).thenAnswer((_) => sender);
    when(() => vm.getDisplayNameForUser(any())).thenReturn('Laddar…');
    when(() => vm.isAccepting(any())).thenReturn(false);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: ChangeNotifierProvider<FriendsViewModel>.value(
            value: vm,
            child: Consumer<FriendsViewModel>(
              builder: (context, vm, _) => IncomingRequestsTabBuilder.build(
                context,
                vm,
                <String>{},
                (_, _) {},
                () {},
                () {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Vänförfrågan'), findsOneWidget);
    expect(find.text('Laddar…'), findsNothing);

    sender = _erik();
    vm.notifyListeners();
    await tester.pump();

    expect(find.text('Erik Sandell'), findsOneWidget);
  });

  testWidgets('tapping Acceptera and Avböj reaches the view model', (
    tester,
  ) async {
    final vm = _MockFriendsVm();
    when(() => vm.getUserProfile('erik')).thenReturn(_erik());
    when(() => vm.isLoading).thenReturn(false);
    when(() => vm.isAccepting(any())).thenReturn(false);
    when(() => vm.acceptFriendRequest('r1')).thenAnswer((_) async => false);
    when(() => vm.rejectFriendRequest('r1')).thenAnswer((_) async => false);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => FriendRequestCard.buildIncomingCard(
                context,
                _request(),
                vm,
                false,
                (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Acceptera'));
    await tester.pump();
    verify(() => vm.acceptFriendRequest('r1')).called(1);

    await tester.tap(find.text('Avböj'));
    await tester.pump();
    verify(() => vm.rejectFriendRequest('r1')).called(1);
  });
}
