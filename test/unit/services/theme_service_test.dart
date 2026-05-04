/// BUT-468: covers the synchronous theme prewarm path used in `main()` to
/// avoid the startup theme flash. Asserts the static `readCachedThemeMode`
/// returns the persisted ThemeMode for each storage value, defaults to
/// system on absent/corrupt input, and the existing instance API still
/// reads the same key.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeService.readCachedThemeMode (BUT-468)', () {
    test('returns ThemeMode.system when no value is persisted', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await ThemeService.readCachedThemeMode(), ThemeMode.system);
    });

    test('returns ThemeMode.light when "light" is persisted', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      expect(await ThemeService.readCachedThemeMode(), ThemeMode.light);
    });

    test('returns ThemeMode.dark when "dark" is persisted', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      expect(await ThemeService.readCachedThemeMode(), ThemeMode.dark);
    });

    test('returns ThemeMode.system when "system" is persisted', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'system'});
      expect(await ThemeService.readCachedThemeMode(), ThemeMode.system);
    });

    test('returns ThemeMode.system when persisted value is unknown', () async {
      // Forward-compat: a future value the parser doesn't recognize falls
      // back to system rather than throwing — `main()` must never crash on
      // a stale on-disk preference.
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      expect(await ThemeService.readCachedThemeMode(), ThemeMode.system);
    });
  });

  group('ThemeService.initialize (regression)', () {
    test('loads persisted "dark" via the instance API too', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
      final service = ThemeService();
      await service.initialize();
      expect(service.themeMode, ThemeMode.dark);
      expect(service.isInitialized, isTrue);
    });
  });
}
