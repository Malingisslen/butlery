/// Parser shadow comparison (ADR-0037): [ImportManager] offers a finished
/// import to the sampler exactly once, from the shared success step — never
/// from a re-parse of an import already measured, never from a failure.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/parser_shadow_sampler.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class _QuietParseEventLogger extends ParseEventLogger {
  @override
  void log(ImportEvent event) {}
}

class _SpySampler extends ParserShadowSampler {
  _SpySampler()
    : super(
        consentService: MockConsentService(),
        llmService: _NoLlm(),
      );

  final List<(ImportChannel, ImportManagerResult)> offered = [];
  Future<bool> answer = Future.value(false);

  @override
  Future<bool> sample(ImportChannel channel, ImportManagerResult result) {
    offered.add((channel, result));
    return answer;
  }
}

class _NoLlm extends Mock implements LlmService {}

class _Strategy extends ImportStrategy {
  _Strategy(this.recipe, {this.metadata});
  final Recipe? recipe;
  final Map<String, dynamic>? metadata;

  @override
  String get strategyName => 'Text Import';
  @override
  bool canHandle(String input) => true;
  @override
  bool validateInput(String input) => true;
  @override
  String get inputExample => '';
  @override
  String get description => '';

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async => recipe == null
      ? ImportResult.failure('nej')
      : ImportResult.success(recipe!, metadata: metadata);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPersonalRecipeOperations ops;
  late _SpySampler spy;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    ops = MockPersonalRecipeOperations();
    spy = _SpySampler();
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  ImportManager managerWith(
    Recipe? recipe, {
    Map<String, dynamic>? metadata,
  }) => ImportManager.withStrategies(
    ops,
    [_Strategy(recipe, metadata: metadata)],
    eventLogger: _QuietParseEventLogger(),
    shadowSampler: spy,
  );

  final recipe = RecipeFactory.build(id: 'r1', title: 'Pannkakor');

  test(
    'a measured import that succeeds is offered once, with its channel',
    () async {
      final r = await managerWith(recipe).autoImport('Pannkakor\n\n3 ägg');

      expect(r.isSuccess, isTrue);
      expect(spy.offered, hasLength(1));
      expect(spy.offered.single.$1, ImportChannel.text);
      expect(spy.offered.single.$2.recipe, same(r.recipe));
    },
  );

  test('a measured multi-parse is offered once', () async {
    await managerWith(recipe).autoParseMulti(
      'Pannkakor\n\n3 ägg',
      channel: ImportChannel.photo,
    );

    expect(spy.offered, hasLength(1));
    expect(spy.offered.single.$1, ImportChannel.photo);
  });

  test('a re-parse of an import already measured is never offered', () async {
    await managerWith(
      recipe,
    ).autoParseMulti('Pannkakor\n\n3 ägg', channel: null);

    expect(spy.offered, isEmpty);
  });

  test('a sample that never answers does not hold the import back', () async {
    spy.answer = Completer<bool>().future;

    final r = await managerWith(
      recipe,
    ).autoImport('Pannkakor\n\n3 ägg').timeout(const Duration(seconds: 5));

    expect(r.isSuccess, isTrue);
    expect(spy.offered, hasLength(1), reason: 'the sample was still asked');
  });

  group('a link import', () {
    const url = 'https://ica.se/recept/pannkakor';
    const pageText = 'Pannkakor\n3 dl vetemjöl\nVispa och stek.';
    final meta = {'pageText': pageText, 'successfulTier': 'HtmlTextParse'};

    test('is offered with its page text, as channel link', () async {
      await managerWith(recipe, metadata: meta).autoImport(url);

      expect(spy.offered, hasLength(1));
      expect(spy.offered.single.$1, ImportChannel.link);
      expect(spy.offered.single.$2.metadata?['pageText'], pageText);
    });

    test('returns to its caller without the page text', () async {
      final r = await managerWith(recipe, metadata: meta).autoImport(url);

      expect(r.isSuccess, isTrue);
      expect(r.metadata?.containsKey('pageText'), isFalse);
      expect(r.metadata?['successfulTier'], 'HtmlTextParse');
    });

    test('is not held back by a sample that never answers', () async {
      spy.answer = Completer<bool>().future;

      final r = await managerWith(
        recipe,
        metadata: meta,
      ).autoImport(url).timeout(const Duration(seconds: 5));

      expect(r.isSuccess, isTrue);
      expect(spy.offered, hasLength(1));
    });
  });

  test('a failed import is never offered', () async {
    await managerWith(null).autoImport('någonting');

    expect(spy.offered, isEmpty);
  });
}
