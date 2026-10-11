import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/widgets/common/share_dialog/share_dialog_helpers.dart';
import 'package:butlery/widgets/common/universal_share_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<String> successMessage(
    WidgetTester tester,
    int friends,
    ShareMode mode, {
    int groups = 0,
    Object? sharedList,
  }) async {
    late String message;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            message = ShareDialogHelpers.getSuccessMessage(
              context,
              friendCount: friends,
              groupCount: groups,
              shareMode: mode,
              sharedList: sharedList,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return message;
  }

  group('ShareDialogHelpers.getSuccessMessage', () {
    testWidgets('a static copy to one person is singular', (tester) async {
      expect(
        await successMessage(tester, 1, ShareMode.staticCopy),
        'Delat med 1 person.',
      );
    });

    testWidgets('a static copy to several people is plural', (tester) async {
      expect(
        await successMessage(tester, 3, ShareMode.staticCopy),
        'Delat med 3 personer.',
      );
    });

    testWidgets('a live share of a shared shopping list says the recipients '
        'are invited, not added', (tester) async {
      final list = UnifiedShoppingList.collaborative(
        name: 'Veckohandling',
        ownerId: 'me',
        ownerDisplayName: 'Malin',
        memberPermissions: {'me': SharedListPermission.admin},
      );
      expect(
        await successMessage(tester, 3, ShareMode.realtime, sharedList: list),
        'Inbjudan skickad. Mottagarna kommer med när de har tackat ja.',
      );
    });

    testWidgets('a live share of a personal list is a copy and keeps the '
        'plain receipt', (tester) async {
      final list = UnifiedShoppingList.personal(
        name: 'Veckohandling',
        ownerId: 'me',
        ownerDisplayName: 'Malin',
      );
      expect(
        await successMessage(tester, 3, ShareMode.realtime, sharedList: list),
        'Delat med 3 personer. Ändringar syns för alla.',
      );
    });

    testWidgets('a live share tells the sender that changes are visible', (
      tester,
    ) async {
      expect(
        await successMessage(tester, 3, ShareMode.realtime),
        'Delat med 3 personer. Ändringar syns för alla.',
      );
    });

    testWidgets('with a group among the picks it does not claim a head count', (
      tester,
    ) async {
      expect(
        await successMessage(tester, 1, ShareMode.staticCopy, groups: 1),
        'Delat med 2 mottagare.',
      );
    });

    testWidgets('a live share with a group keeps the live note', (
      tester,
    ) async {
      expect(
        await successMessage(tester, 0, ShareMode.realtime, groups: 2),
        'Delat med 2 mottagare. Ändringar syns för alla.',
      );
    });
  });
}
