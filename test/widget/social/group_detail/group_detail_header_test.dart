// The group header: the household switch is an admin-only row, and the
// description shows only when the group has one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/views/social/group_detail/group_detail_header.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

const _householdToggle = 'Det här är hushållet'; // householdToggle

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
}) => createLocalizedTestApp(
  wrapInScrollView: true,
  child: Builder(
    builder: (context) => GroupDetailHeader.build(
      context,
      group,
      isAdmin: isAdmin,
      isHousehold: isHousehold,
      onToggleHousehold: onToggleHousehold,
    ),
  ),
);

void main() {
  testWidgets('a non-admin gets no household switch', (tester) async {
    await tester.pumpWidget(_app(_group(), onToggleHousehold: (_) {}));

    expect(find.text(_householdToggle), findsNothing);
  });

  testWidgets('an admin can switch the household on', (tester) async {
    bool? toggledTo;
    await tester.pumpWidget(
      _app(_group(), isAdmin: true, onToggleHousehold: (v) => toggledTo = v),
    );

    expect(find.text(_householdToggle), findsOneWidget);

    await tester.tap(find.text(_householdToggle));
    await tester.pump();

    expect(toggledTo, isTrue);
  });

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

  testWidgets('a description is shown and an empty one is not replaced', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_group(description: 'Söndagsmiddag')));
    expect(find.text('Söndagsmiddag'), findsOneWidget);

    await tester.pumpWidget(_app(_group(description: '')));
    expect(find.text('Ingen beskrivning'), findsNothing);
  });
}
