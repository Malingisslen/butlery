/// The dark ButleryColors set must take a member's dark value whenever the
/// generated dark delivery has one. A light value in the dark set is the bug
/// that gave links #8A5212 on the dark page (about 2.5:1).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

void main() {
  test('info (text.link) takes its dark value in the dark set', () {
    expect(ButleryColors.dark.info, AppColorsDark.info);
  });
}
