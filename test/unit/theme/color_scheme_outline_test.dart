// The schemes' outline slot is semantic border.control in each mode
// (R8-10 = A, BUT-2229: paper at 40 % in dark). token_parity_test compares
// only the generated `static const Color` members with tokens.json, so the
// ColorScheme literals are pinned here against the member that names the
// token.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';

void main() {
  test('light outline is border.control', () {
    expect(AppColors.lightColorScheme.outline, AppColors.placeholderIcon);
  });

  test('dark outline is border.control', () {
    expect(AppColors.darkColorScheme.outline, AppColorsDark.placeholderIcon);
  });
}
