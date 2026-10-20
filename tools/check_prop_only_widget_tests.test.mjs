// Proves the prop-only widget test check still detects what it claims. Run: node --test tools/
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const TOOL = join(dirname(fileURLToPath(import.meta.url)), 'check_prop_only_widget_tests.mjs');

function run(testBody, baselineTests = []) {
  const root = mkdtempSync(join(tmpdir(), 'prop-only-'));
  const files = {
    'lib/cards.dart': 'class RecipeCard extends StatelessWidget {}\n',
    'test/cards_test.dart': `void main() {\n${testBody}\n}\n`,
  };
  for (const [path, body] of Object.entries(files)) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), body);
  }
  const baseline = join(root, 'baseline.json');
  writeFileSync(baseline, JSON.stringify({ tests: baselineTests }));
  return spawnSync('node', [TOOL, '--root', root, '--baseline', baseline, '--check'], { encoding: 'utf8' });
}

const PROP_ONLY = `  testWidgets('badges flag', (tester) async {
    final card = tester.widget<RecipeCard>(find.byType(RecipeCard));
    expect(card.showAllergenBadges, isTrue);
  });`;

test('a test that asserts only a prop of our own widget fails', () => {
  const r = run(PROP_ONLY);
  assert.equal(r.status, 1);
  assert.match(r.stderr, /cards_test\.dart :: badges flag/);
});

test('the same test passes once something that rendered is asserted', () => {
  const r = run(PROP_ONLY.replace('});', "  expect(find.text('Gluten'), findsOneWidget);\n  });"));
  assert.equal(r.status, 0, r.stderr);
});

test('a written reason waives it, a bare marker does not', () => {
  const waived = run(PROP_ONLY.replace('final card', '// props-only: the callback is what is under test\n    final card'));
  assert.equal(waived.status, 0, waived.stderr);
  const bare = run(PROP_ONLY.replace('final card', '// props-only:\n    final card'));
  assert.equal(bare.status, 1);
});

test('a framework widget does not count, and a baselined test passes', () => {
  const framework = run(PROP_ONLY.replaceAll('RecipeCard', 'Container'));
  assert.equal(framework.status, 0, framework.stderr);
  const known = run(PROP_ONLY, ['test/cards_test.dart :: badges flag']);
  assert.equal(known.status, 0, known.stderr);
});
