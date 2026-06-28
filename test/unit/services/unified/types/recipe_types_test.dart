/// Direct unit tests for the recipe-service result types (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Covers the three result classes' factories + getters: RecipeOperationResult
/// (success/failure, isFailure, hasWarnings), ImportResult (success/failure),
/// and ExportResult (success/failure, recipeCount default). The plain data
/// holders (SharedRecipeData, RealtimeEditSession, RecipeCommentData) carry no
/// logic and are out of scope.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/unified/types/recipe_types.dart';

void main() {
  group('RecipeOperationResult', () {
    test('success carries message + warnings', () {
      final r = RecipeOperationResult.success('ok', const ['heads up']);
      expect(r.isSuccess, isTrue);
      expect(r.isFailure, isFalse);
      expect(r.message, 'ok');
      expect(r.hasWarnings, isTrue);
    });

    test('bare success has no message or warnings', () {
      final r = RecipeOperationResult.success();
      expect(r.isSuccess, isTrue);
      expect(r.message, isNull);
      expect(r.hasWarnings, isFalse);
    });

    test('failure is not successful and carries the message', () {
      final r = RecipeOperationResult.failure('nope');
      expect(r.isSuccess, isFalse);
      expect(r.isFailure, isTrue);
      expect(r.message, 'nope');
    });
  });

  group('ImportResult', () {
    test('success sets recipeId + sourceType, leaves error null', () {
      final r = ImportResult.success(
        recipeId: 'r1',
        sourceType: ImportSourceType.url,
        metadata: const {'k': 'v'},
      );
      expect(r.isSuccess, isTrue);
      expect(r.recipeId, 'r1');
      expect(r.error, isNull);
      expect(r.sourceType, ImportSourceType.url);
      expect(r.metadata, {'k': 'v'});
    });

    test('failure sets error, leaves recipeId null', () {
      final r = ImportResult.failure(
        error: 'bad',
        sourceType: ImportSourceType.photo,
      );
      expect(r.isSuccess, isFalse);
      expect(r.error, 'bad');
      expect(r.recipeId, isNull);
      expect(r.sourceType, ImportSourceType.photo);
    });
  });

  group('ExportResult', () {
    test('success sets filePath/format/recipeCount', () {
      final r = ExportResult.success(
        filePath: '/tmp/out.json',
        format: ExportFormat.json,
        recipeCount: 12,
      );
      expect(r.isSuccess, isTrue);
      expect(r.filePath, '/tmp/out.json');
      expect(r.format, ExportFormat.json);
      expect(r.recipeCount, 12);
    });

    test('failure sets error and defaults recipeCount to 0', () {
      final r = ExportResult.failure(
        error: 'disk full',
        format: ExportFormat.csv,
      );
      expect(r.isSuccess, isFalse);
      expect(r.error, 'disk full');
      expect(r.recipeCount, 0);
    });
  });
}
