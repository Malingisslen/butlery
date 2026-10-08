import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social_components/invitation_actions.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('selectionActionBar lays out its send button in a Row', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => InvitationActions.selectionActionBar(
            context,
            selectedCount: 2,
            onSelectAll: () {},
            onSendInvitations: () {},
            showDeselectAll: false,
            showInvert: false,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('bulkOperationButtons lays out its invite button in a Row', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => InvitationActions.bulkOperationButtons(
            context,
            selectedTargets: [
              const InvitationTarget(
                type: InvitationTargetType.individual,
                targetId: 'f1',
                displayName: 'Erik',
              ),
            ],
            onBulkInvite: () {},
            onBulkRemove: () {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
