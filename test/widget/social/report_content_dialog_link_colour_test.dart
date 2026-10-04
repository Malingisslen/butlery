// The community-guidelines link in the report dialog is link text, so it takes
// text.link of the current mode (ModeColors.textLink) while the sentence around
// it keeps the secondary text colour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/services/moderation/report_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

class _MockReportService extends Mock implements ReportService {}

void main() {
  final guidelinesLink = AppLocalizationsSv().reportDialogGuidelinesLink;

  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<ReportService>(_MockReportService());
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  for (final (mode, theme, expected) in [
    ('light', AppTheme.lightTheme, AppColors.textLink),
    ('dark', AppTheme.darkTheme, AppColorsDark.textLink),
  ]) {
    testWidgets('the guidelines link is text.link in $mode mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('sv'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => ReportContentDialog.show(
                  context: context,
                  contentType: ContentType.recipe,
                  contentId: 'c-1',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final link = tester.widget<Text>(find.text(guidelinesLink));
      expect(link.style?.color, expected);
    });
  }
}
