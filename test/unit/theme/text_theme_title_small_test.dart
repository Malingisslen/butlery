// BUT-2369: createTextTheme left titleSmall out, so textTheme.titleSmall
// came from Material's own typography in its own typeface. The slot now
// takes label (14/600) in the app's family.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_theme.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    test('${theme.brightness.name}: titleSmall is label in ButlerySans', () {
      final titleSmall = theme.textTheme.titleSmall!;
      expect(titleSmall.fontFamily, AppTextStyles.family);
      expect(titleSmall.fontSize, AppTextStyles.labelLarge.fontSize);
      expect(titleSmall.fontWeight, AppTextStyles.labelLarge.fontWeight);
    });
  }
}
