/// Turns the pages of a photo import into one document before the parser
/// sees it: strips a phone screenshot's own chrome off each page, drops the
/// lines two overlapping screenshots share, and joins what is left.
///
/// Pure functions, no Flutter imports, same category as `frame_trim.dart`
/// (see `lib/services/CLAUDE.md`). Runs BEFORE `withoutFrameNoise`, which
/// takes its decisions from the page it is handed — so a page handed to it
/// is one with the status bar already gone.
library;

import 'dart:math' as math;

import 'package:butlery/services/import/parsers/heading_word_lists.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// One page's text with its geometry, when the reader measured any.
class PageText {
  final String text;
  final PageLayout? layout;

  const PageText(this.text, {this.layout});

  List<String> get lines => text.split('\n');

  /// Keeps the lines at [kept], and the layout's lines at the same indices
  /// when the layout describes this text line for line. A layout that does
  /// not is dropped rather than kept out of step.
  PageText keepingLines(List<int> kept) {
    final all = lines;
    final text = [for (final i in kept) all[i]].join('\n');
    final layout = this.layout;
    if (kept.length == all.length) return PageText(text, layout: layout);
    if (layout == null || layout.lines.length != all.length) {
      return PageText(text);
    }
    return PageText(
      text,
      layout: PageLayout(
        lines: [for (final i in kept) layout.lines[i]],
        imageWidth: layout.imageWidth,
        imageHeight: layout.imageHeight,
      ),
    );
  }
}

/// The pages after overlap removal, and for each page whether its first
/// line continues the previous page mid-recipe (a proven overlap).
class ReflowedPages {
  final List<PageText> pages;
  final List<bool> continuesPrevious;

  const ReflowedPages(this.pages, this.continuesPrevious);
}

/// The document the parser reads, with one layout entry per joined page.
class PreparedDocument {
  final String text;
  final List<PageLayout?> layouts;

  const PreparedDocument(this.text, this.layouts);
}

/// Strip, de-overlap and join — the one call the viewmodel makes.
PreparedDocument prepareScreenPages(List<PageText> pages) {
  final stripped = pages.map(stripScreenChrome).toList();
  final reflowed = dropPageOverlap(stripped);
  final kept = <int>[
    for (var i = 0; i < reflowed.pages.length; i++)
      if (reflowed.pages[i].text.trim().isNotEmpty) i,
  ];
  final keptPages = [for (final i in kept) reflowed.pages[i]];
  final keptContinues = [for (final i in kept) reflowed.continuesPrevious[i]];
  final layouts = [for (final p in keptPages) p.layout];
  final layoutComplete = layouts.isNotEmpty && layouts.every((l) => l != null);
  return PreparedDocument(
    joinPages(keptPages, keptContinues, layoutComplete: layoutComplete),
    layouts,
  );
}

/// How many lines at the top of a page a status bar can occupy.
const _statusBarLines = 2;

/// How many non-empty lines at either end of a page social chrome can occupy.
const _chromeLines = 4;

