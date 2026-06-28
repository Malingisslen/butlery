/// Direct unit tests for [ImageUploadValidator] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Covers the synchronous, pure-logic surface (no mocks, no I/O): the
/// upload-safety state machine, the pending/failed key collection, image-format
/// and URL classification, and the validation summary. The async file-I/O
/// methods (size/content/wait) are out of scope here — they need XFile fakes.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/image_upload_validator.dart';

ImageUploadStatus _status(ImageUploadState state) =>
    ImageUploadStatus(state: state);

void main() {
  final validator = ImageUploadValidator();

  group('checkUploadSafety', () {
    test('empty state map is safe', () {
      final r = validator.checkUploadSafety({});
      expect(r.isSafe, isTrue);
      expect(r.pendingImagePaths, isEmpty);
      expect(r.failedImagePaths, isEmpty);
    });

    test('all-completed is safe', () {
      final r = validator.checkUploadSafety({
        'a': _status(ImageUploadState.completed),
        'b': _status(ImageUploadState.completed),
      });
      expect(r.isSafe, isTrue);
      expect(r.pendingImagePaths, isEmpty);
      expect(r.failedImagePaths, isEmpty);
    });

    test(
      'pending/uploading/retrying are collected as pending and block save',
      () {
        final r = validator.checkUploadSafety({
          'p': _status(ImageUploadState.pending),
          'u': _status(ImageUploadState.uploading),
          'r': _status(ImageUploadState.retrying),
          'done': _status(ImageUploadState.completed),
        });
        expect(r.isSafe, isFalse);
        expect(r.pendingImagePaths, containsAll(<String>['p', 'u', 'r']));
        expect(r.pendingImagePaths, hasLength(3));
        expect(r.failedImagePaths, isEmpty);
      },
    );

    test('failed/cancelled are collected as failed and block save', () {
      final r = validator.checkUploadSafety({
        'f': _status(ImageUploadState.failed),
        'c': _status(ImageUploadState.cancelled),
      });
      expect(r.isSafe, isFalse);
      expect(r.failedImagePaths, containsAll(<String>['f', 'c']));
      expect(r.pendingImagePaths, isEmpty);
    });
  });

  group('getPendingAndFailedImageKeys', () {
    test('returns every non-completed key, excludes completed', () {
      final keys = validator.getPendingAndFailedImageKeys({
        'p': _status(ImageUploadState.pending),
        'f': _status(ImageUploadState.failed),
        'done': _status(ImageUploadState.completed),
      });
      expect(keys, containsAll(<String>['p', 'f']));
      expect(keys, isNot(contains('done')));
      expect(keys, hasLength(2));
    });
  });

  group('isValidImageFormat', () {
    test('accepts supported extensions, case-insensitively', () {
      for (final url in [
        'photo.jpg',
        'PHOTO.JPEG',
        'a/b/c.png',
        'x.GIF',
        'y.webp',
      ]) {
        expect(validator.isValidImageFormat(url), isTrue, reason: url);
      }
    });

    test('rejects unsupported or extension-less URLs', () {
      for (final url in ['doc.pdf', 'archive.zip', 'noext', 'image.jpg.txt']) {
        expect(validator.isValidImageFormat(url), isFalse, reason: url);
      }
    });
  });

  group('URL classification', () {
    test('isFirebaseUrl matches the storage host only', () {
      expect(
        validator.isFirebaseUrl(
          'https://firebasestorage.googleapis.com/v0/b/x/o/y.jpg',
        ),
        isTrue,
      );
      expect(validator.isFirebaseUrl('https://example.com/y.jpg'), isFalse);
    });

    test('isLocalFilePath matches absolute, file:// and blob: URLs', () {
      expect(validator.isLocalFilePath('/data/user/0/img.jpg'), isTrue);
      expect(validator.isLocalFilePath('file:///tmp/img.png'), isTrue);
      expect(validator.isLocalFilePath('blob:https://app/abc'), isTrue);
      expect(validator.isLocalFilePath('https://example.com/y.jpg'), isFalse);
    });

    test(
      'isDisplayableImage is true for firebase OR local, false otherwise',
      () {
        expect(
          validator.isDisplayableImage(
            'https://firebasestorage.googleapis.com/v0/b/x/o/y.jpg',
          ),
          isTrue,
        );
        expect(validator.isDisplayableImage('/local/img.png'), isTrue);
        expect(
          validator.isDisplayableImage('https://cdn.example.com/y.jpg'),
          isFalse,
        );
      },
    );
  });

  group('getValidationSummary', () {
    test('reports safe/pending/failed/completed/total counts', () {
      final summary = validator.getValidationSummary({
        'p': _status(ImageUploadState.pending),
        'f': _status(ImageUploadState.failed),
        'c1': _status(ImageUploadState.completed),
        'c2': _status(ImageUploadState.completed),
      });
      expect(summary['isSafe'], isFalse);
      expect(summary['pendingCount'], 1);
      expect(summary['failedCount'], 1);
      expect(summary['completedCount'], 2);
      expect(summary['totalImages'], 4);
    });
  });
}
