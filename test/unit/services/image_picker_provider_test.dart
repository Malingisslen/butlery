/// Unit tests for DefaultImageValidator (pure-Dart extension check).
///
/// DefaultImagePickerProvider + DefaultPermissionProvider both wrap
/// platform plugins (image_picker / permission_handler) and require
/// integration tests to exercise. We pin the only pure-Dart bit here.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/image_picker_provider.dart';

void main() {
  final v = DefaultImageValidator();

  group('isValidImageFile — extension allow-list', () {
    test('accepts .jpg', () {
      expect(v.isValidImageFile(File('photo.jpg')), isTrue);
    });

    test('accepts .jpeg', () {
      expect(v.isValidImageFile(File('photo.jpeg')), isTrue);
    });

    test('accepts .png', () {
      expect(v.isValidImageFile(File('photo.png')), isTrue);
    });

    test('accepts .gif', () {
      expect(v.isValidImageFile(File('photo.gif')), isTrue);
    });

    test('accepts .webp', () {
      expect(v.isValidImageFile(File('photo.webp')), isTrue);
    });

    test('rejects unknown extensions', () {
      expect(v.isValidImageFile(File('doc.pdf')), isFalse);
      expect(v.isValidImageFile(File('archive.zip')), isFalse);
      expect(v.isValidImageFile(File('script.dart')), isFalse);
    });

    test('rejects files with no extension', () {
      expect(v.isValidImageFile(File('README')), isFalse);
    });

    test('case-insensitive matching (.JPG / .PNG / .WebP)', () {
      expect(v.isValidImageFile(File('photo.JPG')), isTrue);
      expect(v.isValidImageFile(File('photo.PNG')), isTrue);
      expect(v.isValidImageFile(File('photo.WebP')), isTrue);
    });

    test('checks full path suffix, not just basename', () {
      expect(v.isValidImageFile(File('/some/dir/photo.png')), isTrue);
      expect(v.isValidImageFile(File('C:\\foo\\bar.jpg')), isTrue);
    });

    test('rejects bad-pattern names like "imagepng" (no dot)', () {
      // The impl uses endsWith, so any path ending with the literal
      // extension string passes — including hostnames containing it.
      // This is the actual contract; pin so a future tightening shows up.
      expect(v.isValidImageFile(File('imagepng')), isFalse);
      // With the dot it passes (string endsWith literally).
      expect(v.isValidImageFile(File('image.png')), isTrue);
    });
  });
}