/// Removes a phone screenshot's own lines: the status bar's clock and the
/// icon row beside it in the top two lines, and a social app's like row,
/// follow button, "more" toggle, post age and account name in the first and
/// last four non-empty lines. The account name alone proves
/// nothing: "salt" under a cookbook title is a bare lowercase line too, so
/// it goes only on a page that also shows a clock or social chrome.
PageText stripScreenChrome(PageText page) {
  final lines = page.lines;
  final drop = List<bool>.filled(lines.length, false);
  var screenshotEvidence = false;

  for (var i = 0; i < lines.length && i < _statusBarLines; i++) {
    if (!HeadingWordLists.isClockTime(lines[i])) continue;
    screenshotEvidence = true;
    drop[i] = true;
    for (final j in [i - 1, i + 1]) {
      if (j >= 0 &&
          j < lines.length &&
          j <= _statusBarLines &&
          isIconRow(lines[j])) {
        drop[j] = true;
      }
    }
  }

  final nonEmpty = [
    for (var i = 0; i < lines.length; i++)
      if (lines[i].trim().isNotEmpty) i,
  ];
  final edge = <int>{
    ...nonEmpty.take(_chromeLines),
    ...nonEmpty.skip(math.max(0, nonEmpty.length - _chromeLines)),
  };
  for (final i in edge) {
    if (HeadingWordLists.isSocialChrome(lines[i])) {
      screenshotEvidence = true;
      drop[i] = true;
    }
  }
  final rewritten = List<String>.of(lines);
  if (screenshotEvidence) {
    for (final i in nonEmpty.take(_chromeLines)) {
      if (HeadingWordLists.looksLikeHandle(lines[i])) {
        drop[i] = true;
      } else {
        rewritten[i] = _withoutLeadingHandle(lines[i]);
      }
    }
    // ML Kit orders blocks by position, and a status bar's icons can land
    // mid-page. Only the mixed shape ("5Gtll") counts here: a bare "2 st" is
    // an ingredient row's opening.
    for (final i in nonEmpty) {
      if (_isMidPageIconRow(lines[i])) drop[i] = true;
    }
    // A post's age closes its caption; below it the reader is already in
    // the next post, whose image text is no part of this recipe.
    final tail = nonEmpty.skip(_chromeLines);
    final age = tail.where((i) => HeadingWordLists.isPostAge(lines[i]));
    if (age.isNotEmpty) {
      for (var i = age.first; i < lines.length; i++) {
        drop[i] = true;
      }
    }
    _joinCapsTitle(rewritten, nonEmpty, drop);
    final lastKept = nonEmpty.lastWhere((i) => !drop[i], orElse: () => -1);
    if (lastKept >= 0) {
      rewritten[lastKept] = rewritten[lastKept].replaceFirst(_moreToggle, '');
    }
  }

  return PageText(rewritten.join('\n'), layout: page.layout).keepingLines([
    for (var i = 0; i < lines.length; i++)
      if (!drop[i]) i,
  ]);
}

/// A post's title set in capitals over several lines ("KRÄMIG
/// KYCKLINGGRYTA" / "MED LJUVLIGA SMAKER AV VITLÖK, DIJON &" / "PARMESAN")
/// becomes one sentence-case line. Only on a screenshot page: in a cookbook a
/// line in capitals is a section label, and the parser treats it as one.
void _joinCapsTitle(List<String> lines, List<int> nonEmpty, List<bool> drop) {
  final kept = nonEmpty.where((i) => !drop[i]).toList();
  if (kept.isEmpty || !_isCapsLine(lines[kept.first])) return;
  final first = kept.first;
  final parts = [lines[first].trim()];
  if (parts.first.split(RegExp(r'\s+')).length < 2) return;
  for (final i in kept.skip(1)) {
    final next = lines[i].trim();
    if (!_isCapsLine(next)) break;
    if (!_capsContinues.hasMatch(parts.last) &&
        !_capsOpensContinuation.hasMatch(next)) {
      break;
    }
    parts.add(next);
    drop[i] = true;
  }
  final lower = parts.join(' ').toLowerCase();
  lines[first] = lower[0].toUpperCase() + lower.substring(1);
}

bool _isCapsLine(String line) {
  final letters = line.replaceAll(RegExp(r'[^a-zåäöéA-ZÅÄÖÉ]'), '');
  return letters.length >= 2 && line == line.toUpperCase();
}

final _capsContinues = RegExp(r'[&,]$|\s(?:MED|OCH|AV|I|PÅ|TILL)$');
final _capsOpensContinuation = RegExp(r'^(?:MED|OCH|AV|I|PÅ|TILL|&)\s');

/// The caption's own "mindre" / "… mer" toggle, glued to its last line.
final _moreToggle = RegExp(r'\s+(?:mindre|(?:…|\.\.\.)\s?mer)$');

/// "matglad.anna KRÄMIG KYCKLINGGRYTA" → the caption's title: a
/// post opens with its account name on the same line, and a capital-letter
/// title after it proves the first token is not a lowercase recipe word.
String _withoutLeadingHandle(String line) {
  final m = _handleThenCaps.firstMatch(line.trim());
  if (m == null || !HeadingWordLists.looksLikeHandle(m.group(1)!)) return line;
  return m.group(2)!;
}

