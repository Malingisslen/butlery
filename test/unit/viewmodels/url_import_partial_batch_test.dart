/// P5-U22: a partly fetched URL batch is a third outcome
/// (produktregler.md:905-909, I-29; :588 "sju av nio" is never nine).
///
/// Pins, on the real view model with only the network leaf stubbed:
/// - a settled batch with successes and failures is partial, and neither a
///   loading batch nor an all-failed one is;
/// - each failed row keeps a Swedish reason from l10n, never the
///   exception's own (English, technical) text;
/// - rows have their own ids, and a retry by id reaches exactly that row
///   however the rows are ordered.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/viewmodels/url_import_viewmodel.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

/// Answers each URL from [answers]: a String is the fetched text, anything
/// else is thrown.
class _ScriptedUrlImportViewModel extends UrlImportViewModel {
  _ScriptedUrlImportViewModel({required super.importManager});

  final Map<String, Object> answers = {};

  @override
  Future<String> fetchContentFromUrl(String url) async {
    final answer = answers[url];
    if (answer is String) return answer;
    throw answer ?? Exception('no answer for $url');
  }
}

void main() {
  late _ScriptedUrlImportViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    prod_locator.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    vm = _ScriptedUrlImportViewModel(importManager: MockImportManager());
  });

  tearDown(() {
    if (!vm.isDisposed) vm.dispose();
  });

  const a = 'https://ica.se/recept/ett';
  const b = 'https://example.com/trasig';
  const c = 'https://arla.se/recept/tre';

  test(
    'a settled mix of fetched and failed links is a partial outcome',
    () async {
      vm.answers
        ..[a] = 'Recept ett'
        ..[b] = const UrlFetchFailure(
          UrlFetchFailureReason.unreachable,
          'Timeout: Could not load page within 15 seconds',
        )
        ..[c] = 'Recept tre';
      vm.updateUrl('$a\n$b\n$c');

      await vm.fetchMultipleUrls();

      expect(vm.isPartialBatch, isTrue);
      expect(vm.successfulUrlCount, 2);
      expect(vm.urlResults, hasLength(3));
      expect(vm.failedUrlResults.map((r) => r.url), [b]);
      // I-29 names why, in Swedish; the scraper's English text stays out.
      expect(vm.failedUrlResults.single.error, 'Sidan gick inte att nå');
      // Partial is not an error.
      expect(vm.hasError, isFalse);
    },
  );

  test('an all-failed batch is an error, never partial', () async {
    vm.answers
      ..[a] = Exception('nej')
      ..[b] = Exception('nej');
    vm.updateUrl('$a\n$b');

    await vm.fetchMultipleUrls();

    expect(vm.isPartialBatch, isFalse);
    expect(vm.allUrlsFailed, isTrue);
    expect(vm.hasError, isTrue);
  });

  test('an all-fetched batch is not partial', () async {
    vm.answers
      ..[a] = 'ett'
      ..[b] = 'två';
    vm.updateUrl('$a\n$b');

    await vm.fetchMultipleUrls();

    expect(vm.isPartialBatch, isFalse);
  });

  test(
    'every row has its own id, and a retry by id reaches that row',
    () async {
      vm.answers
        ..[a] = Exception('nere')
        ..[b] = 'ok'
        ..[c] = Exception('nere');
      vm.updateUrl('$a\n$b\n$c');
      await vm.fetchMultipleUrls();

      final ids = vm.urlResults.map((r) => r.id).toList();
      expect(ids.toSet(), hasLength(3));
      expect(ids.every((id) => id.isNotEmpty), isTrue);

      // Only c comes back. Retrying c by its id leaves a failed and untouched.
      vm.answers[c] = 'nu gick det';
      final cId = vm.urlResults.firstWhere((r) => r.url == c).id;
      await vm.retryUrlById(cId);

      expect(vm.urlResults.firstWhere((r) => r.url == c).isSuccess, isTrue);
      expect(vm.urlResults.firstWhere((r) => r.url == c).id, cId);
      expect(vm.urlResults.firstWhere((r) => r.url == a).isFailure, isTrue);
      expect(vm.isPartialBatch, isTrue);
    },
  );

  test('an unknown id is ignored', () async {
    vm.answers[a] = 'ett';
    vm.updateUrl('$a\n$b');
    await vm.fetchMultipleUrls();
    final before = vm.urlResults;

    await vm.retryUrlById('does-not-exist');

    expect(vm.urlResults, before);
  });

  test('a later batch never reuses an earlier row id', () async {
    vm.answers
      ..[a] = 'ett'
      ..[b] = 'två';
    vm.updateUrl('$a\n$b');
    await vm.fetchMultipleUrls();
    final first = vm.urlResults.map((r) => r.id).toSet();

    await vm.fetchMultipleUrls();
    final second = vm.urlResults.map((r) => r.id).toSet();

    expect(first.intersection(second), isEmpty);
  });

  test('failureReason is always one of three Swedish reasons', () {
    String r(Object e) => UrlImportViewModel.failureReason(e);
    expect(
      r(const UrlFetchFailure(UrlFetchFailureReason.unreachable, 'x')),
      'Sidan gick inte att nå',
    );
    expect(
      r(
        const UrlFetchFailure(
          UrlFetchFailureReason.noContent,
          'No text could be extracted from the page',
        ),
      ),
      'Sidan hade ingen recepttext',
    );
    expect(
      r(const UrlFetchFailure(UrlFetchFailureReason.unreadable, 'boom')),
      'Sidan gick inte att läsa',
    );
    expect(r(TimeoutException('slow')), 'Sidan gick inte att nå');
    // Unknown errors never leak their text.
    expect(r(Exception('Technical error: boom')), 'Sidan gick inte att läsa');
    expect(r(StateError('x')), 'Sidan gick inte att läsa');
  });

  test('the scraper reason maps to the user reason', () {
    expect(
      UrlFetchFailure.reasonFromScraper('network'),
      UrlFetchFailureReason.unreachable,
    );
    expect(
      UrlFetchFailure.reasonFromScraper('no_content'),
      UrlFetchFailureReason.noContent,
    );
    expect(
      UrlFetchFailure.reasonFromScraper('parse_failed'),
      UrlFetchFailureReason.unreadable,
    );
    expect(
      UrlFetchFailure.reasonFromScraper(null),
      UrlFetchFailureReason.unreadable,
    );
  });
}
