// P8-U05: the design migration census, generated from the code.
//
// Reads lib/, pubspec.yaml, the ratchet and adoption lists in
// test/architecture (by name, as text), and the package 8 fixtures and
// known-finding lists, and writes one report as JSON and Markdown. Nothing
// here is typed by hand: every number is counted from a file in this repo.
//
//   dart run tools/design_migration_census.dart [--out=<dir>] [--format=both|json|md]
//
// Default out dir: build/design-migration-census. The output is
// deterministic (sorted keys and lists, no clock), so two runs on the same
// tree are byte-identical.
//
// Robust to a moving tree:
// - a ratchet or adoption list that package 7 emptied and deleted is
//   reported RETIRED with 0 entries, never an error;
// - a fixture or findings file that is not there is reported NOT_PRESENT.
//
// Decision Q8-01 = A (Butlery design system fas2/produktbeslut-2026-09-27c.json:17-19):
// package 8 is done when the tests are green and every known failure has a
// ticket; the migration is complete only when the known-failure list is
// empty. The verdict section says which of these holds.

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// Inputs

/// Where the census reads. [overrides] replaces a file's content by its
/// repo-relative path, and a null value makes the file absent; tests use it
/// to simulate a tree without running on a copy.
class CensusSource {
  CensusSource(this.root, {this.overrides = const {}});

  final String root;
  final Map<String, String?> overrides;

  bool exists(String path) {
    if (overrides.containsKey(path)) return overrides[path] != null;
    return File('$root/$path').existsSync();
  }

