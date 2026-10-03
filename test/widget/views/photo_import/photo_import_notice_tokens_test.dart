// BUT-2183 5n: the photo import notices leave the old opacity steps. The
// offline-queued heirloom note and the low-quality photo warning are the
// mode's warning surface tint with no border; their glyph is text.warning (the
// status colour is never text) and their text is onWarningContainer. Each test
// runs in both modes and asserts fills, borders, glyph and text colours.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import/heirloom_section.dart';
import 'package:butlery/views/photo_import_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import '../../../infrastructure/helpers/offline_banner_support.dart';

late AppLocalizations _sv;

class _MockPhotoImportViewModel extends Mock implements PhotoImportViewModel {}

// Answers only what the view reads on the low-quality path; anything else
// reaches noSuchMethod and fails the test loudly.
class _QualityFakeViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  @override
  PhotoPermissionResolver? permissionResolver;

  @override
  bool get hasImage => true;

  @override
  Uint8List? get imageBytes => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  @override
  double? get qualityScore => 0.4;

  @override
  List<String>? get recommendations => ['Fotografera i bättre ljus'];

  @override
  bool get hasError => false;

  @override
  String? get error => null;

  @override
  bool get isProcessing => false;

  @override
  bool get hasOcrResult => false;

  @override
  bool get isHeirloom => false;

  @override
  bool get isHandwritten => false;

  @override
  bool get canToggleHandwritten => true;

  @override
  bool get canRetryOcr => false;

  @override
  bool get canReadPages => false;

  @override
  int get unreadPageCount => 0;

  @override
  List<Uint8List> get pageImages => [imageBytes!];

  @override
  bool get hasMultiplePages => false;

  @override
  bool get canAddPage => false;

  @override
  String get heirloomWriterName => '';

  @override
  int? get heirloomYear => null;

  @override
  String get heirloomNote => '';

  @override
  PhotoPermissionNotice? get permissionNotice => null;

  @override
  Future<PhotoImportDraft?> loadPersistedDraft() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget home) async {
  tester.view.physicalSize = const Size(420, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The test font is wider than the production one, so rows of icon and text
  // overflow the viewport; these tests read colours, not layout.
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalHandler);
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
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
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
    _sv = await AppLocalizations.delegate.load(const Locale('sv', 'SE'));
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final modeColors = ModeColors.of(theme.brightness);

    group('photo import notices, $mode', () {
      testWidgets(
        'the offline-queued heirloom note is the warning tint with no '
        'border, a text.warning glyph and onWarningContainer text',
        (tester) async {
          final vm = _MockPhotoImportViewModel();
          when(() => vm.isHeirloom).thenReturn(true);
          when(() => vm.isOfflineQueued).thenReturn(true);
          when(() => vm.heirloomWriterName).thenReturn('Mormor Ingrid');
          when(() => vm.heirloomYear).thenReturn(1962);
          when(() => vm.heirloomNote).thenReturn('Baksidan av en kalender');
          await _pump(
            tester,
            theme,
            Scaffold(body: HeirloomSection(viewModel: vm)),
          );

          final text = find.text(_sv.heirloomUploadOffline);
          expect(text, findsOneWidget);
          final box = _boxAbove(tester, text);
          expect(box.color, modeColors.surfaceTintWarning);
          expect(box.border, isNull);
          expect(
            _glyphColor(tester, ButleryIcons.wifiOff),
            AppModeColors.textWarning(theme.brightness),
          );
          expect(_textColor(tester, text), modeColors.onWarningContainer);
        },
      );

      group('the view', () {
        late _QualityFakeViewModel fake;

        setUp(() {
          fake = _QualityFakeViewModel();
          final getIt = GetIt.instance;
          if (getIt.isRegistered<PhotoImportViewModel>()) {
            getIt.unregister<PhotoImportViewModel>();
          }
          getIt.registerFactory<PhotoImportViewModel>(() => fake);
          app_provider.ServiceLocator.reset();
          app_provider.ServiceLocator.initialize(DIContainer());
          ensureOfflineService();
        });

        tearDown(() async {
          app_provider.ServiceLocator.reset();
          final getIt = GetIt.instance;
          if (getIt.isRegistered<PhotoImportViewModel>()) {
            getIt.unregister<PhotoImportViewModel>();
          }
        });

        testWidgets(
          'the low-quality warning is the warning tint with no border, a '
          'text.warning glyph and onWarningContainer text',
          (tester) async {
            await _pump(tester, theme, const PhotoImportView());

            final title = find.text(_sv.importImageQualityLow(40));
            expect(title, findsOneWidget);
            final box = _boxAbove(tester, title);
            expect(box.color, modeColors.surfaceTintWarning);
            expect(box.border, isNull);
            expect(
              _glyphColor(tester, ButleryIcons.triangleAlert),
              AppModeColors.textWarning(theme.brightness),
            );
            expect(_textColor(tester, title), modeColors.onWarningContainer);
            expect(
              _textColor(tester, find.text(_sv.importOcrMayFail)),
              modeColors.onWarningContainer,
            );
          },
        );
      });
    });
  }
}
