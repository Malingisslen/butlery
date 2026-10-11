import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/social/groups/ownership_transfer_dialog.dart';

import '../../../infrastructure/factories/social_factory.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final member = SocialFactory.createUserProfile(
    uid: 'u-2',
    displayName: 'Greta',
  );
  final sentinel = SocialFactory.createUserProfile(uid: 'sentinel');

  // The result starts non-null so a dialog that never reports back cannot
  // pass as "cancelled".
  late UserProfile? result;

  Future<void> openDialog(WidgetTester tester) async {
    result = sentinel;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await OwnershipTransferDialog.show(
                context: context,
                group: FriendCategory(
                  id: 'g1',
                  ownerId: 'u-1',
                  name: 'Middagsklubben',
                ),
                availableMembers: [member],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(OwnershipTransferDialog), findsOneWidget);
  }

  testWidgets('Avbryt closes the dialog and the caller gets null', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.text('Avbryt'));
    await tester.pumpAndSettle();

    expect(find.byType(OwnershipTransferDialog), findsNothing);
    expect(result, isNull);
  });

  testWidgets('tapping a member returns that member', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('Greta'));
    await tester.pumpAndSettle();

    expect(find.byType(OwnershipTransferDialog), findsNothing);
    expect(result, same(member));
  });
}
