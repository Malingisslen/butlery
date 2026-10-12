/// The calendar week header keeps its label readable on a narrow phone.
///
/// The Linux golden of the week menu (360 x 800) showed the label
/// "Vecka 39 · 21 sep–27 sep" broken one or two letters per line: the
/// chevrons and the three week actions left it about 88 dp. The header now
/// moves the actions to a second row when the label does not fit beside
/// them. This pumps [WeekNavHeader] with the real ButlerySans at 320 and
/// 360 dp, at 100 % and 200 % text, and expects the title and the dates each
/// on one line, no layout exception, and every action a 48 dp tap target.
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

const _title = 'Vecka 39';
const _range = '21 sep–27 sep';

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
                      title: _title,
                      range: _range,
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

        // Title and dates each stay on one line: the label never wraps a
        // word, let alone a letter, however narrow the phone or large the text.
        for (final text in [_title, _range]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byKey(WeekNavHeader.labelKey),
              matching: find.text(text),
            ),
          );
          final oneLine = TextPainter(
            text: TextSpan(text: text, style: paragraph.text.style),
            textDirection: TextDirection.ltr,
            textScaler: paragraph.textScaler,
          )..layout();
          expect(
            paragraph.size.height,
            lessThanOrEqualTo(oneLine.height + 1),
            reason: '"$text" must fit on one line',
          );
          oneLine.dispose();
        }

        // Every button is a 48 dp tap target, and can be tapped.
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
                title: _title,
                range: _range,
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

    expect(find.byKey(WeekNavHeader.labelKey), findsOneWidget);
    expect(find.byKey(WeekNavHeader.actionsRowKey), findsNothing);
  });
}
