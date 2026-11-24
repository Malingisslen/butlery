/// BUT-2490: `FirebaseChatGroupRepository.setRecurringDayRules` sends the
/// group's fixed days to the `setGroupRecurringDayRules` callable, as the
/// canonical rows `RecurringDayRules.toFirestoreList` builds, and lets a
/// callable failure reach the caller.
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/menu/recurring_day_rule.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/firebase/firebase_chat_group_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

class _MockFunctions extends Mock implements FirebaseFunctions {}

class _MockCallable extends Mock implements HttpsCallable {}

/// Fake instead of Mock: `HttpsCallableResult.data` reads a private field.
class _FakeCallableResult extends Fake
    implements HttpsCallableResult<Map<String, dynamic>> {
  @override
  Map<String, dynamic> get data => <String, dynamic>{};
}

void main() {
  setUpAll(() {
    registerFallbackValue(HttpsCallableOptions());
  });

  late _MockFunctions functions;
  late _MockCallable callable;
  late FakeAuthRepository auth;
  late FirebaseChatGroupRepository repository;

  final tacoFriday = RecurringDayRule.create(
    day: DayOfWeek.fri,
    meal: MealSlot.middag,
    food: RecurringFood.tacos,
  );
  final pausedQuickMonday = RecurringDayRule.create(
    day: DayOfWeek.mon,
    meal: MealSlot.lunch,
    quick: true,
  ).copyWith(paused: true);

  setUp(() {
    functions = _MockFunctions();
    callable = _MockCallable();
    auth = FakeAuthRepository()..setAuthState(userId: 'admin-uid');
    repository = FirebaseChatGroupRepository(
      firestore: FakeFirebaseFirestore(),
      authRepository: auth,
      functions: functions,
    );
    when(
      () => functions.httpsCallable(any(), options: any(named: 'options')),
    ).thenReturn(callable);
  });

  test('calls setGroupRecurringDayRules with the canonical rows', () async {
    when(
      () => callable.call<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => _FakeCallableResult());

    await repository.setRecurringDayRules('g1', [
      tacoFriday,
      pausedQuickMonday,
    ]);

    verify(
      () => functions.httpsCallable('setGroupRecurringDayRules'),
    ).called(1);
    final payload =
        verify(
              () => callable.call<Map<String, dynamic>>(captureAny()),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload, {
      'groupId': 'g1',
      'rules': [
        {
          'id': '5-middag',
          'weekday': 5,
          'meal': 'middag',
          'kind': 'tag',
          'value': 'taco',
          'quick': false,
          'paused': false,
        },
        {
          'id': '1-lunch',
          'weekday': 1,
          'meal': 'lunch',
          'kind': 'quick',
          'value': '',
          'quick': true,
          'paused': true,
        },
      ],
    });
  });

  test('an empty list is sent as an empty list', () async {
    when(
      () => callable.call<Map<String, dynamic>>(any()),
    ).thenAnswer((_) async => _FakeCallableResult());

    await repository.setRecurringDayRules('g1', const []);

    final payload =
        verify(
              () => callable.call<Map<String, dynamic>>(captureAny()),
            ).captured.single
            as Map<String, dynamic>;
    expect(payload['rules'], isEmpty);
  });

  test('a callable refusal reaches the caller', () async {
    when(() => callable.call<Map<String, dynamic>>(any())).thenThrow(
      FirebaseFunctionsException(
        code: 'permission-denied',
        message: 'Not allowed.',
      ),
    );

    await expectLater(
      repository.setRecurringDayRules('g1', [tacoFriday]),
      throwsA(
        isA<FirebaseFunctionsException>().having(
          (e) => e.code,
          'code',
          'permission-denied',
        ),
      ),
    );
  });

  test('signed out, nothing is called', () async {
    auth.setAuthState(userId: null);

    await expectLater(
      repository.setRecurringDayRules('g1', [tacoFriday]),
      throwsA(isA<PermissionDeniedException>()),
    );
    verifyNever(() => functions.httpsCallable(any()));
  });
}
