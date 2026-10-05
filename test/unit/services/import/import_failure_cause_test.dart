/// BUT-2237: a failed link import carries its cause from the strategy, through
/// the [ImportManager], to the text the smart-import screen shows.
///
/// Each case runs the real [UrlImportStrategy] (pages served by a
/// [MockClient], no parser service, no LLM), the real [ImportManager] and the
/// real [SmartImportViewModel]; only the HTTP answer differs between them.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _NoWebScraper extends Mock implements WebScraper {}

class _SilentEventLogger extends Mock implements ParseEventLogger {}

class _FailingStrategy extends ImportStrategy {
  _FailingStrategy(this.strategyName, this.code);

  @override
  final String strategyName;
  final ImportErrorCode? code;

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
  }) async => ImportResult.failure(
    '$strategyName failed',
    errorCode: code,
    metadata: {'from': strategyName},
  );
}

const _url = 'https://8.8.8.8/recept/kladdkaka';

/// A readable page with no recipe on it: long enough for every text tier to
/// look at, and with nothing they can call an ingredient or a step.
final _pageWithoutRecipe =
    '<html><head><title>Om oss</title></head><body>'
    '${'<p>Vi är ett litet företag som skriver om resor och böcker.</p>' * 12}'
    '</body></html>';

final _loginPage =
    '<html><head><title>Logga in</title></head><body>'
    '<form action="/login"><input type="email" name="user">'
    '<input type="password" name="pass"><button>Logga in</button></form>'
    '${'<p>Logga in för att läsa vidare.</p>' * 8}'
    '</body></html>';

Future<ImportFailed> _importWith(http.Response response) async {
  final strategy = UrlImportStrategy(
    httpClient: MockClient((_) async => response),
    webScraperFactory: _NoWebScraper.new,
    dnsLookup: (_) async => [InternetAddress('8.8.8.8')],
  );
  final manager = ImportManager.withStrategies(
    MockPersonalRecipeOperations(),
    [strategy],
    eventLogger: _SilentEventLogger(),
  );
  final viewModel = SmartImportViewModel(importManager: manager)
    ..updateInput(_url);
  final result = await viewModel.startImport();
  viewModel.dispose();
  return result as ImportFailed;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('a broken link (404) says the page could not be reached', () async {
    final r = await _importWith(http.Response('', 404));
    expect(r.errorCode, ImportErrorCode.urlNotAccessible);
    expect(r.message, 'Kunde inte nå sidan');
  });

  test('a 403 says the page requires login', () async {
    final r = await _importWith(http.Response('', 403));
    expect(r.errorCode, ImportErrorCode.platformBlocked);
    expect(r.message, 'Sidan kräver inloggning');
  });

  test('a page that is only a login form says it requires login', () async {
    final r = await _importWith(
      http.Response(
        _loginPage,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    );
    expect(r.errorCode, ImportErrorCode.platformBlocked);
    expect(r.message, 'Sidan kräver inloggning');
  });

  test('a readable page without a recipe says no recipe was found', () async {
    final r = await _importWith(
      http.Response(
        _pageWithoutRecipe,
        200,
        headers: {'content-type': 'text/html; charset=utf-8'},
      ),
    );
    expect(r.errorCode, ImportErrorCode.noRecipeContent);
    expect(r.message, 'Inget recept hittades');
  });

  group('UrlImportStrategy.failureCodeFor', () {
    test('no page and no status → the page could not be reached', () {
      expect(
        UrlImportStrategy.failureCodeFor(null, const HtmlFetch.unreached()),
        ImportErrorCode.urlNotAccessible,
      );
    });

    test('a 401 is a login wall, a 500 is an unreachable page', () {
      expect(
        UrlImportStrategy.failureCodeFor(null, const HtmlFetch.status(401)),
        ImportErrorCode.platformBlocked,
      );
      expect(
        UrlImportStrategy.failureCodeFor(null, const HtmlFetch.status(500)),
        ImportErrorCode.urlNotAccessible,
      );
    });
  });

  group('ImportManager keeps the failure that knows its cause', () {
    Future<ImportManagerResult> run(List<ImportStrategy> strategies) =>
        ImportManager.withStrategies(
          MockPersonalRecipeOperations(),
          strategies,
          eventLogger: _SilentEventLogger(),
        ).autoImport('någonting');

    test('a coded failure beats an earlier uncoded one', () async {
      final r = await run([
        _FailingStrategy('Text Import', null),
        _FailingStrategy('URL Import', ImportErrorCode.noRecipeContent),
      ]);
      expect(r.errorCode, ImportErrorCode.noRecipeContent);
      expect(r.errorMessage, 'URL Import failed');
      expect(r.metadata, {'from': 'URL Import'});
      expect(r.availableStrategies, ['Text Import', 'URL Import']);
    });

    test('of two coded failures the first one stays', () async {
      final r = await run([
        _FailingStrategy('URL Import', ImportErrorCode.urlNotAccessible),
        _FailingStrategy('Text Import', ImportErrorCode.noRecipeContent),
      ]);
      expect(r.errorCode, ImportErrorCode.urlNotAccessible);
    });
  });
}