final _handleThenCaps = RegExp(r'^(\S+)\s+([A-ZÅÄÖÉ0-9][^a-zåäöé]*)$');

bool _isMidPageIconRow(String line) {
  if (!isIconRow(line)) return false;
  final tokens = line.trim().split(RegExp(r'\s+'));
  final glued = tokens.any((t) {
    final m = _digitsThenLetters.firstMatch(t);
    return m != null && !_units.contains(m.group(1)!.toLowerCase());
  });
  if (glued) return true;
  // The spaced spelling splits the icons into separate letter tokens; a
  // quantity row has only its lone unit letter among them.
  final strayLetters = tokens.where(
    (t) => _lettersOnly.hasMatch(t) && !_units.contains(t.toLowerCase()),
  );
  return strayLetters.length >= 2;
}

final _lettersOnly = RegExp(r'^[a-zA-ZåäöÅÄÖ]+$');

final _digitsThenLetters = RegExp(r'^\d+([a-zA-Z]{3,})$');

const _units = {'tsk', 'msk', 'krm', 'pkt', 'st', 'dl', 'cl', 'ml', 'kg'};

/// A status bar's icons as the reader spells them ("d 5 g ll 66"): letters
/// are present, but no token of two or more letters holds a vowel. "2 st ägg"
/// has "ägg"; "1 dl mjöl" has "mjöl".
bool isIconRow(String line) {
  final tokens = line.trim().split(RegExp(r'\s+'));
  var sawLetters = false;
  for (final token in tokens) {
    final letters = token.replaceAll(RegExp(r'[^a-zA-ZåäöÅÄÖ]'), '');
    if (letters.isEmpty) continue;
    sawLetters = true;
    if (letters.length >= 2 &&
        RegExp('[aeiouyåäöAEIOUYÅÄÖ]').hasMatch(letters)) {
      return false;
    }
  }
  return sawLetters;
}

/// Lines two pages must share before they count as one overlap.
const _minOverlapLines = 3;

/// Two shared lines suffice when both are this long — a sentence, not a
/// quantity row that any recipe repeats.
const _longLineChars = 40;

/// Shared lines that prove an overlap without checking the earlier page's
/// half-visible last line.
const _strongOverlapLines = 5;

/// Edit similarity two OCR readings of one line must reach.
const _minSimilarity = 0.85;

/// A page's boundary line can be half visible: this many lines at the end
/// of a page, and at the start of the next, may be skipped before the match.
const _edgeSlack = 1;

/// Drops from each page the lines it shares with the end of the page before
/// it, when the two overlap the way two screenshots of one scrolled post do:
/// the earlier page's last lines ARE the later page's first lines. A line
/// repeated somewhere else ("1 dl socker" under two headings) is not an
/// overlap.
ReflowedPages dropPageOverlap(List<PageText> pages) {
  if (pages.isEmpty) return const ReflowedPages([], []);
  final out = <PageText>[pages.first];
  final continues = <bool>[false];
  for (var p = 1; p < pages.length; p++) {
    final previous = out.last;
    final match = _findOverlap(previous, pages[p]);
    if (match == null) {
      out.add(pages[p]);
      continues.add(false);
      continue;
    }
    out[out.length - 1] = previous.keepingLines(match.keepInPrevious);
    out.add(pages[p].keepingLines(match.keepInNext));
    continues.add(true);
  }
  return ReflowedPages(out, continues);
}

class _Overlap {
  final List<int> keepInPrevious;
  final List<int> keepInNext;
  const _Overlap(this.keepInPrevious, this.keepInNext);
}

