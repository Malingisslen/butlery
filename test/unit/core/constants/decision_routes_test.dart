// BUT-2353: the decision routes. A decision push deep-links to them, so each
// must be a valid route behind sign-in and each router case must build its own
// view. AppRouter.generateRoute needs Firebase for its auth check, so the
// cases are pinned by reading its source, as shell_routes_test.dart does.

import 'dart:io';

import 'package:butlery/core/constants/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final decisionRoutes = {
    'myReports': Routes.myReports,
    'myContentDecisions': Routes.myContentDecisions,
    'decisionDetail': Routes.decisionDetail,
    'appealForm': Routes.appealForm,
  };

  test('every decision route is valid and behind sign-in', () {
    for (final entry in decisionRoutes.entries) {
      expect(Routes.isValidRoute(entry.value), isTrue, reason: entry.key);
      expect(Routes.requiresAuth(entry.value), isTrue, reason: entry.key);
    }
  });

  group('router cases', () {
    final code = File('lib/core/router/app_router.dart').readAsStringSync();

    String caseBody(String name) {
      final start = code.indexOf('case Routes.$name:');
      expect(start, isNonNegative, reason: 'no case for Routes.$name');
      final end = code.indexOf('case Routes.', start + 1);
      return code.substring(start, end < 0 ? code.length : end);
    }

    test('each decision route builds its own view', () {
      expect(
        caseBody('myContentDecisions'),
        contains('MyContentDecisionsView('),
      );
      expect(caseBody('decisionDetail'), contains('DecisionDetailView('));
      expect(caseBody('appealForm'), contains('AppealFormView('));
    });
  });
}
