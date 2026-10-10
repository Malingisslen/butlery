// BUT-2305: an unverified account asking to add a friend was told to verify,
// with no way to get a new mail from where it was blocked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/views/social/friends_list/search_result_card.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  late MockFriendsViewModel viewModel;
  final person = UserProfile(
    uid: 'them-uid',
    email: 'them@example.com',
    displayName: 'Björn Ek',
    joinedAt: DateTime(2026),
    lastActiveAt: DateTime(2026),
  );

  Future<void> tapSend(WidgetTester tester) async {
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
  }

  setUp(() {
    viewModel = MockFriendsViewModel()
      ..blockedByUnverifiedEmail = true
      ..setFriendshipStatus(person.uid, FriendshipStatus.none);
    when(
      () => viewModel.sendFriendRequest(any(), message: any(named: 'message')),
    ).thenAnswer((_) async => false);
  });

  testWidgets('the block offers a new mail, and sending it says so', (
    tester,
  ) async {
    await tapSend(tester);
    expect(
      find.text('Bekräfta din e-post för att lägga till vänner'),
      findsOneWidget,
    );

    await tester.tap(find.text('Skicka nytt mejl'));
    await tester.pumpAndSettle();

    expect(viewModel.resendVerificationCalls, 1);
    expect(find.text('Nytt bekräftelsemejl skickat'), findsOneWidget);
  });

  testWidgets('a mail that could not be sent says that instead', (
    tester,
  ) async {
    viewModel.resendVerificationSucceeds = false;
    await tapSend(tester);
    await tester.tap(find.text('Skicka nytt mejl'));
    await tester.pumpAndSettle();

    expect(find.text('Kunde inte skicka bekräftelsemejlet'), findsOneWidget);
  });

  testWidgets('any other failure offers no mail', (tester) async {
    viewModel.blockedByUnverifiedEmail = false;
    await tapSend(tester);

    expect(find.text('Kunde inte skicka vänförfrågan'), findsOneWidget);
    expect(find.text('Skicka nytt mejl'), findsNothing);
  });
}
