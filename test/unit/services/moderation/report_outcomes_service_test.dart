// BUT-2222: the callable's rows are parsed defensively and no uid is sent.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/services/moderation/report_outcomes_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockCallable callable;
  late ReportOutcomesService service;

  void stubData(Map<dynamic, dynamic> data) {
    final result = _MockResult();
    when(() => result.data).thenReturn(data);
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenAnswer((_) async => result);
  }

  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  setUp(() {
    final functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(
        'getMyReportOutcomes',
        options: any(named: 'options'),
      ),
    ).thenReturn(callable);
    service = ReportOutcomesService(functions: functions);
  });

  test('valid rows become a map and the call carries no arguments', () async {
    stubData({
      'outcomes': [
        {'reportId': 'a', 'decision': 'content_removed'},
        {'reportId': 'b', 'decision': 'no_action'},
        {'reportId': 'c', 'decision': 'profile_hidden'},
      ],
    });

    final out = await service.getMyReportOutcomes();

    expect(out, {
      'a': ModeratorDecision.contentRemoved,
      'b': ModeratorDecision.noAction,
      'c': ModeratorDecision.profileHidden,
    });
    verify(() => callable.call<Map<dynamic, dynamic>>()).called(1);
  });

  test('unknown decision and empty or missing id are skipped', () async {
    stubData({
      'outcomes': [
        {'reportId': 'a', 'decision': 'banished'},
        {'reportId': '', 'decision': 'no_action'},
        {'decision': 'no_action'},
        {'reportId': 'ok', 'decision': 'no_action'},
        'junk',
      ],
    });

    expect(await service.getMyReportOutcomes(), {
      'ok': ModeratorDecision.noAction,
    });
  });

  test('a non-list outcomes value gives an empty map', () async {
    stubData({'outcomes': 'nope'});
    expect(await service.getMyReportOutcomes(), isEmpty);
  });

  test('a failing call throws', () async {
    when(
      () => callable.call<Map<dynamic, dynamic>>(any()),
    ).thenThrow(Exception('boom'));
    expect(service.getMyReportOutcomes(), throwsException);
  });
}
