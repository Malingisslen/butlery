/// Widget tests for [UnknownIngredientDialog].
///
/// The dialog walks the user through a list of ingredients that aren't in
/// the tagging database. Per ingredient it shows allergen + dietary
/// FilterChips, a Skip button, optional Previous, and a Save & Next
/// (or Save & Close on the last item) FilledButton. When the user saves
/// with non-empty properties AND a userId AND a registered TaggingService,
/// it calls `taggingService.saveUserIngredient`; otherwise the save path
/// short-circuits to skip-and-advance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/unknown_ingredient_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(body: child),
    );

/// Opens the dialog via `UnknownIngredientDialog.show` from a triggering
/// button so the real `showDialog` route is exercised. The future
/// resolution is forwarded to [onResult] for assertions.
Widget _trigger({
  required List<String> ingredients,
  String? userId,
  VoidCallback? onComplete,
  void Function(bool)? onResult,
}) {
  return Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () async {
        final result = await UnknownIngredientDialog.show(
          ctx,
          unknownIngredients: ingredients,
          userId: userId,
          onComplete: onComplete,
        );
        onResult?.call(result);
      },
      child: const Text('Show'),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Show'));
  await tester.pumpAndSettle();
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('UnknownIngredientDialog.show — entry guard', () {
    testWidgets('does NOT open and resolves false when ingredients is empty',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const [],
        onResult: (v) => result = v,
      )));

      await _open(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isFalse);
    });
  });

  group('UnknownIngredientDialog rendering', () {
    testWidgets('renders progress title "Okänd ingrediens 1/2" with two items',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake', 'tahini'],
      )));
      await _open(tester);

      expect(find.text('Okänd ingrediens 1/2'), findsOneWidget);
    });

    testWidgets('renders the current ingredient name verbatim', (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await _open(tester);

      expect(find.text('shiitake'), findsOneWidget);
    });

    testWidgets('renders the description, allergen + dietary section headers',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await _open(tester);

      expect(
        find.text(
          'Denna ingrediens finns inte i databasen. Du kan definiera dess egenskaper för bättre taggning.',
        ),
        findsOneWidget,
      );
      expect(find.text('Innehåller allergener:'), findsOneWidget);
      expect(find.text('Dietegenskaper:'), findsOneWidget);
    });

    testWidgets('renders all eight allergen FilterChips with localized labels',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await _open(tester);

      for (final label in const [
        'Gluten',
        'Mjölk',
        'Ägg',
        'Fisk',
        'Kräftdjur',
        'Trädnötter',
        'Jordnötter',
        'Soja',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'allergen $label');
      }
    });

    testWidgets('renders all eight dietary FilterChips with localized labels',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await _open(tester);

      for (final label in const [
        'Kött',
        'Fläsk',
        'Nötkött',
        'Fågel',
        // dietarySeafood = "Fisk/skaldjur" — distinct from allergenFish ("Fisk").
        'Fisk/skaldjur',
        'Animalisk produkt',
        'Alkohol',
        'Starkt',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'dietary $label');
      }
    });

    testWidgets(
        'on the only/last item, skip label is "Hoppa över alla" and save label is "Spara och stäng"',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await _open(tester);

      expect(find.text('Hoppa över alla'), findsOneWidget);
      expect(find.text('Spara och stäng'), findsOneWidget);
      // No "Föregående" on the only item.
      expect(find.text('Föregående'), findsNothing);
    });

    testWidgets(
        'on a non-last item, skip is "Hoppa över" and save is "Spara och nästa"',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake', 'tahini'],
      )));
      await _open(tester);

      expect(find.text('Hoppa över'), findsOneWidget);
      expect(find.text('Spara och nästa'), findsOneWidget);
      // First page → no "Föregående".
      expect(find.text('Föregående'), findsNothing);
    });
  });

  group('UnknownIngredientDialog navigation', () {
    testWidgets('tapping "Hoppa över" advances to the next ingredient',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake', 'tahini'],
      )));
      await _open(tester);

      expect(find.text('shiitake'), findsOneWidget);
      expect(find.text('Okänd ingrediens 1/2'), findsOneWidget);

      await _tapAndSettle(tester, find.text('Hoppa över'));

      expect(find.text('tahini'), findsOneWidget);
      expect(find.text('Okänd ingrediens 2/2'), findsOneWidget);
    });

    testWidgets('"Föregående" appears on page 2 and steps back to page 1',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake', 'tahini'],
      )));
      await _open(tester);

      await _tapAndSettle(tester, find.text('Hoppa över'));
      expect(find.text('Föregående'), findsOneWidget);

      await _tapAndSettle(tester, find.text('Föregående'));

      expect(find.text('shiitake'), findsOneWidget);
      expect(find.text('Okänd ingrediens 1/2'), findsOneWidget);
      expect(find.text('Föregående'), findsNothing);
    });

    testWidgets(
        'tapping "Spara och nästa" with NO selected chips behaves as skip and advances',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake', 'tahini'],
      )));
      await _open(tester);

      await _tapAndSettle(tester, find.text('Spara och nästa'));

      expect(find.text('tahini'), findsOneWidget);
      expect(find.text('Okänd ingrediens 2/2'), findsOneWidget);
    });
  });

  group('UnknownIngredientDialog FilterChip toggling', () {
    testWidgets('tapping the Gluten chip flips its selected state',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await _open(tester);

      FilterChip glutenChip() => tester.widget<FilterChip>(
            find.ancestor(
              of: find.text('Gluten'),
              matching: find.byType(FilterChip),
            ),
          );

      expect(glutenChip().selected, isFalse);

      await _tapAndSettle(tester, find.text('Gluten'));
      expect(glutenChip().selected, isTrue);

      await _tapAndSettle(tester, find.text('Gluten'));
      expect(glutenChip().selected, isFalse);
    });

    testWidgets(
        'selections on page 1 are preserved when returning via Föregående',
        (tester) async {
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake', 'tahini'],
      )));
      await _open(tester);

      await _tapAndSettle(tester, find.text('Gluten'));
      await _tapAndSettle(tester, find.text('Hoppa över'));
      expect(find.text('tahini'), findsOneWidget);

      final tahiniGluten = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Gluten'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(tahiniGluten.selected, isFalse);

      await _tapAndSettle(tester, find.text('Föregående'));

      final shiitakeGluten = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Gluten'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(shiitakeGluten.selected, isTrue);
    });
  });

  group('UnknownIngredientDialog completion', () {
    testWidgets(
        'tapping "Hoppa över alla" on the only item closes the dialog and resolves false',
        (tester) async {
      bool? result;
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
        onResult: (v) => result = v,
      )));
      await _open(tester);

      await _tapAndSettle(tester, find.text('Hoppa över alla'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('onComplete callback is invoked when the dialog closes',
        (tester) async {
      var completed = 0;
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
        onComplete: () => completed++,
      )));
      await _open(tester);

      await _tapAndSettle(tester, find.text('Hoppa över alla'));

      expect(completed, 1);
    });

    testWidgets(
        'tapping "Spara och stäng" with non-empty selections AND null userId closes with anyDefined=true',
        (tester) async {
      // Documents the contract that `_close(anyDefined: true)` is called
      // directly when properties are non-empty, regardless of whether the
      // service actually persisted anything. With userId null the service
      // branch is skipped but the future still resolves true.
      bool? result;
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
        onResult: (v) => result = v,
      )));
      await _open(tester);

      await _tapAndSettle(tester, find.text('Gluten'));
      await _tapAndSettle(tester, find.text('Spara och stäng'));

      expect(find.byType(AlertDialog), findsNothing);
      expect(result, isTrue);
    });
  });

  // SKIP (separate from the layout-bug skip): paths that require a
  // registered TaggingService:
  //   - Successful save with non-empty properties + non-null userId
  //     (verifies `taggingService.saveUserIngredient` is called with the
  //      right name + properties set, and that `_current.isDefined` flips).
  //   - Error path → SnackBar with dialogCouldNotSave + spinner clears.
  //   - Spinner shows while `_isSaving` is true (FilledButton disabled,
  //     CircularProgressIndicator child).
  //
  // These need `ServiceLocator.initialize(DIContainer())` + a stub
  // TaggingService — beyond the scope of a widget test for the dialog
  // itself, and gated on the layout-bug fix above anyway.
}
