// The sketch (v16) draws no GDPR notice banner on the privacy policy. Runs in
// both modes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/widgets/legal/legal_document.dart';

late AppLocalizations _sv;

class _FakeOfflineService extends ChangeNotifier implements OfflineService {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const PrivacyPolicyView(),
    ),
  );
  // The policy is a bundled asset decoded off the fake clock, so let real
  // time pass until the document is built.
  final document = find.byType(MarkdownBody);
  for (var i = 0; i < 100 && document.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  setUp(() async {
    rootBundle.clear();
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<OfflineService>(_FakeOfflineService());
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets(
      'the policy shows the document and not the GDPR notice banner, '
      '$mode',
      (tester) async {
        await _pump(tester, theme);

        expect(find.byType(LegalDocument), findsOneWidget);
        expect(find.text(_sv.privacyGdprCompliant), findsNothing);
      },
    );
  }
}
