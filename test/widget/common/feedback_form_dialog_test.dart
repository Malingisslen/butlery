/// Widget tests for [FeedbackFormDialog].
///
/// The dialog is a full-screen Scaffold (Dialog.fullscreen) with:
/// - Category dropdown (FeedbackCategory.bug default)
/// - Description TextField (multiline, 2000 chars)
/// - Email TextField (optional, 100 chars)
/// - Optional screenshot preview (Image.memory + remove IconButton)
/// - Submit FilledButton that goes through FeedbackService.submitFeedback
///
/// We cover rendering, screenshot toggling, and the empty-description guard
/// (which shows a SnackBar without calling the service — so it's safe to
/// test even without registering FeedbackService). Submission paths that
/// actually call `ServiceLocator.get<FeedbackService>()` are documented with
/// // SKIP: comments because mocking BaseService + GetIt + auth + repository
/// scaffolding is out of scope for a widget test.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/feedback_form_dialog.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// 1x1 transparent PNG — smallest valid byte payload Image.memory accepts.
Uint8List _tinyPng() => Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, //
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, //
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, //
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, //
  0x42, 0x60, 0x82,
]);

/// Pumps the dialog directly inside a Scaffold so the layout pass doesn't
/// have to mediate a route transition.
Widget _hostDialog({Uint8List? screenshot}) =>
    FeedbackFormDialog(screenshot: screenshot);

void main() {
  group('FeedbackFormDialog rendering', () {
    testWidgets('renders the localized AppBar title "Skicka feedback"', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      // AppBar title text — explicit Swedish per app_sv.arb.
      expect(find.text('Skicka feedback'), findsOneWidget);
    });

    testWidgets(
      'renders all three section labels (category, description, email)',
      (tester) async {
        await tester.pumpWidget(_wrap(_hostDialog()));
        await tester.pumpAndSettle();

        expect(find.text('Kategori'), findsOneWidget);
        expect(find.text('Beskrivning'), findsOneWidget);
        expect(find.text('E-post (valfritt)'), findsOneWidget);
      },
    );

    testWidgets(
      'description field renders with localized hint and 2000 maxLength',
      (tester) async {
        await tester.pumpWidget(_wrap(_hostDialog()));
        await tester.pumpAndSettle();

        // The hint text is rendered as a Text widget inside the field decoration.
        expect(find.text('Beskriv vad du upplevde...'), findsOneWidget);

        // Two TextFields (description + email). Pick the multiline one via
        // maxLength to verify the cap is wired correctly.
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.any((f) => f.maxLength == 2000), isTrue);
      },
    );

    testWidgets('email field renders with localized hint and 100 maxLength', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      expect(find.text('din@email.se'), findsOneWidget);

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.any((f) => f.maxLength == 100), isTrue);
    });

    testWidgets('email field uses emailAddress keyboard type', (tester) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      final fields = tester.widgetList<TextField>(find.byType(TextField));
      // Description is multiline (default TextInputType.text), email is
      // emailAddress. Verify at least one field carries it.
      expect(
        fields.any((f) => f.keyboardType == TextInputType.emailAddress),
        isTrue,
      );
    });

    testWidgets('submit button renders the localized "Skicka" label', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      // FilledButton child = Text('Skicka') when not submitting.
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Skicka'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('close (X) icon button is visible in the AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.close),
        ),
        findsOneWidget,
      );
    });
  });

  group('FeedbackFormDialog category dropdown', () {
    testWidgets('defaults to "Bugg" (FeedbackCategory.bug)', (tester) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      // Two text widgets carry "Bugg" while menu is closed: the dropdown's
      // displayed selection AND the hidden one used to size the field.
      // findsAtLeast keeps the assertion robust to that internal detail.
      expect(find.text('Bugg'), findsAtLeastNWidgets(1));
    });

    testWidgets('opening dropdown reveals all three category options', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<FeedbackCategory>));
      await tester.pumpAndSettle();

      // After tap, the overlay shows all three items at minimum once.
      expect(find.text('Bugg'), findsAtLeastNWidgets(1));
      expect(find.text('Önskemål'), findsAtLeastNWidgets(1));
      expect(find.text('Övrigt'), findsAtLeastNWidgets(1));
    });

    testWidgets('selecting "Önskemål" updates the dropdown display', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<FeedbackCategory>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Önskemål').last);
      await tester.pumpAndSettle();

      // After selection the field renders the chosen value.
      expect(find.text('Önskemål'), findsAtLeastNWidgets(1));
    });
  });

  group('FeedbackFormDialog screenshot handling', () {
    testWidgets('no screenshot label/preview when widget.screenshot is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      expect(find.text('Skärmavbild'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'screenshot section renders when widget.screenshot is provided',
      (tester) async {
        await tester.pumpWidget(_wrap(_hostDialog(screenshot: _tinyPng())));
        await tester.pumpAndSettle();

        expect(find.text('Skärmavbild'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);

        // Remove screenshot IconButton with tooltip — two Icons.close exist
        // (AppBar leading + screenshot remove) so we scope by tooltip.
        expect(
          find.byTooltip('Ta bort skärmavbild'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping remove icon clears the screenshot preview', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog(screenshot: _tinyPng())));
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);

      await tester.tap(find.byTooltip('Ta bort skärmavbild'));
      await tester.pumpAndSettle();

      // After removal, label and preview should both be gone.
      expect(find.text('Skärmavbild'), findsNothing);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('FeedbackFormDialog empty-description guard', () {
    testWidgets(
      'tapping Skicka with empty description shows the required SnackBar '
      'and does not call the service',
      (tester) async {
        // ServiceLocator is not initialized; if _submit got past the
        // description check it would throw — so this also implicitly verifies
        // the guard short-circuits before service access.
        await tester.pumpWidget(_wrap(_hostDialog()));
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.text('Skicka'),
          ),
        );
        await tester.pump(); // run the synchronous part of _submit

        // SnackBar with the localized required-message appears.
        expect(find.text('Ange en beskrivning'), findsOneWidget);
        // No exception bubbled up — service path was never entered.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('whitespace-only description is treated as empty', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_hostDialog()));
      await tester.pumpAndSettle();

      // Enter whitespace into the description (the field with maxLength=2000).
      final descField = find.byWidgetPredicate(
        (w) => w is TextField && w.maxLength == 2000,
      );
      await tester.enterText(descField, '   \t  ');
      await tester.tap(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Skicka'),
        ),
      );
      await tester.pump();

      expect(find.text('Ange en beskrivning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // SKIP: Full submission paths (success → SnackBar "Tack för din feedback!"
  // + pop; failure → red error SnackBar) require ServiceLocator.initialize
  // with a DIContainer that registers a stub FeedbackService AND a stub
  // AuthRepository (because submitFeedback reads currentUserId via GetIt).
  // The mock_factory has no FeedbackService factory today, so building one
  // would balloon this widget test beyond its scope. Behavior covered by:
  //   - The empty-description guard tests above (proves the synchronous
  //     branch + SnackBar plumbing).
  //   - The category dropdown + screenshot tests (prove state is captured
  //     correctly before _submit reads it).
  // Untested branches: _isSubmitting spinner, success/failure SnackBars,
  // Navigator.pop on success.
}
