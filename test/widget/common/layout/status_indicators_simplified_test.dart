// The offline banner as a pattern (P3-U05).
//
// Sources: Komponentark v1:752-754 (light) and :570-572 (dark) for the
// anatomy, produktregler.md:162 and :300, flows-roles-budget.md:111,
// tillganglighetshandoff:177 (role status, announced on transition, glyph
// decorative), Skarmar v12 del 4 #hemoffline (single line, comma in the
// screen-reader label).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/layout/status_indicators.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/di/di_container.dart';
import 'package:get_it/get_it.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/base_widget_test.dart';

/// Lightweight mock that extends ChangeNotifier so listeners work.
class _MockOfflineService extends ChangeNotifier implements OfflineService {
  bool _online = true;

  @override
  bool get isOnline => _online;

  void setOnline(bool value) {
    _online = value;
    notifyListeners();
  }

  /// A notification that is not a connectivity change (e.g. a user change).
  void notifyWithoutChange() => notifyListeners();

  // Stubs for remaining OfflineService API (unused in indicator widgets)
  @override
  bool get isInitialized => true;
  @override
  String? get currentUserId => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _offlineKey = ValueKey('offline');
const _onlineKey = ValueKey('online');

Widget _themedApp(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    locale: const Locale('sv'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(body: child),
  );
}

BoxDecoration _bannerDecoration(WidgetTester tester, Key key) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(of: find.byKey(key), matching: find.byType(DecoratedBox))
        .first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('StatusIndicators', () {
    late _MockOfflineService mockOffline;

    setUpAll(() async {
      await BaseWidgetTest.setupWidget();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // Bridge production ServiceLocator to the same GetIt instance
      production.ServiceLocator.initialize(DIContainer());
      mockOffline = _MockOfflineService();
      final getIt = GetIt.instance;
      if (getIt.isRegistered<OfflineService>()) {
        getIt.unregister<OfflineService>();
      }
      getIt.registerSingleton<OfflineService>(mockOffline);
    });

    tearDown(() async {
      await BaseWidgetTest.teardownWidget();
    });

    group('facade', () {
      testWidgets('passes pendingCount and onTap through', (tester) async {
        void tap() {}
        final w = StatusIndicators.offlineIndicator(
          pendingCount: 2,
          onTap: tap,
        );
        expect(w, isA<OfflineIndicator>());
        expect((w as OfflineIndicator).pendingCount, 2);
        expect(w.onTap, same(tap));
        expect(StatusIndicators.offlineStatusIcon(), isA<OfflineStatusIcon>());
      });
    });

    group('OfflineIndicator anatomy', () {
      for (final brightness in Brightness.values) {
        testWidgets('${brightness.name}: paper, text.warning outline and '
            'glyph, text.primary title', (tester) async {
          mockOffline.setOnline(false);
          await tester.pumpWidget(
            _themedApp(const OfflineIndicator(), brightness: brightness),
          );
          await tester.pump();

          final cs = Theme.of(
            tester.element(find.byKey(_offlineKey)),
          ).colorScheme;
          final warning = AppModeColors.textWarning(brightness);
          // text.warning (tokens.json:92-95); surface.base (:104-107);
          // text.primary (:54-57).
          expect(
            warning,
            brightness == Brightness.dark
                ? const Color(0xFFDCA968)
                : const Color(0xFF8A5212),
          );
          expect(
            cs.surface,
            brightness == Brightness.dark
                ? const Color(0xFF17251D)
                : const Color(0xFFF5F4ED),
          );
          expect(
            cs.onSurface,
            brightness == Brightness.dark
                ? const Color(0xFFF5F4ED)
                : const Color(0xFF24382C),
          );

          final deco = _bannerDecoration(tester, _offlineKey);
          expect(deco.color, cs.surface);
          final border = deco.border! as Border;
          expect(border.top.color, warning);
          expect(border.top.width, 1.0);

          final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
          expect(icon.color, warning);

          final title = tester.widget<Text>(find.text('Ingen anslutning'));
          expect(title.style!.color, cs.onSurface);
          expect(title.style!.fontSize, 12.5);
          expect(title.style!.fontWeight, FontWeight.w700);
        });
      }

      testWidgets('the warning member is not the non-text warning border', (
        tester,
      ) async {
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          _themedApp(const OfflineIndicator(), brightness: Brightness.light),
        );
        await tester.pump();
        final deco = _bannerDecoration(tester, _offlineKey);
        // border.statusWarning is #D8B784: surfaces and icons only.
        expect(deco.color, isNot(const Color(0xFFD8B784)));
        expect(
          (deco.border! as Border).top.color,
          isNot(const Color(0xFFD8B784)),
        );
      });
    });

    group('OfflineIndicator title and count', () {
      Future<void> pumpWithCount(WidgetTester tester, int? count) async {
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          createLocalizedTestApp(child: OfflineIndicator(pendingCount: count)),
        );
        await tester.pump();
      }

      testWidgets('null count shows the title only', (tester) async {
        await pumpWithCount(tester, null);
        expect(find.text('Ingen anslutning'), findsOneWidget);
      });

      testWidgets('zero count shows the title only', (tester) async {
        await pumpWithCount(tester, 0);
        expect(find.text('Ingen anslutning'), findsOneWidget);
        expect(find.textContaining('väntar'), findsNothing);
      });

      testWidgets('one change uses the singular', (tester) async {
        await pumpWithCount(tester, 1);
        expect(
          find.text('Ingen anslutning · 1 ändring väntar'),
          findsOneWidget,
        );
      });

      testWidgets('three changes use the plural and the dot', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpWithCount(tester, 3);
        expect(
          find.text('Ingen anslutning · 3 ändringar väntar'),
          findsOneWidget,
        );
        // The screen-reader label uses a comma instead of the dot.
        expect(
          find.bySemanticsLabel('Ingen anslutning, 3 ändringar väntar'),
          findsOneWidget,
        );
        handle.dispose();
      });
    });

    group('OfflineIndicator as a control', () {
      testWidgets('without onTap: a status, no button, no chevron', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();

        expect(find.byIcon(Icons.chevron_right), findsNothing);
        final node = tester.getSemantics(
          find.bySemanticsLabel('Ingen anslutning'),
        );
        final data = node.getSemanticsData();
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.role, SemanticsRole.status);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
        handle.dispose();
      });

      testWidgets('with onTap: a button with a chevron, 48 dp, tap calls it', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var taps = 0;
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          createLocalizedTestApp(child: OfflineIndicator(onTap: () => taps++)),
        );
        await tester.pump();

        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.chevron_right)).color,
          AppModeColors.textWarning(Brightness.light),
        );
        final node = tester.getSemantics(
          find.bySemanticsLabel('Ingen anslutning'),
        );
        final data = node.getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);

        final inkSize = tester.getSize(find.byType(InkWell));
        expect(
          inkSize.height,
          greaterThanOrEqualTo(AppDimensions.minTouchTarget),
        );

        await tester.tap(find.byType(InkWell));
        expect(taps, 1);
        handle.dispose();
      });

      testWidgets('the glyph is decorative', (tester) async {
        final handle = tester.ensureSemantics();
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();
        // One node carries the whole banner; nothing else is exposed.
        expect(find.bySemanticsLabel('Ingen anslutning'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('wifi')), findsNothing);
        handle.dispose();
      });
    });

    group('OfflineIndicator transitions', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOffline.setOnline(true);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(_offlineKey), findsNothing);
        expect(find.byKey(_onlineKey), findsNothing);
      });

      testWidgets('back online: circle-check in text.success, then gone', (
        tester,
      ) async {
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();
        expect(find.byKey(_offlineKey), findsOneWidget);

        mockOffline.setOnline(true);
        await tester.pump();
        expect(find.byKey(_onlineKey), findsOneWidget);
        final cs = Theme.of(tester.element(find.byKey(_onlineKey))).colorScheme;
        final deco = _bannerDecoration(tester, _onlineKey);
        expect(deco.color, cs.surface);
        expect((deco.border! as Border).top.color, cs.tertiary);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.check_circle_outline)).color,
          cs.tertiary,
        );
        expect(find.text('Ansluten igen'), findsOneWidget);

        await tester.pump(AppDimensions.snackbarDuration);
        await tester.pumpAndSettle();
        expect(find.byKey(_onlineKey), findsNothing);
        expect(find.byKey(_offlineKey), findsNothing);
      });

      testWidgets('announces once per transition, never on rebuild', (
        tester,
      ) async {
        mockOffline.setOnline(true);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pumpAndSettle();
        expect(tester.takeAnnouncements(), isEmpty);

        mockOffline.setOnline(false);
        await tester.pump();
        var said = tester.takeAnnouncements();
        expect(said, hasLength(1));
        expect(said.single.message, 'Ingen anslutning');

        // A notification that is not a connectivity change, and rebuilds.
        mockOffline.notifyWithoutChange();
        await tester.pump();
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineIndicator()),
        );
        await tester.pump();
        expect(tester.takeAnnouncements(), isEmpty);

        mockOffline.setOnline(true);
        await tester.pump();
        said = tester.takeAnnouncements();
        expect(said, hasLength(1));
        expect(said.single.message, 'Ansluten igen');
        await tester.pump(AppDimensions.snackbarDuration);
        await tester.pumpAndSettle();
      });

      testWidgets('two stacked routes: one announcement app-wide', (
        tester,
      ) async {
        mockOffline.setOnline(true);
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: OfflineIndicator(key: Key('below'))),
          ),
        );
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                const Scaffold(body: OfflineIndicator(key: Key('top'))),
          ),
        );
        await tester.pumpAndSettle();
        // Both banners are mounted and listening.
        expect(
          find.byKey(const Key('below'), skipOffstage: false),
          findsOneWidget,
        );
        expect(find.byKey(const Key('top')), findsOneWidget);
        expect(tester.takeAnnouncements(), isEmpty);

        mockOffline.setOnline(false);
        await tester.pump();
        final said = tester.takeAnnouncements();
        expect(said, hasLength(1));
        expect(said.single.message, 'Ingen anslutning');

        // The next transition is announced again, still once.
        mockOffline.setOnline(true);
        await tester.pump();
        expect(tester.takeAnnouncements(), hasLength(1));
        await tester.pump(AppDimensions.snackbarDuration);
        await tester.pumpAndSettle();
      });

      testWidgets('a banner only on a route below the top stays quiet', (
        tester,
      ) async {
        mockOffline.setOnline(true);
        final navKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navKey,
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: OfflineIndicator()),
          ),
        );
        navKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('top')),
          ),
        );
        await tester.pumpAndSettle();

        mockOffline.setOnline(false);
        await tester.pump();
        expect(tester.takeAnnouncements(), isEmpty);
      });
    });

    group('OfflineStatusIcon', () {
      testWidgets('shows nothing when online', (tester) async {
        mockOffline.setOnline(true);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineStatusIcon()),
        );
        expect(find.byIcon(Icons.wifi_off), findsNothing);
        expect(find.byIcon(Icons.cloud_off), findsNothing);
      });

      for (final brightness in Brightness.values) {
        testWidgets('${brightness.name}: wifi-off in text.warning', (
          tester,
        ) async {
          mockOffline.setOnline(false);
          await tester.pumpWidget(
            _themedApp(const OfflineStatusIcon(), brightness: brightness),
          );
          expect(find.byIcon(Icons.cloud_off), findsNothing);
          final icon = tester.widget<Icon>(find.byIcon(Icons.wifi_off));
          expect(icon.color, AppModeColors.textWarning(brightness));
          expect(icon.size, AppDimensions.iconSizeAction);
        });
      }

      testWidgets('switches from offline to online', (tester) async {
        mockOffline.setOnline(false);
        await tester.pumpWidget(
          createLocalizedTestApp(child: const OfflineStatusIcon()),
        );
        expect(find.byIcon(Icons.wifi_off), findsOneWidget);
        mockOffline.setOnline(true);
        await tester.pump();
        expect(find.byIcon(Icons.wifi_off), findsNothing);
      });
    });
  });

  group('AppModeColors.textWarning', () {
    test('is text.warning in both modes (tokens.json:92-95)', () {
      expect(
        AppModeColors.textWarning(Brightness.light),
        const Color(0xFF8A5212),
      );
      expect(
        AppModeColors.textWarning(Brightness.dark),
        const Color(0xFFDCA968),
      );
    });
  });
}
