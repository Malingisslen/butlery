// The legal documents' states (P5-U08, P5-U19, P5-U30).
//
// Sources: content-style-guide.md:87-95 (what happened, what you can do),
// produktregler.md:162-163 (offline is a banner; loading is the plate line
// plus text), Grafisk manual v6:665 (actions that need the network become
// inactive with an explanatory text), Komponentark v1:753 (the banner).
//
// The documents ship with the app (assets/legal/), so offline they still
// open, under the offline banner.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/views/legal/community_guidelines_view.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/views/legal/terms_of_service_view.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/widgets/common/state_widget.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _FakeOfflineService extends ChangeNotifier implements OfflineService {
  bool _online = true;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const assetChannel = 'flutter/assets';
  final sv = AppLocalizationsSv();
  late TestDefaultBinaryMessenger messenger;
  late _FakeOfflineService offline;

  setUp(() async {
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    rootBundle.clear();
    await GetIt.instance.reset();
    offline = _FakeOfflineService();
    GetIt.instance.registerSingleton<OfflineService>(offline);
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    messenger.setMockMessageHandler(assetChannel, null);
    rootBundle.clear();
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  void failAllAssetLoads() {
    messenger.setMockMessageHandler(
      assetChannel,
      (ByteData? message) async => null,
    );
  }

  Future<void> pump(WidgetTester tester, Widget view) async {
    await tester.pumpWidget(
      createLocalizedTestApp(wrapInScaffold: false, child: view),
    );
  }

  /// Large assets are decoded off the fake clock, so the plate line would
  /// keep pumpAndSettle busy. Let real time pass until the loading state is
  /// gone.
  Future<void> settleLoad(WidgetTester tester) async {
    bool loading() => tester
        .widgetList<StateWidget>(find.byType(StateWidget))
        .any((w) => w.type == StateType.loading);
    for (var i = 0; i < 50 && loading(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  final docs = <(String, Widget Function(), String, String)>[
    (
      'community guidelines',
      () => const CommunityGuidelinesView(),
      sv.legalGuidelinesCouldNotLoad,
      sv.loadingCommunityGuidelines,
    ),
    (
      'terms of service',
      () => const TermsOfServiceView(),
      sv.legalTermsCouldNotLoad,
      sv.loadingTerms,
    ),
    (
      'privacy policy',
      () => const PrivacyPolicyView(),
      sv.privacyCouldNotLoad,
      sv.privacyLoading,
    ),
  ];

  for (final (name, build, errorText, loadingText) in docs) {
    group(name, () {
      testWidgets('loading says which document is fetched (P5-U19)', (
        tester,
      ) async {
        await pump(tester, build());
        // First frame, before the asset future completes.
        final loading = tester.widget<StateWidget>(find.byType(StateWidget));
        expect(loading.type, StateType.loading);
        expect(loading.message, loadingText);
        await settleLoad(tester);
      });

      testWidgets('a failed load names this document in the standard error '
          'state with Försök igen (P5-U08)', (tester) async {
        failAllAssetLoads();
        await pump(tester, build());
        await tester.pumpAndSettle();

        final error = tester.widget<StateWidget>(find.byType(StateWidget));
        expect(error.type, StateType.error);
        expect(error.message, errorText);
        expect(error.onAction, isNotNull);
        expect(find.text(errorText), findsOneWidget);
        expect(find.text(sv.commonRetry), findsOneWidget);
        // No document borrows another document's message.
        for (final (_, _, other, _) in docs) {
          if (other != errorText) expect(find.text(other), findsNothing);
        }
      });

      testWidgets('offline, the document still opens under the offline '
          'banner (P5-U30)', (tester) async {
        offline.setOnline(false);
        await pump(tester, build());
        await settleLoad(tester);

        expect(find.byType(OfflineIndicator), findsOneWidget);
        expect(find.text(sv.indicatorOfflineMode), findsOneWidget);
        expect(find.byType(StateWidget), findsNothing);
        final bannerTop = tester.getTopLeft(find.byType(OfflineIndicator)).dy;
        final bodyFinder = find.byType(SingleChildScrollView).first;
        expect(tester.getTopLeft(bodyFinder).dy, greaterThan(bannerTop));
      });
    });
  }

  group('privacy policy web links (P5-U30)', () {
    testWidgets('offline: web links are inactive and one line says why', (
      tester,
    ) async {
      offline.setOnline(false);
      await pump(tester, const PrivacyPolicyView());
      await settleLoad(tester);

      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.webLinksEnabled, isFalse);
      expect(find.text(sv.legalLinksNeedConnection), findsOneWidget);
    });

    testWidgets('the links come back when the connection returns', (
      tester,
    ) async {
      offline.setOnline(false);
      await pump(tester, const PrivacyPolicyView());
      await settleLoad(tester);
      expect(find.text(sv.legalLinksNeedConnection), findsOneWidget);

      offline.setOnline(true);
      await tester.pump(const Duration(seconds: 5));
      final body = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(body.webLinksEnabled, isTrue);
      expect(find.text(sv.legalLinksNeedConnection), findsNothing);
    });
  });
}
