import 'package:butlery/models/friend_category.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/social/groups/edit_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/helpers/field_finder.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Future<void> pumpDialog(WidgetTester tester, {required String name}) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: EditGroupDialog(
          group: FriendCategory(id: 'g1', ownerId: 'u1', name: name),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the group name label stands above its box', (tester) async {
    await pumpDialog(tester, name: 'Middagsgänget');

    final field = fieldLabelled('Gruppnamn *');
    expect(field, findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(InputDecorator),
        matching: find.text('Gruppnamn *'),
      ),
      findsNothing,
    );
    expect(
      tester.getBottomLeft(find.text('Gruppnamn *')).dy,
      lessThanOrEqualTo(tester.getTopLeft(field).dy),
    );
  });

  testWidgets('a refused name shows its error with a glyph', (tester) async {
    await pumpDialog(tester, name: 'Middagsgänget');

    await tester.enterText(fieldLabelled('Gruppnamn *'), '');
    await tester.ensureVisible(find.text('Spara ändringar'));
    await tester.tap(find.text('Spara ändringar'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: fieldLabelled('Gruppnamn *'),
        matching: find.byWidgetPredicate(
          (w) => w is ButleryIcon && w.icon == ButleryIcons.info,
        ),
      ),
      findsOneWidget,
    );
  });
}
