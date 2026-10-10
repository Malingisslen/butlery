import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/cookbooks/cookbook_note_banner.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  // Distinct strings so a banner that swapped the two fields cannot pass.
  const bookName = 'Jul hos mormor';
  const note = 'Sänk ugnen till 175 grader';

  testWidgets('shows the book it comes from above the book-only note', (
    tester,
  ) async {
    late String expectedHeading;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            expectedHeading = context.l10n.cookbookNoteFrom(bookName);
            return const CookbookNoteBanner(
              cookbookName: bookName,
              note: note,
            );
          },
        ),
      ),
    );

    // Premise: the heading really names the book.
    expect(expectedHeading, contains(bookName));
    expect(find.text(expectedHeading), findsOneWidget);
    expect(find.text(note), findsOneWidget);

    final headingTop = tester.getTopLeft(find.text(expectedHeading)).dy;
    final noteTop = tester.getTopLeft(find.text(note)).dy;
    expect(headingTop, lessThan(noteTop));
  });

  testWidgets('the heading follows the app language', (tester) async {
    late String englishHeading;
    await tester.pumpWidget(
      createLocalizedTestApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) {
            englishHeading = context.l10n.cookbookNoteFrom(bookName);
            return const CookbookNoteBanner(
              cookbookName: bookName,
              note: note,
            );
          },
        ),
      ),
    );

    expect(find.text(englishHeading), findsOneWidget);
    expect(find.textContaining('Från kokboken'), findsNothing);
  });
}
