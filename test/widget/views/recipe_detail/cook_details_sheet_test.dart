/// "Hur blev det?" returns what the user filled in, asks for a rating only
/// when the household has not already rated, and returns null when skipped.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/cook_details_sheet.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';

void main() {
  CookDetails? result;
  var closed = false;

  Future<AppLocalizations> open(
    WidgetTester tester, {
    required bool askRating,
  }) async {
    result = null;
    closed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showCookDetailsSheet(
                context,
                recipeTitle: 'Linsgryta',
                askRating: askRating,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.text('open')));
  }

  testWidgets('saving returns the rating and the trimmed note', (tester) async {
    final l10n = await open(tester, askRating: true);

    await tester.tap(find.byType(StarRatingRow));
    await tester.enterText(find.byType(TextField), '  mer lime  ');
    await tester.tap(find.text(l10n.cookDetailsSave));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result?.note, 'mer lime');
    expect(result?.rating, isNotNull);
  });

  testWidgets('skipping returns null', (tester) async {
    final l10n = await open(tester, askRating: true);

    await tester.tap(find.text(l10n.cookDetailsSkip));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('no stars when the household already rated', (tester) async {
    await open(tester, askRating: false);

    expect(find.byType(StarRatingRow), findsNothing);
  });
}
