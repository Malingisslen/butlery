// A dialog taller than a small phone at large text must scroll rather than
// overflow, so these raw AlertDialogs are scrollable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/widgets/common/dialogs/confirmation_dialogs.dart';
import 'package:butlery/widgets/common/dialogs/draft_recovery_dialog.dart';
import 'package:butlery/widgets/common/dialogs/rate_limit_dialog.dart';
import 'package:butlery/widgets/common/dialogs/retag_progress_dialog.dart';
import 'package:butlery/widgets/common/dialogs/session_timeout_warning_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final cases = <String, Future<void> Function(BuildContext context)>{
    'loading confirmation': (c) =>
        ConfirmationDialogs.showLoadingConfirmationDialog(
          c,
          title: 'Titel',
          message: 'Ett långt meddelande ' * 40,
        ),
    'text input': (c) => ConfirmationDialogs.showTextInputDialog(
      c,
      title: 'Titel',
      message: 'Ett långt meddelande ' * 40,
      confirmText: 'Spara',
    ),
    'draft recovery': (c) => DraftRecoveryDialog.show(c, [
      for (var i = 0; i < 6; i++)
        DraftMetadata(
          draftId: 'd$i',
          createdAt: DateTime(2026, 1, 1),
          lastModifiedAt: DateTime(2026, 1, 1),
          title: 'Utkast $i',
          fieldCount: 3,
        ),
    ]),
    'rate limit': (c) => RateLimitDialog.show(
      c,
      rateLimitResult: const RateLimitDenied(
        message: 'limit',
        retryAfter: Duration(minutes: 1),
        limitType: LimitType.perMinute,
        suggestedAction: FallbackAction.retryLater,
      ),
    ),
    'session timeout': (c) => SessionTimeoutWarningDialog.show(
      context: c,
      remainingSeconds: 60,
      onExtendSession: () {},
      onLogoutNow: () {},
    ),
    'retag progress': (c) => showDialog<void>(
      context: c,
      builder: (_) => RetagProgressDialog(
        retagFunction: (_) => Completer<int>().future,
      ),
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} dialog scrolls', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => entry.value(context),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.scrollable, isTrue);
    });
  }
}
