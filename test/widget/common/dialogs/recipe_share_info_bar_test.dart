import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_info_bar.dart';

Future<void> _pump(
  WidgetTester tester, {
  String searchQuery = '',
  bool hasSelectedRecipes = false,
  int selectedCount = 0,
  VoidCallback? onClearSelection,
  VoidCallback? onClearSearch,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: RecipeShareInfoBar(
          searchQuery: searchQuery,
          filteredCount: 3,
          totalCount: 12,
          hasSelectedRecipes: hasSelectedRecipes,
          selectedCount: selectedCount,
          onClearSelection: onClearSelection ?? () {},
          onClearSearch: onClearSearch ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a search shows the filtered count and clears the search', (
    tester,
  ) async {
    var cleared = 0;
    await _pump(tester, searchQuery: 'lax', onClearSearch: () => cleared++);

    expect(find.text('3 av 12 recept'), findsOneWidget);
    expect(find.text('Rensa val'), findsNothing);

    await tester.tap(find.text('Rensa'));
    expect(cleared, 1);
  });

  testWidgets('a selection shows the selected count and clears the selection', (
    tester,
  ) async {
    var clearedSelection = 0;
    var clearedSearch = 0;
    await _pump(
      tester,
      searchQuery: 'lax',
      hasSelectedRecipes: true,
      selectedCount: 2,
      onClearSelection: () => clearedSelection++,
      onClearSearch: () => clearedSearch++,
    );

    expect(find.text('3 av 12 recept'), findsOneWidget);
    expect(find.text('Valda (2)'), findsOneWidget);
    expect(find.text('Rensa'), findsNothing);

    await tester.tap(find.text('Rensa val'));
    expect(clearedSelection, 1);
    expect(clearedSearch, 0);
  });

  testWidgets('no search and no selection shows neither count nor action', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.textContaining('recept'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
