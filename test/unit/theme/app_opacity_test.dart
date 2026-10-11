// AppOpacity is hand-written; tokens.json is the source. A step added,
// dropped or changed on either side turns this red.

import 'dart:convert';
import 'dart:io';

import 'package:butlery/theme/app_opacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ladder =
      (jsonDecode(File('design/tokens.json').readAsStringSync())
              as Map<String, dynamic>)['opacityLadder']
          as Map<String, dynamic>;

  List<double> steps(String key) => [
    for (final v in ladder[key] as List<dynamic>) (v as num).toDouble(),
  ];

  test('onPaper is tokens.json opacityLadder.onPaper', () {
    expect(AppOpacity.onPaper, steps('onPaper'));
  });

  test('onInk is tokens.json opacityLadder.onInk', () {
    expect(AppOpacity.onInk, steps('onInk'));
  });
}
