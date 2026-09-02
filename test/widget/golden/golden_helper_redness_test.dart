import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_helper.dart';

/// Reports a mismatch the way [LocalFileComparator] does — by throwing rather
/// than by returning false. That shape is what makes the swallowing possible:
/// `matchesGoldenFile` runs the comparator inside `binding.runAsync`, which
/// catches the throw, routes it to `FlutterError.onError` and completes with
/// `null`, and `null` is the matcher's word for "matched".
class _ThrowingComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    throw FlutterError('Golden "$golden": Pixel test failed.');
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}

Future<void> _pumpAndCompare(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox(width: 20, height: 20));
  await expectLater(
    find.byType(SizedBox).first,
    matchesGoldenFile('goldens/deliberately_missing.png'),
  );
}

void main() {
  group('installGoldenImageErrorFilter — golden comparison path', () {
    setUp(() {
      final previousComparator = goldenFileComparator;
      goldenFileComparator = _ThrowingComparator();
      addTearDown(() => goldenFileComparator = previousComparator);
    });

    // Both tests in this group are skipped under `--update-goldens`, the command
    // `golden_helper.dart` documents for this very directory. With
    // `autoUpdateGoldenFiles` set, `matchesGoldenFile` short-circuits to
    // `goldenFileComparator.update(...)` and returns before `compare(...)` runs,
    // so `_ThrowingComparator` never throws: the first test fails and the second
    // passes for the wrong reason. They are a control pair and skip together.
    testWidgets(
      'a golden mismatch reaches the test binding',
      skip: autoUpdateGoldenFiles,
      (
        tester,
      ) async {
        final previousOnError = installGoldenImageErrorFilter();
        addTearDown(() => FlutterError.onError = previousOnError);

        await _pumpAndCompare(tester);

        // takeException() is both the assertion and the reason this test can
        // itself pass: it proves the binding recorded the failure, and clearing
        // it stops that recorded failure from failing this test at teardown.
        expect(tester.takeException(), isA<FlutterError>());
      },
    );

    testWidgets(
      'the blanket handler this replaced swallowed it',
      skip: autoUpdateGoldenFiles,
      (
        tester,
      ) async {
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (_) {}; // LINT-EXEMPT: golden-blindness — the
        // blank handler IS this test's subject; it is the control that proves
        // the filter above is what makes the mismatch visible (BUT-1946).
        addTearDown(() => FlutterError.onError = previousOnError);

        await _pumpAndCompare(tester);

        // The control: without the filter, the same mismatch leaves no trace and
        // `expectLater` above passes. If this ever starts throwing, the test
        // above has stopped depending on the filter.
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('installGoldenImageErrorFilter — error routing', () {
    testWidgets('drops a failed image load', (tester) async {
      final previousOnError = installGoldenImageErrorFilter();
      addTearDown(() => FlutterError.onError = previousOnError);

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Exception('404 on a network image'),
          library: 'image resource service',
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('forwards everything else', (tester) async {
      final previousOnError = installGoldenImageErrorFilter();
      addTearDown(() => FlutterError.onError = previousOnError);

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: Exception('a real widget failure'),
          library: 'widgets library',
        ),
      );

      expect(tester.takeException(), isNotNull);
    });
  });
}
