import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/models/social/moderation_outcome.dart';

/// Why an appeal was refused, mapped from the callable's error codes.
enum AppealFailure {
  windowClosed,
  alreadyAppealed,
  notAllowed,
  notFound,
  invalidText,
  other,
}

class AppealException implements Exception {
  const AppealException(this.failure);
  final AppealFailure failure;

  @override
  String toString() => 'AppealException($failure)';
}

/// Why `answerAppeal` was refused.
enum AnswerFailure { alreadyAnswered, gone, other }

class AnswerAppealException implements Exception {
  const AnswerAppealException(this.failure);
  final AnswerFailure failure;

  @override
  String toString() => 'AnswerAppealException($failure)';
}

/// The appeal callables: `submitAppeal` for the two parties, and the
/// admin-only `listOpenAppeals` / `answerAppeal`.
class ModerationAppealsService extends BaseService {
  ModerationAppealsService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  static const int minTextLength = 10;
  static const int maxTextLength = 1000;

  @override
  String get serviceName => 'ModerationAppealsService';

  HttpsCallable _callable(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
  );

  /// Throws [AppealException] on a refusal.
  Future<void> submitAppeal({
    required String reportId,
    required AppealRole role,
    required String text,
  }) async {
    try {
      await _callable('submitAppeal').call<Map<dynamic, dynamic>>({
        'reportId': reportId,
        'role': role.wireName,
        'text': text.trim(),
      });
    } on FirebaseFunctionsException catch (e) {
      throw AppealException(failureFor(e));
    }
  }

  static AppealFailure failureFor(FirebaseFunctionsException e) =>
      switch (e.code) {
        'permission-denied' => AppealFailure.notAllowed,
        'not-found' => AppealFailure.notFound,
        'already-exists' => AppealFailure.alreadyAppealed,
        'invalid-argument' => AppealFailure.invalidText,
        'failed-precondition' =>
          e.message == 'appeal_window_closed'
              ? AppealFailure.windowClosed
              : AppealFailure.other,
        _ => AppealFailure.other,
      };

  Future<List<OpenAppeal>> listOpenAppeals() async {
    final result = await _callable(
      'listOpenAppeals',
    ).call<Map<dynamic, dynamic>>();
    final rows = result.data['appeals'];
    if (rows is! List) return const [];
    return [
      for (final row in rows) ?OpenAppeal.fromMap(row),
    ];
  }

  /// Throws [AnswerAppealException] on a refusal.
  Future<void> answerAppeal({
    required String appealId,
    required AppealStatus outcome,
  }) async {
    assert(outcome != AppealStatus.open);
    try {
      await _callable('answerAppeal').call<Map<dynamic, dynamic>>({
        'appealId': appealId,
        'outcome': outcome.wireName,
      });
    } on FirebaseFunctionsException catch (e) {
      throw AnswerAppealException(answerFailureFor(e));
    }
  }

  static AnswerFailure answerFailureFor(FirebaseFunctionsException e) =>
      switch (e.code) {
        'not-found' => AnswerFailure.gone,
        'failed-precondition' =>
          e.message == 'appeal_not_open'
              ? AnswerFailure.alreadyAnswered
              : AnswerFailure.other,
        _ => AnswerFailure.other,
      };
}
