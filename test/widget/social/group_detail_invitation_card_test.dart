// BUT-2261: a pending group invitation names who was invited,
// and the group counts read in the singular for one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/views/social/group_detail/group_invitation_card.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final invitation = GroupInvitation(
    id: 'inv-1',
    groupId: 'g-1',
    groupName: 'Matlaget',
    groupEmoji: 'party',
    fromUserId: 'me',
    fromUserName: 'Malin',
    toUserId: 'u-ina',
  );

  Future<void> pumpCard(WidgetTester tester, {String? inviteeName}) =>
      tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => GroupInvitationCard.build(
              context,
              invitation,
              () {},
              inviteeName: inviteeName,
            ),
          ),
        ),
      );

  testWidgets('the row is titled with the invitee and their initial', (
    tester,
  ) async {
    await pumpCard(tester, inviteeName: 'Ina Inbjuden');

    expect(find.text('Ina Inbjuden'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('Skickad'), findsNothing);
    // The sender's initial belonged to the person who invited, not the row.
    expect(find.text('M'), findsNothing);
  });

  testWidgets('an unreadable invitee falls back to "Skickad"', (tester) async {
    await pumpCard(tester);

    expect(find.text('Skickad'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('an empty name is treated as no name', (tester) async {
    await pumpCard(tester, inviteeName: '');

    expect(find.text('Skickad'), findsOneWidget);
    expect(find.text('?'), findsOneWidget);
  });

  Future<void> openCancelDialog(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avbryt inbjudan'));
    await tester.pumpAndSettle();
  }

  testWidgets('the cancel question names the invitee, not the sender', (
    tester,
  ) async {
    await pumpCard(tester, inviteeName: 'Ina Inbjuden');
    await openCancelDialog(tester);

    expect(
      find.text('Vill du avbryta inbjudan till Ina Inbjuden?'),
      findsOneWidget,
    );
    expect(find.textContaining('Malin'), findsNothing);
  });

  testWidgets('without a name the cancel question names nobody', (
    tester,
  ) async {
    await pumpCard(tester);
    await openCancelDialog(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Vill du avbryta inbjudan till'), findsNothing);
    expect(find.textContaining('Malin'), findsNothing);
  });

  group('singular counts', () {
    final sv = AppLocalizationsSv();

    test('group member count', () {
      expect(sv.groupMemberCount(1), '1 person');
      expect(sv.groupMemberCount(3), '3 personer');
    });

    test('invitations sent', () {
      expect(sv.groupInvitationsSent(1), '1 inbjudan skickad');
      expect(sv.groupInvitationsSent(2), '2 inbjudningar skickade');
    });
  });
}
