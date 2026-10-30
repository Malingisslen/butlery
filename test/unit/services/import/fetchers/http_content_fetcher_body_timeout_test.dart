/// A page that answers its headers and then never finishes its body must
/// not hold the import open: the fetch gives up as unreached.
library;

import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';

void main() {
  test('a body that never ends is given up on', () {
    fakeAsync((async) {
      final body = StreamController<List<int>>();
      final client = MockClient.streaming(
        (request, _) async => http.StreamedResponse(
          body.stream,
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      final fetcher = HttpContentFetcher(
        httpClient: client,
        dnsLookup: (_) async => [InternetAddress('93.184.216.34')],
      );

      HtmlFetch? result;
      unawaited(
        fetcher.fetchHtml('https://example.com/x').then((r) => result = r),
      );
      body.add('<html><body>'.codeUnits);
      async.elapse(const Duration(seconds: 30));

      expect(result, isNotNull, reason: 'the fetch must have finished');
      expect(result!.html, isNull);
      expect(result!.statusCode, isNull);
      unawaited(body.close());
    });
  });
}
