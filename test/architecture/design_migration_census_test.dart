/// P8-U05: the design migration census is consistent with itself.
///
/// Runs tools/design_migration_census.dart in-process against the working
/// tree. It freezes no counts: package 7 and later fixes shrink the lists it
/// reads, and this test must stay green through that. It checks that every
/// section is computed or honestly absent, that totals add up, that the
/// fixtures have the size block 288 gives them, and that the output is
/// deterministic.
library;

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart';

void main() {
  final census = buildCensus(CensusSource('.'));
  final sections = census['sections']! as Map<String, Object?>;
  Map<String, Object?> section(String name) =>
      sections[name]! as Map<String, Object?>;
  int sum(Object? counts) =>
      (counts! as Map).values.fold<int>(0, (t, v) => t + (v as int));

  test('every section is computed or reported absent', () {
    expect(sections.keys, {
      'transitions',
      'states53',
      'interactions',
      'contrast',
      'a11y',
      'tokens',
      'icons',
    });
    for (final e in sections.entries) {
      expect(
        (e.value! as Map)['status'],
        anyOf(present, notPresent, retired),
        reason: e.key,
      );
    }
    for (final r in census['ratchets']! as List) {
      final m = r as Map;
      expect(
        m['status'],
        anyOf(live, retired),
        reason: '${m['file']} ${m['name']} is not a list literal',
      );
    }
  });

  test('ratchet totals are the sum of their entries', () {
    for (final r in census['ratchets']! as List) {
      final m = r as Map;
      final entries = (m['entries'] as List).cast<Map>();
      expect(
        m['total'],
        entries.fold<int>(0, (t, e) => t + (e['weight'] as int)),
        reason: '${m['file']} ${m['name']}',
      );
      expect(
        m['live_total'],
        entries
            .where((e) => e['stale'] != true)
            .fold<int>(0, (t, e) => t + (e['weight'] as int)),
      );
      if (m['status'] == retired) expect(m['total'], 0);
    }
  });

  test('present fixtures have the size block 288 gives them', () {
    final t = section('transitions');
    if (t['status'] == present) {
      expect(t['required'], 81);
      expect(t['required_in_block288'], 81);
      expect(sum(t['by_status']), 81);
      expect(
        (t['not_done']! as List).length,
        81 - ((t['by_status']! as Map)['TESTED'] as int? ?? 0),
      );
    }
    final s = section('states53');
    if (s['status'] == present) {
      expect(s['states'], 53);
      expect(sum(s['by_state']), 53);
      expect(s['cases'], 106);
      expect(
        (s['cases_pass']! as int) + (s['cases_known_finding']! as int),
        106,
      );
      expect(
        (s['states_pass_both_modes']! as int) +
            (s['states_with_known_finding']! as List).length,
        53,
      );
      expect(s['findings_not_matching_a_state'], isEmpty);
    }
    final i = section('interactions');
    if (i['status'] == present) {
      expect(i['required'], 33);
      expect(sum(i['by_status']), 33);
    }
    final c = section('contrast');
    if (c['status'] == present) {
      expect(
        (c['measured_in_both_modes']! as int) +
            (c['unmeasurable']! as List).length,
        c['pairs'],
      );
    }
  });

  test('every known failure is counted once, in a list and by ticket', () {
    final v = census['verdict']! as Map<String, Object?>;
    final tickets = census['tickets']! as Map<String, Object?>;
    final byTicket = tickets.values.fold<int>(
      0,
      (t, m) => t + sum((m! as Map)['findings']),
    );
    expect(sum(v['known_failures_by_list']), v['known_failures']);
    expect(
      byTicket + (v['failures_without_ticket']! as List).length,
      v['known_failures'],
    );
    for (final e in tickets.entries) {
      expect(e.key, matches(RegExp(r'^BUT-\d+$')));
    }
    expect(v['tickets_registered'], tickets.length);
  });

  test('the verdict follows Q8-01 = A from the counts', () {
    final v = census['verdict']! as Map<String, Object?>;
    final empty =
        v['known_failures'] == 0 &&
        (v['residue_lists_not_empty']! as List).isEmpty;
    expect(v['migration_complete'], empty ? 'YES' : startsWith('NO: '));
    final done = v['package8_done']! as String;
    if ((v['failures_without_ticket']! as List).isNotEmpty) {
      expect(done, startsWith('NOT_YET: '));
    }
    final md = renderMarkdown(census);
    expect(md, contains('**Package 8 done:** $done'));
    expect(md, contains('**Migration complete:** ${v['migration_complete']}'));
  });

  test('a known failure without a registered BUT ticket keeps package 8 '
      'NOT_YET', () {
    const file = 'test/views/design_states/known_state_findings.dart';
    final source = CensusSource('.').read(file)!;
    // Adds one entry rather than renaming one, so the case holds while the
    // list is empty too.
    final unregistered = source.replaceFirst(
      'knownStateFindings = {',
      'knownStateFindings = {\n'
          "  'skafferi::OFFLINE::light::NO_OFFLINE_BANNER': "
          "KnownFinding('PROPOSED-1', 'test'),",
    );
    expect(unregistered, isNot(source));
    final v =
        buildCensus(
              CensusSource('.', overrides: {file: unregistered}),
            )['verdict']!
            as Map;
    expect(v['failures_without_ticket'], hasLength(1));
    expect(v['package8_done'], startsWith('NOT_YET: 1 known failures'));
  });

  test('two runs give byte-identical output', () {
    final again = buildCensus(CensusSource('.'));
    expect(renderJson(again), renderJson(census));
    expect(renderMarkdown(again), renderMarkdown(census));
  });

  test('a list package 7 deleted is RETIRED, and a missing fixture is '
      'NOT_PRESENT, never a crash', () {
    const file = 'test/architecture/error_contract_test.dart';
    final source = CensusSource('.').read(file)!;
    final without = source.replaceFirst(
      RegExp(r'^const _privateInlineErrors = .*;$', multiLine: true),
      '',
    );
    expect(without, isNot(source));
    final shrunk = buildCensus(
      CensusSource(
        '.',
        overrides: {
          file: without,
          'test/fixtures/design/transition_census.json': null,
          'test/architecture/package4_t3_adoption_test.dart': null,
        },
      ),
    );
    final ratchets = (shrunk['ratchets']! as List).cast<Map>();
    Map byName(String f, String n) =>
        ratchets.singleWhere((r) => r['file'] == f && r['name'] == n);
    expect(byName(file, '_privateInlineErrors')['status'], retired);
    expect(byName(file, '_privateInlineErrors')['total'], 0);
    expect(
      byName(
        'test/architecture/package4_t3_adoption_test.dart',
        '_topBarFiles',
      )['status'],
      retired,
    );
    final t = (shrunk['sections']! as Map)['transitions'] as Map;
    expect(t['status'], notPresent);
    expect(
      (shrunk['verdict']! as Map)['package8_done'],
      startsWith('NOT_YET: inputs not present: transitions'),
    );
  });

  group('the Dart list reader', () {
    test('ignores brackets and commas inside strings and comments', () {
      const src = '''
// const _decoy = {'a', 'b'};
const _counts = <String, Map<String, int>>{
  'lib/a.dart': {'x': 2, 'y': 1}, // a {comment}, with commas
  'lib/b, c.dart': {'z': 3},
};
const _names = {
  'one' 'two',
  "it's [three]",
  ..._more,
};
const _more = ['four', 'five'];
''';
      final r = readDartCollection(src, '_counts')!;
      expect(r.keys, ['lib/a.dart', 'lib/b, c.dart']);
      expect(r.values, [3, 3]);
      final n = readDartCollection(src, '_names')!;
      expect(n.keys, ['onetwo', "it's [three]", '..._more']);
      expect(n.values, [1, 1, 2]);
      expect(readDartCollection(src, '_decoy'), isNull);
      expect(readDartCollection(src, '_absent'), isNull);
    });
  });
}
