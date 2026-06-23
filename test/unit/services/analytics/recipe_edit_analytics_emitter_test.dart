/// Unit tests for [RecipeEditAnalyticsEmitter] (BUT-738).
///
/// Validates the contract:
///   - `recipe_edited` fires whenever the emitter is called (with non-empty
///     fields_changed when the diff produced any).
///   - `post_import_edit` fires only when the recipe has a sourceUrl and
///     the import is inside the [windowDays] window.
///   - tier_used is forwarded to the post_import_edit payload only when
///     non-null.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics/recipe_edit_analytics_emitter.dart';
import 'package:butlery/services/analytics/trackers/recipe_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';

import '../../../infrastructure/builders/recipe_builder.dart';

void main() {
  group('RecipeEditAnalyticsEmitter (BUT-738)', () {
    final fixedNow = DateTime(2026, 5, 5, 12, 0, 0);

    late _CapturingAnalyticsService analytics;
    late RecipeEditAnalyticsEmitter emitter;

    setUp(() {
      analytics = _CapturingAnalyticsService();
      emitter = RecipeEditAnalyticsEmitter(analytics: analytics);
    });

    test('emits recipe_edited with fields_changed when diff is non-empty', () {
      withClock(Clock.fixed(fixedNow), () {
        final original = _recipe(
          id: 'r1',
          title: 'Pasta',
          sourceUrl: null,
          daysAgo: 60,
        );
        final saved = original.copyWith(title: 'Pasta Carbonara');

        emitter.emit(
          recipeId: 'r1',
          original: original,
          savedRecipe: saved,
        );
      });

      expect(analytics.recipeEdits, hasLength(1));
      expect(analytics.recipeEdits.single.recipeId, 'r1');
      expect(analytics.recipeEdits.single.fieldsChanged, contains('title'));
    });

    test('does NOT emit post_import_edit when recipe has no sourceUrl '
        '(non-imported)', () {
      withClock(Clock.fixed(fixedNow), () {
        final original = _recipe(
          id: 'r1',
          title: 'Pasta',
          sourceUrl: null,
          daysAgo: 1,
        );
        final saved = original.copyWith(title: 'Pasta Carbonara');

        emitter.emit(
          recipeId: 'r1',
          original: original,
          savedRecipe: saved,
        );
      });

      expect(analytics.events, isEmpty);
      expect(analytics.recipeEdits, hasLength(1));
    });

    test('emits post_import_edit when imported within window', () {
      withClock(Clock.fixed(fixedNow), () {
        final original = _recipe(
          id: 'r1',
          title: 'Pasta',
          sourceUrl: 'https://www.koket.se/pasta',
          daysAgo: 5,
        );
        final saved = original.copyWith(title: 'Pasta Carbonara');

        emitter.emit(
          recipeId: 'r1',
          original: original,
          savedRecipe: saved,
          tierUsed: 'site_config',
          windowDays: 30,
        );
      });

      expect(analytics.events, hasLength(1));
      final event = analytics.events.single;
      expect(event.name, AnalyticsEvents.postImportEdit);
      expect(event.parameters['recipe_id'], 'r1');
      expect(event.parameters['fields_changed'], 'title');
      expect(event.parameters['tier_used'], 'site_config');
    });

    test('does NOT emit post_import_edit when import is outside window', () {
      withClock(Clock.fixed(fixedNow), () {
        final original = _recipe(
          id: 'r1',
          title: 'Pasta',
          sourceUrl: 'https://www.koket.se/pasta',
          daysAgo: 60,
        );
        final saved = original.copyWith(title: 'Pasta Carbonara');

        emitter.emit(
          recipeId: 'r1',
          original: original,
          savedRecipe: saved,
          windowDays: 30,
        );
      });

      expect(analytics.events, isEmpty);
    });

    test('omits tier_used from payload when null', () {
      withClock(Clock.fixed(fixedNow), () {
        final original = _recipe(
          id: 'r1',
          title: 'Pasta',
          sourceUrl: 'https://www.koket.se/pasta',
          daysAgo: 1,
        );
        final saved = original.copyWith(title: 'Pasta Carbonara');

        emitter.emit(
          recipeId: 'r1',
          original: original,
          savedRecipe: saved,
          // tierUsed deliberately null
        );
      });

      expect(analytics.events, hasLength(1));
      expect(
        analytics.events.single.parameters.containsKey('tier_used'),
        isFalse,
      );
    });
  });
}

Recipe _recipe({
  required String id,
  required String title,
  required String? sourceUrl,
  required int daysAgo,
}) {
  final createdAt = DateTime(2026, 5, 5, 12, 0, 0).subtract(
    Duration(days: daysAgo),
  );
  return (RecipeBuilder()
        ..id = id
        ..title = title
        ..sourceUrl = sourceUrl
        ..createdAt = createdAt
        ..updatedAt = createdAt)
      .build();
}

class _CapturingAnalyticsService implements AnalyticsService {
  final List<({String recipeId, List<String>? fieldsChanged})> recipeEdits = [];
  final List<({String name, Map<String, Object> parameters})> events = [];

  late final _CapturingRecipeTracker _recipeTracker = _CapturingRecipeTracker(
    this,
  );

  @override
  RecipeEventsTracker get recipe => _recipeTracker;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    events.add((name: name, parameters: parameters ?? const {}));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingRecipeTracker implements RecipeEventsTracker {
  _CapturingRecipeTracker(this._parent);
  final _CapturingAnalyticsService _parent;

  @override
  Future<void> logRecipeEdited({
    required String recipeId,
    List<String>? fieldsChanged,
  }) async {
    _parent.recipeEdits.add((recipeId: recipeId, fieldsChanged: fieldsChanged));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
