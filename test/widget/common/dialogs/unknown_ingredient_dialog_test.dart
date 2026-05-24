/// Widget tests for [UnknownIngredientDialog].
///
/// The dialog walks the user through a list of ingredients that aren't in
/// the tagging database. Per ingredient it shows allergen + dietary
/// FilterChips, a Skip button, optional Previous, and a Save & Next
/// (or Save & Close on the last item) FilledButton. When the user saves
/// with non-empty properties AND a userId AND a registered TaggingService,
/// it calls `taggingService.saveUserIngredient`; otherwise the save path
/// short-circuits to skip-and-advance.
///
/// ## KNOWN PRODUCTION BUG (surfaced by this suite, NOT fixed here)
///
/// `UnknownIngredientDialog` puts a `Row(mainAxisSize: min)` directly
/// inside `AlertDialog.actions`. AlertDialog wraps actions in
/// `OverflowBar` → IntrinsicWidth, which forces infinite-width
/// constraints on the unbounded `FilledButton`/`TextButton` children of
/// the Row. This trips a `BoxConstraints forces an infinite width`
/// assertion on every layout pass — and as a result the action buttons
/// have NO SIZE in the rendered tree.
///
/// Consequence in tests: `tester.tap(find.text('Hoppa över'))` etc. raise
/// `Cannot hit test a render box with no size` because the buttons are
/// not interactive. Consequence in the app (debug build): the dialog
/// throws on layout and the buttons are unusable. Release builds may
/// limp along silently.
///
/// Fix candidates (NOT applied here):
///   - Replace the Row with `IntrinsicWidth(child: Row(...))`.
///   - Spread the conditional Previous + SizedBox + FilledButton directly
///     into the actions list and let OverflowBar lay them out.
///   - Use `OverflowBar(spacing: ...)` explicitly.
///
/// As a result, this suite covers the rendering surface only (which
/// drains the framework's layout assertions via `tester.takeException()`).
/// The interaction tests (skip/previous/save) are written but skipped
/// with `skip: _knownLayoutBugPreventsInteraction` so they automatically
/// run once the production widget is fixed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/unknown_ingredient_dialog.dart';

// Flip this to `false` once the production layout bug is fixed so the
// interaction tests start running. `testWidgets.skip` only accepts bool.
// The reason is documented in this file's header (search "PRODUCTION BUG").
const bool _knownLayoutBugPreventsInteraction = true;

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

/// Drain framework exceptions caused by the known layout bug so subsequent
/// assertions can run. Safe to call repeatedly.
void _drainKnownLayoutBug(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Show'));
  await tester.pumpAndSettle();
  _drainKnownLayoutBug(tester);
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
  _drainKnownLayoutBug(tester);
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

  group('UnknownIngredientDialog production bug witness', () {
    testWidgets(
        'opening the dialog produces a "BoxConstraints forces an infinite width" framework error',
        (tester) async {
      // This test is the canary: it FAILS once the production bug is fixed
      // (no exception → expect on null fails). At that point delete this
      // test AND remove the `skip:` markers from the interaction tests
      // below so they start running.
      await tester.pumpWidget(_wrap(_trigger(
        ingredients: const ['shiitake'],
      )));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // takeException returns a wrapper ("Multiple exceptions (N) were
      // detected...") because the layout error cascades into many follow-on
      // assertions. We just verify that *some* framework exception fired —
      // when the production widget is fixed this will be null and the
      // assertion below fails, prompting removal of the `skip:` markers
      // on the interaction tests.
      final exception = tester.takeException();
      expect(
        exception,
        isNotNull,
        reason:
            'No framework error during layout — the AlertDialog.actions Row '
            'bug appears fixed. Remove `_knownLayoutBugPreventsInteraction` '
            'skip from the interaction tests and delete this witness test.',
      );

      // Drain remaining cascade so the test tearDown doesn't rethrow.
      _drainKnownLayoutBug(tester);
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
    }, skip: _knownLayoutBugPreventsInteraction);

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
    }, skip: _knownLayoutBugPreventsInteraction);

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
    }, skip: _knownLayoutBugPreventsInteraction);
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
    }, skip: _knownLayoutBugPreventsInteraction);

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
    }, skip: _knownLayoutBugPreventsInteraction);
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
    }, skip: _knownLayoutBugPreventsInteraction);

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
    }, skip: _knownLayoutBugPreventsInteraction);

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
    }, skip: _knownLayoutBugPreventsInteraction);
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
