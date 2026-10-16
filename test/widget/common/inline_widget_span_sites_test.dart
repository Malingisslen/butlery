/// A link or chip inside running text is scaled once, by the paragraph. Scaled
/// twice, its text at 200 % would come out four times the size of the setting
/// at 1.0 and break in half the width.
library;

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
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/linkified_text.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

class _MockReportService extends Mock implements ReportService {}

Future<void> _pump(WidgetTester tester, double scale, Widget child) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// How much taller the text of [finder] is at 200 % than at 1.0: 2 when it is
/// scaled once, 4 when it is scaled twice.
Future<double> _growth(
  WidgetTester tester,
  Widget child,
  Finder finder,
) async {
  await _pump(tester, 1, child);
  final normal = tester.getSize(finder).height;
  await _pump(tester, 2, child);
  return tester.getSize(finder).height / normal;
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<ReportService>(_MockReportService());
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets('a link in a comment is scaled once at 200 % text', (
    tester,
  ) async {
    const url = 'https://butlery.se';
    final growth = await _growth(
      tester,
      LinkifiedText.from('Se $url nu', style: const TextStyle(fontSize: 14)),
      find.text(url),
    );
    expect(growth, lessThan(2.5));
  });

  testWidgets('the timer chip in a step is scaled once at 200 % text', (
    tester,
  ) async {
    final growth = await _growth(
      tester,
      InlineTimerText(text: 'Grädda i 25 min mitt i ugnen', onTimerTap: (_) {}),
      find.text('25 min'),
    );
    // The paragraph paints the chip at 200 % itself, so its laid-out text
    // keeps its 1.0 size; scaled twice it would be laid out at 200 %.
    expect(growth, lessThan(1.5));
  });

  testWidgets('the guidelines link in the report dialog is scaled once', (
    tester,
  ) async {
    final link = AppLocalizationsSv().reportDialogGuidelinesLink;
    Future<double> height(double scale) async {
      await _pump(
        tester,
        scale,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => ReportContentDialog.show(
              context: context,
              contentType: ContentType.recipe,
              contentId: 'c-1',
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final h = tester.getSize(find.text(link)).height;
      Navigator.of(tester.element(find.text(link))).pop();
      await tester.pumpAndSettle();
      return h;
    }

    final normal = await height(1);
    final large = await height(2);
    expect(large / normal, lessThan(2.5));
  });
}
