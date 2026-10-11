import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/butlery_search_box.dart';
import 'package:butlery/widgets/common/social/invitation_target_widgets.dart';
import 'package:butlery/widgets/common/social_components/invitation_selectors.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('the invitation selectors search is the shared search box and '
      'reports what is typed', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Material(
          child: InvitationSelectors.targetSearchField(
            onSearchChanged: queries.add,
          ),
        ),
      ),
    );

    expect(find.byType(ButlerySearchBox), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'anna');
    expect(queries, ['anna']);
  });

  testWidgets('the invitation target search is the shared search box and '
      'reports what is typed', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Material(
          child: Builder(
            builder: (context) => InvitationTargetWidgets.targetSearchField(
              context: context,
              onChanged: queries.add,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ButlerySearchBox), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'grupp');
    expect(queries, ['grupp']);
  });
}
