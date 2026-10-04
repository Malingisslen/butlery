/// The dark mode colours must take a member's dark value whenever the
/// generated dark delivery has one.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_mode_colors.dart';

void main() {
  test('info takes its dark value in dark mode', () {
    expect(ModeColors.dark.info, AppColorsDark.info);
    expect(ModeColors.light.info, AppColors.info);
    expect(ModeColors.dark.info, isNot(AppColors.info));
  });
}
