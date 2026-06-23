/// Unit tests for [ComplianceExportManager.exportAuditLogs] (BUT-770).
///
/// BUT-815 covers two paginated-iteration invariants:
///   1. Happy path: iterate until the CF returns `nextCursor: null`.
///   2. Overflow path: stop at [_maxAuditLogPages] (10) and emit the
///      "Capped at..." note in the result. Without this, a runaway power-user
///      history could stream tens of thousands of audit-log entries through
///      the export bundle.
///
/// Mocking strategy: fake `FirebaseFunctions` whose `httpsCallable(...)`
/// returns a counting fake whose `call(...)` consumes a queue of canned
/// responses. We Fake (not Mock) because the real `HttpsCallableResult`
/// constructor is private — a Mock can't construct one — but a Fake that
/// just returns a pre-built shape is fine.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/account/export/compliance_export_manager.dart';

class _FakeHttpsCallableResult<T> implements HttpsCallableResult<T> {
  _FakeHttpsCallableResult(this.data);
  @override
  final T data;
}

class _ScriptedHttpsCallable extends Fake implements HttpsCallable {
  _ScriptedHttpsCallable(this._responses, {this.throwOnCall});

  // Each entry is the full Map<String,dynamic> the CF would return. The
  // call iterator consumes them in order; if exhausted, the test fails fast
  // (we never want a silent "happens to return empty" case).
  final List<Map<String, dynamic>> _responses;

  // BUT-842: optional error to throw instead of returning a scripted page.
  // Lets us cover the "CF rejected the call" branches without scripting
  // success pages.
  final Object? throwOnCall;
  int callCount = 0;
  final List<Object?> receivedParameters = [];

  @override
  Future<HttpsCallableResult<T>> call<T extends Object?>([
    Object? parameters,
  ]) async {
    callCount++;
    receivedParameters.add(parameters);
    if (throwOnCall != null) {
      throw throwOnCall as Object;
    }
    if (callCount > _responses.length) {
      throw StateError(
        'ScriptedHttpsCallable exhausted: production code asked for page '
        '$callCount but only ${_responses.length} responses scripted',
      );
    }
    final response = _responses[callCount - 1];
    // ComplianceExportManager calls `callable.call<Map<dynamic, dynamic>>(...)`,
    // so the cast target is Map<dynamic, dynamic>; we widen to satisfy T.
    return _FakeHttpsCallableResult<T>(response as T);
  }
}

class _FakeFunctions extends Fake implements FirebaseFunctions {
  _FakeFunctions(this.callable);
  final _ScriptedHttpsCallable callable;

  @override
  HttpsCallable httpsCallable(
    String name, {
    HttpsCallableOptions? options,
  }) => callable;
}

Map<String, dynamic> _page({
  required int rowCount,
  String? nextCursor,
  int idOffset = 0,
}) {
  return {
    'rows': List.generate(
      rowCount,
      (i) => {
        'id': 'log-${idOffset + i}',
        'timestamp': '2026-05-08T10:00:00Z',
        'operation': 'read',
        'resourceType': 'recipe',
        'resourceId': 'recipe-${idOffset + i}',
        'granted': i.isEven,
      },
    ),
    'nextCursor': nextCursor,
  };
}

