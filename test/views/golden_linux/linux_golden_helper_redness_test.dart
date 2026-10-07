import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../design_states/state_harness.dart';
import 'linux_golden_helper.dart';

/// Throws on compare, as LocalFileComparator does on a pixel mismatch.
class _ThrowingComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    throw FlutterError('Golden "$golden": Pixel test failed.');
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}

/// Runs [expectScreenGolden] under the state harness's error capture, the
/// handler the key-screen goldens compare beneath, and returns what it threw.
Future<Object?> _compareUnderHarness(WidgetTester tester) async {
  final capture = captureFrameworkErrors();
  await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  Object? thrown;
  try {
    await expectScreenGolden('goldens/deliberately_missing.png');
  } catch (e) {
    thrown = e;
  }
  capture.restore();
  return thrown;
}

void main() {
  // Under --update-goldens the matcher calls update() and never compare(),
  // so there is no mismatch to see.
  group('expectScreenGolden (BUT-2282)', skip: autoUpdateGoldenFiles, () {
    setUp(() {
      final previous = goldenFileComparator;
      goldenFileComparator = _ThrowingComparator();
      addTearDown(() => goldenFileComparator = previous);
    });

    testWidgets('a mismatch fails the test, not only the harness', (
      tester,
    ) async {
      final thrown = await _compareUnderHarness(tester);

      expect(thrown, isA<TestFailure>());
      expect('$thrown', contains('Pixel test failed'));
      // The harness never saw it, so nothing is left for finishState to
      // file away as a violation.
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'a failed image load during the comparison is still dropped',
    (
      tester,
    ) async {
      final previous = goldenFileComparator;
      goldenFileComparator = _ReportingComparator();
      addTearDown(() => goldenFileComparator = previous);

      final thrown = await _compareUnderHarness(tester);

      expect(thrown, isNull);
      expect(tester.takeException(), isNull);
    },
    skip: autoUpdateGoldenFiles,
  );
}

/// Reports an image-load failure while comparing, then matches.
class _ReportingComparator extends GoldenFileComparator {
  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: Exception('404 on a network image'),
        library: 'image resource service',
      ),
    );
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}
}
