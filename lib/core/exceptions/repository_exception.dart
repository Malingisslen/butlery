/// Repository-specific exceptions for error handling.
library;

import 'package:butlery/models/menu/weekly_menu_plan.dart';

class RepositoryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const RepositoryException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'RepositoryException: $message';
}

/// BUT-2215: a week save was refused because the stored week moved on since
/// this copy was read — another save (in practice the owner's other device)
/// landed first. [remote] is the week as the server holds it now.
class WeekPlanConflictException extends RepositoryException {
  final WeeklyMenuPlan remote;

  const WeekPlanConflictException(this.remote, {super.originalError})
    : super('The week was saved elsewhere first', code: 'week-plan-conflict');

  @override
  String toString() => 'WeekPlanConflictException: stored rev ${remote.rev}';
}
