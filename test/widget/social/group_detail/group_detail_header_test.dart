// Mer, omtänkt del 4: the group header's meta line follows the viewer's role
// and the member count, the household toggle is an admin-only row, and an
// empty description falls back to the shared copy.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/views/social/group_detail/group_detail_header.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

const _householdToggle = 'Markera som hushåll'; // householdToggle
const _noDescription = 'Ingen beskrivning'; // groupNoDescription

FriendCategory _group({
  List<String> members = const ['owner-uid'],
  String? description,
  bool isHousehold = false,
}) => FriendCategory(
  id: 'g1',
  ownerId: 'owner-uid',
  name: 'Familjen',
  description: description,
  friendUserIds: members,
  isHousehold: isHousehold,
);

Widget _app(
  FriendCategory group, {
  bool isAdmin = false,
  bool isHousehold = false,
  ValueChanged<bool>? onToggleHousehold,
  int? memberCount,
}) => createLocalizedTestApp(
  wrapInScrollView: true,
  child: Builder(
    builder: (context) => GroupDetailHeader.build(
      context,
      group,
      isAdmin: isAdmin,
      isHousehold: isHousehold,
      onToggleHousehold: onToggleHousehold,
      memberCount: memberCount,
    ),
  ),
);

void main() {
  testWidgets(
    'a non-admin with one friend and no memberCount sees "1 medlem" and no toggle',
    (tester) async {
      await tester.pumpWidget(
        _app(_group(), onToggleHousehold: (_) {}),
      );

      expect(find.text('1 medlem'), findsOneWidget);
      expect(find.textContaining('du är admin'), findsNothing);
      expect(find.text(_householdToggle), findsNothing);
    },
  );

  testWidgets(
    'an admin with memberCount 3 sees the admin meta and can toggle household',
    (tester) async {
      bool? toggledTo;
      await tester.pumpWidget(
        _app(
          _group(),
          isAdmin: true,
          memberCount: 3,
          onToggleHousehold: (v) => toggledTo = v,
        ),
      );

      // memberCount wins over the one-entry friend list.
      expect(find.text('3 medlemmar · du är admin'), findsOneWidget);
      expect(find.text('1 medlem'), findsNothing);
      expect(find.text(_householdToggle), findsOneWidget);

      await tester.tap(find.text(_householdToggle));
      await tester.pump();

      expect(toggledTo, isTrue);
    },
  );

  testWidgets('toggling an already-household group reports false', (
    tester,
  ) async {
    bool? toggledTo;
    await tester.pumpWidget(
      _app(
        _group(isHousehold: true),
        isAdmin: true,
        isHousehold: true,
        onToggleHousehold: (v) => toggledTo = v,
      ),
    );

    await tester.tap(find.text(_householdToggle));
    await tester.pump();

    expect(toggledTo, isFalse);
  });

  testWidgets('an empty-string description shows the no-description copy', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_group(description: '')));

    expect(find.text(_noDescription), findsOneWidget);
  });
}
