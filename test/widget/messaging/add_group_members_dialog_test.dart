import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/user_profile.dart';
import 'package:butlery/widgets/messaging/dialogs/add_group_members_dialog.dart';

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

    final row = find.widgetWithText(CheckboxListTile, 'Anna Lindgren');
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
}
