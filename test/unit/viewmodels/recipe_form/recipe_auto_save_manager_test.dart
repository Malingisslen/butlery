/// Intent-driven unit tests for `RecipeFormAutoSaveManager` (Intent-Test
/// Sprint, Batch 13 — auto-save / data-loss terrain).
///
/// Behaviours covered:
///   * Debounce timing: regular = 3s, quickSave = 1s, rapid reschedules
///     coalesce into a single write (off-by-one in delay = lost writes
///     or excessive Firestore writes).
///   * `_shouldAutoSave` gate: drafts with <2 filled fields are NOT
///     persisted; drafts with >=2 ARE persisted.
///   * Template mode: auto-save suppressed until significant changes
///     (>=5 change score), then promoted to regular form.
///   * `_currentDraftId` stability: a second save reuses the same draft
///     id (no duplicate draft per keystroke).
///   * SharedPreferences side effects: form payload + metadata index
///     written under the correct keys with the correct shape.
///   * `loadDraftData` round-trip works and returns null for unknown
///     draft ids.
///   * `getAvailableDrafts` filters by `isRecent` (24h) and sorts
///     newest-first.
///   * `deleteDraft` removes the per-draft entry AND the metadata
///     index entry.
///   * Race: typing during in-flight save — `skipIfBusy: true` drops
///     the new schedule.
///   * `saveNow` cancels any pending debounce and writes synchronously
///     (used on app background — must not lose data).
///   * `dispose()` mid-save: no setState/notify-after-dispose crash;
///     pending timer is cancelled.
///   * `hasRecentAutoSave` window: true within 10s, false beyond.
///   * Cleanup: `initialize()` purges drafts older than 24h from the
///     metadata index AND payload keys.
///   * Max-drafts cap: oldest drafts beyond the 5-entry limit are
///     pruned, including their per-draft payload key.
///   * `DraftMetadata` JSON round-trip with malformed/missing fields
///     defaults gracefully (via SerializationUtils + orEmpty/orZero).
///
/// Production findings surfaced (BUT-1138 FIXED iter-82):
///   * `clearCurrentDraft()` was `void` firing an unawaited
///     `deleteDraft()` future and nulling `_currentDraftId`
///     synchronously. A caller doing `clear(); save();` back-to-back
///     raced the save against the delete and a stale draft could
///     resurrect under a NEW id while the OLD payload key was still
///     being deleted. Now `Future<void>` and awaits the delete.
///   * `scheduleAutoSave` cancels the timer even when `skipIfBusy`
///     would have aborted the new schedule. Net effect: a queued,
///     debounced edit BEFORE the in-flight save is silently dropped
///     because the in-flight save's success path doesn't re-trigger
///     the cancelled debounce. Worst-case: user types → save fires;
///     user types again while save in flight (skipIfBusy=true) → the
///     post-in-flight edit never persists until the NEXT keystroke
///     after the save returns.
library;

import 'dart:convert';

import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _draftsKey = 'recipe_drafts_metadata';
const _draftPrefix = 'recipe_draft_';

Map<String, dynamic> _formWith({
  String? title,
  String? description,
  int? portions,
  int? timeMinutes,
  List<String>? ingredients,
  List<String>? instructions,
  List<String>? tags,
  List<String>? imageUrls,
}) {
  return <String, dynamic>{
    'title': ?title,
    'description': ?description,
    'portions': ?portions,
    'timeMinutes': ?timeMinutes,
    'ingredients': ?ingredients,
    'instructions': ?instructions,
    'tags': ?tags,
    'imageUrls': ?imageUrls,
  };
}

