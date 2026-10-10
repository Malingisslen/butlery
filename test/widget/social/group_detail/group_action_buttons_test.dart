// BUT-2321: the owner leaves a group too (by handing it over), so the leave
// button is shown to everyone while edit/delete stay owner-only.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/views/social/group_detail/group_action_buttons.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late AppLocalizations l10n;
  var leaveTaps = 0;

  Future<void> pump(WidgetTester tester, {required bool isAdmin}) async {
    leaveTaps = 0;
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    void noop() {}
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScrollView: true,
        child: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return GroupActionButtons(
              group: FriendCategory(
                id: 'g1',
                ownerId: 'owner-uid',
                name: 'Familjen',
                friendUserIds: const ['owner-uid', 'member-uid'],
              ),
              isAdmin: isAdmin,
              onShareRecipe: noop,
              onShareMenu: noop,
              onShareShoppingList: noop,
              onAskWhatToEat: noop,
              onEditGroup: noop,
              onDeleteGroup: noop,
              onLeaveGroup: () => leaveTaps++,
            );
          },
        ),
      ),
    );
  }

  testWidgets('the owner sees leave plus edit and delete, and leave works', (
    tester,
  ) async {
    await pump(tester, isAdmin: true);

    expect(find.text(l10n.groupEditGroup), findsOneWidget);
    expect(find.text(l10n.groupDeleteGroup), findsOneWidget);
    expect(find.text(l10n.groupLeaveGroup), findsOneWidget);

    await tester.tap(find.text(l10n.groupLeaveGroup));
    expect(leaveTaps, 1);
  });

  testWidgets('a member sees leave but neither edit nor delete', (
    tester,
  ) async {
    await pump(tester, isAdmin: false);

    expect(find.text(l10n.groupEditGroup), findsNothing);
    expect(find.text(l10n.groupDeleteGroup), findsNothing);
    expect(find.text(l10n.groupLeaveGroup), findsOneWidget);

    await tester.tap(find.text(l10n.groupLeaveGroup));
    expect(leaveTaps, 1);
  });
}
