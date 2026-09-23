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

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/fullscreen_image_viewer.dart';

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
      testWidgets('${brightness.name}: surface.raised, glyph and second line '
          'text.secondary.onRaised, first line text.body (bodyMuted not '
          'delivered yet), caption 12/400, no button', (
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
        final icon = tester.widget<Icon>(find.byIcon(Icons.image_outlined));
        expect(icon.color, secondary);

        final first = tester.widget<Text>(find.text(sv.imageCouldNotBeShown));
        expect(first.style?.color, AppModeColors.textBody(brightness));
        // Drawn 12.5 px regular; caption 12/400 is the nearest role.
        expect(first.style?.fontSize, 12);
        expect(first.style?.fontWeight, FontWeight.w400);
        final second = tester.widget<Text>(
          find.text(sv.imageRetriesWhenOnline),
        );
        expect(second.style?.color, secondary);

        // The drawing offers no button, and the old faded icon is gone.
        expect(find.byType(ButtonStyleButton), findsNothing);
        expect(find.byIcon(Icons.error_outline), findsNothing);
      });
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

    setUp(() async {
      // The image cache needs a directory; the fetch itself then fails
      // (flutter_test answers every HTTP request with 400).
      tempDir = Directory.systemTemp.createTempSync('fullscreen_img_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => tempDir.path);
      await GetIt.instance.reset();
      offline = _FakeOfflineService();
      GetIt.instance.registerSingleton<OfflineService>(offline);
      prod.ServiceLocator.initialize(DIContainer());
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
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
  });
}
