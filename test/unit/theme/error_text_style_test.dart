// BUT-2371: error text follows the mode. The old AppTextStyles.errorText
// held the light AppColors.error in dark mode too.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/theme/error_text_style.dart';

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    final cs = (dark ? AppTheme.darkTheme : AppTheme.lightTheme).colorScheme;

    test('$mode: on paper it is the scheme\'s error colour', () {
      final style = errorTextStyle(cs);
      expect(style.color, cs.error);
      expect(style.fontSize, AppTextStyles.bodySmall.fontSize);
      expect(style.fontWeight, AppTextStyles.bodySmall.fontWeight);
    });

    test('$mode: on raised or the danger tint it is onErrorContainer', () {
      expect(errorTextStyle(cs, onRaised: true).color, cs.onErrorContainer);
    });
  }

  test('the two modes give different colours', () {
    expect(
      errorTextStyle(AppTheme.darkTheme.colorScheme).color,
      isNot(errorTextStyle(AppTheme.lightTheme.colorScheme).color),
    );
  });
}
