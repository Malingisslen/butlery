/// Widget tests for ButleryTopBar — the canonical top bar
/// (Komponentark v1 §01, patterns 1 and 2; decision D2 of package 2).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

const _titleKey = ValueKey('butleryTopBar.title');
const _secondaryKey = ValueKey('butleryTopBar.secondaryLine');
const _backKey = ValueKey('butleryTopBar.back');

Widget _app(
  PreferredSizeWidget bar, {
  ThemeData? theme,
  double textScale = 1.0,
  bool pushed = false,
}) {
  final page = Scaffold(
    appBar: bar,
    body: const SizedBox.expand(key: ValueKey('body')),
  );
  return MaterialApp(
    theme: theme ?? AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: pushed
        ? Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => page)),
                  child: const Text('open'),
                ),
              ),
            ),
          )
        : page,
  );
}

Future<void> _pumpPushed(WidgetTester tester, PreferredSizeWidget bar) async {
  await tester.pumpWidget(_app(bar, pushed: true));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Color? _textColor(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).style?.color;

Color? _barColor(WidgetTester tester) => tester
    .widget<Material>(
      find
          .descendant(
            of: find.byType(ButleryTopBar),
            matching: find.byType(Material),
          )
          .first,
    )
    .color;

/// The back arrow's accessible name. IconButton carries it as the semantics
/// tooltip, which both platforms read as the control's name.
String _backName(WidgetTester tester) =>
    tester.getSemantics(find.byKey(_backKey)).getSemanticsData().tooltip;

void main() {
  group('pattern 1 · rot', () {
    testWidgets('has no back arrow even when the route can pop', (
      tester,
    ) async {
      await _pumpPushed(tester, const ButleryTopBar.rot(title: 'Inköp'));
      expect(find.byKey(_backKey), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('title is display.compact 26/700', (tester) async {
      await tester.pumpWidget(_app(const ButleryTopBar.rot(title: 'Inköp')));
      final style = tester.widget<Text>(find.byKey(_titleKey)).style!;
      expect(style.fontSize, 26);
      expect(style.fontWeight, FontWeight.w700);
    });

    testWidgets('secondary line sits under the title', (tester) async {
      await tester.pumpWidget(
        _app(
          const ButleryTopBar.rot(
            title: 'Inköp',
            secondaryLine: 'Veckans inköp · 4 av 16 klara',
          ),
        ),
      );
      final title = tester.getRect(find.byKey(_titleKey));
      final line = tester.getRect(find.byKey(_secondaryKey));
      expect(line.top, greaterThanOrEqualTo(title.bottom));
      expect(line.left, title.left);
    });

    testWidgets('the bar hugs its content and the body starts under it', (
      tester,
    ) async {
      const bar = ButleryTopBar.rot(title: 'Inköp', secondaryLine: '4 av 16');
      await tester.pumpWidget(_app(bar));
      final barRect = tester.getRect(find.byType(ButleryTopBar));
      expect(barRect.height, lessThan(bar.preferredSize.height));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        barRect.bottom,
      );
    });
  });

  group('pattern 2 · undersida', () {
    testWidgets('title is 14/700 on a single line', (tester) async {
      await tester.pumpWidget(
        _app(const ButleryTopBar.undersida(title: 'Krämig svamppasta')),
      );
      final text = tester.widget<Text>(find.byKey(_titleKey));
      expect(text.style!.fontSize, 14);
      expect(text.style!.fontWeight, FontWeight.w700);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('back arrow is named after its destination', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpPushed(
        tester,
        const ButleryTopBar.undersida(
          title: 'Krämig svamppasta med timjan',
          backTo: 'Mina recept',
        ),
      );
      expect(find.byKey(_backKey), findsOneWidget);
      expect(_backName(tester), 'Tillbaka till Mina recept');
      handle.dispose();
    });

    testWidgets('without a destination the name falls back to Tillbaka', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpPushed(
        tester,
        const ButleryTopBar.undersida(title: 'Receptet'),
      );
      expect(_backName(tester), 'Tillbaka');
      handle.dispose();
    });

    testWidgets('back arrow pops the route', (tester) async {
      await _pumpPushed(
        tester,
        const ButleryTopBar.undersida(title: 'Receptet'),
      );
      await tester.tap(find.byKey(_backKey));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('onBack replaces the default pop', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _app(
          ButleryTopBar.undersida(title: 'Receptet', onBack: () => tapped++),
        ),
      );
      await tester.tap(find.byKey(_backKey));
      expect(tapped, 1);
    });

    testWidgets('no back arrow when there is nothing to go back to', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const ButleryTopBar.undersida(title: 'Receptet')),
      );
      expect(find.byKey(_backKey), findsNothing);
    });

    testWidgets('a leading widget replaces the back arrow, never beside it', (
      tester,
    ) async {
      await _pumpPushed(
        tester,
        ButleryTopBar.undersida(
          title: '2 valda',
          leading: TextButton(onPressed: () {}, child: const Text('Avbryt')),
        ),
      );
      expect(find.text('Avbryt'), findsOneWidget);
      expect(find.byKey(_backKey), findsNothing);
    });
  });

  group('both patterns', () {
    for (final entry in <String, PreferredSizeWidget Function(List<Widget>)>{
      'rot': (a) => ButleryTopBar.rot(title: 'Inköp', actions: a),
      'undersida': (a) => ButleryTopBar.undersida(title: 'Inköp', actions: a),
    }.entries) {
      testWidgets('${entry.key}: actions get 48 dp hitboxes 8 dp apart', (
        tester,
      ) async {
        final actions = [
          for (var i = 0; i < 3; i++)
            GestureDetector(
              key: ValueKey('action$i'),
              onTap: () {},
              child: const Icon(Icons.more_vert, size: 17),
            ),
        ];
        await tester.pumpWidget(_app(entry.value(actions)));
        final boxes = [
          for (var i = 0; i < 3; i++)
            tester.getRect(
              find
                  .ancestor(
                    of: find.byKey(ValueKey('action$i')),
                    matching: find.byType(ConstrainedBox),
                  )
                  .first,
            ),
        ];
        for (final box in boxes) {
          expect(box.width, greaterThanOrEqualTo(48));
          expect(box.height, greaterThanOrEqualTo(48));
        }
        expect(boxes[1].left - boxes[0].right, greaterThanOrEqualTo(8));
        expect(boxes[2].left - boxes[1].right, greaterThanOrEqualTo(8));
      });

      testWidgets('${entry.key}: the title keeps its case', (tester) async {
        await tester.pumpWidget(_app(entry.value(const [])));
        expect(find.text('Inköp'), findsOneWidget);
        expect(find.text('inköp'), findsNothing);
      });

      testWidgets('${entry.key}: the title is a heading', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(_app(entry.value(const [])));
        final data = tester
            .getSemantics(find.byKey(_titleKey))
            .getSemanticsData();
        expect(data.flagsCollection.isHeader, isTrue);
        expect(data.headingLevel, 1);
        handle.dispose();
      });
    }

    testWidgets('the secondary line is a live region by default', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const ButleryTopBar.rot(
            title: 'Mina recept',
            secondaryLine: '48 recept',
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(_secondaryKey))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('the live region can be turned off for fixed text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const ButleryTopBar.rot(
            title: 'Mina recept',
            secondaryLine: 'Sparade recept',
            secondaryLineIsLive: false,
          ),
        ),
      );
      final data = tester
          .getSemantics(find.byKey(_secondaryKey))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isFalse);
      handle.dispose();
    });

    testWidgets('no accent line: nothing is drawn below the bar', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const ButleryTopBar.rot(title: 'Inköp')));
      expect(
        find.descendant(
          of: find.byType(ButleryTopBar),
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    });

    testWidgets('bottom is added to preferredSize and rendered', (
      tester,
    ) async {
      const bottom = PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: SizedBox(height: 40, key: ValueKey('tabs')),
      );
      const plain = ButleryTopBar.undersida(title: 'Receptet');
      const withBottom = ButleryTopBar.undersida(
        title: 'Receptet',
        bottom: bottom,
      );
      expect(
        withBottom.preferredSize.height,
        plain.preferredSize.height + 40,
      );
      await tester.pumpWidget(_app(withBottom));
      expect(find.byKey(const ValueKey('tabs')), findsOneWidget);
    });

    testWidgets('undersida is at least the toolbar height', (tester) async {
      await tester.pumpWidget(
        _app(const ButleryTopBar.undersida(title: 'Receptet')),
      );
      expect(
        tester.getSize(find.byType(ButleryTopBar)).height,
        greaterThanOrEqualTo(kToolbarHeight),
      );
    });

    testWidgets('iOS gets the same bar as Android (B-45)', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await _pumpPushed(
          tester,
          const ButleryTopBar.undersida(title: 'Receptet'),
        );
        expect(find.byType(CupertinoNavigationBar), findsNothing);
        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('colours are mode-aware', () {
    testWidgets('light: paper surface, ink text, secondary text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(const ButleryTopBar.rot(title: 'Inköp', secondaryLine: '4 av 16')),
      );
      expect(_barColor(tester), AppColors.cream);
      expect(_textColor(tester, _titleKey), AppColors.textDark);
      expect(_textColor(tester, _secondaryKey), AppColors.recipeMeta);
      expect(
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
            )
            .value,
        SystemUiOverlayStyle.dark,
      );
    });

    testWidgets('dark: the same tokens take their dark values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const ButleryTopBar.rot(title: 'Inköp', secondaryLine: '4 av 16'),
          theme: AppTheme.darkTheme,
        ),
      );
      expect(_barColor(tester), AppColorsDark.cream);
      expect(_textColor(tester, _titleKey), AppColorsDark.textDark);
      expect(_textColor(tester, _secondaryKey), AppColorsDark.recipeMeta);
    });

    testWidgets('dark: the back arrow uses the dark foreground', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ButleryTopBar.undersida(title: 'Receptet', onBack: () {}),
          theme: AppTheme.darkTheme,
        ),
      );
      final icon = find.descendant(
        of: find.byKey(_backKey),
        matching: find.byType(RichText),
      );
      final style = tester.widget<RichText>(icon).text.style!;
      expect(style.color, AppColorsDark.textDark);
    });

    testWidgets('overrides win over the defaults', (tester) async {
      await tester.pumpWidget(
        _app(
          const ButleryTopBar.rot(
            title: 'Inköp',
            backgroundColor: AppColors.forestGreen,
            foregroundColor: AppColors.textOnPrimary,
          ),
        ),
      );
      expect(_barColor(tester), AppColors.forestGreen);
      expect(_textColor(tester, _titleKey), AppColors.textOnPrimary);
      expect(
        tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
            )
            .value,
        SystemUiOverlayStyle.light,
      );
    });
  });

  group('focus stays visible in the bar', () {
    for (final theme in {
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    }.entries) {
      testWidgets('${theme.key}: the focused back arrow keeps the app ring', (
        tester,
      ) async {
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
          () => FocusManager.instance.highlightStrategy =
              FocusHighlightStrategy.automatic,
        );
        await tester.pumpWidget(
          _app(
            ButleryTopBar.undersida(title: 'Receptet', onBack: () {}),
            theme: theme.value,
          ),
        );
        OutlinedBorder shape() =>
            tester
                    .widget<Material>(
                      find
                          .descendant(
                            of: find.byKey(_backKey),
                            matching: find.byType(Material),
                          )
                          .first,
                    )
                    .shape!
                as OutlinedBorder;
        expect(shape().side, BorderSide.none);

        Focus.of(
          tester.element(find.byIcon(Icons.chevron_left)),
        ).requestFocus();
        await tester.pumpAndSettle();

        // The app's icon button theme resolves the focused side; the bar
        // only swaps the foreground colour.
        final themed = theme.value.iconButtonTheme.style!.side!.resolve({
          WidgetState.focused,
        });
        expect(themed, isNotNull);
        expect(shape().side, themed);
        // 48 dp minimum from the app theme survives as well.
        final size = tester.getSize(find.byKey(_backKey));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      });
    }
  });

  group('large text (200 %)', () {
    for (final theme in {
      'light': AppTheme.lightTheme,
      'dark': AppTheme.darkTheme,
    }.entries) {
      testWidgets('${theme.key}: rot with actions at 320 dp loses nothing', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final bar = ButleryTopBar.rot(
          title: 'Veckans meny',
          secondaryLine: 'Vecka 6 · 5 rätter',
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
        );
        await tester.pumpWidget(_app(bar, theme: theme.value, textScale: 2));
        expect(tester.takeException(), isNull);
        expect(find.text('Veckans meny'), findsOneWidget);
        expect(find.text('Vecka 6 · 5 rätter'), findsOneWidget);
        final height = tester.getSize(find.byType(ButleryTopBar)).height;
        expect(height, lessThanOrEqualTo(bar.preferredSize.height));
        final line = tester.getRect(find.byKey(_secondaryKey));
        expect(
          line.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(ButleryTopBar)).bottom),
        );
      });

      testWidgets('${theme.key}: undersida at 320 dp does not overflow', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _app(
            ButleryTopBar.undersida(
              title: 'Krämig svamppasta med timjan',
              secondaryLine: '4 portioner',
              onBack: () {},
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
              ],
            ),
            theme: theme.value,
            textScale: 2,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(_backKey), findsOneWidget);
        expect(find.text('4 portioner'), findsOneWidget);
      });
    }
  });
}
