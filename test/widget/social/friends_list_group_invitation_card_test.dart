// The incoming group invitation in the friends list: Avböj and Acceptera call
// the invitation operations, side by side at normal text. The stacking at
// 200 % is pinned through the friends list view (friends_list_view_test).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/operations/friends_invitations_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/views/social/friends_list/group_invitation_card.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockService extends Mock implements UnifiedFriendsService {}

class _MockOps extends Mock implements FriendsInvitationsOperations {}

void main() {
  final invitation = GroupInvitation(
    id: 'inv-1',
    groupId: 'g-1',
    groupName: 'Matlaget',
    groupEmoji: 'party',
    fromUserId: 'u-ina',
    fromUserName: 'Ina',
    toUserId: 'me',
  );

  late _MockService service;
  late _MockOps ops;

  setUp(() {
    service = _MockService();
    ops = _MockOps();
    when(() => service.invitations).thenReturn(ops);
    when(() => ops.isLoading).thenReturn(false);
    when(() => ops.hasError).thenReturn(false);
    when(() => ops.acceptGroupInvitation(any())).thenAnswer((_) async => true);
    when(() => ops.rejectGroupInvitation(any())).thenAnswer((_) async => true);
  });

  Future<void> pumpCard(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      createLocalizedTestApp(
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Builder(
            builder: (context) =>
                GroupInvitationCard.build(context, invitation, service),
          ),
        ),
      ),
    );
  }

  testWidgets('Avböj and Acceptera each call their own operation', (
    tester,
  ) async {
    await pumpCard(tester);

    await tester.tap(find.text('Avböj'));
    await tester.pump();
    verify(() => ops.rejectGroupInvitation('inv-1')).called(1);
    verifyNever(() => ops.acceptGroupInvitation(any()));

    await tester.tap(find.text('Acceptera'));
    await tester.pump();
    verify(() => ops.acceptGroupInvitation('inv-1')).called(1);
  });

  testWidgets('the buttons share a line at normal text', (tester) async {
    await pumpCard(tester);

    expect(
      tester.getCenter(find.text('Avböj')).dy,
      tester.getCenter(find.text('Acceptera')).dy,
    );
  });
}
