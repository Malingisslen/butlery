import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/services/parsing/ner/neural_ingredient_parser.dart';
import 'package:butlery/services/parsing/ner/onnx_ner_service.dart';
import 'package:butlery/services/parsing/ner/ner_model_manager.dart';

/// Mock NER service that returns predetermined predictions.
class MockOnnxNerService extends OnnxNerService {
  NerPrediction? nextPrediction;
  bool _available = true;

  MockOnnxNerService() : super();

  void setAvailable(bool available) => _available = available;

  @override
  bool get isAvailable => _available;

  @override
  Future<NerPrediction?> predict(List<String> words) async {
    return nextPrediction;
  }

  @override
  Future<List<NerPrediction?>> predictBatch(
      List<List<String>> wordsList) async {
    return wordsList.map((words) {
      if (words.isEmpty) return null;
      return nextPrediction;
    }).toList();
  }
}

/// Mock model manager that reports model as available.
class MockNerModelManager extends NerModelManager {
  bool _available = true;

  MockNerModelManager() : super();

  @override
  bool get isModelAvailable => _available;

  void setAvailable(bool available) => _available = available;

  @override
  Future<NerModelFiles?> ensureModelAvailable() async {
    return _available
        ? NerModelFiles(
            modelPath: '/fake/model.onnx',
            vocabContent: '[PAD]\n[UNK]\n[CLS]\n[SEP]',
            version: 1,
          )
        : null;
  }
}

void main() {
  late MockOnnxNerService mockNerService;
  late MockNerModelManager mockModelManager;
  late NeuralIngredientParser parser;

  setUp(() {
    mockNerService = MockOnnxNerService();
    mockModelManager = MockNerModelManager();
    parser = NeuralIngredientParser(
      nerService: mockNerService,
      modelManager: mockModelManager,
    );
  });

  group('parseLine', () {
    test('should return parsed ingredient for high confidence prediction',
        () async {
      mockNerService.nextPrediction = NerPrediction(
        labels: [BioLabel.bQty, BioLabel.bUnit, BioLabel.bName],
        confidence: 0.95,
      );

      final result = await parser.parseLine('2 dl mjölk');

      expect(result, isNotNull);
      expect(result!.name, 'mjölk');
      expect(result.quantity, '2');
      expect(result.unit, 'dl');
      expect(result.confidence, ParseConfidence.high);
    });

    test('should return null for low confidence prediction', () async {
      mockNerService.nextPrediction = NerPrediction(
        labels: [BioLabel.other, BioLabel.other, BioLabel.bName],
        confidence: 0.4, // Below threshold
      );

      final result = await parser.parseLine('lite salt');
      expect(result, isNull);
    });

    test('should return null when NER service is unavailable', () async {
      mockNerService.setAvailable(false);

      final result = await parser.parseLine('2 dl mjölk');
      expect(result, isNull);
    });

    test('should return null when prediction fails', () async {
      mockNerService.nextPrediction = null;

      final result = await parser.parseLine('2 dl mjölk');
      expect(result, isNull);
    });

    test('should handle multi-word ingredient names', () async {
      mockNerService.nextPrediction = NerPrediction(
        labels: [
          BioLabel.bQty,
          BioLabel.bUnit,
          BioLabel.bPrep,
          BioLabel.bName,
          BioLabel.iName,
        ],
        confidence: 0.9,
      );

      final result = await parser.parseLine('2 msk hackad persilja blad');

      expect(result, isNotNull);
      expect(result!.name, 'persilja blad');
      expect(result.quantity, '2');
      expect(result.unit, 'msk');
      expect(result.preparation, 'hackad');
    });

    test('should handle name-only lines', () async {
      mockNerService.nextPrediction = NerPrediction(
        labels: [BioLabel.bName],
        confidence: 0.85,
      );

      final result = await parser.parseLine('salt');

      expect(result, isNotNull);
      expect(result!.name, 'salt');
      expect(result.quantity, isNull);
      expect(result.unit, isNull);
    });

    test('should handle size labels', () async {
      mockNerService.nextPrediction = NerPrediction(
        labels: [
          BioLabel.bQty,
          BioLabel.bSize,
          BioLabel.bName,
        ],
        confidence: 0.88,
      );

      final result = await parser.parseLine('3 stora potatisar');

      expect(result, isNotNull);
      expect(result!.name, 'potatisar');
      expect(result.quantity, '3');
      expect(result.size, 'stora');
    });

    test('should skip punctuation tokens in span assembly', () async {
      // "1 burk tomater , krossade" with comma as punctuation
      mockNerService.nextPrediction = NerPrediction(
        labels: [
          BioLabel.bQty,
          BioLabel.bUnit,
          BioLabel.bName,
          BioLabel.other, // comma
          BioLabel.bPrep,
        ],
        confidence: 0.9,
      );

      final result = await parser.parseLine('1 burk tomater , krossade');

      expect(result, isNotNull);
      expect(result!.name, 'tomater');
      expect(result.preparation, 'krossade');
    });
  });

  group('parseLines', () {
    test('should return results for confident predictions only', () async {
      mockNerService.nextPrediction = NerPrediction(
        labels: [BioLabel.bQty, BioLabel.bUnit, BioLabel.bName],
        confidence: 0.95,
      );

      final results = await parser.parseLines([
        '2 dl mjölk',
        '1 msk smör',
      ]);

      expect(results.length, 2);
      expect(results.containsKey(0), true);
      expect(results.containsKey(1), true);
    });

    test('should return empty map when NER is unavailable', () async {
      mockNerService.setAvailable(false);

      final results = await parser.parseLines(['2 dl mjölk']);
      expect(results, isEmpty);
    });
  });

  group('availability', () {
    test('isAvailable reflects NER service state', () {
      mockNerService.setAvailable(true);
      expect(parser.isAvailable, true);

      mockNerService.setAvailable(false);
      expect(parser.isAvailable, false);
    });
  });
}
