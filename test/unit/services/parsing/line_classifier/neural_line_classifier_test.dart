import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/line_classifier/line_classifier_model_manager.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';
import 'package:butlery/services/parsing/line_classifier/onnx_line_classifier_service.dart';
import 'package:butlery/services/parsing/parsers/swedish_line_classifier.dart';

/// Mock ONNX line classifier that returns predetermined results.
class MockOnnxLineClassifierService extends OnnxLineClassifierService {
  List<ClassifiedLine>? nextBatchResult;
  bool _available = false;

  MockOnnxLineClassifierService() : super();

  void setAvailable(bool available) => _available = available;

  @override
  bool get isAvailable => _available;

  @override
  Future<List<ClassifiedLine>> classifyBatch(List<String> lines) async {
    if (nextBatchResult != null) return nextBatchResult!;
    return lines.map((l) {
      if (l.trim().isEmpty) {
        return ClassifiedLine(text: l, type: LineType.empty, confidence: 1.0);
      }
      return ClassifiedLine(text: l, type: LineType.noise, confidence: 0.3);
    }).toList();
  }

  @override
  Future<bool> initialize({
    required String modelPath,
    required String vocabContent,
  }) async {
    _available = true;
    return true;
  }
}

/// Mock model manager that controls model availability.
class MockLineClassifierModelManager extends LineClassifierModelManager {
  bool _available = true;

  MockLineClassifierModelManager() : super();

  void setAvailable(bool available) => _available = available;

  @override
  Future<LineClassifierModelFiles?> ensureModelAvailable() async {
    return _available
        ? LineClassifierModelFiles(
            modelPath: '/fake/model.onnx',
            vocabContent: '[PAD]\n[UNK]\n[CLS]\n[SEP]',
            version: 1,
          )
        : null;
  }
}

void main() {
  late MockOnnxLineClassifierService mockService;
  late MockLineClassifierModelManager mockModelManager;
  late NeuralLineClassifier classifier;

  setUp(() {
    mockService = MockOnnxLineClassifierService();
    mockModelManager = MockLineClassifierModelManager();
    classifier = NeuralLineClassifier(
      classifierService: mockService,
      modelManager: mockModelManager,
    );
  });

  group('fallback behavior', () {
    test('falls back to SwedishLineClassifier when model unavailable', () {
      mockService.setAvailable(false);

      final result = classifier.parseStructure(
        'Pannkakor\n\n2 dl mjölk\n3 ägg\n\nBlanda allt.',
      );

      // Should still produce results from rule-based classifier
      expect(result.ingredients, isNotEmpty);
      expect(result.instructions, isNotEmpty);
    });

    test('parseStructureAsync falls back when model unavailable', () async {
      mockService.setAvailable(false);

      final result = await classifier.parseStructureAsync(
        'Pannkakor\n\n2 dl mjölk\n3 ägg\n\nBlanda allt.',
      );

      expect(result.ingredients, isNotEmpty);
    });
  });

  group('neural classification', () {
    test('uses ONNX when model is available', () async {
      mockService.setAvailable(true);
      mockService.nextBatchResult = [
        ClassifiedLine(
          text: 'Pannkakor',
          type: LineType.title,
          confidence: 0.92,
        ),
        ClassifiedLine(
          text: '',
          type: LineType.empty,
          confidence: 1.0,
        ),
        ClassifiedLine(
          text: '2 dl mjölk',
          type: LineType.ingredient,
          confidence: 0.95,
        ),
        ClassifiedLine(
          text: '3 ägg',
          type: LineType.ingredient,
          confidence: 0.88,
        ),
        ClassifiedLine(
          text: '',
          type: LineType.empty,
          confidence: 1.0,
        ),
        ClassifiedLine(
          text: 'Blanda allt.',
          type: LineType.instruction,
          confidence: 0.90,
        ),
      ];

      final result = await classifier.parseStructureAsync(
        'Pannkakor\n\n2 dl mjölk\n3 ägg\n\nBlanda allt.',
      );

      expect(result.title, 'Pannkakor');
      expect(result.ingredients, ['2 dl mjölk', '3 ägg']);
      expect(result.instructions, ['Blanda allt.']);
    });
  });

  group('initialization', () {
    test('ensureInitialized returns true when model available', () async {
      final ready = await classifier.ensureInitialized();
      expect(ready, true);
      expect(classifier.isAvailable, true);
    });

    test('ensureInitialized returns false when model unavailable', () async {
      mockModelManager.setAvailable(false);
      final ready = await classifier.ensureInitialized();
      expect(ready, false);
    });

    test('only attempts initialization once', () async {
      mockModelManager.setAvailable(false);

      // First attempt fails
      final first = await classifier.ensureInitialized();
      expect(first, false);

      // Second attempt skips (already attempted)
      mockModelManager.setAvailable(true);
      final second = await classifier.ensureInitialized();
      expect(second, false);
    });
  });

  group('isAvailable', () {
    test('reflects ONNX service state', () {
      mockService.setAvailable(true);
      expect(classifier.isAvailable, true);

      mockService.setAvailable(false);
      expect(classifier.isAvailable, false);
    });
  });
}