_Overlap? _findOverlap(PageText previous, PageText next) {
  final prevLines = previous.lines;
  final nextLines = next.lines;
  final prevIdx = _nonEmptyIndices(prevLines);
  final nextIdx = _nonEmptyIndices(nextLines);
  final prevKeys = [for (final i in prevIdx) _key(prevLines[i])];
  final nextKeys = [for (final i in nextIdx) _key(nextLines[i])];

  for (var skipPrev = 0; skipPrev <= _edgeSlack; skipPrev++) {
    for (var skipNext = 0; skipNext <= _edgeSlack; skipNext++) {
      final tailEnd = prevKeys.length - skipPrev;
      final maxRun = math.min(tailEnd, nextKeys.length - skipNext);
      // Longest edge-anchored run: previous[tailEnd - run .. tailEnd) matches
      // next[skipNext .. skipNext + run).
      for (var run = maxRun; run >= 2; run--) {
        var all = true;
        var allLong = true;
        for (var k = 0; k < run && all; k++) {
          final a = prevKeys[tailEnd - run + k];
          final b = nextKeys[skipNext + k];
          all = _similar(a, b);
          allLong &= a.length >= _longLineChars && b.length >= _longLineChars;
        }
        if (!all) continue;
        if (run < _minOverlapLines && !allLong) continue;
        // A skipped edge line must be the cut half of the line it stands in
        // for on the other page, or it is a line of its own — a title above
        // the shared lines — and this is not that overlap.
        // A long shared run proves the overlap on its own, and the cut line
        // at a screenshot's bottom edge can read as noise no fragment test
        // recognises ("2 DIondoi oramo frairha" for "3. Blanda i crème").
        if (skipPrev > 0 &&
            run < _strongOverlapLines &&
            !_isFragmentOf(
              prevKeys[tailEnd],
              skipNext + run < nextKeys.length ? nextKeys[skipNext + run] : '',
            )) {
          continue;
        }
        if (skipNext > 0 &&
            !_isFragmentOf(
              nextKeys[skipNext - 1],
              tailEnd - run > 0 ? prevKeys[tailEnd - run - 1] : '',
            )) {
          continue;
        }
        // The shared lines stay on the earlier page; the later page loses
        // them, and each page loses its half-visible edge line.
        final dropPrev = prevIdx.skip(tailEnd).toSet();
        final dropNext = nextIdx.take(skipNext + run).toSet();
        return _Overlap(
          [
            for (var i = 0; i < prevLines.length; i++)
              if (!dropPrev.contains(i)) i,
          ],
          [
            for (var i = 0; i < nextLines.length; i++)
              if (!dropNext.contains(i)) i,
          ],
        );
      }
    }
  }
  return null;
}

List<int> _nonEmptyIndices(List<String> lines) => [
  for (var i = 0; i < lines.length; i++)
    if (lines[i].trim().isNotEmpty) i,
];

String _key(String line) =>
    line.toLowerCase().replaceAll(RegExp(r'[^a-z0-9åäöé]+'), ' ').trim();

/// A half-visible line reads as the start or the end of its whole, or as
/// an OCR variant of it.
bool _isFragmentOf(String part, String whole) =>
    part.isNotEmpty &&
    whole.isNotEmpty &&
    (whole.startsWith(part) || whole.endsWith(part) || _similar(part, whole));

bool _similar(String a, String b) {
  if (a == b) return true;
  if (a.isEmpty || b.isEmpty) return false;
  final longest = math.max(a.length, b.length);
  return 1 - _editDistance(a, b) / longest >= _minSimilarity;
}

int _editDistance(String a, String b) {
  var prev = List<int>.generate(b.length + 1, (j) => j);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Joins pages with a blank line, as the splitter expects at a page
/// boundary — except where a page is a proven continuation of the one
/// before and no geometry is in play, where a single newline keeps a step
/// cut by the screenshot edge on one line pair for the line reflow. With a
/// complete layout the blank line stays, because `DocumentLayout` joins its
/// pages the same way and the two must agree row for row.
String joinPages(
  List<PageText> pages,
  List<bool> continuesPrevious, {
  required bool layoutComplete,
}) {
  final buffer = StringBuffer();
  for (var i = 0; i < pages.length; i++) {
    if (i > 0) {
      buffer.write(continuesPrevious[i] && !layoutComplete ? '\n' : '\n\n');
    }
    buffer.write(pages[i].text);
  }
  return buffer.toString();
}
