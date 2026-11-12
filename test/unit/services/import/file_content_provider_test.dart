/// Unit tests for FileContentProvider - File picking and content provision abstraction
///
/// Tests comprehensive file content provider functionality including:
/// - File picker abstraction for dependency injection
/// - Content provision from raw bytes
/// - Mock file result creation
/// - Platform file handling
/// - Multiple file selection
/// - File type filtering
/// - Extension validation
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';

// Production imports
import 'package:butlery/services/import/file_content_provider.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class TestFileContentProvider implements FileContentProvider {
  PlatformFile? mockResult;
  bool shouldThrow = false;
  Exception? exceptionToThrow;

  @override
  Future<PlatformFile?> pickFile({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    if (shouldThrow && exceptionToThrow != null) {
      throw exceptionToThrow!;
    }
    return mockResult;
  }

  @override
  Future<PlatformFile?> provideContent(
    Uint8List content,
    String fileName,
    String? extension,
  ) async {
    if (shouldThrow && exceptionToThrow != null) {
      throw exceptionToThrow!;
    }

    return InMemoryPlatformFile(
      name: fileName,
      bytes: content,
      extension: extension,
    );
  }
}

void main() {
  group('FileContentProvider', () {
    setUpAll(() async {
      // Initialize test infrastructure once for all tests
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      // Initialize service locator for each test
      await TestServiceLocator.initialize();
    });

    tearDown(() async {
      // Reset mocks and service locator after each test
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      // Final cleanup after all tests
      await BaseUnitTest.teardownUnit();
    });

    group('TestFileContentProvider Implementation', () {
      late TestFileContentProvider provider;

      setUp(() {
        provider = TestFileContentProvider();
      });

      test('should return mock result from pickFiles', () async {
        // Arrange
        provider.mockResult = InMemoryPlatformFile(
          name: 'test.txt',
          bytes: Uint8List(100),
          extension: 'txt',
        );

        // Act
        final result = await provider.pickFile();

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals('test.txt'));
      });

      test('should return null when no files picked', () async {
        // Arrange
        provider.mockResult = null;

        // Act
        final result = await provider.pickFile();

        // Assert
        expect(result, isNull);
      });

      test('should throw exception when configured', () async {
        // Arrange
        provider.shouldThrow = true;
        provider.exceptionToThrow = Exception('File picker error');

        // Act & Assert
        expect(
          () => provider.pickFile(),
          throwsA(isA<Exception>()),
        );
      });

      test('should provide content with correct metadata', () async {
        // Arrange
        final content = Uint8List.fromList([1, 2, 3, 4, 5]);
        const fileName = 'test.json';
        const extension = 'json';

        // Act
        final result = await provider.provideContent(
          content,
          fileName,
          extension,
        );

        // Assert
        expect(result, isNotNull);

        final file = result!;
        expect(file.name, equals(fileName));
        expect(await file.readAsBytes(), equals(content));
        expect(await file.length(), equals(5));
        expect(file.extension, equals(extension));
      });
    });

    group('DefaultFileContentProvider', () {
      late DefaultFileContentProvider provider;

      setUp(() {
        provider = DefaultFileContentProvider();
      });

      test('should provide content from raw bytes', () async {
        // Arrange
        final content = Uint8List.fromList([
          123,
          34,
          110,
          97,
          109,
          101,
          34,
          58,
          34,
          84,
          101,
          115,
          116,
          34,
          125,
        ]); // {"name":"Test"} in bytes
        const fileName = 'recipe.json';
        const extension = 'json';

        // Act
        final result = await provider.provideContent(
          content,
          fileName,
          extension,
        );

        // Assert
        expect(result, isNotNull);

        final file = result!;
        expect(file.name, equals(fileName));
        expect(await file.readAsBytes(), equals(content));
        expect(await file.length(), equals(content.length));
        expect(file.extension, equals(extension));
      });

      test('should handle empty content', () async {
        // Arrange
        final content = Uint8List(0);
        const fileName = 'empty.txt';

        // Act
        final result = await provider.provideContent(content, fileName, 'txt');

        // Assert
        expect(result, isNotNull);
        expect(await result!.length(), equals(0));
        expect((await result.readAsBytes()).isEmpty, isTrue);
      });

      test('should handle null extension', () async {
        // Arrange
        final content = Uint8List.fromList([72, 101, 108, 108, 111]); // "Hello"
        const fileName = 'noext';

        // Act
        final result = await provider.provideContent(content, fileName, null);

        // Assert
        expect(result, isNotNull);
        expect(result!.extension, isNull);
      });

      test('should handle large content', () async {
        // Arrange
        final content = Uint8List(1024 * 1024); // 1MB of zeros
        for (int i = 0; i < content.length; i++) {
          content[i] = i % 256;
        }
        const fileName = 'large.bin';

        // Act
        final result = await provider.provideContent(content, fileName, 'bin');

        // Assert
        expect(result, isNotNull);
        expect(await result!.length(), equals(1024 * 1024));
        expect((await result.readAsBytes()).length, equals(1024 * 1024));
      });

      test('should handle special characters in filename', () async {
        // Arrange
        final content = Uint8List.fromList([1, 2, 3]);
        const fileName = 'recipe åäö (2024).json';

        // Act
        final result = await provider.provideContent(content, fileName, 'json');

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals(fileName));
      });
    });

    group('File Type Scenarios', () {
      late TestFileContentProvider provider;

      setUp(() {
        provider = TestFileContentProvider();
      });

      test('should support JSON file content', () async {
        // Arrange
        const jsonString = '{"title":"Swedish Meatballs","servings":4}';
        final content = Uint8List.fromList(jsonString.codeUnits);

        // Act
        final result = await provider.provideContent(
          content,
          'recipe.json',
          'json',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.extension, equals('json'));
        expect(
          String.fromCharCodes(await result.readAsBytes()),
          equals(jsonString),
        );
      });

      test('should support text file content', () async {
        // Arrange
        const textContent = '''Swedish Meatballs
        
Ingredients:
- 500g ground beef
- 1 onion
- 2 dl cream

Instructions:
1. Mix ingredients
2. Form balls
3. Fry until golden''';
        final content = Uint8List.fromList(textContent.codeUnits);

        // Act
        final result = await provider.provideContent(
          content,
          'recipe.txt',
          'txt',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.extension, equals('txt'));
        expect(
          String.fromCharCodes(await result.readAsBytes()),
          equals(textContent),
        );
      });

      test('should support HTML file content', () async {
        // Arrange
        const htmlContent = '<html><body><h1>Recipe</h1></body></html>';
        final content = Uint8List.fromList(htmlContent.codeUnits);

        // Act
        final result = await provider.provideContent(
          content,
          'recipe.html',
          'html',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.extension, equals('html'));
        expect(
          String.fromCharCodes(await result.readAsBytes()),
          equals(htmlContent),
        );
      });

      test('should support binary file content', () async {
        // Arrange - Binary data (could be an image)
        final content = Uint8List.fromList([
          0xFF, 0xD8, 0xFF, 0xE0, // JPEG header
          0x00, 0x10, 0x4A, 0x46,
          0x49, 0x46, 0x00, 0x01,
        ]);

        // Act
        final result = await provider.provideContent(
          content,
          'recipe.jpg',
          'jpg',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.extension, equals('jpg'));
        expect(await result.readAsBytes(), equals(content));
        expect(await result.length(), equals(12));
      });
    });

    group('Single File Support', () {
      test('should handle single file result', () async {
        // Arrange
        final provider = TestFileContentProvider();
        provider.mockResult = InMemoryPlatformFile(
          name: 'file1.txt',
          bytes: Uint8List(50),
        );

        // Act
        final result = await provider.pickFile();

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals('file1.txt'));
        expect(await result.length(), equals(50));
      });

      test('should return each file from successive picks', () async {
        // Arrange
        final provider = TestFileContentProvider();
        final files = [
          InMemoryPlatformFile(name: 'file1.txt', bytes: Uint8List(50)),
          InMemoryPlatformFile(name: 'file2.json', bytes: Uint8List(100)),
          InMemoryPlatformFile(name: 'file3.html', bytes: Uint8List(150)),
        ];

        // Act
        final names = <String>[];
        for (final file in files) {
          provider.mockResult = file;
          names.add((await provider.pickFile())!.name);
        }

        // Assert
        expect(names, equals(['file1.txt', 'file2.json', 'file3.html']));
      });
    });

    group('Edge Cases', () {
      late DefaultFileContentProvider provider;

      setUp(() {
        provider = DefaultFileContentProvider();
      });

      test('should handle filename without extension', () async {
        // Arrange
        final content = Uint8List.fromList([1, 2, 3]);
        const fileName = 'README';

        // Act
        final result = await provider.provideContent(content, fileName, null);

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals(fileName));
        expect(result.extension, isNull);
      });

      test('should handle filename with multiple dots', () async {
        // Arrange
        final content = Uint8List.fromList([1, 2, 3]);
        const fileName = 'recipe.backup.2024.json';

        // Act
        final result = await provider.provideContent(content, fileName, 'json');

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals(fileName));
        expect(result.extension, equals('json'));
      });

      test('should handle content with UTF-8 BOM', () async {
        // Arrange - UTF-8 BOM followed by "Test"
        final content = Uint8List.fromList([
          0xEF,
          0xBB,
          0xBF,
          84,
          101,
          115,
          116,
        ]);

        // Act
        final result = await provider.provideContent(
          content,
          'utf8.txt',
          'txt',
        );

        // Assert
        expect(result, isNotNull);
        expect(await result!.readAsBytes(), equals(content));
        expect(await result.length(), equals(7));
      });

      test('should handle maximum filename length', () async {
        // Arrange
        final content = Uint8List.fromList([1]);
        final longFileName =
            'a' * 255 + '.txt'; // Max filename in most filesystems

        // Act
        final result = await provider.provideContent(
          content,
          longFileName,
          'txt',
        );

        // Assert
        expect(result, isNotNull);
        expect(result!.name, equals(longFileName));
      });
    });
  });
}