void main() {
  group('ComplianceExportManager.exportAuditLogs (BUT-815)', () {
    test('iterates until nextCursor is null and aggregates rows', () async {
      // 3 pages, then null cursor on page 3 ends iteration.
      final callable = _ScriptedHttpsCallable([
        _page(rowCount: 5, nextCursor: 'c1', idOffset: 0),
        _page(rowCount: 5, nextCursor: 'c2', idOffset: 5),
        _page(rowCount: 3, nextCursor: null, idOffset: 10),
      ]);
      final manager = ComplianceExportManager(
        functions: _FakeFunctions(callable),
      );

      final result = await manager.exportAuditLogs('user-uid');

      expect(
        callable.callCount,
        equals(3),
        reason: 'should stop calling once nextCursor is null',
      );
      expect(result['total_count'], equals(13));
      final logs = result['audit_logs'] as List;
      expect(logs, hasLength(13));
      expect(logs.first['audit_log_id'], equals('log-0'));
      expect(logs.last['audit_log_id'], equals('log-12'));
      expect(
        result['note'],
        contains('Full actor history'),
        reason: 'happy path note must NOT include the "Capped at" warning',
      );

      // Page 1 is unscoped, pages 2+ pass `before: <cursor>`.
      expect(callable.receivedParameters[0], isNull);
      expect(callable.receivedParameters[1], equals({'before': 'c1'}));
      expect(callable.receivedParameters[2], equals({'before': 'c2'}));
    });

    test('caps at 10 pages even when nextCursor never goes null, and emits the '
        'Capped note', () async {
      // 11 pages, EVERY one with a non-null cursor → simulates a runaway
      // history. The manager must stop at the 10-page safety cap.
      final callable = _ScriptedHttpsCallable([
        for (var p = 0; p < 11; p++)
          _page(
            rowCount: 100,
            nextCursor: 'cursor-$p',
            idOffset: p * 100,
          ),
      ]);
      final manager = ComplianceExportManager(
        functions: _FakeFunctions(callable),
      );

      final result = await manager.exportAuditLogs('user-uid');

      // Cap is 10 pages; production breaks BEFORE the 11th call.
      expect(
        callable.callCount,
        equals(10),
        reason: 'safety cap must prevent the 11th page request',
      );
      expect(
        result['total_count'],
        equals(1000),
        reason: '10 pages * 100 rows',
      );
      expect(
        result['note'],
        contains('Capped at 10 pages'),
        reason:
            'cap path must surface the "Capped at" warning so downstream '
            'GDPR bundle consumers know the export is partial',
      );
      expect(result['note'], contains('contact support'));
    });
  });

  group('ComplianceExportManager.exportAuditLogs error handling (BUT-842)', () {
    test(
      'transient FirebaseFunctionsException returns recoverable error map',
      () async {
        // 'unavailable' / 'deadline-exceeded' / etc. are network/backend hiccups
        // — the user can retry, so the rest of the bundle should still ship.
        final callable = _ScriptedHttpsCallable(
          const [],
          throwOnCall: FirebaseFunctionsException(
            code: 'unavailable',
            message: 'Backend temporarily unavailable',
          ),
        );
        final manager = ComplianceExportManager(
          functions: _FakeFunctions(callable),
        );

        final result = await manager.exportAuditLogs('user-uid');

        expect(result['error'], equals('Backend temporarily unavailable'));
        expect(result['error_code'], equals('unavailable'));
        expect(result['note'], contains('Transient backend error'));
      },
    );

    test('resource-exhausted (rate limit) is transient, not fatal', () async {
      // BUT-842 code-review follow-up: rate-limit/quota responses are
      // canonically "retry later" — fatal-handling would scatter half-
      // bundles every time a daily cap was hit.
      final callable = _ScriptedHttpsCallable(
        const [],
        throwOnCall: FirebaseFunctionsException(
          code: 'resource-exhausted',
          message: 'Daily quota exceeded',
        ),
      );
      final manager = ComplianceExportManager(
        functions: _FakeFunctions(callable),
      );

      final result = await manager.exportAuditLogs('user-uid');

      expect(result['error_code'], equals('resource-exhausted'));
      expect(result['note'], contains('Transient backend error'));
    });

    test('fatal FirebaseFunctionsException (permission-denied) throws '
        'ComplianceExportException', () async {
      // permission-denied means the CF rejected the caller (e.g. App Check
      // blocked) — partial GDPR bundle would mask an Article 15 failure.
      final callable = _ScriptedHttpsCallable(
        const [],
        throwOnCall: FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'App Check token missing',
        ),
      );
      final manager = ComplianceExportManager(
        functions: _FakeFunctions(callable),
      );

      expect(
        () => manager.exportAuditLogs('user-uid'),
        throwsA(
          isA<ComplianceExportException>()
              .having((e) => e.code, 'code', 'permission-denied')
              .having(
                (e) => e.message,
                'message',
                contains('Audit-log export failed'),
              ),
        ),
      );
    });

    test(
      'fatal FirebaseFunctionsException (failed-precondition) re-throws',
      () async {
        final callable = _ScriptedHttpsCallable(
          const [],
          throwOnCall: FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'User not authenticated',
          ),
        );
        final manager = ComplianceExportManager(
          functions: _FakeFunctions(callable),
        );

        await expectLater(
          manager.exportAuditLogs('user-uid'),
          throwsA(isA<ComplianceExportException>()),
        );
      },
    );

    test(
      'unexpected non-FirebaseFunctions error wraps as ComplianceExportException',
      () async {
        final callable = _ScriptedHttpsCallable(
          const [],
          throwOnCall: StateError('something else broke'),
        );
        final manager = ComplianceExportManager(
          functions: _FakeFunctions(callable),
        );

        await expectLater(
          manager.exportAuditLogs('user-uid'),
          throwsA(
            isA<ComplianceExportException>().having(
              (e) => e.cause,
              'cause underlying error',
              isA<StateError>(),
            ),
          ),
        );
      },
    );
  });
}
