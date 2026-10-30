import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/recipe_selection/recipe_share_dialog_frame.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool hasSelectedRecipes = false,
  int selectedCount = 0,
  bool isSharing = false,
  VoidCallback? onShare,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: RecipeShareDialogFrame(
          recipientName: 'Anna',
          content: const Text('receptlistan'),
          hasSelectedRecipes: hasSelectedRecipes,
          selectedCount: selectedCount,
          isSharing: isSharing,
          onShare: onShare ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('names the recipient, shows the content, and offers no share '
      'button before a recipe is selected', (tester) async {
    await _pump(tester);

    expect(find.text('Dela recept med Anna'), findsOneWidget);
    expect(find.text('receptlistan'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('the share button counts the selection and shares on tap', (
    tester,
  ) async {
    var shared = 0;
    await _pump(
      tester,
      hasSelectedRecipes: true,
      selectedCount: 2,
      onShare: () => shared++,
    );

    await tester.tap(find.text('Dela (2)'));
    expect(shared, 1);
  });

  testWidgets('while sharing the button says so and ignores taps', (
    tester,
  ) async {
    var shared = 0;
    await _pump(
      tester,
      hasSelectedRecipes: true,
      selectedCount: 2,
      isSharing: true,
      onShare: () => shared++,
    );

    expect(find.text('Dela (2)'), findsNothing);
    await tester.tap(find.text('Delar …'));
    expect(shared, 0);
  });
}
