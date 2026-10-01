// test/widget/messaging/group_info_card_locale_test.dart
// BUT-622: Verifies GroupInfoCard renders the createdAt date using the active
// locale's month abbreviation, not a hardcoded Swedish format. Same input
// DateTime should produce visibly different month tokens under sv vs en.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:butlery/widgets/messaging/components/group_info_card.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    // DateFormat needs symbol data for both locales loaded before any usage.
    await initializeDateFormatting('sv');
    await initializeDateFormatting('en');
  });

  group('GroupInfoCard locale-aware date formatting (BUT-622)', () {
    // March is the test month because its abbreviation differs across locales:
    // sv -> "mars", en -> "Mar". January/May would collide on "jan"/"maj".
    final createdAt = DateTime(2026, 3, 15, 14, 30);

    testWidgets('renders Swedish month abbreviation under sv locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('sv'),
          child: GroupInfoCard(
            groupTitle: 'Testgrupp',
            memberCount: 3,
            createdAt: createdAt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Swedish DateFormat.yMMMd renders March as "mars" (lowercase, full word
      // in some locales, abbreviated in others — intl decides). Either form
      // should NOT contain the English "Mar" capitalized standalone.
      expect(find.textContaining('mars'), findsOneWidget);
    });

    testWidgets('renders English month abbreviation under en locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          locale: const Locale('en'),
          child: GroupInfoCard(
            groupTitle: 'Test group',
            memberCount: 3,
            createdAt: createdAt,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // English yMMMd renders March 15, 2026 as "Mar 15, 2026".
      expect(find.textContaining('Mar 15'), findsOneWidget);
    });
  });

  group('GroupInfoCard icon disc (BUT-2183)', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: the disc is surface.base so it stays '
          'visible on the raised card', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: GroupInfoCard(
                groupTitle: 'Testgrupp',
                memberCount: 3,
                createdAt: DateTime(2026, 3, 15),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cs = Theme.of(
          tester.element(find.byType(GroupInfoCard)),
        ).colorScheme;

        final disc = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .singleWhere((d) => d.shape == BoxShape.circle)
            .color;
        expect(disc, cs.surface);
        expect(disc!.a, 1.0);
      });
    }
  });
}
