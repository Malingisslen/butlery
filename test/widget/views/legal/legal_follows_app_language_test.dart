// Megagenomgång A10: the legal documents follow the app's language, not the
// phone's. A phone set to English with the app in Swedish used to read the
// English terms.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/views/legal/community_guidelines_view.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/views/legal/terms_of_service_view.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _OnlineService extends ChangeNotifier implements OfflineService {
  @override
  bool get isOnline => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<OfflineService>(_OnlineService());
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  final documents = <String, ({Widget view, String sv, String en})>{
    'terms': (
      view: const TermsOfServiceView(),
      sv: 'ANVÄNDARVILLKOR',
      en: 'TERMS OF SERVICE',
    ),
    'community guidelines': (
      view: const CommunityGuidelinesView(),
      sv: 'GEMENSKAPSRIKTLINJER',
      en: 'COMMUNITY GUIDELINES',
    ),
    'privacy policy': (
      view: const PrivacyPolicyView(),
      sv: 'Integritetspolicy',
      en: 'Privacy Policy',
    ),
  };

  for (final entry in documents.entries) {
    for (final appLocale in const ['sv', 'en']) {
      final phoneLocale = appLocale == 'sv' ? 'en' : 'sv';
      testWidgets(
        '${entry.key} is $appLocale when the app is $appLocale and the phone '
        'is $phoneLocale',
        (tester) async {
          tester.platformDispatcher.localeTestValue = Locale(phoneLocale);
          addTearDown(tester.platformDispatcher.clearLocaleTestValue);

          await tester.pumpWidget(
            createLocalizedTestApp(
              wrapInScaffold: false,
              locale: Locale(appLocale),
              child: entry.value.view,
            ),
          );
          await tester.pumpAndSettle();

          final expected = appLocale == 'sv' ? entry.value.sv : entry.value.en;
          final other = appLocale == 'sv' ? entry.value.en : entry.value.sv;
          final data = tester
              .widget<MarkdownBody>(find.byType(MarkdownBody))
              .data;
          expect(data, contains(expected));
          expect(data, isNot(contains(other)));
        },
      );
    }
  }
}
