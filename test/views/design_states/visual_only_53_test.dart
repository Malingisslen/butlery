/// P8-U01: the 53 view states source code alone could not settle, each
/// pumped in light and dark and judged by its design rule.
///
/// The migration plan (2026-09-20) gave them their own verification post in
/// package 8: "varje läge körs och jämförs mot designens regel". The rows are
/// ux-beteende.json KLASS = VISUAL_ONLY_MIGRATION (53 rows over 18 views),
/// and every one of them is a required state in
/// fas2/block288-uxfrysning.json vytillstand.
///
/// A state that breaks its rule today is listed in known_state_findings.dart
/// with its ticket. It is never fixed here and never hidden: an unlisted
/// failure is red, and so is a listed one that passes (decision Q8-01 = A).
///
/// The run writes test_results/design-states-53.json.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'known_state_findings.dart';
import 'state_harness.dart';
import 'state_hosts.dart';
import 'state_runner.dart';

/// ux-beteende.json as the package 8 plan re-hashed it.
const _sourceSha256 =
    'fb0a1245d2cd5b14dad68d19b627fe9f081893b1ac135d34a3bf05f48cf0cdd8';

/// fas2/block288-uxfrysning.json BINDNING.UX_STATE_SET_HASH.
const _uxStateSetHash =
    '60e69697717610db907452b858d3535e94627eef3368fb2273544fa8aa08932a';

const _modes = [Brightness.light, Brightness.dark];

String _modeName(Brightness b) => b == Brightness.dark ? 'dark' : 'light';

void main() {
  final fixture = StateFixture.load();
  final rows = fixture.rows;
  final results = <Map<String, Object?>>[];

  setUpAll(() async {
    registerHostFallbacks();
    await loadButlerySans();
  });

  group('the vendored fixture', () {
    test('carries its source hash and the block288 state-set hash', () {
      expect(fixture.source['sha256'], _sourceSha256);
      expect(fixture.block288['UX_STATE_SET_HASH'], _uxStateSetHash);
    });

    test('holds 53 rows over 18 views, 18/8/11/14/2 by kind', () {
      expect(rows, hasLength(53));
      expect(rows.map((r) => r.view).toSet(), hasLength(18));
      final byKind = <String, int>{};
      for (final r in rows) {
        byKind[r.state] = (byKind[r.state] ?? 0) + 1;
      }
      expect(byKind, {
        'DEFAULT': 18,
        'EMPTY': 8,
        'LOADING': 11,
        'OFFLINE': 14,
        'CONFLICT': 2,
      });
      expect(rows.map((r) => r.id).toSet(), hasLength(53));
    });

    test('every row is a required state in block288', () {
      final required = (fixture.block288['required_states'] as List<dynamic>)
          .cast<String>()
          .toSet();
      for (final r in rows) {
        expect(required, contains(r.id), reason: '${r.id} is not required');
        expect(
          ['ALREADY_SATISFIED', 'PRODUCT_REMEDIATION_REQUIRED'],
          contains(r.block288Category),
        );
      }
    });

    test('every HOST is a class in its HOST_FILE, and BEVIS exists', () {
      for (final r in rows) {
        final file = File(r.hostFile);
        expect(file.existsSync(), isTrue, reason: '${r.id}: ${r.hostFile}');
        expect(
          RegExp(
            'class ${RegExp.escape(r.host)}\\b',
          ).hasMatch(file.readAsStringSync()),
          isTrue,
          reason: '${r.id}: no class ${r.host} in ${r.hostFile}',
        );
        expect(File(r.evidence).existsSync(), isTrue, reason: r.evidence);
        if (r.ownerNow != null) {
          expect(File(r.ownerNow!).existsSync(), isTrue, reason: r.ownerNow);
        }
      }
    });

    test('every row has a host, and no host is left without a row', () {
      expect(stateHosts.keys.toSet(), rows.map((r) => r.id).toSet());
    });

    test('the known findings name real rows and stay under the ceiling', () {
      final ids = {
        for (final r in rows)
          for (final m in _modes) '${r.id}::${_modeName(m)}',
      };
      for (final entry in knownStateFindings.entries) {
        final parts = entry.key.split('::');
        expect(parts, hasLength(4), reason: entry.key);
        expect(ids, contains(parts.take(3).join('::')), reason: entry.key);
        expect(
          RegExp(r'^(BUT-\d+|NY-P8-\d\d)$').hasMatch(entry.value.ticket),
          isTrue,
          reason: '${entry.key} has no ticket',
        );
        if (entry.value.ticket.startsWith('NY-')) {
          expect(
            proposedTickets,
            contains(entry.value.ticket),
            reason: 'a proposed ticket needs its title in proposedTickets',
          );
        }
      }
      expect(
        knownStateFindings.length,
        lessThanOrEqualTo(knownStateFindingsCeiling),
        reason: 'the known-findings list may only shrink',
      );
    });
  });

  group('the 53 states', () {
    tearDownAll(() {
      final out = File('test_results/design-states-53.json');
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert({
          'source_sha256': _sourceSha256,
          'ux_state_set_hash': _uxStateSetHash,
          'cases': results,
        }),
      );
    });

    for (final row in rows) {
      for (final mode in _modes) {
        final name = '${row.id} (${_modeName(mode)})';
        testWidgets(name, (tester) async {
          final violations = await atFixedClock(tester, () async {
            final run = await pumpState(tester, row, mode);
            final found = await judgeState(tester, run);
            await finishState(tester, run);
            return found;
          });

          final prefix = '${row.id}::${_modeName(mode)}::';
          final found = violations.map((v) => v.code).toSet();
          final known = knownStateFindings.keys
              .where((k) => k.startsWith(prefix))
              .map((k) => k.substring(prefix.length))
              .toSet();
          results.add({
            'row': row.id,
            'mode': _modeName(mode),
            'host': row.host,
            'violations': [for (final v in violations) v.toString()],
            'known': known.toList()..sort(),
            'verdict': found.isEmpty ? 'PASS' : 'KNOWN_FAILURE',
          });

          final unlisted = found.difference(known);
          final stale = known.difference(found);
          expect(
            unlisted,
            isEmpty,
            reason:
                '$name breaks its rule and the failure is not listed:\n'
                '${violations.where((v) => unlisted.contains(v.code)).join('\n')}',
          );
          expect(
            stale,
            isEmpty,
            reason:
                '$name now passes $stale: remove the entry from '
                'known_state_findings.dart and lower the ceiling',
          );
        });
      }
    }
  });
}