  String? read(String path) {
    if (overrides.containsKey(path)) return overrides[path];
    final f = File('$root/$path');
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  /// Every Dart file under lib/, generated localisations excepted, as
  /// sorted repo-relative paths.
  List<String> libDartFiles() {
    final dir = Directory('$root/lib');
    if (!dir.existsSync()) return const [];
    final prefix = dir.parent.path.replaceAll(r'\', '/');
    return [
      for (final e in dir.listSync(recursive: true, followLinks: false))
        if (e is File && e.path.endsWith('.dart'))
          e.path.replaceAll(r'\', '/').substring(prefix.length + 1),
    ].where((p) => !p.startsWith('lib/l10n/')).toList()..sort();
  }
}

const present = 'PRESENT';
const notPresent = 'NOT_PRESENT';
const live = 'LIVE';
const retired = 'RETIRED';
const unparsed = 'UNPARSED';

const _transitionFixture = 'test/fixtures/design/transition_census.json';
const _transitionSource = 'test/fixtures/design/block288-overgangar.json';
const _statesFixture = 'test/fixtures/design/ux-beteende-53.json';
const _stateFindings = 'test/views/design_states/known_state_findings.dart';
const _a11yFindings = 'test/views/design_states/known_a11y_findings.dart';
const _interactionFixture = 'test/widget/design_states/interaction_census.json';
const _interactionFindings =
    'test/widget/design_states/known_interaction_findings.dart';
const _contrastFixture = 'test/fixtures/design/contrast_pairs.json';
const _contrastTest = 'test/unit/theme/contrast_pairs_test.dart';
const _tokenFixture = 'test/fixtures/design/tokens-semantic.json';
const _tokenTest = 'test/unit/theme/token_parity_test.dart';
const _iconCensus = 'test/architecture/icon_census_test.dart';

/// A named list in a test/architecture file.
class RatchetSpec {
  const RatchetSpec(this.file, this.name, this.role, this.note);

  final String file;
  final String name;

  /// RESIDUE: legacy the list only lets shrink; ALLOWANCE: accepted by
  /// design; ADOPTION: files that adopted a primitive; BAN: retired names
  /// that may not come back.
  final String role;
  final String note;
}

const ratchetSpecs = <RatchetSpec>[
  RatchetSpec(
    'test/architecture/error_contract_test.dart',
    '_legacyErrorCalls',
    'RESIDUE',
    'one-line error calls per file (package 5), removed in package 7',
  ),
  RatchetSpec(
    'test/architecture/error_contract_test.dart',
    '_errorPrefixLiterals',
    'RESIDUE',
    'hard-coded errorPrefix strings, moved to l10n in package 7',
  ),
  RatchetSpec(
    'test/architecture/error_contract_test.dart',
    '_privateInlineErrors',
    'ALLOWANCE',
    'private inline-error copies the contract accepts',
  ),
  RatchetSpec(
    'test/architecture/views_dark_mode_colour_test.dart',
    '_widgetSnackBarsOwnedByT7',
    'RESIDUE',
    'widget snackbars left to track T7',
  ),
  RatchetSpec(
    'test/architecture/views_dark_mode_colour_test.dart',
    '_inkOnPaperSites',
    'ALLOWANCE',
    'ink kept as foreground on a plate that is paper in both modes',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_plateLineFiles',
    'ADOPTION',
    'views that load with PlateLine',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_scaffoldFiles',
    'ADOPTION',
    'views on the shared scaffold',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_package7Components',
    'ALLOWANCE',
    'files allowed to build on a Material progress indicator',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_spinnerResidue',
    'RESIDUE',
    'spinner call sites left to package 7',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_barResidue',
    'RESIDUE',
    'old top bars left to package 7',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_exclusiveHeroFiles',
    'ALLOWANCE',
    'two hero styles in branches that never show together',
  ),
  RatchetSpec(
    'test/architecture/package4_adoption_test.dart',
    '_snackBarResidue',
    'RESIDUE',
    'coloured snackbars left to package 7',
  ),
  RatchetSpec(
    'test/architecture/package4_t3_adoption_test.dart',
    '_plateLineFiles',
    'ADOPTION',
    'package 4 track 3 views on PlateLine',
  ),
  RatchetSpec(
    'test/architecture/package4_t3_adoption_test.dart',
    '_topBarFiles',
    'ADOPTION',
    'package 4 track 3 views on ButleryTopBar',
  ),
  RatchetSpec(
    'test/architecture/package4_t3_adoption_test.dart',
    '_inkSnackbarFiles',
    'ADOPTION',
    'package 4 track 3 views on the ink snackbar',
  ),
  RatchetSpec(
    'test/architecture/package4_social_account_adoption_test.dart',
    '_files',
    'ADOPTION',
    'social and account views on the design-system primitives',
  ),
  RatchetSpec(
    'test/architecture/p4_recipe_views_loading_test.dart',
    '_files',
    'ADOPTION',
    'recipe views on the shared loading state',
  ),
  RatchetSpec(
    'test/architecture/p4_recipe_views_loading_test.dart',
    '_forbidden',
    'BAN',
    'loading patterns the recipe views may not use',
  ),
  RatchetSpec(
    'test/architecture/icon_census_test.dart',
    '_residue',
    'RESIDUE',
    'Material icon uses with no Butlery glyph yet (file, icon, uses)',
  ),
  RatchetSpec(
    'test/architecture/icon_census_test.dart',
    '_deletedByClosingTrack',
    'RESIDUE',
    'files the package 7 closing track deletes',
  ),
  RatchetSpec(
    'test/architecture/icon_census_test.dart',
    '_plainIconAllowed',
    'ALLOWANCE',
    'files allowed to build a plain Icon',
  ),
  RatchetSpec(
    'test/architecture/p7_type_and_space_scale_test.dart',
    '_rawFontSizeAllowlist',
    'RESIDUE',
    'raw font sizes, each a known gap with a follow-up (file, count)',
  ),
  RatchetSpec(
    'test/architecture/p7_type_and_space_scale_test.dart',
    '_retiredSpacing',
    'BAN',
    'AppDimensions members retired in package 7',
  ),
  RatchetSpec(
    'test/architecture/legacy_retirement_test.dart',
    '_retired',
    'BAN',
    'legacy names package 7 retired',
  ),
  RatchetSpec(
    'test/architecture/opacity_ladder_ratchet_test.dart',
    '_residue',
    'RESIDUE',
    'AppDimensions.opacity* uses left to migrate to the B83 token mapping '
        '(BUT-2183, file, uses)',
  ),
];

/// A symbol counted in lib/ code (comments excluded).
class SymbolSpec {
  const SymbolSpec(this.label, this.pattern, this.note, {this.skip});

  final String label;
  final String pattern;
  final String note;

  /// Files not counted, by path prefix.
  final String? skip;
}

const symbolSpecs = <SymbolSpec>[
  SymbolSpec(
    'class ButleryColors',
    r'\bclass\s+ButleryColors\b',
    'the compatibility class; the design-system generator emits one of the same name in lib/theme/butlery_tokens.dart',
  ),
  SymbolSpec(
    'context.butleryColors',
    r'\bcontext\s*\.\s*butleryColors\b',
    'retired for context.modeColors (legacy_retirement_test)',
  ),
  SymbolSpec(
    'AppSpecificColors',
    r'\bAppSpecificColors\b',
    'app-specific decoration colours (lib/theme/app_specific_colors.dart)',
  ),
  SymbolSpec(
    'SeasonalAccent*',
    r'SeasonalAccent',
    'retired seasonal tint (Q7-01 = A)',
  ),
  SymbolSpec('CupertinoColors', r'\bCupertinoColors\b', 'Cupertino palette'),
  SymbolSpec(
    'Icons.<name>',
    r'(?<![\w.$])Icons\.\w+',
    'Material icons; the residue is listed in icon_census_test',
  ),
  SymbolSpec(
    'CupertinoIcons.<name>',
    r'\bCupertinoIcons\.\w+',
    'banned by icon_census_test',
  ),
  SymbolSpec(
    'AdaptiveAppBar(',
    r'\bAdaptiveAppBar\s*\(',
    'retired for ButleryTopBar (B-45)',
  ),
  SymbolSpec(
    'CircularProgressIndicator(',
    r'\bCircularProgressIndicator\s*\(',
    'Material spinner; PlateLine is the only loading indicator (B-18)',
  ),
  SymbolSpec(
    'LinearProgressIndicator(',
    r'\bLinearProgressIndicator\s*\(',
    'PlateLine draws on it (package4_adoption_test _package7Components)',
  ),
  SymbolSpec(
    'commonOk',
    r'\bcommonOk\b',
    '"OK" as a label (content-style-guide.md:77)',
  ),
  SymbolSpec(
    'fontSize: <number>',
    r'fontSize:\s*[0-9]',
    'raw font sizes; allowance in p7_type_and_space_scale_test',
  ),
  SymbolSpec(
    'Color(0x…) outside lib/theme',
    r'\bColor\(\s*0x',
    'literal colours outside the theme files',
    skip: 'lib/theme/',
  ),
  SymbolSpec(
    'BorderRadius.circular(<number>)',
    r'BorderRadius\.circular\(\s*[0-9]',
    'raw corner radii',
  ),
  SymbolSpec(
    'AppDimensions.opacity*',
    r'\bAppDimensions\.opacity\w+',
    'the old opacity steps (BUT-2183); residue in opacity_ladder_ratchet_test',
    skip: 'lib/theme/app_dimensions.dart',
  ),
  SymbolSpec(
    'spacingS / spacingXxs',
    r'\bspacing(?:S|Xxs)\b',
    'spacing members retired in package 7',
  ),
];

const _fontFamilies = ['JosefinSans', 'SpaceGrotesk'];

// ---------------------------------------------------------------------------
// A small scanner for Dart source: finds a top-level declaration by name and
// reads its collection literal, strings and comments respected.

class _Scan {
  _Scan(this.src) {
    final m = StringBuffer();
    var i = 0;
    while (i < src.length) {
      final c = src[i];
      if (src.startsWith('//', i)) {
        final end = src.indexOf('\n', i);
        final stop = end < 0 ? src.length : end;
        m.write(' ' * (stop - i));
        i = stop;
        continue;
      }
      if (src.startsWith('/*', i)) {
        final end = src.indexOf('*/', i + 2);
        final stop = end < 0 ? src.length : end + 2;
        m.write(src.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ' '));
        i = stop;
        continue;
      }
      final raw = c == 'r' && i + 1 < src.length && _isQuote(src[i + 1]);
      if (_isQuote(c) || raw) {
        final start = i;
        var j = raw ? i + 1 : i;
        final q = src[j];
        final triple = src.startsWith(q * 3, j);
        final close = triple ? q * 3 : q;
        j += close.length;
        final bodyStart = j;
        while (j < src.length && !src.startsWith(close, j)) {
          if (!raw && src[j] == r'\') j++;
          j++;
        }
        final bodyEnd = j;
        j = (j + close.length).clamp(0, src.length);
        strings.add(
          _Str(start, j, _unescape(src.substring(bodyStart, bodyEnd), raw)),
        );
        m
          ..write(src.substring(start, bodyStart))
          ..write(
            src.substring(bodyStart, bodyEnd).replaceAll(RegExp(r'[^\n]'), 'x'),
          )
          ..write(src.substring(bodyEnd, j));
        i = j;
        continue;
      }
      m.write(c);
      i++;
    }
    masked = m.toString();
  }

  final String src;
  late final String masked;
  final strings = <_Str>[];

  static bool _isQuote(String c) => c == "'" || c == '"';

  static String _unescape(String s, bool raw) {
    if (raw) return s;
    return s.replaceAllMapped(RegExp(r'\\(.)'), (m) {
      switch (m.group(1)) {
        case 'n':
          return '\n';
        case 't':
          return '\t';
        default:
          return m.group(1)!;
      }
    });
  }

  /// The strings wholly inside [start, end), concatenated (adjacent string
  /// literals are one string in Dart).
  String? stringIn(int start, int end) {
    final parts = [
      for (final s in strings)
        if (s.start >= start && s.end <= end) s.value,
    ];
    return parts.isEmpty ? null : parts.join();
  }

  List<String> stringsIn(int start, int end) => [
    for (final s in strings)
      if (s.start >= start && s.end <= end) s.value,
  ];

  /// The span of the value of top-level declaration [name]: from after `=`
  /// to the `;` that ends it. Null when there is no such declaration.
  (int, int)? valueOf(String name) {
    final decl = RegExp(
      r'^[ \t]*(?:static\s+)?(?:const|final|var)\s+(?:[\w<>,?\s]+?\s+)?' +
          RegExp.escape(name) +
          r'\s*=',
      multiLine: true,
    ).firstMatch(masked);
    if (decl == null) return null;
    var depth = 0;
    for (var i = decl.end; i < masked.length; i++) {
      final c = masked[i];
      if ('([{'.contains(c)) depth++;
      if (')]}'.contains(c)) depth--;
      if (c == ';' && depth == 0) return (decl.end, i);
    }
    return null;
  }

  int _close(int open) {
    var depth = 0;
    for (var i = open; i < masked.length; i++) {
      final c = masked[i];
      if ('([{'.contains(c)) depth++;
      if (')]}'.contains(c)) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return masked.length;
  }

  /// The collection literal starting the span [start, end): `const`,
  /// type arguments and whitespace skipped. Null when the value is not a
  /// list, set or map literal.
  (int, int)? collectionIn(int start, int end) {
    var i = start;
    while (i < end) {
      final rest = masked.substring(i, end);
      final ws = RegExp(r'^\s+').firstMatch(rest);
      if (ws != null) {
        i += ws.end;
        continue;
      }
      if (rest.startsWith('const')) {
        i += 5;
        continue;
      }
      if (rest.startsWith('<')) {
        var depth = 0;
        for (; i < end; i++) {
          if (masked[i] == '<') depth++;
          if (masked[i] == '>') {
            depth--;
            if (depth == 0) {
              i++;
              break;
            }
          }
        }
        continue;
      }
      if (rest.startsWith('{') || rest.startsWith('[')) {
        return (i, _close(i));
      }
      return null;
    }
    return null;
  }

  /// The top-level entries between [open] and its closing bracket, as spans.
  List<(int, int)> entries(int open, int close) {
    final out = <(int, int)>[];
    var depth = 0;
    var from = open + 1;
    for (var i = open + 1; i < close; i++) {
      final c = masked[i];
      if ('([{'.contains(c)) depth++;
      if (')]}'.contains(c)) depth--;
      if (c == ',' && depth == 0) {
        out.add((from, i));
        from = i + 1;
      }
    }
    out.add((from, close));
    return [
      for (final e in out)
        if (masked.substring(e.$1, e.$2).trim().isNotEmpty) e,
    ];
  }

  /// The index of a top-level `:` in the span, or -1.
  int colon(int start, int end) {
    var depth = 0;
    for (var i = start; i < end; i++) {
      final c = masked[i];
      if ('([{'.contains(c)) depth++;
      if (')]}'.contains(c)) depth--;
      if (c == ':' && depth == 0) return i;
    }
    return -1;
  }

  String code(int start, int end) => masked.substring(start, end).trim();
}

class _Str {
  _Str(this.start, this.end, this.value);
  final int start;
  final int end;
  final String value;
}

/// One entry of a parsed collection: its key (a string literal, when it has
/// one), its weight and the strings of its value.
class _Entry {
  _Entry(this.key, this.weight, this.values, this.valueCode);
  final String key;
  final int weight;
  final List<String> values;
  final String valueCode;
}

/// Reads collection [name] in [source]: null when absent, an empty list with
/// [ok] false when present but not a collection literal.
({bool found, bool ok, List<_Entry> entries}) _collection(
  String? source,
  String name,
) {
  if (source == null) return (found: false, ok: false, entries: const []);
  final s = _Scan(source);
  final span = s.valueOf(name);
  if (span == null) return (found: false, ok: false, entries: const []);
  final coll = s.collectionIn(span.$1, span.$2);
  if (coll == null) return (found: true, ok: false, entries: const []);
  return (found: true, ok: true, entries: _entriesOf(s, coll.$1, coll.$2));
}

List<_Entry> _entriesOf(_Scan s, int open, int close) {
  final out = <_Entry>[];
  for (final (a, b) in s.entries(open, close)) {
    final code = s.code(a, b);
    if (code.startsWith('...')) {
      // A spread of another list in the same file weighs what that list
      // holds.
      final span = s.valueOf(code.substring(3).trim());
      final coll = span == null ? null : s.collectionIn(span.$1, span.$2);
      final inner = coll == null
          ? const <_Entry>[]
          : _entriesOf(s, coll.$1, coll.$2);
      out.add(
        _Entry(code, inner.fold(0, (t, e) => t + e.weight), const [], code),
      );
      continue;
    }
    final colon = s.colon(a, b);
    if (colon < 0) {
      final key = s.stringIn(a, b) ?? code;
      out.add(_Entry(key, 1, [key], code));
      continue;
    }
    final key = s.stringIn(a, colon) ?? s.code(a, colon);
    final valueCode = s.code(colon + 1, b);
    var weight = 1;
    if (RegExp(r'^\d+$').hasMatch(valueCode)) {
      weight = int.parse(valueCode);
    } else {
      final nested = s.collectionIn(colon + 1, b);
      if (nested != null && s.masked[nested.$1] == '{') {
        final inner = _entriesOf(s, nested.$1, nested.$2);
        weight = inner.fold(0, (t, e) => t + e.weight);
      }
    }
    out.add(_Entry(key, weight, s.stringsIn(colon + 1, b), valueCode));
  }
  return out;
}

/// Collection [name] in Dart [source] as entry -> weight (a count value,
/// the sum of a nested map's counts, a spread's list total, otherwise 1);
/// null when [name] is not declared.
Map<String, int>? readDartCollection(String source, String name) {
  final c = _collection(source, name);
  if (!c.found) return null;
  return {for (final e in c.entries) e.key: e.weight};
}

int? _intConst(String? source, String name) {
  if (source == null) return null;
  final m = RegExp(
    r'^\s*const\s+(?:int\s+)?' + RegExp.escape(name) + r'\s*=\s*(\d+)\s*;',
    multiLine: true,
  ).firstMatch(_Scan(source).masked);
  return m == null ? null : int.parse(m.group(1)!);
}

/// The `ticket:` of the constructor call assigned to [name].
String? _namedTicket(String source, String name) {
  final s = _Scan(source);
  final span = s.valueOf(name);
  if (span == null) return null;
  final t = RegExp(r'\bticket\s*:').firstMatch(s.masked.substring(span.$1));
  if (t == null || span.$1 + t.end > span.$2) return null;
  final from = span.$1 + t.end;
  for (final str in s.strings) {
    if (str.start >= from && str.end <= span.$2) return str.value;
  }
  return null;
}

Map<String, dynamic>? _json(CensusSource src, String path) {
  final text = src.read(path);
  return text == null ? null : jsonDecode(text) as Map<String, dynamic>;
}

Map<String, int> _countBy(Iterable<String> values) {
  final out = <String, int>{};
  for (final v in values) {
    out[v] = (out[v] ?? 0) + 1;
  }
  return out;
}

/// A registered Linear issue. Anything else (a proposed id, a free-text
/// note) counts as no ticket.
final _ticketPattern = RegExp(r'^BUT-\d+$');

/// A known failure, for the ticket index.
class _Finding {
  _Finding(this.list, this.id, this.ticket);
  final String list;
  final String id;
  final String? ticket;
}

// ---------------------------------------------------------------------------
// Sections

Map<String, Object?> _transitions(CensusSource src, List<_Finding> out) {
  final census = _json(src, _transitionFixture);
  if (census == null) return {'status': notPresent, 'file': _transitionFixture};
  final source = _json(src, _transitionSource);
  final entries = (census['entries'] as List).cast<Map<String, dynamic>>();
  final notDone = <Map<String, Object?>>[];
  for (final e in entries) {
    final status = e['status'] as String;
    if (status == 'TESTED') continue;
    final gap = e['known_gap'] as Map<String, dynamic>?;
    final ticket = (e['ticket'] ?? gap?['ticket']) as String?;
    notDone.add({'id': e['id'], 'status': status, 'ticket': ticket});
    out.add(_Finding('transitions', e['id'] as String, ticket));
  }
  notDone.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  return {
    'status': present,
    'file': _transitionFixture,
    'required': entries.length,
    'required_in_block288': source?['TRANSITIONS_REQUIRED'],
    'by_status': _countBy(entries.map((e) => e['status'] as String)),
    'not_done': notDone,
  };
}

Map<String, Object?> _states(CensusSource src, List<_Finding> out) {
  final fixture = _json(src, _statesFixture);
  if (fixture == null) return {'status': notPresent, 'file': _statesFixture};
  final rows = (fixture['rows'] as List).cast<Map<String, dynamic>>();
  final findings = _collection(src.read(_stateFindings), 'knownStateFindings');
  final registered = _collection(
    src.read(_stateFindings),
    'registeredTickets',
  );
  final byCase = <String, List<_Entry>>{};
  for (final f in findings.entries) {
    final parts = f.key.split('::');
    final caseId = parts.take(3).join('::');
    byCase.putIfAbsent(caseId, () => []).add(f);
    out.add(
      _Finding('states53', f.key, f.values.isEmpty ? null : f.values.first),
    );
  }
  var casesPass = 0;
  var statesPass = 0;
  final failing = <String>[];
  for (final r in rows) {
    final state = '${r['VY']}::${r['TILLSTAND']}';
    var both = true;
    for (final mode in ['light', 'dark']) {
      if (byCase.containsKey('$state::$mode')) {
        both = false;
      } else {
        casesPass++;
      }
    }
    if (both) {
      statesPass++;
    } else {
      failing.add(state);
    }
  }
  final unmatched =
      byCase.keys
          .where(
            (c) => !rows.any(
              (r) => c.startsWith('${r['VY']}::${r['TILLSTAND']}::'),
            ),
          )
          .toList()
        ..sort();
  failing.sort();
  return {
    'status': present,
    'file': _statesFixture,
    'findings_file': findings.found ? _stateFindings : notPresent,
    'states': rows.length,
    'by_state': _countBy(rows.map((r) => r['TILLSTAND'] as String)),
    'cases': rows.length * 2,
    'cases_pass': casesPass,
    'cases_known_finding': rows.length * 2 - casesPass,
    'states_pass_both_modes': statesPass,
    'states_with_known_finding': failing,
    'known_findings': findings.entries.length,
    'known_findings_ceiling': _intConst(
      src.read(_stateFindings),
      'knownStateFindingsCeiling',
    ),
    'known_findings_by_code': _countBy(
      findings.entries.map((f) => f.key.split('::').last),
    ),
    'findings_not_matching_a_state': unmatched,
    'registered_ticket_titles': registered.entries.length,
  };
}

Map<String, Object?> _interactions(CensusSource src, List<_Finding> out) {
  final census = _json(src, _interactionFixture);
  if (census == null) {
    return {'status': notPresent, 'file': _interactionFixture};
  }
  final entries = (census['entries'] as List).cast<Map<String, dynamic>>();
  final notDone = <Map<String, Object?>>[];
  for (final e in entries) {
    if (e['status'] == 'TESTED') continue;
    // A PARTIAL row carries its ticket as known_finding.
    final ticket = (e['ticket'] ?? e['known_finding']) as String?;
    notDone.add({'id': e['row_id'], 'status': e['status'], 'ticket': ticket});
    out.add(_Finding('interactions', e['row_id'] as String, ticket));
  }
  notDone.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  final findingsSource = src.read(_interactionFindings);
  final findings = _collection(findingsSource, 'knownInteractionFindings');
  final checks = <String, String?>{};
  for (final f in findings.entries) {
    final ticket = f.values.isNotEmpty
        ? f.values.first
        : _namedTicket(findingsSource!, f.valueCode);
    checks[f.key] = ticket;
    out.add(_Finding('interaction_checks', f.key, ticket));
  }
  return {
    'status': present,
    'file': _interactionFixture,
    'required': entries.length,
    'by_status': _countBy(entries.map((e) => e['status'] as String)),
    'unspecified': (census['unspecified'] as List?)?.length ?? 0,
    'not_required': (census['not_required'] as List?)?.length ?? 0,
    'not_done': notDone,
    'known_check_findings': findings.entries.length,
  };
}

Map<String, Object?> _contrast(CensusSource src, List<_Finding> out) {
  final fixture = _json(src, _contrastFixture);
  if (fixture == null) return {'status': notPresent, 'file': _contrastFixture};
  final pairs = (fixture['contrastPairs'] as List).length;
  final gaps = _collection(src.read(_contrastTest), 'knownContrastGaps');
  final list = [
    for (final g in gaps.entries)
      {'pair': g.key, 'ticket': g.values.isEmpty ? null : g.values.first},
  ]..sort((a, b) => a['pair']!.compareTo(b['pair']!));
  for (final g in list) {
    out.add(_Finding('contrast', g['pair']!, g['ticket']));
  }
  // Measured pairs under their floor in at least one mode, each with its
  // ticket; the contrast test keeps this list honest (shrink-only).
  final failing = _collection(src.read(_contrastTest), 'knownContrastFailures');
  final under = [
    for (final g in failing.entries)
      {'pair': g.key, 'ticket': g.values.isEmpty ? null : g.values.first},
  ]..sort((a, b) => a['pair']!.compareTo(b['pair']!));
  for (final g in under) {
    out.add(_Finding('contrast', g['pair']!, g['ticket']));
  }
  return {
    'status': present,
    'file': _contrastFixture,
    'tokens_sha256': (fixture['source'] as Map)['sha256'],
    'pairs': pairs,
    'measured_in_both_modes': pairs - list.length,
    'unmeasurable': list,
    'under_floor': under,
    'rule':
        'a measured pair meets its floor in light and dark whenever '
        'test/unit/theme/contrast_pairs_test.dart is green, except the '
        'pairs listed under their floor',
  };
}

Map<String, Object?> _a11y(CensusSource src, List<_Finding> out) {
  final source = src.read(_a11yFindings);
  final shared = _collection(source, 'knownA11yFindings');
  if (!shared.found) return {'status': notPresent, 'file': _a11yFindings};
  // Text contrast read from rendered pixels can depend on the host's glyph
  // rasteriser; those findings are listed per host and count here once each.
  final hostBound = {
    for (final host in ['Linux', 'Windows'])
      host: _collection(source, 'knownA11yFindings${host}Only').entries,
  };
  final findings = [
    ...shared.entries,
    for (final e in hostBound.values) ...e,
  ];
  for (final f in findings) {
    out.add(_Finding('a11y', f.key, f.values.isEmpty ? null : f.values.first));
  }
  final cases = {
    for (final f in findings) f.key.split('::').take(5).join('::'),
  };
  return {
    'status': present,
    'file': _a11yFindings,
    'known_findings': findings.length,
    'known_findings_ceiling': _intConst(source, 'knownA11yFindingsCeiling'),
    'host_bound': {
      for (final e in hostBound.entries) e.key.toLowerCase(): e.value.length,
    },
    'cases_with_known_finding': cases.length,
    'by_code': _countBy(findings.map((f) => f.key.split('::').last)),
    'by_view': _countBy(findings.map((f) => f.key.split('::').first)),
  };
}

Map<String, Object?> _tokens(CensusSource src, List<_Finding> out) {
  final fixture = _json(src, _tokenFixture);
  if (fixture == null) return {'status': notPresent, 'file': _tokenFixture};
  final semantic = fixture['semantic'] as Map<String, dynamic>;
  final ladder = [
    for (final steps in (fixture['opacityLadder'] as Map).values)
      for (final s in steps as List) (s as num).toDouble(),
  ];
  final onLadder = <String>[];
  final offLadder = <String>[];
  for (final e in semantic.entries) {
    for (final mode in ['light', 'dark']) {
      final v = (e.value as Map)[mode] as String;
      final a = RegExp(r',\s*([\d.]+)\s*\)$').firstMatch(v)?.group(1);
      if (a == null) continue;
      (ladder.contains(double.parse(a)) ? onLadder : offLadder).add(
        '${e.key} $mode $a',
      );
    }
  }
  final gaps = _collection(src.read(_tokenTest), 'semanticKeysWithoutMember');
  final list = [
    for (final g in gaps.entries)
      {'key': g.key, 'ticket': g.values.isEmpty ? null : g.values.first},
  ]..sort((a, b) => a['key']!.compareTo(b['key']!));
  for (final g in list) {
    out.add(_Finding('tokens', g['key']!, g['ticket']));
  }
  final header = RegExp(
    r'^// system [\d.]+ · tokens ([\d.]+)$',
    multiLine: true,
  );
  return {
    'status': present,
    'file': _tokenFixture,
    'parity_test': gaps.found ? _tokenTest : notPresent,
    'tokens_version': fixture['version'],
    'tokens_sha256': (fixture['source'] as Map)['sha256'],
    'generated_light_tokens_version': header
        .firstMatch(src.read('lib/theme/app_colors.dart') ?? '')
        ?.group(1),
    'generated_dark_tokens_version': header
        .firstMatch(src.read('lib/theme/app_colors_dark.dart') ?? '')
        ?.group(1),
    'semantic_keys': semantic.length,
    'semantic_keys_with_member': semantic.length - list.length,
    'semantic_keys_without_member': list,
    'translucent_values_on_ladder': (onLadder..sort()),
    'translucent_values_off_ladder': (offLadder..sort()),
  };
}

Map<String, Object?> _icons(CensusSource src, Map<String, int> liveIcons) {
  final residue = _collection(src.read(_iconCensus), '_residue');
  if (!residue.found) return {'status': retired, 'file': _iconCensus};
  final names = <String>{};
  final s = _Scan(src.read(_iconCensus)!);
  final span = s.valueOf('_residue')!;
  final coll = s.collectionIn(span.$1, span.$2)!;
  for (final (a, b) in s.entries(coll.$1, coll.$2)) {
    final colon = s.colon(a, b);
    final file = s.stringIn(a, colon);
    if (file == null || !src.exists(file)) continue;
    final inner = s.collectionIn(colon + 1, b);
    if (inner == null) continue;
    for (final e in _entriesOf(s, inner.$1, inner.$2)) {
      names.add(e.key);
    }
  }
  final liveRows = residue.entries.where((e) => src.exists(e.key)).toList();
  return {
    'status': present,
    'file': _iconCensus,
    'residue_files': liveRows.length,
    'residue_uses': liveRows.fold<int>(0, (t, e) => t + e.weight),
    'stale_rows_for_deleted_files': [
      for (final e in residue.entries)
        if (!src.exists(e.key)) e.key,
    ]..sort(),
    'residue_icon_names': names.length,
    'material_icon_uses_in_lib': liveIcons.values.fold<int>(0, (t, v) => t + v),
  };
}

List<Map<String, Object?>> _ratchets(CensusSource src) {
  final out = <Map<String, Object?>>[];
  for (final spec in ratchetSpecs) {
    final c = _collection(src.read(spec.file), spec.name);
    final status = !c.found
        ? retired
        : c.ok
        ? live
        : unparsed;
    final entries = [
      for (final e in c.entries)
        {
          'entry': e.key,
          'weight': e.weight,
          // An entry naming a lib file that is gone no longer counts.
          'stale': e.key.startsWith('lib/') && !src.exists(e.key),
        },
    ]..sort((a, b) => (a['entry'] as String).compareTo(b['entry'] as String));
    out.add({
      'file': spec.file,
      'name': spec.name,
      'role': spec.role,
      'note': spec.note,
      'status': status,
      'entries': entries,
      'total': c.entries.fold<int>(0, (t, e) => t + e.weight),
      'live_total': entries
          .where((e) => e['stale'] != true)
          .fold<int>(0, (t, e) => t + (e['weight']! as int)),
      'stale_entries': [
        for (final e in entries)
          if (e['stale'] == true) e['entry'],
      ],
    });
  }
  return out;
}

Map<String, Object?> _symbols(CensusSource src, Map<String, int> liveIcons) {
  final files = src.libDartFiles();
  // Symbols are matched on code with strings kept and comments removed.
  final withStrings = {for (final f in files) f: stripComments(src.read(f))};
  final out = <String, Object?>{};
  for (final spec in symbolSpecs) {
    final re = RegExp(spec.pattern);
    final perFile = <String, int>{};
    for (final f in files) {
      if (spec.skip != null && f.startsWith(spec.skip!)) continue;
      final n = re.allMatches(withStrings[f]!).length;
      if (n > 0) perFile[f] = n;
    }
    if (spec.label == 'Icons.<name>') liveIcons.addAll(perFile);
    out[spec.label] = {
      'pattern': spec.pattern,
      'note': spec.note,
      'count': perFile.values.fold<int>(0, (t, v) => t + v),
      'files': perFile,
    };
  }
  final pubspec = src.read('pubspec.yaml');
  final pubCode = pubspec == null
      ? ''
      : pubspec.split('\n').map((l) => l.split('#').first).join('\n');
  out['pubspec fonts'] = {
    'note': 'retired type families still declared in pubspec.yaml',
    'count': _fontFamilies.fold<int>(
      0,
      (t, f) => t + RegExp(f).allMatches(pubCode).length,
    ),
    'files': {
      for (final f in _fontFamilies)
        if (RegExp(f).hasMatch(pubCode))
          'pubspec.yaml:$f': RegExp(f).allMatches(pubCode).length,
    },
  };
  return out;
}

/// Comments stripped, string contents kept — the same scanner the symbol
/// census uses for [symbolSpecs].
String stripComments(String? source) {
  if (source == null) return '';
  final s = _Scan(source);
  final b = StringBuffer();
  var last = 0;
  // Put string contents back into the masked text.
  for (final str in s.strings) {
    b
      ..write(s.masked.substring(last, str.start))
      ..write(source.substring(str.start, str.end));
    last = str.end;
  }
  b.write(s.masked.substring(last));
  return b.toString();
}

Map<String, Object?> _ticketIndex(
  List<_Finding> findings,
  Map<String, String> titles,
) {
  final byTicket = <String, Map<String, int>>{};
  final untracked = <String>[];
  for (final f in findings) {
    final t = f.ticket;
    if (t == null || !_ticketPattern.hasMatch(t)) {
      untracked.add('${f.list}: ${f.id}');
      continue;
    }
    final lists = byTicket.putIfAbsent(t, () => {});
    lists[f.list] = (lists[f.list] ?? 0) + 1;
  }
  final tickets = <String, Object?>{};
  for (final t in byTicket.keys.toList()..sort()) {
    tickets[t] = {
      'title': titles[t],
      'findings': byTicket[t],
    };
  }
  return {
    'tickets': tickets,
    'untracked': untracked..sort(),
  };
}

// ---------------------------------------------------------------------------
// The census

Map<String, Object?> buildCensus(CensusSource src) {
  final findings = <_Finding>[];
  final liveIcons = <String, int>{};
  final symbols = _symbols(src, liveIcons);
  final sections = <String, Object?>{
    'transitions': _transitions(src, findings),
    'states53': _states(src, findings),
    'interactions': _interactions(src, findings),
    'contrast': _contrast(src, findings),
    'a11y': _a11y(src, findings),
    'tokens': _tokens(src, findings),
    'icons': _icons(src, liveIcons),
  };
  final ratchets = _ratchets(src);

  final titles = <String, String>{
    for (final e in _collection(
      src.read(_stateFindings),
      'registeredTickets',
    ).entries)
      e.key: e.values.join(),
    for (final e in _collection(
      src.read(_tokenTest),
      'tokenRegisteredTickets',
    ).entries)
      e.key: e.values.join(),
  };
  final index = _ticketIndex(findings, titles);
  final tickets = index['tickets']! as Map<String, Object?>;
  final untracked = index['untracked']! as List<String>;

  final byList = _countBy(findings.map((f) => f.list));
  final residue = [
    for (final r in ratchets)
      if (r['role'] == 'RESIDUE' && (r['live_total']! as int) > 0)
        '${r['file']} ${r['name']}: ${r['live_total']}',
  ];
  final missingInputs = [
    for (final e in sections.entries)
      if ((e.value! as Map)['status'] == notPresent) e.key,
  ];

  final String package8;
  if (missingInputs.isNotEmpty) {
    package8 = 'NOT_YET: inputs not present: ${missingInputs.join(', ')}';
  } else if (untracked.isNotEmpty) {
    package8 =
        'NOT_YET: ${untracked.length} known failures have no registered '
        'ticket (BUT-nnnn)';
  } else {
    package8 =
        'YES_WHEN_CI_IS_GREEN: every known failure has a registered ticket '
        '(BUT-nnnn in Linear); green tests are shown by CI, not by this '
        'census';
  }
  final complete = findings.isEmpty && residue.isEmpty;

  return {
    'schema': 1,
    'decision':
        'Q8-01 = A (Butlery design system fas2/produktbeslut-2026-09-27c.json:17-19): '
        'package 8 is done when the tests are green and every known failure '
        'has a ticket; the migration is complete only when the known-failure '
        'list is empty.',
    'verdict': {
      'package8_done': package8,
      'migration_complete': complete
          ? 'YES'
          : 'NO: ${findings.length} known failures and ${residue.length} '
                'residue lists are not empty',
      'known_failures': findings.length,
      'known_failures_by_list': byList,
      'tickets_registered': tickets.length,
      'failures_without_ticket': untracked,
      'residue_lists_not_empty': residue,
    },
    'sections': sections,
    'tickets': tickets,
    'ratchets': ratchets,
    'symbols': symbols,
  };
}

/// JSON with sorted keys, two-space indent, trailing newline.
String renderJson(Map<String, Object?> census) =>
    '${const JsonEncoder.withIndent('  ').convert(_sorted(census))}\n';

Object? _sorted(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    return {for (final k in keys) k: _sorted(v[k])};
  }
  if (v is List) return [for (final e in v) _sorted(e)];
  return v;
}

String renderMarkdown(Map<String, Object?> census) {
  final b = StringBuffer();
  final v = census['verdict']! as Map<String, Object?>;
  final s = census['sections']! as Map<String, Object?>;
  Map<String, Object?> sec(String k) => s[k]! as Map<String, Object?>;
  String counts(Object? m) {
    final map = (m ?? const {}) as Map;
    final keys = map.keys.map((k) => '$k').toList()..sort();
    return keys.map((k) => '$k ${map[k]}').join(', ');
  }

  b
    ..writeln('# Design migration census')
    ..writeln()
    ..writeln(
      '> Generated by `tools/design_migration_census.dart` from the code. '
      'Do not edit by hand: re-run the tool.',
    )
    ..writeln()
    ..writeln('## Verdict')
    ..writeln()
    ..writeln(census['decision'])
    ..writeln()
    ..writeln('- **Package 8 done:** ${v['package8_done']}')
    ..writeln('- **Migration complete:** ${v['migration_complete']}')
    ..writeln(
      '- Known failures: ${v['known_failures']} '
      '(${counts(v['known_failures_by_list'])})',
    )
    ..writeln(
      '  Each list counts at its own grain (a transition, a control state, '
      'a check, a view case), so one cause can appear in more than one list.',
    )
    ..writeln(
      '- Tickets: ${v['tickets_registered']} registered in Linear',
    )
    ..writeln(
      '- Failures without a ticket: '
      '${(v['failures_without_ticket']! as List).length}',
    );
  for (final u in v['failures_without_ticket']! as List) {
    b.writeln('  - $u');
  }
  b.writeln(
    '- Residue lists not empty: '
    '${(v['residue_lists_not_empty']! as List).length}',
  );
  for (final r in v['residue_lists_not_empty']! as List) {
    b.writeln('  - `$r`');
  }

  void notPresentLine(Map<String, Object?> m) =>
      b.writeln('NOT_PRESENT: `${m['file']}` is not in this tree.');

  b
    ..writeln()
    ..writeln('## Required flow transitions')
    ..writeln();
  final t = sec('transitions');
  if (t['status'] == notPresent) {
    notPresentLine(t);
  } else {
    b
      ..writeln(
        'Required: ${t['required']} (block 288: ${t['required_in_block288']}). '
        '${counts(t['by_status'])}.',
      )
      ..writeln()
      ..writeln(
        'Only TESTED counts as done. PARTIAL is built and driven but misses '
        'its canonical outcome; BUILT_NOT_REACHABLE is built but a user '
        'cannot reach it; MISSING is not built.',
      )
      ..writeln()
      ..writeln('| Transition | Status | Ticket |')
      ..writeln('| --- | --- | --- |');
    for (final e in t['not_done']! as List) {
      final m = e as Map;
      b.writeln('| `${m['id']}` | ${m['status']} | ${m['ticket'] ?? '—'} |');
    }
  }

  b
    ..writeln()
    ..writeln('## The 53 visual-only view states')
    ..writeln();
  final st = sec('states53');
  if (st['status'] == notPresent) {
    notPresentLine(st);
  } else {
    b
      ..writeln(
        'States: ${st['states']} (${counts(st['by_state'])}), each run in '
        'light and dark: ${st['cases']} cases.',
      )
      ..writeln(
        '- Cases passing: ${st['cases_pass']}; cases with a known finding: '
        '${st['cases_known_finding']}',
      )
      ..writeln(
        '- States passing in both modes: ${st['states_pass_both_modes']} '
        'of ${st['states']}',
      )
      ..writeln(
        '- Known findings: ${st['known_findings']} '
        '(ceiling ${st['known_findings_ceiling']}); by rule: '
        '${counts(st['known_findings_by_code'])}',
      );
    final unmatched = st['findings_not_matching_a_state']! as List;
    if (unmatched.isNotEmpty) {
      b.writeln('- Findings naming no state: ${unmatched.join(', ')}');
    }
  }

  b
    ..writeln()
    ..writeln('## Required control states')
    ..writeln();
  final i = sec('interactions');
  if (i['status'] == notPresent) {
    notPresentLine(i);
  } else {
    b
      ..writeln(
        'Required: ${i['required']}; ${counts(i['by_status'])}. '
        'Unspecified in block 288 (not tested): ${i['unspecified']}; '
        'not required: ${i['not_required']}. Known check findings: '
        '${i['known_check_findings']}.',
      )
      ..writeln()
      ..writeln('| Control state | Status | Ticket |')
      ..writeln('| --- | --- | --- |');
    for (final e in i['not_done']! as List) {
      final m = e as Map;
      b.writeln('| `${m['id']}` | ${m['status']} | ${m['ticket'] ?? '—'} |');
    }
  }

  b
    ..writeln()
    ..writeln('## Contrast pairs')
    ..writeln();
  final c = sec('contrast');
  if (c['status'] == notPresent) {
    notPresentLine(c);
  } else {
    b
      ..writeln(
        'Declared pairs: ${c['pairs']}. Measured in both modes: '
        '${c['measured_in_both_modes']}, of which under their floor: '
        '${(c['under_floor']! as List).length}; unmeasurable (no generated '
        'member): ${(c['unmeasurable']! as List).length}. ${c['rule']}.',
      )
      ..writeln()
      ..writeln('| Unmeasurable pair | Ticket |')
      ..writeln('| --- | --- |');
    for (final e in c['unmeasurable']! as List) {
      final m = e as Map;
      b.writeln('| `${m['pair']}` | ${m['ticket'] ?? '—'} |');
    }
    if ((c['under_floor']! as List).isNotEmpty) {
      b
        ..writeln()
        ..writeln('| Measured pair under its floor | Ticket |')
        ..writeln('| --- | --- |');
      for (final e in c['under_floor']! as List) {
        final m = e as Map;
        b.writeln('| `${m['pair']}` | ${m['ticket'] ?? '—'} |');
      }
    }
  }

  b
    ..writeln()
    ..writeln('## Accessibility matrix')
    ..writeln();
  final a = sec('a11y');
  if (a['status'] == notPresent) {
    notPresentLine(a);
  } else {
    b
      ..writeln(
        'Known findings: ${a['known_findings']} (ceiling '
        '${a['known_findings_ceiling']}) in ${a['cases_with_known_finding']} '
        'cases (view, state, mode, width, text scale).',
      )
      ..writeln(
        '- Host-bound text contrast (glyph rasteriser): '
        '${counts(a['host_bound'])}',
      )
      ..writeln('- By check: ${counts(a['by_code'])}')
      ..writeln('- By view: ${counts(a['by_view'])}');
  }

  b
    ..writeln()
    ..writeln('## Token parity')
    ..writeln();
  final k = sec('tokens');
  if (k['status'] == notPresent) {
    notPresentLine(k);
  } else {
    b
      ..writeln(
        'tokens.json ${k['tokens_version']} (sha256 '
        '`${k['tokens_sha256']}`); generated files say tokens '
        '${k['generated_light_tokens_version']} (light) and '
        '${k['generated_dark_tokens_version']} (dark).',
      )
      ..writeln(
        '- Semantic keys: ${k['semantic_keys']}; with a generated member: '
        '${k['semantic_keys_with_member']}',
      )
      ..writeln(
        '- Translucent semantic values on the opacityLadder: '
        '${(k['translucent_values_on_ladder']! as List).length}; off it: '
        '${(k['translucent_values_off_ladder']! as List).length} '
        '(${(k['translucent_values_off_ladder']! as List).join('; ')})',
      )
      ..writeln()
      ..writeln('| Semantic key without a member | Ticket |')
      ..writeln('| --- | --- |');
    for (final e in k['semantic_keys_without_member']! as List) {
      final m = e as Map;
      b.writeln('| `${m['key']}` | ${m['ticket'] ?? '—'} |');
    }
  }

  b
    ..writeln()
    ..writeln('## Icon residue')
    ..writeln();
  final ic = sec('icons');
  if (ic['status'] != present) {
    b.writeln('${ic['status']}: `${ic['file']}` has no `_residue`.');
  } else {
    b.writeln(
      'Material icons with no Butlery glyph yet: ${ic['residue_uses']} uses '
      'of ${ic['residue_icon_names']} icons in ${ic['residue_files']} files '
      '(Material icon uses found in lib code: '
      '${ic['material_icon_uses_in_lib']}).',
    );
    final stale = ic['stale_rows_for_deleted_files']! as List;
    if (stale.isNotEmpty) {
      b.writeln(
        'Rows still listed for files that are deleted (not counted): '
        '${stale.map((f) => '`$f`').join(', ')}.',
      );
    }
  }

  b
    ..writeln()
    ..writeln('## Known failures by ticket')
    ..writeln()
    ..writeln(
      'Every ticket is a registered Linear issue. A failure whose ticket '
      'is not a BUT-nnnn id is listed above as without a ticket. Titles '
      'are given for the tickets package 8 registered.',
    )
    ..writeln()
    ..writeln('| Ticket | Findings | Title (package 8 tickets) |')
    ..writeln('| --- | --- | --- |');
  final tickets = census['tickets']! as Map<String, Object?>;
  for (final e in tickets.entries) {
    final m = e.value! as Map;
    b.writeln(
      '| ${e.key} | ${counts(m['findings'])} | ${m['title'] ?? ''} |',
    );
  }

  b
    ..writeln()
    ..writeln('## Ratchets and adoption lists')
    ..writeln()
    ..writeln(
      'Read by name from test/architecture. RETIRED: the list is gone '
      '(emptied and deleted), counted as 0.',
    )
    ..writeln()
    ..writeln(
      'Total counts every entry (a count where the list holds one); Live '
      'leaves out entries naming a lib file that no longer exists.',
    )
    ..writeln()
    ..writeln('| File | List | Role | Status | Entries | Total | Live |')
    ..writeln('| --- | --- | --- | --- | --- | --- | --- |');
  for (final r in census['ratchets']! as List) {
    final m = r as Map;
    b.writeln(
      '| `${(m['file'] as String).split('/').last}` | `${m['name']}` | '
      '${m['role']} | ${m['status']} | ${(m['entries'] as List).length} | '
      '${m['total']} | ${m['live_total']} |',
    );
  }

  b
    ..writeln()
    ..writeln('## Symbols counted in lib')
    ..writeln()
    ..writeln(
      'Code only: comments are not counted; generated l10n is left out.',
    )
    ..writeln()
    ..writeln('| Symbol | Count | Files | Note |')
    ..writeln('| --- | --- | --- | --- |');
  final symbols = census['symbols']! as Map<String, Object?>;
  for (final e in symbols.entries) {
    final m = e.value! as Map;
    final files = (m['files'] as Map).keys.toList()..sort();
    final shown = files.length <= 6
        ? files.map((f) => '`$f`').join(', ')
        : '${files.length} files';
    b.writeln('| `${e.key}` | ${m['count']} | $shown | ${m['note']} |');
  }
  return b.toString();
}

Future<void> main(List<String> args) async {
  var out = 'build/design-migration-census';
  var format = 'both';
  for (final a in args) {
    if (a.startsWith('--out=')) {
      out = a.substring(6);
    } else if (a.startsWith('--format=')) {
      format = a.substring(9);
    } else {
      stderr.writeln(
        'usage: dart run tools/design_migration_census.dart '
        '[--out=<dir>] [--format=both|json|md]',
      );
      exit(64);
    }
  }
  if (!Directory('lib').existsSync()) {
    stderr.writeln('lib/ not found: run from the repo root.');
    exit(2);
  }
  final census = buildCensus(CensusSource('.'));
  Directory(out).createSync(recursive: true);
  if (format != 'md') {
    File('$out/census.json').writeAsStringSync(renderJson(census));
  }
  if (format != 'json') {
    File('$out/census.md').writeAsStringSync(renderMarkdown(census));
  }
  final v = census['verdict']! as Map;
  stdout
    ..writeln('package 8 done: ${v['package8_done']}')
    ..writeln('migration complete: ${v['migration_complete']}')
    ..writeln('wrote $out');
}
