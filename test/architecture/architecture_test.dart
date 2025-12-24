import 'dart:io';

import 'package:test/test.dart';

/// Architecture compliance tests that validate MVVM + Repository pattern.
/// These tests run in CI to ensure architecture rules are maintained.
void main() {
  group('Architecture Compliance', () {
    late List<File> dartFiles;
    late Directory libDir;

    setUpAll(() {
      libDir = Directory('lib');
      if (!libDir.existsSync()) {
        fail('lib directory not found');
      }

      dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !f.path.contains('.g.dart'))
          .where((f) => !f.path.contains('.freezed.dart'))
          .toList();
    });

    test('lib directory contains Dart files', () {
      expect(dartFiles, isNotEmpty, reason: 'Should have Dart files in lib/');
    });

    test('MVVM directory structure exists', () {
      final requiredDirs = [
        'lib/models',
        'lib/views',
        'lib/viewmodels',
        'lib/services',
        'lib/repositories',
      ];

      for (final dir in requiredDirs) {
        expect(
          Directory(dir).existsSync(),
          isTrue,
          reason: 'Required directory $dir should exist',
        );
      }
    });

    test('core infrastructure directories exist', () {
      final coreDirs = [
        'lib/core',
        'lib/core/di',
        'lib/core/mixins',
      ];

      for (final dir in coreDirs) {
        expect(
          Directory(dir).existsSync(),
          isTrue,
          reason: 'Core directory $dir should exist',
        );
      }
    });

    test('no direct FirebaseFirestore.instance outside repositories', () {
      final violations = <String>[];

      for (final file in dartFiles) {
        final path = file.path.replaceAll('\\', '/');

        // Skip repository files - they are allowed to use Firestore directly
        if (path.contains('repository') || path.contains('_repository.dart')) {
          continue;
        }

        // Skip test entry points (e.g., main_e2e_emulator.dart)
        if (path.contains('main_e2e')) {
          continue;
        }

        // Skip sync managers that use fallback injection pattern
        if (path.contains('sync_manager')) {
          continue;
        }

        final content = file.readAsStringSync();
        if (content.contains('FirebaseFirestore.instance')) {
          violations.add(path);
        }
      }

      expect(
        violations,
        isEmpty,
        reason:
            'Direct FirebaseFirestore.instance usage should only be in repositories.\n'
            'Violations found in:\n${violations.join('\n')}',
      );
    });

    test('widgets directory exists under lib', () {
      expect(
        Directory('lib/widgets').existsSync(),
        isTrue,
        reason: 'Widgets directory should exist for reusable UI components',
      );
    });

    test('theme directory exists for centralized styling', () {
      expect(
        Directory('lib/theme').existsSync(),
        isTrue,
        reason: 'Theme directory should exist for centralized styling',
      );
    });

    test('DI modules are properly organized', () {
      final diModulesDir = Directory('lib/core/di/modules');
      expect(
        diModulesDir.existsSync(),
        isTrue,
        reason: 'DI modules directory should exist',
      );

      final modules = diModulesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('_module.dart'))
          .toList();

      expect(
        modules,
        isNotEmpty,
        reason: 'Should have at least one DI module',
      );
    });
  });

  group('File Organization', () {
    test('test directory mirrors lib structure', () {
      final testDir = Directory('test');
      expect(
        testDir.existsSync(),
        isTrue,
        reason: 'test directory should exist',
      );

      final testSubdirs = ['test/unit', 'test/widget', 'test/integration'];
      for (final dir in testSubdirs) {
        expect(
          Directory(dir).existsSync(),
          isTrue,
          reason: 'Test subdirectory $dir should exist',
        );
      }
    });
  });
}
