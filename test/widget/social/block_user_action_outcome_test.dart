/// Which message `BlockUserAction` shows for each block outcome (BUT-2022).
///
/// The middle arm is the point. Before this the fake could emit only two of
/// `BlockOutcome`'s three members, so `blockedWithCleanupIssues` and its
/// string were executed by nothing — repointing that arm back to
/// `showError(socialCouldNotBlockUser)` reinstated the exact defect the
/// ticket exists to remove, with every suite still green.
///
/// Tested at `BlockUserAction` rather than through a menu handler on purpose:
/// the handlers pop their screen once the block lands, and no test in this
/// repo can observe a snackbar across that pop — measured, no existing test
/// asserts the SUCCESS message either.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/widgets/social/block_user_action.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/widget_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late MockFriendsViewModel friendsViewModel;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    friendsViewModel = MockFriendsViewModel();
  });

  /// Taps through the confirm dialog and settles.
  Future<void> blockThem(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => BlockUserAction.confirmAndBlock(
              context,
              userId: 'them-uid',
              displayName: 'Björn Ek',
              viewModel: friendsViewModel,
            ),
            child: const Text('start'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blockera').last);
    await tester.pumpAndSettle();
  }

  testWidgets('a clean block reports success', (tester) async {
    friendsViewModel.blockOutcome = BlockOutcome.blocked;

    await blockThem(tester);

    expect(find.text('Björn Ek har blockerats'), findsOneWidget);
    expect(find.text('Kunde inte blockera användare'), findsNothing);
  });

  testWidgets(
    'a block whose cleanup did not finish is NOT reported as failed',
    (
      tester,
    ) async {
      friendsViewModel.blockOutcome = BlockOutcome.blockedWithCleanupIssues;

      await blockThem(tester);

      expect(
        find.textContaining('Björn Ek är blockerad'),
        findsOneWidget,
        reason: 'the message must lead with the protection being in force',
      );
      expect(
        find.text('Kunde inte blockera användare'),
        findsNothing,
        reason:
            'the block STANDS; saying it failed is the defect BUT-2022 fixes',
      );
      // The three arms must be told apart, not merely "not the error one".
      expect(find.text('Björn Ek har blockerats'), findsNothing);
    },
  );

  testWidgets('a refused block reports the failure', (tester) async {
    friendsViewModel.blockOutcome = BlockOutcome.failed;

    await blockThem(tester);

    expect(find.text('Kunde inte blockera användare'), findsOneWidget);
    expect(find.textContaining('är blockerad'), findsNothing);
  });
}
