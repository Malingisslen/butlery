// BUT-2183 5n: the share-receiving view leaves the old opacity steps. The
// "recipe text found" notice is the mode's success surface tint and the failed
// extraction notice is the danger tint, both with no border; glyph and text
// are onSuccessContainer and onErrorContainer. Each test runs in both modes and
// asserts fills, borders, glyph and text colours.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/content_detector_service.dart';
import 'package:butlery/services/social_media_extractor.dart'
    hide SourcePlatform;
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/receive_share_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

late AppLocalizations _sv;

class _MockDetector extends Mock implements ContentDetectorService {}

class _MockExtractor extends Mock implements SocialMediaExtractor {}

class _MockAnalytics extends Mock implements AnalyticsService {}

Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required ContentDetectionResult detected,
  ExtractionResult? extraction,
}) async {
  tester.view.physicalSize = const Size(420, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The test font is wider than the production one, so rows overflow the
  // viewport; these tests read colours, not layout.
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalHandler);

  final detector = _MockDetector();
  when(() => detector.detectContent(any())).thenAnswer((_) async => detected);
  final extractor = _MockExtractor();
  when(extractor.dispose).thenAnswer((_) async {});
  if (extraction != null) {
    when(() => extractor.extractFromUrl(any())).thenAnswer(
      (_) async => extraction,
    );
  }
  final getIt = GetIt.instance;
  getIt.registerSingleton<ContentDetectorService>(detector);
  getIt.registerSingleton<SocialMediaExtractor>(extractor);
  final analytics = _MockAnalytics();
  when(
    () => analytics.logImportStarted(
      source: any(named: 'source'),
      platform: any(named: 'platform'),
      sessionId: any(named: 'sessionId'),
    ),
  ).thenAnswer((_) async {});
  when(
    () => analytics.logExtractionError(
      url: any(named: 'url'),
      platform: any(named: 'platform'),
      error: any(named: 'error'),
      errorType: any(named: 'errorType'),
    ),
  ).thenAnswer((_) async {});
  getIt.registerSingleton<AnalyticsService>(analytics);
  prod.ServiceLocator.initialize(DIContainer());

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
      home: const ReceiveShareView(content: 'delat', type: 'text'),
    ),
  );
  await tester.pump();
  // The view waits out its own short analysis delay before it shows anything.
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
}

BoxDecoration _boxAbove(WidgetTester tester, Finder of) =>
    tester
            .widget<Container>(
              find
                  .ancestor(
                    of: of,
                    matching: find.byWidgetPredicate(
                      (w) =>
                          w is Container &&
                          w.decoration is BoxDecoration &&
                          (w.decoration! as BoxDecoration).color != null,
                    ),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Color? _textColor(WidgetTester tester, Finder text) =>
    tester.widget<Text>(text).style?.color;

Color? _glyphColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon).first).color;

void main() {
  setUpAll(() async {
    registerFallbackValue(SourcePlatform.unknown);
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  setUp(() async {
    await GetIt.instance.reset();
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('receive share view, $mode', () {
      testWidgets(
        'the recipe-text notice is the success tint with no border and '
        'onSuccessContainer glyph and text',
        (tester) async {
          await _pump(
            tester,
            theme,
            detected: ContentDetectionResult(
              type: ContentType.recipeText,
              originalContent: 'delat',
            ),
          );

          final text = find.text(_sv.importRecipeTextCanImport);
          expect(text, findsOneWidget);
          final box = _boxAbove(tester, text);
          expect(box.color, modeColors.surfaceTintSuccess);
          expect(box.border, isNull);
          expect(
            _glyphColor(tester, ButleryIcons.circleCheck),
            modeColors.onSuccessContainer,
          );
          expect(_textColor(tester, text), modeColors.onSuccessContainer);
        },
      );

      testWidgets(
        'the failed-extraction notice is the danger tint with no border and '
        'onErrorContainer glyph and text',
        (tester) async {
          await _pump(
            tester,
            theme,
            detected: ContentDetectionResult(
              type: ContentType.socialMediaUrl,
              extractedUrl: 'https://www.instagram.com/p/abc/',
              originalContent: 'delat',
            ),
            extraction: ExtractionResult(
              success: false,
              error: 'Inlägget gick inte att läsa',
            ),
          );

          await tester.tap(find.text(_sv.importFetchAutomatically));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          final text = find.text('Inlägget gick inte att läsa');
          expect(text, findsOneWidget);
          final box = _boxAbove(tester, text);
          expect(box.color, modeColors.surfaceTintDanger);
          expect(box.border, isNull);
          expect(
            _glyphColor(tester, ButleryIcons.triangleAlert),
            cs.onErrorContainer,
          );
          expect(_textColor(tester, text), cs.onErrorContainer);
        },
      );
    });
  }
}
