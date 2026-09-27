/// The dark mode colours must take a member's dark value whenever the
/// generated dark delivery has one. A light value in dark mode is the bug
/// that gave links #8A5212 on the dark page (about 2.5:1).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_mode_colors.dart';

void main() {
  test('info (text.link) takes its dark value in dark mode', () {
    expect(ModeColors.dark.info, AppColorsDark.info);
    expect(ModeColors.light.info, AppColors.info);
    expect(ModeColors.dark.info, isNot(AppColors.info));
  });
}
