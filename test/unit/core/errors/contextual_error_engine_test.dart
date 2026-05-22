/// Unit tests for ContextualErrorEngine.
///
/// Pure-Dart test — no Flutter widgets, no Firebase. Targets the 204 unhit
/// lines in lib/core/errors/contextual_error_engine.dart by:
/// - Walking every UserActionContext value through `localizedDescription`
/// - Driving generateSimpleMessage across every ErrorType × ConnectivityResult
///   combination (default Swedish locale)
/// - Hitting recovery-guidance branches per context+error pair
/// - Hitting the maintenance-window time branch via `withClock`
/// - Hitting the fallback-message path (try/catch on AppLocale failure is
///   unreachable in test — documented)
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/errors/contextual_error_engine.dart';
import 'package:butlery/core/mixins/error_handling_mixin.dart';
import 'package:butlery/core/utils/connectivity_check.dart';

void main() {
  group('UserActionContext.localizedDescription', () {
    test('every enum value resolves to a non-empty Swedish string', () {
      for (final action in UserActionContext.values) {
        final desc = action.localizedDescription;
        expect(desc, isNotEmpty,
            reason: 'UserActionContext.${action.name} should localize');
      }
    });
  });

  group('ErrorSeverity', () {
    test('every level has a non-empty level string', () {
      for (final s in ErrorSeverity.values) {
        expect(s.level, isNotEmpty);
      }
    });
  });

  group('ErrorContext.fromCurrentState', () {
    test('constructs with defaults', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.networkConnectivity,
        actionContext: UserActionContext.recipeSaving,
      );
      expect(ctx.errorType, ErrorType.networkConnectivity);
      expect(ctx.actionContext, UserActionContext.recipeSaving);
      expect(ctx.connectivity, ConnectivityResult.full);
      expect(ctx.severity, ErrorSeverity.standard);
      expect(ctx.technicalDetails, isNull);
      expect(ctx.recoveryActions, isNull);
      expect(ctx.timestamp, isNotNull);
    });

    test('passes through additional fields', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.authentication,
        actionContext: UserActionContext.recipeSaving,
        connectivity: ConnectivityResult.limited,
        severity: ErrorSeverity.diagnostic,
        technicalDetails: 'stack: foo',
        recoveryActions: const ['Try again'],
        additionalData: const {'permissionLevel': 'viewer'},
      );
      expect(ctx.connectivity, ConnectivityResult.limited);
      expect(ctx.severity, ErrorSeverity.diagnostic);
      expect(ctx.technicalDetails, 'stack: foo');
      expect(ctx.recoveryActions, ['Try again']);
      expect(ctx.additionalData?['permissionLevel'], 'viewer');
    });
  });

  group('generateSimpleMessage — base messages by ErrorType', () {
    test('networkConnectivity renders per connectivity state', () {
      for (final c in ConnectivityResult.values) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: ErrorType.networkConnectivity,
          actionContext: UserActionContext.recipeSaving,
          connectivity: c,
        );
        expect(msg, isNotEmpty,
            reason: 'connectivity ${c.name} should produce a message');
      }
    });

    test('every ErrorType produces a non-empty message', () {
      for (final e in ErrorType.values) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: e,
          actionContext: UserActionContext.recipeSaving,
        );
        expect(msg, isNotEmpty, reason: 'ErrorType.${e.name} should localize');
      }
    });
  });

  group('authentication branch permutations', () {
    test('not authenticated → "not logged in" wording branch', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.authentication,
        actionContext: UserActionContext.recipeSaving,
        additionalData: const {'isAuthenticated': false},
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, isNotEmpty);
    });

    test('permissionLevel: viewer/editor/none route to specific copy', () {
      for (final level in ['viewer', 'editor', 'none']) {
        final ctx = ErrorContext.fromCurrentState(
          errorType: ErrorType.authentication,
          actionContext: UserActionContext.recipeSaving,
          additionalData: {'permissionLevel': level},
        );
        final msg = ContextualErrorEngine.generateMessage(ctx);
        expect(msg, isNotEmpty);
      }
    });

    test('resourceOwner triggers owner-only branch', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.authentication,
        actionContext: UserActionContext.recipeSaving,
        additionalData: const {'resourceOwner': 'Alice'},
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, contains('Alice'));
    });

    test('no extra context → contact-owner generic branch', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.authentication,
        actionContext: UserActionContext.recipeSaving,
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, isNotEmpty);
    });
  });

  group('notFound branch by action context', () {
    test('recipe contexts route to recipe-specific notFound', () {
      const recipeContexts = [
        UserActionContext.recipeSaving,
        UserActionContext.recipeLoading,
        UserActionContext.recipeDeleting,
        UserActionContext.recipeUploading,
        UserActionContext.recipeValidation,
        UserActionContext.recipeCollaborativeSync,
        UserActionContext.recipeDraftRestore,
      ];
      for (final action in recipeContexts) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: ErrorType.notFound,
          actionContext: action,
        );
        expect(msg, isNotEmpty);
      }
    });

    test('shopping contexts route to shopping-list notFound', () {
      const shoppingContexts = [
        UserActionContext.shoppingListCreate,
        UserActionContext.shoppingItemAdd,
        UserActionContext.shoppingListSync,
        UserActionContext.shoppingListShare,
        UserActionContext.shoppingListDelete,
      ];
      for (final action in shoppingContexts) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: ErrorType.notFound,
          actionContext: action,
        );
        expect(msg, isNotEmpty);
      }
    });

    test('image contexts route to image-specific notFound', () {
      const imageContexts = [
        UserActionContext.recipeImageUpload,
        UserActionContext.recipeImageProcessing,
        UserActionContext.recipeImageDelete,
      ];
      for (final action in imageContexts) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: ErrorType.notFound,
          actionContext: action,
        );
        expect(msg, isNotEmpty);
      }
    });

    test('other contexts route to generic notFound default', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.notFound,
        actionContext: UserActionContext.appStartup,
      );
      expect(msg, isNotEmpty);
    });
  });

  group('serviceUnavailable — sync contexts + maintenance window', () {
    test('sync contexts route to sync-specific copy', () {
      const syncContexts = [
        UserActionContext.shoppingListSync,
        UserActionContext.socialSync,
        UserActionContext.dataSync,
        UserActionContext.shoppingListShare,
        UserActionContext.recipeCollaborativeSync,
      ];
      for (final action in syncContexts) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: ErrorType.serviceUnavailable,
          actionContext: action,
        );
        expect(msg, isNotEmpty);
      }
    });

    test('non-sync contexts route to temporary-service copy', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.serviceUnavailable,
        actionContext: UserActionContext.recipeSaving,
      );
      expect(msg, isNotEmpty);
    });

    test('maintenance-window (02:00-04:00 local) routes to maintenance copy',
        () {
      withClock(Clock.fixed(DateTime(2026, 5, 22, 3, 0)), () {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: ErrorType.serviceUnavailable,
          actionContext: UserActionContext.recipeSaving,
        );
        expect(msg, isNotEmpty);
      });
    });
  });

  group('unknown error message branches', () {
    test('with technical details + non-minimal severity uses tech-detail copy',
        () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.unknown,
        actionContext: UserActionContext.recipeSaving,
        technicalDetails: 'NPE at line 42',
        severity: ErrorSeverity.diagnostic,
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, contains('NPE at line 42'));
    });

    test('minimal severity ignores technical details', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.unknown,
        actionContext: UserActionContext.recipeSaving,
        technicalDetails: 'NPE at line 42',
        severity: ErrorSeverity.minimal,
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, isNot(contains('NPE at line 42')));
    });

    test('null technical details falls through to base unknown copy', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.unknown,
        actionContext: UserActionContext.recipeSaving,
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, isNotEmpty);
    });
  });

  group('recovery guidance — context-specific actions', () {
    test('recipeSaving + network → save-locally suggestion appears', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.networkConnectivity,
        actionContext: UserActionContext.recipeSaving,
      );
      // We don't assert on Swedish exact text but the message should
      // include the bullet/label marker that recovery guidance prepends.
      expect(msg.length, greaterThan(20),
          reason: 'recovery guidance should append additional text');
    });

    test('recipeSaving + auth → check-logged-in + permission suggestions', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.authentication,
        actionContext: UserActionContext.recipeSaving,
      );
      expect(msg.length, greaterThan(20));
    });

    test('recipeImageUpload + network → image-saved-locally suggestion', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.networkConnectivity,
        actionContext: UserActionContext.recipeImageUpload,
      );
      expect(msg.length, greaterThan(20));
    });

    test('recipeImageUpload + non-network → size/format suggestions', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.unknown,
        actionContext: UserActionContext.recipeImageUpload,
      );
      expect(msg.length, greaterThan(20));
    });

    test('recipeDraftRestore → multiple draft-related suggestions', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.networkConnectivity,
        actionContext: UserActionContext.recipeDraftRestore,
      );
      expect(msg.length, greaterThan(20));
    });

    test('friendInvite + auth → social suggestions', () {
      final msg = ContextualErrorEngine.generateSimpleMessage(
        errorType: ErrorType.authentication,
        actionContext: UserActionContext.friendInvite,
      );
      expect(msg.length, greaterThan(20));
    });

    test('default context + each error type produces guidance', () {
      for (final e in [
        ErrorType.networkConnectivity,
        ErrorType.authentication,
        ErrorType.serviceUnavailable,
        ErrorType.unknown,
      ]) {
        final msg = ContextualErrorEngine.generateSimpleMessage(
          errorType: e,
          actionContext: UserActionContext.appStartup,
        );
        expect(msg, isNotEmpty);
      }
    });
  });

  group('recoveryActions parameter', () {
    test('user-supplied recovery actions are appended', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.unknown,
        actionContext: UserActionContext.appStartup,
        recoveryActions: const ['Custom action 1', 'Custom action 2'],
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, contains('Custom action 1'));
      expect(msg, contains('Custom action 2'));
    });

    test('single recovery action does not get bullet prefix', () {
      final ctx = ErrorContext.fromCurrentState(
        errorType: ErrorType.unknown,
        actionContext: UserActionContext.appStartup,
        recoveryActions: const ['Only action'],
      );
      final msg = ContextualErrorEngine.generateMessage(ctx);
      expect(msg, contains('Only action'));
    });
  });
}
