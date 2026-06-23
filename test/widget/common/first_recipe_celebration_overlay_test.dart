/// Widget tests for FirstRecipeCelebrationOverlay.
///
/// The overlay is a Material full-screen widget with:
/// - a localized congratulatory title
/// - a localized message interpolating the recipe title
/// - a Continue button that calls `onDismiss`
/// - a Timer-based auto-dismiss after `autoDismissDuration`
///
/// Animation strategy: wrap with MediaQuery(disableAnimations: true) and
/// drive timers with explicit `pump(Duration(...))` rather than
/// `pumpAndSettle`, which would never return because the auto-dismiss timer
/// is an active future at frame zero.
library;

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/first_recipe_celebration_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: Scaffold(body: child),
  ),
);

void main() {
  group('FirstRecipeCelebrationOverlay rendering', () {
    testWidgets('renders the localized Swedish congratulatory title', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'Pannkakor',
            onDismiss: () {},
            autoDismissDuration: const Duration(hours: 1), // far in the future
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Grattis!'), findsOneWidget);
    });

    testWidgets('renders the localized message with the recipe title injected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'Köttbullar',
            onDismiss: () {},
            autoDismissDuration: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      // ARB: "Du har sparat ditt första recept: {recipeTitle}. Välkommen till Butlery!"
      expect(
        find.text(
          'Du har sparat ditt första recept: Köttbullar. Välkommen till Butlery!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the localized continue button label', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'Pannkakor',
            onDismiss: () {},
            autoDismissDuration: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      // Scoped to the subject to avoid matching any unrelated button label
      // elsewhere in the wrapper (there isn't one, but explicit is safer).
      expect(
        find.descendant(
          of: find.byType(FirstRecipeCelebrationOverlay),
          matching: find.widgetWithText(FilledButton, 'Fortsätt'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('uses Material with theme primary color as background', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'r',
            onDismiss: () {},
            autoDismissDuration: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      // The first Material inside the overlay carries the celebration bg color
      // (the surface color comes from Scaffold above it).
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(FirstRecipeCelebrationOverlay),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, AppTheme.lightTheme.colorScheme.primary);
    });
  });

  group('FirstRecipeCelebrationOverlay dismissal', () {
    testWidgets('tapping the Continue button invokes onDismiss exactly once', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'r',
            onDismiss: () => calls++,
            autoDismissDuration: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Fortsätt'));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('auto-dismiss timer fires onDismiss after the duration', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'r',
            onDismiss: () => calls++,
            autoDismissDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump();
      expect(calls, 0, reason: 'timer should not fire before its duration');

      await tester.pump(const Duration(milliseconds: 250));
      expect(calls, 1, reason: 'timer should have fired exactly once');
    });

    testWidgets('auto-dismiss timer does not fire before its duration', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'r',
            onDismiss: () => calls++,
            autoDismissDuration: const Duration(seconds: 5),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4000));

      expect(calls, 0);

      // Tear down the widget tree to cancel the active timer cleanly,
      // otherwise the test framework will flag pending timers.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('disposing the widget cancels the pending auto-dismiss timer', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _wrap(
          FirstRecipeCelebrationOverlay(
            recipeTitle: 'r',
            onDismiss: () => calls++,
            autoDismissDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
      await tester.pump();

      // Remove the overlay BEFORE the timer would fire.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));

      // Advance past the original deadline — onDismiss must NOT be called.
      await tester.pump(const Duration(milliseconds: 500));

      expect(calls, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('FirstRecipeCelebrationOverlay.show', () {
    testWidgets(
      'static show() pushes the overlay route and closes via Continue',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('sv'),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (ctx) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => FirstRecipeCelebrationOverlay.show(
                      ctx,
                      recipeTitle: 'Pannkakor',
                    ),
                    child: const Text('Show'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        // disableAnimations collapses the fade transition to zero, but the
        // showGeneralDialog route still needs one extra pump to commit.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(FirstRecipeCelebrationOverlay), findsOneWidget);
        expect(find.text('Grattis!'), findsOneWidget);

        // The internal onDismiss closure pops the route.
        await tester.tap(find.text('Fortsätt'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(FirstRecipeCelebrationOverlay), findsNothing);
      },
    );
  });
}
