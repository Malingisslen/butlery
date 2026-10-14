/// showUploadChoiceDialog: which actions each upload problem offers, and which
/// UploadChoice each one returns to the save flow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/widgets/recipe/upload_choice_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const pendingOnly = UploadSafetyResult(
    isSafe: false,
    pendingImagePaths: ['/p1.jpg', '/p2.jpg'],
  );
  const failedOnly = UploadSafetyResult(
    isSafe: false,
    failedImagePaths: ['/f1.jpg'],
  );
  const both = UploadSafetyResult(
    isSafe: false,
    pendingImagePaths: ['/p1.jpg'],
    failedImagePaths: ['/f1.jpg', '/f2.jpg', '/f3.jpg'],
  );

  // `choice` is only readable once `done` is true: a dialog that never closes
  // must not read as a null (dismissed) result.
  Future<({UploadChoice? Function() choice, bool Function() done})> open(
    WidgetTester tester,
    UploadSafetyResult result,
  ) async {
    UploadChoice? choice;
    var done = false;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              choice = await showUploadChoiceDialog(
                context: context,
                safetyResult: result,
              );
              done = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (choice: () => choice, done: () => done);
  }

  group('pending uploads only', () {
    testWidgets('offers Vänta and "Spara utan väntande bilder"', (
      tester,
    ) async {
      await open(tester, pendingOnly);

      expect(find.text('Bilduppladdning pågår'), findsOneWidget);
      expect(
        find.text('2 bilder laddas fortfarande upp.\n\nVad vill du göra?'),
        findsOneWidget,
      );
      expect(find.text('Vänta på uppladdning'), findsOneWidget);
      expect(find.text('Spara utan väntande bilder'), findsOneWidget);
      expect(find.text('Spara utan misslyckade bilder'), findsNothing);
    });

    testWidgets('Vänta returns UploadChoice.wait', (tester) async {
      final r = await open(tester, pendingOnly);

      await tester.tap(find.text('Vänta på uppladdning'));
      await tester.pumpAndSettle();

      expect(r.done(), isTrue);
      expect(r.choice(), UploadChoice.wait);
    });

    testWidgets('the pending save-without label returns saveWithoutPending', (
      tester,
    ) async {
      final r = await open(tester, pendingOnly);

      await tester.tap(find.text('Spara utan väntande bilder'));
      await tester.pumpAndSettle();

      expect(r.done(), isTrue);
      expect(r.choice(), UploadChoice.saveWithoutPending);
    });
  });

  group('failed uploads only', () {
    testWidgets('names the failure, offers no Vänta', (tester) async {
      await open(tester, failedOnly);

      expect(find.text('Bilduppladdning misslyckades'), findsOneWidget);
      expect(
        find.text('1 bild kunde inte laddas upp.\n\nVad vill du göra?'),
        findsOneWidget,
      );
      expect(find.text('Spara utan misslyckade bilder'), findsOneWidget);
      expect(find.text('Spara utan väntande bilder'), findsNothing);
      expect(find.text('Vänta på uppladdning'), findsNothing);
    });

    testWidgets('the failed save-without label returns saveWithoutPending', (
      tester,
    ) async {
      final r = await open(tester, failedOnly);

      await tester.tap(find.text('Spara utan misslyckade bilder'));
      await tester.pumpAndSettle();

      expect(r.done(), isTrue);
      expect(r.choice(), UploadChoice.saveWithoutPending);
    });
  });

  group('failed and pending together', () {
    testWidgets('reports both counts, offers Vänta and the failed label', (
      tester,
    ) async {
      await open(tester, both);

      expect(find.text('Bilduppladdning pågår'), findsOneWidget);
      expect(
        find.textContaining('(3)'),
        findsOneWidget,
        reason: 'three failed',
      );
      expect(find.textContaining('(1)'), findsOneWidget, reason: 'one pending');
      expect(find.text('Vänta på uppladdning'), findsOneWidget);
      expect(find.text('Spara utan misslyckade bilder'), findsOneWidget);
      expect(find.text('Spara utan väntande bilder'), findsNothing);
    });
  });

  group('leaving the dialog', () {
    testWidgets('Avbryt returns UploadChoice.cancel', (tester) async {
      final r = await open(tester, pendingOnly);

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(r.done(), isTrue);
      expect(r.choice(), UploadChoice.cancel);
    });

    testWidgets('dismissing by the barrier returns null, not a choice', (
      tester,
    ) async {
      final r = await open(tester, pendingOnly);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(r.done(), isTrue);
      expect(r.choice(), isNull);
    });
  });

  testWidgets('a safe result proceeds as wait without opening a dialog', (
    tester,
  ) async {
    final r = await open(tester, const UploadSafetyResult(isSafe: true));

    expect(find.byType(Dialog), findsNothing);
    expect(r.done(), isTrue);
    expect(r.choice(), UploadChoice.wait);
  });
}
