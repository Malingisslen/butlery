/// The calendar week header keeps its label readable on a narrow phone.
///
/// The Linux golden of the week menu (360 x 800) showed the label
/// "Vecka 39 · 21 sep–27 sep" broken one or two letters per line: the
/// chevrons and the three week actions left it about 88 dp. The header now
/// moves the actions to a second row when the label does not fit beside
/// them. This pumps [WeekNavHeader] with the real ButlerySans at 320 and
/// 360 dp, at 100 % and 200 % text, and expects the label on at most two
/// lines, no word broken inside, no layout exception, and every action a
/// 48 dp tap target.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/menu/calendar/calendar_header.dart';

Future<void> _loadButlerySans() async {
  final loader = FontLoader('ButlerySans');
  for (final face in ['Regular', 'Semibold', 'Bold']) {
    final bytes = File(
      'assets/fonts/ButlerySans-0.626-$face.ttf',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

const _label = 'Vecka 39 · 21 sep–27 sep';

void main() {
  setUpAll(_loadButlerySans);

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the week label stays readable at $width dp, text x$scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('sv'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Column(
                  children: [
                    WeekNavHeader(
                      label: _label,
                      onPrev: () {},
                      onNext: () {},
                      onSelectMode: () {},
                      onCopyWeek: () {},
                      onClearWeek: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);

        final paragraph = tester.renderObject<RenderParagraph>(
          find.byKey(WeekNavHeader.labelKey),
        );
        final labelWidth = paragraph.size.width;
        TextPainter painterFor(String text, {int? maxLines}) => TextPainter(
          text: TextSpan(text: text, style: paragraph.text.style),
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
          maxLines: maxLines,
        )..layout(maxWidth: labelWidth);

        // At most two lines as laid out.
        final laidOut = painterFor(_label, maxLines: 2);
        expect(laidOut.computeLineMetrics().length, lessThanOrEqualTo(2));
        laidOut.dispose();

        // No word is broken inside: every word fits the label's width on
        // one line, so the label wraps by words, never letter by letter.
        for (final word in _label.split(' ')) {
          final p = painterFor(word);
          expect(
            p.computeLineMetrics().length,
            1,
            reason: '"$word" must fit on one line of $labelWidth dp',
          );
          p.dispose();
        }

        // Every button keeps a 48 dp tap target and can be tapped.
        final buttons = find.byType(IconButton);
        expect(buttons, findsNWidgets(5));
        for (final element in buttons.evaluate()) {
          final size = tester.getSize(find.byWidget(element.widget));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        for (final tip in [
          'Välj flera att flytta',
          'Kopiera denna vecka → nästa vecka',
          'Rensa veckan',
        ]) {
          expect(find.byTooltip(tip).hitTestable(), findsOneWidget);
        }
      });
    }
  }

  testWidgets('the actions stay on the label row when there is room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Column(
            children: [
              WeekNavHeader(
                label: _label,
                onPrev: () {},
                onNext: () {},
                onSelectMode: () {},
                onCopyWeek: () {},
                onClearWeek: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(WeekNavHeader.actionsRowKey), findsNothing);
  });
}
