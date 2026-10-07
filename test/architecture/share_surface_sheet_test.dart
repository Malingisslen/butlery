import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BUT-2250 (R8-8 = A): the universal share surface opens only through
/// `showUniversalShareSheet`. `UniversalShareDialog` no longer draws a dialog
/// frame of its own, so a call site opening it with `showDialog` would show
/// the content with no surface behind it.
void main() {
  final factoryCall = RegExp(
    r'UniversalShareDialog\.(recipe|recipes|menu|shoppingList|personalTag)\(',
  );
  const sheetCall = 'showUniversalShareSheet(';

  test('every UniversalShareDialog in lib/ is opened by the share sheet', () {
    final offenders = <String>[];
    var sites = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      if (path == 'lib/widgets/common/universal_share_dialog.dart') continue;
      final source = file.readAsStringSync();
      final built = factoryCall.allMatches(source).length;
      if (built == 0) continue;
      sites += built;
      final opened = sheetCall.allMatches(source).length;
      if (opened < built) {
        offenders.add('$path: $built built, $opened through $sheetCall');
      }
    }

    expect(
      sites,
      greaterThan(0),
      reason: 'no call site found; the scan is broken',
    );
    expect(offenders, isEmpty);
  });
}
