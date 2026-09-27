/// P8-U03: the census of the 81 REQUIRED flow transitions stays true.
///
/// Sources: fas2/block288-uxfrysning.json overgangar (vendored as
/// test/fixtures/design/block288-overgangar.json with its
/// TRANSITION_SET_HASH), flows-roles-budget.md flows 01-08, and
/// fas2/ux-beslut.json D-03 and D-04. The census is
/// test/fixtures/design/transition_census.json.
///
/// It checks:
/// 0. the vendored rows still hash to the pinned TRANSITION_SET_HASH, as
///    tools/block288/uxfrysning.mjs:152 computes it in the design repo;
/// 1. the census ids are exactly the REQUIRED set, 81, per flow 10/4/8/6/6/
///    22/8/17;
/// 2. every test the census cites exists and still carries that name (and
///    group, when one is given);
/// 3. every entry that is not TESTED, and every known gap, names a ticket
///    (BUT-#### or a proposed NY-* listed in the census) and a reason;
/// 4. none of the 5 NOT_REQUIRED transitions is in the census as present;
/// 5. the negative D-03 and D-04 assertions exist in flow_01.
///
/// It writes test_results/transition-census.json with the counts and the
/// open gaps, so CI shows what is proven, what is built but not reachable,
/// and what is missing.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const _pinnedHash =
    '51bafaaed5d02513c607951ff9138fc724d8c9fd28a0c799a391d5651652c05e';

const _statuses = {'TESTED', 'BUILT_NOT_REACHABLE', 'MISSING'};

final _ticket = RegExp(r'^BUT-\d+$');

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The test source as its names read at runtime, near enough to find them:
/// adjacent string literals joined (`'a '\n  'b'` -> `a b`) and `\'`
/// unescaped. Interpolations such as `$mode` stay as written, and the
/// census cites them as written.
String _names(String source) => source
    .replaceAll(RegExp(r"'\s*\n\s*'"), '')
    .replaceAll(RegExp(r'"\s*\n\s*"'), '')
    .replaceAll(r"\'", "'");

