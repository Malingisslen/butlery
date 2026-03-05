import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/line_classifier/onnx_line_classifier_service.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

void main() {
  group('OnnxLineClassifierService', () {
    late OnnxLineClassifierService service;

    setUp(() {
      service = OnnxLineClassifierService();
    });

    test('isAvailable is false before initialization', () {
      expect(service.isAvailable, false);
    });

    test('classifyBatch returns fallback when not initialized', () async {
      final results = await service.classifyBatch([
        '2 dl mjölk',
        '',
        'Blanda allt.',
      ]);

      expect(results.length, 3);

      // Empty lines are always classified as empty
      expect(results[1].type, LineType.empty);
      expect(results[1].confidence, 1.0);

      // Non-empty lines get noise fallback when not initialized
      expect(results[0].type, LineType.noise);
      expect(results[0].confidence, 0.3);
      expect(results[2].type, LineType.noise);
      expect(results[2].confidence, 0.3);
    });

    test('classifyBatch returns empty list for empty input', () async {
      final results = await service.classifyBatch([]);
      expect(results, isEmpty);
    });

    test('classifyBatch handles all-empty lines', () async {
      final results = await service.classifyBatch(['', '  ', '']);

      expect(results.length, 3);
      for (final r in results) {
        expect(r.type, LineType.empty);
        expect(r.confidence, 1.0);
      }
    });

    test('dispose resets state', () async {
      await service.dispose();
      expect(service.isAvailable, false);
    });
  });
}
