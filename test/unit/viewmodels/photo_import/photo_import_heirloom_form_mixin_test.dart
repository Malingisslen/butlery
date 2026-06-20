import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_heirloom_form_mixin.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

/// Minimal concrete host so the mixin's BUT-410 heirloom form state can be
/// exercised in isolation — none of these tests touch the OCR/import pipeline,
/// only the getters/setters/clear the mixin owns. Extracted in BUT-1154.
class _HeirloomHost extends ImportBaseViewModel
    with PhotoImportHeirloomFormMixin {
  _HeirloomHost({required super.importManager});

  @override
  Future<void> performImport() async {}

  @override
  String get importType => 'test';
}

void main() {
  late _HeirloomHost host;
  late int notifyCount;

  setUp(() {
    host = _HeirloomHost(importManager: MockImportManager());
    notifyCount = 0;
    host.addListener(() => notifyCount++);
  });

  group('PhotoImportHeirloomFormMixin', () {
    test('writerName truncates at 100 chars to mirror HeirloomMetadata limit',
        () {
      host.heirloomWriterName = 'a' * 150;
      expect(host.heirloomWriterName.length, 100);
      // A boundary value at exactly 100 is kept intact (no off-by-one trim).
      host.heirloomWriterName = 'b' * 100;
      expect(host.heirloomWriterName, 'b' * 100);
    });

    test('note truncates at 200 chars to mirror HeirloomMetadata limit', () {
      host.heirloomNote = 'x' * 300;
      expect(host.heirloomNote.length, 200);
      host.heirloomNote = 'y' * 200;
      expect(host.heirloomNote, 'y' * 200);
    });

    test('setters are idempotent — same value does not over-notify', () {
      host.isHeirloom = true;
      host.heirloomWriterName = 'Farmor';
      host.heirloomYear = 1962;
      host.heirloomNote = 'från receptboken';
      final afterFirstWrites = notifyCount;

      // Re-setting identical values must short-circuit before notifyListeners.
      host.isHeirloom = true;
      host.heirloomWriterName = 'Farmor';
      host.heirloomYear = 1962;
      host.heirloomNote = 'från receptboken';
      expect(notifyCount, afterFirstWrites,
          reason: 'identical re-sets should not fire notifyListeners');
    });

    test('clearHeirloomForm resets every field to its empty default', () {
      host.isHeirloom = true;
      host.heirloomWriterName = 'Farmor';
      host.heirloomYear = 1962;
      host.heirloomNote = 'från receptboken';

      host.clearHeirloomForm();

      expect(host.isHeirloom, isFalse);
      expect(host.heirloomWriterName, isEmpty);
      expect(host.heirloomYear, isNull);
      expect(host.heirloomNote, isEmpty);
      expect(host.isOfflineQueued, isFalse);
    });

    group('hasHeirloomContent (gates the remove-photo confirm)', () {
      test('false when no origin field is filled', () {
        expect(host.hasHeirloomContent, isFalse);
        // The toggle alone, with no typed details, is not "content".
        host.isHeirloom = true;
        expect(host.hasHeirloomContent, isFalse);
      });

      test('true when any single field holds content', () {
        host.heirloomWriterName = 'Farmor';
        expect(host.hasHeirloomContent, isTrue);

        host.clearHeirloomForm();
        host.heirloomYear = 1962;
        expect(host.hasHeirloomContent, isTrue);

        host.clearHeirloomForm();
        host.heirloomNote = 'från receptboken';
        expect(host.hasHeirloomContent, isTrue);
      });

      test('false again after the form is cleared', () {
        host.heirloomWriterName = 'Farmor';
        host.heirloomNote = 'note';
        host.clearHeirloomForm();
        expect(host.hasHeirloomContent, isFalse);
      });
    });

    test('setters no-op after dispose so a late callback cannot mutate state',
        () {
      host.heirloomWriterName = 'Farmor';
      host.dispose();

      host.heirloomWriterName = 'someone else';
      host.isHeirloom = true;
      host.heirloomYear = 2000;
      host.heirloomNote = 'late';

      expect(host.heirloomWriterName, 'Farmor');
      expect(host.isHeirloom, isFalse);
      expect(host.heirloomYear, isNull);
      expect(host.heirloomNote, isEmpty);
    });
  });
}
