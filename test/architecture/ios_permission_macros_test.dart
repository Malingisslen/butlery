import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// permission_handler compiles each iOS permission out unless its macro is set
// in the Podfile. A compiled-out permission reports denied without prompting,
// so the feature silently never works on iPhone.
void main() {
  const macroByPermission = {
    'camera': 'PERMISSION_CAMERA=1',
    'photos': 'PERMISSION_PHOTOS=1',
    'microphone': 'PERMISSION_MICROPHONE=1',
    'notification': 'PERMISSION_NOTIFICATIONS=1',
  };

  test('camera, photos, microphone and notification requests in lib/ '
      'have their Podfile macros', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    final used = <String>{};
    final pattern = RegExp(r'Permission\.(\w+)');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        final name = match.group(1)!;
        if (macroByPermission.containsKey(name)) used.add(name);
      }
    }

    expect(
      used,
      contains('camera'),
      reason: 'guard is pointless if it no longer finds the camera request',
    );
    final missing = [
      for (final name in used)
        if (!podfile.contains("'${macroByPermission[name]}'"))
          macroByPermission[name],
    ];
    expect(
      missing,
      isEmpty,
      reason: 'add these to GCC_PREPROCESSOR_DEFINITIONS in ios/Podfile',
    );
  });
}
