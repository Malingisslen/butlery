/// The invitee's cards at the top of the shopping tab: what each answer does
/// to the card and which message it gets. The view model runs for real over a
/// mocked operations layer; only the server side is stubbed.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social_request.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/viewmodels/list_invitations_viewmodel.dart';
import 'package:butlery/views/unified_shopping/widgets/list_invitations_section.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/mocks/widget_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockOps extends Mock implements ListInvitationOperations {}

SocialRequest _inv(
  String id, {
  String name = 'Veckohandling',
  String permission = 'edit',
}) => SocialRequest(
  id: id,
  type: SocialRequestType.listInvitation,
  fromUserId: 'anna',
  toUserId: 'bob',
  listId: 'l-$id',
  listName: name,
  permission: permission,
  fromUserName: 'Anna',
);

// byType matches the exact runtimeType, so ElevatedButton and TextButton need
// a predicate.
final _anyButton = find.byWidgetPredicate((w) => w is ButtonStyleButton);

void main() {
  late _MockOps ops;
  late StreamController<List<SocialRequest>> rows;
  late ListInvitationsViewModel vm;
  late MockFriendsViewModel friends;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    ops = _MockOps();
    rows = StreamController<List<SocialRequest>>.broadcast();
    when(() => ops.pendingReceived).thenAnswer((_) => rows.stream);
    friends = MockFriendsViewModel();
    vm = ListInvitationsViewModel(operations: ops, analytics: null);
  });

  tearDown(() async {
    vm.dispose();
    await rows.close();
  });

  Future<void> show(WidgetTester tester, List<SocialRequest> list) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: ListInvitationsSection(viewModel: vm, friendsViewModel: friends),
      ),
    );
    rows.add(list);
    await tester.pump();
  }

  testWidgets('shows nothing at all when there are no invitations', (
    tester,
  ) async {
    await show(tester, []);

    expect(find.text('INBJUDNINGAR'), findsNothing);
    expect(find.text('Gå med'), findsNothing);
  });

  testWidgets('a card carries the list name, who invited and the level', (
    tester,
  ) async {
    await show(tester, [
      _inv('a'),
      _inv('b', name: 'Fest', permission: 'view'),
    ]);

    expect(find.text('INBJUDNINGAR'), findsOneWidget);
    Finder onCard(String id, String text) => find.descendant(
      of: find.byKey(ValueKey(id)),
      matching: find.text(text),
    );
    expect(onCard('a', 'Veckohandling'), findsOneWidget);
    expect(
      onCard(
        'a',
        'Anna bjuder in dig till sin delade lista. Du kan redigera den.',
      ),
      findsOneWidget,
    );
    expect(onCard('b', 'Fest'), findsOneWidget);
    expect(
      onCard('b', 'Anna bjuder in dig till sin delade lista. Du kan se den.'),
      findsOneWidget,
    );
    expect(find.text('Gå med'), findsNWidgets(2));
    expect(find.text('Avböj'), findsNWidgets(2));
  });

  testWidgets('Gå med accepts, welcomes and removes the card', (tester) async {
    when(
      () => ops.acceptListInvitation('a'),
    ).thenAnswer((_) async => ListInvitationOutcome.accepted);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Gå med'));
    await tester.pump();
    await tester.pump();

    verify(() => ops.acceptListInvitation('a')).called(1);
    expect(find.text('Du är med i Veckohandling'), findsOneWidget);
    expect(find.text('Gå med'), findsNothing);
  });

  testWidgets('an invitation to a list already joined counts as joined', (
    tester,
  ) async {
    when(
      () => ops.acceptListInvitation('a'),
    ).thenAnswer((_) async => ListInvitationOutcome.alreadyMember);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Gå med'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Du är med i Veckohandling'), findsOneWidget);
    expect(find.text('Gå med'), findsNothing);
  });

  testWidgets('Avböj declines, says so and removes the card', (tester) async {
    when(
      () => ops.declineListInvitation('a'),
    ).thenAnswer((_) async => ListInvitationOutcome.declined);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Avböj'));
    await tester.pump();
    await tester.pump();

    verify(() => ops.declineListInvitation('a')).called(1);
    verifyNever(() => ops.acceptListInvitation(any()));
    expect(find.text('Inbjudan avböjd'), findsOneWidget);
    expect(find.text('Avböj'), findsNothing);
  });

  testWidgets('while the call runs both buttons are off and a second tap does '
      'nothing', (tester) async {
    final gate = Completer<ListInvitationOutcome>();
    when(() => ops.acceptListInvitation('a')).thenAnswer((_) => gate.future);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Gå med'));
    await tester.pump();

    final buttons = tester.widgetList<ButtonStyleButton>(_anyButton).toList();
    // Avböj, Gå med and the three-dot button.
    expect(buttons, hasLength(3));
    // A busy ActionButtons button keeps a no-op handler rather than null
    // (PlateLineButton.ignore); the taps below prove it does nothing.
    expect(
      buttons.every(
        (b) => b.onPressed == null || b.onPressed == PlateLineButton.ignore,
      ),
      isTrue,
    );
    expect(buttons.where((b) => b.onPressed == null), hasLength(2));
    await tester.tap(find.text('Gå med'), warnIfMissed: false);
    await tester.tap(find.text('Avböj'), warnIfMissed: false);
    verify(() => ops.acceptListInvitation('a')).called(1);
    verifyNever(() => ops.declineListInvitation(any()));

    gate.complete(ListInvitationOutcome.accepted);
    await tester.pump();
    await tester.pump();
  });

  testWidgets('a server refusal says the invitation is void and removes the '
      'card', (tester) async {
    when(
      () => ops.acceptListInvitation('a'),
    ).thenAnswer((_) async => ListInvitationOutcome.notAvailable);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Gå med'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Inbjudan gäller inte längre'), findsOneWidget);
    expect(find.text('Gå med'), findsNothing);
  });

  testWidgets('offline refuses with the network error and the card stays', (
    tester,
  ) async {
    when(
      () => ops.declineListInvitation('a'),
    ).thenAnswer((_) async => ListInvitationOutcome.offline);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Avböj'));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Nätverksfel. Kontrollera din internetanslutning.'),
      findsOneWidget,
    );
    expect(find.text('Avböj'), findsOneWidget);
    expect(find.text('Gå med'), findsOneWidget);
  });

  testWidgets('a transient failure shows a generic message and the card stays '
      'usable', (tester) async {
    when(
      () => ops.acceptListInvitation('a'),
    ).thenAnswer((_) async => ListInvitationOutcome.failed);
    await show(tester, [_inv('a')]);

    await tester.tap(find.text('Gå med'));
    await tester.pump();
    await tester.pump();

    expect(
      find.textContaining('Det gick inte att svara på inbjudan'),
      findsOneWidget,
    );
    expect(find.text('Du är med i Veckohandling'), findsNothing);
    final join = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Gå med'),
        matching: _anyButton,
      ),
    );
    expect(join.onPressed, isNotNull);
  });

  group('the three-dot menu', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Fler val för inbjudan').first);
      await tester.pumpAndSettle();
    }

    testWidgets('offers one danger row naming the sender', (tester) async {
      await show(tester, [_inv('a')]);

      await openMenu(tester);

      expect(find.text('Blockera Anna'), findsOneWidget);
    });

    testWidgets('a confirmed block removes the card without answering it', (
      tester,
    ) async {
      friends.blockOutcome = BlockOutcome.blocked;
      await show(tester, [_inv('a'), _inv('b')]);

      await openMenu(tester);
      await tester.tap(find.text('Blockera Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blockera').last);
      await tester.pumpAndSettle();

      expect(friends.blockedUserIds, ['anna']);
      expect(find.text('Gå med'), findsNothing);
      verifyNever(() => ops.acceptListInvitation(any()));
      verifyNever(() => ops.declineListInvitation(any()));
    });

    testWidgets('backing out of the confirmation keeps the card', (
      tester,
    ) async {
      await show(tester, [_inv('a')]);

      await openMenu(tester);
      await tester.tap(find.text('Blockera Anna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(friends.blockedUserIds, isEmpty);
      expect(find.text('Gå med'), findsOneWidget);
    });

    testWidgets('a sender without a name reads as Någon, on the card and in '
        'the block confirmation', (tester) async {
      await show(tester, [
        SocialRequest(
          id: 'a',
          type: SocialRequestType.listInvitation,
          fromUserId: 'anna',
          toUserId: 'bob',
          listId: 'l-a',
          listName: 'Veckohandling',
          permission: 'edit',
          fromUserName: ' ',
        ),
      ]);

      expect(
        find.text(
          'Någon bjuder in dig till sin delade lista. Du kan redigera den.',
        ),
        findsOneWidget,
      );
      await openMenu(tester);
      await tester.tap(find.text('Blockera Någon'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Vill du blockera Någon?'), findsOneWidget);
    });
  });
}
