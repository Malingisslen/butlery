/// Text scale reaches a link inside running text once: a link span that was
/// scaled both by its own Text and by the paragraph around it would grow by
/// the square of the scale.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/views/legal/markdown_body.dart';
import 'package:butlery/widgets/auth/terms_consent_row.dart';
import 'package:butlery/widgets/common/butlery_link.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';

Widget _app(Widget child, {required double scale}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

/// Width the paragraph gives the first link. The link's own box is laid out
/// unscaled and scaled by the paragraph, so a double scaling shows here.
Future<double> _linkWidth(
  WidgetTester tester,
  Widget child, {
  required double scale,
}) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child, scale: scale));
  await tester.pumpAndSettle();
  final link = find.byType(ButleryLink).first;
  final paragraph = tester.renderObject<RenderParagraph>(
    find.ancestor(of: link, matching: find.byType(RichText)).first,
  );
  final at = paragraph.text.toPlainText().indexOf('\uFFFC');
  return paragraph
      .getBoxesForSelection(TextSelection(baseOffset: at, extentOffset: at + 1))
      .single
      .toRect()
      .width;
}

void main() {
  void expectScaledOnce(double at1, double at2) {
    final ratio = at2 / at1;
    expect(ratio, inInclusiveRange(1.7, 2.3), reason: 'ratio $ratio');
  }

  testWidgets('a link in TermsConsentRow scales once at 2x text', (
    tester,
  ) async {
    Widget row() => TermsConsentRow(accepted: false, onChanged: (_) {});
    final at1 = await _linkWidth(tester, row(), scale: 1);
    final at2 = await _linkWidth(tester, row(), scale: 2);
    expectScaledOnce(at1, at2);
  });

  testWidgets('a link in MarkdownBody scales once at 2x text', (tester) async {
    const doc = 'Se [villkoren](https://butlery.se/villkor) för mer.';
    final at1 = await _linkWidth(
      tester,
      const MarkdownBody(data: doc),
      scale: 1,
    );
    final at2 = await _linkWidth(
      tester,
      const MarkdownBody(data: doc),
      scale: 2,
    );
    expectScaledOnce(at1, at2);
  });

  testWidgets('WholeWordText keeps the text scale when the words fit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const WholeWordText('Kort text', style: TextStyle(fontSize: 14)),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('Kort text'));
    expect(text.textScaler, isNull);
  });
}
