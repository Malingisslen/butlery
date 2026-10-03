// A photo that exists but failed to load (P5-U11).
//
// Sources: Komponentark v1:839 (case 4: keep the surface in surface.raised,
// the image glyph in text.secondary, "Bilden kunde inte visas", a silent
// retry when the network returns), Skarmar v12 del 4 #receptbildfel (the
// second line "Försöker igen när nätet är tillbaka", and no button: the
// user can do nothing about the network), tillganglighetshandoff:188 (role
// status, the text read once, the glyph decorative).
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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

Widget _app(Widget home, Brightness brightness) => MaterialApp(
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
  home: home,
);

void main() {
  final sv = AppLocalizationsSv();

  group('ImageFailedPlate', () {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${brightness.name}: surface.raised, glyph and second line '
        'text.secondary.onRaised, first line text.bodyMuted, caption 12/400, no button',
        (
          tester,
        ) async {
          await tester.pumpWidget(
            _app(
              const Scaffold(body: Center(child: ImageFailedPlate())),
              brightness,
            ),
          );

          final theme = Theme.of(tester.element(find.byType(ImageFailedPlate)));
          final box = tester.widget<ColoredBox>(
            find.descendant(
              of: find.byType(ImageFailedPlate),
              matching: find.byType(ColoredBox),
            ),
          );
          // surface.raised: #E6EAD9 light, #2F4437 dark.
          expect(box.color, theme.colorScheme.surfaceContainerHighest);
          expect(
            box.color,
            brightness == Brightness.dark
                ? const Color(0xFF2F4437)
                : const Color(0xFFE6EAD9),
          );

          final secondary = AppModeColors.textSecondaryOnRaised(brightness);
          final icon = tester.widget<Icon>(find.byIcon(ButleryIcons.image));
          expect(icon.color, secondary);

          final first = tester.widget<Text>(find.text(sv.imageCouldNotBeShown));
          expect(first.style?.color, AppModeColors.textBodyMuted(brightness));
          // Drawn 12.5 px regular; caption 12/400 is the nearest role.
          expect(first.style?.fontSize, 12);
          expect(first.style?.fontWeight, FontWeight.w400);
          final second = tester.widget<Text>(
            find.text(sv.imageRetriesWhenOnline),
          );
          expect(second.style?.color, secondary);

          // The drawing offers no button, and the old faded icon is gone.
          expect(find.byType(ButtonStyleButton), findsNothing);
          expect(find.byIcon(ButleryIcons.triangleAlert), findsNothing);
        },
      );
    }

    testWidgets('without a pending retry the plate promises none', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Scaffold(
            body: Center(child: ImageFailedPlate(retriesWhenOnline: false)),
          ),
          Brightness.light,
        ),
      );
      expect(find.text(sv.imageCouldNotBeShown), findsOneWidget);
      expect(find.text(sv.imageRetriesWhenOnline), findsNothing);
    });

    testWidgets('screen readers hear one status line; the glyph is decor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const Scaffold(body: Center(child: ImageFailedPlate())),
          Brightness.light,
        ),
      );
      final node = tester.getSemantics(find.byType(ImageFailedPlate));
      expect(node.label, sv.imageCouldNotBeShown);
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });

  group('FullscreenImageViewer', () {
    late _FakeOfflineService offline;
    late Directory tempDir;
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    const sqfliteChannel = MethodChannel('com.tekartik.sqflite');

    setUp(() async {
      // The image cache needs a directory; the fetch itself then fails
      // (flutter_test answers every HTTP request with 400).
      tempDir = Directory.systemTemp.createTempSync('fullscreen_img_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
      // On a macOS host flutter_cache_manager keeps its index in sqflite
      // (`Platform.isMacOS` in its config), and flutter test never runs the
      // plugin registrant that sets sqflite's factory. Without this the index
      // throws before the fetch, the load never completes, and the plate
      // never appears on a macOS runner.
      sqflite.databaseFactoryOrNull = sqflite.databaseFactorySqflitePlugin;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sqfliteChannel, (call) async {
            switch (call.method) {
              case 'getDatabasesPath':
                return tempDir.path;
              case 'openDatabase':
                return 1;
              case 'query':
                return <Map<String, Object?>>[];
              default:
                return null;
            }
          });
      await GetIt.instance.reset();
      offline = _FakeOfflineService();
      GetIt.instance.registerSingleton<OfflineService>(offline);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(sqfliteChannel, null);
      sqflite.databaseFactoryOrNull = null;
      prod.ServiceLocator.reset();
      await GetIt.instance.reset();
      try {
        tempDir.deleteSync(recursive: true);
      } on FileSystemException catch (_) {
        // The cache may still hold a handle on Windows; the OS cleans up.
      }
    });

    Future<void> pumpUntilFailed(WidgetTester tester) async {
      for (var i = 0; i < 250; i++) {
        if (find.byType(ImageFailedPlate).evaluate().isNotEmpty) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    testWidgets('a failed photo keeps its surface and explains, and is '
        'retried silently when the connection returns', (tester) async {
      await tester.pumpWidget(
        _app(
          const FullscreenImageViewer(
            imageUrls: ['https://invalid.invalid/photo.jpg'],
            initialIndex: 0,
          ),
          Brightness.light,
        ),
      );
      await pumpUntilFailed(tester);

      expect(find.byType(ImageFailedPlate), findsOneWidget);
      expect(find.text(sv.imageCouldNotBeShown), findsOneWidget);
      // Failed while online: no retry is pending, so none is promised.
      expect(find.text(sv.imageRetriesWhenOnline), findsNothing);
      expect(
        find.byKey(const ValueKey('fullscreenImage.0.0')),
        findsOneWidget,
      );

      // Connection drops: now a retry is pending and the line says so.
      offline.setOnline(false);
      await tester.pump();
      expect(find.text(sv.imageRetriesWhenOnline), findsOneWidget);

      // Connection returns: the photo is resolved anew, with no tap from
      // the user.
      offline.setOnline(true);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('fullscreenImage.0.1')),
        findsOneWidget,
      );
      expect(find.byType(CachedNetworkImage), findsOneWidget);

      // Let the retried fetch and the cache's own timers run out.
      await pumpUntilFailed(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 1));
    });

    // P7-A3: a modal over the photo closes with X, never a back arrow
    // (Komponentark v1:57, pattern 4), as the chat photo viewer does
    // (lib/widgets/messaging/fullscreen_image_viewer.dart). The bar is the
    // standard ButleryTopBar with the 'n / N' title; a tap hides it.
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: the bar is ButleryTopBar with an X '
          '(Stäng) and the n / N title, no back arrow', (tester) async {
        await tester.pumpWidget(
          _app(
            const FullscreenImageViewer(
              imageUrls: [
                'https://invalid.invalid/a.jpg',
                'https://invalid.invalid/b.jpg',
              ],
              initialIndex: 1,
            ),
            brightness,
          ),
        );
        await tester.pump();

        expect(find.byType(ButleryTopBar), findsOneWidget);
        final close = find.widgetWithIcon(IconButton, ButleryIcons.x);
        expect(close, findsOneWidget);
        expect(tester.widget<IconButton>(close).tooltip, sv.commonClose);
        expect(find.byIcon(ButleryIcons.arrowLeft), findsNothing);
        expect(find.text('2 / 2'), findsOneWidget);

        // Tapping the photo hides the bar.
        await tester.tap(find.byType(InteractiveViewer));
        await tester.pump();
        expect(find.byType(ButleryTopBar), findsNothing);
      });

      // Q7-03 = A: the photo is framed on surface.ink in both modes, and the
      // X stays on the photo when the bar is hidden: a paper X on an ink
      // disc, 48 dp, named Stäng, with the paper focus ring of an ink
      // surface (tokens.json:112-115, :155-160, touchTarget.min).
      testWidgets('${brightness.name}: the frame is ink and the X stays when '
          'the bar is hidden', (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigatorKey,
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
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const Scaffold(body: Text('recipe')),
          ),
        );
        navigatorKey.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const FullscreenImageViewer(
              imageUrls: ['https://invalid.invalid/a.jpg'],
              initialIndex: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cs = Theme.of(
          tester.element(find.byType(FullscreenImageViewer)),
        ).colorScheme;
        // surface.ink is the same colour in both schemes.
        expect(cs.primary, AppTheme.lightTheme.colorScheme.primary);
        expect(cs.primary, AppTheme.darkTheme.colorScheme.primary);
        final scaffold = tester.widget<Scaffold>(
          find
              .descendant(
                of: find.byType(FullscreenImageViewer),
                matching: find.byType(Scaffold),
              )
              .first,
        );
        expect(scaffold.backgroundColor, cs.primary);

        // With the bar showing, its own X is the only one.
        expect(
          find.byKey(const ValueKey('fullscreenImage.close')),
          findsNothing,
        );
        expect(find.byIcon(ButleryIcons.x), findsOneWidget);

        await tester.tap(find.byType(InteractiveViewer));
        await tester.pump();
        expect(find.byType(ButleryTopBar), findsNothing);

        final closeFinder = find.byKey(const ValueKey('fullscreenImage.close'));
        expect(closeFinder, findsOneWidget);
        expect(find.byIcon(ButleryIcons.x), findsOneWidget);
        final close = tester.widget<IconButton>(closeFinder);
        expect(close.tooltip, sv.commonClose);
        expect(close.style!.backgroundColor!.resolve({}), cs.primary);
        expect(close.style!.foregroundColor!.resolve({}), cs.onPrimary);
        expect(cs.onPrimary, AppTheme.lightTheme.colorScheme.onPrimary);
        expect(cs.onPrimary, AppTheme.darkTheme.colorScheme.onPrimary);
        final size = tester.getSize(closeFinder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(
          tester.getSemantics(closeFinder),
          matchesSemantics(
            tooltip: sv.commonClose,
            isButton: true,
            hasTapAction: true,
            hasFocusAction: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
          ),
        );
        final surface = tester.widget<FocusRingSurface>(
          find.ancestor(
            of: closeFinder,
            matching: find.byType(FocusRingSurface),
          ),
        );
        expect(surface.brightness, Brightness.dark);

        // The X closes the viewer.
        await tester.tap(closeFinder);
        await tester.pumpAndSettle();
        expect(find.byType(FullscreenImageViewer), findsNothing);
        expect(find.text('recipe'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(minutes: 1));
      });
    }
  });
}
