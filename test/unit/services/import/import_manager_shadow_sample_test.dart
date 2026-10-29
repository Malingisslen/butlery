/// Parser shadow comparison (ADR-0037): [ImportManager] offers a finished
/// import to the sampler exactly once, from the shared success step — never
/// from a re-parse of an import already measured, never from a failure.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
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
  _Strategy(this.recipe);
  final Recipe? recipe;

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
      : ImportResult.success(recipe!);
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
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ParserShadowSampler>()) {
      getIt.unregister<ParserShadowSampler>();
    }
    getIt.registerSingleton<ParserShadowSampler>(spy);
    // Without this, tryGet finds nothing and every "never" below would pass
    // for free.
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ParserShadowSampler>()) {
      getIt.unregister<ParserShadowSampler>();
    }
    app_provider.ServiceLocator.reset();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  ImportManager managerWith(Recipe? recipe) => ImportManager.withStrategies(
    ops,
    [_Strategy(recipe)],
    eventLogger: _QuietParseEventLogger(),
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

  test('a failed import is never offered', () async {
    await managerWith(null).autoImport('någonting');

    expect(spy.offered, isEmpty);
  });
}
