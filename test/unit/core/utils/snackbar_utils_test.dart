import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';

void main() {
  group('SnackBarUtils.userFriendlyMessage', () {
    late BuildContext testContext;

    Future<void> setupContext(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: _ContextCapture()),
        ),
      );
      testContext = _ContextCapture.capturedContext!;
    }

    testWidgets('returns network error for SocketException', (tester) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('SocketException: Connection refused'),
      );
      expect(message, contains('internet'));
    });

    testWidgets('returns network error for connection failures', (
      tester,
    ) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('Connection failed: no internet'),
      );
      expect(message, contains('internet'));
    });

    testWidgets('returns auth error for authentication failures', (
      tester,
    ) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('Unauthenticated: token expired'),
      );
      expect(message, contains('Logga in'));
    });

    testWidgets('returns permission error for unauthorized access', (
      tester,
    ) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('Permission denied for this resource'),
      );
      expect(message, contains('behörighet'));
    });

    testWidgets('returns not found error for missing resources', (
      tester,
    ) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('Document not found'),
      );
      expect(message, contains('hittas'));
    });

    testWidgets('returns server error for 500 responses', (tester) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('Internal server error'),
      );
      expect(message, contains('Server'));
    });

    testWidgets('returns generic error for unknown exceptions', (tester) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('Something unexpected happened'),
      );
      // Should be the generic Swedish error, not the raw exception
      expect(message, contains('Försök'));
      expect(message, isNot(contains('unexpected')));
    });

    testWidgets('does not expose raw exception details', (tester) async {
      await setupContext(tester);
      final message = SnackBarUtils.userFriendlyMessage(
        testContext,
        Exception('NullPointerException at com.firebase.internal.Storage'),
      );
      expect(message, isNot(contains('NullPointerException')));
      expect(message, isNot(contains('firebase.internal')));
    });
  });

  // P7-C1: showUserFriendlyError goes through showFailure: the alert role,
  // the sanitized cause (never the exception text) and "Stäng", or
  // "Försök igen" when a retry is given (content-style-guide.md:87-97).
  group('SnackBarUtils.showUserFriendlyError', () {
    Finder alertRole() => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.role == SemanticsRole.alert,
    );

    Future<BuildContext> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: _ContextCapture()),
        ),
      );
      return _ContextCapture.capturedContext!;
    }

    testWidgets('shows the alert, the sanitized cause and Stäng', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final context = await pump(tester);
      const raw = 'Permission denied at firestore.internal/RAW';

      SnackBarUtils.showUserFriendlyError(context, Exception(raw));
      await tester.pumpAndSettle();

      expect(alertRole(), findsOneWidget);
      expect(
        find.text(SnackBarUtils.userFriendlyMessage(context, Exception(raw))),
        findsOneWidget,
      );
      expect(find.text('Stäng'), findsOneWidget);
      expect(find.textContaining('firestore.internal'), findsNothing);
      handle.dispose();
    });

    testWidgets('with a retry, the action is Försök igen', (tester) async {
      final context = await pump(tester);
      var retried = 0;

      SnackBarUtils.showUserFriendlyError(
        context,
        Exception('timeout'),
        onRetry: () => retried++,
      );
      await tester.pumpAndSettle();

      expect(find.text('Stäng'), findsNothing);
      await tester.tap(find.text('Försök igen'));
      await tester.pumpAndSettle();
      expect(retried, 1);
    });
  });
}

/// Helper widget that captures its BuildContext for testing.
class _ContextCapture extends StatelessWidget {
  static BuildContext? capturedContext;

  const _ContextCapture();

  @override
  Widget build(BuildContext context) {
    capturedContext = context;
    return const SizedBox.shrink();
  }
}
