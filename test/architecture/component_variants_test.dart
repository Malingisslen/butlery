/// BUT-2375: each component type is drawn in no more places than its
/// ceiling allows.
///
/// The counts come from tools/design_variants.dart. A ceiling only falls: a
/// change that removes variants may lower its row, and must not raise one.
/// A count below its ceiling passes, so tickets fixing different rows never
/// have to edit this list at the same time.
library;

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart';
import '../../tools/design_variants.dart';

const variantCeilings = {
  'raw_destructive_alert_dialogs': 20,
  'hero_style_outside_hero_button': 0,
  'raw_button_style_from': 14,
  'raw_dialog_cancel': 29,
  'raw_snackbars': 21,
  'own_empty_states': 7,
  'card_surface_overrides': 9,
  'chevron_sizes': 5,
  'sheet_shape_overrides': 11,
  'direct_font_weights': 5,
  'hardcoded_max_width': 12,
  'forbidden_words_sv': 184,
  'raw_white_black': 1,
  'photo_viewers': 0,
  'alpha_literals': 0,
  'icon_size_literals': 2,
  'spacing_literals': 71,
  'scale_aliases': 2638,
};

void main() {
  final counts = countVariants(CensusSource('.'));

  test('every counted type has a ceiling, and every ceiling a type', () {
    expect(
      variantCeilings.keys.toSet(),
      variantSpecs.map((s) => s.key).toSet(),
    );
  });

  for (final s in variantSpecs) {
    test('${s.key} does not rise above its ceiling (${s.ticket})', () {
      final c = counts[s.key]!;
      final shown = c.values.isNotEmpty
          ? c.values.join(', ')
          : (c.files.keys.toList()..sort()).join('\n');
      expect(
        c.count,
        lessThanOrEqualTo(variantCeilings[s.key]!),
        reason:
            '${s.description}.\nA new variant was added; use the canonical '
            'component instead (${s.ticket}). Found in:\n$shown',
      );
    });
  }

  test('a ceiling is never below the target it is heading for', () {
    for (final s in variantSpecs) {
      expect(variantCeilings[s.key]!, greaterThanOrEqualTo(s.target));
    }
  });

  test('the census reads the same ceilings', () {
    final variants =
        buildCensus(CensusSource('.'))['variants']! as Map<String, Object?>;
    for (final e in variantCeilings.entries) {
      expect((variants[e.key]! as Map)['ceiling'], e.value, reason: e.key);
      expect((variants[e.key]! as Map)['count'], counts[e.key]!.count);
    }
  });

  // One line per row that draws that variant once more. Each row's counter
  // must see it, so a counter that silently returns 0 fails here instead of
  // passing under its ceiling.
  const probes = {
    'raw_destructive_alert_dialogs':
        'final _p = AlertDialog(actions: [TextButton(style: '
        'TextButton.styleFrom(foregroundColor: cs.error))]);',
    'hero_style_outside_hero_button':
        'final _p = ComponentThemes.heroButtonStyle(cs);',
    'raw_button_style_from': 'final _p = FilledButton.styleFrom();',
    'raw_dialog_cancel':
        'final _p = TextButton(onPressed: f, '
        'child: Text(context.l10n.commonCancel));',
    'raw_snackbars': 'final _p = SnackBar(content: Text("x"));',
    'own_empty_states': 'class _ProbeEmptyState {}',
    'card_surface_overrides': 'final _p = Card(elevation: 2);',
    'chevron_sizes':
        'final _p = ButleryIcon(ButleryIcons.chevronRight, size: 999);',
    'sheet_shape_overrides':
        'final _p = showModalBottomSheet(shape: s, builder: b);',
    'direct_font_weights': 'final _p = TextStyle(fontWeight: w);',
    'hardcoded_max_width': 'final _p = BoxConstraints(maxWidth: 321);',
    'raw_white_black': 'final _p = Colors.white;',
    'photo_viewers': 'final _p = InteractiveViewer(child: c);',
    'alpha_literals': 'final _p = c.withValues(alpha: 0.5);',
    'icon_size_literals':
        'final _p = ButleryIcon(ButleryIcons.check, size: 13);',
    'spacing_literals': 'final _p = EdgeInsets.all(7);',
    'scale_aliases': 'final _p = AppDimensions.spacingSm;',
  };
  const probeFile = 'lib/views/quick_capture_view.dart';

  for (final e in probes.entries) {
    test('one more ${e.key} raises its count by one', () {
      final source = CensusSource('.').read(probeFile)!;
      final after = countVariants(
        CensusSource('.', overrides: {probeFile: '$source\n${e.value}\n'}),
      );
      expect(after[e.key]!.count, counts[e.key]!.count + 1);
    });
  }

  test('one more forbidden Swedish value raises its count by one', () {
    const arb = 'lib/l10n/app_sv.arb';
    final source = CensusSource('.').read(arb)!;
    final added = source.replaceFirst(
      '{',
      '{\n  "probeKey": "Ta bort artikel",',
    );
    expect(added, isNot(source));
    final after = countVariants(CensusSource('.', overrides: {arb: added}));
    expect(
      after['forbidden_words_sv']!.count,
      counts['forbidden_words_sv']!.count + 1,
    );
  });

  test('every row has a probe', () {
    expect(
      {...probes.keys, 'forbidden_words_sv'},
      variantSpecs.map((s) => s.key).toSet(),
    );
  });

  int spacingAfter(String line) {
    final source = CensusSource('.').read(probeFile)!;
    return countVariants(
      CensusSource('.', overrides: {probeFile: '$source\n$line\n'}),
    )['spacing_literals']!.count;
  }

  test(
    'a numbered SizedBox gap counts; a token, a zero or a size does not',
    () {
      final base = counts['spacing_literals']!.count;
      expect(spacingAfter('final _p = SizedBox(height: 6);'), base + 1);
      expect(
        spacingAfter('final _p = SizedBox(width: AppDimensions.space8);'),
        base,
      );
      expect(spacingAfter('final _p = EdgeInsets.only(left: 0);'), base);
      expect(
        spacingAfter('final _p = EdgeInsets.all(AppDimensions.space4);'),
        base,
      );
      expect(spacingAfter('final _p = SizedBox(width: 92);'), base);
      expect(spacingAfter('final _p = SizedBox(width: 16, height: 16);'), base);
    },
  );

  test('a shape set on a child does not count as the Card\'s own', () {
    final source = CensusSource('.').read(probeFile)!;
    final after = countVariants(
      CensusSource(
        '.',
        overrides: {
          probeFile: '$source\nfinal _p = Card(child: ListTile(shape: s));\n',
        },
      ),
    );
    expect(
      after['card_surface_overrides']!.count,
      counts['card_surface_overrides']!.count,
    );
  });

  group('the call reader', () {
    test('skips parentheses inside strings and interpolations', () {
      const code = '''
final a = Card(child: Text('(not a close'), shape: x);
final b = OtherCard(shape: y);
final c = foo.Card(shape: z);
final d = Card(child: Text("\${f("))")}"), shape: q);
''';
      final calls = callArguments(code, 'Card');
      expect(calls, hasLength(2));
      expect(calls.first, contains('shape: x'));
      expect(calls.last, endsWith('shape: q'));
    });

    test('reads a named argument at the top level only', () {
      expect(
        namedArgument('X.a, size: AppDimensions.iconSizeS, color: c', 'size'),
        'AppDimensions.iconSizeS',
      );
      expect(namedArgument('X.a, child: Foo(size: 3)', 'size'), isNull);
    });
  });
}
