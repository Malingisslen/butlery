import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Runs a transaction handler. Production binds this to
/// `firestore.runTransaction`; tests inject a runner that fails the way a
/// platform does.
typedef TransactionRunnerFn<T> =
    Future<T> Function(Future<T> Function(Transaction transaction) handler);

TransactionRunnerFn<T> budgetedTransactionRunner<T>(
  FirebaseFirestore firestore,
  Duration budget,
) =>
    (handler) => firestore.runTransaction<T>(handler, timeout: budget);

/// Gives [run] the error contract native platforms already have: the error
/// the handler threw comes out as itself, and a spent budget comes out as
/// `deadline-exceeded`.
///
/// Why: on the web the Firestore plugin hands a handler's error to the
/// browser SDK inside a plain JS `Error` that nothing converts back, and lets
/// the Dart-side budget through as a `TimeoutException`. Callers that act on
/// a `FirebaseException` code (the offline fallbacks) then never match.
Future<T> runTransactionKeepingHandlerError<T>(
  TransactionRunnerFn<T> run,
  Future<T> Function(Transaction transaction) handler,
) async {
  Object? handlerError;
  StackTrace? handlerStack;
  try {
    return await run((transaction) async {
      // A retried attempt must not inherit the last attempt's failure.
      handlerError = null;
      handlerStack = null;
      try {
        return await handler(transaction);
      } catch (e, s) {
        handlerError = e;
        handlerStack = s;
        rethrow;
      }
    });
  } on FirebaseException {
    rethrow;
  } catch (e, s) {
    final recorded = handlerError;
    if (recorded != null) {
      Error.throwWithStackTrace(recorded, handlerStack ?? s);
    }
    if (e is TimeoutException) {
      Error.throwWithStackTrace(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'deadline-exceeded',
          message: 'The transaction budget ran out',
        ),
        s,
      );
    }
    rethrow;
  }
}

/// Runs [handler] in a transaction on [firestore] with the error contract
/// [runTransactionKeepingHandlerError] gives: for callers that act on an
/// error their handler throws and use the platform's own budget.
Future<T> runTransactionWithNativeErrors<T>(
  FirebaseFirestore firestore,
  Future<T> Function(Transaction transaction) handler,
) => runTransactionKeepingHandlerError<T>(
  (inner) => firestore.runTransaction<T>(inner),
  handler,
);
