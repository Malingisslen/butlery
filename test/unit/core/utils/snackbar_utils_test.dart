import 'package:flutter/material.dart';
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
