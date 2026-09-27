// P7-B2: deleting a group that fails keeps the dialog open with the
// three-part inline error (BaseActionDialog), never the exception's text
// (content-style-guide.md:87-97, :95).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';
import 'package:butlery/widgets/social/groups/delete_group_dialog.dart';

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
            body: DeleteGroupDialog(
              group: SocialFactory.createFriendCategory(name: 'Middagsklubben'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(sv.groupDeleteGroup).last);
      await tester.pumpAndSettle();

      expect(find.byType(InlineError), findsOneWidget);
      expect(find.text(sv.dialogActionFailed), findsOneWidget);
      expect(find.text(sv.commonRetry), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('UnifiedFriendsService'), findsNothing);
      expect(find.byType(DeleteGroupDialog), findsOneWidget);
    });
  }
}
