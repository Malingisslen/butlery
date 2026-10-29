/// A phone screenshot's own lines stay out of the recipe, and two
/// screenshots of one scrolled post become one text without the lines they
/// share (BUT-2455).
library;

import 'package:butlery/services/import/layout/page_reflow.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

OcrLine line(String text) => OcrLine(
  text: text,
  box: LayoutBox(left: 0, top: 0, width: text.length * 18, height: 20),
);

PageLayout layoutOf(String text) =>
    PageLayout(lines: text.split('\n').map(line).toList());

const post = '''
matglad.anna
Krämig kycklinggryta med timjan
Ingredienser
500 g kycklingfilé
2 dl grädde
Gör så här
Skär kycklingen i bitar och stek den gyllene i smör.
Häll i grädden och låt sjuda i tio minuter.
Smaka av med salt och peppar innan servering.
Servera med ris och en sallad.''';

void main() {
  final lines = post.split('\n');

  group('stripScreenChrome', () {
    test('the clock and its icon row go', () {
      final page = stripScreenChrome(PageText('10:55\nd 5 g ll 66\n$post'));
      expect(page.text, startsWith('Krämig kycklinggryta'));
    });

    test('an icon row only goes beside a clock', () {
      final page = stripScreenChrome(PageText('d 5 g ll 66\n$post'));
      expect(page.text, startsWith('d 5 g ll 66'));
    });

    test('a quantity row at the top stays', () {
      final page = stripScreenChrome(PageText('10:55\n2 st ägg\n$post'));
      expect(page.lines.first, '2 st ägg');
    });

    test('a clock on line five is the recipe', () {
      final page = stripScreenChrome(
        PageText('Deg\n1 dl vatten\n2 dl mjöl\nSalt\n1:30\nJäs.'),
      );
      expect(page.lines, contains('1:30'));
    });

    test('social lines at the edges go, the handle only at the top', () {
      final page = stripScreenChrome(
        PageText(
          '$post\n… mer\nGillas av anna_k och 12 andra\nFör 6 dagar sedan\nFöljer',
        ),
      );
      expect(page.text, startsWith('Krämig kycklinggryta'));
      expect(page.text, endsWith('Servera med ris och en sallad.'));
    });

    test('a social line in the middle of the page stays', () {
      const text =
          'Deg\n1 dl vatten\n2 dl mjöl\nSalt\nFör 6 dagar sedan\nJäs i en timme.\nKnåda.\nBaka.\nServera.';
      expect(stripScreenChrome(PageText(text)).text, text);
    });

    test('a bare lowercase ingredient at the top of a cookbook page stays', () {
      const text = 'Pannkakor\n3 dl mjöl\nsalt\nvatten\nVispa ihop allt.';
      expect(stripScreenChrome(PageText(text)).text, text);
    });

    test('the handle goes when the page also shows social chrome', () {
      final page = stripScreenChrome(PageText('$post\nFör 6 dagar sedan'));
      expect(page.text, startsWith('Krämig kycklinggryta'));
    });

    test('social chrome in the first lines goes', () {
      final page = stripScreenChrome(
        PageText('matglad.anna\nFöljer\n${lines.skip(1).join('\n')}'),
      );
      expect(page.text, startsWith('Krämig kycklinggryta'));
    });

    test('a handle-shaped word at the bottom stays even with evidence', () {
      final page = stripScreenChrome(
        PageText('$post\nFör 6 dagar sedan\nsalt'),
      );
      expect(page.lines.last, 'salt');
      expect(page.text, startsWith('Krämig kycklinggryta'));
    });

    test('an icon row before the clock goes', () {
      final page = stripScreenChrome(PageText('d 5 g ll 66\n10:55\n$post'));
      expect(page.text, startsWith('Krämig kycklinggryta'));
    });

    test('a clock on the second line is the status bar, on the third not', () {
      expect(
        stripScreenChrome(PageText('Hej\n10:55\n$post')).lines,
        isNot(contains('10:55')),
      );
      const deg = 'Deg\n1 dl vatten\n1:30\nJäs.';
      expect(stripScreenChrome(PageText(deg)).text, deg);
    });

    test('a bare lowercase word at the bottom stays', () {
      final page = stripScreenChrome(PageText('$post\nsalt'));
      expect(page.lines.last, 'salt');
    });

    test('the layout is filtered on the same indices', () {
      const text = '10:55\nd 5 g ll 66\n$post';
      final page = stripScreenChrome(PageText(text, layout: layoutOf(text)));
      expect(page.layout!.lines.map((l) => l.text).join('\n'), page.text);
    });

    test('a layout out of step with the text is dropped', () {
      const text = '10:55\n$post';
      final page = stripScreenChrome(
        PageText(text, layout: layoutOf('one\ntwo')),
      );
      expect(page.layout, isNull);
    });

    test('isIconRow', () {
      expect(isIconRow('d 5 g ll 66'), isTrue);
      expect(isIconRow('4G 66'), isTrue);
      expect(isIconRow('2 st ägg'), isFalse);
      expect(isIconRow('1 dl mjöl'), isFalse);
      expect(isIconRow('66'), isFalse);
    });
  });

  group('dropPageOverlap', () {
    test('three shared lines are dropped from the second page', () {
      final first = lines.take(7).join('\n');
      final second = lines.skip(4).join('\n');
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious, [false, true]);
      expect(result.pages[0].text, first);
      expect(result.pages[1].text, lines.skip(7).join('\n'));
    });

    test('a half-visible edge line is tolerated', () {
      final first = '${lines.take(7).join('\n')}\nHäll i gräd';
      final second = lines.skip(4).join('\n');
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isTrue);
      expect(result.pages[0].text, lines.take(7).join('\n'));
      expect(result.pages[1].text, lines.skip(7).join('\n'));
    });

    test('a title above near-identical bodies is not an edge line', () {
      // Two recipes on a spread can share most of their prose; the second
      // page's title must not be skipped to make them overlap.
      final steps = lines.skip(5).join('\n');
      final first = 'Italiensk frittata\n$steps';
      final second = 'Fransk omelett\n${steps.replaceFirst('tio', 'tolv')}';
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isFalse);
      expect(result.pages[1].text, second);
    });

    test('a cut-off first line on the later page is tolerated', () {
      // The later screenshot starts on the tail of the line before the
      // shared run — the cut half of "500 g kycklingfilé".
      final first = lines.take(7).join('\n');
      final second =
          'g kycklingfilé\n${lines.skip(4).take(3).join('\n')}\nNytt steg.';
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isTrue);
      expect(result.pages[1].text, 'Nytt steg.');
    });

    test('a trailing line that is no fragment is not skipped', () {
      final first = '${lines.take(7).join('\n')}\nSidan 3';
      final second = lines.skip(4).join('\n');
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isFalse);
      expect(result.pages[1].text, second);
    });

    test('OCR variants of one line still match', () {
      final first = lines.take(7).join('\n');
      final second = lines
          .skip(4)
          .join('\n')
          .replaceFirst('kycklingen', 'kyckIingen')
          .replaceFirst('grädde', 'gradde');
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isTrue);
    });

    test('a repeated quantity row is not an overlap', () {
      const first = 'Deg\n2 dl mjöl\n1 dl socker\n1 ägg';
      const second = 'Fyllning\n1 dl socker\n1 ägg\n50 g smör';
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isFalse);
      expect(result.pages[1].text, second);
    });

    test('two shared short lines are not an overlap', () {
      const first = 'Deg\n2 dl mjöl\n1 dl socker\n1 ägg';
      const second = '1 dl socker\n1 ägg\n50 g smör';
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isFalse);
      expect(result.pages[1].text, second);
    });

    test('two shared long lines suffice', () {
      final first = lines.take(8).join('\n');
      final second = lines.skip(6).join('\n');
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isTrue);
      expect(result.pages[1].text, lines.skip(8).join('\n'));
    });

    test('a repeat elsewhere in the page is not an overlap', () {
      final first = lines.take(7).join('\n');
      final second = '${lines.skip(2).take(3).join('\n')}\nNågot annat helt.';
      final result = dropPageOverlap([PageText(first), PageText(second)]);
      expect(result.continuesPrevious[1], isFalse);
    });

    test('no overlap leaves both pages whole', () {
      final result = dropPageOverlap([
        PageText(lines.take(5).join('\n')),
        PageText(lines.skip(5).join('\n')),
      ]);
      expect(result.continuesPrevious, [false, false]);
      expect(result.pages.map((p) => p.text).join('\n'), post);
    });
  });

  group('joinPages', () {
    test('a continuation joins with one newline without layout', () {
      expect(
        joinPages(
          [const PageText('a'), const PageText('b'), const PageText('c')],
          [false, true, false],
          layoutComplete: false,
        ),
        'a\nb\n\nc',
      );
    });

    test('with a complete layout every boundary is a blank line', () {
      expect(
        joinPages(
          [const PageText('a'), const PageText('b')],
          [false, true],
          layoutComplete: true,
        ),
        'a\n\nb',
      );
    });
  });

  group('prepareScreenPages', () {
    test('two overlapping screenshots become one cleaned text', () {
      final first = '10:55\nd 5 g ll 66\n${lines.take(7).join('\n')}';
      final second =
          '10:56\nd 5 g ll 66\n${lines.skip(4).join('\n')}\nFör 6 dagar sedan';
      final doc = prepareScreenPages([PageText(first), PageText(second)]);
      expect(doc.text, lines.skip(1).join('\n'));
      expect(doc.layouts, [null, null]);
    });

    test('with layouts on every page an overlap boundary stays blank', () {
      final first = lines.take(7).join('\n');
      final second = lines.skip(4).join('\n');
      final doc = prepareScreenPages([
        PageText(first, layout: layoutOf(first)),
        PageText(second, layout: layoutOf(second)),
      ]);
      final rows = doc.layouts.fold<int>(0, (n, l) => n + l!.lines.length);
      // Text rows = layout rows + the blank line `DocumentLayout` joins with.
      expect(doc.text.split('\n'), hasLength(rows + 1));
      expect(doc.text, '$first\n\n${lines.skip(7).join('\n')}');

      final mixed = prepareScreenPages([
        PageText(first, layout: layoutOf(first)),
        PageText(second),
      ]);
      expect(mixed.text, '$first\n${lines.skip(7).join('\n')}');
    });

    test('a page emptied by the overlap is dropped', () {
      final first = lines.take(7).join('\n');
      final second = lines.skip(4).take(3).join('\n');
      final doc = prepareScreenPages([PageText(first), PageText(second)]);
      // No clock and no social line on either page, so the handle stays.
      expect(doc.text, first);
      expect(doc.layouts, hasLength(1));
    });
  });
}