/// Wait long enough for a Timer of [d] to fire AND for the resulting
/// async save chain (SharedPreferences future, jsonEncode/decode) to
/// complete. We can't use `fakeAsync` cleanly here because
/// SharedPreferences's mock channel returns real Futures.
Future<void> _settle(Duration d) async {
  await Future<void>.delayed(d + const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('debounce timing', () {
    /// Proves: a single 3-second debounce window collapses many rapid
    /// `scheduleAutoSave` calls into exactly ONE persisted write.
    /// A regression that fires per-keystroke would write N times to
    /// SharedPreferences (and in production, Firestore).
    test(
      'coalesces rapid reschedules into a single write',
      () async {
        final manager = RecipeFormAutoSaveManager();
        addTearDown(manager.dispose);

        // Five rapid reschedules, each well under the 3s window.
        for (var i = 0; i < 5; i++) {
          manager.scheduleAutoSave(
            _formWith(
              title: 'edit #$i',
              ingredients: const ['salt'],
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        // Less than 3s total elapsed; nothing should be written yet.
        var prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(_draftsKey),
          isNull,
          reason: 'debounce should not have fired yet',
        );

        await _settle(const Duration(seconds: 3));

        prefs = await SharedPreferences.getInstance();
        final metadata = prefs.getString(_draftsKey);
        expect(metadata, isNotNull, reason: 'exactly one write expected');
        final decoded = jsonDecode(metadata!) as List;
        expect(
          decoded.length,
          1,
          reason: 'reschedules must coalesce, not duplicate drafts',
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    /// Proves: `isQuickSave: true` shortens the debounce window to 1s.
    /// A regression that swapped the constants would fire at 3s
    /// instead — or never (off-by-one).
    test(
      'quickSave fires faster than the default delay',
      () async {
        final manager = RecipeFormAutoSaveManager();
        addTearDown(manager.dispose);

        manager.scheduleAutoSave(
          _formWith(title: 't', ingredients: const ['a']),
          isQuickSave: true,
        );

        await _settle(const Duration(seconds: 1));
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(_draftsKey),
          isNotNull,
          reason: 'quickSave (1s) should fire well before the 3s default',
        );
      },
      timeout: const Timeout(Duration(seconds: 10)),
    );
  });

  group('shouldAutoSave gate', () {
    /// Proves: a draft below the `_minFieldsForAutoSave` threshold (2)
    /// is NOT written. The opposite — writing a single-field draft —
    /// would generate hundreds of trivial "Untitled" drafts per session.
    test('skips persist when <2 filled fields', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      // Only "title" filled -> 1 field.
      await manager.saveNow(_formWith(title: 'lonely'));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_draftsKey),
        isNull,
        reason: 'single-field forms must not be persisted',
      );
      expect(
        manager.currentDraftId,
        isNull,
        reason: 'no draft id should be assigned when gate fails',
      );
    });

    /// Proves: >= 2 filled fields persists.
    test('persists when >=2 filled fields', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await manager.saveNow(
        _formWith(title: 'soup', ingredients: const ['onion']),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_draftsKey), isNotNull);
      expect(manager.currentDraftId, isNotNull);
    });
  });

  group('template mode', () {
    /// Proves: a manager initialised as template does NOT auto-save
    /// minor edits — protects against polluting the draft list every
    /// time a user opens a template to browse it.
    test('suppresses auto-save for minor edits', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);
      await manager.initialize(isTemplate: true);

      // Title only — changeScore = 2; below the 5-point threshold.
      await manager.saveNow(
        _formWith(
          title: 'tiny edit',
          ingredients: const ['salt'],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_draftsKey),
        isNull,
        reason: 'template minor edits must not pollute the draft list',
      );
    });

    /// Proves: once the template has crossed the significance threshold
    /// (>=5 change score), it auto-saves. Title(2) + description(2) +
    /// one ingredient(1) = 5.
    test('auto-saves after crossing significance threshold', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);
      await manager.initialize(isTemplate: true);

      await manager.saveNow(
        _formWith(
          title: 'My Customized Recipe',
          description: 'Tweaked to my taste',
          ingredients: const ['onion'],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_draftsKey),
        isNotNull,
        reason: 'template should promote and persist past threshold',
      );
    });

    /// Proves: once promoted to non-template, a SECOND minor edit
    /// auto-saves freely (the promotion is sticky).
    test('promotion is sticky — subsequent minor edits also persist', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);
      await manager.initialize(isTemplate: true);

      // First save crosses threshold and promotes.
      await manager.saveNow(
        _formWith(
          title: 'Big',
          description: 'edit',
          ingredients: const ['onion'],
        ),
      );

      // Reset prefs so we can detect the SECOND save.
      SharedPreferences.setMockInitialValues({});

      // Second save: just two fields (below template threshold).
      await manager.saveNow(
        _formWith(
          title: 'follow',
          ingredients: const ['x'],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_draftsKey),
        isNotNull,
        reason: 'after promotion, template gate should be off',
      );
    });
  });

  group('draft id stability', () {
    /// Proves: across multiple auto-saves of the SAME session, the
    /// draft id is reused. Otherwise every save creates a new draft
    /// and the user accumulates ghosts.
    test('same draft id reused across successive saves', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await manager.saveNow(
        _formWith(title: 'a', ingredients: const ['x']),
      );
      final firstId = manager.currentDraftId;
      expect(firstId, isNotNull);

      await manager.saveNow(
        _formWith(title: 'a updated', ingredients: const ['x', 'y']),
      );

      expect(
        manager.currentDraftId,
        firstId,
        reason: 'second save must reuse the existing draft id',
      );

      final prefs = await SharedPreferences.getInstance();
      final metadata =
          jsonDecode(prefs.getString(_draftsKey)!) as List<dynamic>;
      expect(
        metadata.length,
        1,
        reason: 'reusing id must not produce a second metadata entry',
      );
    });
  });

  group('payload and metadata shape', () {
    /// Proves: the form payload survives a save/load cycle byte-for-byte.
    /// Catches a JSON-encoder/decoder mismatch or a key collision in
    /// the draft prefix.
    test('saveNow → loadDraftData round-trips the form payload', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      final form = _formWith(
        title: 'Carbonara',
        description: 'Roman classic',
        portions: 4,
        timeMinutes: 25,
        ingredients: const ['pasta', 'guanciale', 'egg', 'pecorino'],
        instructions: const ['boil pasta', 'render guanciale'],
        tags: const ['italian'],
      );

      await manager.saveNow(form);

      final id = manager.currentDraftId!;
      final reloaded = await manager.loadDraftData(id);

      expect(reloaded, isNotNull);
      expect(reloaded!['title'], 'Carbonara');
      expect(
        reloaded['ingredients'],
        ['pasta', 'guanciale', 'egg', 'pecorino'],
      );
      expect(reloaded['portions'], 4);
    });

    /// Proves: loadDraftData on an unknown id returns null, doesn't
    /// throw.
    test('loadDraftData returns null for unknown draft id', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      final result = await manager.loadDraftData('does_not_exist');
      expect(result, isNull);
    });

    /// Proves: metadata's fieldCount reflects the actual count of
    /// filled fields (so the recovery UI can prioritise drafts).
    test('metadata records non-zero fieldCount for a saved draft', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await manager.saveNow(
        _formWith(
          title: 'a',
          description: 'b',
          ingredients: const ['x', 'y'],
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final meta = jsonDecode(prefs.getString(_draftsKey)!) as List<dynamic>;
      final entry = meta.first as Map<String, dynamic>;
      // 1 title + 1 description + 2 ingredients = 4
      expect(entry['fieldCount'], 4);
      expect(entry['title'], 'a');
    });
  });

  group('getAvailableDrafts filtering', () {
    /// Proves: drafts older than 24h are hidden from the recovery UI
    /// even when they're still in the SharedPreferences index. The
    /// `isRecent` getter is the contract.
    test('hides drafts older than 24h, sorts newest first', () async {
      // Seed metadata directly with 3 drafts at different ages.
      final base = DateTime.utc(2026, 5, 27, 12);
      final fresh = DraftMetadata(
        draftId: 'fresh',
        createdAt: base.subtract(const Duration(minutes: 5)),
        lastModifiedAt: base.subtract(const Duration(minutes: 5)),
        title: 'fresh',
        fieldCount: 3,
      );
      final hourOld = DraftMetadata(
        draftId: 'hourOld',
        createdAt: base.subtract(const Duration(hours: 6)),
        lastModifiedAt: base.subtract(const Duration(hours: 6)),
        title: 'hourOld',
        fieldCount: 3,
      );
      final ancient = DraftMetadata(
        draftId: 'ancient',
        createdAt: base.subtract(const Duration(days: 5)),
        lastModifiedAt: base.subtract(const Duration(days: 5)),
        title: 'ancient',
        fieldCount: 3,
      );

      SharedPreferences.setMockInitialValues({
        _draftsKey: jsonEncode(
          [fresh, hourOld, ancient].map((m) => m.toJson()).toList(),
        ),
      });

      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await withClock(Clock.fixed(base), () async {
        final drafts = await manager.getAvailableDrafts();
        expect(
          drafts.map((d) => d.draftId).toList(),
          ['fresh', 'hourOld'],
          reason: 'ancient must be filtered, newest first',
        );
      });
    });
  });

  group('deleteDraft', () {
    /// Proves: deletion is two-sided — the payload key AND the metadata
    /// index entry both go. A regression that forgets the payload
    /// leaks bytes per delete; one that forgets the metadata leaves
    /// a phantom in the recovery dialog.
    test('removes both the payload entry and the metadata entry', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await manager.saveNow(
        _formWith(
          title: 'ephemeral',
          ingredients: const ['x'],
        ),
      );
      final id = manager.currentDraftId!;

      var prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('$_draftPrefix$id'),
        isNotNull,
        reason: 'precondition: payload exists',
      );
      expect(
        prefs.getString(_draftsKey),
        isNotNull,
        reason: 'precondition: metadata exists',
      );

      await manager.deleteDraft(id);

      prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('$_draftPrefix$id'),
        isNull,
        reason: 'payload key must be removed',
      );
      final remainingMeta =
          jsonDecode(prefs.getString(_draftsKey)!) as List<dynamic>;
      expect(remainingMeta, isEmpty, reason: 'metadata entry must be removed');
    });
  });

  group('race: typing during in-flight save', () {
    /// Proves: scheduling with `skipIfBusy: true` while a save is in
    /// flight does NOT enqueue a second timer that would re-enter
    /// `_performAutoSave` concurrently.
    ///
    /// Mechanic: we kick off `saveNow` (sets `_isAutoSaving=true`) and
    /// without awaiting it, call `scheduleAutoSave(..., skipIfBusy:
    /// true)`. The guard inside `scheduleAutoSave` should observe
    /// `_isAutoSaving` and return early, leaving `_autoSaveTimer`
    /// null (cancelled but not rescheduled).
    test(
      'skipIfBusy=true does not stack a new timer',
      () async {
        final manager = RecipeFormAutoSaveManager();
        addTearDown(manager.dispose);

        // Start an in-flight save (do NOT await).
        final inflight = manager.saveNow(
          _formWith(
            title: 'first',
            ingredients: const ['x'],
          ),
        );

        // While in flight, schedule another with skipIfBusy.
        manager.scheduleAutoSave(
          _formWith(title: 'second', ingredients: const ['y']),
          skipIfBusy: true,
        );

        // currentDraftId should already be set by saveNow's sync prelude
        // before the await; isAutoSaving should be true.
        expect(
          manager.isAutoSaving,
          isTrue,
          reason: 'precondition: save is in flight',
        );

        await inflight;

        // Give time for any sneakily-scheduled timer to fire.
        await _settle(const Duration(seconds: 3));

        // Exactly one metadata entry — 'second' was skipped.
        final prefs = await SharedPreferences.getInstance();
        final meta = jsonDecode(prefs.getString(_draftsKey)!) as List<dynamic>;
        expect(
          meta.length,
          1,
          reason: 'skipIfBusy=true must drop the new schedule entirely',
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );
  });

  group('saveNow', () {
    /// Proves: `saveNow` writes synchronously regardless of the debounce.
    /// Used when the app is backgrounded — losing data here is the
    /// worst-case for the feature.
    test(
      'cancels debounce and writes immediately',
      () async {
        final manager = RecipeFormAutoSaveManager();
        addTearDown(manager.dispose);

        // Schedule a debounced save we'll preempt with saveNow.
        manager.scheduleAutoSave(
          _formWith(title: 'stale', ingredients: const ['x']),
        );

        await manager.saveNow(
          _formWith(
            title: 'fresh-final',
            ingredients: const ['x', 'y'],
          ),
        );

        final prefs = await SharedPreferences.getInstance();
        final id = manager.currentDraftId!;
        final saved =
            jsonDecode(prefs.getString('$_draftPrefix$id')!)
                as Map<String, dynamic>;
        expect(
          saved['title'],
          'fresh-final',
          reason: 'saveNow must persist the payload it was called with',
        );

        // Give the cancelled debounce a chance to fire — it must not.
        await _settle(const Duration(seconds: 3));
        final reloaded =
            jsonDecode(prefs.getString('$_draftPrefix$id')!)
                as Map<String, dynamic>;
        expect(
          reloaded['title'],
          'fresh-final',
          reason: 'cancelled debounce must not overwrite saveNow payload',
        );
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    /// Proves: `saveNow` with insufficient content does NOT persist
    /// (the `_shouldAutoSave` gate still applies on the forced path).
    test('respects shouldAutoSave gate even on forced save', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await manager.saveNow(_formWith(title: 'only one field'));

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(_draftsKey),
        isNull,
        reason: 'saveNow does not bypass the significance gate',
      );
    });
  });

  group('dispose mid-save', () {
    /// Proves: disposing the manager while a debounced save is pending
    /// does not crash (no `notifyListeners` after dispose). The
    /// `_isDisposed` guard inside `_performAutoSave` is what we're
    /// protecting.
    test(
      'dispose with pending timer is safe and cancels the write',
      () async {
        final manager = RecipeFormAutoSaveManager();

        manager.scheduleAutoSave(
          _formWith(title: 'pending', ingredients: const ['x']),
        );
        // Dispose BEFORE the debounce fires.
        manager.dispose();
        // Wait past the original fire window.
        await _settle(const Duration(seconds: 3));

        // Nothing should be written because the timer was cancelled.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(_draftsKey), isNull);
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    /// Proves: when dispose runs while `_performAutoSave` is awaiting
    /// SharedPreferences, the post-await `notifyListeners` path is
    /// guarded — awaiting the in-flight future after disposing must
    /// NOT throw.
    test('dispose during in-flight saveNow does not crash', () async {
      final manager = RecipeFormAutoSaveManager();
      final saveFuture = manager.saveNow(
        _formWith(
          title: 'in flight',
          ingredients: const ['x'],
        ),
      );
      // Dispose immediately, before the SharedPreferences future
      // has a chance to complete.
      manager.dispose();
      // The expect here is that the future completes cleanly.
      await saveFuture;
      expect(true, isTrue);
    });
  });

  group('hasRecentAutoSave window', () {
    /// Proves: `hasRecentAutoSave` flips from true to false at the
    /// 10-second mark. The UI uses this for the "saved just now"
    /// indicator; off-by-one would either flash too briefly or stick.
    test('true within 10s, false beyond', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      final t0 = DateTime.utc(2026, 5, 27, 12);

      // Perform save under fixed clock = t0.
      await withClock(Clock.fixed(t0), () async {
        await manager.saveNow(
          _formWith(title: 'a', ingredients: const ['x']),
        );
      });

      // Read getter under a later fixed clock.
      withClock(Clock.fixed(t0.add(const Duration(seconds: 5))), () {
        expect(
          manager.hasRecentAutoSave,
          isTrue,
          reason: '5s after save: should still be flagged recent',
        );
      });
      withClock(Clock.fixed(t0.add(const Duration(seconds: 11))), () {
        expect(
          manager.hasRecentAutoSave,
          isFalse,
          reason: '11s after save: window must have closed',
        );
      });
    });

    /// Proves: with no save ever performed, `hasRecentAutoSave` is
    /// false (defends against a regression where the getter forgets
    /// the null check on `_lastAutoSaveTime`).
    test('false when no save has happened', () {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      expect(manager.hasRecentAutoSave, isFalse);
    });
  });

  group('cleanup on initialize', () {
    /// Proves: stale drafts beyond the 24h retention are physically
    /// purged on initialize (both payload and metadata). A regression
    /// where cleanup only updates the metadata leaks payload bytes.
    test('purges stale drafts from payload AND metadata', () async {
      final stale = DraftMetadata(
        draftId: 'old',
        createdAt: DateTime.utc(2026, 5, 1),
        lastModifiedAt: DateTime.utc(2026, 5, 1),
        title: 'old',
        fieldCount: 3,
      );
      final recent = DraftMetadata(
        draftId: 'new',
        createdAt: DateTime.utc(2026, 5, 27, 11),
        lastModifiedAt: DateTime.utc(2026, 5, 27, 11),
        title: 'new',
        fieldCount: 3,
      );

      SharedPreferences.setMockInitialValues({
        _draftsKey: jsonEncode([stale, recent].map((m) => m.toJson()).toList()),
        '${_draftPrefix}old': jsonEncode({'title': 'old'}),
        '${_draftPrefix}new': jsonEncode({'title': 'new'}),
      });

      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      await withClock(Clock.fixed(DateTime.utc(2026, 5, 27, 12)), () async {
        await manager.initialize();
      });

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${_draftPrefix}old'),
        isNull,
        reason: 'stale payload key must be removed',
      );
      expect(
        prefs.getString('${_draftPrefix}new'),
        isNotNull,
        reason: 'recent payload key must survive cleanup',
      );
      final remaining =
          jsonDecode(prefs.getString(_draftsKey)!) as List<dynamic>;
      expect(remaining.length, 1);
      expect((remaining.first as Map)['draftId'], 'new');
    });
  });

  group('max-drafts cap', () {
    /// Proves: when more than 5 drafts exist after a save, the oldest
    /// are pruned (both metadata entry and payload key). A regression
    /// that lets the cap grow unbounded silently bloats prefs and the
    /// recovery dialog.
    test('drops oldest beyond 5-entry cap, deleting their payloads', () async {
      // Seed 5 existing drafts (all within 24h so cleanup keeps them).
      final base = DateTime.utc(2026, 5, 27, 10);
      final existing = List.generate(5, (i) {
        final ts = base.add(Duration(minutes: i));
        return DraftMetadata(
          draftId: 'd$i',
          createdAt: ts,
          lastModifiedAt: ts,
          title: 'd$i',
          fieldCount: 3,
        );
      });

      SharedPreferences.setMockInitialValues({
        _draftsKey: jsonEncode(existing.map((m) => m.toJson()).toList()),
        for (final d in existing)
          '$_draftPrefix${d.draftId}': jsonEncode({'title': d.draftId}),
      });

      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      // Save with a clock past base so the new save's lastModifiedAt is
      // the newest in the list (sort = newest first → d0 evicted).
      await withClock(
        Clock.fixed(base.add(const Duration(hours: 1))),
        () async {
          await manager.saveNow(
            _formWith(
              title: 'newest',
              ingredients: const ['onion'],
            ),
          );
        },
      );

      final prefs = await SharedPreferences.getInstance();
      final metadata =
          jsonDecode(prefs.getString(_draftsKey)!) as List<dynamic>;
      expect(metadata.length, 5, reason: 'cap is 5 — six entries pruned to 5');

      // The oldest seed ("d0") must have been evicted.
      final ids = metadata.map((m) => (m as Map)['draftId'] as String).toList();
      expect(ids, isNot(contains('d0')));
      expect(
        prefs.getString('${_draftPrefix}d0'),
        isNull,
        reason: 'evicted payload key must be deleted, not orphaned',
      );
    });
  });

  group('DraftMetadata JSON', () {
    /// Proves: a DraftMetadata round-trips through JSON without loss.
    test('toJson/fromJson are inverse', () {
      final original = DraftMetadata(
        draftId: 'd1',
        createdAt: DateTime.utc(2026, 5, 27, 10),
        lastModifiedAt: DateTime.utc(2026, 5, 27, 11),
        title: 'Pasta',
        fieldCount: 7,
      );

      final restored = DraftMetadata.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );

      expect(restored.draftId, 'd1');
      expect(restored.createdAt, DateTime.utc(2026, 5, 27, 10));
      expect(restored.lastModifiedAt, DateTime.utc(2026, 5, 27, 11));
      expect(restored.title, 'Pasta');
      expect(restored.fieldCount, 7);
    });

    /// Proves: missing nullable fields (`title`, `fieldCount`,
    /// `draftId`) default safely via the `orEmpty()` / `orZero()`
    /// extensions. A regression that NPEs on a null field would crash
    /// the recovery dialog on every cold start with corrupted prefs.
    test('fromJson tolerates missing title/fieldCount/draftId', () {
      final restored = DraftMetadata.fromJson({
        'createdAt': '2026-05-27T10:00:00.000Z',
        'lastModifiedAt': '2026-05-27T11:00:00.000Z',
      });

      expect(restored.draftId, '');
      expect(restored.title, '');
      expect(restored.fieldCount, 0);
    });

    /// Proves: `isRecent` flips at the 24h boundary.
    test('isRecent is false beyond 24h', () {
      withClock(Clock.fixed(DateTime.utc(2026, 5, 27, 12)), () {
        final fresh = DraftMetadata(
          draftId: 'a',
          createdAt: DateTime.utc(2026, 5, 27),
          lastModifiedAt: DateTime.utc(2026, 5, 27, 11, 30),
          title: 'a',
          fieldCount: 3,
        );
        final stale = DraftMetadata(
          draftId: 'b',
          createdAt: DateTime.utc(2026, 5, 25),
          lastModifiedAt: DateTime.utc(2026, 5, 25),
          title: 'b',
          fieldCount: 3,
        );
        expect(fresh.isRecent, isTrue);
        expect(stale.isRecent, isFalse);
      });
    });
  });

  group('BUT-1136: timer survives skipIfBusy guard', () {
    /// BUT-1136 race-pin: when a debounce timer is pending AND a save is
    /// in flight, calling `scheduleAutoSave(skipIfBusy: true)` must NOT
    /// cancel the queued timer. Pre-fix: `_autoSaveTimer?.cancel()` ran
    /// before the guard, so the queued edit was silently dropped — the
    /// in-flight save's success path doesn't re-trigger anything, so the
    /// next debounce only existed if the user typed again. Post-fix: the
    /// guard runs first, returns early, and the pending timer survives.
    ///
    /// We need the test seam (`debugIsAutoSaving`) because driving this
    /// scenario via real `saveNow()` would itself cancel the queued
    /// timer (saveNow's own `_autoSaveTimer?.cancel()` prelude), masking
    /// the bug. The seam isolates the exact line under test.
    test('skipIfBusy=true preserves the pending timer when busy', () {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      // Step 1: schedule a normal debounce — pending timer is now active.
      manager.scheduleAutoSave(
        _formWith(
          title: 'queued edit',
          ingredients: const ['x'],
        ),
      );
      expect(
        manager.hasPendingAutoSaveTimer,
        isTrue,
        reason: 'precondition: debounce timer should be active',
      );

      // Step 2: simulate a save going in flight (e.g. saveNow racing the
      // debounce).
      manager.debugIsAutoSaving = true;

      // Step 3: caller schedules ANOTHER edit with skipIfBusy=true while
      // the save is in flight.
      manager.scheduleAutoSave(
        _formWith(title: 'concurrent edit', ingredients: const ['y']),
        skipIfBusy: true,
      );

      // Post-fix invariant: the original queued timer must still be
      // active. Pre-fix, this would be false because the cancel ran
      // before the guard.
      expect(
        manager.hasPendingAutoSaveTimer,
        isTrue,
        reason: 'BUT-1136: guard-first order must preserve queued timer',
      );
    });

    /// Companion: when NOT busy, skipIfBusy=true still proceeds with the
    /// normal cancel+reschedule flow. Catches a regression that
    /// over-corrects by ignoring the schedule entirely when skipIfBusy is
    /// set.
    test('skipIfBusy=true still schedules when not busy', () {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      manager.scheduleAutoSave(
        _formWith(title: 'first', ingredients: const ['x']),
        skipIfBusy: true,
      );

      expect(
        manager.hasPendingAutoSaveTimer,
        isTrue,
        reason: 'no in-flight save → normal scheduling proceeds',
      );
    });
  });

  group('clearCurrentDraft', () {
    /// Proves: `clearCurrentDraft()` is `Future<void>` (BUT-1138 — was `void`
    /// firing an unawaited delete) and nulls the in-memory pointer after the
    /// delete completes. Contract: awaiting the call leaves currentDraftId
    /// null.
    test(
      'after awaiting, currentDraftId is null and payload is gone',
      () async {
        final manager = RecipeFormAutoSaveManager();
        addTearDown(manager.dispose);

        await manager.saveNow(
          _formWith(
            title: 'a',
            ingredients: const ['x'],
          ),
        );
        final draftId = manager.currentDraftId;
        expect(draftId, isNotNull);

        await manager.clearCurrentDraft();

        expect(
          manager.currentDraftId,
          isNull,
          reason: 'pointer must be cleared after awaiting',
        );

        // Verify the per-draft payload key is also gone — confirms the delete
        // actually ran (not just the pointer nulled).
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('$_draftPrefix$draftId'),
          isNull,
          reason: 'payload must be deleted, not orphaned',
        );
      },
    );

    /// BUT-1138 race-pin: `clearCurrentDraft(); saveNow(...)` chained
    /// back-to-back. Before the fix, the synchronous-null + unawaited
    /// delete let `saveNow`'s metadata write race the just-issued
    /// `deleteDraft` metadata write; in some orderings the freshly saved
    /// draft was clobbered. After the fix, awaiting `clearCurrentDraft`
    /// guarantees the prior draft's metadata is gone BEFORE the new
    /// save's metadata is written — so the metadata index ends up with
    /// exactly one entry (the freshly saved one), and it is NOT the
    /// cleared draftId.
    test('chained clearCurrentDraft + saveNow does not race', () async {
      final manager = RecipeFormAutoSaveManager();
      addTearDown(manager.dispose);

      // First save establishes a draft id.
      await manager.saveNow(
        _formWith(
          title: 'first',
          ingredients: const ['x'],
        ),
      );
      final firstId = manager.currentDraftId;
      expect(firstId, isNotNull);

      // The contested sequence: caller clears the just-saved draft and
      // immediately starts a NEW draft via saveNow. Insert a 2ms wait so
      // the new draftId (derived from `clock.now().millisecondsSinceEpoch`)
      // is guaranteed to differ from the first one — without this the
      // test would flake on the benign collision when both saves land in
      // the same millisecond, which is not what BUT-1138 pins.
      await manager.clearCurrentDraft();
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await manager.saveNow(
        _formWith(
          title: 'second',
          ingredients: const ['y'],
        ),
      );

      final secondId = manager.currentDraftId;
      expect(secondId, isNotNull, reason: 'second save must mint a fresh id');
      expect(
        secondId,
        isNot(firstId),
        reason: 'second save must NOT reuse the cleared id',
      );

      // Metadata index: exactly one entry, the new draft. No ghost of the
      // cleared draft (would be present if the delete lost the race).
      final prefs = await SharedPreferences.getInstance();
      final metaJson = prefs.getString(_draftsKey);
      expect(
        metaJson,
        isNotNull,
        reason: 'second save must have written metadata',
      );
      final entries = jsonDecode(metaJson!) as List;
      expect(
        entries.length,
        1,
        reason: 'cleared draft must not coexist with the new draft',
      );
      expect(
        entries.first['draftId'],
        secondId,
        reason: 'the surviving entry must be the new draft',
      );

      // And the OLD draft's payload key is gone — confirms the await
      // completed before the new write started.
      expect(
        prefs.getString('$_draftPrefix$firstId'),
        isNull,
        reason: 'cleared draft payload must be gone',
      );
    });
  });
}
