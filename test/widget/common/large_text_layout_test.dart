/// At 200 % text a row that shares one line at 1.0 gives its parts a share too
/// narrow for their words. Each shared layout then moves the part that does
/// not fit under the rest, so no word is broken between letters.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/button_row.dart';
import 'package:butlery/widgets/common/buttons/image_source_buttons.dart';
import 'package:butlery/widgets/common/diff_field_row.dart';
import 'package:butlery/widgets/common/layout/heading_actions_row.dart';
import 'package:butlery/widgets/common/layout/inline_widget_span.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
import 'package:butlery/widgets/common/list/butlery_media_row.dart';

import '../../infrastructure/helpers/base_widget_test.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/word_break_finder.dart';

Future<void> _pump(
  WidgetTester tester,
  double scale,
  Widget Function(BuildContext) build,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    createLocalizedTestApp(
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(24),
              children: [build(context)],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(BaseWidgetTest.setupWidget);
  tearDown(BaseWidgetTest.teardownWidget);

  testWidgets('a widget in running text is scaled once, by the paragraph', (
    tester,
  ) async {
    double? inside;
    await _pump(
      tester,
      2,
      (context) => Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'Jag godkänner '),
            inlineWidgetSpan(
              child: Builder(
                builder: (context) {
                  inside = MediaQuery.textScalerOf(context).scale(1);
                  return const Text('villkoren');
                },
              ),
            ),
          ],
        ),
      ),
    );
    expect(inside, 1.0);
  });

  testWidgets('buttons share a line at 1.0 and stack at 200 % text', (
    tester,
  ) async {
    Widget row(BuildContext context) => ButtonRow(
      children: [
        ActionButtons.outlinedButton(
          context,
          label: 'Nästa steg',
          isExpanded: true,
          onPressed: () {},
        ),
        ActionButtons.dangerButton(
          context,
          label: 'Radera innehåll',
          isExpanded: true,
          onPressed: () {},
        ),
      ],
    );
    await _pump(tester, 1, row);
    final first = tester.getTopLeft(find.byType(OutlinedButton).first);
    final second = tester.getTopLeft(find.byType(OutlinedButton).last);
    expect(second.dx, greaterThan(first.dx), reason: 'side by side at 1.0');

    await _pump(tester, 2, row);
    final stackedFirst = tester.getBottomLeft(
      find.byType(OutlinedButton).first,
    );
    final stackedSecond = tester.getTopLeft(find.byType(OutlinedButton).last);
    expect(stackedSecond.dy, greaterThan(stackedFirst.dy - 1));
    expect(findMidWordBreaks(tester), isEmpty);
  });

  testWidgets(
    'a button label wider than the button scales instead of breaking',
    (
      tester,
    ) async {
      await _pump(
        tester,
        2,
        (context) => Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 150,
            child: ActionButtons.outlinedButton(
              context,
              label: 'Galleri',
              isExpanded: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(findMidWordBreaks(tester), isEmpty);
    },
  );

  testWidgets('the picture buttons stack when a label word does not fit half', (
    tester,
  ) async {
    Widget buttons(BuildContext context) => ImageSourceButtons(
      cameraLabel: 'Fota nu',
      libraryLabel: 'Galleri',
      onCamera: () {},
      onLibrary: () {},
    );
    await _pump(tester, 1, buttons);
    final camera = tester.getTopLeft(find.text('Fota nu'));
    final library = tester.getTopLeft(find.text('Galleri'));
    expect(library.dx, greaterThan(camera.dx), reason: 'side by side at 1.0');

    await _pump(tester, 2, buttons);
    final stackedCamera = tester.getBottomLeft(find.text('Fota nu'));
    final stackedLibrary = tester.getTopLeft(find.text('Galleri'));
    expect(stackedLibrary.dy, greaterThan(stackedCamera.dy));
    expect(findMidWordBreaks(tester), isEmpty);
  });

  testWidgets('a media row puts its end control under the name at 200 % text', (
    tester,
  ) async {
    Widget row(BuildContext context) => ButleryMediaRow(
      leading: const SizedBox(width: 40, height: 40),
      title: 'Gryta citron',
      trailing: const SizedBox(key: Key('end'), width: 120, height: 48),
    );
    await _pump(tester, 1, row);
    expect(
      tester.getTopLeft(find.byKey(const Key('end'))).dy,
      lessThan(tester.getBottomLeft(find.text('Gryta citron')).dy),
      reason: 'beside the name at 1.0',
    );

    await _pump(tester, 2, row);
    expect(
      tester.getTopLeft(find.byKey(const Key('end'))).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.text('Gryta citron')).dy,
      ),
    );
    expect(findMidWordBreaks(tester), isEmpty);
  });

  testWidgets('a heading puts its actions under it at 200 % text', (
    tester,
  ) async {
    Widget row(BuildContext context) => const HeadingActionsRow(
      heading: Text('Medlemmar'),
      actions: [SizedBox(key: Key('act'), width: 100, height: 48)],
    );
    await _pump(tester, 1, row);
    expect(
      tester.getTopLeft(find.byKey(const Key('act'))).dy,
      lessThan(tester.getBottomLeft(find.text('Medlemmar')).dy),
    );
    await _pump(tester, 2, row);
    expect(
      tester.getTopLeft(find.byKey(const Key('act'))).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.text('Medlemmar')).dy),
    );
  });

  testWidgets(
    'a changed field puts each version\'s text under its name at 200 %',
    (
      tester,
    ) async {
      Widget row(BuildContext context) => const DiffFieldRow(
        title: 'Titel',
        emptyText: '(tom)',
        versions: [
          DiffVersion(
            name: 'Förslaget',
            text: 'Röda linser',
            marker: Colors.red,
          ),
        ],
      );
      await _pump(tester, 1, row);
      expect(
        tester.getTopLeft(find.text('Röda linser')).dy,
        lessThan(tester.getBottomLeft(find.text('Förslaget')).dy),
        reason: 'beside the name at 1.0',
      );
      await _pump(tester, 2, row);
      expect(
        tester.getTopLeft(find.text('Röda linser')).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.text('Förslaget')).dy),
      );
      expect(findMidWordBreaks(tester), isEmpty);
    },
  );

  testWidgets('rich whole-word text scales a word wider than its line', (
    tester,
  ) async {
    await _pump(
      tester,
      2,
      (context) => const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 200,
          child: WholeWordText.rich(
            TextSpan(
              text: 'Utfall: matlagningsentusiaster',
              style: TextStyle(fontSize: 14),
            ),
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
    expect(findMidWordBreaks(tester), isEmpty);
  });
}