void main() {
  final fixture = _json('test/fixtures/design/block288-overgangar.json');
  final rows = (fixture['overgangar'] as List).cast<Map<String, dynamic>>();
  final census = _json('test/fixtures/design/transition_census.json');
  final entries = (census['entries'] as List).cast<Map<String, dynamic>>();
  final proposed = (census['proposed_tickets'] as Map).cast<String, String>();

  final required = [
    for (final r in rows)
      if (r['STATUS'] == 'REQUIRED') r['TRANSITION_ID'] as String,
  ];
  final notRequired = [
    for (final r in rows)
      if (r['STATUS'] == 'NOT_REQUIRED') r['TRANSITION_ID'] as String,
  ];

  test('0 · the vendored transitions still hash to TRANSITION_SET_HASH', () {
    final lines = rows
        .map(
          (r) => '${r['TRANSITION_ID']}=${r['STATUS']}/${r['REPRESENTATION']}',
        )
        .join('\n');
    final hash = sha256.convert(utf8.encode(lines)).toString();
    expect(hash, _pinnedHash);
    expect(fixture['TRANSITION_SET_HASH'], _pinnedHash);
    expect(census['TRANSITION_SET_HASH'], _pinnedHash);
    expect(rows, hasLength(86));
  });

  test('1 · the census is exactly the 81 REQUIRED transitions', () {
    final ids = [for (final e in entries) e['id'] as String];
    expect(ids.toSet(), hasLength(ids.length), reason: 'no id twice');
    expect(ids.toSet(), required.toSet());
    expect(ids, hasLength(81));

    final perFlow = <String, int>{};
    for (final id in ids) {
      final flow = id.split('::')[2];
      perFlow[flow] = (perFlow[flow] ?? 0) + 1;
    }
    expect(perFlow, {
      '01': 10,
      '02': 4,
      '03': 8,
      '04': 6,
      '05': 6,
      '06': 22,
      '07': 8,
      '08': 17,
    });
    for (final e in entries) {
      expect(_statuses, contains(e['status']), reason: '${e['id']}');
      expect(e['flow'], (e['id'] as String).split('::')[2]);
    }
  });

  test('2 · every cited test exists and still carries its name', () {
    final sources = <String, String>{};
    String source(String path) => sources.putIfAbsent(path, () {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path does not exist');
      return _names(file.readAsStringSync());
    });

    void check(String id, Map<String, dynamic> ref) {
      final path = ref['file'] as String;
      final text = source(path);
      expect(
        text.contains(ref['name'] as String),
        isTrue,
        reason: '$id cites "${ref['name']}" in $path, which is not there',
      );
      final group = ref['group'] as String?;
      if (group != null) {
        expect(
          text.contains(group),
          isTrue,
          reason: '$id cites the group "$group" in $path',
        );
      }
    }

    for (final e in entries) {
      final id = e['id'] as String;
      final tests = (e['tests'] as List).cast<Map<String, dynamic>>();
      if (e['status'] == 'TESTED') {
        expect(tests, isNotEmpty, reason: '$id is TESTED without a test');
        expect(e['test_file'], tests.first['file']);
        expect(e['test_name'], tests.first['name']);
      }
      for (final ref in tests) {
        check(id, ref);
      }
      final gap = e['known_gap'] as Map<String, dynamic>?;
      final gapTest = gap?['test'] as Map<String, dynamic>?;
      if (gapTest != null) check(id, gapTest);
    }
  });

  test('3 · every gap names a ticket and a reason', () {
    void hasTicket(String id, Map<String, dynamic> m) {
      final ticket = m['ticket'] as String?;
      final draft = m['proposed_ticket'] as String?;
      expect(
        (ticket != null && _ticket.hasMatch(ticket)) ||
            (draft != null && proposed.containsKey(draft)),
        isTrue,
        reason: '$id needs a BUT ticket or a listed proposed ticket',
      );
      expect(
        (m['reason'] as String?)?.trim(),
        isNotEmpty,
        reason: '$id needs a reason',
      );
    }

    for (final e in entries) {
      final id = e['id'] as String;
      if (e['status'] != 'TESTED') hasTicket(id, e);
      final gap = e['known_gap'] as Map<String, dynamic>?;
      if (gap != null) hasTicket(id, gap);
    }
    for (final entry in proposed.entries) {
      expect(entry.key, matches(RegExp(r'^NY-[A-Z]$')));
      expect(entry.value.trim(), isNotEmpty);
    }
  });

  test('4 · the 5 NOT_REQUIRED transitions are not in the census', () {
    expect(notRequired, hasLength(5));
    final ids = {for (final e in entries) e['id']};
    for (final id in notRequired) {
      expect(ids, isNot(contains(id)), reason: '$id is NOT_REQUIRED');
    }
  });

  test('5 · flow_01 carries the negative D-03 and D-04 assertions', () {
    final flow01 = _names(
      File('test/views/flows/flow_01_transitions_test.dart').readAsStringSync(),
    );
    // D-03: no long-wait state and no "Fortsätt i bakgrunden".
    expect(flow01, contains('ux-beslut D-03: no long wait and no background'));
    expect(flow01, contains("find.textContaining('bakgrund'), findsNothing"));
    // D-04: no undo on the result, and the receipt's way back is Ändra.
    expect(flow01, contains('D-04: no undo on the result'));
    expect(flow01, contains("find.text('Ångra'), findsNothing"));
  });

  tearDownAll(() {
    int count(String status) =>
        entries.where((e) => e['status'] == status).length;
    final summary = {
      'TRANSITION_SET_HASH': _pinnedHash,
      'required': entries.length,
      'tested': count('TESTED'),
      'built_not_reachable': count('BUILT_NOT_REACHABLE'),
      'missing': count('MISSING'),
      'not_done': [
        for (final e in entries)
          if (e['status'] != 'TESTED')
            {
              'id': e['id'],
              'status': e['status'],
              'ticket': e['ticket'] ?? e['proposed_ticket'],
            },
      ],
      'known_gaps': [
        for (final e in entries)
          if (e['known_gap'] != null)
            {
              'id': e['id'],
              'ticket':
                  (e['known_gap'] as Map)['ticket'] ??
                  (e['known_gap'] as Map)['proposed_ticket'],
            },
      ],
      'proposed_tickets': proposed,
    };
    try {
      Directory('test_results').createSync(recursive: true);
      File('test_results/transition-census.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(summary),
      );
    } on FileSystemException {
      // The summary is a convenience for CI; the assertions above are the
      // gate.
    }
  });
}
