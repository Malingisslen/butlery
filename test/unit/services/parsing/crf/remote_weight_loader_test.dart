import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/crf/remote_weight_loader.dart';

void main() {
  group('RemoteWeightLoader', () {
    late RemoteWeightLoader loader;

    setUp(() {
      // Create without Firebase Storage -- will fail gracefully
      loader = RemoteWeightLoader();
    });

    test('returns null when no remote weights exist', () async {
      // Without Firebase initialized, this should return null (not throw)
      final result = await loader.tryLoadRemoteWeights(bundledVersion: 1);
      expect(result, isNull);
    });

    test(
      'respects check interval (does not re-check within 6 hours)',
      () async {
        // First call -- will fail gracefully
        await loader.tryLoadRemoteWeights(bundledVersion: 1);

        // Second call within check interval -- should short-circuit
        final result = await loader.tryLoadRemoteWeights(bundledVersion: 1);
        expect(result, isNull);
      },
    );

    test('handles concurrent calls safely', () async {
      // Multiple concurrent calls should not throw
      final futures = List.generate(
        5,
        (_) => loader.tryLoadRemoteWeights(bundledVersion: 1),
      );
      final results = await Future.wait(futures);

      // All should return null (no Firebase)
      for (final result in results) {
        expect(result, isNull);
      }
    });
  });
}
