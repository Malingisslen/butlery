// P7-B2: deleting a group that fails keeps the dialog open with the
// three-part inline error, never the exception's text
// (content-style-guide.md). Since BUT-2366 the delete runs inside
// the shared DestructiveConfirmationDialog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/social/groups/group_dialogs.dart';

import '../../../infrastructure/factories/social_factory.dart';

void main() {
  setUp(() async {
    // No friends service is registered, so the delete throws.
    final container = DIContainer();
    await container.reset();
    ServiceLocator.initialize(container);
  });

  tearDown(() => DIContainer().reset());

  for (final dark in [false, true]) {
    testWidgets('a failed delete: inline error, Försök igen, no exception '
        'text (${dark ? 'dark' : 'light'})', (tester) async {
      final sv = AppLocalizationsSv();
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          locale: const Locale('sv'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => GroupDialogs.showDeleteGroupDialog(
                  context,
                  group: SocialFactory.createFriendCategory(
                    name: 'Middagsklubben',
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(sv.groupDeleteConfirmTitle), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().contains('”Middagsklubben”'),
        ),
        findsOneWidget,
      );
      expect(find.text(sv.groupDeleteWarning), findsOneWidget);
      expect(find.text(sv.deleteActionIrreversible), findsOneWidget);

      await tester.tap(find.text(sv.groupDeleteTheGroup));
      await tester.pumpAndSettle();

      expect(find.byType(InlineError), findsOneWidget);
      expect(find.text(sv.dialogActionFailed), findsOneWidget);
      expect(find.text(sv.commonRetry), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('UnifiedFriendsService'), findsNothing);
      expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
    });
  }
}
