// A sectioned invitation list says how many members a group has, with the
// singular for exactly one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social_components/invitation_lists.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

InvitationTarget _group(String name, int? count) => InvitationTarget(
  type: InvitationTargetType.group,
  targetId: name,
  displayName: name,
  memberCount: count,
);

void main() {
  testWidgets('member count reads 1 medlem / N medlemmar, null as 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => InvitationLists.sectionedTargetList(
            context,
            targets: [
              _group('Ensam', 1),
              _group('Släkten', 5),
              _group('Tom', null),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1 medlem'), findsOneWidget);
    expect(find.text('5 medlemmar'), findsOneWidget);
    expect(find.text('0 medlemmar'), findsOneWidget);
  });
}
