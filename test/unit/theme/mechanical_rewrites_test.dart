/// The review gates skip a file whose only change swaps the pairs listed under
/// `mechanicalRewrites` in .claude/shared-plugin.json. That is safe only while
/// every pair names the same value.
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:flutter_test/flutter_test.dart';

final _values = <String, Object>{
  'AppDimensions.spacingXs': AppDimensions.spacingXs,
  'AppDimensions.spacingSm': AppDimensions.spacingSm,
  'AppDimensions.spacingM': AppDimensions.spacingM,
  'AppDimensions.paddingS': AppDimensions.paddingS,
  'AppDimensions.spacingL': AppDimensions.spacingL,
  'AppDimensions.paddingM': AppDimensions.paddingM,
  'AppDimensions.paddingMd': AppDimensions.paddingMd,
  'AppDimensions.spacingMd': AppDimensions.spacingMd,
  'AppDimensions.paddingL': AppDimensions.paddingL,
  'AppDimensions.spacingLg': AppDimensions.spacingLg,
  'AppDimensions.spacingXxxl': AppDimensions.spacingXxxl,
  'AppDimensions.spacingXl': AppDimensions.spacingXl,
  'AppDimensions.iconSizeAction': AppDimensions.iconSizeAction,
  'AppDimensions.iconSizeInfo': AppDimensions.iconSizeInfo,
  'AppDimensions.iconSizeDisplay': AppDimensions.iconSizeDisplay,
  'AppDimensions.iconSizeEmptyState': AppDimensions.iconSizeEmptyState,
  'AppDimensions.space4': AppDimensions.space4,
  'AppDimensions.space8': AppDimensions.space8,
  'AppDimensions.space12': AppDimensions.space12,
  'AppDimensions.space16': AppDimensions.space16,
  'AppDimensions.space24': AppDimensions.space24,
  'AppDimensions.space32': AppDimensions.space32,
  'AppDimensions.iconSizeM': AppDimensions.iconSizeM,
  'AppDimensions.iconSizeXl': AppDimensions.iconSizeXl,
  'AppTextStyles.metadataEmphasized': AppTextStyles.metadataEmphasized,
  'AppTextStyles.bodyMediumMuted': AppTextStyles.bodyMediumMuted,
  'AppTextStyles.titleMediumMuted': AppTextStyles.titleMediumMuted,
  'AppTextStyles.labelMediumMuted': AppTextStyles.labelMediumMuted,
  'AppTextStyles.labelMedium': AppTextStyles.labelMedium,
  'AppTextStyles.bodyMedium': AppTextStyles.bodyMedium,
  'AppTextStyles.titleMedium': AppTextStyles.titleMedium,
};

bool _isPathPair((String, String) pair) =>
    pair.$1.contains('/') && pair.$2.contains('/');

List<(String, String)> _declaredPairs() {
  final config =
      jsonDecode(File('.claude/shared-plugin.json').readAsStringSync())
          as Map<String, dynamic>;
  return [
    for (final rule in config['mechanicalRewrites'] as List)
      for (final pair in (rule as Map<String, dynamic>)['pairs'] as List)
        ((pair as List)[0] as String, pair[1] as String),
  ];
}

void main() {
  final all = _declaredPairs();
  final pairs = all.where((p) => !_isPathPair(p)).toList();
  final pathPairs = all.where(_isPathPair).toList();

  test('the config declares at least one pair', () {
    expect(pairs, isNotEmpty);
  });

  for (final (from, to) in pairs) {
    test('$from names the same value as $to', () {
      expect(_values, contains(from), reason: 'add $from to _values');
      expect(_values, contains(to), reason: 'add $to to _values');
      expect(_values[from], _values[to]);
    });
  }

  test('the config declares at least one path pair', () {
    expect(pathPairs, isNotEmpty);
  });

  test('no pair renames to a name another pair renames away', () {
    final froms = {for (final (a, _) in all) a};
    expect([for (final (_, b) in all) b].where(froms.contains), isEmpty);
  });

  test('this file is outside every rewrite path', () {
    final config =
        jsonDecode(File('.claude/shared-plugin.json').readAsStringSync())
            as Map<String, dynamic>;
    const self = 'test/unit/theme/mechanical_rewrites_test.dart';
    for (final rule in config['mechanicalRewrites'] as List) {
      for (final p in (rule as Map<String, dynamic>)['paths'] as List) {
        expect(RegExp('^(?:$p)').hasMatch(self), isFalse, reason: p as String);
      }
    }
  });

  test('_values names nothing the config no longer declares', () {
    final named = {
      for (final (a, b) in pairs) ...[a, b],
    };
    expect(_values.keys.toSet().difference(named), isEmpty);
  });
}
