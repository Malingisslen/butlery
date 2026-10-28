// BUT-1953: labels in the recipe-detail / image widgets that used to restate
// their visible text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/recipe_detail/recipe_detail_hero_buttons.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/image/components/upload_progress_widgets.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/semantics_announcement.dart';

void main() {
  testWidgets('a hero button is announced once, as a button', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Center(
          child: Semantics(
            identifier: 'btn-share-friends',
            button: true,
            child: RecipeHeroButton(
              icon: ButleryIcons.users,
              onPressed: () {},
              tooltip: 'Dela med vänner',
            ),
          ),
        ),
      ),
    );

    final button = find.bySemanticsLabel('Dela med vänner');
    expect(button, findsOneWidget);
    expect(announcedLines(tester, button), ['Dela med vänner']);
    expectActivatable(tester, button);
    handle.dispose();
  });

  testWidgets('bulk and overlay upload buttons are announced once', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Column(
          children: [
            UploadProgressWidgets.buildBulkActionButton(
              icon: ButleryIcons.x,
              label: 'Försök igen alla',
              onTap: () {},
              color: Colors.red,
            ),
            UploadProgressWidgets.buildUploadActionButton(
              icon: ButleryIcons.x,
              label: 'Försök igen',
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    for (final text in ['Försök igen alla', 'Försök igen']) {
      final button = find.bySemanticsLabel(text);
      expect(button, findsOneWidget, reason: text);
      expect(announcedLines(tester, button), [text]);
      expectActivatable(tester, button);
    }
    handle.dispose();
  });
}
