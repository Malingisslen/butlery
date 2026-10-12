import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/messaging/dialogs/add_group_members_dialog.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  final anna = UserProfile(
    uid: 'anna',
    displayName: 'Anna Lindgren',
    email: 'anna@example.com',
    joinedAt: DateTime(2026, 1, 1),
    lastActiveAt: DateTime(2026, 1, 1),
  );

  testWidgets('a friend row announces the name once, activates and toggles', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: AddGroupMembersDialog(availableFriends: [anna]),
      ),
    );

    final row = find.widgetWithText(ButleryCheckboxTile, 'Anna Lindgren');
    final lines = announcedLines(tester, row);
    expect(lines.where((l) => l.contains('Anna Lindgren')), hasLength(1));
    expect(lines.where((l) => l.contains('Profilbild')), isEmpty);
    expectActivatable(tester, row);

    CheckedState checked() =>
        tester.getSemantics(row).getSemanticsData().flagsCollection.isChecked;
    expect(checked(), CheckedState.isFalse);

    await tester.tap(row);
    await tester.pump();

    expect(checked(), CheckedState.isTrue);
    handle.dispose();
  });

  testWidgets(
    'the shared search box narrows the list and its clear restores it',
    (
      tester,
    ) async {
      final bertil = UserProfile(
        uid: 'bertil',
        displayName: 'Bertil Ek',
        email: 'bertil@example.com',
        joinedAt: DateTime(2026, 1, 1),
        lastActiveAt: DateTime(2026, 1, 1),
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: AddGroupMembersDialog(availableFriends: [anna, bertil]),
        ),
      );

      expect(find.byType(ButlerySearchBox), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'bert');
      await tester.pump();
      expect(
        find.widgetWithText(ButleryCheckboxTile, 'Anna Lindgren'),
        findsNothing,
      );
      expect(
        find.widgetWithText(ButleryCheckboxTile, 'Bertil Ek'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(ButleryIcons.x));
      await tester.pump();
      expect(
        find.widgetWithText(ButleryCheckboxTile, 'Anna Lindgren'),
        findsOneWidget,
      );
    },
  );
}
