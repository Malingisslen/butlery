// The createIngredientChangePr callable: result parsing and the error-code
// mapping the admin tab shows messages for.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/tagging/ingredient_change_pr_service.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

class _MockResult extends Mock
    implements HttpsCallableResult<Map<dynamic, dynamic>> {}

void main() {
  late _MockCallable callable;
  late IngredientChangePrService service;

  setUpAll(() => registerFallbackValue(HttpsCallableOptions()));

  setUp(() {
    final functions = _MockFunctions();
    callable = _MockCallable();
    when(
      () => functions.httpsCallable(
        'createIngredientChangePr',
        options: any(named: 'options'),
      ),
    ).thenReturn(callable);
    service = IngredientChangePrService(functions: functions);
  });

  test('parses the result counts and url', () async {
    final result = _MockResult();
    when(() => result.data).thenReturn({
      'prNumber': 12,
      'prUrl': 'https://github.com/Malingisslen/butlery/pull/12',
      'applied': 4,
      'conflicts': 2,
      'rejected': 1,
      'skipped': 3,
      'reopened': 5,
    });
    when(
      () => callable.call<Map<dynamic, dynamic>>(),
    ).thenAnswer((_) async => result);

    final r = await service.createPr();
    expect(r.prNumber, 12);
    expect(r.prUrl, endsWith('/pull/12'));
    expect(r.applied, 4);
    expect(r.conflicts, 2);
    expect(r.rejected, 1);
    expect(r.skipped, 3);
    expect(r.reopened, 5);
  });

  test('a function error becomes a typed failure', () async {
    when(() => callable.call<Map<dynamic, dynamic>>()).thenThrow(
      FirebaseFunctionsException(
        message: 'locked',
        code: 'failed-precondition',
      ),
    );
    await expectLater(
      service.createPr(),
      throwsA(
        isA<IngredientChangePrException>().having(
          (e) => e.failure,
          'failure',
          IngredientChangePrFailure.locked,
        ),
      ),
    );
  });

  test('failureFor maps every documented code', () {
    IngredientChangePrFailure f(String code, [String message = '']) =>
        IngredientChangePrService.failureFor(
          FirebaseFunctionsException(message: message, code: code),
        );
    expect(f('permission-denied'), IngredientChangePrFailure.notAdmin);
    expect(
      f('failed-precondition', 'locked'),
      IngredientChangePrFailure.locked,
    );
    expect(
      f('failed-precondition', 'too-many-proposals'),
      IngredientChangePrFailure.tooManyProposals,
    );
    expect(
      f('failed-precondition', 'github-not-configured'),
      IngredientChangePrFailure.notConfigured,
    );
    expect(
      f('failed-precondition', 'not-configured'),
      IngredientChangePrFailure.notConfigured,
    );
    expect(f('failed-precondition', 'x'), IngredientChangePrFailure.other);
    expect(f('unavailable'), IngredientChangePrFailure.unavailable);
    for (final m in [
      'main-moved',
      'branch-moved',
      'pr-merged',
      'pr-merged-during-rebuild',
    ]) {
      expect(f('aborted', m), IngredientChangePrFailure.mainMoved, reason: m);
    }
    expect(
      f('aborted', 'foreign-commits'),
      IngredientChangePrFailure.foreignCommits,
    );
    expect(f('resource-exhausted'), IngredientChangePrFailure.rateLimited);
    expect(f('internal'), IngredientChangePrFailure.other);
  });
}
