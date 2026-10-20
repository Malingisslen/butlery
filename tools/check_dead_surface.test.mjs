// Proves the dead-surface check still detects what it claims. Run: node --test tools/
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const TOOL = join(dirname(fileURLToPath(import.meta.url)), 'check_dead_surface.mjs');

function checkout(files) {
  const root = mkdtempSync(join(tmpdir(), 'dead-surface-'));
  for (const [path, body] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), body);
  }
  return root;
}

function run(root, ...extra) {
  const baseline = join(root, 'baseline.json');
  writeFileSync(baseline, JSON.stringify({ arbKeys: [] }));
  return spawnSync('node', [TOOL, '--root', root, '--baseline', baseline, ...extra], { encoding: 'utf8' });
}

const ARB = JSON.stringify({ '@@locale': 'sv', used: 'a', '@used': {}, orphan: 'b', '@orphan': {} });

test('--check fails on an ARB key nothing in lib/ names, and not on the metadata entry', () => {
  const root = checkout({
    'lib/l10n/app_sv.arb': ARB,
    'lib/view.dart': 'class V { String t(c) => c.l10n.used; }\n',
  });
  const r = run(root, '--check');
  assert.equal(r.status, 1);
  assert.match(r.stderr, /orphan/);
  assert.match(r.stderr, /^ {2}orphan$/m);
  assert.doesNotMatch(r.stderr, /^ {2}used$/m);
});

test('a baselined key passes, so the existing backlog never fails a build', () => {
  const root = checkout({
    'lib/l10n/app_sv.arb': ARB,
    'lib/view.dart': 'class V { String t(c) => c.l10n.used; }\n',
  });
  writeFileSync(join(root, 'baseline.json'), JSON.stringify({ arbKeys: ['orphan'] }));
  const r = spawnSync('node', [TOOL, '--root', root, '--baseline', join(root, 'baseline.json'), '--check'],
    { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
});

test('a method with no caller is reported even when another class has one of the same name', () => {
  const root = checkout({
    'lib/l10n/app_sv.arb': '{}',
    'lib/actions.dart': [
      'class Actions {',
      '  Future<void> blockUser(int id) async {}',
      '  Future<void> kept(int id) async {}',
      '  @override',
      '  void overridden() {}',
      '}',
      '',
    ].join('\n'),
    'lib/service.dart': 'class Service { void blockUser(int id) {} }\n',
    'lib/view.dart': 'void f(Actions a) { a.kept(1); }\n',
  });
  const r = run(root, '--all');
  assert.match(r.stdout, /Actions\.blockUser/);
  assert.doesNotMatch(r.stdout, /Actions\.kept/);
  assert.doesNotMatch(r.stdout, /overridden/);
  assert.equal(r.status, 0, 'the method half reports, it never fails a build');
});

test('a call statement at class indent is not read as a declaration', () => {
  const root = checkout({
    'lib/l10n/app_sv.arb': '{}',
    'lib/f.dart': 'void run() {\n  await doThing(1);\n  other(2);\n}\n',
  });
  const r = run(root, '--all');
  assert.doesNotMatch(r.stdout, /doThing|other/);
});
